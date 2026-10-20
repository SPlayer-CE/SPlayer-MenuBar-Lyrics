/**
 * @name 菜单栏收藏桥接
 * @id com.beichen.splayer-favorite-bridge
 * @version 1.0.0
 * @description 为 SPlayer 菜单栏歌词提供收藏状态读取与切换桥接
 * @author beichen
 * @apiLevel 4
 * @grant network api
 */

const BASE = "http://127.0.0.1:14561";
const LIKED_CACHE_MS = 5 * 60 * 1000;
const POLL_MS = 400;

let currentTrack = null;
let uid = null;
let likedIds = new Set();
let likedUid = null;
let likedFetchedAt = 0;
let polling = false;

function log(message) {
  try {
    splayer.log.info("[favorite-bridge] " + message);
  } catch (error) {
    // 日志失败不影响主流程
  }
}

async function bridgeGet(path) {
  try {
    const response = await splayer.request(BASE + path, {
      responseType: "json",
      timeout: 1200,
    });
    return response && response.body ? response.body : null;
  } catch (error) {
    return null;
  }
}

async function bridgePost(path, payload) {
  try {
    const response = await splayer.request(BASE + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      timeout: 1200,
    });
    return response ? response.status : null;
  } catch (error) {
    // 菜单栏应用未启动时静默失败
    return null;
  }
}

function report(available) {
  if (!currentTrack) return;
  const trackId = String(currentTrack.id);
  const favorite = likedIds.has(trackId);
  void bridgePost("/state", {
    trackId,
    favorite,
    source: currentTrack.source,
    available: Boolean(available),
  }).then((status) => {
    log("report track=" + trackId + " favorite=" + favorite + " status=" + status);
  });
}

async function ensureUid() {
  if (uid) return uid;
  try {
    const response = await splayer.api.call("netease", "login_status", {});
    if (!response || !response.ok) return null;
    const body = response.body || {};
    const data = body.data || body;
    const profile = data.profile || {};
    const account = data.account || {};
    const value = Number(profile.userId || account.id || data.userId || 0);
    uid = Number.isFinite(value) && value > 0 ? value : null;
  } catch (error) {
    uid = null;
  }
  return uid;
}

async function refreshLiked(force) {
  const userId = await ensureUid();
  if (!userId) {
    likedIds = new Set();
    likedUid = null;
    return false;
  }
  if (!force && likedUid === userId && Date.now() - likedFetchedAt < LIKED_CACHE_MS) {
    return true;
  }
  try {
    const response = await splayer.api.call("netease", "likelist", { uid: userId });
    if (!response || !response.ok) return false;
    const body = response.body || {};
    const ids = body.ids || (body.data && body.data.ids) || [];
    if (!Array.isArray(ids)) return false;
    likedIds = new Set(ids.map(String));
    likedUid = userId;
    likedFetchedAt = Date.now();
    return true;
  } catch (error) {
    return false;
  }
}

async function handleTrack(track) {
  currentTrack = track || null;
  if (!currentTrack) return;
  log("track " + currentTrack.id + " source=" + currentTrack.source);
  if (currentTrack.source !== "netease") {
    report(false);
    return;
  }
  const ok = await refreshLiked(false);
  report(Boolean(ok && uid));
}

async function applyPendingToggle(request) {
  const track = currentTrack;
  if (!track || String(request.trackId) !== String(track.id) || track.source !== "netease") {
    return;
  }
  const userId = await ensureUid();
  if (!userId) {
    report(false);
    return;
  }
  const desired = Boolean(request.favorite);
  let ok = false;
  try {
    const response = await splayer.api.call("netease", "song_like", {
      id: String(track.id),
      like: desired,
      uid: userId,
    });
    ok = Boolean(
      response &&
        response.ok &&
        (!response.body || response.body.code === undefined || response.body.code === 200)
    );
  } catch (error) {
    ok = false;
  }
  if (ok) {
    if (desired) likedIds.add(String(track.id));
    else likedIds.delete(String(track.id));
    likedFetchedAt = Date.now();
  } else {
    log("song_like failed for " + track.id);
  }
  report(true);
}

async function poll() {
  if (polling) return;
  polling = true;
  try {
    const request = await bridgeGet("/toggle");
    if (!request) return;
    if (request.pending) {
      await applyPendingToggle(request);
    }
    if (request.refresh) {
      // 菜单栏应用请求重新上报：优先用当前曲目，没有则主动拉一次
      if (currentTrack) {
        await handleTrack(currentTrack);
      } else {
        const snapshot = await splayer.player.getNowPlaying().catch(() => null);
        if (snapshot && snapshot.track) await handleTrack(snapshot.track);
      }
    }
  } finally {
    polling = false;
  }
}

splayer.register({ events: ["trackChange"] });
splayer.player.on("trackChange", ({ track }) => {
  void handleTrack(track);
});
setInterval(() => {
  void poll();
}, POLL_MS);
void bridgeGet("/ping").then((response) => {
  log(response ? "menu bar bridge connected" : "menu bar bridge unavailable");
});

// 兜底：部分宿主在注册时只回放已缓存的事件，主动拉一次当前曲目
void splayer.player
  .getNowPlaying()
  .then((snapshot) => {
    if (snapshot && snapshot.track) void handleTrack(snapshot.track);
  })
  .catch(() => {});
