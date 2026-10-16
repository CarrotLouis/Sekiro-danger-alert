"""Build-time checks and comment removal; no game access or file writes.

The release carries executable modules and localized UI only. Lua strings,
including long strings and escaped PCM, must survive comment removal verbatim.
"""
import json
from pathlib import Path
import re

LANGUAGES = {'en', 'fr', 'it', 'de', 'es', 'es-419', 'ja', 'ko',
             'pl', 'pt', 'pt-BR', 'ru', 'zh-Hans', 'zh-Hant'}


def without_comments(source):
    pieces, i = [], 0
    opening = re.compile(r'\[(=*)\[')
    while i < len(source):
        start = i
        comment = source.startswith('--', i)
        if comment:
            i += 2
        bracket = opening.match(source, i)
        if bracket:
            closing = ']' + bracket.group(1) + ']'
            end = source.find(closing, bracket.end())
            if end < 0:
                raise ValueError('unterminated Lua long string/comment')
            i = end + len(closing)
            pieces.append(' ' + '\n' * source[start:i].count('\n') if comment else source[start:i])
        elif comment:
            end = source.find('\n', i)
            i = len(source) if end < 0 else end
            pieces.append(' ')
        elif source[i] in ('"', "'"):
            quote = source[i]
            i += 1
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                elif source[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            else:
                raise ValueError('unterminated Lua quoted string')
            pieces.append(source[start:i])
        else:
            pieces.append(source[i])
            i += 1
    return ''.join(pieces)


def load_locales(root):
    folder = Path(root) / 'locales'
    result = {p.stem: json.loads(p.read_text(encoding='utf-8')) for p in sorted(folder.glob('*.json'))}
    if set(result) != LANGUAGES:
        raise ValueError('locale coverage differs: ' + repr(set(result) ^ LANGUAGES))
    reference = set(result['en'])
    for language, texts in result.items():
        if set(texts) != reference:
            raise ValueError(f'{language}: missing/extra translation keys')
        for key, text in texts.items():
            limit = 400 if key.endswith('_desc') else 64 if key.startswith('move.') or key not in (
                'ready', 'play', 'later', 'restore') else 48
            if not isinstance(text, str) or not text.strip() or len(text) > limit or any(ord(c) < 32 for c in text):
                raise ValueError(f'{language}/{key}: invalid or oversized text')
            if '/' in text or re.search(r'测试|采集|诊断|\b(?:testing|diagnostics|capture)\b', text, re.I):
                raise ValueError(f'{language}/{key}: development or bilingual text')
            if language not in ('zh-Hans', 'zh-Hant', 'ja') and re.search('[\u3400-\u9fff]', text):
                raise ValueError(f'{language}/{key}: unexpected CJK text')
    return result
