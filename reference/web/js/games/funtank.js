// Xe tăng dũng cảm (đợt 17): lái tới chỗ chạm, tháp pháo tự ngắm. Hệ 8 loại đạn nhặt từ hộp (rơi từ địch/thùng gỗ), mỗi loại 5 sao;
// đổi đạn bằng nút bên trái. Skill bên phải nạp năng lượng khi hạ địch: khiên điện, sửa xe, gọi không kích, xe tăng đồng minh (tối đa 2).
// Kho đồ giữ qua màn (opts.carry): {v, coins, wp: {loại: sao cao nhất}, cur, body, up: {hp, spd, rate, rng, ally}, allies, en}.
// Xưởng xe tăng (DOM) chỉ hiện ở cấp đầu lượt: chọn màu xe, chọn đạn, mua nâng cấp vĩnh viễn bằng xu.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';
import {booms, dust, shaker, sheets, spr, tile} from './funfx.js?v=4c51d34a6e';
import {h, src} from '../ui.js?v=4c51d34a6e';

const local = (cv, e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
const TAU = Math.PI * 2;
const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= TAU; while (d < -Math.PI) d += TAU; return d; };

// ---------- Dữ liệu đồ ----------
export const TK_WEAPONS = [
  {id: 'norm', vi: 'Đạn thường', img: 'Bullseye', c: '#37b24d'},
  {id: 'multi', vi: 'Nhiều nòng', img: 'Sparkles', c: '#f59f00'},
  {id: 'bounce', vi: 'Đạn nảy', img: 'Basketball', c: '#ff922b'},
  {id: 'homing', vi: 'Tên lửa', img: 'Rocket', c: '#f03e3e'},
  {id: 'blast', vi: 'Pháo nổ', img: 'Collision', c: '#d9480f'},
  {id: 'laser', vi: 'Laser', img: 'High voltage', c: '#ae3ec9'},
  {id: 'flame', vi: 'Súng lửa', img: 'Fire', c: '#e8590c'},
  {id: 'mine', vi: 'Mìn', img: 'Bomb', c: '#495057'}
];
const WP = Object.fromEntries(TK_WEAPONS.map(w => [w.id, w]));
const SKILLS = [
  {id: 'shield', img: 'Shield', cost: 25, c: '#1c7ed6', vi: 'KHIÊN ĐIỆN!'},
  {id: 'fix', img: 'Wrench', cost: 35, c: '#2f9e44', vi: 'SỬA XE!'},
  {id: 'air', img: 'Airplane', cost: 50, c: '#e03131', vi: 'KHÔNG KÍCH!'},
  {id: 'ally', img: 'Military helmet', cost: 60, c: '#f08c00', vi: 'ĐỒNG MINH!'}
];
const BODIES = [
  {id: 'green', body: 'tankBody_green', barrel: 'tankGreen_barrel2', c: '#37b24d'},
  {id: 'blue', body: 'tankBody_blue', barrel: 'tankBlue_barrel2', c: '#1c7ed6'},
  {id: 'sand', body: 'tankBody_sand', barrel: 'tankSand_barrel1', c: '#d9a441'}
];
const UPG = [
  {id: 'hp', img: 'Red heart', vi: 'Máu', max: 5},
  {id: 'spd', img: 'Running shoe', vi: 'Chạy', max: 5},
  {id: 'rate', img: 'Stopwatch', vi: 'Bắn nhanh', max: 5},
  {id: 'rng', img: 'Bow and arrow', vi: 'Bắn xa', max: 5},
  {id: 'ally', img: 'Military helmet', vi: 'Đồng minh', max: 2}
];
// Giá: mỗi lượt (3 cấp) được khoảng 30-80 xu → 2-4 lượt mua được một món
const upPrice = (u, n) => u.id === 'ally' ? 160 * (n + 1) : 70 + 50 * n;
const WP_PRICE = 120;
const IMGS = ['Coin', 'Red heart', 'Shield', 'Glowing star', 'Wrapped gift', ...TK_WEAPONS.map(w => w.img), ...SKILLS.map(s => s.img), ...UPG.map(u => u.img)];

// Đọc kho đồ phòng thủ (hồ sơ cũ / thiếu trường → mặc định)
function normCarry(c) {
  c = c && typeof c === 'object' ? c : {};
  const n = x => Math.max(0, Math.floor(+x || 0));
  const wp = {norm: 1};
  for (const w of TK_WEAPONS) { const s = Math.min(5, n(c.wp && c.wp[w.id])); if (s) wp[w.id] = Math.max(wp[w.id] || 0, s); }
  const up = {}; for (const u of UPG) up[u.id] = Math.min(u.max, n(c.up && c.up[u.id]));
  return {v: 1, coins: n(c.coins), wp, cur: wp[c.cur] ? c.cur : 'norm', body: BODIES.some(b => b.id === c.body) ? c.body : 'green', up, allies: Math.min(2, n(c.allies)), en: Math.min(100, n(c.en))};
}
const cloneCarry = G => ({...G, wp: {...G.wp}, up: {...G.up}});

// Vẽ xe tăng nhìn từ trên: thân xoay theo hướng chạy a, nòng xoay theo tháp pháo tur (sprite nòng gốc hướng xuống)
function drawTank(ctx, tk, x, y, body, barrel, size, a, tur, recoil = 0, alpha = 1) {
  ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.beginPath(); ctx.ellipse(x + 4, y + 6, size * .55, size * .5, 0, 0, 7); ctx.fill();
  spr(ctx, tk, body, x, y, size, {rot: a + Math.PI / 2, alpha});
  const bl = size * .62, back = recoil * size * .12;
  spr(ctx, tk, barrel, x + Math.cos(tur) * (bl * .38 - back), y + Math.sin(tur) * (bl * .38 - back), bl, {rot: tur - Math.PI / 2, alpha});
}

// ---------- Xưởng xe tăng (DOM) ----------
const CSS = `.tks{position:absolute;inset:0;z-index:3;overflow:auto;touch-action:pan-y;background:linear-gradient(#5c940d,#2b8a3e);padding:60px 12px 14px;display:flex;flex-direction:column;align-items:center;gap:8px;font-family:"Baloo 2",sans-serif}
.tks h2{margin:0;color:#fff;font-size:1.9em;text-shadow:0 3px 0 rgba(0,0,0,.25);display:flex;align-items:center;gap:12px;flex-wrap:wrap;justify-content:center}
.tks .tks-coin{display:inline-flex;align-items:center;gap:4px;background:rgba(0,0,0,.3);border-radius:22px;padding:0 14px 0 6px;font-size:.85em}
.tks .tks-coin img{width:34px;height:34px}
.tks .tks-row{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;width:min(900px,100%);background:rgba(255,255,255,.14);border-radius:22px;padding:10px}
.tks .tks-lab{width:100%;text-align:center;color:#fff;font-weight:800;font-size:1.15em;margin:-4px 0 -2px}
.tks .tks-card{position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:0;min-width:86px;padding:6px 6px 8px;border-radius:20px;background:#fff;border:4px solid var(--c,#adb5bd);box-shadow:0 5px 0 rgba(0,0,0,.18);font:inherit;font-weight:800;color:#343a40;cursor:pointer}
.tks .tks-card img{width:46px;height:46px}
.tks .tks-card canvas{width:72px;height:72px}
.tks .tks-card.on{background:#fff3bf;transform:translateY(-3px);box-shadow:0 0 0 4px #ffd43b,0 7px 0 rgba(0,0,0,.2)}
.tks .tks-card.lock img{opacity:.35}
.tks .tks-card.no{animation:tks-no .3s}
.tks .tks-st{color:#f59f00;font-size:1.05em;letter-spacing:-1px;line-height:1;min-height:1em}
.tks .tks-st i{color:#dee2e6;font-style:normal}
.tks .tks-pr{display:inline-flex;align-items:center;gap:2px;font-size:1em;line-height:1}
.tks .tks-pr img{width:22px;height:22px}
.tks .tks-pr.poor{opacity:.45}
.tks .tks-nm{font-size:.8em;color:#495057;line-height:1.1}
.tks .tks-pip{display:flex;gap:3px;margin:3px 0}
.tks .tks-pip b{width:10px;height:10px;border-radius:50%;background:#dee2e6}
.tks .tks-pip b.f{background:#40c057}
.tks .tks-go{position:sticky;bottom:6px;z-index:2;margin-top:6px;font:inherit;font-size:2em;font-weight:800;color:#fff;background:#f76707;border:0;border-radius:40px;padding:6px 48px;box-shadow:0 6px 0 #c2410c;cursor:pointer}
.tks .tks-go:active,.tks .tks-card:active{transform:scale(.96)}
@keyframes tks-no{25%{transform:translateX(-6px)}75%{transform:translateX(6px)}}
@media (max-width:520px){.tks .tks-card{min-width:70px}.tks .tks-card img{width:42px;height:42px}.tks .tks-card canvas{width:60px;height:60px}.tks h2{font-size:1.5em}}`;

function tankShop(box, G, opts, tk) {
  if (!document.getElementById('tks-css')) document.head.append(h('style', {id: 'tks-css'}, CSS));
  const save = () => { if (opts.saveGear) opts.saveGear(cloneCarry(G)); };
  return new Promise(resolve => {
    const wrap = h('div', {class: 'tks'});
    const nope = el => { sfx('wrong'); el.classList.remove('no'); void el.offsetWidth; el.classList.add('no'); };
    const stars = n => h('span', {class: 'tks-st'}, '★'.repeat(n), h('i', {}, '★'.repeat(5 - n)));
    const price = p => h('span', {class: 'tks-pr' + (G.coins < p ? ' poor' : '')}, h('img', {src: src('Coin'), alt: ''}), p);
    const render = () => {
      wrap.replaceChildren(
        h('h2', {}, '🛠️ Xưởng xe tăng', h('span', {class: 'tks-coin'}, h('img', {src: src('Coin'), alt: ''}), G.coins)),
        // Màu xe
        h('div', {class: 'tks-row'}, h('div', {class: 'tks-lab'}, '🎨'), BODIES.map(b => {
          const cv = h('canvas', {width: 120, height: 120});
          const x = cv.getContext('2d'); drawTank(x, tk, 60, 62, b.body, b.barrel, 80, -Math.PI / 2, -Math.PI / 2);
          return h('button', {class: 'tks-card' + (G.body === b.id ? ' on' : ''), style: {'--c': b.c}, onclick: () => { sfx('tap'); G.body = b.id; save(); render(); }}, cv);
        })),
        // Đạn mang vào
        h('div', {class: 'tks-row'}, h('div', {class: 'tks-lab'}, '💥'), TK_WEAPONS.map(w => {
          const s = G.wp[w.id] || 0;
          return h('button', {class: 'tks-card' + (G.cur === w.id ? ' on' : '') + (s ? '' : ' lock'), style: {'--c': w.c}, onclick: e => {
            if (s) { sfx('tap'); G.cur = w.id; save(); return render(); }
            if (G.coins < WP_PRICE) return nope(e.currentTarget);
            G.coins -= WP_PRICE; G.wp[w.id] = 1; G.cur = w.id; sfx('coin'); save(); render();
          }}, h('img', {src: src(w.img), alt: ''}), s ? stars(s) : price(WP_PRICE), h('span', {class: 'tks-nm'}, w.vi));
        })),
        // Nâng cấp vĩnh viễn
        h('div', {class: 'tks-row'}, h('div', {class: 'tks-lab'}, '⬆️'), UPG.map(u => {
          const n = G.up[u.id] || 0, max = n >= u.max, p = upPrice(u, n);
          return h('button', {class: 'tks-card', style: {'--c': max ? '#ffd43b' : '#74c0fc'}, onclick: e => {
            if (max || G.coins < p) return nope(e.currentTarget);
            G.coins -= p; G.up[u.id] = n + 1; sfx('power'); save(); render();
          }}, h('img', {src: src(u.img), alt: ''}), h('span', {class: 'tks-pip'}, Array.from({length: u.max}, (_, i) => h('b', {class: i < n ? 'f' : ''}))),
          max ? h('span', {class: 'tks-st'}, 'MAX') : price(p), h('span', {class: 'tks-nm'}, u.vi));
        })),
        h('button', {class: 'tks-go', onclick: () => { sfx('power'); save(); wrap.remove(); resolve(); }}, 'Chơi ▶')
      );
    };
    render();
    box.append(wrap);
  });
}

// ---------- Game ----------
export async function tank(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.min(30, 5 + Math.floor(lv * .4)), bossLv = (lv + 1) % 5 === 0;
  const G = normCarry(opts.carry);
  const [[tk, fxs]] = await Promise.all([sheets(['tanks/tanks', 'fxa/fx']), loadAll(IMGS)]);
  // Xưởng chỉ hiện ở cấp đầu của lượt (opts dùng chung giữa các cấp trong một lượt)
  if (!opts.tankShopDone) { await tankShop(box, G, opts, tk); opts.tankShopDone = true; if (opts.alive && !opts.alive()) return null; }
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), R = S * .05, D = dust(260), B = booms(fxs, 24), SH = shaker(), narrow = W < 520;
  const BODY = BODIES.find(b => b.id === G.body) || BODIES[0];
  const sand = [1, 5].includes(Math.floor(lv / 10) % 6), groundK = sand ? 'tileSand1' : 'tileGrass1';
  const tracks = Array.from({length: 60}, () => ({x: 0, y: 0, a: 0, t: 0})); let trackI = 0, trackD = 0;
  const deco = Array.from({length: 6}, (_, i) => ({x: i % 2 ? W - rand(10, 40) : rand(10, 40), y: 100 + (i >> 1) * (H - 140) / 2 + rand(0, 60), k: pick(['treeGreen_large', 'treeGreen_small', 'treeBrown_large']), s: S * rand(.12, .18)}));
  // Sức mạnh đồ → địch tăng máu nhẹ (đồ max vẫn có thử thách)
  const startAllies = Math.min(2, Math.max(G.allies, G.up.ally));
  const pw = (Math.max(...Object.values(G.wp)) - 1) / 4 + (G.up.rate + G.up.rng) / 10 + startAllies * .2;
  const hpMul = (1 + lv * .035) * (1 + .3 * pw);
  const maxHp = 5 + G.up.hp, range = Math.hypot(W, H) * (.42 + .06 * G.up.rng), cdMul = 1 - .06 * G.up.rate, speed = 230 * (1 + .08 * G.up.spd);
  const st = {...G.wp};  // sao trong màn
  let cur = st[G.cur] ? G.cur : 'norm', hp = maxHp, en = Math.max(25, G.en), coinsRun = 0;
  const me = {x: W / 2, y: H * .8, a: -Math.PI / 2, tur: -Math.PI / 2, recoil: 0, tx: null, ty: null, cd: 0, mcd: 1, inv: 1.5, shield: 0, eshield: 0, flameS: 0};
  const bullets = [], foes = [], items = [], walls = [], mines = [], beams = [], bombs = [], allies = [];
  let plane = null;
  for (let i = 0; i < startAllies; i++) allies.push({x: me.x + (i ? 1 : -1) * R * 2.4, y: me.y + R * 1.5, a: -Math.PI / 2, tur: -Math.PI / 2, cd: rand(.3, .8), hp: 3, inv: 0, slot: i});
  const nw = Math.round(ramp(lv, 4, 10));
  for (let i = 0; i < nw; i++) walls.push({x: rand(W * .1, W * .9), y: rand(H * .25, H * .65), w: S * .1, h: S * .1, hp: 3, k: Math.random() < .55 ? 'crateWood' : 'sandbagBeige', hitT: 0});
  let killed = 0, t = 0, spawn = 1, end = null, endT = 0, boss = null, bossDone = false, sndT = 0;
  const inWall = (x, y, r) => walls.find(w => Math.abs(x - w.x) < w.w / 2 + r && Math.abs(y - w.y) < w.h / 2 + r);
  const fsp = ramp(lv, 40, 110), fireRate = ramp(lv, 3.2, 1.3), ebs = ramp(lv, 160, 260);
  const carryNow = () => {
    const wp = {...G.wp}; for (const k in st) wp[k] = Math.max(wp[k] || 0, st[k]);
    return {v: 1, coins: G.coins + coinsRun, wp, cur, body: G.body, up: {...G.up}, allies: allies.length, en: Math.round(Math.min(100, en))};
  };
  const saveNow = () => { if (opts.saveGear) opts.saveGear(carryNow()); };
  const finish = win => {
    if (end) return;
    if (win) { coinsRun += 15 + (bossLv ? 20 : 0); sfx('win'); }
    end = {win, score: killed * 3 + (win ? hp * 2 : 0) + (bossDone ? 20 : 0)};
    end.carry = carryNow();
  };

  // ---- Nút chạm: đạn bên trái, skill bên phải ----
  const bs = narrow ? 48 : 58, ss = narrow ? 56 : 66;
  const wBtns = () => TK_WEAPONS.filter(w => st[w.id]).map((w, i) => ({w, x: 10 + bs / 2, y: H - 12 - bs / 2 - i * (bs + 8), r: bs / 2}));
  const sBtns = () => SKILLS.map((s, i) => ({s, x: W - 10 - ss / 2, y: H - 12 - ss / 2 - i * (ss + 10), r: ss / 2}));
  const canSkill = s => en >= s.cost && !(s.id === 'ally' && allies.length >= 2) && !(s.id === 'fix' && hp >= maxHp && allies.every(a => a.hp >= 3));
  function useSkill(s) {
    if (!canSkill(s)) { sfx('wrong'); return; }
    en -= s.cost; sfx('power'); F.text(me.x, me.y - R * 2, s.vi, '#ffe066'); F.burst(me.x, me.y, 12);
    if (s.id === 'shield') me.eshield = 7;
    else if (s.id === 'fix') { hp = maxHp; for (const a of allies) a.hp = 3; F.text(me.x, me.y - R * 3.2, '❤'.repeat(Math.min(5, maxHp)), '#ff6b6b'); }
    else if (s.id === 'air') {
      plane = {x: -80, y: H * .45, t: 0};
      const tg = foes.filter(f => !f.dead).slice(0, 8);
      tg.forEach((f, i) => bombs.push({f, x: f.x, y: f.y, t: .35 + i * .14}));
      for (let i = tg.length; i < 4; i++) bombs.push({x: rand(W * .15, W * .85), y: rand(110, H * .6), t: .35 + i * .14});
    } else if (s.id === 'ally') allies.push({x: me.x, y: me.y + R * 2, a: -Math.PI / 2, tur: -Math.PI / 2, cd: .5, hp: 3, inv: 1, slot: allies.some(a => a.slot === 0) ? 1 : 0});
    saveNow();
  }
  let steer = null;
  const step = e => { const [x, y] = local(cv, e); me.tx = x; me.ty = y; };
  cv.addEventListener('pointerdown', e => {
    const [x, y] = local(cv, e);
    if (t >= 2 && !end) {
      const wb = wBtns().find(b => Math.hypot(x - b.x, y - b.y) < b.r + 6);
      if (wb) { if (cur !== wb.w.id) { cur = wb.w.id; sfx('tap'); F.text(wb.x + bs * 1.6, wb.y, `${wb.w.vi} ${'★'.repeat(st[cur])}`, '#fff'); me.cd = Math.min(me.cd, .15); } return; }
      const sb = sBtns().find(b => Math.hypot(x - b.x, y - b.y) < b.r + 6);
      if (sb) { useSkill(sb.s); return; }
    }
    steer = e.pointerId; cv.setPointerCapture(e.pointerId); step(e);
  });
  cv.addEventListener('pointermove', e => { if (steer === e.pointerId && (e.buttons || e.pointerType !== 'mouse')) step(e); });
  cv.addEventListener('pointerup', e => { if (steer === e.pointerId) steer = null; });

  // ---- Địch ----
  const FT = {
    basic: {body: 'tankBody_red', barrel: 'tankRed_barrel1', hp: 1, sp: 1, s: .1},
    fast: {body: 'tankBody_dark', barrel: 'tankDark_barrel3', hp: .8, sp: 1.9, s: .085},
    heavy: {body: 'tankBody_bigRed', barrel: 'tankRed_barrel1', hp: 3, sp: .7, s: .13},
    turret: {body: 'crateMetal', barrel: 'specialBarrel1', hp: 3, sp: 0, s: .1},
    boss: {body: 'tankBody_huge', barrel: 'specialBarrel6', hp: 1, sp: .5, s: .24}
  };
  const pickFoe = () => {
    const r = Math.random(), tur = foes.filter(f => f.k === 'turret').length;
    if (lv >= 7 && r < .12 && tur < 2) return 'turret';
    if (lv >= 3 && r < .36) return 'fast';
    if (lv >= 12 && r < .52) return 'heavy';
    return 'basic';
  };
  function addFoe(k, x, y) {
    const T = FT[k], m = Math.max(1, T.hp * hpMul);
    const f = {k, x, y, hp: m, max: m, cd: rand(1, fireRate), ph: rand(0, 6), s: S * T.s, flash: 0, ang: Math.PI / 2, tur: Math.PI / 2};
    if (k === 'turret') { for (let n = 0; n < 12 && inWall(f.x, f.y, f.s); n++) { f.x = rand(W * .15, W * .85); f.y = rand(H * .18, H * .5); } }
    foes.push(f); return f;
  }
  function spawnBoss() {
    const m = 25 * (1 + lv * .05) * (1 + .5 * pw);
    boss = addFoe('boss', W / 2, -60); boss.hp = boss.max = m; boss.boss = true; boss.cd = 2; boss.cd2 = 5;
    sfx('boom'); SH.add(12); F.text(W / 2, H * .35, '⚠️ TRÙM XE TĂNG!', '#ff6b6b');
  }
  function drop(x, y, wpChance) {
    const r = Math.random();
    if (r < wpChance) {
      const open = TK_WEAPONS.filter(w => (st[w.id] || 0) < 5);
      if (!open.length) return items.push({k: 'coin', x, y, t: 9});
      const w = (st[cur] < 5 && Math.random() < .35) ? WP[cur] : pick(open);
      items.push({k: 'wp', w: w.id, x, y, t: 10});
    } else if (r < wpChance + .12) items.push({k: 'coin', x, y, t: 9});
    else if (r < wpChance + .18 && hp < maxHp) items.push({k: 'heart', x, y, t: 9});
    else if (r < wpChance + .22) items.push({k: 'shield', x, y, t: 9});
  }
  function killFoe(f) {
    if (f.dead) return;
    f.dead = true; sfx('boom'); B.add(f.x, f.y, f.s * 1.8); D.debris(f.x, f.y, 10, '#495057', 300); D.puff(f.x, f.y, 6, 'rgba(80,80,80,1)', 60, 10); SH.add(f.boss ? 16 : f.k === 'heavy' ? 8 : 5); F.star(f.x, f.y);
    en = Math.min(100, en + (f.boss ? 40 : f.k === 'heavy' || f.k === 'turret' ? 12 : 8)); coinsRun += 3;
    if (f.boss) {
      bossDone = true; boss = null; coinsRun += 5;
      for (let i = 0; i < 5; i++) B.add(f.x + rand(-60, 60), f.y + rand(-50, 50), f.s);
      items.push({k: 'wp', w: (pick(TK_WEAPONS.filter(w => (st[w.id] || 0) < 5)) || WP.norm).id, x: f.x, y: f.y, t: 12});
      finish(true); return;
    }
    killed++;
    drop(f.x, f.y, lv < 10 ? .24 : .17);
    if (killed >= need) { if (bossLv) { if (!boss && !bossDone) spawnBoss(); } else finish(true); }
  }
  function hurtFoe(f, d, x, y) {
    if (f.dead || d <= 0) return;
    f.hp -= d; f.flash = .1;
    if (f.hp <= 0) killFoe(f); else D.sparks(x, y, 4, '#ffe066', 180);
  }
  function wallHit(w, d) {
    w.hp -= d; w.hitT = .15;
    if (w.hp <= 0 && walls.includes(w)) {
      walls.splice(walls.indexOf(w), 1); B.add(w.x, w.y, w.w * 1.4, 'smoke'); D.debris(w.x, w.y, 12, w.k === 'crateWood' ? '#c08552' : '#d8c8a0', 260); SH.add(4); sfx('pop');
      if (w.k === 'crateWood') drop(w.x, w.y, .55);
    }
  }
  // Nổ diện rộng (pháo nổ, mìn, không kích, tên lửa sao cao)
  function splash(x, y, rad, d, big = false) {
    B.add(x, y, rad * 1.6); if (big) B.add(x + rand(-20, 20), y + rand(-20, 20), rad * 1.2); D.sparks(x, y, 10, '#ffa94d', 300); SH.add(big ? 8 : 4); sfx('boom');
    for (const f of foes) if (!f.dead && Math.hypot(f.x - x, f.y - y) < rad + f.s * .4) hurtFoe(f, f.boss && big ? f.max * .1 : d, f.x, f.y);
    for (const w of [...walls]) if (Math.hypot(w.x - x, w.y - y) < rad + w.w * .4) wallHit(w, 1);
  }
  const shot = (a, sp, o) => {
    if (bullets.length > 150) return;
    bullets.push({x: me.x + Math.cos(a) * R * 1.4, y: me.y + Math.sin(a) * R * 1.4, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, mine: true, life: range / sp * 1.1, kind: 'norm', dmg: 1, r: 8, ...o});
  };
  const nearestFoe = (x, y, maxD = Infinity, skip = null) => { let b = null, bd = maxD; for (const f of foes) { if (f.dead || f === skip) continue; const d = Math.hypot(f.x - x, f.y - y); if (d < bd) { bd = d; b = f; } } return b; };
  const flameRange = () => R * (3.6 + .5 * st.flame);
  // Bắn theo loại đạn đang dùng (s = sao 1..5)
  function fire(tg) {
    const s = st[cur], a = me.tur, mx = me.x + Math.cos(a) * R * 1.5, my = me.y + Math.sin(a) * R * 1.5;
    me.recoil = 1;
    switch (cur) {
      case 'norm': shot(a, 560, {dmg: 1 + (s >= 3) + (s >= 5), r: 6 + s * 1.6, spr: ['bulletGreen2', 'bulletGreen2', 'bulletBlue2', 'bulletBlue2', 'bulletDark2'][s - 1], pierce: s >= 4 ? 1 : 0}); me.cd = (.46 - .04 * s) * cdMul; sfx('shoot'); break;
      case 'multi': { const n = [2, 3, 3, 4, 5][s - 1], gap = .17; for (let i = 0; i < n; i++) shot(a + (i - (n - 1) / 2) * gap, 520, {dmg: s >= 3 ? 1.3 : 1, r: 8, spr: 'bulletGreen2'}); me.cd = (.56 - .03 * s) * cdMul; sfx('shoot'); break; }
      case 'bounce': shot(a, 470, {kind: 'bounce', dmg: 1 + (s >= 4) * .6, bn: s + 1, r: 10 + s, life: 4}); me.cd = (.5 - .02 * s) * cdMul; sfx('pop'); break;
      case 'homing': { const n = [1, 1, 2, 2, 3][s - 1]; for (let i = 0; i < n; i++) shot(a + (i - (n - 1) / 2) * .6, 330, {kind: 'homing', dmg: 2 + (s >= 3), turn: 2.5 + s * .7, boom: s >= 4 ? R * 1.6 : 0, r: 24 + s * 2, life: 3.2}); me.cd = (1 - .06 * s) * cdMul; sfx('shoot'); break; }
      case 'blast': { const d = Math.hypot(tg.x - mx, tg.y - my), sp = 420; shot(a, sp, {kind: 'blast', dmg: 2 + Math.floor(s / 2), rad: R * (1.5 + .35 * s), life: Math.max(.15, d / sp), r: 16 + s * 2, max: Math.max(.15, d / sp)}); me.cd = (1.15 - .07 * s) * cdMul; sfx('shoot'); SH.add(3); break; }
      case 'laser': {
        const len = range * 1.2, w = 4 + s * 2.4, d = 1 + Math.floor((s - 1) / 2) + (s >= 5) * .5;
        beams.push({x: mx, y: my, a, len, w, t: .22, c: ['#ff6b6b', '#ff8787', '#f783ac', '#da77f2', '#9775fa'][s - 1]});
        const cx = Math.cos(a), cy = Math.sin(a);
        for (const f of foes) { if (f.dead) continue; const px = f.x - mx, py = f.y - my, along = px * cx + py * cy; if (along < 0 || along > len) continue; if (Math.abs(px * cy - py * cx) < f.s * .45 + w / 2) hurtFoe(f, d, f.x, f.y); }
        me.cd = (.78 - .05 * s) * cdMul; sfx('laser'); break;
      }
      case 'flame': {
        const fr = flameRange(), sp = 330, n = s >= 4 ? 2 : 1;
        for (let i = 0; i < n; i++) shot(a + rand(-1, 1) * (.14 + .04 * s), sp * rand(.85, 1.1), {kind: 'flame', dmg: .25 + .08 * s, life: fr / sp, r: 8, max: fr / sp});
        me.cd = .09 * cdMul; me.recoil = .4; sndT -= 1; if (sndT <= 0) { sndT = 4; sfx('shoot'); } break;
      }
      case 'mine': shot(a, 520, {dmg: 1, r: 7, spr: 'bulletGreen2'}); me.cd = .8 * cdMul; sfx('shoot'); break;
    }
    if (cur !== 'flame' && cur !== 'laser') { D.puff(mx, my, 3, 'rgba(230,230,230,1)', 40, 5); SH.add(1.2); }
  }

  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); B.update(dt); SH.update(dt); me.recoil = Math.max(0, me.recoil - dt * 4);
      for (const w of walls) w.hitT = Math.max(0, w.hitT - dt);
      for (const tr of tracks) tr.t = Math.max(0, tr.t - dt);
      for (let i = beams.length - 1; i >= 0; i--) if ((beams[i].t -= dt) <= 0) beams.splice(i, 1);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      me.inv = Math.max(0, me.inv - dt); me.cd -= dt; me.shield = Math.max(0, me.shield - dt); me.eshield = Math.max(0, me.eshield - dt);
      if (me.tx != null) {
        const dx = me.tx - me.x, dy = me.ty - me.y, d = Math.hypot(dx, dy);
        if (d > 8) {
          me.ta = Math.atan2(dy, dx);
          const da = angDiff(me.ta, me.a);
          me.a += Math.max(-7 * dt, Math.min(7 * dt, da));
          const sp = speed * (1 - Math.min(.6, Math.abs(da) / 2));
          const nx = me.x + dx / d * sp * dt, ny = me.y + dy / d * sp * dt;
          trackD += sp * dt; if (trackD > R * .5) { trackD = 0; const tr = tracks[trackI]; trackI = (trackI + 1) % tracks.length; tr.x = me.x; tr.y = me.y; tr.a = me.a; tr.t = 3; if (Math.random() < .4) D.emit(me.x - Math.cos(me.a) * R, me.y - Math.sin(me.a) * R, rand(-20, 20), rand(-20, 20), {life: .5, r: 4, grow: 10, c: sand ? 'rgba(220,190,140,1)' : 'rgba(170,150,110,1)', a: .5}); }
          if (!inWall(nx, me.y, R)) me.x = Math.max(R, Math.min(W - R, nx));
          if (!inWall(me.x, ny, R)) me.y = Math.max(80 + R, Math.min(H - R, ny));
        }
      }
      // Ngắm: địch gần nhất trong tầm; không có địch thì bắn thùng gỗ (có quà)
      let tg = nearestFoe(me.x, me.y, cur === 'flame' ? flameRange() * 1.15 : range);
      if (!tg && cur !== 'flame' && cur !== 'mine') tg = walls.filter(w => w.k === 'crateWood').reduce((b, w) => { const d = Math.hypot(w.x - me.x, w.y - me.y); return d < range * .7 && (!b || d < Math.hypot(b.x - me.x, b.y - me.y)) ? w : b; }, null);
      if (tg) { const da = angDiff(Math.atan2(tg.y - me.y, tg.x - me.x), me.tur); me.tur += Math.max(-9 * dt, Math.min(9 * dt, da)); me.aimOk = Math.abs(da) < .35; }
      if (tg && me.cd <= 0 && me.aimOk) fire(tg);
      // Mìn: thả sau đuôi xe khi có địch trên sân
      if (cur === 'mine') {
        me.mcd -= dt; const s = st.mine;
        if (me.mcd <= 0 && foes.length && mines.length < 2 + s) { me.mcd = (1.5 - .12 * s) * cdMul; mines.push({x: me.x - Math.cos(me.a) * R * 1.3, y: me.y - Math.sin(me.a) * R * 1.3, t: 0, s}); sfx('pop'); }
      }
      // Sinh địch
      spawn -= dt;
      if (!boss && spawn <= 0 && foes.length < Math.round(ramp(lv, 2, 6)) && killed + foes.length < need) {
        spawn = ramp(lv, 2.2, .9);
        const k = pickFoe();
        addFoe(k, rand(W * .1, W * .9), k === 'turret' ? rand(H * .18, H * .5) : 100);
      }
      const add = [];
      for (const f of foes) {
        if (f.dead) continue;
        f.ph += dt; f.flash = Math.max(0, f.flash - dt);
        const T = FT[f.k];
        let tx = me.x, ty = me.y;
        const aim = Math.atan2(ty - f.y, tx - f.x);
        f.tur = f.tur + Math.max(-3 * dt, Math.min(3 * dt, angDiff(aim, f.tur)));
        if (f.boss) {
          // Trùm: đi xuống rồi lượn ngang, bắn quạt đạn, gọi lính
          const gy = Math.min(H * .3, 170), nx = W / 2 + Math.sin(f.ph * .45) * W * .32;
          f.y += (gy - f.y) * Math.min(1, dt * 1.5); f.x += (nx - f.x) * Math.min(1, dt * 1.2); f.ang = Math.PI / 2;
          f.cd -= dt; f.cd2 -= dt;
          if (f.cd <= 0) {
            f.cd = ramp(lv, 2.2, 1.2); const n = lv < 20 ? 3 : 5;
            for (let i = 0; i < n; i++) { const b = f.tur + (i - (n - 1) / 2) * .22; bullets.push({x: f.x + Math.cos(b) * f.s * .5, y: f.y + Math.sin(b) * f.s * .5, vx: Math.cos(b) * ebs, vy: Math.sin(b) * ebs, life: 6, kind: 'enemy', big: true}); }
            SH.add(3); D.puff(f.x + Math.cos(f.tur) * f.s * .5, f.y + Math.sin(f.tur) * f.s * .5, 4, 'rgba(230,230,230,1)', 40, 6);
          }
          if (f.cd2 <= 0) { f.cd2 = ramp(lv, 7, 4.5); if (foes.length < 5) add.push('basic', lv >= 10 ? 'fast' : 'basic'); }
        } else if (f.k !== 'turret') {
          const a = aim + Math.sin(f.ph) * .8;
          f.ang = f.ang + Math.max(-4 * dt, Math.min(4 * dt, angDiff(a, f.ang)));
          const v = fsp * T.sp, nx = f.x + Math.cos(a) * v * dt, ny = f.y + Math.sin(a) * v * dt * .6;
          if (!inWall(nx, ny, f.s * .4)) { f.x = Math.max(f.s / 2, Math.min(W - f.s / 2, nx)); f.y = Math.max(90, Math.min(H * .7, ny)); }
          if (f.k === 'fast' && Math.random() < .2) D.emit(f.x, f.y, rand(-15, 15), rand(-15, 15), {life: .4, r: 3, grow: 8, c: 'rgba(170,150,110,1)', a: .4});
        }
        if (!f.boss) {
          f.cd -= dt;
          if (f.cd <= 0) {
            f.cd = rand(fireRate * .8, fireRate * 1.3) * (f.k === 'turret' ? 1.3 : f.k === 'fast' ? 1.2 : 1);
            const n = f.k === 'turret' ? 3 : 1;
            for (let i = 0; i < n; i++) { const b = f.tur + (i - (n - 1) / 2) * .25; bullets.push({x: f.x + Math.cos(b) * f.s * .5, y: f.y + Math.sin(b) * f.s * .5, vx: Math.cos(b) * ebs, vy: Math.sin(b) * ebs, life: 6, kind: 'enemy'}); }
            D.puff(f.x + Math.cos(f.tur) * f.s * .55, f.y + Math.sin(f.tur) * f.s * .55, 2, 'rgba(230,230,230,1)', 30, 4);
          }
        }
        if (Math.hypot(f.x - me.x, f.y - me.y) < R + f.s * .4) { if (me.eshield > 0) hurtFoe(f, 3 * dt * hpMul, f.x, f.y); else hurt(); }
        if (me.eshield > 0 && Math.hypot(f.x - me.x, f.y - me.y) < R * 1.9 + f.s * .4) hurtFoe(f, 2 * dt * hpMul, f.x, f.y);
      }
      for (const k of add) addFoe(k, boss ? boss.x + rand(-60, 60) : W / 2, 110);
      function hurt() {
        if (me.inv > 0 || end) return;
        if (me.eshield > 0) return;
        if (me.shield > 0) { me.shield = 0; me.inv = 1; sfx('pop'); return; }
        hp--; me.inv = 1.4; sfx('hit'); B.add(me.x, me.y, R * 2.5); SH.add(10);
        if (hp <= 0) finish(false);
      }
      // Đồng minh: theo sau hai bên, tự bắn địch gần
      for (let i = allies.length - 1; i >= 0; i--) {
        const al = allies[i]; al.inv = Math.max(0, al.inv - dt); al.cd -= dt;
        const gx = me.x + (al.slot ? 1 : -1) * R * 2.4, gy = Math.min(H - R, me.y + R * 1.6), dx = gx - al.x, dy = gy - al.y, d = Math.hypot(dx, dy);
        if (d > 6) { const v = Math.min(d * 3, speed * 1.1); al.x += dx / d * v * dt; al.y += dy / d * v * dt; al.a += Math.max(-6 * dt, Math.min(6 * dt, angDiff(Math.atan2(dy, dx), al.a))); }
        const ft = nearestFoe(al.x, al.y, range * .9);
        if (ft) {
          const da = angDiff(Math.atan2(ft.y - al.y, ft.x - al.x), al.tur); al.tur += Math.max(-8 * dt, Math.min(8 * dt, da));
          if (al.cd <= 0 && Math.abs(da) < .4 && bullets.length < 150) { al.cd = .75 * cdMul; const a = al.tur; bullets.push({x: al.x + Math.cos(a) * R, y: al.y + Math.sin(a) * R, vx: Math.cos(a) * 520, vy: Math.sin(a) * 520, mine: true, life: range / 520, kind: 'norm', dmg: 1, r: 6, spr: 'bulletGreen2'}); }
        }
      }
      // Đạn
      for (let i = bullets.length - 1; i >= 0; i--) {
        const b = bullets[i];
        if (b.kind === 'homing') { const f = nearestFoe(b.x, b.y); if (f) { const a = Math.atan2(b.vy, b.vx), da = angDiff(Math.atan2(f.y - b.y, f.x - b.x), a), na = a + Math.max(-b.turn * dt, Math.min(b.turn * dt, da)), sp = Math.hypot(b.vx, b.vy); b.vx = Math.cos(na) * sp; b.vy = Math.sin(na) * sp; } if (Math.random() < .5) D.emit(b.x, b.y, rand(-20, 20), rand(-20, 20), {life: .35, r: 3, grow: 8, c: 'rgba(200,200,200,1)', a: .5}); }
        b.x += b.vx * dt; b.y += b.vy * dt; b.life -= dt;
        if (b.kind === 'blast') { if (b.life <= 0) { bullets.splice(i, 1); splash(b.x, b.y, b.rad, b.dmg); } continue; }  // đạn pháo bay vòng qua tường
        if (b.life <= 0) { bullets.splice(i, 1); continue; }
        // Ra mép sân: đạn nảy bật lại
        const out = b.x < 0 || b.x > W || b.y < 70 || b.y > H;
        if (out) {
          if (b.kind === 'bounce' && b.bn > 0) { b.bn--; if (b.x < 0 || b.x > W) b.vx = -b.vx; else b.vy = -b.vy; b.x = Math.max(1, Math.min(W - 1, b.x)); b.y = Math.max(71, Math.min(H - 1, b.y)); sfx('pop'); }
          else { bullets.splice(i, 1); continue; }
        }
        const w = inWall(b.x, b.y, 4);
        if (w) {
          if (b.mine) wallHit(w, b.kind === 'flame' ? b.dmg : 1);
          if (b.kind === 'bounce' && b.bn > 0) { b.bn--; const kx = (b.x - w.x) / (w.w / 2), ky = (b.y - w.y) / (w.h / 2); if (Math.abs(kx) > Math.abs(ky)) b.vx = -b.vx; else b.vy = -b.vy; b.x += b.vx * dt * 2; b.y += b.vy * dt * 2; D.sparks(b.x, b.y, 4, '#ffa94d', 140); continue; }
          bullets.splice(i, 1); D.sparks(b.x, b.y, 5, '#ffe066', 160); if (b.boom) splash(b.x, b.y, b.boom, b.dmg * .5);
          continue;
        }
        if (b.mine) {
          const f = foes.find(f => !f.dead && f !== b.last && Math.hypot(f.x - b.x, f.y - b.y) < f.s * .5 + (b.kind === 'flame' ? 8 : 0));
          if (!f) continue;
          hurtFoe(f, b.dmg, b.x, b.y); b.last = f;
          if (b.boom) splash(b.x, b.y, b.boom, b.dmg * .5);
          if (b.pierce > 0) { b.pierce--; continue; }
          if (b.kind === 'bounce' && b.bn > 0) {
            // Nảy sang địch gần nhất kế tiếp
            b.bn--; const n2 = nearestFoe(b.x, b.y, range, f), sp = Math.hypot(b.vx, b.vy);
            if (n2) { const a = Math.atan2(n2.y - b.y, n2.x - b.x); b.vx = Math.cos(a) * sp; b.vy = Math.sin(a) * sp; } else { b.vx = -b.vx; b.vy = -b.vy; }
            continue;
          }
          bullets.splice(i, 1);
        } else {
          const dm = Math.hypot(b.x - me.x, b.y - me.y);
          if (me.eshield > 0 && dm < R * 1.9) { bullets.splice(i, 1); D.sparks(b.x, b.y, 6, '#74c0fc', 200); continue; }
          if (dm < R) { bullets.splice(i, 1); hurt(); continue; }
          const al = allies.find(a => Math.hypot(b.x - a.x, b.y - a.y) < R * .75);
          if (al) { bullets.splice(i, 1); if (al.inv <= 0 && --al.hp <= 0) { allies.splice(allies.indexOf(al), 1); B.add(al.x, al.y, R * 2); sfx('boom'); } else { al.inv = .6; D.sparks(b.x, b.y, 5, '#ffe066', 160); } }
        }
      }
      // Mìn: hút về địch gần, chạm là nổ
      for (let i = mines.length - 1; i >= 0; i--) {
        const m = mines[i]; m.t += dt;
        if (m.t > 25) { mines.splice(i, 1); continue; }
        if (m.t < .4) continue;
        const f = nearestFoe(m.x, m.y, R * 3.2);
        if (!f) continue;
        const d = Math.hypot(f.x - m.x, f.y - m.y);
        if (d < f.s * .5 + 10) { mines.splice(i, 1); splash(m.x, m.y, R * (1.4 + .3 * m.s), 3 + m.s); continue; }
        m.x += (f.x - m.x) / d * 150 * dt; m.y += (f.y - m.y) / d * 150 * dt;
      }
      // Không kích
      if (plane) { plane.t += dt; plane.x += (W + 200) / 1.6 * dt; if (plane.x > W + 100) plane = null; }
      for (let i = bombs.length - 1; i >= 0; i--) { const bm = bombs[i]; bm.t -= dt; if (bm.f && !bm.f.dead) { bm.x = bm.f.x; bm.y = bm.f.y; } if (bm.t <= 0) { bombs.splice(i, 1); splash(bm.x, bm.y, R * 2.2, 5 * hpMul, true); } }
      // Nhặt đồ
      for (let i = items.length - 1; i >= 0; i--) {
        const it = items[i]; it.t -= dt;
        if (it.t <= 0) { items.splice(i, 1); continue; }
        if (Math.hypot(it.x - me.x, it.y - me.y) > R + 26) continue;
        items.splice(i, 1);
        if (it.k === 'wp') {
          st[it.w] = Math.min(5, (st[it.w] || 0) + 1); cur = it.w; sfx('power'); F.burst(me.x, me.y, 16);
          F.text(me.x, me.y - R * 2, `${WP[it.w].vi} ${'★'.repeat(st[it.w])}`, '#ffe066'); saveNow();
        } else if (it.k === 'coin') { coinsRun += 3; sfx('coin'); F.text(it.x, it.y - 20, '+3', '#ffd43b'); }
        else if (it.k === 'heart') { hp = Math.min(maxHp, hp + 1); sfx('power'); }
        else { me.shield = 8; sfx('power'); }
      }
      for (let i = foes.length - 1; i >= 0; i--) if (foes[i].dead) foes.splice(i, 1);
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      if (tk) tile(ctx, tk, groundK, Math.max(96, S * .16), 0, 0, -10, -10, W + 20, H + 20); else { ctx.fillStyle = th.ground; ctx.fillRect(0, 0, W, H); }
      for (const tr of tracks) if (tr.t > 0) spr(ctx, tk, 'tracksSmall', tr.x, tr.y, R * .9, {rot: tr.a + Math.PI / 2, alpha: Math.min(.5, tr.t * .25)});
      for (const w of walls) { const k = 1 + w.hitT * 1.2; spr(ctx, tk, w.k, w.x, w.y, w.h * k * (w.k === 'crateWood' ? 1 : .8), {alpha: .55 + Math.max(0, w.hp) * .15, rot: w.hitT * 1.5}); }
      // Mìn nhấp nháy đèn đỏ
      for (const m of mines) { draw(ctx, 'Bomb', m.x, m.y, 30); if (Math.floor(m.t * 4) % 2) { ctx.fillStyle = '#ff2b2b'; ctx.beginPath(); ctx.arc(m.x + 7, m.y - 9, 4, 0, 7); ctx.fill(); } }
      // Hộp đồ: hộp màu to có hình loại đạn + ngôi sao
      for (const it of items) {
        const y = it.y + Math.sin(t * 5 + it.x) * 3, al = it.t < 2 && Math.floor(it.t * 6) % 2 ? .4 : 1;
        if (it.k === 'wp') {
          const w = WP[it.w], s = narrow ? 44 : 52;
          ctx.globalAlpha = al; ctx.fillStyle = 'rgba(0,0,0,.25)'; roundRect(ctx, it.x - s / 2 + 3, y - s / 2 + 5, s, s, 12); ctx.fill();
          ctx.fillStyle = w.c; roundRect(ctx, it.x - s / 2, y - s / 2, s, s, 12); ctx.fill();
          ctx.strokeStyle = '#fff'; ctx.lineWidth = 3 + Math.sin(t * 8) * 1.5; ctx.stroke(); ctx.globalAlpha = 1;
          draw(ctx, w.img, it.x, y, s * .7, s * .7, {alpha: al});
          draw(ctx, 'Glowing star', it.x + s * .42, y - s * .42, 22, 22, {alpha: al});
        } else draw(ctx, it.k === 'coin' ? 'Coin' : it.k === 'heart' ? 'Red heart' : 'Shield', it.x, y, 40, 40, {alpha: al});
      }
      for (const f of foes) {
        const T = FT[f.k], al = f.flash > 0 ? .55 : 1;
        if (f.k === 'turret') { spr(ctx, tk, 'crateMetal', f.x, f.y, f.s, {alpha: al}); const bl = f.s * .6; spr(ctx, tk, T.barrel, f.x + Math.cos(f.tur) * bl * .35, f.y + Math.sin(f.tur) * bl * .35, bl, {rot: f.tur - Math.PI / 2, alpha: al}); }
        else if (f.boss) {
          drawTank(ctx, tk, f.x, f.y, T.body, T.barrel, f.s * 1.05, f.ang, f.tur, 0, al);
          const o = f.s * .22; for (const sx of [-1, 1]) spr(ctx, tk, 'specialBarrel1', f.x + Math.cos(f.tur) * f.s * .25 - Math.sin(f.tur) * o * sx, f.y + Math.sin(f.tur) * f.s * .25 + Math.cos(f.tur) * o * sx, f.s * .4, {rot: f.tur - Math.PI / 2, alpha: al});
        } else drawTank(ctx, tk, f.x, f.y, T.body, T.barrel, f.s * 1.05, f.ang, f.tur, 0, al);
        // Thanh máu nhỏ cho địch nhiều máu
        if (!f.boss && f.max > 1.5 && f.hp < f.max) { const bw = f.s * .8; ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.fillRect(f.x - bw / 2, f.y - f.s * .7, bw, 6); ctx.fillStyle = '#ff6b6b'; ctx.fillRect(f.x - bw / 2, f.y - f.s * .7, bw * Math.max(0, f.hp / f.max), 6); }
      }
      for (const al of allies) {
        if (al.inv > 0 && Math.floor(al.inv * 10) % 2) continue;
        drawTank(ctx, tk, al.x, al.y, BODY.body, BODY.barrel, R * 1.45, al.a, al.tur);
        draw(ctx, 'Military helmet', al.x, al.y, R * .7);
      }
      // Xe tăng của bé
      const blink = me.inv > 0 && Math.floor(me.inv * 10) % 2;
      if (!blink) {
        drawTank(ctx, tk, me.x, me.y, BODY.body, BODY.barrel, R * 2.1, me.a, me.tur, me.recoil);
        if (me.recoil > .7 && cur !== 'flame' && cur !== 'laser') spr(ctx, tk, 'shotOrange', me.x + Math.cos(me.tur) * R * 1.9, me.y + Math.sin(me.tur) * R * 1.9, R * .9, {rot: me.tur + Math.PI / 2});
        if (me.shield > 0) { ctx.strokeStyle = `rgba(116,192,252,${.6 + .2 * Math.sin(t * 10)})`; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(me.x, me.y, R * 1.5 + Math.sin(t * 6) * 3, 0, 7); ctx.stroke(); }
      }
      // Khiên điện: vòng xanh + tia sét chớp
      if (me.eshield > 0) {
        const rr = R * 1.9, al = me.eshield < 1.5 && Math.floor(me.eshield * 6) % 2 ? .35 : 1;
        ctx.globalAlpha = al; ctx.fillStyle = 'rgba(77,171,247,.18)'; ctx.beginPath(); ctx.arc(me.x, me.y, rr, 0, 7); ctx.fill();
        ctx.strokeStyle = '#74c0fc'; ctx.lineWidth = 4; ctx.stroke();
        ctx.strokeStyle = '#e7f5ff'; ctx.lineWidth = 2; ctx.beginPath();
        for (let k = 0; k < 4; k++) { let a = rand(0, TAU); ctx.moveTo(me.x + Math.cos(a) * rr, me.y + Math.sin(a) * rr); for (let j = 1; j < 4; j++) { a += rand(.1, .3); const r2 = rr * rand(.85, 1.1); ctx.lineTo(me.x + Math.cos(a) * r2, me.y + Math.sin(a) * r2); } }
        ctx.stroke(); ctx.globalAlpha = 1;
      }
      // Tia laser
      for (const bm of beams) {
        const k = bm.t / .22, ex = bm.x + Math.cos(bm.a) * bm.len, ey = bm.y + Math.sin(bm.a) * bm.len;
        ctx.globalAlpha = k; ctx.lineCap = 'round';
        ctx.strokeStyle = bm.c; ctx.lineWidth = bm.w * 2; ctx.beginPath(); ctx.moveTo(bm.x, bm.y); ctx.lineTo(ex, ey); ctx.stroke();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = bm.w * .6; ctx.stroke();
        ctx.globalAlpha = 1; ctx.lineCap = 'butt';
      }
      for (const b of bullets) {
        const a = Math.atan2(b.vy, b.vx);
        if (b.kind === 'enemy') spr(ctx, tk, 'bulletRed2', b.x, b.y, b.big ? 28 : 20, {rot: a + Math.PI / 2});
        else if (b.kind === 'flame') { const k = 1 - b.life / b.max; ctx.globalAlpha = 1 - k * .7; ctx.fillStyle = k < .3 ? '#ffe066' : k < .6 ? '#ff922b' : '#e03131'; ctx.beginPath(); ctx.arc(b.x, b.y, 6 + k * 14, 0, 7); ctx.fill(); ctx.globalAlpha = 1; }
        else if (b.kind === 'bounce') draw(ctx, 'Basketball', b.x, b.y, b.r * 2, b.r * 2, {rot: t * 12});
        else if (b.kind === 'homing') draw(ctx, 'Rocket', b.x, b.y, b.r, b.r, {rot: a + Math.PI / 4});
        else if (b.kind === 'blast') {
          // Đạn pháo bay cầu vồng: bóng dưới đất, quả đạn nhô lên giữa đường
          const k = 1 - b.life / b.max, lift = Math.sin(k * Math.PI) * 40;
          ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.beginPath(); ctx.ellipse(b.x, b.y, b.r * .5, b.r * .3, 0, 0, 7); ctx.fill();
          ctx.fillStyle = '#343a40'; ctx.beginPath(); ctx.arc(b.x, b.y - lift, b.r * .55, 0, 7); ctx.fill(); ctx.fillStyle = '#ff922b'; ctx.beginPath(); ctx.arc(b.x - 3, b.y - lift - 3, b.r * .2, 0, 7); ctx.fill();
        } else spr(ctx, tk, b.spr || 'bulletGreen2', b.x, b.y, b.r * 2.4, {rot: a + Math.PI / 2});
      }
      D.draw(ctx);
      for (const d of deco) spr(ctx, tk, d.k, d.x, d.y, d.s);
      B.draw(ctx);
      if (plane) { ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(plane.x + 30, plane.y + 70, 50, 16, 0, 0, 7); ctx.fill(); draw(ctx, 'Airplane', plane.x, plane.y, 110, 110, {rot: Math.PI / 4}); }
      F.draw(ctx);
      ctx.restore();
      drawHud();
      if (t < 2) levelBanner(ctx, W, H, lv, bossLv ? `Hạ ${need} xe tăng + TRÙM` : `Hạ ${need} xe tăng địch`, 'Chạm để lái · Nhặt hộp súng · Nút trái đổi đạn, nút phải dùng chiêu');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'XE TĂNG HỎNG RỒI!', `Hạ ${killed}/${need}`);
    }
  }, opts.alive);

  // HUD riêng (máu tới 10 tim): xu, tim, năng lượng, mục tiêu, thanh máu trùm, nút đạn + nút chiêu
  function drawHud() {
    ctx.font = '800 28px "Baloo 2", sans-serif'; ctx.textAlign = 'left';
    const ct = String(G.coins + coinsRun);
    ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, 12, 10, Math.max(narrow ? 112 : 150, ctx.measureText(ct).width + 66), 44, 22); ctx.fill();
    draw(ctx, 'Coin', 38, 32, 30); ctx.fillStyle = '#fff'; ctx.fillText(ct, 60, 42);
    const hs = Math.min(narrow ? 22 : 30, W * .42 / maxHp - 3), hg = hs + 3;
    for (let i = 0; i < maxHp; i++) draw(ctx, 'Red heart', W - 12 - hs / 2 - i * hg, 32, hs, hs, {alpha: i < hp ? 1 : .22});
    // Năng lượng chiêu
    const ew = Math.min(170, W * .3), ex = W - 12 - ew, ey = 52;
    ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, ex, ey, ew, 14, 7); ctx.fill();
    ctx.fillStyle = '#ffd43b'; roundRect(ctx, ex + 2, ey + 2, Math.max(4, (ew - 4) * en / 100), 10, 5); ctx.fill();
    draw(ctx, 'High voltage', ex - 12, ey + 7, 22);
    goalPill(ctx, W, killed, need, 16);
    if (boss) {
      const bw = Math.min(360, W * .6), by = narrow ? 104 : 62;
      ctx.fillStyle = 'rgba(0,0,0,.4)'; roundRect(ctx, W / 2 - bw / 2, by, bw, 20, 10); ctx.fill();
      ctx.fillStyle = '#ff6b6b'; roundRect(ctx, W / 2 - bw / 2 + 3, by + 3, (bw - 6) * Math.max(0, boss.hp / boss.max), 14, 7); ctx.fill();
      draw(ctx, 'Collision', W / 2 - bw / 2 - 14, by + 10, 28);
    }
    if (t < 2) return;
    for (const b of wBtns()) {
      const on = b.w.id === cur, r = b.r * (on ? 1.08 : .92);
      ctx.fillStyle = on ? b.w.c : 'rgba(0,0,0,.35)'; ctx.beginPath(); ctx.arc(b.x, b.y, r, 0, 7); ctx.fill();
      ctx.strokeStyle = on ? '#fff' : 'rgba(255,255,255,.5)'; ctx.lineWidth = on ? 4 : 2; ctx.stroke();
      draw(ctx, b.w.img, b.x, b.y - 4, r * 1.1);
      const n = st[b.w.id], sw = Math.min(11, r * .4);
      for (let k = 0; k < n; k++) draw(ctx, 'Glowing star', b.x + (k - (n - 1) / 2) * sw, b.y + r * .68, sw + 2);
    }
    for (const b of sBtns()) {
      const ok = canSkill(b.s), k = Math.min(1, en / b.s.cost);
      ctx.fillStyle = ok ? b.s.c : 'rgba(0,0,0,.4)'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, 7); ctx.fill();
      // Vòng nạp đầy dần
      ctx.strokeStyle = 'rgba(255,255,255,.3)'; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(b.x, b.y, b.r - 3, 0, 7); ctx.stroke();
      ctx.strokeStyle = ok ? '#fff' : '#ffd43b'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r - 3, -Math.PI / 2, -Math.PI / 2 + TAU * k); ctx.stroke();
      const pulse = ok ? 1 + Math.sin(t * 6) * .06 : 1;
      draw(ctx, b.s.img, b.x, b.y, b.r * 1.15 * pulse, b.r * 1.15 * pulse, {alpha: ok ? 1 : .45, rot: b.s.id === 'air' ? Math.PI / 4 : 0});
      if (b.s.id === 'ally') { ctx.fillStyle = '#fff'; ctx.font = '800 16px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(`${allies.length}/2`, b.x, b.y + b.r + 2); }
    }
  }
}
