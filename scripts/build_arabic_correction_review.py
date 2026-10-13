"""Offline before/after review of corrected Arabic audio. No automatic playback."""
import argparse
import csv
import hashlib
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--folder', default='docs/qa/arabic-corrections')
args = parser.parse_args()
FOLDER = (ROOT / args.folder).resolve()
assert FOLDER.is_relative_to(ROOT)
data = json.loads((FOLDER / 'candidates.json').read_text())
request = json.loads((FOLDER / 'requested.json').read_text())
data['round'] = request.get('round', '2026-10-12')
data['storageKey'] = 'pikolumi-arabic-corrections-2026-10-12-v1' if FOLDER.name == 'arabic-corrections' else f'pikolumi-{FOLDER.name}-v1'
provenance = json.loads((ROOT / 'assets/content/audio_provenance.json').read_text())
approved_total = sum(r.get('nativeReview', {}).get('decision') == 'correct'
                     for r in provenance['locales']['ar']['clips'].values())
notice = 'These new Modern Standard Arabic takes are not bundled until you approve them. Compare each take, select Sounds correct or Still wrong, then Save review. No audio autoplays.'
summary = FOLDER / 'imported-review.json'
if summary.exists():
    imported = json.loads(summary.read_text())
    data['importedReview'] = json.loads((ROOT / imported['reviewFile']).read_text())
    notice = f"This round: {len(imported['approvedAndBundled'])} takes approved and {len(imported['rejectedAndNotBundled'])} rejected. Your exact imported decisions are shown here. {approved_total} approved replacements are now bundled across all rounds."
    round_number = re.fullmatch(r'arabic-corrections-round(\d+)(?:-[a-z]+)?', FOLDER.name)
    next_name = 'arabic-corrections-round2' if FOLDER.name == 'arabic-corrections' else f'arabic-corrections-round{int(round_number[1]) + 1}' if round_number else 'next-review'
    next_folder = FOLDER.parent / next_name
    if (next_folder / 'candidates.json').exists():
        count = len(json.loads((next_folder / 'candidates.json').read_text())['recordings'])
        notice += f" <a href='../{next_name}/index.html'>Open the next review round ({count} takes)</a>."
else:
    notice += f' The {approved_total} previously approved replacements are already bundled.'
alternate_name = FOLDER.name + '-alternative'
if (FOLDER.parent / alternate_name / 'candidates.json').exists():
    notice += f" <a href='../{html.escape(alternate_name)}/index.html'>Compare the other new take</a>."
elif FOLDER.name.endswith('-alternative'):
    primary_name = FOLDER.name.removesuffix('-alternative')
    if (FOLDER.parent / primary_name / 'candidates.json').exists():
        notice += f" <a href='../{html.escape(primary_name)}/index.html'>Compare the first new take</a>."
cards = []
for row in data['recordings']:
    file = row['file']
    for directory, expected in [('originals', row['originalSha256']), ('candidates', row['sha256'])]:
        assert hashlib.sha256((FOLDER / directory / file).read_bytes()).hexdigest() == expected
    context_player = ''
    if row.get('contextualSource'):
        context = row['contextualSource']
        assert hashlib.sha256((FOLDER / context['file']).read_bytes()).hexdigest() == context['sha256']
        context_player = f'''<label class="context-source">Source word: <span lang="ar" dir="rtl">{html.escape(row['synthesisText'])}</span><audio controls preload="none" aria-label="Source word for {file}" src="{html.escape(context['file'])}?v={context['sha256']}"></audio></label>'''
    cards.append(f'''<article data-file="{html.escape(file)}">
<h2>{html.escape(file)}</h2><p class="arabic" lang="ar" dir="rtl">{html.escape(row['text'])}</p>
<p>Your note: {html.escape(row['note'])}</p>
<div class="comparison"><label>Original<audio controls preload="none" aria-label="Original {file}" src="originals/{file}?v={row['originalSha256']}"></audio></label>
<label>New candidate<audio controls preload="none" aria-label="New recording {file}" src="candidates/{file}?v={row['sha256']}"></audio></label>{context_player}</div>
<fieldset><legend>New recording</legend><label><input type="radio" name="{file}" value="correct"> Sounds correct</label>
<label><input type="radio" name="{file}" value="wrong"> Still wrong</label></fieldset>
<label class="notes">Further correction (optional)<textarea dir="auto" maxlength="5000"></textarea></label>
</article>''')
payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pikolumi Arabic corrections</title><style>
@font-face{font-family:Nunito;src:url('../../../assets/fonts/Nunito.ttf')}@font-face{font-family:Arabic;src:url('../../../assets/fonts/NotoSansArabic.ttf')}
*{box-sizing:border-box}body{margin:0;background:#fbf7ee;color:#344850;font:17px/1.5 Nunito,system-ui}main{max-width:1000px;margin:auto;padding:28px 20px}
h1{font-size:32px;line-height:1.2}h2{font-size:19px;overflow-wrap:anywhere;margin:0}.arabic{font:32px/1.7 Arabic; margin:10px 0}
a{color:#12606a}article{background:white;border:1px solid #c8d5d4;border-radius:18px;margin:20px 0;padding:22px}
.comparison{display:grid;grid-template-columns:1fr 1fr;gap:20px}.comparison label{min-width:0}.context-source{grid-column:1/-1}audio{display:block;width:100%;margin-top:8px}
fieldset{border:0;padding:0;margin:18px 0}legend{font-weight:800;margin-bottom:6px}fieldset label{display:inline-flex;align-items:center;gap:10px;min-height:48px;margin-right:20px}
input[type=radio]{width:22px;height:22px;accent-color:#12606a}.notes{display:block}textarea{display:block;width:100%;min-height:70px;padding:10px;font:inherit;border:1px solid #849c9f;border-radius:8px}
.tools{display:flex;flex-wrap:wrap;align-items:center;gap:12px;margin:22px 0}input[type=search],select,button{font:inherit;padding:12px;border-radius:10px;min-height:48px;border:1px solid #849c9f;background:white;color:#344850}
input[type=search]{flex:1;min-width:180px}button{background:#12606a;color:white;border:0;font-weight:800;cursor:pointer}:focus-visible{outline:3px solid #344850;outline-offset:3px}
[hidden]{display:none!important}.notice{border-left:4px solid #12606a;padding-left:15px}#status{font-weight:800}
@media(max-width:650px){.comparison{grid-template-columns:1fr}main{padding:18px 12px}article{padding:16px}}
</style><main><a href="../arabic-review/index.html">Full Arabic review</a><h1>Arabic pronunciation corrections</h1>
<p class="notice">@@NOTICE@@</p>
<p>Short vowels remain short: fatḥa = a, kasra = i, ḍamma = u. Keep the distinct sounds of <span lang="ar" dir="rtl">ح، ه، ع، غ، ذ، ظ، ص، ط</span>.</p>
<div class="tools"><input type="search" id="search" aria-label="Find recording" placeholder="Filename, Arabic text, or note">
<select id="filter" aria-label="Review filter"><option value="all">All recordings</option><option value="pending">Not reviewed</option><option value="wrong">Still wrong</option><option value="correct">Sounds correct</option></select>
<button id="export">Save review</button></div><p id="storage-warning" role="alert" hidden>Browser storage is unavailable. Use Save review to keep your choices before closing this page.</p><p id="status" role="status" aria-live="polite"></p><p id="empty" hidden>No recordings match this filter.</p>
@@CARDS@@<script id="review-data" type="application/json">@@DATA@@</script><script>
(()=>{'use strict';const data=JSON.parse(document.getElementById('review-data').textContent),key=data.storageKey,states={};
let previous={};try{previous=JSON.parse(localStorage.getItem(key)||'{}')}catch(_){}
const incoming=Object.fromEntries((data.importedReview?.recordings||[]).map(r=>[r.file,r]));
for(const r of data.recordings){const p=previous[r.file]||incoming[r.file];states[r.file]=p?.sha256===r.sha256&&['correct','wrong',null].includes(p.decision)?p:{sha256:r.sha256,decision:null,notes:p?.notes||''}}
const search=document.getElementById('search'),filter=document.getElementById('filter');
function render(){let shown=0,reviewed=0,wrong=0;for(const r of data.recordings){const s=states[r.file],card=document.querySelector('article[data-file="'+r.file+'"]');if(s.decision)reviewed++;if(s.decision==='wrong')wrong++;
card.hidden=!(filter.value==='all'||(filter.value==='pending'&&!s.decision)||filter.value===s.decision)||!`${r.file} ${r.text} ${r.note}`.toLowerCase().includes(search.value.toLowerCase());if(!card.hidden)shown++;
for(const radio of card.querySelectorAll('input[type=radio]'))radio.checked=radio.value===s.decision;card.querySelector('textarea').value=s.notes;}
document.getElementById('status').textContent=`${reviewed} of ${data.recordings.length} reviewed · ${wrong} still wrong · ${shown} shown`;document.getElementById('empty').hidden=shown!==0;}
function save(){try{localStorage.setItem(key,JSON.stringify(states));document.getElementById('storage-warning').hidden=true}catch(_){document.getElementById('storage-warning').hidden=false}}
document.addEventListener('change',e=>{const card=e.target.closest('article');if(!card||e.target.type!=='radio')return;states[card.dataset.file].decision=e.target.value;save();render()});
document.addEventListener('input',e=>{const card=e.target.closest('article');if(card&&e.target.tagName==='TEXTAREA'){states[card.dataset.file].notes=e.target.value;save()}});
search.addEventListener('input',render);filter.addEventListener('change',render);
document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')for(const a of document.querySelectorAll('audio'))if(a!==e.target)a.pause()},true);
document.getElementById('export').addEventListener('click',()=>{const report={locale:'ar',round:data.round,exportedAt:new Date().toISOString(),recordings:data.recordings.map(r=>({file:r.file,text:r.text,...states[r.file]}))};const url=URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='pikolumi-arabic-replacement-review.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});render();})();
</script></main></html>'''
(FOLDER / 'index.html').write_text(page.replace('@@NOTICE@@',notice).replace('@@CARDS@@', ''.join(cards)).replace('@@DATA@@', payload))
print(f'Built focused before/after review for {len(cards)} candidates')
