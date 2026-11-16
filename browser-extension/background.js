/* PAUSE active-website sender. Manifest V3 service worker.
 * No browsing history, page titles, full URLs, or cookies leave the browser.
 * Runs only after explicit user pairing and while Chrome is focused/active.
 */
importScripts("domain.js");

const endpoint = "http://127.0.0.1:8766/active-site";
const alarmName = "pause-active-tab";

async function currentDomain() {
  try {
    const idleState = await chrome.idle.queryState(60);
    if (idleState !== "active") return null;
    const win = await chrome.windows.getLastFocused({ populate: true });
    if (!win || !win.focused || !win.tabs) return null;
    const tab = win.tabs.find(t => t.active);
    return pauseDomain(tab?.url);
  } catch {
    return null;
  }
}

async function sendObservation() {
  const settings = await chrome.storage.local.get({
    enabled: false, pairingCode: ""
  });
  if (!settings.enabled || !/^[a-f0-9]{48}$/.test(settings.pairingCode)) {
    return { ok: false, reason: "not-paired" };
  }

  // A hostname snapshot, not a usage record. The Mac decides what counts
  // as foreground activity and prevents browser-app double counting.
  const domain = await currentDomain();
  try {
    const result = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-PAUSE-Token": settings.pairingCode
      },
      body: JSON.stringify({ domain }),
      cache: "no-store",
      signal: AbortSignal.timeout(3000)
    });
    await chrome.storage.local.set({
      lastStatus: result.ok ? "Connected" : "Pairing rejected (" + result.status + ")",
      lastSentAt: Date.now(),
      lastDomain: domain
    });
    return { ok: result.ok, reason: result.ok ? "connected" : "http-" + result.status };
  } catch {
    await chrome.storage.local.set({ lastStatus: "PAUSE Mac app not running" });
    return { ok: false, reason: "unreachable" };
  }
}

chrome.runtime.onInstalled.addListener(async () => {
  const existing = await chrome.storage.local.get("enabled");
  if (existing.enabled === undefined) {
    await chrome.storage.local.set({ enabled: false, lastStatus: "Not paired" });
  }
  await chrome.alarms.create(alarmName, { periodInMinutes: 0.5 });
});
chrome.runtime.onStartup.addListener(() =>
  chrome.alarms.create(alarmName, { periodInMinutes: 0.5 })
);
chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === alarmName) sendObservation();
});
chrome.tabs.onActivated.addListener(() => sendObservation());
chrome.tabs.onUpdated.addListener((_id, change, tab) => {
  if (tab.active && change.url !== undefined) sendObservation();
});
chrome.windows.onFocusChanged.addListener(() => sendObservation());
chrome.idle.onStateChanged.addListener(() => sendObservation());
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (message && message.action === "checkConnection") {
    sendObservation().then(reply);
    return true;
  }
  return false;
});
