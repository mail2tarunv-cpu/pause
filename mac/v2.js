/* PAUSE Mac browser-only design interactions — no OS monitoring or secrets */
(function(){
'use strict';
const KEY='pause-mac-web-design-v1',SESSION='pause-mac-browser-session-v2';
const qs=s=>document.querySelector(s);
const escapeHTML=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function getState(){try{const s=JSON.parse(localStorage.getItem(KEY)||'null');return s&&typeof s==='object'?s:null}catch(e){return null}}
function putState(s){localStorage.setItem(KEY,JSON.stringify(s))}
let data=getState(),step=0,editId=null,session=Number(localStorage.getItem(SESSION))||0,editShown=false,setupOpen=false;
let draftApp='discord',draftLimit=30,draftGoals=['Reading'],draftTime='20:00',draftDays='Every day';
function hydrate(){const s=getState()||{};draftApp=s.watchApp||'discord';draftLimit=s.apps?.find(a=>a.id===draftApp)?.limit||30;draftGoals=[s.goals?.find(g=>g.id===s.picked)?.name||'Reading'];draftTime=s.goals?.find(g=>g.id===s.picked)?.time||'20:00';draftDays=s.goals?.find(g=>g.id===s.picked)?.days||'Every day'}
function dismiss(){setupOpen=false;editId=null;const r=qs('#setup-v2');if(r)r.remove();document.removeEventListener('keydown',onKey)}
function onKey(e){if(e.key==='Escape'&&editId!==null){dismiss()}if(e.key==='Escape'&&setupOpen){return}}
function top(label){return '<div class="row"><span class="overline">PAUSE / '+escapeHTML(label)+'</span><span class="overline">DESIGN PREVIEW</span></div>'}
const cap=(s)=>String(s||'').charAt(0).toUpperCase()+String(s||'').slice(1);
function stepMarkup(){
const s=getState()||{},appOptions=(s.apps||[]).map(a=>'<option value="'+escapeHTML(a.id)+'" '+(draftApp===a.id?'selected':'')+'>'+escapeHTML(a.name)+'</option>').join('');
const options=['Reading','Running','Sketching','Cooking','Walking','Playing music'];
return '<div class="modal-backdrop" id="setup-v2"><section class="setup-modal" role="dialog" aria-modal="true" aria-labelledby="setup-title">'+top('Setup')+
'<div class="setup-step">'+[0,1,2].map(i=>'<i class="'+(i<=step?'on':'')+'"></i>').join('')+'</div>'+
(step===0?
'<div class="setup-art"><span>PAUSE</span></div><h2 class="setup-heading" id="setup-title">A little less screen time.</h2><p class="setup-copy">Set a daily limit, then choose what you want to do instead. PAUSE tells you when you go over. You decide what happens next.</p><div class="note-box"><strong>Your Mac stays private.</strong> This web preview uses sample data. Real app tracking needs the native Mac companion.</div>':
step===1?
'<div class="setup-art"><span>YOUR LIMIT</span></div><h2 class="setup-heading" id="setup-title">Pick an app to watch.</h2><p class="setup-copy">Start with one app. You can set different limits for the others later.</p><div class="setup-controls"><div class="field"><label for="setup-app-v2">App</label><select class="input" id="setup-app-v2">'+appOptions+'</select></div><div class="field"><label for="setup-limit-v2">Daily limit</label><select class="input" id="setup-limit-v2">'+[15,20,30,45,60,90,120,180].map(v=>'<option value="'+v+'" '+(v===draftLimit?'selected':'')+'>'+v+' minutes</option>').join('')+'</select></div></div>':
'<div class="setup-art"><span>YOUR TIME</span></div><h2 class="setup-heading" id="setup-title">What do you want more time for?</h2><p class="setup-copy">Choose as many activities as you like. We’ll use your preferred time for suggestions.</p><div class="goal-choice-grid">'+options.map(name=>'<label class="goal-choice"><input type="checkbox" value="'+escapeHTML(name)+'" data-setup-goal '+(draftGoals.includes(name)?'checked':'')+'><span>'+escapeHTML(name)+'</span></label>').join('')+'</div><div class="setup-controls"><div class="field"><label for="setup-time-v2">Preferred time</label><input type="time" class="input" id="setup-time-v2" value="'+escapeHTML(draftTime)+'"></div><div class="field"><label for="setup-days-v2">Days</label><select class="input" id="setup-days-v2">'+['Every day','Weekdays','Weekends','Whenever'].map(x=>'<option '+(draftDays===x?'selected':'')+'>'+x+'</option>').join('')+'</select></div></div>')+
'<div class="setup-footer"><button class="btn" data-setup-action="'+(step===0?'skip':'back')+'">'+(step===0?'Skip setup':'Back')+'</button><button class="btn dark" data-setup-action="'+(step===2?'finish':'next')+'">'+(step===2?'Save setup':'Continue')+' <i data-lucide="arrow-right" aria-hidden="true"></i></button></div><p class="setup-save-note">You can change these choices later in Limits and My activities.</p></section></div>'}
function showSetup(){setupOpen=true;editId=null;const root=qs('#overlay-root');if(!root)return;let target=qs('#setup-v2');if(target)target.remove();root.insertAdjacentHTML('beforeend',stepMarkup());window.lucide?.createIcons?.();document.addEventListener('keydown',onKey)}
function runSetup(action){
if(action==='skip'){const s=getState();if(s){s.onboarded=true;putState(s)}dismiss();location.reload();return}
if(action==='back'){step=Math.max(0,step-1);showSetup();return}
if(action==='next'){
 if(step===1){draftApp=qs('#setup-app-v2')?.value||'discord';draftLimit=Math.min(240,Math.max(5,Number(qs('#setup-limit-v2')?.value)||30))}
 step=Math.min(2,step+1);showSetup();return
}
if(action==='finish'){
 draftGoals=Array.from(document.querySelectorAll('[data-setup-goal]:checked')).map(x=>x.value);
 draftTime=qs('#setup-time-v2')?.value||'20:00';draftDays=qs('#setup-days-v2')?.value||'Every day';
 const s=getState();if(!s)return;
 const a=s.apps?.find(x=>x.id===draftApp);if(a)a.limit=draftLimit;s.watchApp=draftApp;s.onboarded=true;
 if(!Array.isArray(s.goals))s.goals=[];
 let newFirst=null;
 for(const name of draftGoals){let g=s.goals.find(g=>g.name.toLowerCase()===name.toLowerCase());if(!g){g={id:Date.now()+Math.floor(Math.random()*10000),name,mark:'',days:draftDays,time:draftTime};s.goals.push(g)}else{g.days=draftDays;g.time=draftTime}if(!newFirst)newFirst=g.id}
 if(newFirst)s.picked=newFirst;
 putState(s);dismiss();location.reload();
 }
}
function editGoalModal(id){
const s=getState(),g=s?.goals?.find(x=>String(x.id)===String(id));if(!g)return;editId=id;setupOpen=false;const root=qs('#overlay-root');root.insertAdjacentHTML('beforeend','<div class="modal-backdrop" id="setup-v2"><form class="setup-modal" id="edit-goal-form" role="dialog" aria-modal="true" aria-labelledby="edit-goal-title">'+top('Your activities')+'<h2 class="setup-heading" id="edit-goal-title" style="margin-top:28px">Edit '+escapeHTML(g.name)+'</h2><p class="setup-copy">Change when you’d like to make time for this.</p><div class="setup-controls"><div class="field"><label for="edit-goal-name">Activity</label><input id="edit-goal-name" class="input" name="name" maxlength="32" value="'+escapeHTML(g.name)+'" required></div><div class="field"><label for="edit-goal-time">Preferred time</label><input id="edit-goal-time" class="input" name="time" type="time" value="'+escapeHTML(g.time)+'" required></div></div><div class="field"><label for="edit-goal-days">Days</label><select id="edit-goal-days" class="input" name="days">'+['Every day','Weekdays','Weekends','Whenever'].map(d=>'<option '+(g.days===d?'selected':'')+'>'+d+'</option>').join('')+'</select></div><div class="setup-footer"><button class="btn" type="button" data-setup-action="cancel-edit">Cancel</button><button class="btn dark" type="submit">Save changes</button></div></form></div>');qs('#edit-goal-name')?.focus();document.addEventListener('keydown',onKey)}
document.addEventListener('click',e=>{
const b=e.target.closest('button');
if(!b)return;
if(b.dataset.setupAction){if(b.dataset.setupAction==='cancel-edit'){dismiss();return}runSetup(b.dataset.setupAction);return}
if(b.dataset.openSetup){step=0;hydrate();showSetup();return}
if(b.dataset.editGoalV2){editGoalModal(b.dataset.editGoalV2);return}
if(b.dataset.togglePreview){const s=getState();if(!s)return;s.tracking=!s.tracking;putState(s);location.reload();return}
},true);
document.addEventListener('submit',e=>{
if(e.target.id!=='edit-goal-form')return;
e.preventDefault();const s=getState();if(!s)return;
const g=s.goals.find(x=>String(x.id)===String(editId));if(!g)return;
const f=new FormData(e.target);
g.name=String(f.get('name')||'').trim().slice(0,32)||g.name;
g.time=String(f.get('time')||'20:00');g.days=String(f.get('days')||'Every day');putState(s);dismiss();location.reload();
},true);
function enhance(){
 const main=qs('#main');if(!main)return;
 const s=getState();if(!s)return;
 const view=s.view;
 if(view==='settings'&&!main.querySelector('[data-open-setup]')){
  const prefs=main.querySelector('.surface .surface-head h3');
  if(prefs){const row=document.createElement('div');row.className='setting-row';row.innerHTML='<div><strong>Onboarding</strong><small>Edit your app limit and preferred activities.</small></div><button class="btn sm" data-open-setup="1">Edit setup</button>';prefs.closest('.surface')?.append(row)}
 }
 if(view==='hobbies'){
  main.querySelectorAll('.goal-card').forEach(card=>{
   const actions=card.querySelector('.goal-actions');
   const id=actions?.querySelector('[data-pick]')?.getAttribute('data-pick');
   if(id&&!actions.querySelector('[data-edit-goal-v2]')){
     const button=document.createElement('button');button.dataset.editGoalV2=id;button.textContent='Edit';const remove=actions.querySelector('[data-remove-goal]');actions.insertBefore(button,remove);
   }
  })
 }
 if(view==='activity'&&!main.querySelector('#mac-preview-time')){
  const intro=main.querySelector('.page-intro');if(intro){const section=document.createElement('div');section.className='note-box session-line';section.innerHTML='<div class="row"><div><strong>PAUSE browser session</strong><p style="margin:5px 0 0;font-size:11px">Measures only time spent viewing this page.</p></div><span id="mac-preview-time"></span></div><div class="row" style="margin-top:13px"><span class="overline">'+(s.tracking?'PREVIEW ACTIVE':'PREVIEW PAUSED')+'</span><button class="btn sm" data-toggle-preview="1">'+(s.tracking?'Pause':'Resume')+'</button></div>';intro.insertAdjacentElement('afterend',section)}
 }
 if(view==='overview'){
  const h=main.querySelector('.page-intro');if(h&&!main.querySelector('.prototype-banner')){const box=document.createElement('div');box.className='prototype-banner';box.textContent='Demo usage · Try adding time in Activity to test the limit alert.';h.insertAdjacentElement('afterend',box)}
 }
 if(window.lucide?.createIcons)window.lucide.createIcons();
}
let queued=false;
const observer=new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;enhance()})});
const main=qs('#main');if(main)observer.observe(main,{childList:true,subtree:false});
const nav=qs('#nav');if(nav)observer.observe(nav,{childList:true,subtree:false});
const sidebar=qs('#sidebar-hobby');if(sidebar)observer.observe(sidebar,{childList:true,subtree:false});
setTimeout(()=>{hydrate();enhance();const s=getState();if(s&&!s.onboarded){step=0;showSetup()}},70);
let last=Date.now(),lastSaved=Date.now();
setInterval(()=>{const now=Date.now(),seconds=Math.max(0,Math.min(2,(now-last)/1000));last=now;const s=getState();if(s?.tracking&&s?.onboarded&&!document.hidden){session+=seconds;const t=qs('#mac-preview-time');if(t)t.textContent=Math.floor(session/60)+'m '+Math.floor(session%60)+'s';if(now-lastSaved>10000){localStorage.setItem(SESSION,String(Math.floor(session)));lastSaved=now}}},1000);
document.addEventListener('visibilitychange',()=>{last=Date.now();localStorage.setItem(SESSION,String(Math.floor(session)))});
window.addEventListener('beforeunload',()=>{localStorage.setItem(SESSION,String(Math.floor(session)))});
})();
