const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const root=path.resolve(__dirname,"..");
const load=p=>fs.readFileSync(path.join(root,p),"utf8");
const web=load("index.html");
const css=load("design/board-hardware.css");
const local=load("controller.html");
const cloud=load("cloud.html");
const cloudJS=load("cloud/controller.js");
const ios=load("ios/App/PAUSEBoardView.swift");
const mac=load("macos/App/MacDashboard.swift");

// The design must depict a single real object, not colored UI confetti.
assert.match(web, /<body class="pause-board-page">/);
assert.match(web, /design\/board-hardware\.css/);
assert.match(web, /class="board-shell"/);
assert.match(web, /class="board-wordmark"/);
assert.match(web, /print\.className='printed-glyph'/);
assert.match(web, /const ROWS=6,COLS=22,TOTAL=132/);
assert.match(css, /aspect-ratio:\s*1\.865/);
assert.match(css, /aspect-ratio:\s*\.625/);
assert.match(css, /position:\s*absolute;\s*left:\s*7%;\s*top:\s*50%/);
assert.match(css, /transform:\s*translateY\(-50%\)/);
assert.match(css, /\.tile \.seam/);
assert.match(css, /\.printed-glyph/);
assert.match(css, /\.tile\.flipping \.printed-glyph/);
assert.match(css, /\.color-yellow \.upper/);
assert.match(css, /\.color-blue \.lower/);

// Four chromatic rows and two type rows exactly fill 6 × 22.
const match=web.match(/title:'Chromatic pause'[^\n]*message:\[([^\]]+)\]\.join\('\\n'\)/u);
assert.ok(match,"The first preset should render the physical split-flap idle scene.");
const rows=[...match[1].matchAll(/'([^']*)'/gu)].map(m=>m[1]);
assert.equal(rows.length,6);
for(const row of rows)assert.equal(Array.from(row).length,22,JSON.stringify(row));
const colors=/[🟥🟧🟨🟩🟦🟪]/u;
assert.ok(rows.slice(0,2).every(x=>colors.test(x)));
assert.ok(rows.slice(4,6).every(x=>colors.test(x)));
assert.ok(rows[2].includes("LESS SCREEN")&&rows[3].includes("MORE LIFE"));

// Every preview uses the same physical silhouette and supports color flaps.
for(const markup of [local,cloud]){
 assert.match(markup,/design\/board-hardware\.css/);
 assert.match(markup,/class="board-wordmark"/);
}
assert.match(local,/dataset\.color/);
assert.match(cloudJS,/dataset\.color/);
assert.match(ios,/width \/ 1\.865/);
assert.match(mac,/width \/ 1\.865/);
assert.match(ios,/cellWidth \/ 0\.625/);
assert.match(mac,/cellWidth \/ 0\.625/);
console.log("PAUSE physical-board geometry, 132 cells, color layout, and native preview contracts pass.");
