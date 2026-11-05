/* PAUSE V2: local ActivityWatch integration, controls and deterministic interventions.
   No AI service, cloud sync, or device-wide iPhone tracking is used in this version. */
(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const defaults = {
    mode: "live", enabled: true, tone: "playful", persistence: "balanced",
    limits: {social:20, creative:90, entertainment:45},
    overrides: {}, feedback: {}, snoozeUntil:0, lastNudged:{}
  };
  const read = () => { try {return JSON.parse(localStorage.getItem("pause-v2-settings")) || {}} catch {return {}} };
  const old = read();
  const config = {...defaults,...old,limits:{...defaults.limits,...(old.limits||{})},
                  overrides:old.overrides||{}, feedback:old.feedback||{},lastNudged:old.lastNudged||{}};
  const save = () => {try{localStorage.setItem("pause-v2-settings",JSON.stringify(config))}catch{}};
  const esc = value => String(value).replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
  const minutes = secs => Math.max(0,Math.floor((Number(secs)||0)/60));
  const pretty = secs => {const mins=minutes(secs);return mins>=60?`${Math.floor(mins/60)}h ${mins%60}m`:`${mins}m`};
  const clamp = (value,low,high) => Math.max(low,Math.min(high,Number(value)||low));
  const categories = ["social","creative","entertainment","other","ignore"];
  const labels = {social:"Social",creative:"Creative / work",entertainment:"Entertainment",other:"Other",ignore:"Ignore"};
  const coolDown = {subtle:60,balanced:30,assertive:15};
  let localConnected=false, liveData=null, liveError="Local companion not detected.", activeNudge=null,
      lastAmbientAt=0, lastAmbientMinutes=-1, panelVisible=false, demoSeconds=5*60;
  let demoKind="social", nowLoading=false, startDone=false, toastTimer=null;

  const trigger=document.createElement("button");
  trigger.type="button"; trigger.className="attention-trigger";
  trigger.id="attentionTrigger";
  trigger.innerHTML='<span class="attention-led" id="attentionLed"></span><span id="attentionButtonText">Attention</span>';
  const controls=document.querySelector(".top-actions");
  controls.insertBefore(trigger,controls.firstChild);

  const layer=document.createElement("div");
  layer.className="attention-layer";layer.id="attentionLayer";layer.setAttribute("aria-hidden","true");
  layer.innerHTML=`<aside class="attention-panel" role="dialog" aria-modal="true" aria-labelledby="attentionTitle">
    <div class="attention-content">
      <div class="attention-panel-head"><h2 id="attentionTitle">Your attention</h2><button id="attentionClose" type="button" aria-label="Close attention settings">×</button></div>
      <p class="attention-sub">Not all screen time is the same. Decide when PAUSE should interrupt — and when it should stay quiet.</p>
      <div class="attention-switch" role="group" aria-label="Activity source">
        <button id="liveModeBtn" type="button" aria-pressed="true">Mac activity</button>
        <button id="demoModeBtn" type="button" aria-pressed="false">Demo mode</button>
      </div>
      <div class="status-card" aria-live="polite">
        <div class="status-title"><span class="attention-led" id="sourceLed"></span><span id="sourceTitle">Connecting…</span></div>
        <p id="sourceHelp" class="status-help">Checking the local ActivityWatch connector.</p>
      </div>
      <div class="attention-metrics">
        <div class="metric"><div id="totalMetric" class="value">—</div><div class="meta">Active Mac time today</div></div>
        <div class="metric"><div id="socialMetric" class="value">—</div><div class="meta">Social websites / apps</div></div>
        <div class="metric"><div id="creativeMetric" class="value">—</div><div class="meta">Creative / work time</div></div>
      </div>
      <div class="live-source"><div><strong id="currentName">Nothing active</strong><small id="currentDescription">Waiting for activity</small></div><span id="currentDuration" class="duration">—</span></div>
      <div id="demoControls" class="hidden-attention"><div class="section-label">Simulate screen time</div>
        <div class="demo-actions">
          <button type="button" data-demo="social">Instagram</button>
          <button type="button" data-demo="creative">Figma</button>
          <button type="button" data-demo="entertainment">YouTube</button>
          <button type="button" id="demoAdd">+5 min</button>
          <button type="button" id="demoReset">Reset</button>
        </div><p class="status-help">These events are simulated. They are not actual screen-time measurements.</p></div>
      <div class="section-label">Interventions</div>
      <div class="form-row"><label for="nudgesEnabled">Enable nudges</label><input id="nudgesEnabled" type="checkbox" /></div>
      <div id="limitsControls">
        <div class="rule"><div class="rule-head"><label for="socialLimit">Social app limit</label><output id="socialOutput"></output></div><input id="socialLimit" type="range" min="5" max="120" step="5"><small>More direct when a continuous session exceeds your limit</small></div>
        <div class="rule"><div class="rule-head"><label for="creativeLimit">Creative / work break</label><output id="creativeOutput"></output></div><input id="creativeLimit" type="range" min="15" max="240" step="15"><small>A gentle invitation after extended focus</small></div>
        <div class="rule"><div class="rule-head"><label for="entertainmentLimit">Entertainment limit</label><output id="entertainmentOutput"></output></div><input id="entertainmentLimit" type="range" min="10" max="180" step="5"><small>A check-in when watching or browsing runs long</small></div>
        <div class="form-row"><label for="toneSelect">Board personality</label><select id="toneSelect" class="attention-select"><option value="gentle">Gentle</option><option value="playful">Playful</option><option value="direct">Straightforward</option></select></div>
        <div class="form-row"><label for="persistenceSelect">Reminder intensity</label><select id="persistenceSelect" class="attention-select"><option value="subtle">Subtle · 60m cooldown</option><option value="balanced">Balanced · 30m cooldown</option><option value="assertive">Assertive · 15m cooldown</option></select></div>
        <button id="testNudge" class="soft-action" type="button">Preview a nudge on the board ↗</button>
      </div>
      <div class="section-label">App-specific rules</div>
      <p class="status-help">Change how PAUSE categorizes detected apps and sites. Set an optional individual limit (minutes). Empty means use the category limit.</p>
      <div id="detectedApps"></div>
      <div class="section-label">Privacy & behavior</div>
      <div class="attention-note">PAUSE reads summarized activity through a local bridge. It does not collect page titles or URL paths, upload activity to a cloud service, or access iPhone Screen Time. Interventions use explicit timing rules, not AI predictions yet. Live mode works only when the local companion is running.</div>
    </div></aside>`;
  document.body.append(layer);
  const banner=document.createElement("div");banner.className="nudge-banner";banner.id="nudgeBanner";
  banner.innerHTML=`<div class="nudge-header"><strong>PAUSE has a thought</strong><button type="button" class="nudge-close" id="nudgeDismiss" aria-label="Dismiss">×</button></div>
    <p id="nudgeSubtitle">You can ignore this or decide what to do next.</p>
    <div class="nudge-actions"><button type="button" data-response="break">Take a break</button><button type="button" data-response="continue">Keep going</button><button type="button" data-response="unhelpful">Not helpful</button></div>`;
  document.body.append(banner);
  const board = message => {
    if (window.PauseRemote?.isHeld?.()) return;
    if (window.PauseBoard && window.PauseBoard.display) window.PauseBoard.display(message);
  };
  function activeData(){
    if(config.mode==="demo")return demoData();
    return liveData && liveData.connected ? liveData : null;
  }
  function demoData(){
    const names={social:"instagram.com",creative:"Figma",entertainment:"youtube.com"};
    const id=demoKind==="creative"?"app:figma":"site:"+names[demoKind];
    const name=names[demoKind], category=demoKind;
    return {connected:true, demo:true, total_seconds:demoSeconds+75*60,
      current:{id,name,category,session_seconds:demoSeconds,seconds_today:demoSeconds},
      items:[{id,name,category,seconds:demoSeconds},{id:"app:other",name:"Other activity",category:"other",seconds:75*60}],
      buckets:{window:true,web:true,afk:true}};
  }
  function getCategory(item){
    const override=config.overrides[item.id];
    return (override&&override.category)||item.category||"other";
  }
  function limitFor(item){
    const override=config.overrides[item.id];
    const cat=getCategory(item);
    const value=override&&override.limit;
    return value>=1?Number(value):(config.limits[cat]||0);
  }
  function currentNudge(item){
    if(!item||!config.enabled||Date.now()<config.snoozeUntil)return null;
    const cat=getCategory(item);
    if(!["social","creative","entertainment"].includes(cat))return null;
    const limit=limitFor(item);
    if(!limit||minutes(item.session_seconds)<limit)return null;
    const recent=config.lastNudged[item.id]||0;
    if(Date.now()-recent<coolDown[config.persistence]*60000)return null;
    return {item,cat,limit};
  }
  function messageFor(nudge){
    const {item,cat,limit}=nudge;
    const elapsed=minutes(item.session_seconds);
    const where=(item.name||"THIS APP").toUpperCase().replace(/[^A-Z0-9 .-]/g,"").slice(0,18);
    if(cat==="creative"){
      if(config.tone==="direct")return `${elapsed} MIN ON ${where}\n\nTIME TO STRETCH?\nA BREAK CAN HELP.`;
      if(config.tone==="gentle")return `YOU HAVE BEEN IN\n${where} FOR ${elapsed} MIN\n\nHOW ABOUT A BREAK?`;
      return `${elapsed} MIN IN ${where}\n\nYOUR SHOULDERS JUST\nREQUESTED A BREAK.`;
    }
    if(config.tone==="gentle")return `YOU HAVE SPENT\n${elapsed} MIN ON ${where}\n\nREADY TO STEP AWAY?`;
    if(config.tone==="direct")return `${where}: ${elapsed} MIN\nYOUR LIMIT: ${limit} MIN\n\nTIME TO LOG OFF?`;
    if(cat==="social")return `${where}: ${elapsed} MIN\nYOUR PLAN: ${limit} MIN\n\nSTILL SCROLLING?\nTAKE A LITTLE PAUSE.`;
    return `${elapsed} MIN ON ${where}\n\nONE MORE EPISODE?\nOR A REAL BREAK?`;
  }
  function showNudge(nudge,force=false){
    if(!nudge)return;
    if(!force&&activeNudge&&activeNudge.item.id===nudge.item.id)return;
    activeNudge=nudge;
    config.lastNudged[nudge.item.id]=Date.now();save();
    board(messageFor(nudge));
    $("nudgeSubtitle").textContent=`${nudge.item.name} · ${minutes(nudge.item.session_seconds)} minutes in this session. Respond only if useful.`;
    banner.classList.add("visible");
  }
  function ambient(force=false){
    if(activeNudge && !force)return;
    const data=activeData();
    if(!data)return;
    const total=minutes(data.total_seconds||0);
    if(!force && Date.now()-lastAmbientAt<10*60000)return;
    if(!force && Math.abs(total-lastAmbientMinutes)<10)return;
    lastAmbientMinutes=total;lastAmbientAt=Date.now();
    const h=Math.floor(total/60),m=total%60;
    const amount=h?`${h} HOUR${h===1?"":"S"} ${m} MIN`:`${m} MINUTES`;
    board(`TODAY ON YOUR MAC\n\n${amount}\nOF ACTIVE SCREEN TIME\n\nMAKE SPACE TO NOTICE`);
  }
  function hideNudge(){
    banner.classList.remove("visible");activeNudge=null;
  }
  function respond(kind){
    if(!activeNudge)return;
    const id=activeNudge.item.id;
    const feedback=config.feedback[id]||{break:0,continue:0,unhelpful:0};
    feedback[kind]=(feedback[kind]||0)+1;config.feedback[id]=feedback;
    let pauseMinutes=15;
    if(kind==="break"){pauseMinutes=30;board("A MOMENT AWAY\nFROM YOUR SCREEN\n\nENJOY YOUR BREAK");}
    else if(kind==="continue"){pauseMinutes=15;board("YOUR CHOICE.\n\nWE WILL BE QUIET\nFOR A LITTLE WHILE");}
    else{pauseMinutes=60;board("GOT IT.\n\nLESS OF THAT\nFROM NOW ON.");}
    config.snoozeUntil=Date.now()+pauseMinutes*60000;
    config.lastNudged[id]=Date.now();
    save();hideNudge();render();
    if(kind==="unhelpful"&&feedback.unhelpful>=2)toast("You dismissed this nudge twice. Consider raising its limit in settings.");
  }
  function toast(message){
    const old=document.querySelector(".attention-toast");if(old)old.remove();
    const element=document.createElement("div");element.className="attention-toast";element.textContent=message;
    document.body.append(element);clearTimeout(toastTimer);toastTimer=setTimeout(()=>element.remove(),4500);
  }
  function refreshBoard(){
    const data=activeData();
    if(!data||!data.current){ambient();return}
    const nudge=currentNudge(data.current);
    if(nudge)showNudge(nudge);
    else ambient();
  }
  async function poll(){
    if(nowLoading)return;nowLoading=true;
    try{
      const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),6000);
      let response;
      try{response=await fetch("/pause-api/status",{cache:"no-store",signal:controller.signal})}finally{clearTimeout(timeout)}
      if(!response.ok)throw new Error("Local bridge unavailable");
      const data=await response.json();
      localConnected=!!data.connected;liveData=data;
      liveError=data.error || (localConnected?"": "ActivityWatch isn't running.");
    }catch(err){
      localConnected=false;liveData=null;liveError="PAUSE local companion not connected. Run python3 bridge.py on your Mac.";
    }finally{
      nowLoading=false;
      if(!startDone){startDone=true;if(!localConnected&&config.mode==="live")config.mode="demo";save();ambient(true)}
      if(config.mode==="live")refreshBoard();
      if(panelVisible)render();updateStatusButton();
    }
  }
  function updateStatusButton(){
    const live=config.mode==="live" && localConnected;
    $("attentionLed").className="attention-led"+(live?" is-live":" is-demo");
    $("attentionButtonText").textContent=live?"Live activity":config.mode==="demo"?"Demo mode":"Offline";
  }
  function render(){
    const demo=config.mode==="demo", data=activeData(), available=!!data;
    $("liveModeBtn").setAttribute("aria-pressed",String(!demo));
    $("demoModeBtn").setAttribute("aria-pressed",String(demo));
    $("sourceLed").className="attention-led"+(demo?" is-demo":localConnected?" is-live":"");
    $("sourceTitle").textContent=demo?"Simulation (not real activity)":localConnected?"ActivityWatch connected":"Mac tracking unavailable";
    const bucketInfo=data?.buckets||{};
    const warnings=[];
    if(!demo){
      if(!localConnected)warnings.push(liveError);
      else{
        if(data.error)warnings.push(data.error);
        if(data.warning)warnings.push(data.warning);
        if(!bucketInfo.web)warnings.push("Browser extension not detected — website-specific nudges won't work.");
        if(!bucketInfo.afk)warnings.push("Idle-time watcher missing.");
      }
    }
    $("sourceHelp").textContent=demo?"Use the controls below to simulate app activity and test nudges. No device data is read.":warnings.length?warnings.join(" "):"Live local Mac usage. Website hostnames only; no page titles or full URLs.";
    $("totalMetric").textContent=available?pretty(data.total_seconds):"—";
    const categoryTotal=cat=>available?data.items.filter(x=>getCategory(x)===cat).reduce((s,x)=>s+x.seconds,0):null;
    $("socialMetric").textContent=available?pretty(categoryTotal("social")):"—";
    $("creativeMetric").textContent=available?pretty(categoryTotal("creative")):"—";
    $("currentName").textContent=data?.current?.name||"Nothing active";
    $("currentDescription").textContent=data?.current?`${labels[getCategory(data.current)]||"Other"} · current session`:"No current active app";
    $("currentDuration").textContent=data?.current?pretty(data.current.session_seconds):"—";
    $("demoControls").classList.toggle("hidden-attention",!demo);
    $("nudgesEnabled").checked=!!config.enabled;
    ["social","creative","entertainment"].forEach(cat=>{
      $(cat+"Limit").value=config.limits[cat];
      $(cat+"Output").textContent=config.limits[cat]+" min";
    });
    $("toneSelect").value=config.tone;
    $("persistenceSelect").value=config.persistence;
    const entries=(data?.items||[]).filter(item=>item.id!=="app:other").slice(0,16);
    $("detectedApps").innerHTML=entries.length?entries.map((item,i)=>{
      const cat=getCategory(item),override=config.overrides[item.id]||{};
      const choices=categories.map(option=>`<option value="${option}" ${cat===option?"selected":""}>${labels[option]}</option>`).join("");
      return `<div class="app-row" data-index="${i}">
      <div><div class="app-name" title="${esc(item.name)}">${esc(item.name)}</div><div class="app-min">${pretty(item.seconds)} today</div></div>
      <select class="attention-select app-category" aria-label="Category for ${esc(item.name)}">${choices}</select>
      <input class="app-limit" type="number" min="1" max="600" step="1" placeholder="Auto" value="${override.limit||""}" aria-label="Individual limit in minutes for ${esc(item.name)}">
      </div>`;
    }).join(""):'<p class="status-help">No detected apps yet. Use Demo mode, or start ActivityWatch and use your Mac for a few minutes.</p>';
    layer._items=entries;
    updateStatusButton();
  }
  function open(){
    if(window.PauseBoard?.closePanel)window.PauseBoard.closePanel();
    panelVisible=true;render();layer.classList.add("is-open");layer.setAttribute("aria-hidden","false");$("attentionClose").focus();
  }
  function close(){panelVisible=false;layer.classList.remove("is-open");layer.setAttribute("aria-hidden","true");trigger.focus()}
  trigger.addEventListener("click",open);
  $("attentionClose").addEventListener("click",close);
  layer.addEventListener("click",event=>{if(event.target===layer)close()});
  document.addEventListener("keydown",event=>{if(event.key==="Escape"&&panelVisible)close()});
  $("liveModeBtn").addEventListener("click",()=>{config.mode="live";save();hideNudge();render();ambient(true);refreshBoard();if(!localConnected)toast("Start the local companion to enable live tracking.")});
  $("demoModeBtn").addEventListener("click",()=>{config.mode="demo";save();hideNudge();render();ambient(true)});
  $("nudgesEnabled").addEventListener("change",event=>{config.enabled=event.target.checked;save();if(!config.enabled)hideNudge()});
  ["social","creative","entertainment"].forEach(cat=>$(cat+"Limit").addEventListener("input",event=>{
    config.limits[cat]=Number(event.target.value);$(cat+"Output").textContent=config.limits[cat]+" min";save();
  }));
  $("toneSelect").addEventListener("change",event=>{config.tone=event.target.value;save()});
  $("persistenceSelect").addEventListener("change",event=>{config.persistence=event.target.value;save()});
  $("detectedApps").addEventListener("change",event=>{
    const row=event.target.closest(".app-row");if(!row)return;
    const item=layer._items?.[Number(row.dataset.index)];if(!item)return;
    const settings=config.overrides[item.id]||{};
    if(event.target.matches(".app-category"))settings.category=event.target.value;
    if(event.target.matches(".app-limit"))settings.limit=event.target.value?clamp(event.target.value,1,600):null;
    config.overrides[item.id]=settings;save();render();
  });
  $("testNudge").addEventListener("click",()=>{
    const data=activeData(),source=data?.current||{id:"site:instagram.com",name:"instagram.com",category:"social",session_seconds:40*60};
    const cat=getCategory(source);
    const mock={...source,category:cat==="other"||cat==="ignore"?"social":cat};
    const nudge={item:mock,cat:mock.category,limit:limitFor(mock)||20};
    hideNudge();showNudge(nudge,true);close();
  });
  document.querySelectorAll("[data-demo]").forEach(btn=>btn.addEventListener("click",()=>{
    demoKind=btn.dataset.demo;demoSeconds=5*60;config.lastNudged={};save();hideNudge();render();ambient(true);
  }));
  $("demoAdd").addEventListener("click",()=>{
    demoSeconds+=5*60;render();refreshBoard();if(minutes(demoSeconds)%10===0&&!activeNudge)ambient(true);
  });
  $("demoReset").addEventListener("click",()=>{
    demoSeconds=5*60;config.lastNudged={};config.snoozeUntil=0;save();hideNudge();render();ambient(true);
  });
  banner.addEventListener("click",event=>{const btn=event.target.closest("[data-response]");if(btn)respond(btn.dataset.response)});
  $("nudgeDismiss").addEventListener("click",()=>respond("continue"));
  // The first read picks real data if the bridge is available, otherwise demo
  // is explicitly labelled as a simulation. No fake data shown as live.
  poll();
  setInterval(poll,15000);
  setInterval(()=>{
    if(activeNudge){
      const id=activeNudge.item.id;
      if(Date.now()-config.lastNudged[id]>90000){hideNudge();ambient(true)}
    }
  },10000);
})();
