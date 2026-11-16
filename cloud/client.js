/* Browser-only PAUSE client. Uses Supabase Auth + RLS; no service-role secrets.
 * Public project URL/key may be stored locally. JWTs stay in sessionStorage,
 * so a new tab or device must explicitly sign in.
 */
(() => {
  "use strict";
  const CONFIG = "pause-cloud-project-v1";
  const SESSION = "pause-cloud-session-v1";

  class PauseCloud {
    constructor() {
      try { this.config = JSON.parse(localStorage.getItem(CONFIG)) || {}; }
      catch { this.config = {}; }
      try { this.session = JSON.parse(sessionStorage.getItem(SESSION)); }
      catch { this.session = null; }
    }

    configure(url, publishableKey) {
      const parsed = new URL(String(url).trim());
      const hostname = parsed.hostname;
      if (parsed.protocol !== "https:" || parsed.port || parsed.pathname !== "/" ||
          parsed.search || parsed.hash ||
          !(hostname.endsWith(".supabase.co") || hostname.endsWith(".supabase.in"))) {
        throw Error("Use your project's HTTPS Supabase URL.");
      }
      if (!/^sb_publishable_[a-zA-Z0-9_-]+$/.test(publishableKey) &&
          !/^eyJ[a-zA-Z0-9_.-]+$/.test(publishableKey)) {
        throw Error("Use the project's public publishable key (never a secret key).");
      }
      this.config = { url: parsed.origin, key: publishableKey };
      localStorage.setItem(CONFIG, JSON.stringify(this.config));
    }

    get isConfigured() { return !!(this.config.url && this.config.key); }
    get isSignedIn() { return !!(this.session?.access_token && this.session?.user?.id); }
    get userId() { return this.session?.user?.id || null; }

    async raw(path, options = {}) {
      if (!this.isConfigured) throw Error("Configure your Supabase project first.");
      const headers = {
        apikey: this.config.key,
        "Content-Type": "application/json",
        ...options.headers
      };
      if (options.auth !== false) {
        await this.renew();
        if (!this.session?.access_token) throw Error("Sign in to PAUSE first.");
        headers.Authorization = "Bearer " + this.session.access_token;
      }
      const response = await fetch(this.config.url + path, {
        method: options.method || "GET",
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        cache: "no-store",
        signal: AbortSignal.timeout(12000)
      });
      const text = await response.text();
      let data;
      try { data = text ? JSON.parse(text) : null; }
      catch { data = null; }
      if (!response.ok) {
        throw Error(data?.msg || data?.error_description || data?.message ||
                    data?.error || "Request failed (" + response.status + ")");
      }
      return data;
    }

    setSession(session) {
      if (!session?.access_token || !session?.user?.id) {
        throw Error("No authenticated session was returned. Check your email if confirmation is required.");
      }
      this.session = {
        ...session,
        expires_at: Math.floor(Date.now() / 1000) + (session.expires_in || 3600)
      };
      sessionStorage.setItem(SESSION, JSON.stringify(this.session));
    }

    async signIn(email, password) {
      const result = await this.raw("/auth/v1/token?grant_type=password", {
        method: "POST", auth: false, body: { email, password }
      });
      this.setSession(result);
      return result;
    }

    async signUp(email, password) {
      const result = await this.raw("/auth/v1/signup", {
        method: "POST", auth: false, body: { email, password }
      });
      if (result?.access_token) this.setSession(result);
      return result;
    }

    async renew() {
      if (!this.session) throw Error("Sign in first.");
      if (Date.now() / 1000 < (this.session.expires_at || 0) - 90) return;
      if (!this.session.refresh_token) throw Error("Session expired. Sign in again.");
      const result = await this.raw("/auth/v1/token?grant_type=refresh_token", {
        method: "POST", auth: false,
        body: { refresh_token: this.session.refresh_token }
      });
      this.setSession(result);
    }

    signOut() {
      this.session = null;
      sessionStorage.removeItem(SESSION);
    }

    async sendBoard(message, source = "manual") {
      if (message !== null && (!message.trim() || message.length > 280)) {
        throw Error("Board messages must contain 1–280 characters.");
      }
      if (!["manual", "threshold", "preset", "system"].includes(source)) {
        throw Error("Invalid message source.");
      }
      return this.raw("/rest/v1/pause_board_state?on_conflict=user_id", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: [{
          user_id: this.userId,
          message: message == null ? null : message.toUpperCase(),
          source
        }]
      });
    }

    async getBoard() {
      return (await this.raw(
        "/rest/v1/pause_board_state?select=message,source,updated_at&user_id=eq." +
        encodeURIComponent(this.userId) + "&limit=1"
      ))?.[0] ?? null;
    }

    async getDaily(days = 7) {
      const since = new Date();
      since.setDate(since.getDate() - days + 1);
      const day = [
        since.getFullYear(), String(since.getMonth() + 1).padStart(2, "0"),
        String(since.getDate()).padStart(2, "0")
      ].join("-");
      return this.raw(
        "/rest/v1/pause_usage_daily?select=device_id,day,category,seconds&user_id=eq." +
        encodeURIComponent(this.userId) + "&day=gte." + day +
        "&order=day.desc"
      );
    }

    async getDevices() {
      return this.raw(
        "/rest/v1/pause_devices?select=id,kind,label,last_seen&user_id=eq." +
        encodeURIComponent(this.userId) + "&order=last_seen.desc"
      );
    }
  }

  window.PauseCloud = new PauseCloud();
})();
