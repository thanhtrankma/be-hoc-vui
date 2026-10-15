// Đợt 18: đồng bộ nhiều máy bằng "mã gia đình" (không email, không mật khẩu, không tên thật).
// Từ mã suy ra: sid = SHA-256 (tên ngăn trên máy chủ) và khoá AES-GCM (PBKDF2). Dữ liệu mã hoá trên máy rồi mới gửi,
// máy chủ datpilot.com chỉ giữ một khối byte không đọc được. Chỉ chạy khi bố mẹ bật trong Góc bố mẹ.
import * as store from './store.js?v=4c51d34a6e';

const API = '/api/bvh/sync/';
const LS = 'bvh.sync';
const ALPHA = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';   // bỏ I, L, O, 0, 1 cho khỏi nhầm khi đọc cho nhau
const enc = new TextEncoder(), dec = new TextDecoder();

let st = (() => { try { return JSON.parse(localStorage.getItem(LS)) || {}; } catch (e) { return {}; } })();
const keep = () => { try { localStorage.setItem(LS, JSON.stringify(st)); } catch (e) { /* bỏ qua */ } };
let keys = null, busy = null, timer = null, onMerged = null;
// st.dirty: máy này có thay đổi chưa đẩy lên (giữ qua lần mở app sau, kể cả khi đang mất mạng).

export const supported = () => !!(window.crypto && crypto.subtle && window.fetch);
export const code = () => st.code || null;
export const lastAt = () => st.at || 0;
export const lastErr = () => st.err || null;
export const normalize = s => String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
export const pretty = c => normalize(c).replace(/(.{4})(?=.)/g, '$1-');
export function newCode() {
  const r = crypto.getRandomValues(new Uint8Array(16));
  return pretty([...r].map(x => ALPHA[x % ALPHA.length]).join(''));
}

const b64 = u8 => { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode(...u8.subarray(i, i + 0x8000)); return btoa(s); };
const unb64 = s => Uint8Array.from(atob(s), ch => ch.charCodeAt(0));
async function deriveKeys(c) {
  const raw = enc.encode(normalize(c));
  const sid = [...new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode('bvh-sync-id|' + normalize(c))))].map(x => x.toString(16).padStart(2, '0')).join('');
  const base = await crypto.subtle.importKey('raw', raw, 'PBKDF2', false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey({name: 'PBKDF2', salt: enc.encode('bvh-sync-key-v1'), iterations: 150000, hash: 'SHA-256'},
    base, {name: 'AES-GCM', length: 256}, false, ['encrypt', 'decrypt']);
  return {sid, key};
}
async function seal(key, obj) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv}, key, enc.encode(JSON.stringify(obj))));
  const out = new Uint8Array(12 + ct.length); out.set(iv); out.set(ct, 12);
  return b64(out);
}
async function open(key, blob) {
  const u8 = unb64(blob);
  return JSON.parse(dec.decode(await crypto.subtle.decrypt({name: 'AES-GCM', iv: u8.subarray(0, 12)}, key, u8.subarray(12))));
}

// Một lượt: kéo bản trên máy chủ (gộp nếu khác), rồi đẩy bản đã gộp. mode 'create' | 'join' | undefined.
async function round(mode) {
  if (!keys) keys = await deriveKeys(st.code);
  let base = 0;
  if (mode !== 'create') {
    const r = await fetch(API + keys.sid, {cache: 'no-store'});
    if (r.status === 404) {
      if (mode === 'join') return 'notfound';
      base = 0;  // ngăn bị xoá trên máy chủ (hoặc quá hạn): tạo lại từ máy này
    } else if (!r.ok) throw new Error('http ' + r.status);
    else {
      const j = await r.json();
      if (j.v !== st.v) {
        const R = await open(keys.key, j.blob);
        if (store.mergeRemote(R) && onMerged) onMerged();
      }
      base = j.v;
      if (base === st.v && !st.dirty && mode !== 'join') return 'ok';
    }
  }
  for (let k = 0; k < 3; k++) {
    st.dirty = false;
    const w = await fetch(API + keys.sid, {method: 'PUT', headers: {'content-type': 'application/json'},
      body: JSON.stringify({base, blob: await seal(keys.key, store.snapshot())})});
    if (w.ok) { st.v = (await w.json()).v; return 'ok'; }
    if (w.status === 409) {
      const j = await w.json();
      if (store.mergeRemote(await open(keys.key, j.blob)) && onMerged) onMerged();
      base = j.v;
      continue;
    }
    throw new Error('http ' + w.status);
  }
  throw new Error('conflict');
}

export function syncNow(mode) {
  if (!st.code || !supported()) return Promise.resolve('off');
  if (busy) return busy;
  busy = round(mode).then(res => {
    if (res === 'ok') { st.at = Date.now(); st.err = null; }
    keep();
    return res;
  }).catch(e => {
    st.err = navigator.onLine === false ? 'offline' : String(e.message || e);
    keep();
    return 'error';
  }).finally(() => { busy = null; });
  return busy;
}

// Bật trên máy đầu tiên: tạo mã mới, đẩy dữ liệu lên.
export async function create() {
  st = {code: newCode(), v: 0}; keys = null; keep();
  const r = await syncNow('create');
  if (r !== 'ok') { st = {}; keys = null; keep(); }
  return r;
}
// Máy thứ hai: nhập mã, kéo dữ liệu về gộp với máy này.
export async function join(c) {
  if (normalize(c).length !== 16) return 'bad';
  st = {code: pretty(c), v: 0}; keys = null; keep();
  const r = await syncNow('join');
  if (r !== 'ok') { st = {}; keys = null; keep(); }
  return r;
}
// Ngắt máy này (dữ liệu trên máy vẫn giữ). wipe: xoá luôn bản trên máy chủ.
export async function leave(wipe) {
  if (wipe && st.code) {
    try { if (!keys) keys = await deriveKeys(st.code); await fetch(API + keys.sid, {method: 'DELETE'}); } catch (e) { /* bỏ qua */ }
  }
  st = {}; keys = null; keep();
}

// Tự đồng bộ: lúc mở app, 20 giây sau mỗi lần lưu, khi app chuyển nền.
export function init(merged) {
  onMerged = merged;
  store.setOnSave(() => {
    if (!st.code) return;
    if (!st.dirty) { st.dirty = true; keep(); }
    clearTimeout(timer);
    timer = setTimeout(() => syncNow(), 20000);
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden && st.dirty && st.code) { clearTimeout(timer); syncNow(); } });
  window.addEventListener('online', () => { if (st.code) syncNow(); });
  if (st.code) syncNow();
}
