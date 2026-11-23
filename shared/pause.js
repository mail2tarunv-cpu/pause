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
const sampleDevices={
discord:{mac:30,phone:10},instagram:{mac:0,phone:46},youtube:{mac:34,phone:35},figma:{mac:112,phone:0},chrome:{mac:76,phone:41}
};
// Initial suggestions only; the person's saved classification always wins.
const categories=["entertainment","productivity"];
const autoCategory=a=>/discord|instagram|youtube|netflix|tiktok|twitch|reddit|facebook|spotify|steam|game|social|snapchat|hulu|disney/i.test(String(a.id)+" "+String(a.name))?"entertainment":"productivity";
const categoryName=c=>c==="entertainment"?"Entertainment":"Productivity";
const categoryIcon=c=>c==="entertainment"?"play":"briefcase-business";
const start=()=>({
version:6,onboarded:false,view:"today",period:"day",reminders:true,paused:false,
quietStart:"22:00",quietEnd:"08:00",apps:catalog.map(x=>({...x,category:autoCategory(x),explicitReminder:false,tracked:true,selected:autoCategory(x)==="entertainment",enabled:autoCategory(x)==="entertainment",usage:{...sampleDevices[x.id]},minutes:sampleDevices[x.id].mac+sampleDevices[x.id].phone})),
activities:[{id:"read",name:"Reading",time:"20:00",days:"Every day",selected:true},{id:"walk",name:"Walking",time:"17:00",days:"Weekends",selected:true}],
choice:null,boardReminders:false,tracking:true,budget:90,budgetEnabled:false,breakMinutes:20,cooldown:30,lastDelivered:0,demoArmed:false,choices:{},lastAlerts:{},feedback:[],history:{},day:null
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
a.limit=Math.max(5,Math.min(240,Number(old.limit)||a.limit));a.minutes=Number(old.minutes??prev.usage?.[a.name]??a.minutes);delete a.usage;}
const oldGoals=Array.isArray(prev.activities)?prev.activities:Array.isArray(prev.goals)?prev.goals:Array.isArray(prev.hobbies)?prev.hobbies:[];
if(oldGoals.length){s.activities=oldGoals.filter(g=>g.name).slice(0,12).map((g,i)=>({id:String(g.id??`import-${i}`),name:String(g.name).slice(0,36),time:mins(g.time),days:g.days||"Every day",selected:true}));}
s.reminders=prev.reminders??prev.enabled??true;s.paused=prev.tracking===false;
return s;
}
let state=parse(localStorage.getItem(KEY))||migrate();
state={...start(),...state};
if(!Array.isArray(state.apps)||!state.apps.length)state.apps=start().apps;
if(!Array.isArray(state.activities))state.activities=start().activities;
for(const app of state.apps){
const sample=sampleDevices[app.id]||{mac:1,phone:1};
if(!app.usage||!Number.isFinite(app.usage.mac)||!Number.isFinite(app.usage.phone)){
const sum=Math.max(0,Math.round(Number(app.minutes)||0)),fraction=sample.mac/Math.max(1,sample.mac+sample.phone);
const mac=Math.round(sum*fraction);app.usage={mac,phone:sum-mac};
}
app.minutes=app.usage.mac+app.usage.phone;
if(!categories.includes(app.category))app.category=autoCategory(app);
}
state.version=6;
const dayKey=(d=new Date())=>d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0");
const clockMinutes=t=>{const [h,m]=mins(t).split(":").map(Number);return h*60+m};
const endTime=(t,d=120)=>{const n=(clockMinutes(t)+d)%1440;return String(Math.floor(n/60)).padStart(2,"0")+":"+String(n%60).padStart(2,"0")};
function normalize(){
for(const a of state.apps){a.tracked=a.tracked!==false;a.explicitReminder=a.explicitReminder??true;}
for(const h of state.activities){h.time=mins(h.time);h.end=h.end||endTime(h.time);h.duration=Math.max(5,Number(h.duration)||20);}
state.choices=state.choices||{};state.lastAlerts=state.lastAlerts||{};state.history=state.history||{};state.feedback=Array.isArray(state.feedback)?state.feedback:[];
if(state.choice){const c=state.choice;state.choices[c.kind==="break"?"global":c.appId||"global"]=c;state.choice=null;}
if(!state.day){state.day=dayKey();for(let i=1;i<=6;i++){const d=new Date();d.setDate(d.getDate()-i);const key=dayKey(d);if(!state.history[key])state.history[key]=Object.fromEntries(state.apps.map(a=>[a.id,{mac:Math.round(a.usage.mac*[.88,1.13,.93,1.04,.76,.64][i-1]),phone:Math.round(a.usage.phone*[.88,1.13,.93,1.04,.76,.64][i-1])}]));}}
}
function rollover(){
if(state.day===dayKey())return false;
state.history[state.day]=Object.fromEntries(state.apps.map(a=>[a.id,{...a.usage}]));
for(const a of state.apps){a.usage={mac:0,phone:0};a.minutes=0;}
state.day=dayKey();state.choices={};state.lastAlerts={};state.lastDelivered=0;
Object.keys(state.history).sort().slice(0,-35).forEach(k=>delete state.history[k]);return true;
}
normalize();rollover();
let deviceScope="all";
state.view=["today","plan","settings","activity"].includes(state.view)?state.view:"today";
let step=0;
let modal=null;
let modalFocus=null;
let feedbackReason="bad-timing";
let alternateId=null;
const icon=name=>`<i data-lucide="${name}" aria-hidden="true"></i>`;
const esc=v=>String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const selectedApps=()=>state.apps.filter(a=>a.enabled&&a.tracked);
const activeHobbies=()=>state.activities.filter(a=>a.selected);
const getApp=id=>id==="entertainment-total"?budgetTarget():state.apps.find(a=>a.id===id);
function budgetTarget(){const apps=state.apps.filter(a=>a.category==="entertainment");const usage={mac:apps.reduce((s,a)=>s+a.usage.mac,0),phone:apps.reduce((s,a)=>s+a.usage.phone,0)};return {id:"entertainment-total",name:"Entertainment",category:"entertainment",icon:"play",usage,minutes:usage.mac+usage.phone,limit:state.budget,enabled:state.budgetEnabled,selected:state.budgetEnabled,tracked:true};}
function targets(){return [...selectedApps(),...(state.budgetEnabled?[budgetTarget()]:[])];}
const getHobby=id=>state.activities.find(a=>a.id===id);
const used=(a,scope=deviceScope)=>scope==="all"?a.usage.mac+a.usage.phone:a.usage[scope]||0;
const total=(scope=deviceScope)=>state.apps.reduce((sum,a)=>sum+used(a,scope),0);
function categorySummary(period="day"){
const values=categories.map(c=>state.apps.filter(a=>a.category===c).reduce((sum,a)=>sum+periodUsed(a,deviceScope,period),0));
const sum=values[0]+values[1];
return `<div class="category-summary" aria-label="Usage by category"><div class="category-summary-track" role="img" aria-label="Entertainment ${fmt(values[0])}, Productivity ${fmt(values[1])}"><span class="entertainment-fill" style="width:${sum?values[0]/sum*100:0}%"></span><span class="productivity-fill" style="width:${sum?values[1]/sum*100:0}%"></span></div><div class="category-summary-labels">${categories.map((c,i)=>`<div><span class="category-key ${c}"></span><span>${categoryName(c)}</span><strong>${fmt(values[i])}</strong></div>`).join("")}</div></div>`;
}
function categoryGroup(c,body){return `<div class="category-group"><div class="category-group-title">${icon(categoryIcon(c))}<h3>${categoryName(c)}</h3></div>${body}</div>`;}
const scopeLabel=()=>deviceScope==="all"?"All devices":deviceScope==="mac"?"Mac":"iPhone";
const fmtParts=n=>({h:Math.floor(n/60),m:Math.round(n%60)});
const hobbyIcon=h=>/read|book/i.test(h?.name||"")?"book-open":/walk|run/i.test(h?.name||"")?"footprints":/music|guitar/i.test(h?.name||"")?"music":/sketch|draw|paint/i.test(h?.name||"")?"pencil":/cook/i.test(h?.name||"")?"cooking-pot":/rest|sleep/i.test(h?.name||"")?"coffee":"leaf";
function scopeControl(){
return '<div class="device-filter" role="group" aria-label="Filter activity by device">'+[["all","All devices","layers"],["mac","Mac","laptop"],["phone","iPhone","smartphone"]].map(([v,l,i])=>`<button type="button" data-scope="${v}" aria-pressed="${deviceScope===v}">${icon(i)}<span>${l}</span></button>`).join("")+'</div>';
}
function timeDisplay(n){
const {h,m}=fmtParts(n);return `<span class="time-display" aria-label="${h} hours ${m} minutes"><span>${h}</span><small>h</small><span>${String(m).padStart(2,"0")}</span><small>m</small></span>`;
}
function distribute(n,weights){
const sum=weights.reduce((a,b)=>a+b,0)||1;let vals=weights.map(x=>Math.floor(n*x/sum)),left=n-vals.reduce((a,b)=>a+b,0);for(let i=0;left>0;i++,left--)vals[i%vals.length]++;return vals;
}
function series(a,scope,period){
const macWeights=[0,0,0,0,0,0,1,2,4,6,8,8,4,6,9,8,6,4,3,2,1,1,0,0],phoneWeights=[1,0,0,0,0,1,3,5,4,3,3,4,5,4,3,4,4,6,7,8,8,5,2,1];
const one=d=>period==="day"?distribute(used(a,d),d==="mac"?macWeights:phoneWeights):Array.from({length:7},(_,i)=>{const date=new Date();date.setDate(date.getDate()-6+i);return i===6?used(a,d):Number(state.history[dayKey(date)]?.[a.id]?.[d]||0);});
if(scope!=="all")return one(scope);const m=one("mac"),p=one("phone");return m.map((n,i)=>n+p[i]);
}
const periodUsed=(a,scope,period)=>series(a,scope,period).reduce((s,n)=>s+n,0);
function periodTotal(scope,period){return state.apps.reduce((s,a)=>s+periodUsed(a,scope,period),0)}
function deviceBreakdown(period="day"){
const m=periodTotal("mac",period),p=periodTotal("phone",period),sum=m+p;
return `<div class="device-split" role="img" aria-label="Mac ${fmt(m)}; iPhone ${fmt(p)}"><span class="split-mac" style="width:${sum?m/sum*100:50}%"></span><span class="split-phone" style="width:${sum?p/sum*100:50}%"></span></div><div class="device-pair">${[["mac","Mac","laptop",m],["phone","iPhone","smartphone",p]].map(([k,l,ico,n])=>`<button class="device-item" data-scope="${k}" aria-label="Show ${l} activity, ${fmt(n)}"><span class="device-icon ${k}">${icon(ico)}</span><span class="device-item-name">${l}<strong>${fmt(n)}</strong></span>${icon("chevron-right")}</button>`).join("")}</div>`;
}
const fmt=n=>n<60?Math.round(n)+"m":Math.floor(n/60)+"h "+String(Math.round(n%60)).padStart(2,"0")+"m";
const niceTime=t=>{const parts=mins(t).split(":").map(Number);return (parts[0]%12||12)+(parts[1]?":"+String(parts[1]).padStart(2,"0"):"")+(parts[0]>=12?" PM":" AM")};
const currentDate=()=>new Date().toLocaleDateString("en-US",{weekday:"long",month:"long",day:"numeric"});
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(state))}catch{}};
const persistBoard=(kind="idle",h=null,until=null)=>{try{localStorage.setItem("pause-demo-board-v1",JSON.stringify({kind,message:kind==="reminder"?(h?"TIME FOR A PAUSE\n\n"+h.name.toUpperCase().slice(0,44):"TIME FOR A PAUSE\n\nTAKE A MOMENT"):kind==="break"?"TAKING A BREAK":kind==="test"?"PAUSE\n\nBOARD CONNECTED":"LESS SCREEN\nMORE LIFE",until:until||Date.now()+120000,enabled:state.boardReminders,revision:Date.now()}))}catch{}};
const refreshBoard=()=>{if(state.boardReminders)persistBoard("idle");else try{localStorage.removeItem("pause-demo-board-v1")}catch{}};
function activeChoice(id){const c=state.choices[id];return c&&(!c.until||c.until>Date.now())?c:null;}
function chooseTarget(){return targets().filter(canAlert).sort((a,b)=>Number(b.category==="entertainment")-Number(a.category==="entertainment")||Number(b.id==="entertainment-total")-Number(a.id==="entertainment-total")||(b.minutes-b.limit)-(a.minutes-a.limit))[0];}
function checkIn(){if(!state.onboarded||modal||document.hidden||(document.hasFocus&&!document.hasFocus()))return;const a=chooseTarget();if(a){state.lastAlerts[a.id]=Date.now();state.lastDelivered=Date.now();save();showModal("reminder",a.id);if(state.boardReminders)persistBoard("reminder",suggestHobby(),Date.now()+300000);}}

function announce(t){announcer.textContent="";requestAnimationFrame(()=>announcer.textContent=t);}
function navButton(view,label,ico){
return `<button type="button" class="nav-link" data-view="${view}" aria-current="${state.view===view?"page":"false"}">${icon(ico)}<span class="nav-text">${label}</span></button>`;
}
function statusTag(){
return `<span class="status-tag" aria-label="Sample data, ${!state.tracking?"tracking paused":state.paused?"reminder previews paused":"reminder previews enabled"}"><span class="status-dot ${state.paused?"dim":""}"></span>${!state.tracking?"Tracking paused":state.paused?"Reminders paused":"Sample activity"}</span>`;
}
function shell(content){
const brand=`<a class="brand" href="${device==="phone"?"/phone/":"/mac/"}" data-view="today"><span class="brand-mark">P.</span><span class="brand-word">PAUSE</span></a>`;
const nav=`${navButton("today","Today","house")}${navButton("plan","My plan","calendar-days")}${navButton("settings","Settings","settings")}`;
if(device==="phone")return `<div class="phone-shell"><header class="topbar">${brand}<div class="topbar-right">${statusTag()}</div></header><main class="main" id="main" tabindex="-1">${content}</main><nav class="phone-bottom" aria-label="Main navigation">${nav}</nav></div>`;
return `<div class="app-layout"><aside class="sidebar">${brand}<div class="side-label">Workspace</div><nav class="nav" aria-label="Main navigation">${nav}</nav><div class="side-footer"><div class="side-note">Design preview · App usage is illustrative, not measured from this computer.</div><a href="/phone/" target="_blank" rel="noopener">View mobile version</a></div></aside><div class="workspace"><header class="topbar"><div class="topbar-left">PAUSE <span aria-hidden="true">/</span> <span class="current">${state.view==="today"?"Today":state.view==="plan"?"My plan":state.view==="activity"?"Activity":"Settings"}</span></div><div class="topbar-right"><button class="icon-button" data-action="menubar" aria-label="Preview Mac menu bar">${icon("panel-top")}</button>${statusTag()}</div></header><main class="main" id="main" tabindex="-1">${content}</main></div></div>`;
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
const exceeded=a.enabled&&a.minutes>=a.limit;const scoped=used(a);
return `<div class="usage-row">${appIcon(a)}<div class="row-main"><span class="row-title">${esc(a.name)}</span>${meter(a)}<span class="row-detail">${a.minutes} / ${a.limit} min across devices${!a.enabled?" · Reminder off":""}</span></div><div class="usage-value">${fmt(scoped)}${deviceScope!=="all"?`<span class="scope-small">on ${scopeLabel()}</span>`:""}${exceeded?`<span class="over">${a.minutes===a.limit?"Limit reached":(a.minutes-a.limit)+"m over"}</span>`:""}</div></div>`;
}
function chart(period="day"){
const data=Array.from({length:period==="week"?7:24},(_,i)=>state.apps.reduce((sum,a)=>sum+series(a,deviceScope,period)[i],0));
const mx=Math.max(1,...data);const days=data.map((_,i)=>{const dt=new Date();dt.setDate(dt.getDate()-6+i);return dt.toLocaleDateString("en-US",{weekday:"short"})});
const maxLabel=period==="week"?fmt(mx):mx+"m";
return `<div class="chart-frame"><div class="chart-scale"><span>${maxLabel}</span><span>${period==="week"?fmt(Math.round(mx/2)):Math.round(mx/2)+"m"}</span><span>0</span></div><div class="chart-inner"><div class="usage-chart ${period==="week"?"weekly":""}" role="img" aria-label="${scopeLabel()} sample usage, ${period==="week"?"last seven days":"by hour"}">${data.map((v,i)=>`<span class="usage-bar ${deviceScope==="phone"?"phone-bar":"active"}" title="${period==="week"?days[i]:i+":00"}: ${fmt(v)}" style="height:${v/mx*100}%"></span>`).join("")}</div><div class="chart-axis">${(period==="week"?days:["12 AM","6 AM","12 PM","6 PM","11 PM"]).map(d=>`<span>${d}</span>`).join("")}</div></div></div>`;
}

function nextHobby(){
const current=suggestHobby();if(current)return current;const arr=activeHobbies();if(!arr.length)return null;
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
function suggestHobby(){
const now=new Date(),m=now.getHours()*60+now.getMinutes(),d=now.getDay();
return activeHobbies().filter(h=>{
const a=clockMinutes(h.time),b=clockMinutes(h.end||endTime(h.time)),overnight=b<a,day=overnight&&m<b?(d+6)%7:d;
const valid=h.days==="Weekends"?(day===0||day===6):h.days==="Weekdays"?(day>0&&day<6):true;
const inWindow=a===b||(!overnight?m>=a&&m<b:m>=a||m<b);
return valid&&(h.days==="Whenever"||inWindow)&&!state.feedback.some(f=>f.hobbyId===h.id&&f.reason==="other"&&Date.now()-f.at<86400000);
}).sort((a,b)=>(state.feedback.filter(f=>f.hobbyId===a.id&&f.reason==="bad-timing").length-state.feedback.filter(f=>f.hobbyId===b.id&&f.reason==="bad-timing").length)||a.duration-b.duration)[0]||null;
}
function hobbySchedule(h){return esc(h.days)+" · "+niceTime(h.time)+"–"+niceTime(h.end||endTime(h.time))+" · "+(h.duration||20)+" min";}
function choiceBanner(){
const choices=Object.entries(state.choices).filter(([k,c])=>activeChoice(k));if(!choices.length)return "";
return choices.map(([key,c])=>{const app=getApp(c.appId),title=c.kind==="break"?"Taking a break":c.kind==="snooze"?"Snoozed":c.kind==="dismiss"?"No more reminders today":"Reminders paused";
return `<div class="preview-banner"><span><strong>${title}</strong> · ${key!=="global"&&app?esc(app.name)+" · ":""}Until ${new Date(c.until).toLocaleTimeString("en-US",{hour:"numeric",minute:"2-digit"})}</span><button class="text-action" data-action="undo" data-id="${esc(key)}">Undo</button></div>`;}).join("");
}
function today(){
const hobby=nextHobby(),apps=selectedApps().filter(a=>deviceScope==="all"||used(a)>0);
const nextAlert=chooseTarget();const over=nextAlert?[nextAlert]:[];
return header("Today",currentDate(),scopeControl())+choiceBanner()+
`<div class="hero-grid">
<section class="card pad hero-usage" aria-label="Screen time overview">
<div class="section-heading"><h2>${deviceScope==="all"?"Screen time":scopeLabel()+" screen time"}</h2><span class="sample-caption">Sample</span></div>
<div class="hero-numbers">${timeDisplay(total())}</div>
<p class="hero-meta">${deviceScope==="all"?"Total device time · may include overlap":"Sample usage across tracked apps"}</p>
${categorySummary()}${deviceScope==="all"?deviceBreakdown():""}
<button class="text-action activity-link" data-view="activity">View activity ${icon("arrow-right")}</button>
</section>
<section class="card pad hero-hobby" aria-label="Upcoming activity">
<div class="hobby-top"><h2>Up next</h2><span class="hobby-icon">${icon(hobbyIcon(hobby))}</span></div>
<div class="hobby-content"><h2 class="hobby-title">${hobby?esc(hobby.name):"Make time for something else"}</h2><p class="hobby-info">${hobby?hobbySchedule(hobby):"Add an activity you'd like more time for."}</p></div>
<button class="btn secondary hobby-action" data-view="plan">Edit plan ${icon("arrow-up-right")}</button>
</section></div>
<section class="card pad limits-card"><div class="section-heading"><div><h2>App limits</h2><p class="section-subtitle">Entertainment first. Limits apply across devices.</p></div><button class="text-action" data-view="plan">Manage ${icon("arrow-right")}</button></div>
${state.budgetEnabled?`<div class="budget-today">${usageRow(budgetTarget())}</div>`:""}${apps.length?`<div class="usage-list">${categories.map(c=>{const group=apps.filter(a=>a.category===c);return group.length?categoryGroup(c,group.map(usageRow).join("")):""}).join("")}</div>`:`<div class="empty-state"><h3>No limited apps here</h3><p>Choose an app in My plan, or switch devices.</p><button class="btn secondary" style="margin-top:16px" data-view="plan">Manage limits</button></div>`}
${over.length?`<button class="reminder-link" data-action="reminder" data-id="${over[0].id}"><span class="reminder-link-icon">${icon("bell")}</span><span><strong>${esc(over[0].name)} · ${over[0].minutes===over[0].limit?"Limit reached":(over[0].minutes-over[0].limit)+" min over"}</strong><small>View check-in</small></span>${icon("chevron-right")}</button>`:""}
</section><p class="footer-note">Sample device data · no live monitoring or cross-device sync.</p>`;
}
function activity(){
const apps=[...state.apps].filter(a=>periodUsed(a,deviceScope,state.period)>0).sort((a,b)=>periodUsed(b,deviceScope,state.period)-periodUsed(a,deviceScope,state.period));
const sum=periodTotal(deviceScope,state.period),week=state.period==="week";
return header("Activity",week?"Last seven days":"Today",scopeControl())+
`<section class="card pad activity-card"><div class="metric-head"><h2>${scopeLabel()} usage</h2><div class="tabs" role="group" aria-label="Activity period"><button data-period="day" aria-pressed="${!week}">Day</button><button data-period="week" aria-pressed="${week}">Week</button></div></div>
<div class="hero-numbers">${timeDisplay(sum)}</div><p class="hero-meta">${week?"Seven days of sample device time":"Sample device time today"}${deviceScope==="all"?" · may include overlap":""}</p>
${chart(state.period)}
${deviceScope==="all"?deviceBreakdown(state.period):""}${categorySummary(state.period)}</section>
<section class="card pad spaced"><div class="section-heading"><h2>By app</h2><span class="sample-caption">${week?"7 days":"Today"}</span></div><div class="usage-list">${categories.map(c=>{const group=apps.filter(a=>a.category===c);return group.length?categoryGroup(c,group.map(a=>{const n=periodUsed(a,deviceScope,state.period);return `<button class="usage-row detail-row detail-button" data-action="app-detail" data-id="${esc(a.id)}">${appIcon(a)}<div class="row-main"><span class="row-title">${esc(a.name)}</span><div class="track" aria-hidden="true"><span class="${c==="entertainment"?"entertainment-fill":""}" style="width:${sum?n/sum*100:0}%"></span></div></div><span class="usage-value">${fmt(n)}</span></button>`}).join("")):""}).join("")||'<p class="inline-helper">No sample usage for this device.</p>'}</div></section>
<p class="footer-note">Illustrative activity, not measured from your devices.</p>`;
}
function plan(){
const hobbies=activeHobbies();
return header("My plan","Limits and activities")+
`<section class="card pad plan-block"><div class="section-heading"><h2>Apps &amp; limits</h2></div>
<p class="section-subtitle plan-intro">Change a category or reminder at any time.</p><button class="app-plan-row budget-row" data-action="budget"><span class="app-icon">${icon("clock")}</span><span class="app-plan-copy"><strong>Entertainment budget</strong><small>${state.budgetEnabled?fmt(state.budget)+" per day":"Optional daily total"}</small></span><span class="rule-state">${state.budgetEnabled?"On":"Off"}</span>${icon("chevron-right")}</button>
${categories.map(c=>{const group=state.apps.filter(a=>a.category===c);return categoryGroup(c,`<p class="category-hint">${c==="entertainment"?"Reminders on by default.":"Tracked without reminders unless you turn them on."}</p>${group.length?group.map(a=>`<button class="app-plan-row" data-action="edit-app" data-id="${esc(a.id)}" aria-label="Edit ${esc(a.name)} category and reminders">${appIcon(a)}<span class="app-plan-copy"><strong>${esc(a.name)}</strong><small>${!a.tracked?"Tracking off":a.enabled?a.limit+" min / day":"No reminder"}</small></span><span class="rule-state ${a.selected&&a.enabled?"rule-on":""}">${!a.tracked?"Paused":a.enabled?"On":"Off"}</span>${icon("chevron-right")}</button>`).join(""):'<p class="inline-helper empty-category">No apps in this category.</p>'}`);}).join("")}
</section>
<section class="card pad">
<div class="section-heading"><h2>Activities</h2><button class="text-action" data-action="add-hobby">${icon("plus")} Add activity</button></div>
${hobbies.length?hobbies.map(h=>`<div class="plan-item"><span class="app-icon">${icon(hobbyIcon(h))}</span><div><strong class="row-title">${esc(h.name)}</strong><span class="row-detail">${hobbySchedule(h)}</span></div><button class="icon-button" aria-label="Edit ${esc(h.name)}" data-action="edit-hobby" data-id="${esc(h.id)}">${icon("pencil")}</button></div>`).join(""):`<p class="inline-helper">Add a hobby, a short break, or simply time to rest.</p>`}
</section><p class="footer-note">Both categories count toward screen time. Only apps with reminders enabled can trigger a check-in.</p>`;
}
function settings(){
return header("Settings","Preferences and devices")+
`<div class="two-col">
<section class="card pad"><h2 style="margin-bottom:12px">Reminders</h2><div class="settings-list">
<div class="settings-row"><div class="settings-copy"><strong>Reminders</strong><p>Show a check-in when you reach an app limit.</p></div><button class="switch" role="switch" aria-label="Reminders" aria-checked="${state.reminders}" data-action="toggle-reminders"></button></div>
<div class="settings-row"><div class="settings-copy"><strong>Pause reminders</strong><p>Stop check-ins without changing your limits.</p></div><button class="switch" role="switch" aria-label="Pause reminders" aria-checked="${state.paused}" data-action="toggle-pause"></button></div>
<div class="settings-row"><div class="settings-copy"><strong>Quiet hours</strong><p>${niceTime(state.quietStart)} – ${niceTime(state.quietEnd)}</p></div><button class="icon-button" data-action="quiet" aria-label="Edit quiet hours">${icon("pencil")}</button></div>
<div class="settings-row"><div class="settings-copy"><strong>Reminder timing</strong><p>${state.breakMinutes} min break · ${state.cooldown} min minimum between check-ins</p></div><button class="icon-button" data-action="timing" aria-label="Edit reminder timing">${icon("pencil")}</button></div></div></section>
<section class="card pad"><h2 style="margin-bottom:12px">Devices and privacy</h2><div class="settings-list">
<div class="settings-row"><div class="settings-copy"><strong>Preview tracking</strong><p>${state.tracking?"Sample usage can be added.":"New sample usage is paused."}</p></div><button class="switch" role="switch" aria-label="Preview tracking" aria-checked="${state.tracking}" data-action="toggle-tracking"></button></div><div class="settings-row"><div class="settings-copy"><strong>Device access</strong><p>Sample Mac and iPhone data only.</p></div><button class="icon-button" data-action="devices" aria-label="Device access">${icon("chevron-right")}</button></div>
<div class="settings-row"><div class="settings-copy"><strong>Ambient board</strong><p>${state.boardReminders?"Following this browser’s demo reminders.":"Optional · private messages only."}</p></div><button class="icon-button" data-action="board-settings" aria-label="Board settings">${icon("chevron-right")}</button></div>
<div class="settings-row"><div class="settings-copy"><strong>Review onboarding</strong><p>Update the apps and activities you started with.</p></div><button class="icon-button" data-action="setup" aria-label="Review onboarding">${icon("arrow-up-right")}</button></div>
</div></section></div>
<details class="card pad spaced"><summary style="cursor:pointer;font-weight:650;min-height:44px">Preview tools</summary>
<p class="detail-intro">For design testing only. These controls change sample data in this browser.</p>
<div class="btn-group"><button class="btn secondary" data-action="simulate">Simulate app usage</button><button class="btn secondary" data-action="advance-snooze">Expire snoozes</button><button class="btn secondary" data-action="reminder" data-id="discord">Preview reminder</button><button class="btn ghost" data-action="reset">Reset demo</button></div>
</details>
<p class="footer-note">Preferences are stored in this browser. No account, cloud sync or other-app monitoring is active here.</p>`;
}
function onboarding(){
const steps=["Welcome","Device access","Choose apps","Set limits","Choose activities","Review"];const stage=step===1?-1:step>1?step-1:step;
let body="";
if(stage===0)body=`<h1 class="onboarding-title">A little less screen.<br>More life.</h1><p class="onboarding-intro">Set limits for the apps that tend to run long. PAUSE will let you know when you've passed one and suggest something you'd rather be doing.</p><div class="note"><strong>You're in a preview.</strong> This website uses sample activity. Real app tracking requires the native Mac or iPhone app.</div><button class="text-action" data-action="devices">Device access and privacy ${icon("arrow-right")}</button>`;
if(stage===-1)body=`<h1 class="onboarding-title">Connect your activity.</h1><p class="onboarding-intro">Native tracking needs device permission. This preview lets you set up your plan and test with sample usage instead.</p><div class="card pad"><div class="settings-row"><div class="settings-copy"><strong>Mac</strong><p>Foreground app usage, excluding idle time.</p></div><span class="sample-caption">Not connected</span></div><div class="settings-row"><div class="settings-copy"><strong>iPhone</strong><p>Apple Screen Time authorization.</p></div><span class="sample-caption">Not connected</span></div></div><p class="footer-note">No real app history or permission requests are made in this browser.</p>`;
if(stage===1)body=`<h1 class="onboarding-title">Choose your reminders.</h1><p class="onboarding-intro">Entertainment apps are selected by default. Add productivity apps if you want reminders for them too.</p><div class="card pad">${categories.map(c=>categoryGroup(c,state.apps.filter(a=>a.category===c).map(a=>`<div class="onboard-app-row"><label class="onboard-choice"><input type="checkbox" data-onboard-app="${esc(a.id)}" ${a.selected&&a.enabled?"checked":""}><span class="app-icon">${icon(a.icon)}</span><span>${esc(a.name)}</span></label><div class="form-field category-picker"><label class="sr-only" for="cat-${esc(a.id)}">Category for ${esc(a.name)}</label><select id="cat-${esc(a.id)}" data-onboard-category="${esc(a.id)}">${categories.map(x=>`<option value="${x}" ${a.category===x?"selected":""}>${categoryName(x)}</option>`).join("")}</select></div></div>`).join("")||'<p class="inline-helper">No apps in this category.</p>')).join("")}</div><p class="footer-note">These are suggested categories, not a judgement about how you use an app.</p>`;
if(stage===2)body=`<h1 class="onboarding-title">Set your daily limits.</h1><p class="onboarding-intro">These trigger a reminder, never a lockout.</p><div class="card pad"><button class="app-plan-row budget-row" data-action="budget"><span class="app-icon">${icon("clock")}</span><span class="app-plan-copy"><strong>Entertainment budget</strong><small>${state.budgetEnabled?fmt(state.budget)+" per day":"Optional daily total"}</small></span>${icon("chevron-right")}</button>${selectedApps().map(a=>`<div class="onboard-limit">${appIcon(a)}<span class="row-title">${esc(a.name)}</span><div class="form-field"><label class="sr-only" for="onboard-limit-${a.id}">Limit for ${esc(a.name)}</label><select id="onboard-limit-${a.id}" data-onboard-limit="${a.id}">${[15,20,30,45,60,90,120,180,240].map(n=>`<option value="${n}" ${a.limit===n?"selected":""}>${n} min</option>`).join("")}</select></div></div>`).join("")||'<p class="inline-helper">No reminders selected. You can set limits later.</p>'}</div>`;
if(stage===3){for(const name of ["Sketching","Running","Cooking","Music","Rest"]){if(!state.activities.some(a=>a.name.toLowerCase()===name.toLowerCase()))state.activities.push({id:"option-"+name.toLowerCase(),name,time:"20:00",days:"Every day",selected:false});}normalize();}
if(stage===3)body=`<h1 class="onboarding-title">What would you rather do?</h1><p class="onboarding-intro">Choose activities you want to make time for. Rest counts, too.</p><div class="activity-pills">${state.activities.map(a=>`<button class="activity-pill" data-onboard-hobby="${esc(a.id)}" aria-pressed="${a.selected}">${icon(hobbyIcon(a))}${esc(a.name)}</button>`).join("")}</div><div class="card pad">${activeHobbies().length?activeHobbies().map(a=>`<div class="schedule-row"><strong class="schedule-name">${esc(a.name)}</strong><div class="form-field"><label for="onboard-time-${esc(a.id)}">From</label><input type="time" id="onboard-time-${esc(a.id)}" value="${esc(a.time)}" data-onboard-time="${esc(a.id)}"></div><div class="form-field"><label for="onboard-end-${esc(a.id)}">Until</label><input type="time" id="onboard-end-${esc(a.id)}" value="${esc(a.end)}" data-onboard-end="${esc(a.id)}"></div><div class="form-field"><label for="onboard-duration-${esc(a.id)}">Minutes</label><input type="number" min="5" max="180" step="5" id="onboard-duration-${esc(a.id)}" value="${a.duration}" data-onboard-duration="${esc(a.id)}"></div><div class="form-field"><label for="onboard-days-${esc(a.id)}">Days</label><select id="onboard-days-${esc(a.id)}" data-onboard-days="${esc(a.id)}">${["Every day","Weekdays","Weekends","Whenever"].map(x=>`<option ${a.days===x?"selected":""}>${x}</option>`).join("")}</select></div></div>`).join(""):`<p class="inline-helper">No activities chosen. You can add one later.</p>`}</div><button class="text-action" data-action="add-hobby">+ Add your own activity</button><p class="footer-note">Fine-tune time windows and durations in My plan.</p>`;
if(stage===4)body=`<h1 class="onboarding-title">Your starting plan.</h1><p class="onboarding-intro">Check the basics. Everything stays editable.</p><div class="card pad review-list"><div class="review-item"><strong>App limits</strong><p>${selectedApps().map(a=>esc(a.name)+" · "+a.limit+" min/day").join(" · ")||"None selected"}${state.budgetEnabled?" · Total entertainment: "+fmt(state.budget):""}</p></div><div class="review-item"><strong>Activities</strong><p>${activeHobbies().map(a=>esc(a.name)+" · "+hobbySchedule(a)).join(" · ")||"None yet"}</p></div><div class="review-item"><strong>Reminders</strong><p>Optional, non-blocking check-ins with Undo.</p></div></div>`;
return `<div class="${device==="phone"?"phone-shell":""}"><div class="onboarding-shell">
<div class="brand"><span class="brand-mark">P.</span><span class="brand-word">PAUSE</span></div>
<div class="step-top"><span class="eyebrow">${steps[step]}</span><span class="small-mono">${step+1} / ${steps.length}</span></div>
<div class="step-bars" aria-label="Setup progress, step ${step+1} of ${steps.length}">${steps.map((_,i)=>`<span class="${i<=step?"done":""}"></span>`).join("")}</div>
${body}
<div class="onboard-footer"><button class="btn secondary" data-action="${step===0?"skip":"back"}">${step===0?"Explore demo":"Back"}</button><button class="btn" data-action="${step===5?"finish":"next"}">${step===5?"Start PAUSE":step===1?"Use sample data":"Continue"} ${icon("arrow-right")}</button></div>
</div></div>`;
}
function dialogShell(title,body,form=false){
return `<div class="dialog-backdrop"><section class="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><div class="dialog-header"><h2 id="dialog-title">${esc(title)}</h2><button type="button" class="icon-button" data-action="close" aria-label="Close dialog">${icon("x")}</button></div>${body}</section></div>`;
}
function editAppDialog(add){
const app=getApp(modal.id)||state.apps.find(a=>!a.selected);
if(!app)return dialogShell("Apps",'<p>No apps available.</p>');
return dialogShell(app.name,`<form id="app-form"><input type="hidden" name="appId" value="${esc(app.id)}">
<div class="form-field"><label for="edit-category">Category</label><select id="edit-category" name="category">${categories.map(c=>`<option value="${c}" ${app.category===c?"selected":""}>${categoryName(c)}</option>`).join("")}</select><small>Change this to match how you use the app.</small></div>
<label class="reminder-check"><input type="checkbox" name="tracked" ${app.tracked?"checked":""}><span><strong>Track usage</strong><small>Turning this off keeps your existing history.</small></span></label><label class="reminder-check"><input type="checkbox" id="edit-enabled" name="enabled" ${app.selected&&app.enabled?"checked":""}><span><strong>Daily reminder</strong><small>Notify me when I reach the limit across devices.</small></span></label>
<div class="form-field" id="limit-field" ${app.selected&&app.enabled?"":"hidden"}><label for="edit-limit">Daily limit in minutes</label><input type="number" id="edit-limit" name="limit" required min="5" max="240" step="5" value="${app.limit||30}" ${app.selected&&app.enabled?"":"disabled"}></div>
<div class="dialog-actions"><button class="btn secondary" data-action="close" type="button">Cancel</button><button class="btn" type="submit">Save changes</button></div></form>`);
}

function editHobbyDialog(add){
const hobby=add?{id:"",name:"",time:"20:00",days:"Every day"}:getHobby(modal.id);
if(!hobby)return"";
return dialogShell(add?"Add an activity":"Edit "+hobby.name,`<form id="hobby-form"><div class="form-field"><label for="hobby-name">Activity</label><input id="hobby-name" name="name" maxlength="36" required placeholder="Reading, cooking, resting..." value="${esc(hobby.name)}"></div>
<div class="form-grid"><div class="form-field"><label for="hobby-time">From</label><input type="time" name="time" id="hobby-time" value="${esc(mins(hobby.time))}" required></div>
<div class="form-field"><label for="hobby-days">Preferred days</label><select id="hobby-days" name="days">${["Every day","Weekdays","Weekends","Whenever"].map(x=>`<option ${hobby.days===x?"selected":""}>${x}</option>`).join("")}</select></div></div>
<div class="form-grid"><div class="form-field"><label for="hobby-end">Until</label><input id="hobby-end" name="end" type="time" required value="${esc(hobby.end||endTime(hobby.time))}"></div><div class="form-field"><label for="hobby-duration">Duration (min)</label><input id="hobby-duration" type="number" name="duration" min="5" max="180" step="5" required value="${hobby.duration||20}"></div></div><div class="dialog-actions">${!add?`<button type="button" class="btn ghost" data-action="remove-hobby" data-id="${esc(hobby.id)}">Remove</button>`:""}<button class="btn secondary" data-action="close" type="button">Cancel</button><button class="btn" type="submit">Save activity</button></div>
</form>`,true);
}
function quietDialog(){
return dialogShell("Quiet hours",`<p>PAUSE will not show check-ins during these times.</p><form id="quiet-form"><div class="form-grid"><div class="form-field"><label for="quiet-start">Start</label><input id="quiet-start" name="start" type="time" value="${esc(state.quietStart)}" required></div><div class="form-field"><label for="quiet-end">End</label><input id="quiet-end" name="end" type="time" value="${esc(state.quietEnd)}" required></div></div><div class="dialog-actions"><button type="button" class="btn secondary" data-action="close">Cancel</button><button class="btn" type="submit">Save</button></div></form>`);
}
function reminderDialog(){
const app=getApp(modal.id)||selectedApps()[0]||state.apps[0],hobby=getHobby(alternateId)||suggestHobby();
return dialogShell(app.minutes>app.limit?`You're ${app.minutes-app.limit} min over your limit.`:app.minutes===app.limit?"You've reached your limit.":"Preview a check-in",`<p>${esc(app.name)} · ${app.minutes} minutes across your devices today.</p>
<div class="reminder-number">${app.minutes}<span> / ${app.limit} min</span></div>${meter(app)}
<div class="reminder-hobby"><span class="app-icon">${icon(hobbyIcon(hobby))}</span><div><strong>${hobby?esc(hobby.name):"Take a short break"}</strong><p>${hobby?`${hobby.duration||20} min · ${alternateId?"You chose this activity.":"Fits your preferred time."}`:"You can step away when you're ready."}</p></div></div>
<div class="reminder-actions"><button class="btn full" data-action="take-break">${hobby&&/read/i.test(hobby.name)?"Read now":hobby?"Start "+esc(hobby.name.toLowerCase()):"Take a break"} ${icon("arrow-right")}</button><button class="btn secondary full" data-action="snooze">15 more minutes</button><button class="btn ghost full" data-action="dismiss">Not today</button></div>
<div class="reminder-links"><button data-action="alternatives">Another activity</button><button data-action="feedback">Not helpful</button><button data-action="why">Why this suggestion?</button></div>`);
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
function extraDialog(){
const a=getApp(modal.id);
const footer='<div class="dialog-actions"><button class="btn secondary" type="button" data-action="close">Cancel</button><button class="btn" type="submit">Save</button></div>';
if(modal.type==="budget")return dialogShell("Entertainment budget",`<p>One daily limit across all entertainment apps and devices. Individual app limits remain optional.</p><form id="budget-form"><label class="reminder-check"><input type="checkbox" name="enabled" ${state.budgetEnabled?"checked":""}> Enable a total daily reminder</label><div class="form-field"><label for="budget-min">Minutes per day</label><input id="budget-min" name="budget" type="number" min="15" max="720" step="5" value="${state.budget}" required></div>${footer}</form>`);
if(modal.type==="timing")return dialogShell("Reminder timing",`<form id="timing-form"><div class="form-field"><label for="break-min">Default break (minutes)</label><input id="break-min" name="break" type="number" min="5" max="120" step="5" value="${state.breakMinutes}" required></div><div class="form-field"><label for="cooldown-min">Minimum between check-ins (minutes)</label><input id="cooldown-min" name="cooldown" type="number" min="15" max="180" step="5" value="${state.cooldown}" required></div>${footer}</form>`);
if(modal.type==="devices")return dialogShell("Device access",'<p>No live tracking connection in this web preview. Your sample activity and preferences stay in this browser.</p><div class="note"><strong>Mac:</strong> Native foreground-app tracking and notification access are required.<br><strong>iPhone:</strong> Native Screen Time authorization is required. Protected usage may not be shareable.</div><p>If access is unavailable, you can still set preferences and explore sample activity.</p><button class="btn full" data-action="close">Continue with sample data</button>');
if(modal.type==="board-settings")return dialogShell("Ambient board",`<p>Open the display in another tab of this browser. It receives generic demo messages only; no app names or usage figures.</p><label class="reminder-check"><span><strong>Follow demo check-ins</strong></span><button class="switch" role="switch" aria-label="Board reminders" aria-checked="${state.boardReminders}" data-action="toggle-board"></button></label><div class="btn-group" style="margin-top:18px"><a class="btn secondary" href="/" target="_blank" rel="noopener">Open board</a><button class="btn" data-action="board-test" ${state.boardReminders?"":"disabled"}>Send test</button></div>`);
if(modal.type==="simulate")return dialogShell("Simulate usage",`<p>Only sample values change. Actual device tracking is not connected.</p><form id="simulate-form"><div class="form-field"><label for="sim-app">App</label><select id="sim-app" name="appId">${state.apps.filter(a=>a.tracked).map(a=>`<option value="${esc(a.id)}">${esc(a.name)}</option>`).join("")}</select></div><div class="form-grid"><div class="form-field"><label for="sim-device">Device</label><select id="sim-device" name="device"><option value="mac">Mac</option><option value="phone">iPhone</option></select></div><div class="form-field"><label for="sim-min">Minutes</label><input id="sim-min" name="minutes" type="number" min="1" max="120" value="10" required></div></div><button class="btn full" type="submit" ${state.tracking?"":"disabled"}>Add sample time</button></form>`);
if(modal.type==="why"){const h=getHobby(alternateId)||suggestHobby();return dialogShell("Why this suggestion?",`<p>${h?esc(h.name)+(alternateId?" is the activity you selected.":" fits your saved activity window. Previous feedback helps avoid repeating poor suggestions."):"None of your saved activities fit this time. A simple break is an option."}</p><p class="note">This preview uses local rules, not a live AI service. No activity completion is inferred.</p><button class="btn secondary full" data-action="reminder" data-id="${esc(modal.appId)}">Back</button>`);}
if(modal.type==="menubar"){const h=nextHobby(),a=targets().find(a=>a.minutes>=a.limit);return dialogShell("PAUSE · Menu bar preview",`<p>Screen time today · sample data</p><div class="reminder-number">${fmt(total("mac"))}</div>${a?`<div class="note">${esc(a.name)} · ${a.minutes} / ${a.limit} min across devices</div>`:""}${h?`<div class="reminder-hobby">${icon(hobbyIcon(h))}<div><strong>${esc(h.name)}</strong><p>${hobbySchedule(h)}</p></div></div>`:""}<div class="btn-group"><button class="btn secondary" data-action="menu-pause">${state.paused?"Resume":"Pause"} reminders</button><button class="btn" data-action="menu-open">Open Today</button></div>`);}
if(modal.type==="app-detail"&&a)return dialogShell(a.name,`<p>${categoryName(a.category)} · ${scopeLabel()} · sample activity</p><div class="reminder-number">${fmt(used(a))}</div><div class="history-list">${series(a,deviceScope,"week").map((n,i)=>{const d=new Date();d.setDate(d.getDate()-6+i);return `<div class="settings-row"><span>${d.toLocaleDateString("en-US",{weekday:"short",month:"short",day:"numeric"})}</span><strong>${fmt(n)}</strong></div>`;}).join("")}</div><button class="btn secondary full" data-action="edit-app" data-id="${esc(a.id)}">Edit preferences</button>`);
return dialogShell("Unavailable","<p>This option is not available in this preview.</p>");
}
function renderDialog(){
document.body.style.overflow=modal?"hidden":"";root.inert=Boolean(modal);
if(!modal){dialogRoot.innerHTML="";if(modalFocus instanceof HTMLElement&&document.contains(modalFocus))modalFocus.focus();modalFocus=null;return;}
let html="";
if(modal.type==="add-app"||modal.type==="edit-app")html=editAppDialog(modal.type==="add-app");
if(modal.type==="add-hobby"||modal.type==="edit-hobby")html=editHobbyDialog(modal.type==="add-hobby");
if(modal.type==="quiet")html=quietDialog();
if(modal.type==="reminder")html=reminderDialog();
if(modal.type==="alternatives")html=alternativesDialog();
if(modal.type==="feedback")html=feedbackDialog();
if(modal.type==="approval")html=approvalDialog();
if(["budget","timing","devices","board-settings","simulate","why","app-detail","menubar"].includes(modal.type))html=extraDialog();
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
const h=getHobby(alternateId)||suggestHobby(),duration=h?.duration||state.breakMinutes;
const until=kind==="snooze"?Date.now()+900000:kind==="dismiss"?new Date().setHours(23,59,59,999):kind==="pause"?Date.now()+2700000:Date.now()+duration*60000;
const key=kind==="break"?"global":id||"global";
state.choices[key]={kind,appId:id,until};if(kind==="snooze"||kind==="pause")state.lastAlerts[id]=0;
if(state.boardReminders)persistBoard(kind==="break"?"break":"idle",null,until);
closeModal();navigate("today");announce(kind==="break"?"Break selected.":kind==="dismiss"?"No more reminders for this app today.":"Reminder paused.");
}
function withinQuiet(){
const [sh,sm]=state.quietStart.split(":").map(Number),[eh,em]=state.quietEnd.split(":").map(Number);
const d=new Date(),n=d.getHours()*60+d.getMinutes(),a=sh*60+sm,b=eh*60+em;
return a===b?false:a<b?n>=a&&n<b:n>=a||n<b;
}
function canAlert(app){
if(!app||activeChoice("global")||activeChoice(app.id))return false;
const last=state.lastAlerts[app.id]||0;const globalLast=state.lastDelivered||0;
return state.tracking&&state.reminders&&!state.paused&&!withinQuiet()&&app.tracked&&app.enabled&&app.minutes>=app.limit&&(!last||Date.now()-last>=state.cooldown*60000)&&(!globalLast||Date.now()-globalLast>=state.cooldown*60000);
}
function act(action,id,button){
if(action==="skip"){state.onboarded=true;state.view="today";announce("Demo started.");render(true);return;}
if(action==="back"){step=Math.max(0,step-1);render(true);return;}
if(action==="next"){
step=Math.min(5,step+1);render(true);return;}
if(action==="finish"){state.onboarded=true;state.view="today";step=0;render(true);announce("Your plan is ready.");return;}
if(action==="setup"){step=0;state.onboarded=false;closeModal();render(true);return;}
if(["budget","timing","devices","board-settings","simulate","app-detail","menubar"].includes(action)){showModal(action,id);return}if(action==="why"){modal={type:"why",appId:modal?.id};renderDialog();return}if(action==="menu-pause"){state.paused=!state.paused;render();if(state.paused)refreshBoard();renderDialog();return}if(action==="menu-open"){closeModal();navigate("today");return}if(action==="toggle-tracking"){state.tracking=!state.tracking;render(true);if(!state.tracking)refreshBoard();return}if(action==="toggle-board"){state.boardReminders=!state.boardReminders;save();refreshBoard();render();renderDialog();return}if(action==="board-test"){if(state.boardReminders){persistBoard("test");announce("Test message sent to this browser’s board.");}return}if(action==="advance-snooze"){for(const [k,c] of Object.entries(state.choices)){if(c.kind==="snooze"||c.kind==="pause"){delete state.choices[k];state.lastAlerts[k]=0;state.lastDelivered=0;}}render();checkIn();return}if(action==="add-app"||action==="edit-app"||action==="add-hobby"||action==="edit-hobby"||action==="quiet"){showModal(action,id);return}
if(action==="close"){if(modal?.type==="reminder"){state.lastAlerts[modal.id]=Date.now();save();if(state.boardReminders)refreshBoard();}closeModal();return}
if(action==="reminder"){if(modal?.type==="why"||modal?.type==="alternatives"){modal={type:"reminder",id};renderDialog();return}alternateId=null;const a=getApp(id)||chooseTarget()||getApp("discord");if(canAlert(a)){state.lastAlerts[a.id]=Date.now();state.lastDelivered=Date.now();save();if(state.boardReminders)persistBoard("reminder",suggestHobby(),Date.now()+300000);}showModal("reminder",a.id);return}
if(action==="alternatives"){const appId=modal?.id||"discord";modal={type:"alternatives",appId};renderDialog();return}
if(action==="choose-alternative"){const appId=modal?.appId||"discord";const old=suggestHobby();if(old&&old.id!==id){state.feedback.push({reason:"other",hobbyId:old.id,appId,at:Date.now()});state.feedback=state.feedback.slice(-100);save();}alternateId=id;modal={type:"reminder",id:appId};renderDialog();return}
if(action==="feedback"){modal={type:"feedback",appId:modal?.id||"discord"};renderDialog();return}
if(action==="feedback-reason"){feedbackReason=id;if(id==="other"){modal={type:"alternatives",appId:modal?.appId};renderDialog();return}modal={type:"approval",appId:modal?.appId||"discord"};renderDialog();return}
if(action==="approve-pause"){state.feedback.push({reason:feedbackReason,hobbyId:suggestHobby()?.id||null,appId:modal?.appId,at:Date.now()});state.feedback=state.feedback.slice(-100);finishChoice("pause",modal?.appId);return}
if(action==="take-break"){finishChoice("break",modal?.id);return}
if(action==="snooze"){finishChoice("snooze",modal?.id);return}
if(action==="dismiss"){finishChoice("dismiss",modal?.id);return}
if(action==="undo"){delete state.choices[id||"global"];render();refreshBoard();announce("Reminder preference restored.");return}
if(action==="toggle-reminders"){state.reminders=!state.reminders;render();if(!state.reminders)refreshBoard();announce(state.reminders?"Reminders on.":"Reminders off.");return}
if(action==="toggle-pause"){state.paused=!state.paused;render();if(state.paused)refreshBoard();announce(state.paused?"Reminder previews paused.":"Reminder previews resumed.");return}
if(action==="remove-app"){const a=getApp(id);if(a){a.selected=false;closeModal();render(true);announce(a.name+" removed from your plan.");}return}
if(action==="remove-hobby"){state.activities=state.activities.filter(h=>h.id!==id);closeModal();render(true);announce("Activity removed.");return}
if(action==="add-time"){
const a=getApp("discord");if(!a||!a.tracked||!state.tracking)return;
const before=a.minutes<a.limit;const target=deviceScope==="all"?device:deviceScope;a.usage[target]+=10;a.minutes=a.usage.mac+a.usage.phone;render();announce("Added ten sample minutes to Discord on "+(target==="mac"?"Mac":"iPhone")+".");
if(before&&canAlert(a))showModal("reminder",a.id);
return}
if(action==="reset"){if(!window.confirm("Reset the sample data and preferences?"))return;state=start();normalize();rollover();refreshBoard();deviceScope="all";step=0;closeModal();render(true);announce("Demo reset.");return}
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
if(el.id==="edit-category"||el.id==="edit-enabled"){
const check=document.getElementById("edit-enabled"),field=document.getElementById("limit-field"),input=document.getElementById("edit-limit");
if(el.id==="edit-category"&&check){/* category and reminder are independent */}
if(check&&field&&input){field.hidden=!check.checked;input.disabled=!check.checked;}
return;
}
if(el.dataset.onboardCategory){const a=getApp(el.dataset.onboardCategory);if(a&&categories.includes(el.value)){a.category=el.value;if(!a.explicitReminder)a.selected=a.enabled=el.value==="entertainment";render();root.querySelector('[data-onboard-category="'+a.id+'"]')?.focus();}return;}
if(el.dataset.onboardApp){const a=getApp(el.dataset.onboardApp);if(a){a.selected=el.checked;a.enabled=el.checked;a.explicitReminder=true;save();}return}
if(el.dataset.onboardLimit){const a=getApp(el.dataset.onboardLimit);if(a){a.limit=Number(el.value)||30;save();}return}
if(el.dataset.onboardTime){const h=getHobby(el.dataset.onboardTime);if(h){h.time=mins(el.value);save();}return}
if(el.dataset.onboardEnd){const h=getHobby(el.dataset.onboardEnd);if(h){h.end=mins(el.value);save();}return}if(el.dataset.onboardDuration){const h=getHobby(el.dataset.onboardDuration);if(h){h.duration=Math.max(5,Math.min(180,Number(el.value)||20));save();}return}if(el.dataset.onboardDays){const h=getHobby(el.dataset.onboardDays);if(h){h.days=el.value;save();}return}
if(el.dataset.period){state.period=el.dataset.period;render();return}
});
document.addEventListener("click",e=>{const b=e.target.closest("button[data-period],button[data-scope]");if(!b)return;if(b.dataset.scope){if(!["all","mac","phone"].includes(b.dataset.scope))return;deviceScope=b.dataset.scope;render();root.querySelector('.device-filter [data-scope="'+deviceScope+'"]')?.focus();announce("Showing "+scopeLabel()+" sample activity.");return;}if(b.dataset.period){state.period=b.dataset.period;render();root.querySelector('[data-period="'+state.period+'"]')?.focus();}});
document.addEventListener("submit",e=>{
if(!["app-form","hobby-form","quiet-form","budget-form","timing-form","simulate-form"].includes(e.target.id))return;e.preventDefault();
const f=new FormData(e.target);
if(e.target.id==="budget-form"){state.budgetEnabled=f.has("enabled");state.budget=Math.max(15,Math.min(720,Number(f.get("budget"))||90));closeModal();render(true);return;}
if(e.target.id==="timing-form"){state.breakMinutes=Math.max(5,Number(f.get("break"))||20);state.cooldown=Math.max(15,Number(f.get("cooldown"))||30);closeModal();render(true);return;}
if(e.target.id==="simulate-form"){const a=getApp(String(f.get("appId"))),d=String(f.get("device")),n=Number(f.get("minutes"));if(!state.tracking||!a?.tracked||!["mac","phone"].includes(d)||!Number.isFinite(n)||n<1||n>120){announce("Tracking is paused or the sample input is invalid.");return;}rollover();state.demoArmed=true;a.usage[d]+=Math.round(n);a.minutes=a.usage.mac+a.usage.phone;closeModal();render(true);checkIn();return;}
if(e.target.id==="app-form"){
const id=String(f.get("appId"));const a=getApp(id);if(!a)return;
const category=String(f.get("category")||a.category);if(!categories.includes(category))return;
const enabled=f.has("enabled"),limit=enabled?Number(f.get("limit")):a.limit;
if(enabled&&(!Number.isFinite(limit)||limit<5||limit>240||limit%5!==0)){announce("Choose a limit from 5 to 240 minutes in steps of five.");return}
a.category=category;a.tracked=f.has("tracked");a.selected=enabled;a.enabled=enabled;a.explicitReminder=true;a.limit=limit||30;closeModal();render(true);announce(a.name+" preferences saved.");return;
}
if(e.target.id==="hobby-form"){
const name=String(f.get("name")||"").trim().slice(0,36),time=mins(String(f.get("time")||"20:00")),days=String(f.get("days")||"Every day");
if(!name){announce("Enter an activity name.");return}
if(modal?.type==="add-hobby")state.activities.push({id:"h"+Date.now(),name,time,days,end:mins(String(f.get("end")||endTime(time))),duration:Number(f.get("duration"))||20,selected:true});
else {const h=getHobby(modal?.id);if(h){h.name=name;h.time=time;h.days=days;h.end=mins(String(f.get("end")||endTime(time)));h.duration=Number(f.get("duration"))||20;}}
closeModal();render(true);announce("Activity saved.");return;
}
if(e.target.id==="quiet-form"){state.quietStart=String(f.get("start")||"22:00");state.quietEnd=String(f.get("end")||"08:00");closeModal();render(true);announce("Quiet hours saved.");}
});
document.addEventListener("keydown",e=>{
if(!modal)return;
if(e.key==="Escape"){e.preventDefault();act("close");return}
if(e.key!=="Tab")return;
const nodes=[...dialogRoot.querySelectorAll("button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href]")].filter(n=>n.getClientRects().length);
if(!nodes.length)return;
const first=nodes[0],last=nodes[nodes.length-1];
if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}
else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}
});
document.addEventListener("click",e=>{if(e.target.classList.contains("dialog-backdrop"))act("close")});
root.addEventListener("click",e=>{const a=e.target.closest("a[data-view]");if(a){e.preventDefault();navigate(a.dataset.view)}});
render();
window.addEventListener("storage",e=>{if(e.key!==KEY||!e.newValue)return;const incoming=parse(e.newValue);if(!incoming)return;const view=state.view;state={...start(),...incoming,view};normalize();rollover();if(modal?.type==="reminder"&&(activeChoice("global")||activeChoice(modal.id)||!state.reminders||state.paused||!state.tracking||!getApp(modal.id)?.enabled)){closeModal();}if(!modal){root.innerHTML=state.onboarded?shell(state.view==="today"?today():state.view==="activity"?activity():state.view==="plan"?plan():settings()):onboarding();iconRefresh();}});
setInterval(()=>{if(document.hidden||modal)return;const changed=rollover();if(changed){render();return;}const expired=Object.entries(state.choices).filter(([k,c])=>c.until<=Date.now());if(expired.length){for(const [k,c] of expired){delete state.choices[k];if(c.kind==="snooze"||c.kind==="pause"){state.lastAlerts[k]=0;if(Date.now()-(state.lastDelivered||0)>=900000)state.lastDelivered=0;}}render();refreshBoard();checkIn();}else if(state.demoArmed){checkIn();}},1500);
})();