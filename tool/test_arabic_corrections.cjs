const fs=require('node:fs');
const assert=require('node:assert/strict');
const {JSDOM,VirtualConsole}=require('../tmp/arabic-review-test/node_modules/jsdom');
const folder=process.argv[2]||'docs/qa/arabic-corrections';
let plays=0,network=0,download;
function load(saved={}) {
  const errors=[],console=new VirtualConsole();console.on('jsdomError',e=>errors.push(e.message));
  const dom=new JSDOM(fs.readFileSync(folder+'/index.html','utf8'),{url:'https://review.example.test/',runScripts:'dangerously',virtualConsole:console,beforeParse(w){
    w.HTMLMediaElement.prototype.play=()=>{plays++;throw Error('Audio playback prohibited')};w.HTMLMediaElement.prototype.pause=()=>{};
    w.fetch=()=>{network++;throw Error('Network prohibited')};w.URL.createObjectURL=b=>{download=b;return 'blob:test'};w.URL.revokeObjectURL=()=>{};w.HTMLAnchorElement.prototype.click=()=>{};
    for(const [key,value] of Object.entries(saved))w.localStorage.setItem(key,value);
  }});dom.errors=errors;return dom;
}
function event(dom,element,type='change'){element.dispatchEvent(new dom.window.Event(type,{bubbles:true}))}
(async()=>{
  const initial=load(),data=JSON.parse(initial.window.document.getElementById('review-data').textContent),count=data.recordings.length;
  const imported=(data.importedReview?.recordings||[]).filter(r=>r.decision==='correct').length;
  assert.equal(initial.window.document.querySelectorAll('input[value=correct]:checked').length,imported);
  const blank=Object.fromEntries(data.recordings.map(r=>[r.file,{sha256:r.sha256,decision:null,notes:''}]));
  const dom=load({[data.storageKey]:JSON.stringify(blank)}),doc=dom.window.document;
  initial.window.close();
  assert.ok([55,11,3,1].includes(count));assert.equal(doc.querySelectorAll('article').length,count);
  assert.equal(doc.querySelectorAll('audio').length,count*2);assert.equal(doc.querySelectorAll('[autoplay]').length,0);
  for(const audio of doc.querySelectorAll('audio')){assert.equal(audio.preload,'none');assert.ok(audio.getAttribute('aria-label'))}
  const first=doc.querySelector('article'),correct=first.querySelector('[value=correct]');correct.checked=true;event(dom,correct);
  const note=first.querySelector('textarea');note.value='Native review: correct';event(dom,note,'input');
  const second=doc.querySelectorAll('article')[1];
  if(second){const wrong=second.querySelector('[value=wrong]');wrong.checked=true;event(dom,wrong)}
  assert.match(doc.getElementById('status').textContent,new RegExp((second?'2':'1')+' of '+count+' reviewed · '+(second?'1':'0')+' still wrong'));
  const filter=doc.getElementById('filter');filter.value='wrong';event(dom,filter);
  assert.equal([...doc.querySelectorAll('article')].filter(x=>!x.hidden).length,second?1:0);
  const search=doc.getElementById('search');search.value='not-a-real-clip';event(dom,search,'input');assert.equal(doc.getElementById('empty').hidden,false);
  const saved=Object.fromEntries(Object.keys(dom.window.localStorage).map(k=>[k,dom.window.localStorage.getItem(k)]));
  doc.getElementById('export').click();
  const text=await new Promise(resolve=>{const reader=new dom.window.FileReader();reader.onload=()=>resolve(reader.result);reader.readAsText(download)});
  const report=JSON.parse(text);assert.equal(report.recordings.length,count);assert.equal(report.recordings[0].decision,'correct');if(second)assert.equal(report.recordings[1].decision,'wrong');assert.equal(report.recordings[0].notes,'Native review: correct');
  if(count>=3)assert.equal(report.recordings[2].decision,null);assert.equal(report.recordings[0].sha256,data.recordings[0].sha256);
  const reopened=load(saved);assert.equal(reopened.window.document.querySelector('input[value=correct]').checked,true);
  const key=Object.keys(saved)[0],stale=JSON.parse(saved[key]);stale[data.recordings[0].file].sha256='obsolete';
  const changed=load({[key]:JSON.stringify(stale)});assert.equal(changed.window.document.querySelector('input[value=correct]').checked,false);assert.equal(changed.window.document.querySelector('textarea').value,'Native review: correct');
  assert.equal(plays,0);assert.equal(network,0);assert.deepEqual(dom.errors,[]);assert.deepEqual(reopened.errors,[]);assert.deepEqual(changed.errors,[]);
  dom.window.close();reopened.window.close();changed.window.close();
  const result={passed:true,recordings:count,comparisonPlayers:count*2,importedApprovalsShown:imported,approvalRequiresExplicitSelection:true,staleApprovalCleared:true,notesRetained:true,filtersAndExportVerified:true,playbackCalls:plays,networkCalls:network};
  fs.writeFileSync(folder+'/review-ui-validation.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
})().catch(e=>{console.error(e);process.exit(1)});
