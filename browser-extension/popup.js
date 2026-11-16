const $ = id => document.getElementById(id);

async function load() {
  const settings = await chrome.storage.local.get({
    pairingCode: "", enabled: false,
    lastStatus: "Not paired", lastDomain: null
  });
  $("code").value = settings.pairingCode;
  $("enabled").checked = settings.enabled;
  $("statusText").textContent = settings.lastStatus;
  $("led").classList.toggle("ok", settings.lastStatus === "Connected");
  $("site").textContent = settings.lastDomain
    ? "Last active domain: " + settings.lastDomain
    : "No website observed yet";
}

$("connect").addEventListener("click", async () => {
  const pairingCode = $("code").value.trim().toLowerCase();
  if (!/^[a-f0-9]{48}$/.test(pairingCode)) {
    $("statusText").textContent = "Enter the 48-character code from the Mac app.";
    return;
  }
  await chrome.storage.local.set({ pairingCode, enabled: true });
  $("enabled").checked = true;
  $("statusText").textContent = "Checking your Mac…";
  await chrome.runtime.sendMessage({ action: "checkConnection" });
  load();
});

$("enabled").addEventListener("change", async () => {
  await chrome.storage.local.set({ enabled: $("enabled").checked });
  if ($("enabled").checked) {
    await chrome.runtime.sendMessage({ action: "checkConnection" });
  } else {
    await chrome.storage.local.set({ lastStatus: "Paused", lastDomain: null });
  }
  load();
});

$("forget").addEventListener("click", async () => {
  await chrome.storage.local.remove(["pairingCode", "lastDomain", "lastSentAt"]);
  await chrome.storage.local.set({ enabled: false, lastStatus: "Not paired" });
  load();
});
load();
