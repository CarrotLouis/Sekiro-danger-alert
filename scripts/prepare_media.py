"""Extract straight-alpha frames from the user's black-backed MP4, streaming one frame at a time."""
from pathlib import Path
import argparse, json, subprocess, zipfile, hashlib, shutil
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
PARSER=argparse.ArgumentParser(description=__doc__)
PARSER.add_argument('source',type=Path)
PARSER.add_argument('--ffmpeg',default='ffmpeg')
PARSER.add_argument('--output-dir',type=Path,default=ROOT/'outputs')
ARGS=PARSER.parse_args()
OUT=ARGS.output_dir.resolve()
SOURCE=ARGS.source.resolve()
FF=ARGS.ffmpeg
DEST=OUT/'Sekiro danger alert Transparent Sequence'
FRAMES=DEST/'PNG_1920x1080_5994fps'
FRAMES.mkdir(parents=True,exist_ok=True)
W,H=1920,1080
cmd=[str(FF),'-v','error','-i',str(SOURCE),'-map','0:v:0','-vsync','0','-f','rawvideo','-pix_fmt','rgb24','pipe:1']
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
samples={};bounds=[];visible=[];n=0;errmax=0
while True:
 data=p.stdout.read(W*H*3)
 if not data:break
 if len(data)!=W*H*3:raise RuntimeError('incomplete video frame')
 c=np.frombuffer(data,dtype=np.uint8).reshape(H,W,3)
 alpha=c.max(axis=2)
 alpha=np.where(alpha<=3,0,alpha).astype(np.uint8)
 # Minimal opacity unmult: C = straight_RGB * alpha over black.
 rgb=np.minimum(255,np.rint(c.astype(np.float32)*255/np.maximum(alpha[...,None],1))).astype(np.uint8)
 rgb[alpha==0]=0
 rgba=np.dstack((rgb,alpha))
 im=Image.fromarray(rgba,'RGBA');im.save(FRAMES/f'peril_{n:04d}.png',compress_level=6)
 if n in (0,6,12,18,30,42,60,78,90):samples[n]=im.copy()
 active=alpha>8
 if active.any():
  yy,xx=np.where(active);bounds.append([int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)])
  visible.append(n)
 reconstructed=np.rint(rgb.astype(np.float32)*(alpha[...,None].astype(np.float32)/255))
 errmax=max(errmax,int(np.abs(reconstructed-c).max()))
 n+=1
 if n%60==0: print(f'Frames extracted: {n}',flush=True)
assert p.wait()==0,p.stderr.read().decode(errors='replace')
assert n==300,n
subprocess.run([str(FF),'-v','error','-y','-i',str(SOURCE),'-vn','-ac','2','-ar','48000','-c:a','pcm_s16le',str(DEST/'peril_audio_original_48k_stereo.wav')],check=True)
info={'source':SOURCE.name,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 'frames':n,'fps_numerator':60000,'fps_denominator':1001,'fps':60000/1001,'width':W,'height':H,
 'duration_seconds':n*1001/60000,'first_visible_frame':min(visible),'last_visible_frame':max(visible),
 'content_bounds':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)],
 'alpha':'straight / unassociated; estimated from black-composited source via max-channel unmult',
 'black_noise_threshold_8bit':3,'max_black_recomposition_error_8bit':errmax,
 'audio_offset_seconds':0,'frame_zero_time_seconds':0}
(DEST/'sequence.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
(DEST/'使用说明.txt').write_text('只狼 危 — 透明 PNG 序列\n\n300 帧，1920×1080，59.94005994 fps（60000/1001），总长 5.005 秒。\n从 peril_0000.png 开始按 PNG 序列导入，指定 59.94 fps；WAV 从时间轴 0 秒对齐。\n透明通道为 Straight / Unmatted（直通、无预乘），不是 Premultiplied。\n黑底已移入 Alpha；画面后段原本为空，保留空白帧用于与音频尾音对齐。\n\nMP4 原片没有 Alpha。此序列通过“移除黑色预乘”重建透明度，并不是原始工程的无损 Alpha。\n保留红色光晕与白色亮芯；极暗压缩噪点（最大通道 <= 3/255）被清除。\n普通 Alpha 合成在明亮背景上会减弱；若要原本发光叠加观感，可在剪辑软件使用 Add/Screen，\n但采用叠加混合前应检查光晕，避免重复去黑或重复乘 Alpha。\n用于游戏时还需编译纹理/材质，并通过 Lua 按帧切换；游戏不能直接加载此序列或 .aep。\n',encoding='utf-8')
# Show identical frames over checker, dark and light backgrounds.
keys=[6,12,18,30,42,60]
cw,ch=240,240
sheet=Image.new('RGB',(cw*len(keys),ch*3+60),(24,24,28));draw=ImageDraw.Draw(sheet)
for ix,k in enumerate(keys):
 frame=samples[k].crop((480,60,1440,1020)).resize((cw,ch),Image.Resampling.LANCZOS)
 for row,kind in enumerate(['CHECKER','DARK','LIGHT']):
  bg=Image.new('RGBA',(cw,ch),((24,26,30,255) if row==1 else (224,224,220,255)))
  if row==0:
   d=ImageDraw.Draw(bg)
   for y in range(0,ch,20):
    for x in range(0,cw,20):d.rectangle((x,y,x+19,y+19),fill=((72,72,76,255) if (x//20+y//20)%2 else (104,104,108,255)))
  bg.alpha_composite(frame);sheet.paste(bg.convert('RGB'),(ix*cw,30+row*ch))
 draw.text((ix*cw+8,10),f'{k/float(60000/1001):.2f}s',fill='white')
draw.text((8,ch*3+38),'Same straight-alpha frames: checker / dark / light',fill='white')
sheet.save(OUT/'Sekiro danger alert Transparency Check.png')
with zipfile.ZipFile(OUT/'Sekiro danger alert Transparent PNG 5994fps.zip','w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
 for f in sorted(DEST.rglob('*')):
  if f.is_file():z.write(f,f.relative_to(OUT).as_posix())
print(json.dumps(info,ensure_ascii=False),flush=True)
