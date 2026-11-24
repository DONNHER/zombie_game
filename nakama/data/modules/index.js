var _cachedRelease = {
  fetchedAt: 0,
  tag: "",
  pckUrl: ""
};

function normalizeVersion(v) {
  return String(v || "").trim().replace(/^v/i, "");
}

function getLatestGithubRelease(logger) {
  var now = Date.now();
  if (_cachedRelease.tag && (now - _cachedRelease.fetchedAt) < 60000) {
    return _cachedRelease;
  }
  try {
    var res = nk.httpRequest(
      "https://api.github.com/repos/DONNHER/zombie_game/releases/latest",
      "get",
      {
        "Accept": "application/vnd.github+json",
        "User-Agent": "RangerOutbreak-Nakama"
      },
      "",
      5000
    );
    if (res && res.code === 200 && res.body) {
      var rel = JSON.parse(res.body);
      var tag = String(rel.tag_name || "");
      var pckUrl = "";
      if (rel.assets && rel.assets.length) {
        for (var i = 0; i < rel.assets.length; i++) {
          if (String(rel.assets[i].name || "").indexOf(".pck") !== -1) {
            pckUrl = String(rel.assets[i].browser_download_url || "");
            break;
          }
        }
      }
      if (tag) {
        _cachedRelease = { fetchedAt: now, tag: tag, pckUrl: pckUrl };
      }
    } else if (logger) {
      logger.warn("[OTA CHECK] GitHub API returned HTTP " + (res ? res.code : "no_response"));
    }
  } catch (err) {
    if (logger) {
      logger.warn("[OTA CHECK] GitHub API fetch failed: " + err);
    }
  }
  return _cachedRelease;
}

function rpcCheckUpdate(ctx, logger, nk, payload) {
  var clientVersion = "1.0.0";
  try {
    if (payload) {
      var data = typeof payload === "string" ? JSON.parse(payload) : payload;
      if (typeof data === "string") data = JSON.parse(data);
      if (data) {
        if (data.client_version) clientVersion = String(data.client_version);
        else if (data.version) clientVersion = String(data.version);
      }
    }
  } catch (e) {
    logger.warn("rpcCheckUpdate parse warning: " + e);
  }

  var release = getLatestGithubRelease(logger);
  var serverVersion = release.tag || (ctx.env && ctx.env.APP_VERSION) || "1.0.0";
  var normClient = normalizeVersion(clientVersion);
  var normServer = normalizeVersion(serverVersion);
  var hasPatch = (normServer !== "" && normServer !== "dev" && normServer !== normClient);

  logger.info(
    "[OTA CHECK] status=%s user=%s (%s) client_version=%s latest_version=%s has_patch=%s",
    hasPatch ? "OUTDATED_CLIENT" : "UP_TO_DATE",
    ctx.username || "guest",
    ctx.userId || "unauthenticated",
    clientVersion,
    serverVersion,
    String(hasPatch)
  );

  return JSON.stringify({
    ok: true,
    server_version: serverVersion,
    client_version: clientVersion,
    has_patch: hasPatch,
    release_url: "https://github.com/DONNHER/zombie_game/releases/latest",
    pck_url: release.pckUrl || ""
  });
}
