"""Release text completeness, Lua comment lexer and end-user artifact boundary."""
from pathlib import Path
import re
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from release_source import load_locales,without_comments

locales=load_locales(ROOT)
assert len(locales)==14 and len(locales['en'])==48
sample='''-- remove this line
local--[[ comment ]]value="-- keep this string"
local text=[==[ -- keep long string ]==]
local quote='it\\\'s -- still a string' -- tail
--[=[multi
line]=]
return value,text,quote
'''
result=without_comments(sample)
assert 'remove this line' not in result and 'comment' not in result and 'multi' not in result
for text in ['-- keep this string','-- keep long string',"it\\'s -- still a string"]:
    assert text in result
assert 'local value=' in result and result.count('\n')==sample.count('\n')
for invalid in ['--[=[unfinished','"unfinished']:
    try:without_comments(invalid)
    except ValueError:pass
    else:raise AssertionError('invalid Lua not refused')

for name in ['README.md','README.txt','README-使用说明.txt','CREDITS.txt','CHANGELOG.md','docs/RELEASE-1.0.0.md']:
    text=(ROOT/name).read_text(encoding='utf-8')
    assert not re.search(r'测试|采集|诊断|\b(?:tests?|testing|captures?|diagnostics|F8|Spawner)\b',text,re.I),name
    if name.startswith('README'):
        for filename in ['Sekiro danger alert.log','ModOptionsMenu.values','ModOptionsMenu.values.bak',
                'ModOptionsMenu.values.tmp','ModOptionsMenu.log','BingusSharedLoader.log']:
            assert filename in text,(name,filename)
        assert '%LOCALAPPDATA%\\CowboyBingus\\Helldivers2\\Logs\\'in text

with zipfile.ZipFile(ROOT/'outputs/Sekiro danger alert 1.0.0.zip')as archive:
    assert not re.search(r'测试|采集|诊断|\b(?:tests?|testing|captures?|diagnostics?|F8|Spawner)\b',archive.read('manifest.json').decode('utf-8'),re.I)
    for name in ['README.txt','README-使用说明.txt','CREDITS.txt']:
        assert archive.read(name)==(ROOT/name).read_bytes(),name
    for source,target in [('Bingus-LICENSE.txt','LICENSES/Bingus-0BSD.txt'),('HD2Runtime-LICENSE.txt','LICENSES/HD2Runtime-MIT.txt')]:
        assert archive.read(target)==(ROOT/'vendor'/source).read_bytes()
print('PASS complete localized text, quoted/long Lua strings, clean public guides, runtime file disclosure and exact licenses')
