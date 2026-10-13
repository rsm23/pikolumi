const fs = require('node:fs');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.PIKOLUMI_JSDOM_PATH || '../tmp/arabic-review-test/node_modules/jsdom');
const folder='docs/qa/language-review';
const manifest=JSON.parse(fs.readFileSync(`${folder}/packet-manifest.json`,'utf8'));
let playback=0,downloaded,clipboard='',network=0;
function load(path,storage={}) {
  const errors=[],console=new VirtualConsole();console.on('jsdomError',error=>errors.push(error.message));
  const source=fs.readFileSync(path,'utf8').replace(/(<script type="application\/json" id="review-data">)([\s\S]*?)(<\/script>)/,(_,open,text,close)=>{
    const fixture=JSON.parse(text);for(const clip of fixture.recordings)delete clip.initialReview;return open+JSON.stringify(fixture)+close;
  });
  const dom=new JSDOM(source,{url:'https://review.example.test/',runScripts:'dangerously',virtualConsole:console,beforeParse(window){
    window.HTMLMediaElement.prototype.play=()=>{playback++;throw new Error('Playback prohibited');};
    window.HTMLMediaElement.prototype.pause=()=>{};
    window.fetch=()=>{network++;throw new Error('Network prohibited');};
    window.URL.createObjectURL=blob=>{downloaded=blob;return 'blob:review-test';};window.URL.revokeObjectURL=()=>{};window.HTMLAnchorElement.prototype.click=()=>{};
    Object.defineProperty(window.navigator,'clipboard',{value:{writeText:async text=>{clipboard=text;}}});
    for(const [key,value] of Object.entries(storage))window.localStorage.setItem(key,value);
  }});
  dom.errors=errors;return dom;
}
const doc=dom=>dom.window.document;
const data=dom=>JSON.parse(doc(dom).getElementById('review-data').textContent);
const card=(dom,file)=>doc(dom).querySelector(`.recording[data-file="${file}"]`);
const delay=()=>new Promise(resolve=>setTimeout(resolve,20));
function change(dom,element,type='change'){element.dispatchEvent(new dom.window.Event(type,{bubbles:true}));}
function flag(dom,file){const checkbox=card(dom,file).querySelector('[data-flag]');checkbox.checked=true;change(dom,checkbox);}
function set(dom,id,value,type='change'){const element=doc(dom).getElementById(id);element.value=value;change(dom,element,type);}
function storage(dom){return Object.fromEntries(Object.keys(dom.window.localStorage).map(key=>[key,dom.window.localStorage.getItem(key)]));}
function readBlob(dom,blob){return new Promise((resolve,reject)=>{const reader=new dom.window.FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=reject;reader.readAsText(blob);});}
async function importReport(dom,report){const input=doc(dom).getElementById('import-report');Object.defineProperty(input,'files',{configurable:true,value:[new dom.window.File([JSON.stringify(report)],'review.json',{type:'application/json'})]});change(dom,input);await delay();}
(async()=>{
  const all=[];let sharedStorage={},frenchReport;
  for(const entry of manifest.locales) {
    const page=entry.locale==='ar'?'docs/qa/arabic-review/index.html':`${folder}/${entry.locale}.html`;
    const dom=load(page,sharedStorage);all.push(dom);
    assert.equal(doc(dom).querySelectorAll('.recording').length,entry.recordings);
    assert.equal(data(dom).locale,entry.locale);
    assert.equal(doc(dom).getElementById('selected-count').textContent,'0 selected');
    flag(dom,'letter_0.mp3');const note=card(dom,'letter_0.mp3').querySelector('[data-note]');note.value=`Test note for ${entry.locale}`;change(dom,note,'input');
    doc(dom).getElementById('copy-report').click();await delay();assert.match(clipboard,new RegExp(data(dom).localeName));
    doc(dom).getElementById('download-report').click();const exported=JSON.parse(await readBlob(dom,downloaded));
    assert.equal(exported.locale,entry.locale);assert.equal(exported.recordings.length,1);assert.equal(exported.recordings[0].notes,`Test note for ${entry.locale}`);
    if(entry.locale==='fr')frenchReport=exported;
    sharedStorage=storage(dom);
    const reload=load(page,sharedStorage);all.push(reload);assert.equal(doc(reload).getElementById('selected-count').textContent,'1 selected');
    assert.equal(card(reload,'letter_0.mp3').querySelector('[data-note]').value,`Test note for ${entry.locale}`);
  }
  assert.equal(Object.keys(sharedStorage).length,5);
  const english=load(`${folder}/en.html`,sharedStorage);all.push(english);
  const previous=storage(english);await importReport(english,frenchReport);assert.deepEqual(storage(english),previous);assert.equal(doc(english).getElementById('action-status').classList.contains('error'),true);
  const bulk=load('docs/qa/arabic-review/index.html');all.push(bulk);
  const fullReport={schema:1,locale:'ar',reviewMode:'corrections_only',recordings:data(bulk).recordings.map(clip=>({file:clip.file,sha256:clip.sha256,notes:'م'.repeat(5000)}))};
  assert.ok(Buffer.byteLength(JSON.stringify(fullReport))>1024*1024);
  await importReport(bulk,fullReport);assert.equal(doc(bulk).getElementById('selected-count').textContent,'214 selected');
  doc(bulk).getElementById('download-report').click();const fullExport=JSON.parse(await readBlob(bulk,downloaded));assert.equal(fullExport.recordings.length,214);assert.ok(fullExport.recordings.every(clip=>clip.notes.length===5000));
  for(const entry of manifest.locales) {
    const dom=load(`${folder}/${entry.locale}-lessons.html`);all.push(dom);
    const lessons=JSON.parse(doc(dom).getElementById('lesson-data').textContent).activities;
    assert.equal(lessons.length,2400);assert.equal(new Set(lessons.map(lesson=>lesson.id)).size,2400);
    assert.equal(doc(dom).querySelectorAll('.lesson').length,24);assert.equal(doc(dom).getElementById('previous').disabled,true);
    doc(dom).getElementById('next').click();assert.equal(doc(dom).querySelector('.lesson').dataset.activityId,lessons[24].id);assert.equal(doc(dom).getElementById('previous').disabled,false);
    set(dom,'section','letters');assert.equal(doc(dom).getElementById('count').textContent,'160 of 2400 activities');
    const stage=lessons.find(lesson=>lesson.section==='letters').stage;set(dom,'stage',String(stage));
    assert.match(doc(dom).getElementById('count').textContent,new RegExp(`^${lessons.filter(lesson=>lesson.section==='letters'&&lesson.stage===stage).length} of`));
    set(dom,'section','all');set(dom,'stage','all');set(dom,'search','tracing-0001','input');assert.equal(doc(dom).querySelectorAll('.lesson').length,1);
    const trace=lessons.find(lesson=>lesson.id==='tracing-0001');const guide=doc(dom).querySelector('svg');assert.equal(guide.getAttribute('viewBox'),'0 0 220 220');
    assert.equal(guide.querySelectorAll('polyline').length,trace.config.strokes.length);assert.equal(guide.querySelector('polyline').getAttribute('points'),trace.config.strokes[0].map(point=>point.join(',')).join(' '));
    set(dom,'search','math-0001','input');const display=doc(dom).querySelector('.display');assert.equal(display.dir,'ltr');assert.equal(doc(dom).querySelectorAll('li').length,4);
    assert.match(doc(dom).querySelector('li').parentElement.textContent,/\(correct\)/);
    set(dom,'search','NO_SUCH_ACTIVITY','input');assert.equal(doc(dom).querySelectorAll('.lesson').length,0);assert.equal(doc(dom).getElementById('empty').hidden,false);assert.equal(doc(dom).getElementById('next').disabled,true);
    assert.equal(doc(dom).querySelectorAll('audio,video').length,0);
    assert.equal(doc(dom).getElementById('search').value,'NO_SUCH_ACTIVITY');
  }
  for(const dom of all){assert.deepEqual(dom.errors,[]);dom.window.close();}
  assert.equal(playback,0);assert.equal(network,0);
  const result={checkedAtUTC:new Date().toISOString(),passed:true,method:'Isolated jsdom documents; no browser session, network resources or media playback',localeRecordingCounts:Object.fromEntries(manifest.locales.map(entry=>[entry.locale,entry.recordings])),lessonLocales:5,activitiesPerLocale:2400,distinctAdvertisedActivities:2400,audioPlaybackCalls:playback,networkRequests:network,checks:['locale-specific copies and exports','separate saved selections across identical filenames','cross-locale import rejection without losing notes','recording reload persistence','full Arabic correction list with maximum-length Unicode notes','24-item lesson pagination','section and stage filters','activity search and empty state','stroke paths match the native 220-unit coordinate space','correct quiz choices','mathematics retains LTR direction','lesson pages contain no media'],visualBrowserVerification:'not performed; local file navigation is blocked by browser automation policy',humanApproval:false};
  fs.writeFileSync(`${folder}/ui-validation.json`,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
})().catch(error=>{console.error(error);process.exit(1);});
