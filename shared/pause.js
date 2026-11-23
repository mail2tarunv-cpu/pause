(function pauseExperience(){
"use strict";
const device=document.body.dataset.device==="phone"?"phone":"mac";
const KEY="pause-experience-v3";
const root=document.getElementById("app");
const dialogRoot=document.getElementById("dialog-root");
const announcer=document.getElementById("status");
const catalog=[
{id:"discord",name:"Discord",icon:"message-circle",minutes:40,limit:30,enabled:true,selected:true},
{id:"instagram",name:"Instagram",icon:"instagram",minutes:24,limit:45,enabled:true,selected:true},
{id:"youtube",name:"YouTube",icon:"youtube",minutes:38,limit:60,enabled:false,selected:false},
{id:"figma",name:"Figma",icon:"figma",minutes:102,limit:90,enabled:false,selected:false},
{id:"chrome",name:"Chrome",icon:"chrome",minutes:64,limit:60,enabled:false,selected:false}
];
const start=()=>({
version:3,onboarded:false,view:"today",period:"day",reminders:true,paused:false,
quietStart:"22:00",quietEnd:"08:00",apps:catalog.map(x=>({...x})),
activities:[{id:"read",name:"Reading",time:"20:00",days:"Every day",selected:true},{id:"walk",name:"Walking",time:"17:00",days:"Weekends",selected:true}],
choice:null,boardReminders:false
});
function parse(t){try{return JSON.parse(t)}catch{return null}}
function mins(time){
if(typeof time!=="string")return"20:00";
const m=time.trim().match(/^(\d{1,2}):(\d{2})\s*(am|pm)?$/i);
if(!m)return"20:00";
let h=Number(m[1]);
if(m[3])h=h%12+(m[3].toLowerCase()==="pm"?12:0);
return String(Math.min(23,h)).padStart(2,"0")+":"+m[2];
}
function migrate(){
const prev=parse(localStorage.getItem(device==="phone"?"pause.phone.prototype.v1":"pause-mac-web-design-v1"));
if(!prev)return start();
const s=start();s.onboarded=Boolean(prev.onboarded);
const oldApps=Array.isArray(prev.apps)?prev.apps:Array.isArray(prev.rules)?prev.rules:[];
for(const a of s.apps){const old=oldApps.find(x=>(x.id||String(x.app||"").toLowerCase())===a.id);if(!old)continue;
a.selected=old.selected??true;a.enabled=old.enabled??old.on??true;
a.limit=Math.max(5,Math.min(240,Number(old.limit)||a.limit));a.minutes=Number(old.minutes??prev.usage?.[a.name]??a.minutes);}
const oldGoals=Array.isArray(prev.activities)?prev.activities:Array.isArray(prev.goals)?prev.goals:Array.isArray(prev.hobbies)?prev.hobbies:[];
if(oldGoals.length){s.activities=oldGoals.filter(g=>g.name).slice(0,12).map((g,i)=>({id:String(g.id??`import-${i}`),name:String(g.name).slice(0,36),time:mins(g.time),days:g.days||"Every day",selected:true}));}
s.reminders=prev.reminders??prev.enabled??true;s.paused=prev.tracking===false;
return s;
}
let state=parse(localStorage.getItem(KEY))||migrate();
state={...start(),...state};
if(!Array.isArray(state.apps)||!state.apps.length)state.apps=start().apps;
if(!Array.isArray(state.activities))state.activities=start().activities;
state.view=["today","plan","settings","activity"].includes(state.view)?state.view:"today";
let step=0;
let modal=null;
let modalFocus=null;
let feedbackReason="bad-timing";
let alternateId=null;
const icon=name=>`<i data-lucide="${name}" aria-hidden="true"></i>`;
const esc=v=>String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const selectedApps=()=>state.apps.filter(a=>a.selected);
const activeHobbies=()=>state.activities.filter(a=>a.selected);
const getApp=id=>state.apps.find(a=>a.id===id);
const getHobby=id=>state.activities.find(a=>a.id===id);
const total=()=>selectedApps().reduce((sum,a)=>sum+Number(a.minutes||0),0);
const fmt=n=>n<60?Math.round(n)+"m":Math.floor(n/60)+"h "+String(Math.round(n%60)).padStart(2,"0")+"m";
const niceTime=t=>{const parts=mins(t).split(":").map(Number);return (parts[0]%12||12)+(parts[1]?":"+String(parts[1]).padStart(2,"0"):"")+(parts[0]>=12?" PM":" AM")};
const currentDate=()=>new Date().toLocaleDateString("en-US",{weekday:"long",month:"long",day:"numeric"});
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(state))}catch{}};
function announce(t){announcer.textContent="";requestAnimationFrame(()=>announcer.textContent=t);}
function navButton(view,label,ico){
return `<button type="button" class="nav-link" data-view="${view}" aria-current="${state.view===view?"page":"false"}">${icon(ico)}<span class="nav-text">${label}</span></button>`;
}
function statusTag(){
return `<span class="status-tag" aria-label="Sample data, ${state.paused?"reminder previews paused":"reminder previews enabled"}"><span class="status-dot ${state.paused?"dim":""}"></span>${state.paused?"Preview paused":"Sample activity"}</span>`;
}
function shell(content){
const brand=`<a class="brand" href="${device==="phone"?"/phone/":"/mac/"}" data-view="today"><span class="brand-mark">P.</span><span class="brand-word">PAUSE</span></a>`;
const nav=`${navButton("today","Today","house")}${navButton("plan","My plan","calendar-days")}${navButton("settings","Settings","settings")}`;
if(device==="phone")return `<div class="phone-shell"><header class="topbar">${brand}<div class="topbar-right">${statusTag()}</div></header><main class="main" id="main" tabindex="-1">${content}</main><nav class="phone-bottom" aria-label="Main navigation">${nav}</nav></div>`;
return `<div class="app-layout"><aside class="sidebar">${brand}<div class="side-label">Workspace</div><nav class="nav" aria-label="Main navigation">${nav}</nav><div class="side-footer"><div class="side-note">Design preview · App usage is illustrative, not measured from this computer.</div><a href="/phone/" target="_blank" rel="noopener">View mobile version</a></div></aside><div class="workspace"><header class="topbar"><div class="topbar-left">PAUSE <span aria-hidden="true">/</span> <span class="current">${state.view==="today"?"Today":state.view==="plan"?"My plan":state.view==="activity"?"Activity":"Settings"}</span></div><div class="topbar-right">${statusTag()}</div></header><main class="main" id="main" tabindex="-1">${content}</main></div></div>`;
}
function header(title,desc,action=""){
return `<div class="page-heading"><div><h1>${title}</h1>${desc?`<p class="subtitle">${desc}</p>`:""}</div>${action}</div>`;
}
function appIcon(a){return `<span class="app-icon">${icon(a.icon||"app-window")}</span>`;}
function meter(a){
const value=Math.max(0,a.limit)?Math.min(100,Number(a.minutes||0)/a.limit*100):0;
return `<div class="track" role="meter" aria-label="${esc(a.name)} usage" aria-valuemin="0" aria-valuemax="${Math.max(a.minutes,a.limit)}" aria-valuenow="${a.minutes}" aria-valuetext="${a.minutes} of ${a.limit} minutes"><span class="${a.enabled&&a.minutes>a.limit?"over":""}" style="width:${value}%"></span></div>`;
}
function usageRow(a){
const exceeded=a.enabled&&a.minutes>a.limit;
return `<div class="usage-row">${appIcon(a)}<div class="row-main"><span class="row-title">${esc(a.name)}</span>${meter(a)}<span class="row-detail">${a.minutes} of ${a.limit} min today${!a.enabled?" · Reminder off":""}</span></div><div class="usage-value">${fmt(a.minutes)}${exceeded?`<span class="over">${a.minutes-a.limit}m over</span>`:""}</div></div>`;
}
function chart(period="day"){
const data=period==="week"?[54,78,63,92,80,45,36]:[3,9,5,11,18,29,35,22,48,43,26,32,50,37,45,56,39,25,33,17,8,6,4,2];
const mx=Math.max(...data);
return `<div class="usage-chart" role="img" aria-label="Illustrative ${period==="week"?"weekly":"hourly"} usage bar chart, sample activity only">${data.map((v,i)=>`<span class="usage-bar ${i>=6&&i<=18?"active":""} ${i===(period==="week"?3:15)?"over":""}" style="height:${Math.max(5,v/mx*100)}%"></span>`).join("")}</div><div class="chart-axis"><span>${period==="week"?"Mon":"12 AM"}</span><span>${period==="week"?"Thu":"12 PM"}</span><span>${period==="week"?"Sun":"11 PM"}</span></div>`;
}
function nextHobby(){
const arr=activeHobbies();if(!arr.length)return null;
const now=new Date(),weekday=now.getDay(),minutes=now.getHours()*60+now.getMinutes();
const offset=h=>{
const [hour,min]=mins(h.time).split(":").map(Number),time=hour*60+min;
for(let day=0;day<=7;day++){
const d=(weekday+day)%7;
const valid=h.days==="Weekends"?(d===0||d===6):h.days==="Weekdays"?(d>=1&&d<=5):true;
if(valid&&(day>0||time>=minutes))return day*1440+time-minutes;
}
return 10080;
};
return [...arr].sort((a,b)=>offset(a)-offset(b))[0];
}
function choiceBanner(){
const c=state.choice;if(!c)return"";
if(c.until&&Date.now()>=c.until){state.choice=null;save();return""}
const msg=c.kind==="break"?"Taking a break":c.kind==="snooze"?"15-minute extension":c.kind==="dismiss"?"Not today":"Reminders paused";
const detail=c.kind==="break"?"Check-ins are quiet for 30 minutes. You can return sooner.":c.until?`Until ${new Date(c.until).toLocaleTimeString("en-US",{hour:"numeric",minute:"2-digit"})}. Your daily limit is unchanged.`:"You can resume whenever you like.";
return `<div class="preview-banner" role="status"><span><strong>${msg}</strong> · ${detail}</span><button class="text-action" data-action="undo">Undo ${icon("undo-2")}</button></div>`;
}
function today(){
const hobby=nextHobby();const apps=selectedApps();
const over=apps.filter(a=>a.enabled&&a.minutes>a.limit);
return header("Today",currentDate())+choiceBanner()+
`<div class="hero-grid">
<section class="card pad hero-usage" aria-label="Screen time overview">
<div class="section-heading"><h2>Selected app time</h2><span class="small-mono">TODAY</span></div>
<div class="hero-numbers"><span class="total-time">${fmt(total())}</span></div>
<p class="hero-meta">${apps.length} selected app${apps.length===1?"":"s"} · Sample activity</p>
${chart("day")}
<button class="text-action" data-view="activity" style="margin-top:10px;align-self:flex-start">View activity ${icon("arrow-up-right")}</button>
</section>
<section class="card pad hero-hobby" aria-label="Upcoming activity">
<span class="eyebrow">YOUR NEXT ACTIVITY</span>
<h2 class="hobby-title">${hobby?esc(hobby.name):"Make time for something else"}</h2>
<p class="hobby-info">${hobby?`${esc(hobby.days)} · ${niceTime(hobby.time)}`:"Add something you want to spend time doing."}</p>
<button class="btn secondary hobby-action" data-view="plan">Edit my plan ${icon("arrow-up-right")}</button>
</section></div>
<section class="card pad"><div class="section-heading"><h2>App limits</h2><button class="text-action" data-view="plan">Manage ${icon("arrow-right")}</button></div>
${apps.length?`<div class="usage-list">${apps.map(usageRow).join("")}</div>`:`<div class="empty-state"><h3>No apps selected</h3><p>Add an app to start seeing its daily limit.</p><button class="btn secondary" style="margin-top:16px" data-view="plan">Set an app limit</button></div>`}
${over.length&&!state.choice?`<button class="btn tertiary" data-action="reminder" data-id="${over[0].id}" style="margin-top:19px">View today's reminder ${icon("arrow-right")}</button>`:""}
</section>
<p class="footer-note">Sample app activity for design testing. Real tracking requires the native app and device permission.</p>`;
}
function activity(){
const apps=selectedApps();const max=apps.length?apps.reduce((a,b)=>a.minutes>b.minutes?a:b):null;
return header("Activity","Sample usage for your selected apps",`<button class="btn secondary" data-view="today">${icon("arrow-left")} Today</button>`)+
`<div class="kpi-grid"><div class="card kpi"><span class="eyebrow">SELECTED APP TIME</span><strong>${fmt(total())}</strong></div><div class="card kpi"><span class="eyebrow">MOST USED</span><strong>${max?esc(max.name):"None"}</strong></div></div>
<section class="card pad">
<div class="metric-head"><h2>Usage over time</h2><div class="tabs" role="group" aria-label="Activity period">
<button data-period="day" aria-pressed="${state.period==="day"}">Day</button>
<button data-period="week" aria-pressed="${state.period==="week"}">Week</button></div></div>
${chart(state.period)}<p class="footer-note">Illustrative distribution, not recorded device history.</p>
</section>
<section class="card pad spaced"><div class="section-heading"><h2>By app</h2></div><div class="usage-list">${apps.map(usageRow).join("")||`<p class="inline-helper">No apps selected.</p>`}</div></section>`;
}
function plan(){
const apps=selectedApps();const hobbies=activeHobbies();
return header("My plan","What to limit, and what to make time for")+
`<section class="card pad plan-block">
<div class="section-heading"><h2>Daily app limits</h2><button class="text-action" data-action="add-app">${icon("plus")} Add app</button></div>
${apps.length?apps.map(a=>`<div class="plan-item">${appIcon(a)}<div><strong class="row-title">${esc(a.name)}</strong><span class="row-detail">${a.limit} minutes a day · ${a.enabled?"On":"Off"}</span></div><button class="icon-button" aria-label="Edit ${esc(a.name)} limit" data-action="edit-app" data-id="${a.id}">${icon("pencil")}</button></div>`).join(""):`<p class="inline-helper">No app limits set.</p>`}
</section>
<section class="card pad">
<div class="section-heading"><h2>Activities</h2><button class="text-action" data-action="add-hobby">${icon("plus")} Add activity</button></div>
${hobbies.length?hobbies.map(h=>`<div class="plan-item"><span class="app-icon">${icon("book-open")}</span><div><strong class="row-title">${esc(h.name)}</strong><span class="row-detail">${esc(h.days)} · ${niceTime(h.time)}</span></div><button class="icon-button" aria-label="Edit ${esc(h.name)}" data-action="edit-hobby" data-id="${esc(h.id)}">${icon("pencil")}</button></div>`).join(""):`<p class="inline-helper">Add a hobby, a short break, or simply time to rest.</p>`}
</section>
<p class="footer-note">You can change your plan whenever you like. PAUSE never blocks an app or assumes you completed an activity.</p>`;
}
function settings(){
return header("Settings","Only the controls you need")+
`<div class="two-col">
<section class="card pad"><h2 style="margin-bottom:12px">Reminders</h2><div class="settings-list">
<div class="settings-row"><div class="settings-copy"><strong>Reminders</strong><p>Show a check-in when you reach an app limit.</p></div><button class="switch" role="switch" aria-label="Reminders" aria-checked="${state.reminders}" data-action="toggle-reminders"></button></div>
<div class="settings-row"><div class="settings-copy"><strong>Pause reminders</strong><p>Stop check-ins without changing your limits.</p></div><button class="switch" role="switch" aria-label="Pause reminders" aria-checked="${state.paused}" data-action="toggle-pause"></button></div>
<div class="settings-row"><div class="settings-copy"><strong>Quiet hours</strong><p>No check-ins during these times.</p></div><button class="icon-button" data-action="quiet" aria-label="Edit quiet hours">${icon("pencil")}</button></div>
<div class="settings-row"><div class="settings-copy"><strong>Quiet from</strong><p>${niceTime(state.quietStart)} to ${niceTime(state.quietEnd)}</p></div><span>${icon("moon")}</span></div>
</div></section>
<section class="card pad"><h2 style="margin-bottom:12px">Devices and privacy</h2><div class="settings-list">
<div class="settings-row"><div class="settings-copy"><strong>Tracking</strong><p>Browser preview uses sample data. Real tracking runs only in the native apps.</p></div><span class="small-mono">DEMO</span></div>
<div class="settings-row"><div class="settings-copy"><strong>Ambient board</strong><p>Open the digital split-flap display. No device is paired in this preview.</p></div><a class="icon-button" href="/" target="_blank" rel="noopener" aria-label="Open ambient board in new tab">${icon("arrow-up-right")}</a></div>
<div class="settings-row"><div class="settings-copy"><strong>Review onboarding</strong><p>Update the apps and activities you started with.</p></div><button class="icon-button" data-action="setup" aria-label="Review onboarding">${icon("arrow-up-right")}</button></div>
</div></section></div>
<details class="card pad spaced"><summary style="cursor:pointer;font-weight:650;min-height:44px">Preview tools</summary>
<p class="detail-intro">For design testing only. These controls change sample data in this browser.</p>
<div class="btn-group"><button class="btn secondary" data-action="add-time">Add 10 minutes to Discord</button><button class="btn secondary" data-action="reminder" data-id="discord">Preview reminder</button><button class="btn ghost" data-action="reset">Reset demo</button></div>
</details>
<p class="footer-note">Preferences are stored in this browser. No account, cloud sync or other-app monitoring is active here.</p>`;
}
function onboarding(){
const steps=["Welcome","Choose apps","Set limits","Choose activities","Review"];
let body="";
if(step===0)body=`<h1 class="onboarding-title">A little less screen.<br>More life.</h1><p class="onboarding-intro">Set limits for the apps that tend to run long. PAUSE will let you know when you've passed one and suggest something you'd rather be doing.</p><div class="note"><strong>You're in a preview.</strong> This website uses sample activity. Real app tracking requires the native Mac or iPhone app.</div>`;
if(step===1)body=`<h1 class="onboarding-title">Which apps run long?</h1><p class="onboarding-intro">Choose where a reminder would be useful. You can change this later.</p><div class="card pad">${state.apps.map(a=>`<label class="onboard-choice"><input type="checkbox" data-onboard-app="${a.id}" ${a.selected?"checked":""}><span class="app-icon">${icon(a.icon)}</span><span>${esc(a.name)}</span></label>`).join("")}</div>`;
if(step===2)body=`<h1 class="onboarding-title">Set your daily limits.</h1><p class="onboarding-intro">These trigger a reminder, never a lockout.</p><div class="card pad">${selectedApps().map(a=>`<div class="onboard-limit">${appIcon(a)}<span class="row-title">${esc(a.name)}</span><div class="form-field"><label class="sr-only" for="onboard-limit-${a.id}">Limit for ${esc(a.name)}</label><select id="onboard-limit-${a.id}" data-onboard-limit="${a.id}">${[15,20,30,45,60,90,120,180,240].map(n=>`<option value="${n}" ${a.limit===n?"selected":""}>${n} min</option>`).join("")}</select></div></div>`).join("")}</div>`;
if(step===3)body=`<h1 class="onboarding-title">What would you rather do?</h1><p class="onboarding-intro">Choose activities you want to make time for. Rest counts, too.</p><div class="activity-pills">${state.activities.map(a=>`<button class="activity-pill" data-onboard-hobby="${esc(a.id)}" aria-pressed="${a.selected}">${icon(a.name==="Reading"?"book-open":"footprints")}${esc(a.name)}</button>`).join("")}</div><div class="card pad">${activeHobbies().length?activeHobbies().map(a=>`<div class="schedule-row"><strong class="schedule-name">${esc(a.name)}</strong><div class="form-field"><label for="onboard-time-${esc(a.id)}">Time</label><input type="time" id="onboard-time-${esc(a.id)}" value="${esc(a.time)}" data-onboard-time="${esc(a.id)}"></div><div class="form-field"><label for="onboard-days-${esc(a.id)}">Days</label><select id="onboard-days-${esc(a.id)}" data-onboard-days="${esc(a.id)}">${["Every day","Weekdays","Weekends","Whenever"].map(x=>`<option ${a.days===x?"selected":""}>${x}</option>`).join("")}</select></div></div>`).join(""):`<p class="inline-helper">No activities chosen. You can add one later.</p>`}</div><p class="footer-note">More activities can be added in My plan.</p>`;
if(step===4)body=`<h1 class="onboarding-title">Your starting plan.</h1><p class="onboarding-intro">Check the basics. Everything stays editable.</p><div class="card pad review-list"><div class="review-item"><strong>App limits</strong><p>${selectedApps().map(a=>esc(a.name)+" · "+a.limit+" min/day").join(" · ")||"None selected"}</p></div><div class="review-item"><strong>Activities</strong><p>${activeHobbies().map(a=>esc(a.name)+" · "+niceTime(a.time)).join(" · ")||"None yet"}</p></div><div class="review-item"><strong>Reminders</strong><p>Optional, non-blocking check-ins with Undo.</p></div></div>`;
return `<div class="${device==="phone"?"phone-shell":""}"><div class="onboarding-shell">
<div class="brand"><span class="brand-mark">P.</span><span class="brand-word">PAUSE</span></div>
<div class="step-top"><span class="eyebrow">${steps[step]}</span><span class="small-mono">${step+1} / ${steps.length}</span></div>
<div class="step-bars" aria-label="Setup progress, step ${step+1} of ${steps.length}">${steps.map((_,i)=>`<span class="${i<=step?"done":""}"></span>`).join("")}</div>
${body}
<div class="onboard-footer"><button class="btn secondary" data-action="${step===0?"skip":"back"}">${step===0?"Explore demo":"Back"}</button><button class="btn" data-action="${step===4?"finish":"next"}">${step===4?"Start PAUSE":"Continue"} ${icon("arrow-right")}</button></div>
</div></div>`;
}
function dialogShell(title,body,form=false){
return `<div class="dialog-backdrop"><section class="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><div class="dialog-header"><h2 id="dialog-title">${esc(title)}</h2><button type="button" class="icon-button" data-action="close" aria-label="Close dialog">${icon("x")}</button></div>${body}</section></div>`;
}
function editAppDialog(add){
const app=add?state.apps.find(a=>!a.selected)||null:getApp(modal.id);
if(!app)return dialogShell("No more apps",`<p>All demo apps already have a limit.</p>`);
const picker=add?`<div class="form-field"><label for="edit-app-id">App</label><select id="edit-app-id" name="appId">${state.apps.filter(a=>!a.selected).map(a=>`<option value="${a.id}">${esc(a.name)}</option>`).join("")}</select></div>`:`<input type="hidden" name="appId" value="${esc(app.id)}">`;
return dialogShell(add?"Add an app limit":"Edit "+app.name,`<form id="app-form">${picker}
<div class="form-field"><label for="edit-limit">Daily limit in minutes</label><input type="number" id="edit-limit" name="limit" required min="5" max="240" step="5" value="${app.limit}"><small>PAUSE will remind you, not block the app.</small></div>
<label style="display:flex;align-items:center;gap:10px;font-size:.84rem"><input type="checkbox" name="enabled" ${app.enabled?"checked":""} style="width:20px;height:20px;accent-color:#30382F"> Enable reminders for this app</label>
<div class="dialog-actions">${!add?`<button class="btn ghost" type="button" data-action="remove-app" data-id="${app.id}">Remove</button>`:""}<button class="btn secondary" data-action="close" type="button">Cancel</button><button class="btn" type="submit">Save limit</button></div>
</form>`,true);
}
function editHobbyDialog(add){
const hobby=add?{id:"",name:"",time:"20:00",days:"Every day"}:getHobby(modal.id);
if(!hobby)return"";
return dialogShell(add?"Add an activity":"Edit "+hobby.name,`<form id="hobby-form"><div class="form-field"><label for="hobby-name">Activity</label><input id="hobby-name" name="name" maxlength="36" required placeholder="Reading, cooking, resting..." value="${esc(hobby.name)}"></div>
<div class="form-grid"><div class="form-field"><label for="hobby-time">Preferred time</label><input type="time" name="time" id="hobby-time" value="${esc(mins(hobby.time))}" required></div>
<div class="form-field"><label for="hobby-days">Preferred days</label><select id="hobby-days" name="days">${["Every day","Weekdays","Weekends","Whenever"].map(x=>`<option ${hobby.days===x?"selected":""}>${x}</option>`).join("")}</select></div></div>
<div class="dialog-actions">${!add?`<button type="button" class="btn ghost" data-action="remove-hobby" data-id="${esc(hobby.id)}">Remove</button>`:""}<button class="btn secondary" data-action="close" type="button">Cancel</button><button class="btn" type="submit">Save activity</button></div>
</form>`,true);
}
function quietDialog(){
return dialogShell("Quiet hours",`<p>PAUSE will not show check-ins during these times.</p><form id="quiet-form"><div class="form-grid"><div class="form-field"><label for="quiet-start">Start</label><input id="quiet-start" name="start" type="time" value="${esc(state.quietStart)}" required></div><div class="form-field"><label for="quiet-end">End</label><input id="quiet-end" name="end" type="time" value="${esc(state.quietEnd)}" required></div></div><div class="dialog-actions"><button type="button" class="btn secondary" data-action="close">Cancel</button><button class="btn" type="submit">Save</button></div></form>`);
}
function reminderDialog(){
const app=getApp(modal.id)||selectedApps()[0]||state.apps[0],hobby=getHobby(alternateId)||nextHobby();
return dialogShell("A little PAUSE?",`<p>${esc(app.name)} has reached ${app.minutes} minutes today. Your limit is ${app.limit} minutes.</p>
<div class="reminder-number">${app.minutes}<span> / ${app.limit} min</span></div>${meter(app)}
<div class="reminder-hobby"><span class="app-icon">${icon("book-open")}</span><div><strong>${hobby?esc(hobby.name):"Take a short break"}</strong><p>${hobby?`You chose ${esc(hobby.days.toLowerCase())} around ${niceTime(hobby.time)}.`:"You can step away when you're ready."}</p></div></div>
<div class="reminder-actions"><button class="btn full" data-action="take-break">Take a break ${icon("arrow-right")}</button><button class="btn secondary full" data-action="snooze">15 more minutes</button><button class="btn ghost full" data-action="dismiss">Not today</button></div>
<div class="reminder-links"><button data-action="alternatives">Another activity</button><button data-action="feedback">Not helpful</button></div>`);
}
function alternativesDialog(){
const hobbies=activeHobbies();return dialogShell("Choose another activity",`<p>What would you rather make time for?</p><div class="reminder-actions">${hobbies.map(h=>`<button class="btn secondary full" data-action="choose-alternative" data-id="${esc(h.id)}">${esc(h.name)} · ${niceTime(h.time)}</button>`).join("")||`<p>Add an activity in My plan to get a personalised suggestion.</p>`}<button class="btn ghost full" data-action="reminder" data-id="${esc(modal.appId||"discord")}">Back</button></div>`);
}
function feedbackDialog(){
return dialogShell("What didn't work?",`<p>Tell PAUSE what to change for this reminder. Your usual limit stays the same unless you edit it.</p><div class="reminder-actions"><button class="btn secondary full" data-action="feedback-reason" data-id="intentional">I'm using this app intentionally</button><button class="btn secondary full" data-action="feedback-reason" data-id="bad-timing">Bad timing</button><button class="btn secondary full" data-action="feedback-reason" data-id="other">I'd rather do something else</button></div>`);
}
function approvalDialog(){
return dialogShell("Pause reminders for 45 minutes?",`<p>${feedbackReason==="intentional"?"Got it. This session can continue without another check-in.":feedbackReason==="other"?"No problem. You can choose another activity next time.":"We can leave you alone for a while."} Your daily limit will stay the same.</p><div class="dialog-actions"><button class="btn secondary" data-action="close">Keep current</button><button class="btn" data-action="approve-pause">Pause reminders</button></div>`);
}
function renderDialog(){
document.body.style.overflow=modal?"hidden":"";
if(!modal){dialogRoot.innerHTML="";if(modalFocus instanceof HTMLElement&&document.contains(modalFocus))modalFocus.focus();modalFocus=null;return;}
let html="";
if(modal.type==="add-app"||modal.type==="edit-app")html=editAppDialog(modal.type==="add-app");
if(modal.type==="add-hobby"||modal.type==="edit-hobby")html=editHobbyDialog(modal.type==="add-hobby");
if(modal.type==="quiet")html=quietDialog();
if(modal.type==="reminder")html=reminderDialog();
if(modal.type==="alternatives")html=alternativesDialog();
if(modal.type==="feedback")html=feedbackDialog();
if(modal.type==="approval")html=approvalDialog();
dialogRoot.innerHTML=html;
iconRefresh();const first=dialogRoot.querySelector("input:not([type=hidden]),select,button");if(first)first.focus();
}
function iconRefresh(){try{window.lucide?.createIcons?.()}catch{}}
function render(focus=false){
root.innerHTML=state.onboarded?shell(state.view==="today"?today():state.view==="activity"?activity():state.view==="plan"?plan():settings()):onboarding();
save();iconRefresh();
if(focus){const heading=root.querySelector("h1");if(heading){heading.setAttribute("tabindex","-1");heading.focus({preventScroll:true});}}
}
function showModal(type,id=null){modalFocus=document.activeElement;modal={type,id};renderDialog();}
function closeModal(){modal=null;alternateId=null;renderDialog();}
function navigate(view){if(!["today","plan","settings","activity"].includes(view))return;state.view=view;render(true);window.scrollTo?.(0,0);}
function finishChoice(kind,id){
const until=kind==="snooze"?Date.now()+15*60*1000:kind==="dismiss"?new Date().setHours(23,59,59,999):kind==="pause"?Date.now()+45*60*1000:kind==="break"?Date.now()+30*60*1000:null;
state.choice={kind,appId:id,until};closeModal();navigate("today");
announce(kind==="break"?"Break selected. Reminders are quiet.":kind==="snooze"?"Reminders paused for 15 minutes.":kind==="dismiss"?"No more reminders for this app today.":"Reminders paused for 45 minutes.");
}
function withinQuiet(){
const [sh,sm]=state.quietStart.split(":").map(Number),[eh,em]=state.quietEnd.split(":").map(Number);
const d=new Date(),n=d.getHours()*60+d.getMinutes(),a=sh*60+sm,b=eh*60+em;
return a===b?false:a<b?n>=a&&n<b:n>=a||n<b;
}
function canAlert(app){
const c=state.choice;if(c&&(!c.until||c.until>Date.now())&&(c.kind==="break"||c.kind==="pause"||c.appId===app?.id))return false;
return state.reminders&&!state.paused&&!withinQuiet()&&app?.selected&&app?.enabled&&app.minutes>=app.limit;
}
function act(action,id,button){
if(action==="skip"){state.onboarded=true;state.view="today";announce("Demo started.");render(true);return;}
if(action==="back"){step=Math.max(0,step-1);render(true);return;}
if(action==="next"){
if(step===1&&!selectedApps().length){announce("Select at least one app or explore the demo.");return}
step=Math.min(4,step+1);render(true);return;}
if(action==="finish"){state.onboarded=true;state.view="today";step=0;render(true);announce("Your plan is ready.");return;}
if(action==="setup"){step=0;state.onboarded=false;closeModal();render(true);return;}
if(action==="add-app"||action==="edit-app"||action==="add-hobby"||action==="edit-hobby"||action==="quiet"){showModal(action,id);return}
if(action==="close"){closeModal();return}
if(action==="reminder"){if(modal?.type==="alternatives"){modal={type:"reminder",id};renderDialog();return}alternateId=null;showModal("reminder",id||selectedApps().find(a=>a.enabled&&a.minutes>=a.limit)?.id||"discord");return}
if(action==="alternatives"){const appId=modal?.id||"discord";modal={type:"alternatives",appId};renderDialog();return}
if(action==="choose-alternative"){const appId=modal?.appId||"discord";alternateId=id;modal={type:"reminder",id:appId};renderDialog();return}
if(action==="feedback"){modal={type:"feedback",appId:modal?.id||"discord"};renderDialog();return}
if(action==="feedback-reason"){feedbackReason=id;modal={type:"approval",appId:modal?.appId||"discord"};renderDialog();return}
if(action==="approve-pause"){finishChoice("pause",modal?.appId);return}
if(action==="take-break"){finishChoice("break",modal?.id);return}
if(action==="snooze"){finishChoice("snooze",modal?.id);return}
if(action==="dismiss"){finishChoice("dismiss",modal?.id);return}
if(action==="undo"){state.choice=null;render();announce("Previous reminder settings restored.");return}
if(action==="toggle-reminders"){state.reminders=!state.reminders;render();announce(state.reminders?"Reminders on.":"Reminders off.");return}
if(action==="toggle-pause"){state.paused=!state.paused;render();announce(state.paused?"Reminder previews paused.":"Reminder previews resumed.");return}
if(action==="remove-app"){const a=getApp(id);if(a){a.selected=false;closeModal();render();announce(a.name+" removed from your plan.");}return}
if(action==="remove-hobby"){state.activities=state.activities.filter(h=>h.id!==id);closeModal();render();announce("Activity removed.");return}
if(action==="add-time"){
const a=getApp("discord");if(!a)return;
const before=a.minutes<a.limit;a.minutes+=10;render();announce("Added ten sample minutes to Discord.");
if(before&&canAlert(a))showModal("reminder",a.id);
return}
if(action==="reset"){if(!window.confirm("Reset the sample data and preferences?"))return;state=start();step=0;closeModal();render(true);announce("Demo reset.");return}
}
document.addEventListener("click",e=>{
const button=e.target.closest("button[data-view],button[data-action],button[data-onboard-hobby]");
if(!button)return;
if(button.dataset.view){e.preventDefault();if(!state.onboarded)return; navigate(button.dataset.view);return;}
if(button.dataset.onboardHobby){const h=getHobby(button.dataset.onboardHobby);if(h){h.selected=!h.selected;render();}return;}
act(button.dataset.action,button.dataset.id,button);
});
document.addEventListener("change",e=>{
const el=e.target;
if(el.dataset.onboardApp){const a=getApp(el.dataset.onboardApp);if(a){a.selected=el.checked;a.enabled=el.checked;save();}return}
if(el.dataset.onboardLimit){const a=getApp(el.dataset.onboardLimit);if(a){a.limit=Number(el.value)||30;save();}return}
if(el.dataset.onboardTime){const h=getHobby(el.dataset.onboardTime);if(h){h.time=mins(el.value);save();}return}
if(el.dataset.onboardDays){const h=getHobby(el.dataset.onboardDays);if(h){h.days=el.value;save();}return}
if(el.dataset.period){state.period=el.dataset.period;render();return}
});
document.addEventListener("click",e=>{const b=e.target.closest("button[data-period]");if(!b)return;state.period=b.dataset.period;render();});
document.addEventListener("submit",e=>{
if(!["app-form","hobby-form","quiet-form"].includes(e.target.id))return;e.preventDefault();
const f=new FormData(e.target);
if(e.target.id==="app-form"){
const id=String(f.get("appId"));const a=getApp(id);if(!a)return;
const limit=Number(f.get("limit"));if(!Number.isFinite(limit)||limit<5||limit>240||limit%5!==0){announce("Choose a limit from 5 to 240 minutes in steps of five.");return}
a.selected=true;a.limit=limit;a.enabled=f.has("enabled");closeModal();render();announce(a.name+" limit saved.");return;
}
if(e.target.id==="hobby-form"){
const name=String(f.get("name")||"").trim().slice(0,36),time=mins(String(f.get("time")||"20:00")),days=String(f.get("days")||"Every day");
if(!name){announce("Enter an activity name.");return}
if(modal?.type==="add-hobby")state.activities.push({id:"h"+Date.now(),name,time,days,selected:true});
else {const h=getHobby(modal?.id);if(h){h.name=name;h.time=time;h.days=days;}}
closeModal();render();announce("Activity saved.");return;
}
if(e.target.id==="quiet-form"){state.quietStart=String(f.get("start")||"22:00");state.quietEnd=String(f.get("end")||"08:00");closeModal();render();announce("Quiet hours saved.");}
});
document.addEventListener("keydown",e=>{
if(!modal)return;
if(e.key==="Escape"){e.preventDefault();closeModal();return}
if(e.key!=="Tab")return;
const nodes=[...dialogRoot.querySelectorAll("button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href]")].filter(n=>n.getClientRects().length);
if(!nodes.length)return;
const first=nodes[0],last=nodes[nodes.length-1];
if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}
else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}
});
document.addEventListener("click",e=>{if(e.target.classList.contains("dialog-backdrop"))closeModal()});
root.addEventListener("click",e=>{const a=e.target.closest("a[data-view]");if(a){e.preventDefault();navigate(a.dataset.view)}});
render();
})();