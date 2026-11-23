/* Opt-in companion demo receiver. Same-origin, same-browser only. No network access. */
(()=>{
"use strict";
const KEY="pause-demo-board-v1";
let last="",following=false;
function update(){
 if(!window.PauseBoard||window.PauseCloudBoard?.isHeld?.())return;
 let s=null;try{s=JSON.parse(localStorage.getItem(KEY)||"null")}catch{}
 const active=Boolean(s?.enabled);
 if(!active&&!following)return;
 const message=active&&s.until>Date.now()?String(s.message||"LESS SCREEN\nMORE LIFE"):"LESS SCREEN\nMORE LIFE";
 const revision=(active?String(s.revision):"off")+":"+message;
 if(revision===last)return;
 last=revision;following=active;
 window.PauseBoard.display(message);
 const shell=document.querySelector(".board-shell");
 if(shell)shell.setAttribute("aria-label",message.replace(/\n+/g,". "));
}
window.addEventListener("storage",e=>{if(e.key===KEY)update()});
window.addEventListener("focus",update);setInterval(update,2000);update();
})();
