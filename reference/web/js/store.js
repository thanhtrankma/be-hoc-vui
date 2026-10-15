// Lưu hồ sơ các bé + cài đặt trên máy (localStorage). Mọi đọc/ghi đều bọc try/catch:
// Safari chế độ riêng tư hoặc bị xoá dữ liệu thì app vẫn chạy, chỉ không nhớ.
const KEY = 'bvh.v1';
const DEFAULTS = {lang: 'vi', music: true, sound: true, limit: 20, fun: true, ticketsPer: 1, lockOrder: false};
let S = load();

function load() {
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && Array.isArray(s.profiles)) return {profiles: s.profiles, active: s.active, settings: {...DEFAULTS, ...s.settings}, gone: s.gone || {}, smt: s.smt || 0};
  } catch (e) { /* bỏ qua */ }
  return {profiles: [], active: null, settings: {...DEFAULTS}, gone: {}, smt: 0};
}

// Đợt 18 đồng bộ: mỗi lần lưu đóng dấu giờ sửa (mt) lên hồ sơ đang chơi; onSave báo cho sync.js biết có thay đổi.
let onSave = null;
export const setOnSave = fn => { onSave = fn; };
function rawSave() {
  try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { /* bỏ qua */ }
}
export function save() {
  const p = profile();
  if (p) p.mt = Date.now();
  rawSave();
  if (onSave) onSave();
}

export function persist() {
  try { navigator.storage && navigator.storage.persist && navigator.storage.persist(); } catch (e) { /* bỏ qua */ }
}

export const settings = () => S.settings;
export function setSetting(k, v) { S.settings[k] = v; S.smt = Date.now(); save(); }

export const profiles = () => S.profiles;
export const profile = () => S.profiles.find(p => p.id === S.active) || null;
export function setActive(id) { S.active = id; rawSave(); }  // chỉ đổi bé đang chơi: không đóng dấu sửa hồ sơ

export function addProfile(name, mascot) {
  const p = {id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6), name, mascot,
    stars: 0, rounds: 0, stickers: [], levels: {}, usage: {}, bonus: {}, created: Date.now()};
  S.profiles.push(p);
  S.active = p.id;
  save();
  return p;
}

export function updateProfile(id, fields) {
  const p = S.profiles.find(x => x.id === id);
  if (p) { Object.assign(p, fields, {mt: Date.now()}); save(); }
}

export function removeProfile(id) {
  S.profiles = S.profiles.filter(p => p.id !== id);
  S.gone = {...S.gone, [id]: Date.now()};
  if (S.active === id) S.active = S.profiles[0]?.id || null;
  save();
}

export const levelStars = (p, island, i) => p.levels[`${island}:${i}`] || 0;

// Ghi kết quả một lượt chơi. Sao cộng dồn mỗi lượt (chơi lại = luyện thêm), bài chỉ giữ số sao cao nhất.
export function recordRound(island, i, stars, stickerPool) {
  const p = profile();
  const key = `${island}:${i}`;
  p.levels[key] = Math.max(p.levels[key] || 0, stars);
  p.stars += stars;
  p.rounds += 1;
  logDay(p, 1, stars);
  const left = stickerPool.filter(s => !p.stickers.includes(s));
  const sticker = left.length ? left[Math.floor(Math.random() * left.length)] : null;
  if (sticker) p.stickers.push(sticker);
  save();
  return sticker;
}

// YYYY-MM-DD theo giờ máy (không dùng toLocaleDateString vì mỗi trình duyệt ra một kiểu).
export const dayKey = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
export const today = () => dayKey(new Date());

export function addUsage(seconds) {
  const p = profile();
  if (!p) return;
  const d = today();
  p.usage[d] = (p.usage[d] || 0) + seconds;
  const keys = Object.keys(p.usage).sort();
  while (keys.length > 60) delete p.usage[keys.shift()];
  save();
}

// Hết giờ chơi hôm nay chưa (giới hạn + phút bố mẹ cho thêm).
export function overLimit() {
  const p = profile();
  const lim = S.settings.limit;
  if (!p || !lim) return false;
  const d = today();
  return (p.usage[d] || 0) >= (lim + ((p.bonus || {})[d] || 0)) * 60;
}

export function addBonus(minutes) {
  const p = profile();
  if (!p) return;
  p.bonus = p.bonus || {};
  const d = today();
  p.bonus = {[d]: (p.bonus[d] || 0) + minutes};
  save();
}

export function exportData() {
  return JSON.stringify({app: 'be-vui-hoc', version: 1, exported: new Date().toISOString(), data: S});
}

export function importData(text) {
  const obj = JSON.parse(text);
  const d = obj && obj.app === 'be-vui-hoc' ? obj.data : null;
  if (!d || !Array.isArray(d.profiles)) throw new Error('bad file');
  // Khôi phục giữ nguyên hồ sơ như trong file (không đóng dấu giờ sửa); đồng bộ vẫn gộp theo sao lớn hơn.
  S = {profiles: d.profiles, active: d.active || d.profiles[0]?.id || null, settings: {...DEFAULTS, ...d.settings}, gone: {}, smt: Date.now()};
  rawSave();
  if (onSave) onSave();
}

// ---------- Phòng của bé: ví sao (sao kiếm được trừ sao đã tiêu), đồ đã mua, đồ đang đeo ----------
export const wallet = p => p.stars - (p.spent || 0);
export function buy(item) {
  const p = profile();
  if (wallet(p) < item.price) return false;
  p.spent = (p.spent || 0) + item.price;
  p.owned = [...(p.owned || []), item.id];
  equip(item.slot, item.id);
  return true;
}
export function equip(slot, id) {
  const p = profile();
  p.outfit = {...(p.outfit || {}), [slot]: id};
  if (!id) delete p.outfit[slot];
  save();
}

// ---------- Thử thách hằng ngày: 3 đảo chọn theo ngày, chuỗi ngày liên tiếp ----------
function seeded(str) {
  let h = 2166136261;
  for (const c of str) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return () => { h = Math.imul(h ^ (h >>> 15), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909); return ((h ^= h >>> 16) >>> 0) / 4294967296; };
}
export function daily(islandIds) {
  const p = profile();
  const d = today();
  if (!p.daily || p.daily.date !== d) {
    const rnd = seeded(d + p.id);
    const pool = [...islandIds];
    const tasks = [];
    while (tasks.length < 3 && pool.length) tasks.push(pool.splice(Math.floor(rnd() * pool.length), 1)[0]);
    p.daily = {date: d, tasks, done: [], claimed: false};
    save();
  }
  return p.daily;
}
// Ghi nhận một lượt chơi cho thử thách. Trả về true nếu vừa hoàn thành đủ 3 nhiệm vụ.
export function dailyProgress(islandId) {
  const p = profile();
  const dl = p.daily;
  if (!dl || dl.date !== today() || dl.claimed) return false;
  if (dl.tasks.includes(islandId) && !dl.done.includes(islandId)) dl.done.push(islandId);
  if (dl.done.length < dl.tasks.length) { save(); return false; }
  dl.claimed = true;
  const y = dayKey(new Date(Date.now() - 864e5));
  const st = p.streak || {last: null, count: 0};
  p.streak = {last: today(), count: st.last === y ? st.count + 1 : st.last === today() ? st.count : 1};
  p.stars += 5;
  save();
  return true;
}

// ---------- Huy hiệu: ghi lại cái nào đã nhận để báo "mới" một lần ----------
export function newBadges(earnedIds) {
  const p = profile();
  const have = new Set(p.badges || []);
  const fresh = earnedIds.filter(id => !have.has(id));
  if (fresh.length) { p.badges = [...have, ...fresh]; save(); }
  return fresh;
}

// ---------- Khu vui chơi: vé chơi game kiếm được bằng cách học ----------
export const tickets = p => p.tickets ?? 2;
export function addTickets(n) {
  const p = profile();
  if (!p) return;
  p.tickets = tickets(p) + n;
  save();
}
export function useTicket() {
  const p = profile();
  if (tickets(p) <= 0) return false;
  p.tickets = tickets(p) - 1;
  save();
  return true;
}
export function saveBest(game, score) {
  const p = profile();
  p.best = p.best || {};
  const isNew = score > (p.best[game] || 0);
  if (isNew) p.best[game] = score;
  save();
  return isNew;
}

// Số cấp mỗi game ở Khu vui chơi (trùng MAX_LV trong games/funcore.js).
export const FUN_MAX = 60;
export const funLevel = (p, id) => Math.min(FUN_MAX - 1, (p.funLevel || {})[id] || 0);
export function funLevelUp(id) {
  const p = profile();
  p.funLevel = {...(p.funLevel || {}), [id]: Math.min(FUN_MAX - 1, funLevel(p, id) + 1)};
  save();
}

// Đợt 17: kho đồ của từng game Khu vui chơi (súng, skill, nâng cấp xe...) giữ qua các cấp và các lượt.
// Nội dung do từng game tự định nghĩa (JSON thuần); hồ sơ cũ không có p.gear thì coi như rỗng.
export const gear = (p, id) => ((p && p.gear) || {})[id] || {};
export function saveGear(id, data) {
  const p = profile();
  if (!p || !data) return;
  p.gear = {...(p.gear || {}), [id]: data};
  save();
}

// ---------- Đợt 15: theo dõi học tập cho Báo cáo bố mẹ, ôn tập ngắt quãng, mốc tiến bộ ----------
// p.learn (hồ sơ cũ không có, tạo khi cần; sao lưu/khôi phục đi kèm hồ sơ):
//   items: {"bộ:id": [đúng ngay, sai, ngày ôn tới, chuỗi đúng liền, đã thạo 0/1]}  (đếm theo mục, số mục có hạn theo nội dung)
//   conf:  {"loại|đáp án|bé chọn": số lần}  (tối đa 80 cặp)
//   skills:{đảo: [câu đúng ngay, câu sai, tổng ms]}
//   days:  {"YYYY-MM-DD": [bài, sao, câu đúng, câu sai, mục mới thạo]}  (giữ 60 ngày)
//   ms:    [mốc đã đạt], msAt: {mốc: ngày}
export const dayNum = (d = new Date()) => Math.floor((d.getTime() - d.getTimezoneOffset() * 6e4) / 864e5);
const GAPS = [0, 1, 3, 7, 14, 30];
export const mastered = it => !!it && it[3] >= 1 && it[0] > it[1];
export function learn(p) {
  const l = p.learn || (p.learn = {});
  l.items = l.items || {}; l.conf = l.conf || {}; l.skills = l.skills || {}; l.days = l.days || {}; l.ms = l.ms || []; l.msAt = l.msAt || {};
  return l;
}
function logDay(p, rounds, stars) {
  const l = learn(p);
  const d = l.days[today()] || (l.days[today()] = [0, 0, 0, 0, 0]);
  d[0] += rounds; d[1] += stars;
  const keys = Object.keys(l.days).sort();
  while (keys.length > 60) delete l.days[keys.shift()];
  return d;
}
// Ghi một câu hỏi: ok = đúng ngay lần đầu; keys = các mục của câu; conf = cặp nhầm ["loại|đáp án|bé chọn"].
// Trả về danh sách mục vừa thạo lần đầu.
export function recordAnswer(skill, keys, ok, conf = [], ms = 0) {
  const p = profile();
  if (!p) return [];
  const l = learn(p);
  const sk = l.skills[skill] || (l.skills[skill] = [0, 0, 0]);
  sk[ok ? 0 : 1]++; sk[2] += Math.min(ms || 0, 60000);
  const d = logDay(p, 0, 0);
  d[ok ? 2 : 3]++;
  const now = dayNum(), fresh = [];
  for (const k of keys) {
    const it = l.items[k] || (l.items[k] = [0, 0, 0, 0, 0]);
    if (ok) { it[0]++; it[3]++; it[2] = now + GAPS[Math.min(it[3], GAPS.length - 1)]; }
    else { it[1]++; it[3] = 0; it[2] = now; }
    if (!it[4] && mastered(it)) { it[4] = 1; d[4]++; fresh.push(k); }
  }
  for (const c of conf) l.conf[c] = (l.conf[c] || 0) + 1;
  const ck = Object.keys(l.conf);
  if (ck.length > 80) ck.sort((a, b) => l.conf[a] - l.conf[b]).slice(0, ck.length - 80).forEach(k => delete l.conf[k]);
  save();
  return fresh;
}
// Mục cần ôn: từng sai, chưa nhớ chắc (chuỗi đúng < 5) và đã tới ngày ôn. all = lấy cả mục chưa tới ngày (bố mẹ bấm Luyện lại).
export function dueItems(p, all = false) {
  const l = learn(p), now = dayNum();
  return Object.entries(l.items).filter(([, it]) => it[1] > 0 && it[3] < 5 && (all ? it[3] < 2 || it[2] <= now : it[2] <= now))
    .sort((a, b) => (a[1][2] - b[1][2]) || ((b[1][1] - b[1][0]) - (a[1][1] - a[1][0]))).map(([k]) => k);
}
// Bài ôn tập: cộng sao như một bài (không tính vào bài của đảo).
export function recordReview(stars) {
  const p = profile();
  p.stars += stars;
  logDay(p, 1, stars);
  save();
}
export function addMilestones(ids) {
  const p = profile();
  const l = learn(p);
  const fresh = ids.filter(id => !l.ms.includes(id));
  if (fresh.length) { l.ms.push(...fresh); for (const id of fresh) l.msAt[id] = today(); save(); }
  return fresh;
}

// ---------- Đợt 18: đồng bộ nhiều máy (dữ liệu gửi đi đã mã hoá, xem sync.js) ----------
export const snapshot = () => ({profiles: S.profiles, settings: S.settings, gone: S.gone, smt: S.smt});
const maxMerge = (a = {}, b = {}) => { const o = {...a}; for (const [k, v] of Object.entries(b)) if (typeof v === 'number') o[k] = Math.max(o[k] || 0, v); return o; };
// Gộp dữ liệu máy khác vào máy này, sửa tại chỗ (game đang mở vẫn giữ đúng đối tượng hồ sơ).
// Mỗi hồ sơ: bản sửa sau thắng, nhưng sao (tổng và từng bài), số lượt, giờ học, cấp game, hình dán lấy phần lớn hơn của cả hai máy (không bao giờ giảm).
export function mergeRemote(R) {
  if (!R || !Array.isArray(R.profiles)) return false;
  let changed = false;
  const gone = {...S.gone};
  for (const [id, t] of Object.entries(R.gone || {})) gone[id] = Math.max(t, gone[id] || 0);
  S.gone = gone;
  for (const rp of R.profiles) {
    if (gone[rp.id] >= (rp.mt || 0)) continue;
    const lp = S.profiles.find(p => p.id === rp.id);
    if (!lp) { S.profiles.push(rp); changed = true; continue; }
    if (JSON.stringify(lp) === JSON.stringify(rp)) continue;
    const win = (rp.mt || 0) > (lp.mt || 0) ? rp : lp, lose = win === rp ? lp : rp;
    const big = k => Math.max(win[k] || 0, lose[k] || 0);
    const merged = {...win, levels: maxMerge(lose.levels, win.levels), funLevel: maxMerge(lose.funLevel, win.funLevel), usage: maxMerge(lose.usage, win.usage),
      stars: big('stars'), rounds: big('rounds'), spent: big('spent'),
      stickers: [...new Set([...(win.stickers || []), ...(lose.stickers || [])])], mt: Math.max(lp.mt || 0, rp.mt || 0)};
    for (const k of Object.keys(lp)) if (!(k in merged)) delete lp[k];
    Object.assign(lp, merged);
    changed = true;
  }
  const n = S.profiles.length;
  S.profiles = S.profiles.filter(p => !(gone[p.id] >= (p.mt || 0)));
  if (S.profiles.length !== n) changed = true;
  if (!S.profiles.find(p => p.id === S.active)) S.active = S.profiles[0]?.id || null;
  if ((R.smt || 0) > (S.smt || 0)) { S.settings = {...DEFAULTS, ...R.settings}; S.smt = R.smt; changed = true; }
  if (changed) rawSave();
  return changed;
}
