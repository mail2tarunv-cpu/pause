/* Optional authenticated cloud receiver for the existing 6x22 display.
 * Cloud mode is opt-in. The unauthenticated board remains fully functional.
 */
(() => {
  "use strict";
  if (!window.PauseCloud || !window.PauseBoard) return;
  const client = window.PauseCloud;
  let connected = false;
  let held = false;
  let revision = "";
  let pollTimer = null;

  window.PauseCloudBoard = { isHeld: () => held };

  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "Cloud";
  button.setAttribute("aria-label", "Connect PAUSE board to your cloud account");
  button.style.cssText = "border:1px solid #6d7067;border-radius:7px;padding:8px 11px;background:transparent;color:inherit;cursor:pointer;font-size:12px";
  const actions = document.querySelector(".top-actions");
  if (actions) actions.appendChild(button);
  else document.body.appendChild(button);

  const overlay = document.createElement("div");
  overlay.style.cssText = "display:none;position:fixed;inset:0;z-index:9999;background:#000a;align-items:center;justify-content:center;padding:22px";
  overlay.innerHTML = `
    <div style="background:#f4f3ed;color:#252925;width:min(420px,100%);padding:25px;border-radius:14px;font:14px system-ui">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <b style="letter-spacing:.2em">PAUSE / CLOUD BOARD</b><button id="cloudClose" type="button">×</button>
      </div>
      <p style="font-size:12px;color:#777;line-height:1.6">Sign in on the display device. Only the account owner can read and change its board message.</p>
      <label for="cloudUrl" style="display:block;margin:12px 0 5px;font-size:11px">SUPABASE PROJECT URL</label>
      <input id="cloudUrl" type="url" autocomplete="url" style="width:100%;padding:10px" placeholder="https://your-project.supabase.co"/>
      <label for="cloudKey" style="display:block;margin:12px 0 5px;font-size:11px">PUBLIC PUBLISHABLE KEY</label>
      <input id="cloudKey" autocomplete="off" style="width:100%;padding:10px" placeholder="sb_publishable_…"/>
      <label for="cloudEmail" style="display:block;margin:12px 0 5px;font-size:11px">EMAIL</label>
      <input id="cloudEmail" type="email" autocomplete="email" style="width:100%;padding:10px"/>
      <label for="cloudPassword" style="display:block;margin:12px 0 5px;font-size:11px">PASSWORD</label>
      <input id="cloudPassword" type="password" autocomplete="current-password" style="width:100%;padding:10px"/>
      <p id="cloudNotice" style="min-height:14px;font-size:11px;color:#656d60"></p>
      <div style="display:flex;gap:8px"><button id="cloudConnect" type="button" style="flex:1">Connect board</button><button id="cloudDisconnect" type="button">Disconnect</button></div>
      <p style="font-size:10px;color:#898e85">Auth tokens are held only in this tab's session, not in the public GitHub repository.</p>
    </div>
  `;
  document.body.append(overlay);
  const $ = id => overlay.querySelector("#" + id);
  $("cloudUrl").value = client.config.url || "";
  $("cloudKey").value = client.config.key || "";
  const notice = text => { $("cloudNotice").textContent = text; };
  const close = () => { overlay.style.display = "none"; };
  button.addEventListener("click", () => { overlay.style.display = "flex"; });
  $("cloudClose").addEventListener("click", close);
  overlay.addEventListener("click", event => {
    if (event.target === overlay) close();
  });

  async function updateBoard() {
    if (!connected || document.hidden) return;
    try {
      const state = await client.getBoard();
      if (!state || !state.updated_at || state.updated_at === revision) return;
      revision = state.updated_at;
      held = typeof state.message === "string" && state.message.trim().length > 0;
      if (held) {
        window.PauseBoard.display(state.message);
      } else {
        window.PauseBoard.display("A LITTLE SPACE\nTO NOTICE WHAT MATTERS");
      }
      button.textContent = "Cloud ✓";
    } catch (error) {
      notice("Board connection lost: " + error.message);
      button.textContent = "Cloud !";
    }
  }

  $("cloudConnect").addEventListener("click", async () => {
    try {
      client.configure($("cloudUrl").value, $("cloudKey").value.trim());
      await client.signIn($("cloudEmail").value.trim(), $("cloudPassword").value);
      $("cloudPassword").value = "";
      connected = true;
      held = false;
      revision = "";
      notice("Connected. This board will receive messages from your account.");
      await updateBoard();
      if (pollTimer) clearInterval(pollTimer);
      pollTimer = setInterval(updateBoard, 4000);
      close();
    } catch (error) { notice(error.message); }
  });

  $("cloudDisconnect").addEventListener("click", () => {
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = null;
    connected = false;
    held = false;
    revision = "";
    client.signOut();
    button.textContent = "Cloud";
    notice("Signed out of the board.");
  });
})();
