function parseJson(text, fallback) {
  try {
    return JSON.parse(String(text || ""))
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
    var ip = String(h.ip || "")
    var local = String(h.local || "")
    var hostname = String(h.hostname || "")
    if (!hostname && local) {
      hostname = local.endsWith(".local") ? local.slice(0, -".local".length) : local
    }
    if (!local && hostname) local = hostname + ".local"
    hosts.push({
      id: String(h.id || ip || local || ("host-" + i)),
      name: String(h.name || hostname || ip || "Unknown"),
      hostname: hostname,
      local: local,
      ip: ip,
      kind: String(h.kind || "other"),
      self: h.self === true
    })
  }
  return {
    iface: String(data.iface || ""),
    selfIp: String(data.selfIp || ""),
    error: data.error ? String(data.error) : "",
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
