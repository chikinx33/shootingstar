"""v38 migration/check for the shared centered text policy (no font changes)."""
from pathlib import Path
import argparse
import re

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check',action='store_true')
args=parser.parse_args()

def mask(s):
    return re.sub(r"//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"",lambda m:' '*len(m[0]),s)

count=0; failures=[]
for p in [*(ROOT/'lib/ui').glob('*.dart'),ROOT/'lib/art/raster_assets.dart']:
    s=p.read_text(encoding='utf8');m=mask(s);edits=[]
    for call in re.finditer(r'\b(?:Text(?:\.rich)?|SelectableText(?:\.rich)?|TextField|TextFormField|RichText)\s*\(',m):
        start=call.end();i=start;depth=1;align=None
        while i<len(m) and depth:
            if depth==1:
                a=re.match(r'textAlign\s*:\s*([^,\n)]+)',m[i:])
                if a: align=(i+a.start(1),i+a.end(1))
            if m[i] in '([{':depth+=1
            elif m[i] in ')]}':depth-=1
            i+=1
        assert depth==0,(p,call.start())
        if align:
            if m[align[0]:align[1]].strip()=='TextAlign.center':continue
            edits.append((align[0],align[1],'TextAlign.center'))
        else:
            end=i-1;comma='' if m[start:end].rstrip().endswith(',') else ','
            edits.append((end,end,comma+'\ntextAlign: TextAlign.center,\n'))
    if args.check:
        if edits:failures.append(str(p.relative_to(ROOT)))
    else:
        for a,b,v in sorted(edits,reverse=True):s=s[:a]+v+s[b:]
        # Preserve stretch (equal slot heights/full-width cells), center the
        # formerly leading/trailing aligned text groups inside each cell.
        s=re.sub(r'crossAxisAlignment:\s*CrossAxisAlignment\.(start|end)',
                 'crossAxisAlignment: CrossAxisAlignment.center',s)
        if s!=p.read_text(encoding='utf8'):p.write_text(s,encoding='utf8')
    count+=len(edits)
if failures:raise SystemExit('Missing centered text: '+', '.join(failures))
print('Centered text contract passed' if args.check else f'Centered {count} text controls')
