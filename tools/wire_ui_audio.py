"""One-time v35 migration: preserve callback expressions, wrap real activation.

No pointer/drag/scroll handlers or text input onChanged handlers are touched.
Wrapped null still means disabled. Shared forwarding callbacks are deduplicated
by the director, and accessible/keyboard activation uses the same callback.
"""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]


def expression_end(s, start):
    depth=0
    i=start
    while i<len(s):
        if s.startswith('//',i):
            i=s.find('\n',i)
            if i<0: return len(s)
        elif s.startswith('/*',i):
            i=s.index('*/',i+2)+2
        elif s[i] in "'\"":
            quote=s[i]*3 if s.startswith(s[i]*3,i) else s[i]
            i+=len(quote)
            while i<len(s) and not s.startswith(quote,i):
                i+=2 if s[i]=='\\' else 1
            i+=len(quote)
        else:
            c=s[i]
            if c in '([{': depth+=1
            elif c in ')]}':
                if depth==0: return i
                depth-=1
            elif c==',' and depth==0: return i
            i+=1
    raise ValueError('Unterminated callback')


def main():
    count=0
    for p in [* (ROOT/'lib/ui').glob('*.dart'), ROOT/'lib/art/raster_assets.dart']:
        if p.name=='audio_feedback.dart': continue
        s=p.read_text(encoding='utf-8-sig')
        edits=[]
        for m in re.finditer(r'\b(onPressed|onTap|onLongPress|onSelected|onChanged|onDestinationSelected|onSelectionChanged|onSubmitted)\s*:\s*',s):
            start=m.end()
            end=expression_end(s,start)
            value=s[start:end].rstrip()
            if not value or value=='null' or value.startswith(('audible(', 'audibleChange(')): continue
            # Text fields do not beep on every keystroke (submitting is audible).
            if m[1]=='onChanged' and p.name in ('account_screen.dart','delete_account_screen.dart','progress_backup_screen.dart'): continue
            wrapper='audible' if m[1] in ('onPressed','onTap','onLongPress') else 'audibleChange'
            edits.extend([(start,wrapper+'('),(start+len(value),')')])
        if not edits: continue
        count+=len(edits)//2
        for pos,text in sorted(edits,key=lambda v:v[0],reverse=True): s=s[:pos]+text+s[pos:]
        imp="import 'audio_feedback.dart';\n" if p.parent.name=='ui' else "import '../ui/audio_feedback.dart';\n"
        s=imp+s
        p.write_text(s,encoding='utf-8')
    print('Wrapped control callbacks:',count)


if __name__=='__main__': main()
