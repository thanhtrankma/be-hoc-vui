// Sinh test/parity/fixtures/web_store_trace.json: chạy store.js THẬT của web (reference/web/js/store.js) trong Node
// với đồng hồ và Math.random cố định, ghi lại kết quả + trạng thái sau từng thao tác. store_parity_test.dart phát lại
// đúng các thao tác đó trên AppStore (Dart) và so từng bước.
// Chạy lại: node test/parity/tool/web_store_trace.mjs
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const mem = new Map();
globalThis.localStorage = {getItem: k => mem.has(k) ? mem.get(k) : null, setItem: (k, v) => mem.set(k, String(v)), removeItem: k => mem.delete(k)};

// Đồng hồ: giờ địa phương (y, m, d, h, phút) — Dart dựng DateTime(y, m, d, h, phút) nên ngày khớp ở mọi múi giờ.
let clock = [2026, 10, 14, 9, 0];
const RealDate = Date;
const mk = () => new RealDate(clock[0], clock[1] - 1, clock[2], clock[3], clock[4]);
globalThis.Date = class extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(mk().getTime()); }
  static now() { return mk().getTime(); }
};
// Math.random: dãy cố định (Dart dùng Random giả trả cùng dãy).
const RND = [0.42, 0.13, 0.77, 0.05, 0.91, 0.33, 0.6, 0.25];
let ri = 0;
Math.random = () => RND[ri++ % RND.length];

const ISL = ['letters', 'spell', 'trace', 'read', 'count', 'math', 'life', 'english', 'memory', 'logic', 'code', 'arcade', 'music', 'art', 'explore'];
const init = {
  profiles: [
    {id: 'kidA1x', name: 'Na', mascot: 'robot', stars: 10, rounds: 2, stickers: ['Rainbow'], levels: {'letters:1': 2}, usage: {}, bonus: {}, created: 1700000000000, mt: 1700000000000, tier: 2},
    {id: 'kidB2y', name: 'Bin', mascot: 'superhero', stars: 0, rounds: 0, stickers: [], levels: {}, usage: {}, bonus: {}, created: 1700000000000, mt: 1700000000000},
  ],
  active: 'kidA1x', settings: {lang: 'vi', music: true, sound: true, limit: 20, fun: true, ticketsPer: 1, lockOrder: false}, gone: {}, smt: 0,
};
mem.set('bvh.v1', JSON.stringify(init));
const S = await import(pathToFileURL(path.join(root, 'reference/web/js/store.js')).href);

const ops = [];
const at = (y, m, d, h = 9, mi = 0) => ({at: [y, m, d, h, mi]});
const op = (o, extra = {}) => ops.push({...extra, ...o});
let t = [2026, 10, 14, 9, 0];
const tick = (min = 1) => { const d = new RealDate(t[0], t[1] - 1, t[2], t[3], t[4] + min); t = [d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes()]; return {at: [...t]}; };
const day = n => { const d = new RealDate(t[0], t[1] - 1, t[2] + n, 9, 0); t = [d.getFullYear(), d.getMonth() + 1, d.getDate(), 9, 0]; return {at: [...t]}; };

const pool = ['Rainbow', 'Rocket', 'Star', 'Unicorn'];
op({op: 'recordRound', args: ['letters', 0, 2, pool]}, tick());
op({op: 'recordRound', args: ['letters', 0, 3, pool]}, tick());
op({op: 'recordRound', args: ['count', 1, 1, pool]}, tick());
op({op: 'levelStars', args: ['letters', 0]}, tick());
op({op: 'addUsage', args: [600]}, tick());
op({op: 'overLimit', args: []}, tick());
op({op: 'addUsage', args: [700]}, tick());
op({op: 'overLimit', args: []}, tick());
op({op: 'addBonus', args: [10]}, tick());
op({op: 'overLimit', args: []}, tick());
op({op: 'setSetting', args: ['limit', 0]}, tick());
op({op: 'overLimit', args: []}, tick());
op({op: 'setSetting', args: ['lang', 'en']}, tick());
op({op: 'buy', args: [{id: 'cap', price: 3, slot: 'hat'}]}, tick());
op({op: 'buy', args: [{id: 'crown', price: 999, slot: 'hat'}]}, tick());
op({op: 'wallet', args: []}, tick());
op({op: 'equip', args: ['hat', null]}, tick());
op({op: 'equip', args: ['bg', 'space']}, tick());
op({op: 'daily', args: [ISL]}, tick());
op({op: 'dailyProgress', args: ['nope']}, tick());
op({op: 'dailyProgressAll', args: []}, tick());
op({op: 'dailyProgressAll', args: []}, tick());
op({op: 'daily', args: [ISL]}, day(1));
op({op: 'dailyProgressAll', args: []}, tick());
op({op: 'daily', args: [ISL]}, day(2));
op({op: 'dailyProgressAll', args: []}, tick());
op({op: 'newBadges', args: [['b1', 'b2']]}, tick());
op({op: 'newBadges', args: [['b2', 'b3']]}, tick());
op({op: 'tickets', args: []}, tick());
op({op: 'addTickets', args: [3]}, tick());
for (let k = 0; k < 6; k++) op({op: 'useTicket', args: []}, tick());
op({op: 'saveBest', args: ['racer', 100]}, tick());
op({op: 'saveBest', args: ['racer', 50]}, tick());
op({op: 'saveBest', args: ['racer', 101]}, tick());
for (let k = 0; k < 3; k++) op({op: 'funLevelUp', args: ['racer']}, tick());
op({op: 'funLevel', args: ['racer']}, tick());
op({op: 'saveGear', args: ['hunt', {sword: 2, skills: ['dash']}]}, tick());
op({op: 'saveGear', args: ['hunt', null]}, tick());
// Học tập: trả lời, nhầm lẫn, ôn tập ngắt quãng qua nhiều ngày
op({op: 'recordAnswer', args: ['letters', ['letters:a', 'letters:b'], false, ['letter|a|b'], 1200]}, tick());
op({op: 'recordAnswer', args: ['letters', ['letters:a'], true, [], 90000]}, tick());
op({op: 'recordAnswer', args: ['math', ['addFacts:2,3'], true, [], 800]}, tick());
op({op: 'recordAnswer', args: ['math', ['addFacts:2,3'], false, ['add|5|6'], 800]}, tick());
op({op: 'dueItems', args: [false]}, tick());
op({op: 'dueItems', args: [true]}, tick());
op({op: 'recordAnswer', args: ['letters', ['letters:b'], true, [], 500]}, day(1));
op({op: 'dueItems', args: [false]}, tick());
op({op: 'dueItems', args: [true]}, tick());
op({op: 'recordAnswer', args: ['letters', ['letters:a', 'letters:b'], true, [], 500]}, day(3));
op({op: 'dueItems', args: [false]}, tick());
op({op: 'dueItems', args: [true]}, day(10));
// Nhiều cặp nhầm có số lần bằng nhau (>80): web giữ thứ tự chèn khi xoá bớt (sort ổn định)
for (let k = 0; k < 9; k++) op({op: 'recordAnswer', args: ['english', [`en_animals:w${k}`], false, Array.from({length: 10}, (_, j) => `en|w${k}|x${j}`), 100]}, tick());
// Nhiều mục sai bằng nhau: thứ tự dueItems khi bằng điểm
for (let k = 0; k < 40; k++) op({op: 'recordAnswer', args: ['read', [`vnwords:t${k}`], false, [], 0]}, tick());
op({op: 'dueItems', args: [false]}, tick());
op({op: 'recordReview', args: [2]}, tick());
op({op: 'addMilestones', args: [['w10', 'm20']]}, tick());
op({op: 'addMilestones', args: [['m20', 'm50']]}, tick());
// Giờ chơi giữ 60 ngày, nhật ký học 60 ngày
for (let k = 0; k < 62; k++) { op({op: 'addUsage', args: [60]}, day(1)); if (k % 20 === 0) op({op: 'recordRound', args: ['math', k % 5, 3, pool]}, tick()); }
op({op: 'recordReview', args: [1]}, tick());
op({op: 'updateProfile', args: ['kidB2y', {tier: 1, name: 'Bin Bin'}]}, tick());
op({op: 'setActive', args: ['kidB2y']}, tick());
op({op: 'recordRound', args: ['spell', 3, 2, pool]}, tick());
op({op: 'setActive', args: ['kidA1x']}, tick());
// Gộp dữ liệu máy khác
op({op: 'mergeRemote', args: [{
  profiles: [
    {id: 'kidA1x', name: 'Na (máy 2)', mascot: 'robot', stars: 5, rounds: 99, stickers: ['Unicorn', 'Moon'], levels: {'letters:0': 1, 'math:9': 3}, usage: {'2020-01-01': 5}, bonus: {}, funLevel: {racer: 1, hunt: 4}, created: 1700000000000, mt: 4102444800000, extra: 'x'},
    {id: 'kidB2y', name: 'Bin cũ', mascot: 'superhero', stars: 0, rounds: 0, stickers: [], levels: {}, usage: {}, bonus: {}, created: 1700000000000, mt: 1},
    {id: 'kidC3z', name: 'Su', mascot: 'cat', stars: 7, rounds: 1, stickers: [], levels: {}, usage: {}, bonus: {}, created: 1700000000000, mt: 1700000000500},
    {id: 'kidD4w', name: 'Đã xoá', mascot: 'cat', stars: 7, rounds: 1, stickers: [], levels: {}, usage: {}, bonus: {}, created: 1700000000000, mt: 1700000000500},
  ],
  settings: {lang: 'vi', limit: 45}, gone: {kidD4w: 1800000000000}, smt: 4102444800000,
}]}, tick());
op({op: 'mergeRemote', args: [{profiles: [], settings: {}, gone: {kidC3z: 4102444800001}, smt: 0}]}, tick());
op({op: 'removeProfile', args: ['kidB2y']}, tick());
op({op: 'exportImport', args: []}, tick());
op({op: 'importBad', args: ['{"app":"other"}']}, tick());

// Chạy
const out = [];
const strip = s => JSON.parse(JSON.stringify(s));
for (const o of ops) {
  clock = o.at;
  let res;
  const p = S.profile();
  switch (o.op) {
    case 'levelStars': res = S.levelStars(p, ...o.args); break;
    case 'wallet': res = S.wallet(p); break;
    case 'tickets': res = S.tickets(p); break;
    case 'funLevel': res = S.funLevel(p, ...o.args); break;
    case 'dueItems': res = S.dueItems(p, ...o.args); break;
    case 'dailyProgressAll': res = (p.daily ? [...p.daily.tasks] : []).map(id => S.dailyProgress(id)); break;
    case 'exportImport': { const txt = S.exportData(); S.importData(txt); res = JSON.parse(txt).app; break; }
    case 'importBad': try { S.importData(o.args[0]); res = 'ok'; } catch (e) { res = 'error'; } break;
    default: res = S[o.op](...o.args);
  }
  out.push({...o, result: res === undefined ? null : strip(res), state: strip({...S.snapshot(), active: S.profile() ? S.profile().id : null})});
}
fs.writeFileSync(path.join(root, 'test/parity/fixtures/web_store_trace.json'), JSON.stringify({init, random: RND, ops: out}, null, 0) + '\n');
console.log('ops', out.length);
