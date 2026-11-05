/* PAUSE local relay display receiver.
   No cloud service is contacted. Safely no-ops on a static Vercel deployment. */
(() => {
  "use strict";
  let sequence = -1;
  let held = false;
  let started = false;
  let pending = false;
  const poll = async () => {
    if (pending || document.hidden) return;
    pending = true;
    try {
      const response = await fetch("/pause-api/board", {cache:"no-store"});
      if (!response.ok) return;
      const data = await response.json();
      if (typeof data.sequence !== "number" || data.sequence === sequence) return;
      sequence = data.sequence;
      held = typeof data.message === "string" && data.message.trim().length > 0;
      if (held && window.PauseBoard?.display) {
        window.PauseBoard.display(data.message);
        if (data.source === "threshold") {
          const caption = document.querySelector(".footnote");
          if (caption) caption.textContent = "PAUSE / A NUDGE FROM YOUR CONNECTED CONTROLLER";
        }
      } else if (started && window.PauseBoard?.display) {
        const welcome = "A LITTLE SPACE TO\nNOTICE WHAT MATTERS";
        window.PauseBoard.display(welcome);
        const caption = document.querySelector(".footnote");
        if (caption) caption.textContent = "132 individual split flaps · 6 rows × 22 columns";
      }
      started = true;
    } catch (_) {
      // Static deployments do not have the local relay endpoint.
    } finally {
      pending = false;
    }
  };
  window.PauseRemote = {isHeld: () => held};
  poll();
  setInterval(poll, 1500);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) poll();
  });
})();
