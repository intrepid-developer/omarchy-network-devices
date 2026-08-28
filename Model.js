// Hard limit on helper stdout retained in the long-lived shell process.
// ASCII-heavy JSON: each UTF-16 code unit is one byte in practice.
var MAX_OUTPUT_CHARS = 512 * 1024

function capOutput(text) {
  var s = String(text === undefined || text === null ? "" : text)
  if (s.length > MAX_OUTPUT_CHARS) return s.substring(0, MAX_OUTPUT_CHARS)
  return s
}

function appendCapped(existing, chunk) {
  var current = String(existing === undefined || existing === null ? "" : existing)
  if (current.length >= MAX_OUTPUT_CHARS) return current
  var next = String(chunk === undefined || chunk === null ? "" : chunk)
  if (next === "") return current
  var remaining = MAX_OUTPUT_CHARS - current.length
  if (next.length > remaining) next = next.substring(0, remaining)
  return current + next
}

function wasCapped(text) {
  return String(text === undefined || text === null ? "" : text).length >= MAX_OUTPUT_CHARS
}

// Sanitize LAN-controlled strings before they reach QML Text / tooltips.
// Strips angle brackets (Qt AutoText → StyledText / remote img fetch),
// ASCII controls, bidi overrides, and Unicode tag characters; then caps length.
function clean(value, max) {
  var s = String(value === undefined || value === null ? "" : value)
  s = s.replace(/[<>]/g, "")
    .replace(/[\x00-\x1f\x7f]/g, "")
    .replace(/[​-‏‪-‮⁦-⁩]/g, "")
    .replace(/\uDB40[\uDC00-\uDC7F]/g, "")
  var cap = max || 64
  return s.length > cap ? s.slice(0, cap) : s
}

function parseJson(text, fallback) {
  try {
    return JSON.parse(capOutput(text))
  } catch (e) {
    return fallback
  }
}

function pluginDirFromUrl(url) {
  return String(url || "").replace(/^file:\/\//, "").replace(/\/[^/]+$/, "")
}

function helperPath(pluginDir) {
  return String(pluginDir || "").replace(/\/$/, "") + "/bin/lan-hosts"
}

function normalizeHosts(payload) {
  var data = payload && typeof payload === "object" ? payload : {}
  var raw = Array.isArray(data.hosts) ? data.hosts : []
  var hosts = []
  for (var i = 0; i < raw.length && hosts.length < 80; i++) {
    var h = raw[i] || {}
    var ip = clean(h.ip, 45)
    var local = clean(h.local, 96)
    var hostname = clean(h.hostname, 64)
    if (!hostname && local) {
      hostname = local.endsWith(".local") ? local.slice(0, -".local".length) : local
    }
    if (!local && hostname) local = hostname + ".local"
    hosts.push({
      id: clean(h.id || ip || local || ("host-" + i), 96),
      name: clean(h.name || hostname || ip || "Unknown", 64),
      hostname: hostname,
      local: local,
      ip: ip,
      kind: clean(h.kind || "other", 24),
      self: h.self === true
    })
  }
  return {
    iface: clean(data.iface, 32),
    selfIp: clean(data.selfIp, 45),
    error: data.error ? clean(data.error, 160) : "",
    hosts: hosts
  }
}

function barCountText(hosts) {
  var n = Array.isArray(hosts) ? hosts.length : 0
  return String(n)
}

function kindGlyph(kind) {
  switch (String(kind || "")) {
    case "this": return "󰌢"
    case "computer": return "󰇄"
    case "phone": return "󰄜"
    case "tablet": return "󰓶"
    case "tv": return "󰟴"
    case "speaker": return "󰓃"
    case "router": return "󰒍"
    default: return "󰈀"
  }
}

function hostSubtitle(host) {
  if (!host) return ""
  var parts = []
  if (host.ip) parts.push(host.ip)
  if (host.local) parts.push(host.local)
  return parts.join("  ·  ")
}

function hostTooltip(host) {
  if (!host) return ""
  var lines = [host.name || "Host"]
  if (host.ip) lines.push(host.ip)
  if (host.local) lines.push(host.local)
  return lines.join("\n")
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_OUTPUT_CHARS: MAX_OUTPUT_CHARS,
    capOutput: capOutput,
    appendCapped: appendCapped,
    wasCapped: wasCapped,
    clean: clean,
    parseJson: parseJson,
    pluginDirFromUrl: pluginDirFromUrl,
    helperPath: helperPath,
    normalizeHosts: normalizeHosts,
    barCountText: barCountText,
    kindGlyph: kindGlyph,
    hostSubtitle: hostSubtitle,
    hostTooltip: hostTooltip
  }
}
