(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  const client = window.PauseCloud;
  const cells = [];
  let interval = null;

  for (let i = 0; i < 132; i++) {
    const tile = document.createElement("span");
    tile.className = "tile";
    $("board").appendChild(tile);
    cells.push(tile);
  }

  const colors = {'🟥':'red','🟧':'orange','🟨':'yellow','🟩':'green','🟦':'blue','🟪':'violet','⬜':'white'};
  function boardFormat(value) {
    const rows = [];
    const cleaned=String(value||'').toUpperCase().replace(/[^A-Z0-9 .,?!+:/&@\-\n🟥🟧🟨🟩🟦🟪⬜]/gu,' ');
    for (const line of cleaned.split('\n')) {
      const chars=Array.from(line);
      if(chars.length===22 && chars.some(ch=>colors[ch])) { rows.push(line); continue; }
      if (!line.trim()) { rows.push(''); continue; }
      let current='';
      for(const word of line.trim().split(/\s+/)) {
        const letters=Array.from(word);
        if(letters.length>22) {
          if(current) {rows.push(current);current='';}
          for(let i=0;i<letters.length;i+=22) rows.push(letters.slice(i,i+22).join(''));
        }else if(Array.from(current).length+(current?1:0)+letters.length>22) {
          rows.push(current); current=word;
        }else current+=(current?' ':'')+word;
      }
      if(current)rows.push(current);
    }
    const tiles=Array(132).fill(' '),active=rows.slice(0,6);
    active.forEach((line,i)=>{
      const letters=Array.from(line);
      const start=(Math.floor((6-active.length)/2)+i)*22+Math.floor((22-letters.length)/2);
      letters.forEach((ch,j)=>{if(j<22)tiles[start+j]=ch;});
    });
    return {tiles,overflow:rows.length>6};
  }
  function preview(value) {
    const {tiles,overflow}=boardFormat(value);
    cells.forEach((cell,i)=>{
      const ch=tiles[i];
      if(colors[ch])cell.dataset.color=colors[ch];else delete cell.dataset.color;
      cell.textContent=ch===' '||colors[ch]?'':ch;
    });
    $('count').textContent=Array.from(value).length+' / 280 characters'+
      (overflow?' · Preview exceeds six rows':'');
    $('send').disabled=overflow||!value.trim();
    return !overflow;
  }

  function status(message, error = false) {
    $("status").textContent = message;
    $("status").className = error ? "error" : "";
  }

  function visible() {
    const signed = client.isSignedIn;
    $("ready").classList.toggle("hidden", !signed);
    $("connectForm").classList.toggle("hidden", signed);
    $("user").textContent = signed ? "Signed in" : "";
    if (signed) {
      loadRemote().catch(e => status(e.message, true));
      if (!interval) interval = setInterval(() => loadRemote().catch(() => {}), 12000);
    } else {
      if (interval) clearInterval(interval);
      interval = null;
    }
  }

  async function loadRemote() {
    if (!client.isSignedIn) return;
    const [board, usage, devices] = await Promise.all([
      client.getBoard(), client.getDaily(), client.getDevices()
    ]);
    if (board) {
      $("boardUpdated").textContent = new Date(board.updated_at).toLocaleString();
      // Only update the preview if the user isn't actively composing.
      if (document.activeElement !== $("message")) preview(board.message || "");
    }
    const amounts = {};
    for (const row of usage || []) {
      const category = row.category || "other";
      amounts[category] = (amounts[category] || 0) + row.seconds;
    }
    $("usage").replaceChildren();
    if (!Object.keys(amounts).length) {
      $("usage").textContent = "No synced category totals yet.";
    } else {
      for (const [category, seconds] of Object.entries(amounts)) {
        const row = document.createElement("div");
        row.className = "metric";
        const label = document.createElement("span");
        label.textContent = category[0].toUpperCase() + category.slice(1);
        const value = document.createElement("strong");
        value.textContent = Math.floor(seconds / 3600) + "h " +
          Math.floor((seconds % 3600) / 60) + "m";
        row.append(label, value);
        $("usage").appendChild(row);
      }
    }
    $("devices").textContent = devices?.length ?
      devices.map(d => d.label + " · " + d.kind).join(" · ") :
      "No devices connected yet";
  }

  $("url").value = client.config.url || "";
  $("key").value = client.config.key || "";
  $("saveConfig").addEventListener("click", () => {
    try {
      client.configure($("url").value, $("key").value.trim());
      status("Project saved. Sign in to continue.");
    } catch (error) { status(error.message, true); }
  });
  $("signIn").addEventListener("click", async () => {
    try {
      await client.signIn($("email").value.trim(), $("password").value);
      $("password").value = "";
      visible();
      status("Signed in. Your board is private to this account.");
    } catch (error) { status(error.message, true); }
  });
  $("signUp").addEventListener("click", async () => {
    try {
      const result = await client.signUp($("email").value.trim(), $("password").value);
      $("password").value = "";
      visible();
      status(result?.access_token ? "Account created and signed in." :
        "Account created. Check your email for confirmation, then sign in.");
    } catch (error) { status(error.message, true); }
  });
  $("signOut").addEventListener("click", () => {
    client.signOut();
    visible();
    status("Signed out. This tab's session was cleared.");
  });
  $("message").addEventListener("input", () => preview($("message").value));
  $("send").addEventListener("click", async () => {
    try {
      if (!preview($("message").value)) throw Error("Message won't fit six rows.");
      await client.sendBoard($("message").value);
      status("Sent. Signed-in boards receive this message on their next poll.");
      await loadRemote();
    } catch (error) { status(error.message, true); }
  });
  $("clear").addEventListener("click", async () => {
    try {
      await client.sendBoard(null);
      status("Board cleared.");
      preview("");
    } catch (error) { status(error.message, true); }
  });
  document.querySelectorAll("[data-nudge]").forEach(button =>
    button.addEventListener("click", async () => {
      const type = button.dataset.nudge;
      const messages = {
        social: "YOUR PLAN WAS TO PAUSE\n\nSTILL WANT TO SCROLL?",
        creative: "YOU HAVE BEEN CREATING\n\nA STRETCH BREAK?",
        entertainment: "TIME FOR A CHECK-IN\n\nKEEP WATCHING?"
      };
      try {
        await client.sendBoard(messages[type], "threshold");
        preview(messages[type]);
        status(type + " test nudge sent. This was not real screen-time data.");
      } catch (error) { status(error.message, true); }
    })
  );
  preview($("message").value);
  visible();
})();
