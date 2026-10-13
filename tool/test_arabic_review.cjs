const fs = require('node:fs');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.PIKOLUMI_JSDOM_PATH || '../tmp/arabic-review-test/node_modules/jsdom');
const html = fs.readFileSync('docs/qa/arabic-review/index.html', 'utf8');
const storageKey = 'pikolumi-arabic-pronunciation-review-v1';
let playback = 0;
let clipboard = '';
let downloaded;
function load(source = html, saved, options = {}) {
  const errors=[];
  const console = new VirtualConsole();
  console.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(source, {url:'https://review.example.test/', runScripts:'dangerously', virtualConsole:console,
    beforeParse(window) {
      window.HTMLMediaElement.prototype.play = () => {playback++;throw new Error('Playback prohibited');};
      window.HTMLMediaElement.prototype.pause = () => {};
      window.URL.createObjectURL = blob => {downloaded=blob;return 'blob:test';};
      window.URL.revokeObjectURL = () => {};
      window.HTMLAnchorElement.prototype.click = () => {};
      if (saved) window.localStorage.setItem(storageKey,saved);
      if (options.storageFails) window.Storage.prototype.setItem = () => {throw new Error('Storage unavailable');};
      if (!options.clipboardFails) Object.defineProperty(window.navigator, 'clipboard', {value:{writeText:async text => {clipboard=text;}}});
    }
  });
  dom.errors=errors;
  return dom;
}
const doc=dom=>dom.window.document;
const card=(dom,file)=>doc(dom).querySelector(`.recording[data-file="${file}"]`);
function change(dom,element,type='change') {element.dispatchEvent(new dom.window.Event(type,{bubbles:true}));}
function flag(dom,file,value=true) {const checkbox=card(dom,file).querySelector('[data-flag]');checkbox.checked=value;change(dom,checkbox);}
function set(dom,id,value,type='change') {const el=doc(dom).getElementById(id);el.value=value;change(dom,el,type);}
const data=dom=>JSON.parse(doc(dom).getElementById('review-data').textContent);
const saved=dom=>dom.window.localStorage.getItem(storageKey);
const visible=dom=>[...doc(dom).querySelectorAll('.recording')].filter(c=>!c.hidden);
const delay=()=>new Promise(resolve=>setTimeout(resolve,20));
function readBlob(dom,blob) {return new Promise((resolve,reject)=>{const reader=new dom.window.FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=reject;reader.readAsText(blob);});}
async function importReport(dom,report) {
  const input=doc(dom).getElementById('import-report');
  const file=new dom.window.File([typeof report==='string'?report:JSON.stringify(report)],'review.json',{type:'application/json'});
  Object.defineProperty(input,'files',{configurable:true,value:[file]});change(dom,input);await delay();
}
(async()=>{
  const first=load();
  assert.equal(doc(first).querySelectorAll('.recording').length,214);
  assert.equal(doc(first).querySelector('.recording').dataset.file,'letter_0.mp3');
  assert.equal(playback,0);
  assert.equal(doc(first).querySelectorAll('audio[autoplay]').length,0);
  assert.equal(doc(first).getElementById('copy-report').disabled,true);
  flag(first,'letter_13.mp3');flag(first,'syllable_40.mp3');
  const note=card(first,'syllable_40.mp3').querySelector('[data-note]');note.value='ملاحظة اختبار';change(first,note,'input');
  assert.equal(doc(first).getElementById('selected-count').textContent,'2 selected');
  set(first,'view','selected');assert.equal(visible(first).length,2);
  set(first,'category','syllables');assert.equal(visible(first).length,1);
  const clip=data(first).recordings.find(c=>c.file==='syllable_40.mp3');
  set(first,'search',clip.text.normalize('NFD').replace(/\p{M}/gu,''),'input');assert.equal(card(first,clip.file).hidden,false);
  set(first,'search','NO_SUCH_RECORDING','input');assert.equal(visible(first).length,0);assert.equal(doc(first).getElementById('empty').hidden,false);
  set(first,'search','','input');
  doc(first).getElementById('copy-report').click();await delay();
  assert.match(clipboard,/syllable_40\.mp3/);assert.match(clipboard,/ملاحظة اختبار/);assert.doesNotMatch(clipboard,/letter_0\.mp3/);
  assert.equal(doc(first).getElementById('report').hidden,false);
  doc(first).getElementById('close-report').click();assert.equal(doc(first).getElementById('report').hidden,true);
  doc(first).getElementById('download-report').click();
  const exported=JSON.parse(await readBlob(first,downloaded));
  assert.equal(exported.recordings.length,2);assert.equal(exported.reviewMode,'corrections_only');assert.equal(exported.recordings[1].notes,'ملاحظة اختبار');
  const reload=load(html,saved(first));assert.equal(doc(reload).getElementById('selected-count').textContent,'2 selected');assert.equal(card(reload,clip.file).querySelector('[data-note]').value,'ملاحظة اختبار');
  doc(reload).getElementById('unselect-all').click();assert.equal(doc(reload).getElementById('selected-count').textContent,'0 selected');
  flag(reload,clip.file);assert.equal(card(reload,clip.file).querySelector('[data-note]').value,'ملاحظة اختبار');
  const changedData=data(first);changedData.recordings.find(c=>c.file==='letter_13.mp3').sha256='new-recording-hash';
  const changedHtml=html.replace(/(<script type="application\/json" id="review-data">)[\s\S]*?(<\/script>)/,(_,open,close)=>open+JSON.stringify(changedData)+close);
  const updated=load(changedHtml,saved(first));assert.equal(card(updated,'letter_13.mp3').querySelector('[data-flag]').checked,false);assert.equal(card(updated,'letter_13.mp3').querySelector('[data-updated]').hidden,false);
  const updatedReload=load(changedHtml,saved(updated));assert.equal(card(updatedReload,'letter_13.mp3').querySelector('[data-updated]').hidden,false);
  const fallback=load(html,undefined,{storageFails:true,clipboardFails:true});flag(fallback,'letter_13.mp3');assert.match(doc(fallback).getElementById('storage-status').textContent,/unavailable/);
  doc(fallback).getElementById('copy-report').click();await delay();assert.match(doc(fallback).getElementById('action-status').textContent,/Command\+C/);assert.equal(doc(fallback).activeElement.id,'report-text');
  const imported=load();await importReport(imported,exported);assert.equal(doc(imported).getElementById('selected-count').textContent,'2 selected');
  await importReport(imported,{...exported,recordings:[{...exported.recordings[0],file:'unknown.mp3'}]});assert.equal(doc(imported).getElementById('selected-count').textContent,'2 selected');assert.equal(doc(imported).getElementById('action-status').classList.contains('error'),true);
  await importReport(imported,'bad-json');assert.equal(doc(imported).getElementById('selected-count').textContent,'2 selected');
  const staleImport=load(changedHtml);await importReport(staleImport,exported);assert.equal(doc(staleImport).getElementById('selected-count').textContent,'1 selected');assert.match(doc(staleImport).getElementById('action-status').textContent,/changed/);
  for (const dom of [first,reload,updated,updatedReload,fallback,imported,staleImport]) {assert.deepEqual(dom.errors,[]);dom.window.close();}
  assert.equal(playback,0);
  const report={checkedAtUTC:new Date().toISOString(),passed:true,recordings:214,audioPlaybackCalls:playback,method:'Isolated jsdom document tests; no browser session or network resources',checks:['checkboxes','optional Arabic notes','selected/category/search filters','empty states','copy and clipboard fallback','download JSON','reload persistence','storage unavailable fallback','unselect retains notes','changed audio requires re-selection','valid and invalid imports','all audio starts only on manual play'],visualBrowserVerification:'not performed; local file URLs are blocked by browser automation policy'};
  fs.writeFileSync('docs/qa/arabic-review/selection-ui-validation.json',JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exit(1);});
