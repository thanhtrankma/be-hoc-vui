// Săn quái vật: kiểu "survivor" nhìn từ trên xuống. Kéo ngón tay để chạy (cần điều khiển ảo hiện ở chỗ chạm), bé TỰ BẮN quái gần nhất.
// Quái đến theo đợt, hết giờ thì trùm ra. Quái chết rơi ngọc; đầy thanh ngọc → dừng game, chọn 1 trong 3 thẻ skill (12 skill × 5 cấp).
// Đợt 17: mọi skill + cấp skill lưu vào carry, mang sang cấp sau/lượt sau (trần tổng cấp CAP, đủ trần thì thẻ đổi thành xu/hồi máu).
// Xu tích vào carry.coins, mua nâng cấp vĩnh viễn ở "Kho vũ khí" (DOM, chỉ hiện ở cấp đầu của lượt); ở đó bé bật/tắt skill đã có.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {h, src} from '../ui.js?v=4c51d34a6e';
import {drawFigure, petBuddy, heroOf} from './figure.js?v=4c51d34a6e';
import {anim, booms, dust, shaker, sheets, spr, coin} from './funfx.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';

// Skill: atk = vũ khí đánh quái (ít nhất 1 cái phải bật)
export const SKILLS = {
  gun: {img: 'Water pistol', vi: 'Súng nước', c: '#4dabf7', atk: 1},
  knife: {img: 'Dagger', vi: 'Dao bay', c: '#adb5bd', atk: 1},
  bolt: {img: 'High voltage', vi: 'Tia sét', c: '#fcc419', atk: 1},
  fire: {img: 'Fire', vi: 'Cầu lửa', c: '#ff922b', atk: 1},
  frost: {img: 'Snowflake', vi: 'Vòng băng', c: '#74c0fc', atk: 1},
  boom: {img: 'Boomerang', vi: 'Bumerang', c: '#e8590c', atk: 1},
  meteor: {img: 'Comet', vi: 'Sao băng', c: '#f06595', atk: 1},
  pet: {img: 'Dog face', vi: 'Cún đánh hộ', c: '#b7793f', atk: 1},
  magnet: {img: 'Magnet', vi: 'Nam châm', c: '#fa5252'},
  shoes: {img: 'Running shoe', vi: 'Giày nhanh', c: '#20c997'},
  heart: {img: 'Red heart', vi: 'Thêm tim', c: '#ff6b6b'},
  armor: {img: 'Shield', vi: 'Khiên', c: '#748ffc'}
};
const SK = Object.keys(SKILLS), SK_MAX = 5, CAP = 45;  // 12 skill × 5 = 60 cấp, trần tổng 45: phải chọn món mình thích
// Nâng cấp vĩnh viễn mua bằng xu ở Kho vũ khí
export const PERM = {
  hp: {img: 'Red heart', vi: 'Máu', c: '#ff6b6b'},
  speed: {img: 'Running shoe', vi: 'Chạy', c: '#20c997'},
  power: {img: 'Flexed biceps', vi: 'Sức mạnh', c: '#f08c00'},
  gem: {img: 'Gem stone', vi: 'Ngọc', c: '#cc5de8'}
};
const PERM_MAX = 5, price = n => 80 + n * 40;  // 80, 120, 160, 200, 240 xu (một cấp ~25 xu, một lượt 3 cấp ~50-80 xu)
const IMGS = ['Coin', 'Glowing star', 'Ogre', 'Collision', ...SK.map(k => SKILLS[k].img), ...Object.values(PERM).map(p => p.img)];

// Quái thường (sprite Kenney plat/enemies, creatures/flyers). hp/sp/sz: hệ số; R: hình gốc quay mặt sang phải.
const KINDS = [
  {a: 'slime', hp: 1, sp: 1, sz: 1},
  {a: 'mouse', hp: .8, sp: 1.45, sz: .85},
  {a: 'bee', hp: .7, sp: 1.3, sz: .85, zig: 1},
  {a: 'fly', sheet: 'fly', hp: 1.2, sp: 1.2, sz: 1, R: 1, zig: 1},
  {a: 'ladybug', hp: 1.4, sp: 1.1, sz: .95},
  {a: 'worm', hp: 1.6, sp: .85, sz: 1},
  {a: 'sslime', hp: 2.2, sp: .95, sz: 1.05},
  {a: 'frog', hp: 1.8, sp: .7, sz: 1, hop: 1},
  {a: 'fslime', hp: 2.4, sp: .9, sz: 1.05, shoot: 1},
  {a: 'snail', hp: 3.5, sp: .6, sz: 1.2}
];
const BOSSES = [{k: 'bslime', vi: 'Vua slime'}, {k: 'dragon', vi: 'Rồng'}, {k: 'Ogre', vi: 'Quỷ khổng lồ'}];

const int = (v, a, b) => Math.max(a, Math.min(b, Math.floor(+v || 0)));
// Đọc carry phòng thủ: thiếu trường thì mặc định. Súng nước tối thiểu cấp 1 (món chính).
export function readCarry(c) {
  c = c && typeof c === 'object' ? c : {};
  const skills = {}, perm = {};
  for (const k of SK) skills[k] = int(c.skills && c.skills[k], 0, SK_MAX);
  for (const k in PERM) perm[k] = int(c.perm && c.perm[k], 0, PERM_MAX);
  if (!skills.gun) skills.gun = 1;
  const off = Array.isArray(c.off) ? c.off.filter(k => SKILLS[k] && skills[k]) : [];
  return {v: 1, coins: int(c.coins, 0, 1e7), skills, perm, off};
}
const totalOf = sk => SK.reduce((s, k) => s + sk[k], 0);
// Gộp: đồ sở hữu không bao giờ giảm so với bản đã lưu
function mergeCarry(old, cur) {
  const o = readCarry(old), out = readCarry(cur);
  for (const k of SK) out.skills[k] = Math.max(o.skills[k], out.skills[k]);
  for (const k in PERM) out.perm[k] = Math.max(o.perm[k], out.perm[k]);
  return out;
}

// ---------- Kho vũ khí (DOM, trước khi chơi) ----------
const CSS = `
.hunt-shop { position: absolute; inset: 0; z-index: 3; display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 64px 14px 20px; background: linear-gradient(#5f3dc4, #845ef7); overflow: auto; color: #fff; font-family: "Baloo 2", sans-serif; }
.hunt-shop h2 { margin: 0; font-size: 2em; text-shadow: 0 3px 0 rgba(0,0,0,.25); }
.hunt-coins { display: flex; align-items: center; gap: 8px; font-size: 2em; font-weight: 800; background: rgba(0,0,0,.25); border-radius: 30px; padding: 2px 22px 2px 10px; }
.hunt-coins img { width: 48px; height: 48px; }
.hunt-perm { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; width: min(820px, 100%); }
@media (max-width: 640px) { .hunt-perm { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.hunt-card { display: flex; flex-direction: column; align-items: center; gap: 0; padding: 10px 6px 10px; border-radius: 24px; background: #fff; border: 4px solid var(--c); box-shadow: 0 6px 0 rgba(0,0,0,.2); font: inherit; color: #343a40; cursor: pointer; }
.hunt-card img { width: 84px; height: 84px; }
.hunt-card b { font-size: 1.3em; color: var(--c); line-height: 1.1; }
.hunt-card .st { color: #fab005; font-size: 1.3em; letter-spacing: 1px; line-height: 1.2; }
.hunt-card .pr { display: flex; align-items: center; gap: 4px; font-size: 1.4em; font-weight: 800; }
.hunt-card .pr img { width: 30px; height: 30px; }
.hunt-card.no { opacity: .55; }
.hunt-card.max .pr { color: #2f9e44; }
.hunt-card:active { transform: scale(.96); }
.hunt-card.buy { animation: hunt-pop .4s; }
@keyframes hunt-pop { 50% { transform: scale(1.12); } }
.hunt-shop h3 { margin: 4px 0 0; font-size: 1.4em; }
.hunt-own { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; width: min(820px, 100%); }
.hunt-sk { position: relative; width: 74px; padding: 4px 2px 2px; border-radius: 18px; background: rgba(255,255,255,.95); border: 3px solid var(--c); font: inherit; cursor: pointer; }
.hunt-sk img { width: 50px; height: 50px; display: block; margin: 0 auto; }
.hunt-sk .st { display: block; color: #fab005; font-size: .72em; letter-spacing: -1px; line-height: 1.2; white-space: nowrap; }
.hunt-sk.off { opacity: .35; filter: grayscale(1); }
.hunt-sk.off::after { content: '✖'; position: absolute; top: 2px; right: 8px; color: #e03131; font-size: 1.4em; font-weight: 800; }
.hunt-play { margin-top: 6px; font: inherit; font-size: 2.2em; font-weight: 800; color: #fff; background: #40c057; border: 0; border-radius: 40px; padding: 6px 54px; box-shadow: 0 7px 0 #2b8a3e; cursor: pointer; }
.hunt-play:active { transform: translateY(4px); box-shadow: 0 3px 0 #2b8a3e; }
`;
const stars = (n, m = 5) => '★'.repeat(n) + '☆'.repeat(Math.max(0, m - n));
const pic = name => h('img', {src: src(name), alt: '', draggable: 'false'});

function armory(box, C, save) {
  return new Promise(resolve => {
    if (!document.getElementById('hunt-css')) document.head.append(h('style', {id: 'hunt-css'}, CSS));
    const coinsEl = h('span', {}, C.coins);
    const permBox = h('div', {class: 'hunt-perm'}), ownBox = h('div', {class: 'hunt-own'});
    const paint = () => {
      coinsEl.textContent = C.coins;
      permBox.replaceChildren(...Object.keys(PERM).map(k => {
        const P = PERM[k], n = C.perm[k], max = n >= PERM_MAX, cost = price(n), ok = !max && C.coins >= cost;
        const b = h('button', {class: 'hunt-card' + (max ? ' max' : ok ? '' : ' no'), style: {'--c': P.c}, onclick: () => {
          if (max || C.coins < cost) { sfx('wrong'); return; }
          C.coins -= cost; C.perm[k]++; sfx('power'); save(); paint();
          const nb = permBox.children[Object.keys(PERM).indexOf(k)]; if (nb) nb.classList.add('buy');
        }}, pic(P.img), h('b', {}, P.vi), h('span', {class: 'st'}, stars(n)), h('span', {class: 'pr'}, max ? '✔ MAX' : [pic('Coin'), cost]));
        return b;
      }));
      // Đồ của bé: chạm để bật/tắt (luôn còn ít nhất 1 vũ khí bật)
      const owned = SK.filter(k => C.skills[k] > 0);
      ownBox.replaceChildren(...owned.map(k => h('button', {class: 'hunt-sk' + (C.off.includes(k) ? ' off' : ''), style: {'--c': SKILLS[k].c}, onclick: () => {
        if (C.off.includes(k)) C.off = C.off.filter(x => x !== k);
        else if (SKILLS[k].atk && !SK.some(x => x !== k && SKILLS[x].atk && C.skills[x] && !C.off.includes(x))) { sfx('wrong'); return; }
        else C.off.push(k);
        sfx('tap'); save(); paint();
      }}, pic(SKILLS[k].img), h('span', {class: 'st'}, '★'.repeat(C.skills[k])))));
    };
    paint();
    const wrap = h('div', {class: 'hunt-shop'}, h('h2', {}, '🛡️ Kho vũ khí'), h('div', {class: 'hunt-coins'}, pic('Coin'), coinsEl), permBox,
      h('h3', {}, '🎒 Đồ của bé'), ownBox,
      h('button', {class: 'hunt-play', onclick: () => { sfx('tap'); wrap.remove(); resolve(true); }}, 'Chơi ▶'));
    box.append(wrap);
  });
}

// ---------- Game ----------
export async function hunt(box, opts) {
  const lv = opts.level || 0, th = theme(lv), BK = BOSSES[Math.floor(lv / 10) % BOSSES.length];
  const C = readCarry(opts.carry), saved = readCarry(opts.carry);
  const bot = !!opts._bot, TURBO = Math.max(1, opts._turbo || 1);
  const [[en, fly, tl, fxs]] = await Promise.all([sheets(['plat/enemies', 'creatures/flyers', 'plat/tiles', 'fxa/fx']), loadAll([opts.hero, th.sun, ...th.deco, ...IMGS])]);
  const save = () => { if (opts.saveGear) opts.saveGear(mergeCarry(saved, C)); };
  // Kho vũ khí: chỉ ở cấp đầu của lượt (opts dùng chung giữa các cấp trong một vé)
  if (!opts._huntShop && (!bot || opts._shop)) { opts._huntShop = true; await armory(box, C, save); if (!opts.alive()) return null; }
  opts._huntShop = true;

  const {cv, ctx, W, H} = canvasIn(box);
  cv.style.touchAction = 'none';
  const S = Math.min(W, H), DIAG = Math.hypot(W, H) / 2;
  const F = fx(), D = dust(220), B = booms(fxs, 28), SH = shaker();
  const sk = C.skills, on = k => sk[k] > 0 && !C.off.includes(k) ? sk[k] : 0;
  const L = k => on(k);  // cấp skill đang dùng
  const total = () => totalOf(sk);
  const pw = 1 + .12 * C.perm.power;
  const power = Math.min(1, (total() + Object.values(C.perm).reduce((a, b) => a + b, 0)) / (CAP + 20));  // 0..1 sức mạnh đồ
  // Cấp: quái đông, nhanh, trâu dần; trùm mạnh dần. Đồ mạnh thì quái/trùm tăng máu nhẹ.
  const DUR = Math.round(ramp(lv, 55, 75)), hpK = (1 + 11 * Math.pow(ramp(lv, 0, 1), 1.4)) * (1 + 1.5 * power * power), spK = S * ramp(lv, .085, .18);
  const CAPN = Math.round(ramp(lv, 32, 60)), spawnBase = ramp(lv, 1.05, .3);
  const U = Math.max(S, 460), fsz = U * .085;  // điện thoại: hình không quá bé
  const me = {x: 0, y: 0, r: U * .038, hp: 0, max: 0, inv: 0, face: 1, mv: 0, shield: 0, shieldT: 0, t: 0};
  const maxHp = () => 5 + C.perm.hp + L('heart');
  me.max = me.hp = maxHp();
  const speed = () => S * .3 * (1 + .06 * L('shoes') + .04 * C.perm.speed);
  const foes = [], shots = [], eshots = [], gems = [], coins = [], zaps = [], meteors = [], pets = [];
  const cd = {gun: .6, bolt: 1.2, fire: 1.5, boom: 1, meteor: 2};
  let t = 0, score = 0, earned = 0, kills = 0, xp = 0, spawnT = 2.5, wave = 0, boss = null, bossDone = false, end = null, endT = 0, msg = null, knifeA = 0, pickQ = 0, card = null;
  const need = () => { const n = total(); return n >= CAP ? 40 + lv : Math.round(3 + n * 1.5 + n * n * .04); };
  xp = need() * .2 * C.perm.gem;
  if (xp >= need()) { xp = 0; pickQ = 1; }
  const syncPets = () => { const n = L('pet') ? (L('pet') >= 4 ? 2 : 1) : 0; while (pets.length < n) pets.push({x: me.x - 40 * (pets.length + 1), y: me.y + 30, cd: 0, rig: petBuddy('dog'), face: 1, mv: 0}); };
  syncPets();
  const fig = heroOf(opts.hero);

  // ---- Điều khiển: cần ảo ở chỗ chạm + phím mũi tên ----
  const joy = {id: null, bx: 0, by: 0, x: 0, y: 0}, keys = {};
  const JR = Math.min(70, S * .11);
  const local = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  cv.addEventListener('pointerdown', e => {
    const [x, y] = local(e);
    if (card) { tapCard(x, y); return; }
    if (end) return;
    joy.id = e.pointerId; joy.bx = joy.x = x; joy.by = joy.y = y;
    try { cv.setPointerCapture(e.pointerId); } catch (er) { /* trình duyệt cũ */ }
  });
  cv.addEventListener('pointermove', e => { if (e.pointerId !== joy.id) return; const [x, y] = local(e); joy.x = x; joy.y = y; });
  const up = e => { if (e.pointerId === joy.id) joy.id = null; if (card) card.lift = true; };
  cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
  const kd = e => { if (!cv.isConnected) return cleanup(); keys[e.key] = e.type === 'keydown'; };
  window.addEventListener('keydown', kd); window.addEventListener('keyup', kd);
  const cleanup = () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', kd); };

  // ---- Thẻ chọn skill ----
  function makeCard() {
    const atTop = total() >= CAP;
    const avail = atTop ? [] : SK.filter(k => sk[k] < SK_MAX);
    // Ưu tiên vũ khí bé đã có (lên sao) và luôn có ít nhất 1 vũ khí đánh quái nếu còn
    const wt = k => (sk[k] ? 2 : 1) * (SKILLS[k].atk ? 1.3 : 1);
    const opts3 = [];
    const pool = [...avail];
    while (opts3.length < 3 && pool.length) {
      let r = Math.random() * pool.reduce((s, k) => s + wt(k), 0), i = 0;
      for (; i < pool.length - 1; i++) { r -= wt(pool[i]); if (r <= 0) break; }
      opts3.push({k: pool[i]}); pool.splice(i, 1);
    }
    if (opts3.length && !opts3.some(o => SKILLS[o.k].atk)) { const a = pool.filter(k => SKILLS[k].atk); if (a.length) opts3[opts3.length - 1] = {k: pick(a)}; }
    if (opts3.length < 3) opts3.push({k: 'coins'});
    if (opts3.length < 3) opts3.push({k: 'heal'});
    card = {list: opts3, t: 0, lift: !joy.id && !bot, sel: -1, rects: []};
    joy.id = null;
    sfx('star');
  }
  function choose(i) {
    const o = card.list[i]; if (!o) return;
    card.sel = i; card.done = .35;
    if (o.k === 'coins') { earned += 5; C.coins += 5; F.text(me.x, me.y - 60, '+5', '#ffd43b'); sfx('coin'); }
    else if (o.k === 'heal') { me.hp = maxHp(); F.text(me.x, me.y - 60, '+❤', '#ff6b6b'); sfx('power'); }
    else {
      sk[o.k] = Math.min(SK_MAX, sk[o.k] + 1); C.off = C.off.filter(x => x !== o.k);
      if (o.k === 'heart') { me.max = maxHp(); me.hp = Math.min(me.max, me.hp + 2); }
      if (o.k === 'pet') syncPets();
      if (o.k === 'armor') me.shieldT = 0;
      sfx('power'); D.sparks(me.x, me.y, 20, SKILLS[o.k].c, 320);
    }
    save();
  }
  function tapCard(x, y) {
    if (!card || card.sel >= 0 || card.t < .45 || !card.lift) return;
    card.rects.forEach((r, i) => { if (x > r[0] && x < r[0] + r[2] && y > r[1] && y < r[1] + r[3]) choose(i); });
  }

  // ---- Quái ----
  const visible = (o, pad = 0) => Math.abs(o.x - me.x) < W / 2 + pad && Math.abs(o.y - me.y) < H / 2 + pad;
  function spawnFoe(kind, x, y, elite = false) {
    if (foes.length >= CAPN) return null;
    if (x == null) { const a = rand(0, 6.283), d = DIAG + 40; x = me.x + Math.cos(a) * d; y = me.y + Math.sin(a) * d; }
    const k = kind || KINDS[0], sz = fsz * k.sz * (elite ? 1.7 : 1), hp = k.hp * hpK * (elite ? 10 : 1) * (1 + t / DUR * .4);
    const f = {K: k, x, y, h: sz, r: sz * .42, hp, max: hp, sp: spK * k.sp * rand(.9, 1.1) * (elite ? .8 : 1), ph: rand(0, 6), slow: 0, flash: 0, kh: 0, bh: 0, elite, vx: 0, sc: rand(2, 5), hopT: rand(1, 2)};
    foes.push(f);
    return f;
  }
  const poolNow = () => KINDS.slice(0, Math.min(KINDS.length, 2 + wave + Math.floor(lv / 5)));
  function hurtFoe(f, dmg, c = '#fff') {
    if (f.dead) return;
    f.hp -= dmg; f.flash = .08;
    if (f === boss) { if (Math.random() < .3) D.sparks(f.x, f.y, 4, c, 200); return; }
    if (f.hp <= 0) killFoe(f);
  }
  function killFoe(f) {
    f.dead = true; kills++;
    B.add(f.x, f.y, f.h * 1.3); D.sparks(f.x, f.y, 8, '#ffe066', 260);
    score += f.elite ? 5 : 1;
    if (f.elite) { gems.push({x: f.x, y: f.y, v: 10, k: 'gem_red'}); for (let i = 0; i < 3; i++) coins.push({x: f.x + rand(-30, 30), y: f.y + rand(-30, 30)}); if (Math.random() < .3) coins.push({x: f.x, y: f.y, heart: 1}); sfx('boom'); SH.add(5); }
    else {
      if (gems.length < 140) gems.push({x: f.x, y: f.y, v: lv >= 30 && Math.random() < .15 ? 3 : 1, k: 'gem_blue'});
      else gems[kills % gems.length].v += 1;  // nhiều ngọc quá: dồn vào ngọc cũ
      if (gems[gems.length - 1].v === 3) gems[gems.length - 1].k = 'gem_green';
      if (Math.random() < .04) coins.push({x: f.x, y: f.y});
      else if (Math.random() < .012) coins.push({x: f.x, y: f.y, heart: 1});  // tim rơi: hồi 1 máu
      if (Math.random() < .25) sfx('pop');
    }
  }
  const nearest = (x, y, maxD = 1e9) => {
    let best = null, bd = maxD * maxD;
    for (const f of foes) { if (f.dead) continue; const d = (f.x - x) ** 2 + (f.y - y) ** 2; if (d < bd) { bd = d; best = f; } }
    if (boss && !boss.dead) { const d = (boss.x - x) ** 2 + (boss.y - y) ** 2; if (d < bd) best = boss; }
    return best;
  };
  const allTargets = () => boss && !boss.dead ? [...foes.filter(f => !f.dead), boss] : foes.filter(f => !f.dead);
  const area = (x, y, rad, dmg, c) => { for (const f of allTargets()) if (Math.hypot(f.x - x, f.y - y) < rad + f.r) hurtFoe(f, dmg, c); };

  function startBoss() {
    const hp = ramp(lv, 40, 1200) * (1 + 1.5 * power * power), a = rand(0, 6.283);
    boss = {x: me.x + Math.cos(a) * DIAG * .9, y: me.y + Math.sin(a) * DIAG * .9, h: S * .3, r: S * .12, hp, max: hp, sp: S * ramp(lv, .07, .12), ring: 2.5, sum: 5, dash: 4, dashT: 0, aim: 0, dx: 0, dy: 0, flash: 0, ph: 0, slow: 0, kh: 0, bh: 0, K: {}};
    msg = {s: `${BK.vi.toUpperCase()} ĐÃ TỚI!`, t: 2.2, c: '#ff6b6b'}; sfx('power'); SH.add(10);
  }

  function hurtMe(n = 1) {
    if (me.inv > 0 || end) return;
    if (me.shield) { me.shield = 0; me.inv = .8; me.shieldT = 0; sfx('pop'); D.sparks(me.x, me.y, 14, '#748ffc', 260); return; }
    me.hp -= n; me.inv = 1.3 + .1 * L('armor'); sfx('hit'); SH.add(8); D.sparks(me.x, me.y, 12, '#ff8787', 280);
    if (me.hp <= 0) { me.hp = 0; finish(false); }
  }
  function finish(win) {
    if (end) return;
    if (win) { const b = 5 + Math.floor(lv / 5); earned += b; C.coins += b; score += 50; sfx('win'); }
    // Hút hết ngọc/xu còn trên sân thành điểm
    score += earned;
    const carry = mergeCarry(saved, C);
    end = {win, score, carry, kills};
    cleanup();
  }

  // ---- Một bước mô phỏng ----
  function step(dt) {
    if (card) {
      card.t += dt;
      if (bot && card.t > (opts._pickDelay || .5) && card.sel < 0) choose(0);
      if (card.sel >= 0) { card.done -= dt; if (card.done <= 0) { card = null; pickQ = Math.max(0, pickQ - 1); if (bot) window.__hunt = {...window.__hunt, card: false}; } }
      return;
    }
    if (pickQ > 0) { makeCard(); if (bot) window.__hunt = {...window.__hunt, card: true}; return; }
    t += dt; me.t += dt;
    F.update(dt); D.update(dt); B.update(dt); SH.update(dt);
    if (msg) { msg.t -= dt; if (msg.t <= 0) msg = null; }
    if (end) return;
    // Di chuyển
    let mx = 0, my = 0;
    if (joy.id != null) {
      const dx = joy.x - joy.bx, dy = joy.y - joy.by, d = Math.hypot(dx, dy);
      if (d > 8) { const k = Math.min(1, d / JR); mx = dx / d * k; my = dy / d * k; }
      if (d > JR) { joy.bx = joy.x - dx / d * JR; joy.by = joy.y - dy / d * JR; }  // cần ảo đi theo ngón tay
    } else if (bot) [mx, my] = botMove();
    else {
      mx = (keys.ArrowRight || keys.d ? 1 : 0) - (keys.ArrowLeft || keys.a ? 1 : 0); my = (keys.ArrowDown || keys.s ? 1 : 0) - (keys.ArrowUp || keys.w ? 1 : 0);
      const d = Math.hypot(mx, my); if (d > 1) { mx /= d; my /= d; }
    }
    const sp = speed();
    me.x += mx * sp * dt; me.y += my * sp * dt; me.mv = Math.hypot(mx, my);
    if (Math.abs(mx) > .15) me.face = mx > 0 ? 1 : -1;
    me.inv = Math.max(0, me.inv - dt);
    if (L('armor') && !me.shield) { me.shieldT += dt; if (me.shieldT >= 13 - 2 * L('armor')) { me.shield = 1; me.shieldT = 0; sfx('pop'); } }

    // Đợt quái + sinh quái
    const nw = Math.min(3, Math.floor(t / (DUR / 4)));
    if (nw > wave && t < DUR) {
      wave = nw; msg = {s: `ĐỢT ${wave + 1}!`, t: 1.6, c: '#ffd43b'}; sfx('power');
      // Vòng vây: quái xếp vòng quanh bé + 1 quái to (elite)
      const n = Math.round(ramp(lv, 8, 16)), pool = poolNow(), k = pick(pool);
      for (let i = 0; i < n; i++) { const a = i / n * 6.283; spawnFoe(k, me.x + Math.cos(a) * DIAG * .95, me.y + Math.sin(a) * DIAG * .95); }
      spawnFoe(pick(pool), null, null, true);
    }
    if (t > 2.5) {
      spawnT -= dt;
      const rate = boss ? 2.2 : 1 - .45 * Math.min(1, t / DUR);
      if (spawnT <= 0) {
        spawnT = spawnBase * rate * rand(.8, 1.2);
        const g = boss ? 1 : 1 + Math.floor(t / 25) + Math.floor(lv / 15), pool = poolNow();
        for (let i = 0; i < g; i++) spawnFoe(pick(pool));
      }
    }
    if (t >= DUR && !boss && !bossDone) startBoss();

    // Quái đi về phía bé
    const frostR = L('frost') ? S * (.13 + .025 * L('frost')) : 0, frostSlow = .55 - .05 * L('frost'), frostDps = (.6 + .35 * L('frost')) * pw;
    for (const f of foes) {
      if (f.dead) continue;
      f.ph += dt; f.flash = Math.max(0, f.flash - dt); f.kh = Math.max(0, f.kh - dt); f.bh = Math.max(0, f.bh - dt);
      let dx = me.x - f.x, dy = me.y - f.y; const d = Math.hypot(dx, dy) || 1; dx /= d; dy /= d;
      let v = f.sp * (f.slow > 0 ? frostSlow : 1); f.slow = Math.max(0, f.slow - dt);
      if (f.K.hop) { f.hopT -= dt; v *= f.hopT < .35 ? 3.2 : .25; if (f.hopT <= 0) f.hopT = rand(1.2, 2); }
      if (f.K.zig) { const z = Math.sin(f.ph * f.sc) * .7; const ox = -dy * z, oy = dx * z; dx += ox; dy += oy; }
      f.x += dx * v * dt; f.y += dy * v * dt; f.vx = dx;
      if (d > DIAG * 1.8) { const a = (me.mv > .1 ? Math.atan2(my, mx) : rand(0, 6.283)) + rand(-.8, .8), dd = DIAG + 40; f.x = me.x + Math.cos(a) * dd; f.y = me.y + Math.sin(a) * dd; }  // quái bị bỏ xa: đưa ra phía trước
      if (frostR && d < frostR + f.r) { f.slow = .3; hurtFoe(f, frostDps * dt, '#74c0fc'); }
      if (f.K.shoot && lv >= 12 && d < DIAG) { f.sc -= dt * .3; if (f.sc <= 0) { f.sc = rand(3, 5) * ramp(lv, 1.3, .8); if (eshots.length < 40) eshots.push({x: f.x, y: f.y, vx: dx * S * .32, vy: dy * S * .32, r: S * .022, life: 4}); } }
      if (!f.dead && d < f.r + me.r) hurtMe(f.elite && lv >= 40 ? 2 : 1);
    }
    // Quái không chồng lên nhau
    for (let i = 0; i < foes.length; i++) {
      const a = foes[i];
      for (let j = i + 1; j < foes.length; j++) {
        const b = foes[j], dx = b.x - a.x, dy = b.y - a.y, rr = (a.r + b.r) * .85, d2 = dx * dx + dy * dy;
        if (d2 < rr * rr && d2 > .01) { const d = Math.sqrt(d2), p = (rr - d) / 2 / d; a.x -= dx * p; a.y -= dy * p; b.x += dx * p; b.y += dy * p; }
      }
    }

    // Trùm
    if (boss && !boss.dead) {
      const b = boss; b.ph += dt; b.flash = Math.max(0, b.flash - dt); b.kh = Math.max(0, b.kh - dt); b.bh = Math.max(0, b.bh - dt);
      const dx = me.x - b.x, dy = me.y - b.y, d = Math.hypot(dx, dy) || 1, rage = b.hp < b.max / 2;
      if (b.dashT > 0) { b.dashT -= dt; if (b.aim > 0) b.aim -= dt; else { b.x += b.dx * b.sp * 4.5 * dt; b.y += b.dy * b.sp * 4.5 * dt; } }
      else { const v = b.sp * (b.slow > 0 ? .7 : 1); b.x += dx / d * v * dt; b.y += dy / d * v * dt; }
      b.slow = Math.max(0, b.slow - dt);
      if (frostR && d < frostR + b.r) { b.slow = .3; hurtFoe(b, frostDps * dt, '#74c0fc'); }
      b.ring -= dt; b.sum -= dt; b.dash -= dt;
      if (b.ring <= 0) {
        b.ring = ramp(lv, 3.4, 1.7) * (rage ? .75 : 1);
        const n = Math.round(ramp(lv, 6, 16)), off = rand(0, 1);
        for (let i = 0; i < n && eshots.length < 80; i++) { const a = (i + off) / n * 6.283; eshots.push({x: b.x, y: b.y, vx: Math.cos(a) * S * ramp(lv, .24, .38), vy: Math.sin(a) * S * ramp(lv, .24, .38), r: S * .026, life: 5}); }
        sfx('boom'); SH.add(4);
      }
      if (b.sum <= 0) { b.sum = ramp(lv, 7, 4); const pool = poolNow(); for (let i = 0; i < 3 + Math.floor(lv / 15); i++) spawnFoe(pick(pool), b.x + rand(-80, 80), b.y + rand(-80, 80)); }
      if (lv >= 15 && b.dash <= 0 && b.dashT <= 0) { b.dash = ramp(lv, 6, 3.5); b.dashT = 1.15; b.aim = .65; b.dx = dx / d; b.dy = dy / d; F.text(b.x, b.y - b.h * .6, '!!', '#ff6b6b'); }
      if (d < b.r + me.r) hurtMe(lv >= 30 ? 2 : 1);
      if (b.hp <= 0) {
        b.dead = true; bossDone = true;
        for (let k = 0; k < 8; k++) B.add(b.x + rand(-b.h * .4, b.h * .4), b.y + rand(-b.h * .4, b.h * .4), rand(90, 160));
        D.sparks(b.x, b.y, 30, '#ffd43b', 420); SH.add(16);
        for (let i = 0; i < 10; i++) coins.push({x: b.x + rand(-60, 60), y: b.y + rand(-60, 60), fly: true});
        for (const f of foes) if (!f.dead) killFoe(f);
        for (const g of gems) g.fly = true;
        eshots.length = 0;
        endT = 1.6;  // chờ xu/ngọc bay về rồi mới kết thúc
      }
    }
    if (bossDone && !end) { endT -= dt; if (endT <= 0) finish(true); }

    // ---- Vũ khí ----
    const tgtR = DIAG * 1.05;
    if (L('gun')) {
      cd.gun -= dt;
      if (cd.gun <= 0) {
        const f = boss && !boss.dead && visible(boss) && (cd.alt = !cd.alt) ? boss : nearest(me.x, me.y, tgtR);
        if (f) {
          const l = L('gun'); cd.gun = .62 - .06 * l;
          const n = [1, 1, 2, 2, 3][l - 1], a0 = Math.atan2(f.y - me.y, f.x - me.x);
          for (let i = 0; i < n && shots.length < 90; i++) { const a = a0 + (i - (n - 1) / 2) * .14; shots.push({k: 'gun', x: me.x, y: me.y, vx: Math.cos(a) * S * 1.1, vy: Math.sin(a) * S * 1.1, r: S * .016 + l, dmg: (1 + .3 * (l - 1)) * pw, life: 1.2, pierce: l >= 5 ? 2 : 1}); }
          me.face = f.x > me.x ? 1 : -1;
          if (Math.random() < .4) sfx('laser');
        }
      }
    }
    if (L('fire')) {
      cd.fire -= dt;
      if (cd.fire <= 0) {
        const f = nearest(me.x, me.y, tgtR);
        if (f) {
          const l = L('fire'); cd.fire = 2.4 - .25 * l;
          for (let i = 0; i < (l >= 4 ? 2 : 1) && shots.length < 90; i++) { const a = Math.atan2(f.y - me.y, f.x - me.x) + (i ? .35 : 0); shots.push({k: 'fire', x: me.x, y: me.y, vx: Math.cos(a) * S * .6, vy: Math.sin(a) * S * .6, r: S * .03, dmg: (3 + l) * pw, rad: S * (.09 + .015 * l), life: 1.4, pierce: 1}); }
        }
      }
    }
    if (L('boom')) {
      cd.boom -= dt;
      if (cd.boom <= 0) {
        const f = nearest(me.x, me.y, tgtR);
        if (f) {
          const l = L('boom'); cd.boom = 2 - .2 * l;
          const n = [1, 1, 2, 2, 3][l - 1], a0 = Math.atan2(f.y - me.y, f.x - me.x);
          for (let i = 0; i < n && shots.length < 90; i++) { const a = a0 + (i - (n - 1) / 2) * .6; shots.push({k: 'boom', x: me.x, y: me.y, a, t: 0, dist: S * .45, r: S * .035, dmg: (1.5 + .4 * l) * pw, life: 1.2}); }
        }
      }
    }
    if (L('bolt')) {
      cd.bolt -= dt;
      if (cd.bolt <= 0) {
        const l = L('bolt'), list = allTargets().filter(f => visible(f));
        if (list.length) {
          cd.bolt = 2.6 - .3 * l;
          for (let i = 0; i < [1, 2, 2, 3, 4][l - 1] && list.length; i++) {
            const f = list.splice(Math.floor(Math.random() * list.length), 1)[0];
            zaps.push({x: f.x, y: f.y, life: .22, seed: Math.random() * 99}); hurtFoe(f, (3 + 1.2 * l) * pw, '#fcc419'); D.sparks(f.x, f.y, 8, '#fff3bf', 240);
          }
          sfx('laser');
        }
      }
    }
    if (L('meteor')) {
      cd.meteor -= dt;
      if (cd.meteor <= 0) {
        const l = L('meteor'), list = allTargets().filter(f => visible(f));
        cd.meteor = 4.2 - .5 * l;
        for (let i = 0; i < [1, 1, 2, 2, 3][l - 1]; i++) {
          const f = boss && !boss.dead && visible(boss) && Math.random() < .5 ? boss : list.length ? pick(list) : null;
          meteors.push({x: f ? f.x : me.x + rand(-W / 3, W / 3), y: f ? f.y : me.y + rand(-H / 3, H / 3), t: 0, dur: .6 + i * .12, dmg: (4 + 1.5 * l) * pw, rad: S * .11});
        }
      }
    }
    const TG = allTargets();  // một mảng mục tiêu cho cả khung (đỡ cấp phát mỗi viên đạn)
    // Dao bay xoay quanh
    if (L('knife')) {
      knifeA += dt * 3.4;
      const l = L('knife'), R = S * .14, kr = S * .035;
      for (let i = 0; i < l; i++) {
        const a = knifeA + i / l * 6.283, kx = me.x + Math.cos(a) * R, ky = me.y + Math.sin(a) * R;
        for (const f of TG) if (!f.dead && f.kh <= 0 && Math.hypot(f.x - kx, f.y - ky) < f.r + kr) { f.kh = .35; hurtFoe(f, (1.2 + .35 * l) * pw, '#dee2e6'); D.sparks(kx, ky, 4, '#fff', 200); }
      }
    }
    // Đạn bay
    for (let i = shots.length - 1; i >= 0; i--) {
      const s = shots[i]; s.life -= dt;
      if (s.k === 'boom') {
        s.t += dt; const k = s.t / 1.2, d = Math.sin(Math.min(1, k) * Math.PI) * s.dist;  // bay ra rồi quay về
        s.x = me.x + Math.cos(s.a) * d; s.y = me.y + Math.sin(s.a) * d;
        for (const f of TG) if (!f.dead && f.bh <= 0 && Math.hypot(f.x - s.x, f.y - s.y) < f.r + s.r) { f.bh = .3; hurtFoe(f, s.dmg, '#e8590c'); }
        if (s.t >= 1.2) shots.splice(i, 1);
        continue;
      }
      s.x += s.vx * dt; s.y += s.vy * dt;
      let gone = s.life <= 0;
      if (!gone) for (const f of TG) {
        if (f.dead) continue;
        if (Math.hypot(f.x - s.x, f.y - s.y) > f.r + s.r || (s.hit && s.hit.includes(f))) continue;
        if (s.k === 'fire') { gone = true; break; }
        hurtFoe(f, s.dmg, '#74c0fc'); (s.hit = s.hit || []).push(f);
        if (--s.pierce <= 0) { gone = true; break; }
      }
      if (gone) {
        if (s.k === 'fire') { area(s.x, s.y, s.rad, s.dmg, '#ff922b'); B.add(s.x, s.y, s.rad * 2.2); D.sparks(s.x, s.y, 12, '#ff922b', 300); SH.add(2); sfx('boom'); }
        shots.splice(i, 1);
      }
    }
    for (let i = meteors.length - 1; i >= 0; i--) {
      const m = meteors[i]; m.t += dt;
      if (m.t >= m.dur) { area(m.x, m.y, m.rad, m.dmg, '#f06595'); B.add(m.x, m.y, m.rad * 2.4); D.debris(m.x, m.y, 10, '#868e96', 300); SH.add(4); sfx('boom'); meteors.splice(i, 1); }
    }
    for (let i = zaps.length - 1; i >= 0; i--) { zaps[i].life -= dt; if (zaps[i].life <= 0) zaps.splice(i, 1); }
    // Cún đánh hộ
    for (const p of pets) {
      const l = L('pet'), f = nearest(p.x, p.y, DIAG);
      let tx = me.x - me.face * S * .08, ty = me.y + S * .05;
      if (f) { tx = f.x; ty = f.y; }
      const dx = tx - p.x, dy = ty - p.y, d = Math.hypot(dx, dy) || 1, v = S * (.42 + .03 * l);
      if (d > 6) { p.x += dx / d * Math.min(d, v * dt); p.y += dy / d * Math.min(d, v * dt); p.face = dx > 0 ? 1 : -1; }
      p.mv = d > 10; p.rig.update(dt, p.mv);
      if (Math.hypot(p.x - me.x, p.y - me.y) > DIAG * 1.2) { p.x = me.x; p.y = me.y; }
      p.cd -= dt;
      if (f && p.cd <= 0 && d < f.r + S * .04) { p.cd = .8 - .05 * l; hurtFoe(f, (1.5 + .7 * l) * pw, '#b7793f'); D.sparks(f.x, f.y, 5, '#fff', 200); if (Math.random() < .3) sfx('bark'); }
    }
    for (let i = foes.length - 1; i >= 0; i--) if (foes[i].dead) foes.splice(i, 1);
    // Đạn quái
    for (let i = eshots.length - 1; i >= 0; i--) {
      const s = eshots[i]; s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
      if (s.life <= 0) { eshots.splice(i, 1); continue; }
      if (Math.hypot(s.x - me.x, s.y - me.y) < s.r + me.r * .8) { eshots.splice(i, 1); hurtMe(1); }
    }
    // Ngọc + xu: trong tầm nam châm thì bay về bé
    const magR = U * (.18 + .06 * L('magnet'));
    for (let i = gems.length - 1; i >= 0; i--) {
      const g = gems[i], dx = me.x - g.x, dy = me.y - g.y, d = Math.hypot(dx, dy);
      if (d < magR) g.fly = true;
      if (g.fly) { const v = S * 1.4 * dt; g.x += dx / (d || 1) * Math.min(d, v); g.y += dy / (d || 1) * Math.min(d, v); }
      if (d < me.r + 10) {
        gems.splice(i, 1); xp += g.v; score += g.v > 1 ? 1 : 0;
        if (Math.random() < .3) sfx('coin');
        if (xp >= need()) { xp -= need(); pickQ++; }
      }
    }
    for (let i = coins.length - 1; i >= 0; i--) {
      const c = coins[i], dx = me.x - c.x, dy = me.y - c.y, d = Math.hypot(dx, dy);
      if (d < magR) c.fly = true;
      if (c.fly) { const v = S * 1.4 * dt; c.x += dx / (d || 1) * Math.min(d, v); c.y += dy / (d || 1) * Math.min(d, v); }
      if (d < me.r + 12) { coins.splice(i, 1); if (c.heart) { me.hp = Math.min(me.max, me.hp + 1); sfx('power'); F.text(c.x, c.y - 20, '+❤', '#ff6b6b'); } else { earned++; C.coins++; sfx('coin'); F.text(c.x, c.y - 20, '+1', '#ffd43b'); } }
    }
    if (bot && Math.floor(t * 2) !== Math.floor((t - dt) * 2)) window.__hunt = {card: false, t, hp: me.hp, max: me.max, kills, total: total(), foes: foes.length, boss: boss ? Math.round(boss.hp) : null, bossMax: boss ? Math.round(boss.max) : null, xp, coins: C.coins, lv};
  }

  // Lái tự động khi test (opts._bot): đi lang thang như bé, nhặt ngọc gần, chỉ né quái sát người
  let wp = null, wpT = 0;
  function botMove() {
    wpT -= 1 / 60;
    if (!wp || wpT <= 0 || Math.hypot(wp.x - me.x, wp.y - me.y) < 20) { wp = {x: me.x + rand(-S * .6, S * .6), y: me.y + rand(-S * .6, S * .6)}; wpT = rand(1.5, 3); }
    let ax = wp.x - me.x, ay = wp.y - me.y; const dw = Math.hypot(ax, ay) || 1; ax /= dw; ay /= dw;
    const g = gems.find(q => Math.hypot(q.x - me.x, q.y - me.y) < S * .3);
    if (g) { const dx = g.x - me.x, dy = g.y - me.y, d = Math.hypot(dx, dy) || 1; ax += dx / d; ay += dy / d; }
    for (const f of [...foes, ...eshots, ...(boss && !boss.dead ? [boss] : [])]) {
      const dx = me.x - f.x, dy = me.y - f.y, d = Math.hypot(dx, dy) || 1, R = (f.r || 10) + S * (opts._bot === 2 ? .2 : .1);
      if (d < R) { ax += dx / d * 1.5; ay += dy / d * 1.5; }
    }
    const d = Math.hypot(ax, ay) || 1;
    return [ax / d, ay / d];
  }

  // ---- Vẽ ----
  const hash = (i, j) => { const s = Math.sin(i * 127.1 + j * 311.7) * 43758.5453; return s - Math.floor(s); };
  function drawFoe(f) {
    const flip = f.K.R ? f.vx < 0 : f.vx > 0, sq = 1 + Math.sin(f.ph * 10) * .06;
    ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(f.x, f.y + f.h * .42, f.h * .36, f.h * .1, 0, 0, 7); ctx.fill();
    ctx.save(); ctx.translate(f.x, f.y + f.h * .45); ctx.scale(1 / sq, sq);
    if (f.K.sheet === 'fly') anim(ctx, fly, 'fly', f.ph, 0, -f.h * .45, f.h, {flip, alpha: f.flash > 0 ? .55 : 1});
    else anim(ctx, en, f.K.a, f.ph, 0, -f.h * .45, f.h, {flip, alpha: f.flash > 0 ? .55 : 1});
    ctx.restore();
    if (f.slow > 0) { ctx.fillStyle = 'rgba(116,192,252,.35)'; ctx.beginPath(); ctx.arc(f.x, f.y, f.r * 1.1, 0, 7); ctx.fill(); }
    if (f.elite) {
      ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(f.x - f.h * .4, f.y - f.h * .62, f.h * .8, 7);
      ctx.fillStyle = '#ff6b6b'; ctx.fillRect(f.x - f.h * .4, f.y - f.h * .62, f.h * .8 * Math.max(0, f.hp / f.max), 7);
    }
  }
  function drawBoss(b) {
    const a = b.flash > 0 ? .6 : 1, flip = me.x > b.x;
    ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.beginPath(); ctx.ellipse(b.x, b.y + b.h * .42, b.h * .38, b.h * .1, 0, 0, 7); ctx.fill();
    if (b.aim > 0) { ctx.strokeStyle = `rgba(255,60,60,${.4 + .4 * Math.sin(t * 30)})`; ctx.lineWidth = b.r * 1.4; ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(b.x + b.dx * b.sp * 4.5 * .5, b.y + b.dy * b.sp * 4.5 * .5); ctx.stroke(); }
    const jx = b.hp < b.max / 2 ? Math.sin(t * 50) * 2 : 0;
    if (BK.k === 'dragon') anim(ctx, fly, 'dragon', b.ph, b.x + jx, b.y + Math.sin(b.ph * 3) * 8, b.h * .85, {flip: !flip, alpha: a});
    else if (BK.k === 'Ogre') draw(ctx, 'Ogre', b.x + jx, b.y, b.h, b.h, {flip: flip, rot: Math.sin(b.ph * 6) * .06, alpha: a});
    else { const sq = 1 + Math.sin(b.ph * 5) * .07; ctx.save(); ctx.translate(b.x + jx, b.y + b.h * .45); ctx.scale(sq, 1 / sq); anim(ctx, en, b.hp < b.max / 2 ? 'fslime' : 'bslime', b.ph, 0, -b.h * .45, b.h, {flip, alpha: a}); ctx.restore(); }
    if (b.slow > 0) { ctx.strokeStyle = 'rgba(116,192,252,.7)'; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(b.x, b.y, b.r * 1.2, 0, 7); ctx.stroke(); }
  }
  function drawWorld() {
    ctx.fillStyle = th.ground; ctx.fillRect(0, 0, W, H);
    ctx.save();
    SH.apply(ctx);
    ctx.translate(Math.round(W / 2 - me.x), Math.round(H / 2 - me.y));
    // Nền: cỏ lấm tấm + cảnh trang trí theo ô lưới (vẽ ô nhìn thấy)
    const G = 170, i0 = Math.floor((me.x - W / 2) / G) - 1, i1 = Math.floor((me.x + W / 2) / G) + 1, j0 = Math.floor((me.y - H / 2) / G) - 1, j1 = Math.floor((me.y + H / 2) / G) + 1;
    ctx.fillStyle = th.edge;
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) {
      const r = hash(i, j), x = i * G + r * G, y = j * G + hash(j, i) * G;
      ctx.globalAlpha = .45; ctx.beginPath(); ctx.ellipse(x, y, 16 + r * 14, 6 + r * 4, 0, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
    }
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) {
      const r = hash(i + 7, j - 3);
      if (r < .16) draw(ctx, th.deco[Math.floor(r * 100) % th.deco.length], i * G + G / 2, j * G + G / 2, S * .1 + r * 120);
    }
    for (const g of gems) spr(ctx, tl, g.k, g.x, g.y, g.v >= 10 ? 40 : g.v >= 3 ? 32 : 26);
    for (const c of coins) if (c.heart) draw(ctx, 'Red heart', c.x, c.y + Math.sin(t * 4) * 3, 34); else coin(ctx, fxs, t + c.x * .01, c.x, c.y, 30);
    // Vòng băng quanh bé
    if (L('frost')) {
      const R = S * (.13 + .025 * L('frost'));
      ctx.fillStyle = 'rgba(165,216,255,.22)'; ctx.beginPath(); ctx.arc(me.x, me.y, R, 0, 7); ctx.fill();
      ctx.strokeStyle = 'rgba(116,192,252,.75)'; ctx.lineWidth = 3; ctx.setLineDash([10, 10]); ctx.lineDashOffset = -t * 30; ctx.beginPath(); ctx.arc(me.x, me.y, R, 0, 7); ctx.stroke(); ctx.setLineDash([]);
      for (let i = 0; i < 3; i++) { const a = t * 1.2 + i * 2.094; draw(ctx, 'Snowflake', me.x + Math.cos(a) * R, me.y + Math.sin(a) * R, 26, 26, {rot: t * 2}); }
    }
    for (const m of meteors) { const k = m.t / m.dur; ctx.strokeStyle = 'rgba(240,101,149,.8)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(m.x, m.y, m.rad * (1.2 - k * .2), 0, 7); ctx.stroke(); ctx.fillStyle = `rgba(240,101,149,${k * .3})`; ctx.fill(); }
    for (const f of foes) drawFoe(f);
    for (const p of pets) p.rig.draw(ctx, p.x, p.y + U * .03, U * .045, p.face);
    if (boss && !boss.dead) drawBoss(boss);
    D.draw(ctx); B.draw(ctx);  // nổ vẽ dưới bé để bé luôn nhìn thấy mình
    // Bé (người que mặc theo linh vật), nhấp nháy khi vừa trúng đòn
    if (!(me.inv > 0 && Math.floor(me.inv * 10) % 2 === 0)) {
      const FH = U * .14;
      drawFigure(ctx, me.x, me.y + FH * .45, FH, {c: fig, pose: me.mv > .1 ? 'run' : 'idle', t: me.t, face: me.face, weapon: L('gun') ? 'Water pistol' : null});
    }
    if (me.shield) { ctx.strokeStyle = 'rgba(116,143,252,.9)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(me.x, me.y, U * .085, 0, 7); ctx.stroke(); ctx.fillStyle = 'rgba(116,143,252,.15)'; ctx.fill(); }
    if (L('knife')) { const l = L('knife'), R = S * .14; for (let i = 0; i < l; i++) { const a = knifeA + i / l * 6.283; draw(ctx, 'Dagger', me.x + Math.cos(a) * R, me.y + Math.sin(a) * R, S * .07, S * .07, {rot: a + Math.PI * 1.25}); } }
    for (const s of shots) {
      if (s.k === 'gun') { ctx.fillStyle = '#1c7ed6'; ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, 7); ctx.fill(); ctx.fillStyle = '#a5d8ff'; ctx.beginPath(); ctx.arc(s.x - s.r * .3, s.y - s.r * .3, s.r * .45, 0, 7); ctx.fill(); }
      else if (s.k === 'fire') draw(ctx, 'Fire', s.x, s.y, s.r * 2.6, s.r * 2.6, {rot: Math.atan2(s.vy, s.vx) + Math.PI / 2});
      else draw(ctx, 'Boomerang', s.x, s.y, s.r * 2.4, s.r * 2.4, {rot: s.t * 14});
    }
    for (const m of meteors) { const k = m.t / m.dur; draw(ctx, 'Comet', m.x + (1 - k) * S * .5, m.y - (1 - k) * S * .8, S * .1, S * .1, {rot: -.6}); }
    for (const s of eshots) spr(ctx, tl, 'fireball', s.x, s.y, s.r * 2.6, {rot: Math.atan2(s.vy, s.vx) + Math.PI});
    // Tia sét: đường gấp khúc từ trên trời xuống
    for (const z of zaps) {
      ctx.strokeStyle = '#fff3bf'; ctx.lineWidth = 7; ctx.globalAlpha = z.life / .22;
      for (const [lw, c] of [[8, '#fcc419'], [3, '#fff']]) {
        ctx.strokeStyle = c; ctx.lineWidth = lw; ctx.beginPath(); ctx.moveTo(z.x + 20, z.y - H * .6);
        for (let k = 1; k <= 6; k++) ctx.lineTo(z.x + (k < 6 ? (hash(z.seed, k) - .5) * 50 : 0), z.y - H * .6 * (1 - k / 6));
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
    }
    F.draw(ctx);
    ctx.restore();
  }
  function drawHud() {
    hud(ctx, W, {score: C.coins, time: boss || bossDone ? null : Math.max(0, DUR - t), boss: boss && !boss.dead ? boss : null});
    // Tim
    const n = me.max, narrow = W < 640, hs = Math.min(28, (narrow ? W * .6 : W * .36) / n), x0 = W - 14 - hs / 2, hy = narrow ? 78 : 32;  // màn hẹp: tim xuống dòng dưới
    for (let i = 0; i < n; i++) draw(ctx, 'Red heart', x0 - i * hs * 1.05, hy, hs * .95, hs * .95, {alpha: i < me.hp ? 1 : .22});
    if (me.shield) draw(ctx, 'Shield', x0 - n * hs * 1.05 - 6, hy, hs, hs);
    // Thanh ngọc (kinh nghiệm) dưới cùng
    const by = H - 18, bw = W - 70, k = Math.min(1, xp / need());
    ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, 50, by - 9, bw, 18, 9); ctx.fill();
    ctx.fillStyle = total() >= CAP ? '#ffd43b' : '#4dabf7'; if (k > .02) { roundRect(ctx, 52, by - 7, (bw - 4) * k, 14, 7); ctx.fill(); }
    spr(ctx, tl, 'gem_blue', 30, by, 30);
    // Skill đang có: hình + sao
    const own = SK.filter(q => sk[q] > 0), is = Math.min(44, (W - 20) / Math.max(1, own.length) - 4);
    own.forEach((q, i) => {
      const x = 10 + is / 2 + i * (is + 4), y = by - 22 - is / 2, off = C.off.includes(q);
      ctx.fillStyle = 'rgba(255,255,255,.75)'; roundRect(ctx, x - is / 2, y - is / 2, is, is + 8, 10); ctx.fill();
      draw(ctx, SKILLS[q].img, x, y - 2, is * .78, is * .78, {alpha: off ? .3 : 1});
      ctx.fillStyle = '#f59f00'; ctx.font = `800 ${Math.max(8, is * .22)}px sans-serif`; ctx.textAlign = 'center'; ctx.fillText('★'.repeat(sk[q]), x, y + is / 2 + 4);
    });
    // Cần điều khiển ảo
    if (joy.id != null) {
      ctx.fillStyle = 'rgba(255,255,255,.25)'; ctx.beginPath(); ctx.arc(joy.bx, joy.by, JR, 0, 7); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = 3; ctx.stroke();
      const dx = joy.x - joy.bx, dy = joy.y - joy.by, d = Math.hypot(dx, dy), m = Math.min(d, JR) / (d || 1);
      ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.beginPath(); ctx.arc(joy.bx + dx * m, joy.by + dy * m, JR * .45, 0, 7); ctx.fill();
    }
    if (msg) {
      ctx.globalAlpha = Math.min(1, msg.t * 2); ctx.textAlign = 'center'; ctx.font = `800 ${Math.min(54, W * .09)}px "Baloo 2", sans-serif`;
      ctx.strokeStyle = 'rgba(0,0,0,.4)'; ctx.lineWidth = 6; ctx.strokeText(msg.s, W / 2, H * .3); ctx.fillStyle = msg.c; ctx.fillText(msg.s, W / 2, H * .3); ctx.globalAlpha = 1;
    }
  }
  function drawCards() {
    ctx.fillStyle = 'rgba(20,10,60,.62)'; ctx.fillRect(0, 0, W, H);
    ctx.textAlign = 'center'; ctx.fillStyle = '#ffd43b'; ctx.font = `800 ${Math.min(46, W * .085)}px "Baloo 2", sans-serif`;
    ctx.fillText(total() >= CAP ? 'ĐỒ ĐÃ MẠNH NHẤT!' : 'CHỌN SỨC MẠNH!', W / 2, Math.min(H * .16, 96));
    const n = card.list.length, wide = W > H * 1.05, pop = Math.min(1, card.t / .25);
    card.rects = [];
    card.list.forEach((o, i) => {
      let x, y, w, hh;
      if (wide) { w = Math.min(250, (W - 80) / 3); hh = Math.min(H * .6, w * 1.4); x = W / 2 + (i - (n - 1) / 2) * (w + 24) - w / 2; y = H * .55 - hh / 2; }
      else { w = Math.min(W - 40, 360); hh = Math.min((H * .72) / 3 - 14, 170); x = W / 2 - w / 2; y = H * .22 + i * (hh + 14); }
      card.rects.push([x, y, w, hh]);
      const S2 = card.sel === i ? 1.08 : card.sel >= 0 ? .9 : pop, cxm = x + w / 2, cym = y + hh / 2;
      ctx.save(); ctx.translate(cxm, cym); ctx.scale(S2, S2); ctx.translate(-cxm, -cym);
      if (card.sel >= 0 && card.sel !== i) ctx.globalAlpha = .4;
      const isSk = SKILLS[o.k], col = isSk ? isSk.c : o.k === 'coins' ? '#fab005' : '#ff6b6b';
      ctx.fillStyle = '#fff'; roundRect(ctx, x, y, w, hh, 22); ctx.fill();
      ctx.strokeStyle = col; ctx.lineWidth = 6; ctx.stroke();
      const im = isSk ? isSk.img : o.k === 'coins' ? 'Coin' : 'Red heart', name = isSk ? isSk.vi : o.k === 'coins' ? '+5 xu' : 'Hồi đầy máu';
      const lvNow = isSk ? sk[o.k] : 0;
      if (wide) {
        const is = Math.min(w * .62, hh * .48);
        draw(ctx, im, cxm, y + hh * .33, is, is, {rot: Math.sin(card.t * 3 + i) * .08});
        ctx.fillStyle = col; ctx.font = `800 ${Math.min(30, w * .13)}px "Baloo 2", sans-serif`; ctx.fillText(name, cxm, y + hh * .7);
        if (isSk) { ctx.fillStyle = '#fab005'; ctx.font = `800 ${Math.min(30, w * .12)}px sans-serif`; ctx.fillText(stars(lvNow + 1), cxm, y + hh * .87); }
      } else {
        const is = hh * .72;
        draw(ctx, im, x + 16 + is / 2, cym, is, is, {rot: Math.sin(card.t * 3 + i) * .08});
        ctx.textAlign = 'left'; ctx.fillStyle = col; ctx.font = `800 ${Math.min(30, w * .085)}px "Baloo 2", sans-serif`; ctx.fillText(name, x + 30 + is, cym - 4);
        if (isSk) { ctx.fillStyle = '#fab005'; ctx.font = `800 ${Math.min(28, w * .07)}px sans-serif`; ctx.fillText(stars(lvNow + 1), x + 30 + is, cym + 30); }
        ctx.textAlign = 'center';
      }
      if (isSk && !lvNow) { ctx.fillStyle = '#e03131'; roundRect(ctx, x + w - 78, y - 12, 84, 32, 16); ctx.fill(); ctx.fillStyle = '#fff'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('MỚI!', x + w - 36, y + 11); }
      ctx.restore();
    });
  }

  return loop({
    update(dt) {
      if (!opts.alive()) { cleanup(); return null; }
      for (let i = 0; i < TURBO && !(end && i); i++) step(dt);  // _turbo: test chạy nhanh nhiều bước mỗi khung
      if (end) { endT += dt; if (endT > (end.win ? 2 : 2.2)) return end; }
      return null;
    },
    draw() {
      drawWorld();
      drawHud();
      if (t < 2.8 && !card) levelBanner(ctx, W, H, lv, `Sống ${DUR} giây · Hạ ${BK.vi.toLowerCase()}`, 'Kéo ngón tay để chạy · Bé tự bắn quái');
      if (card) drawCards();
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT MÁU!', `${end.score} điểm`);
    }
  }, opts.alive);
}
