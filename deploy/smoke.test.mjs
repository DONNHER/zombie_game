import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { setTimeout as delay } from "node:timers/promises";

const url = process.env.NAKAMA_TEST_URL ?? "http://127.0.0.1:17350";
const key = process.env.NAKAMA_SERVER_KEY ?? "defaultkey";

async function request(path, options) {
  const timeout = path === "/v2/rpc/check_update" ? 18000 : 8000;
  const response = await fetch(url + path, { signal: AbortSignal.timeout(timeout), ...options });
  assert.ok(response.ok, `${path} returned HTTP ${response.status}: ${await response.clone().text()}`);
  return response.json();
}

async function authenticate() {
  const response = await request("/v2/account/authenticate/device?create=true", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Basic " + Buffer.from(key + ":").toString("base64")
    },
    body: JSON.stringify({ id: randomUUID() })
  });
  assert.ok(response.token, "device authentication returned a session");
  return response.token;
}

async function rpc(token, name, payload = {}) {
  const response = await request("/v2/rpc/" + name, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer " + token },
    body: JSON.stringify(JSON.stringify(payload))
  });
  return JSON.parse(response.payload);
}

function join(socket, matchId) {
  return new Promise((resolve, reject) => {
    const cid = randomUUID();
    const timer = setTimeout(() => finish(new Error("Timed out joining room")), 6000);
    function finish(error, match) {
      clearTimeout(timer);
      socket.removeEventListener("message", handleMessage);
      if (error) reject(error);
      else resolve(match);
    }
    function handleMessage(event) {
      const envelope = JSON.parse(event.data);
      if (envelope.cid !== cid) return;
      if (envelope.match) finish(null, envelope.match);
      else finish(new Error(JSON.stringify(envelope.error)));
    }
    socket.addEventListener("message", handleMessage);
    socket.send(JSON.stringify({ cid, match_join: { match_id: matchId } }));
  });
}

function openSocket(t, token) {
  const endpoint = new URL("/ws", url);
  endpoint.protocol = endpoint.protocol === "https:" ? "wss:" : "ws:";
  endpoint.searchParams.set("token", token);
  endpoint.searchParams.set("format", "json");
  const socket = new WebSocket(endpoint);
  t.after(() => socket.close());
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("WebSocket open timed out")), 6000);
    socket.addEventListener("open", () => {
      clearTimeout(timer);
      resolve(socket);
    }, { once: true });
    socket.addEventListener("error", () => {
      clearTimeout(timer);
      reject(new Error("Nakama WebSocket failed to open"));
    }, { once: true });
  });
}

test("Nakama is healthy and reports the built revision", async () => {
  const health = await fetch(url + "/healthcheck", { signal: AbortSignal.timeout(5000) });
  assert.equal(health.status, 200);
  const token = await authenticate();
  const status = await rpc(token, "deployment_status");
  assert.deepEqual(status, { status: "ok", version: process.env.APP_VERSION ?? "dev" });
  const updateInfo = await rpc(token, "check_update", { client_version: "0.9.0" });
  assert.equal(typeof updateInfo.has_patch, "boolean");
  if (updateInfo.ok) assert.match(updateInfo.server_version, /^v\d+\.\d+\.\d+$/);
  else assert.equal(updateInfo.has_patch, false);
});

test("two accounts can create, find, and join the same co-op room", async (t) => {
  const [host, guest] = await Promise.all([authenticate(), authenticate()]);
  assert.notEqual(host, guest);
  const room = await rpc(host, "create_coop_room", { mode: "story", stageId: 1 });
  assert.equal(room.ok, true);
  assert.match(room.code, /^[A-Z2-9]{4}$/);
  assert.equal((await join(await openSocket(t, host), room.matchId)).match_id, room.matchId);
  let visible = false;
  for (let attempt = 0; attempt < 20 && !visible; attempt++) {
    const rooms = await rpc(guest, "list_public_rooms");
    visible = rooms.rooms.some((entry) => entry.matchId === room.matchId);
    if (!visible) await delay(250);
  }
  assert.ok(visible, "the host's room appeared in the public match index");
  const found = await rpc(guest, "find_room_by_code", { code: room.code });
  assert.equal(found.matchId, room.matchId);
  assert.equal((await join(await openSocket(t, guest), found.matchId)).match_id, room.matchId);
});
