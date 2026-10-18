// Sinh / kiểm tra vector đồng bộ bằng WebCrypto của Node — cài đặt độc lập của thuật toán trong lib/features/sync/sync_crypto.dart.
//   node webcrypto_vectors.mjs make                 → in JSON vector (IV cố định để so từng byte)
//   node webcrypto_vectors.mjs open <code> <blob>   → giải mã blob (do Dart tạo), in JSON gốc
import {webcrypto as crypto} from 'node:crypto';

const enc = new TextEncoder(), dec = new TextDecoder();
const normalize = s => String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
const b64 = u8 => Buffer.from(u8).toString('base64');
const unb64 = s => new Uint8Array(Buffer.from(s, 'base64'));
const hex = u8 => [...new Uint8Array(u8)].map(x => x.toString(16).padStart(2, '0')).join('');

async function deriveKeys(c) {
  const sid = hex(await crypto.subtle.digest('SHA-256', enc.encode('bvh-sync-id|' + normalize(c))));
  const base = await crypto.subtle.importKey('raw', enc.encode(normalize(c)), 'PBKDF2', false, ['deriveKey']);
  // extractable = true chỉ để in khoá ra so (khoá giống hệt khi không xuất được).
  const key = await crypto.subtle.deriveKey({name: 'PBKDF2', salt: enc.encode('bvh-sync-key-v1'), iterations: 150000, hash: 'SHA-256'},
    base, {name: 'AES-GCM', length: 256}, true, ['encrypt', 'decrypt']);
  return {sid, key, raw: hex(await crypto.subtle.exportKey('raw', key))};
}
async function seal(key, obj, iv) {
  const ct = new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv}, key, enc.encode(JSON.stringify(obj))));
  const out = new Uint8Array(12 + ct.length); out.set(iv); out.set(ct, 12);
  return b64(out);
}
async function open(key, blob) {
  const u8 = unb64(blob);
  return JSON.parse(dec.decode(await crypto.subtle.decrypt({name: 'AES-GCM', iv: u8.subarray(0, 12)}, key, u8.subarray(12))));
}

const [, , cmd, a, b] = process.argv;
if (cmd === 'make') {
  const code = 'ABCD-EFGH-JKMN-PQ23';
  const {sid, key, raw} = await deriveKeys(code);
  const obj = {profiles: [{id: 'k1', name: 'Bé Na 🐰', stars: 12, levels: {'count:0': 3}, mt: 1700000000000}],
    settings: {lang: 'vi', music: true}, gone: {}, smt: 1700000000001};
  const iv = Uint8Array.from({length: 12}, (_, i) => i + 1);
  const blob = await seal(key, obj, iv);
  console.log(JSON.stringify({code, sid, key: raw, plain: JSON.stringify(obj), iv: hex(iv), blob}, null, 2));
} else if (cmd === 'open') {
  const {key} = await deriveKeys(a);
  console.log(JSON.stringify(await open(key, b)));
} else {
  console.error('usage: make | open <code> <blob>');
  process.exit(2);
}
