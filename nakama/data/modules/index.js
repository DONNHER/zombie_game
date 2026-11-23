// Nakama Server Runtime Module for Zombie Apocalypse: Ranger Outbreak
// Provides room code lookup, public room creation/listing, verified match rewards, and leaderboards.

var MATCH_MODULE_NAME = "coop_relay";
var LEADERBOARD_TOTAL = "total_points";
var LEADERBOARD_WEEKLY = "weekly_points";

function generateRoomCode() {
  var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  var code = "";
  for (var i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

function matchInit(ctx, logger, nk, params) {
  var code = params && params.code ? String(params.code).toUpperCase() : generateRoomCode();
  var mode = params && params.mode === "endless" ? "endless" : "story";
  var stageId = params && params.stageId ? Number(params.stageId) : 1;
  var isPrivate = Boolean(params && params.isPrivate);
  var hostUsername = params && params.hostUsername ? String(params.hostUsername) : "Host";
  var hostUserId = params && params.hostUserId ? String(params.hostUserId) : "";
  var state = {
    code: code,
    mode: mode,
    stageId: mode === "endless" ? 99 : stageId,
    isPrivate: isPrivate,
    hostUserId: hostUserId,
    hostUsername: hostUsername,
    status: "waiting",
    presences: {},
    readyMap: {},
    deployReadyMap: {},
    idleTicks: 0
  };
  var label = JSON.stringify({
    code: code,
    mode: state.mode,
    stageId: state.stageId,
    isPrivate: isPrivate,
    hostUsername: hostUsername,
    status: "waiting",
    playerCount: 0
  });
  return { state: state, tickRate: 10, label: label };
}

function matchJoinAttempt(ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
  var count = Object.keys(state.presences).length;
  for (var sessionId in state.presences) {
    if (state.presences[sessionId].userId === presence.userId) {
      return { state: state, accept: false, rejectMessage: "This account is already in the squad. Use a different account." };
    }
  }
  if (count >= 4) {
    return { state: state, accept: false, rejectMessage: "Room is full (4/4)" };
  }
  if (state.status !== "waiting") {
    return { state: state, accept: false, rejectMessage: "Match already in progress" };
  }
  return { state: state, accept: true };
}

function matchJoin(ctx, logger, nk, dispatcher, tick, state, presences) {
  state.idleTicks = 0;
  for (var i = 0; i < presences.length; i++) {
    var p = presences[i];
    state.presences[p.sessionId] = p;
    if (!state.hostUserId) {
      state.hostUserId = p.userId;
      state.hostUsername = p.username;
    }
    state.readyMap[p.userId] = (p.userId === state.hostUserId);
  }
  updateMatchLabel(dispatcher, state);
  broadcastLobbyState(dispatcher, state);
  return { state: state };
}

function matchLeave(ctx, logger, nk, dispatcher, tick, state, presences) {
  for (var i = 0; i < presences.length; i++) {
    var p = presences[i];
    delete state.presences[p.sessionId];
    delete state.readyMap[p.userId];
    delete state.deployReadyMap[p.userId];
  }
  var remaining = Object.keys(state.presences);
  if (remaining.length === 0) {
    return null;
  }
  var hostPresent = false;
  for (var k = 0; k < remaining.length; k++) {
    if (state.presences[remaining[k]].userId === state.hostUserId) {
      hostPresent = true;
      break;
    }
  }
  if (!hostPresent) {
    var nextHost = state.presences[remaining[0]];
    state.hostUserId = nextHost.userId;
    state.hostUsername = nextHost.username;
    state.readyMap[nextHost.userId] = true;
  }
  updateMatchLabel(dispatcher, state);
  broadcastLobbyState(dispatcher, state);
  if (state.status === "deploying") broadcastDeployState(nk, dispatcher, state);
  return { state: state };
}

function broadcastDeployState(nk, dispatcher, state) {
  var players = Object.keys(state.presences).map(function (sessionId) {
    return state.presences[sessionId];
  });
  var readyCount = players.filter(function (p) { return Boolean(state.deployReadyMap[p.userId]); }).length;
  var allReady = players.length > 0 && readyCount === players.length;
  if (allReady) {
    state.status = "in_progress";
    updateMatchLabel(dispatcher, state);
  }
  dispatcher.broadcastMessage(4, nk.stringToBinary(JSON.stringify({
    readyCount: readyCount,
    total: players.length,
    allReady: allReady
  })), null, null, true);
}

function matchLoop(ctx, logger, nk, dispatcher, tick, state, messages) {
  if (Object.keys(state.presences).length === 0) {
    state.idleTicks += 1;
    if (state.idleTicks >= 600) return null; // Drop rooms left empty for one minute.
  } else {
    state.idleTicks = 0;
  }
  for (var i = 0; i < messages.length; i++) {
    var msg = messages[i];
    if (msg.opCode === 1) {
      state.readyMap[msg.sender.userId] = !state.readyMap[msg.sender.userId];
      broadcastLobbyState(dispatcher, state);
    } else if (msg.opCode === 2) {
      if (msg.sender.userId === state.hostUserId && state.status === "waiting") {
        state.status = "deploying";
        state.deployReadyMap = {};
        updateMatchLabel(dispatcher, state);
        dispatcher.broadcastMessage(2, nk.stringToBinary(JSON.stringify({
          started: true,
          mode: state.mode,
          stageId: state.stageId,
          hostUserId: state.hostUserId,
          code: state.code
        })), null, null, true);
      }
    } else if (msg.opCode === 4) {
      if (state.status === "deploying" && state.presences[msg.sender.sessionId]) {
        state.deployReadyMap[msg.sender.userId] = true;
        broadcastDeployState(nk, dispatcher, state);
      }
    } else {
      var recipients = [];
      var keys = Object.keys(state.presences);
      for (var j = 0; j < keys.length; j++) {
        var target = state.presences[keys[j]];
        if (target.sessionId !== msg.sender.sessionId) {
          recipients.push(target);
        }
      }
      if (recipients.length > 0) {
        dispatcher.broadcastMessage(msg.opCode, msg.data, recipients, msg.sender, true);
      }
    }
  }
  return { state: state };
}

function matchTerminate(ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
  return { state: state };
}

function matchSignal(ctx, logger, nk, dispatcher, tick, state, data) {
  return { state: state, data: JSON.stringify(state) };
}

function rpcCreateCoopRoom(ctx, logger, nk, payload) {
  var req = payload ? JSON.parse(payload) : {};
  var code = generateRoomCode();
  var matchId = nk.matchCreate(MATCH_MODULE_NAME, {
    code: code,
    mode: req.mode || "story",
    stageId: req.stageId || 1,
    isPrivate: Boolean(req.isPrivate),
    hostUserId: ctx.userId || "",
    hostUsername: ctx.username || "Ranger"
  });
  return JSON.stringify({ ok: true, matchId: matchId, code: code });
}

function rpcListPublicRooms(ctx, logger, nk, payload) {
  var matches = nk.matchList(25, true, "", 1, 3, "");
  var rooms = [];
  for (var i = 0; i < matches.length; i++) {
    try {
      var meta = JSON.parse(matches[i].label || "{}");
      if (!meta.isPrivate && meta.status === "waiting") {
        rooms.push({
          matchId: matches[i].matchId,
          code: meta.code || "",
          mode: meta.mode || "story",
          stageId: meta.stageId || 1,
          isPrivate: false,
          hostUsername: meta.hostUsername || "Host",
          playerCount: matches[i].size || 1,
          maxPlayers: 4,
          status: meta.status || "waiting"
        });
      }
    } catch (e) {}
  }
  return JSON.stringify({ ok: true, rooms: rooms });
}

function rpcFindRoomByCode(ctx, logger, nk, payload) {
  var req = payload ? JSON.parse(payload) : {};
  var targetCode = String(req.code || "").trim().toUpperCase();
  if (!targetCode) {
    return JSON.stringify({ ok: false, error: "Enter a 4-character room code" });
  }
  var matches = nk.matchList(50, true, "", 1, 4, "");
  for (var i = 0; i < matches.length; i++) {
    try {
      var meta = JSON.parse(matches[i].label || "{}");
      if (String(meta.code || "").toUpperCase() === targetCode) {
        if (meta.status !== "waiting") {
          return JSON.stringify({ ok: false, error: "Match already in progress" });
        }
        if ((matches[i].size || 1) >= 4) {
          return JSON.stringify({ ok: false, error: "Room is full (4/4)" });
        }
        return JSON.stringify({ ok: true, matchId: matches[i].matchId, meta: meta });
      }
    } catch (e) {}
  }
  return JSON.stringify({ ok: false, error: "Room code not found" });
}

function rpcCommitMatchResult(ctx, logger, nk, payload) {
  if (!ctx.userId) {
    return JSON.stringify({ ok: false, error: "Authentication required" });
  }
  var req = payload ? JSON.parse(payload) : {};
  var pointsEarned = Math.max(0, Math.floor(Number(req.pointsEarned || 0)));
  var highestWave = Math.max(1, Math.floor(Number(req.waveReached || 1)));
  var kills = Math.max(0, Math.floor(Number(req.kills || 0)));
  var bossDefeats = Math.max(0, Math.floor(Number(req.bossDefeats || 0)));
  var level = Math.max(1, Math.floor(Number(req.level || 1)));
  var meta = {
    username: ctx.username || req.username || "Ranger",
    level: level,
    highestWave: highestWave,
    bossDefeats: bossDefeats,
    kills: kills
  };
  try {
    nk.leaderboardRecordWrite(LEADERBOARD_TOTAL, ctx.userId, meta.username, pointsEarned, 0, meta);
    nk.leaderboardRecordWrite(LEADERBOARD_WEEKLY, ctx.userId, meta.username, pointsEarned, 0, meta);
  } catch (e) {
    logger.warn("Leaderboard write error: " + e);
  }
  return JSON.stringify({ ok: true, pointsCommitted: pointsEarned });
}

function rpcDeploymentStatus(ctx) {
  return JSON.stringify({ status: "ok", version: (ctx.env && ctx.env.APP_VERSION) || "dev" });
}

function InitModule(ctx, logger, nk, initializer) {
  try {
    nk.leaderboardCreate(LEADERBOARD_TOTAL, false, "desc", "best", "", {}, false);
    nk.leaderboardCreate(LEADERBOARD_WEEKLY, false, "desc", "incr", "0 0 * * 1", {}, false);
  } catch (err) {
    logger.warn("Leaderboard init notice: " + err);
  }

  initializer.registerMatch(MATCH_MODULE_NAME, {
    matchInit: matchInit,
    matchJoinAttempt: matchJoinAttempt,
    matchJoin: matchJoin,
    matchLeave: matchLeave,
    matchLoop: matchLoop,
    matchTerminate: matchTerminate,
    matchSignal: matchSignal
  });

  initializer.registerRpc("create_coop_room", rpcCreateCoopRoom);
  initializer.registerRpc("list_public_rooms", rpcListPublicRooms);
  initializer.registerRpc("find_room_by_code", rpcFindRoomByCode);
  initializer.registerRpc("commit_match_result", rpcCommitMatchResult);
  initializer.registerRpc("deployment_status", rpcDeploymentStatus);

  logger.info("Zombie Apocalypse: Ranger Outbreak Nakama Runtime initialized!");
}

function updateMatchLabel(dispatcher, state) {
  var count = Object.keys(state.presences).length;
  dispatcher.matchLabelUpdate(JSON.stringify({
    code: state.code,
    mode: state.mode,
    stageId: state.stageId,
    isPrivate: state.isPrivate,
    hostUsername: state.hostUsername,
    status: state.status,
    playerCount: count
  }));
}

function broadcastLobbyState(dispatcher, state) {
  var players = [];
  var keys = Object.keys(state.presences);
  for (var i = 0; i < keys.length; i++) {
    var p = state.presences[keys[i]];
    players.push({
      userId: p.userId,
      username: p.username,
      ready: Boolean(state.readyMap[p.userId]),
      isHost: p.userId === state.hostUserId
    });
  }
  dispatcher.broadcastMessage(1, JSON.stringify({
    code: state.code,
    mode: state.mode,
    stageId: state.stageId,
    isPrivate: state.isPrivate,
    hostUserId: state.hostUserId,
    hostUsername: state.hostUsername,
    status: state.status,
    players: players
  }), null, null, true);
}
