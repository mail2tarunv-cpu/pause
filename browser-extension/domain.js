/* Shared, pure privacy filter for extension background and tests. */
function pauseDomain(url) {
  if (typeof url !== "string") return null;
  try {
    const value = new URL(url);
    if (!["https:", "http:"].includes(value.protocol)) return null;
    let host = value.hostname.toLowerCase().replace(/^www\./, "");
    if (!host.includes(".") || host.length > 150) return null;
    if (!/^[a-z0-9.-]+$/.test(host)) return null;
    if (host === "localhost" || host.endsWith(".local") || host.startsWith("127.")) return null;
    // Send the hostname only; never path, query, hash, tab title or referrer.
    return host;
  } catch {
    return null;
  }
}
if (typeof module !== "undefined") module.exports = { pauseDomain };
