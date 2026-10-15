// Phi thuyền diệt quái bản nâng cấp: 8 loại súng (laser, toả, plasma xuyên, tên lửa đuổi, tia sét nảy, chùm laser liên tục,
// đạn băng làm chậm, lốc xoáy bumerang), mỗi loại lên 5 sao; máy bay phụ, bom, 3 chiêu có nút (khiên năng lượng, mưa sao băng,
// phi thuyền khổng lồ) nạp khi hạ quái; trùm giữa trận và trùm cuối 2 giai đoạn.
// Kho đồ giữ qua màn (opts.carry): súng đã có + sao cao nhất, súng đang dùng, máy bay phụ, bom, xu, nâng cấp mua ở Xưởng.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {h, img} from '../ui.js?v=4c51d34a6e';
import {anim, approach, booms, dust, shaker, sheets, spr, tile, coin} from './funfx.js?v=4c51d34a6e';
import {LIVES, banner, canvasIn, draw, endText, fx, hit, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect} from './funcore.js?v=4c51d34a6e';

// Màu vũ trụ đổi mỗi 10 cấp.
// Nền sao Kenney theo cảnh
const BG = ['bg_purple', 'bg_blue', 'bg_darkPurple', 'bg_black', 'bg_blue', 'bg_darkPurple'];
const SPACE = [['#1a1b4b', '#3b2c85'], ['#0b3d3a', '#1864ab'], ['#3d0b2e', '#862e9c'], ['#1b1b1b', '#495057'], ['#0b2545', '#0c8599'], ['#3b0a0a', '#c92a2a']];

// Súng: s = frame Kenney, f = hình Fluent làm biểu tượng; mỗi súng tối đa 5 sao
const GUNS = {
  laser: {c: '#ffe066', vi: 'LASER', s: 'laserBlue01'},
  spread: {c: '#69db7c', vi: 'ĐẠN TOẢ', f: 'Sparkles'},
  plasma: {c: '#da77f2', vi: 'PLASMA', orb: true},
  missile: {c: '#ff8787', vi: 'TÊN LỬA', s: 'missile'},
  thunder: {c: '#4dabf7', vi: 'TIA SÉT', f: 'High voltage'},
  beam: {c: '#3bc9db', vi: 'CHÙM LASER', f: 'Flashlight'},
  ice: {c: '#a5d8ff', vi: 'ĐẠN BĂNG', f: 'Snowflake'},
  vortex: {c: '#ffa94d', vi: 'LỐC XOÁY', f: 'Tornado'}
};
const GUN_IDS = Object.keys(GUNS), MAXS = 5;
// Nâng cấp vĩnh viễn ở Xưởng (giá theo bậc). Đo bằng bot: một cấp được ~35-130 xu + thưởng thắng 10+ → 2-4 vé mua 1 món
const UPS = [
  {id: 'hp', f: 'Red heart', max: 2, price: [350, 550]},          // máu tối đa 5 → 7
  {id: 'armor', f: 'Shield', max: 3, price: [200, 350, 500]},     // khiên tự hồi
  {id: 'rate', f: 'Fire', max: 3, price: [200, 350, 500]},        // bắn nhanh hơn
  {id: 'drone', f: 'Satellite', max: 2, price: [250, 450]},       // máy bay phụ khởi đầu
  {id: 'bomb', f: 'Bomb', max: 3, price: [150, 250, 350]},        // bom khởi đầu
  {id: 'magnet', f: 'Magnet', max: 2, price: [150, 300]}          // hút xu xa hơn
];
const GUN_PRICE = 300, starPrice = n => 100 * n;  // mở súng mới; lên sao n → n+1
// Chiêu chủ động: nạp theo số quái hạ được
const SKILLS = [
  {id: 'shield', f: 'Shield', c: '#4dabf7', kills: 10},
  {id: 'meteor', f: 'Shooting star', c: '#ffd43b', kills: 18},
  {id: 'giant', f: 'Rocket', c: '#ff6b6b', kills: 26}
];
const MAX_BOMBS = 5, MAX_DRONES = 2;

const num = v => { const n = Math.floor(+v); return Number.isFinite(n) && n > 0 ? n : 0; };
const clampN = (v, a, b) => Math.max(a, Math.min(b, v));
// Đọc kho đồ phòng thủ: thiếu/sai trường thì dùng mặc định
function readCarry(c) {
  c = c && typeof c === 'object' ? c : {};
  const guns = c.guns && typeof c.guns === 'object' ? c.guns : {}, ups = c.up && typeof c.up === 'object' ? c.up : {}, en = c.en && typeof c.en === 'object' ? c.en : {};
  const own = {laser: 1};
  for (const g of GUN_IDS) { const n = num(guns[g]); if (n) own[g] = clampN(n, 1, MAXS); }
  const up = {};
  for (const u of UPS) up[u.id] = clampN(num(ups[u.id]), 0, u.max);
  const E = {};
  for (const s of SKILLS) { const v = +en[s.id]; E[s.id] = Number.isFinite(v) ? clampN(v, 0, 1) : 0; }
  return {own, up, en: E, gun: own[c.gun] ? c.gun : 'laser', drones: clampN(Math.max(num(c.drones), up.drone), 0, MAX_DRONES),
    bombs: clampN(Math.max(1 + up.bomb, num(c.bombs)), 1, MAX_BOMBS), coins: num(c.coins), wins: num(c.wins)};
}
// Kho đồ ra (JSON thuần)
const pack = G => ({v: 1, guns: {...G.own}, gun: G.gun, up: {...G.up}, drones: G.drones, bombs: clampN(G.bombs, 0, MAX_BOMBS), coins: Math.floor(G.coins), en: Object.fromEntries(SKILLS.map(s => [s.id, Math.round(G.en[s.id] * 100) / 100])), wins: G.wins});

// Biểu tượng súng: quả cầu màu + hình súng (dùng chung cho vật phẩm, HUD, Xưởng)
function gunIcon(ctx, sp, g, x, y, r, alpha = 1) {
  const G = GUNS[g];
  ctx.save(); ctx.globalAlpha = alpha;
  ctx.fillStyle = G.c; ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill();
  ctx.strokeStyle = '#fff'; ctx.lineWidth = Math.max(2, r * .14); ctx.stroke();
  ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.arc(x, y, r * .72, 0, 7); ctx.fill();
  if (G.f) draw(ctx, G.f, x, y, r * 1.3, r * 1.3, {alpha});
  else if (G.orb) { ctx.fillStyle = 'rgba(190,75,219,.9)'; ctx.beginPath(); ctx.arc(x, y, r * .55, 0, 7); ctx.fill(); ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(x, y, r * .28, 0, 7); ctx.fill(); }
  else spr(ctx, sp, G.s, x, y, r * 1.5, {rot: g === 'laser' ? .6 : -.6, alpha});
  ctx.restore();
}

// ---------- Xưởng phi thuyền (DOM, chỉ ở cấp đầu của lượt) ----------
const CSS = `.shp-wrap{position:absolute;inset:0;z-index:3;display:flex;flex-direction:column;align-items:center;gap:12px;padding:70px 14px 18px;background:linear-gradient(#1a1b4b,#5f3dc4);overflow:auto;touch-action:pan-y;color:#fff}
.shp-top{display:flex;align-items:center;gap:14px;flex-wrap:wrap;justify-content:center}
.shp-top h2{margin:0;font-size:1.8em;text-shadow:0 3px 0 rgba(0,0,0,.3)}
.shp-coins{display:flex;align-items:center;gap:6px;background:rgba(0,0,0,.3);border-radius:30px;padding:4px 16px 4px 8px;font-size:1.8em;font-weight:800}
.shp-coins img{width:40px;height:40px}
.shp-guns,.shp-ups{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;width:min(820px,100%)}
.shp-ups{grid-template-columns:repeat(auto-fill,minmax(98px,1fr))}
.shp-card{position:relative;display:flex;flex-direction:column;align-items:center;gap:2px;padding:8px 4px 10px;border-radius:22px;background:rgba(255,255,255,.12);border:4px solid rgba(255,255,255,.25);color:#fff;font:inherit;font-weight:800;box-shadow:0 5px 0 rgba(0,0,0,.25)}
.shp-card canvas{width:84px;height:84px}
.shp-card>img{width:58px;height:58px}
.shp-card.on{background:rgba(255,255,255,.3);border-color:#ffd43b;transform:scale(1.04)}
.shp-card.lock canvas{opacity:.35}
.shp-card .shp-lk{position:absolute;top:26px;width:44px;height:44px}
.shp-card:active{transform:scale(.95)}
.shp-st{font-size:1.15em;letter-spacing:1px;line-height:1}
.shp-st i{font-style:normal;color:rgba(255,255,255,.3)}
.shp-pr{display:flex;align-items:center;gap:3px;font-size:1.2em}
.shp-pr img{width:24px;height:24px}
.shp-pr.no{opacity:.45}
.shp-max{color:#ffd43b;font-size:1.1em;white-space:nowrap}
.shp-star .shp-max{font-size:.95em;letter-spacing:-1px}
.shp-sec{margin:4px 0 0;font-size:1.3em;opacity:.9}
.shp-play{margin-top:6px;font:inherit;font-size:2em;font-weight:800;color:#fff;background:#40c057;border:0;border-radius:40px;padding:12px 56px;box-shadow:0 7px 0 #2b8a3e}
.shp-play:active{transform:translateY(4px);box-shadow:0 3px 0 #2b8a3e}
.shp-shake{animation:shpk .3s}
@keyframes shpk{0%,100%{transform:translateX(0)}25%{transform:translateX(-8px)}75%{transform:translateX(8px)}}
@media (max-width:520px){.shp-card canvas{width:64px;height:64px}.shp-card>img{width:44px;height:44px}.shp-top{padding-left:50px}.shp-top h2{font-size:1.2em}.shp-coins{font-size:1.4em}.shp-coins img{width:30px;height:30px}.shp-ups{grid-template-columns:repeat(4,minmax(0,1fr))}.shp-st{font-size:.95em}.shp-card .shp-lk{top:18px;width:34px;height:34px}}`;

function shop(box, G, sp, save) {
  if (!document.getElementById('shp-css')) document.head.append(h('style', {id: 'shp-css'}, CSS));
  return new Promise(resolve => {
    const wrap = h('div', {class: 'shp-wrap'});
    const stars = n => h('div', {class: 'shp-st', style: {color: '#ffd43b'}}, '★'.repeat(n), h('i', {}, '★'.repeat(MAXS - n)));
    const price = (p, ok = G.coins >= p) => h('div', {class: 'shp-pr' + (ok ? '' : ' no')}, img('Coin'), p);
    const pips = (n, m) => h('div', {class: 'shp-st', style: {color: '#69db7c'}}, '●'.repeat(n), h('i', {}, '●'.repeat(m - n)));
    const buy = (el, p, fn) => {
      if (G.coins < p) { sfx('wrong'); el.classList.remove('shp-shake'); void el.offsetWidth; el.classList.add('shp-shake'); return; }
      G.coins -= p; fn(); sfx('power'); save(); render();
    };
    const gunCv = (g, sz = 96) => { const cv = h('canvas', {width: sz, height: sz}); gunIcon(cv.getContext('2d'), sp, g, sz / 2, sz / 2, sz * .4); return cv; };
    function render() {
      const sel = G.gun, n = G.own[sel];
      wrap.replaceChildren(
        h('div', {class: 'shp-top'}, h('h2', {}, '🚀 Xưởng phi thuyền'), h('div', {class: 'shp-coins'}, img('Coin'), G.coins)),
        h('div', {class: 'shp-guns'}, GUN_IDS.map(g => {
          const has = G.own[g];
          const b = h('button', {class: 'shp-card shp-g-' + g + (g === sel ? ' on' : '') + (has ? '' : ' lock'), 'data-gun': g, onclick: () => {
            if (has) { G.gun = g; sfx('tap'); save(); render(); } else buy(b, GUN_PRICE, () => { G.own[g] = 1; G.gun = g; });
          }}, gunCv(g), has ? stars(has) : [img('Locked', {class: 'shp-lk'}), price(GUN_PRICE)]);
          return b;
        })),
        h('div', {class: 'shp-ups'},
          // Lên sao súng đang chọn
          (() => { const b = h('button', {class: 'shp-card shp-star', onclick: () => n < MAXS && buy(b, starPrice(n), () => { G.own[sel] = n + 1; })}, gunCv(sel, 72), h('div', {class: 'shp-max'}, n < MAXS ? '+★' : '★'.repeat(MAXS)), n < MAXS ? price(starPrice(n)) : h('div', {class: 'shp-max'}, 'MAX')); return b; })(),
          UPS.map(u => {
            const lv = G.up[u.id], p = u.price[lv];
            const b = h('button', {class: 'shp-card shp-u-' + u.id, onclick: () => lv < u.max && buy(b, p, () => {
              G.up[u.id] = lv + 1;
              if (u.id === 'drone') G.drones = Math.max(G.drones, G.up.drone);
              if (u.id === 'bomb') G.bombs = clampN(Math.max(G.bombs, 1 + G.up.bomb), 1, MAX_BOMBS);
            })}, img(u.f), pips(lv, u.max), lv < u.max ? price(p) : h('div', {class: 'shp-max'}, 'MAX'));
            return b;
          })),
        h('button', {class: 'shp-play', onclick: () => { sfx('power'); wrap.remove(); resolve(); }}, 'Chơi ▶'));
    }
    render();
    box.append(wrap);
  });
}

export async function shooter(box, opts) {
  // Cấp: quái nhanh, dày, trâu hơn; trùm nhiều máu và bắn dày hơn.
  const lv = opts.level || 0, space = SPACE[Math.floor(lv / 10) % SPACE.length], hpUp = Math.floor(lv / 15);
  const ENEMY = ['Alien monster', 'Flying saucer', 'Ghost', 'Bat', 'Octopus', 'Comet'];
  const [[sp, fxs]] = await Promise.all([sheets(['space/space', 'fxa/fx']), loadAll(['Rocket', ...ENEMY, 'Alien', 'Glowing star', 'Shield', 'Red heart', 'Coin', 'Ringed planet', 'Crescent moon', 'Bomb', 'Magnet', 'Satellite', 'Collision',
    'Sparkles', 'High voltage', 'Flashlight', 'Snowflake', 'Tornado', 'Shooting star', 'Fire', 'Locked'])]);
  // Kho đồ: đọc từ opts.carry; Xưởng chỉ hiện ở cấp đầu của lượt (opts dùng chung giữa các cấp trong một vé)
  const G = readCarry(opts.carry);
  let lastSave = 0;
  const save = () => { lastSave = G.coins; if (opts.saveGear) opts.saveGear(pack(G)); };
  if (!opts._shopDone) {
    opts._shopDone = true;
    await shop(box, G, sp, save);
    if (!opts.alive()) return null;
  }
  // Quái là phi thuyền, đĩa bay, thiên thạch Kenney (hình emoji cũ chỉ là khoá luật chơi)
  const LOOK = {'Alien monster': 'enemyGreen1', 'Ghost': 'enemyBlue2', 'Bat': 'enemyRed4', 'Flying saucer': 'ufoRed', 'Octopus': 'enemyBlack5', 'Comet': 'meteorBrown_big1'};
  const bgK = BG[Math.floor(lv / 10) % BG.length], D = dust(240), B = booms(fxs, 30), SH = shaker();
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), narrow = W < 520;
  const own = G.own, cur = {...own};  // own: sao đã sở hữu (lưu), cur: sao trong màn (trúng đòn tạm hạ)
  const me = {vx: 0, bank: 0, x: W / 2, y: H * .8, w: S * .13, h: S * .13, tx: W / 2, ty: H * .8, inv: 0, shield: G.up.armor ? 6 : 0, magnet: 0, gun: G.gun, eshield: 0, giant: 0, gs: 1};
  const shots = [], foes = [], orbs = [], items = [], coins = [], stars = [], zaps = [], meteors = [], F = fx();
  for (let i = 0; i < 80; i++) { const s = rand(1, 3); stars.push({x: rand(0, W), y: rand(0, H), s, v: s * s * 18 + rand(0, 20)}); }  // sao gần chạy nhanh (parallax)
  const maxLives = LIVES + G.up.hp, rateK = 1 - .08 * G.up.rate, magR = S * (.15 + .08 * G.up.magnet), armorCd = G.up.armor ? 30 - 6 * G.up.armor : 0;
  let scrollY = 0, pop = 0, score = 0, lives = maxLives, t = 0, fire = 0, droneFire = 0, spawn = 1.2, boss = null, midDone = false, end = null, endT = 0, flash = 0, got = 0, armorT = armorCd, beamSnd = 0;
  // Nút: bom góc phải dưới, 3 chiêu cột trái dưới, thanh súng trên HUD (dưới thanh máu trùm, tránh nút thoát)
  const btnR = Math.min(56, S * .09), bombBtn = {x: W - btnR - 20, y: H - btnR - 20}, skR = btnR * .85;
  const skBtn = SKILLS.map((s, i) => ({...s, x: skR + 20, y: H - skR - 20 - i * (skR * 2 + 14)}));
  const gunBar = {x: 68, y: 88, h: 44};
  const owned = () => GUN_IDS.filter(g => own[g]);
  const step = () => Math.min(40, (W - gunBar.x - 14) / owned().length), barW = () => owned().length * step() + 8;
  const at = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  const steer = e => { const [x, y] = at(e); me.tx = x; me.ty = Math.max(H * .35, Math.min(H - 30, y - S * .09)); };
  // Chạm nút nào? (trả về hàm xử lý) — kiểm trước khi lái
  const button = e => {
    const [x, y] = at(e);
    if (Math.hypot(x - bombBtn.x, y - bombBtn.y) < btnR * 1.15) return useBomb;
    for (const b of skBtn) if (Math.hypot(x - b.x, y - b.y) < skR * 1.15) return () => useSkill(b.id);
    if (x > gunBar.x - 6 && x < gunBar.x + barW() + 6 && y > gunBar.y - 6 && y < gunBar.y + gunBar.h + 30) return nextGun;
    return null;
  };
  const btnPtr = new Set();
  cv.addEventListener('pointerdown', e => { const fn = button(e); if (fn) { btnPtr.add(e.pointerId); return fn(); } cv.setPointerCapture(e.pointerId); steer(e); });
  cv.addEventListener('pointermove', e => { if (btnPtr.has(e.pointerId)) return; if (e.buttons || e.pointerType !== 'mouse') steer(e); });
  const unPtr = e => btnPtr.delete(e.pointerId);
  cv.addEventListener('pointerup', unPtr); cv.addEventListener('pointercancel', unPtr);

  // Sức mạnh đồ → quái/trùm tăng máu nhẹ để cấp cao vẫn có thử thách
  const power = () => Math.min(1.9, 1 + .1 * (cur[me.gun] - 1) + .12 * G.drones + .05 * G.up.rate + .04 * G.up.armor + .05 * G.up.hp);
  // Súng rơi: thường là súng đang dùng (lên sao), đôi khi súng khác đã có hoặc súng mới
  const dropGun = () => { const r = Math.random(), o = owned().filter(g => g !== me.gun); return r < .5 || (r < .8 && !o.length) ? me.gun : r < .8 ? pick(o) : pick(GUN_IDS); };
  const drop = (x, y) => {
    for (let k = 0; k < 2; k++) coins.push({x: x + rand(-14, 14), y, vy: rand(-80, 20), w: 30, h: 30});
    const r = Math.random();
    if (r < .1) items.push({k: 'gun', gun: dropGun(), x, y, w: 50, h: 50});
    else if (r < .13) items.push({k: 'Shield', x, y, w: 50, h: 50});
    else if (r < .155) items.push({k: 'Red heart', x, y, w: 50, h: 50});
    else if (r < .18) items.push({k: 'Bomb', x, y, w: 50, h: 50});
    else if (r < .2) items.push({k: 'Satellite', x, y, w: 50, h: 50});
    else if (r < .22) items.push({k: 'Magnet', x, y, w: 50, h: 50});
  };
  const kill = (f) => {
    B.add(f.x, f.y, f.w * 1.5); D.sparks(f.x, f.y, 12, '#ffe066', 300); D.puff(f.x, f.y, 4, 'rgba(160,160,180,1)', 50, f.w * .15); SH.add(f.big ? 5 : 2.5);
    F.star(f.x, f.y); score += f.pts; sfx('boom'); F.text(f.x, f.y - 30, '+' + f.pts, '#ffd43b');
    drop(f.x, f.y);
    // Nạp chiêu
    for (const s of SKILLS) if (G.en[s.id] < 1) { G.en[s.id] = Math.min(1, G.en[s.id] + 1 / s.kills); if (G.en[s.id] >= 1) { sfx('star'); F.text(W / 2, H * .55, 'CHIÊU SẴN SÀNG!', s.c); } }
  };
  // Trúng quái: hết máu thì đánh dấu chết (dọn ở vòng quái), không xoá giữa vòng lặp
  const hitFoe = (f, dmg, x, y) => {
    if (f.dead) return false;
    f.hp -= dmg; f.flash = .08;
    if (f.hp > 0) { D.sparks(x, y, 5, '#fff3bf', 180); return false; }
    f.dead = true; kill(f); return true;
  };
  // Trúng trùm: mọi nguồn sát thương (đạn, chùm, sét, bom, sao băng) đi qua đây
  const bossHit = (dmg, x, y) => {
    if (!boss) return;
    boss.hp -= dmg; boss.flash = .08; D.sparks(x, y, 4, '#fff3bf', 160);
    if (boss.hp > 0) return;
    for (let k = 0; k < 8; k++) B.add(boss.x + rand(-boss.w * .4, boss.w * .4), boss.y + rand(-boss.h * .3, boss.h * .3), rand(90, 160)); SH.add(14); flash = .3; D.sparks(boss.x, boss.y, 30, '#ffd43b', 420);
    score += boss.final ? 40 : 15; sfx('win'); drop(boss.x, boss.y); drop(boss.x - 40, boss.y); drop(boss.x + 40, boss.y);
    if (boss.final) finish(true); else { midDone = true; items.push({k: 'gun', gun: dropGun(), x: boss.x, y: boss.y, w: 50, h: 50}); }
    boss = null;
  };
  // Kết thúc: thắng thì thưởng xu; kho đồ luôn trả về (thua cũng giữ)
  function finish(win) {
    if (end) return;
    let bonus = 0;
    if (win) { bonus = 10 + Math.floor(lv / 3); G.coins += bonus; G.wins++; }
    end = {win, score, bonus};
  }
  function useBomb() {
    if (G.bombs <= 0 || end) return;
    G.bombs--; flash = .5; SH.add(16); sfx('boom'); sfx('win');
    for (let k = 0; k < 8; k++) B.add(rand(W * .1, W * .9), rand(H * .1, H * .7), rand(100, 180));
    for (const f of foes) if (!f.dead) { f.dead = true; kill(f); }
    orbs.length = 0;
    if (boss) bossHit(Math.min(12, boss.max * .15), boss.x, boss.y);
    F.text(W / 2, H * .45, 'BÙM!', '#ffd43b');
    save();
  }
  function useSkill(id) {
    if (end || G.en[id] < 1) { sfx('tap'); return; }
    G.en[id] = 0; sfx('power'); sfx('win'); flash = .25;
    const ty = H * (.4 + .07 * SKILLS.findIndex(s => s.id === id));
    if (id === 'shield') { me.eshield = 8; F.text(W / 2, ty, 'KHIÊN NĂNG LƯỢNG!', '#74c0fc'); }
    else if (id === 'meteor') { for (let k = 0; k < 18; k++) meteors.push({x: rand(W * .05, W * 1.1), y: -60 - k * 45, vx: -120, vy: rand(650, 800), w: S * .09, h: S * .09, hitB: false}); F.text(W / 2, ty, 'MƯA SAO BĂNG!', '#ffd43b'); }
    else { me.giant = 8; F.text(W / 2, ty, 'PHI THUYỀN KHỔNG LỒ!', '#ff6b6b'); }
    save();
  }
  function nextGun() {
    const o = owned();
    if (o.length < 2 || end) return;
    me.gun = G.gun = o[(o.indexOf(me.gun) + 1) % o.length]; fire = .05;
    sfx('tap'); F.text(me.x, me.y - 60, GUNS[me.gun].vi, GUNS[me.gun].c); save();
  }
  const add = s => { if (shots.length < 160) shots.push(s); };
  // Tia sét: đánh quái gần nhất phía trên rồi nảy sang quái kế bên
  function zap(x, y, n, dmg) {
    const pts = [[x, y]], seen = new Set();
    let px = x, py = y, range = Math.max(W, H);
    for (let k = 0; k < n; k++) {
      let best = null, bd = range;
      for (const f of foes) { if (f.dead || seen.has(f) || (k === 0 && f.y > y)) continue; const d = Math.hypot(f.x - px, f.y - py); if (d < bd) { bd = d; best = f; } }
      if (!best && boss && !seen.has(boss) && (k === 0 || Math.hypot(boss.x - px, boss.y - py) < range * 1.3)) best = boss;
      if (!best) break;
      seen.add(best); pts.push([best.x, best.y]); px = best.x; py = best.y; range = S * .38;
      if (best === boss) { bossHit(dmg, best.x, best.y); break; }
      hitFoe(best, dmg, best.x, best.y);
    }
    if (pts.length < 2) pts.push([x + rand(-30, 30), y - S * .3]);
    // Đường gấp khúc làm sẵn (không tính mỗi khung)
    const line = [pts[0]];
    for (let i = 1; i < pts.length; i++) { const [ax, ay] = pts[i - 1], [bx, by] = pts[i]; for (let j = 1; j <= 3; j++) line.push([ax + (bx - ax) * j / 4 + rand(-12, 12), ay + (by - ay) * j / 4 + rand(-12, 12)]); line.push([bx, by]); }
    if (zaps.length < 12) zaps.push({line, life: .16});
  }
  // Bắn theo loại súng và cấp sao
  function shoot(x, y, small = false) {
    const g = small ? 'laser' : me.gun, sv = small ? 1 : cur[me.gun];
    if (g === 'laser') {
      for (const dx of [[0], [-10, 10], [-16, 0, 16], [-24, -8, 8, 24], [-30, -15, 0, 15, 30]][sv - 1]) add({x: x + dx, y, vx: 0, vy: -820, w: 10, h: 26, dmg: 1, k: 'laser'});
    } else if (g === 'spread') {
      const n = [3, 5, 7, 9, 11][sv - 1];
      for (let i = 0; i < n; i++) { const a = (i - (n - 1) / 2) * .15; add({x, y, vx: Math.sin(a) * 700, vy: -Math.cos(a) * 700, w: 14, h: 14, dmg: 1, k: 'spread'}); }
    } else if (g === 'plasma') {
      for (const dx of [[0], [-14, 14], [-22, 0, 22], [-22, 0, 22], [-30, -10, 10, 30]][sv - 1]) add({x: x + dx, y, vx: 0, vy: -520, w: 30 + sv * 4, h: 30 + sv * 4, dmg: sv >= 4 ? 3 : 2, k: 'plasma', pierce: 3 + sv});
    } else if (g === 'missile') {
      add({x, y, vx: 0, vy: -820, w: 10, h: 26, dmg: 1, k: 'laser'});
      const n = sv + 1;
      for (let i = 0; i < n; i++) add({x: x + (i - (n - 1) / 2) * 20, y: y + 10, vx: (i - (n - 1) / 2) * 120, vy: -380, w: 22, h: 22, dmg: 2, k: 'missile', seek: true});
    } else if (g === 'thunder') zap(x, y, 1 + sv, sv >= 4 ? 2 : 1);
    else if (g === 'ice') {
      const n = [1, 2, 3, 3, 4][sv - 1];
      for (let i = 0; i < n; i++) { const a = (i - (n - 1) / 2) * .12; add({x, y, vx: Math.sin(a) * 640, vy: -Math.cos(a) * 640, w: 26, h: 26, dmg: 1, k: 'ice', slow: true, pierce: sv >= 4 ? 2 : 0}); }
    } else if (g === 'vortex') {
      const n = [1, 2, 2, 3, 3][sv - 1];
      for (let i = 0; i < n; i++) add({x, y, vx: (i - (n - 1) / 2) * 170, vy: -780, ay: 780 * 780 / (2 * H * .75), w: 40 + sv * 5, h: 40 + sv * 5, dmg: sv >= 4 ? 2 : 1.5, k: 'vortex', pierce: 99, back: false});
    }
    // Phi thuyền khổng lồ: thêm 2 tia từ cánh
    if (!small && me.giant > 0) for (const d of [-1, 1]) add({x: x + d * me.w * .8, y: y + me.h * .3, vx: d * 60, vy: -820, w: 12, h: 30, dmg: 1, k: 'laser'});
  }
  const RATE = {laser: [.18, .16, .14, .13, .12], spread: [.28, .26, .24, .22, .2], plasma: [.42, .38, .34, .31, .28], missile: [.5, .45, .4, .37, .34],
    thunder: [.42, .38, .34, .31, .28], beam: [.1, .1, .1, .1, .1], ice: [.26, .24, .22, .2, .18], vortex: [.55, .5, .46, .42, .38]};
  const rate = () => RATE[me.gun][cur[me.gun] - 1] * (me.gun === 'beam' ? 1 : rateK) * (me.giant > 0 ? .6 : 1);
  const beamW = () => S * (.03 + .012 * cur.beam) * (me.giant > 0 ? 1.6 : 1);
  // Chùm laser: mỗi nhịp gây sát thương mọi quái trong cột phía trên
  function beamTick() {
    const sv = cur.beam, bw = beamW(), dmg = (.4 + .08 * sv) / rateK;
    for (const f of foes) if (!f.dead && f.y < me.y && Math.abs(f.x - me.x) < bw / 2 + f.w * .4) hitFoe(f, dmg, f.x, f.y + f.h * .3);
    if (boss && boss.y < me.y && Math.abs(boss.x - me.x) < bw / 2 + boss.w * .35) bossHit(dmg, me.x, boss.y + boss.h * .3);
  }

  // Kiểu quái: điểm, máu, cách bay
  const ENEMIES = {
    'Alien monster': {hp: 1, pts: 2, v: 90},
    'Ghost': {hp: 1, pts: 2, v: 70, wave: 40},
    'Bat': {hp: 1, pts: 3, v: 150, swoop: true},
    'Flying saucer': {hp: 3, pts: 4, v: 70, gun: true},
    'Octopus': {hp: 6, pts: 6, v: 50, big: 1.4},
    'Comet': {hp: 2, pts: 2, v: 220, rock: true}
  };
  const hpOf = base => Math.max(base, Math.round(base * power()));
  const spawnFoe = () => {
    const tt = t + ramp(lv, 0, 30), pool = tt < 15 ? ['Alien monster', 'Ghost', 'Bat'] : tt < 35 ? ['Alien monster', 'Ghost', 'Bat', 'Flying saucer', 'Comet'] : Object.keys(ENEMIES);
    const k = pick(pool), e = ENEMIES[k], sz = S * rand(.1, .12) * (e.big || 1);
    if (Math.random() < .25 && t > 8) {
      // Đội hình chữ V
      const cx = rand(W * .25, W * .75);
      for (let i = -2; i <= 2; i++) foes.push({k: 'Alien monster', ...ENEMIES['Alien monster'], hp: hpOf(1), x: cx + i * sz * .9, y: -sz - Math.abs(i) * sz * .6, w: sz * .85, h: sz * .85, ph: 0, vy: 110, cd: 9});
      return;
    }
    foes.push({k, ...e, hp: hpOf(e.hp + hpUp), x: rand(sz, W - sz), y: -sz, w: sz, h: sz, ph: rand(0, 6), vy: (e.v + t * .8) * ramp(lv, 1, 1.5), vx: e.rock ? rand(-80, 80) : 0, cd: rand(1, 3)});
  };
  const makeBoss = (final) => { const hp = Math.round((final ? ramp(lv, 70, 190) : ramp(lv, 28, 80)) * power()); return {k: final ? 'Flying saucer' : 'Alien', final, x: W / 2, y: -S * .3, w: S * (final ? .4 : .3), h: S * (final ? .4 : .3), hp, max: hp, cd: 1.5, ph: 0, flash: 0}; };

  return loop({
    update(dt) {
      t += dt;
      for (const s of stars) { s.y += s.v * dt * (boss ? .5 : 1); if (s.y > H) { s.y = 0; s.x = rand(0, W); } }
      flash = Math.max(0, flash - dt); SH.update(dt); D.update(dt); B.update(dt); scrollY += dt * (boss ? 20 : 45);
      for (let i = zaps.length - 1; i >= 0; i--) if ((zaps[i].life -= dt) <= 0) zaps.splice(i, 1);
      if (end) { endT += dt; F.update(dt); return endT > 2.2 ? {win: end.win, score, carry: pack(G)} : null; }
      // Bay có quán tính: vận tốc tiến dần về phía ngón tay, thân nghiêng theo hướng lượn
      const px = me.x;
      me.x = approach(me.x, me.tx, 9, dt); me.y = approach(me.y, me.ty, 9, dt);
      me.vx = (me.x - px) / Math.max(dt, .001); me.bank = approach(me.bank, Math.max(-1, Math.min(1, me.vx / 700)), 10, dt);
      if (Math.random() < .7) D.emit(me.x + rand(-4, 4), me.y + me.h * .5, rand(-20, 20), rand(160, 260), {life: .25, r: 3, grow: 4, c: Math.random() < .5 ? '#ffa94d' : '#ffe066', a: .9});
      me.inv = Math.max(0, me.inv - dt); me.shield = Math.max(0, me.shield - dt); me.magnet = Math.max(0, me.magnet - dt);
      me.eshield = Math.max(0, me.eshield - dt); me.giant = Math.max(0, me.giant - dt); me.gs = approach(me.gs, me.giant > 0 ? 1.8 : 1, 6, dt);
      // Giáp: khiên tự hồi
      if (armorCd && me.shield <= 0) { armorT -= dt; if (armorT <= 0) { armorT = armorCd; me.shield = 8; F.text(me.x, me.y - 50, 'KHIÊN!', '#74c0fc'); } }
      const meBox = {x: me.x, y: me.y, w: me.w * me.gs, h: me.h * me.gs};
      fire -= dt;
      if (fire <= 0) {
        fire = rate();
        if (me.gun === 'beam') { beamTick(); if ((beamSnd -= fire) <= 0) { beamSnd = .3; sfx('laser'); } if (me.giant > 0) shoot(me.x, me.y - me.h / 2); }
        else { sfx(me.gun === 'plasma' || me.gun === 'vortex' ? 'shoot' : 'laser'); shoot(me.x, me.y - me.h * me.gs / 2); }
      }
      droneFire -= dt;
      if (G.drones && droneFire <= 0) { droneFire = .35; for (let k = 0; k < G.drones; k++) shoot(me.x + (k ? 1 : -1) * me.w * .9 * me.gs, me.y, true); }
      // Sinh quái, trùm giữa trận (30s) và trùm cuối (60s)
      if (!boss) {
        spawn -= dt;
        if (spawn <= 0 && t < 60 && !(t > 28 && !midDone)) { spawn = Math.max(.3, 1.1 - t / 90) * ramp(lv, 1, .65); spawnFoe(); }
        if (t > 28 && !midDone && !foes.length) { boss = makeBoss(false); sfx('power'); F.text(W / 2, H * .3, 'QUÁI TO XUẤT HIỆN!', '#ff6b6b'); }
        if (t >= 60 && midDone && !foes.length) { boss = makeBoss(true); sfx('power'); F.text(W / 2, H * .3, 'TRÙM CUỐI!', '#ff6b6b'); }
      } else {
        boss.ph += dt; boss.flash = Math.max(0, boss.flash - dt);
        boss.y += (H * .2 - boss.y) * Math.min(1, dt * 1.5); boss.x = W / 2 + Math.sin(boss.ph * .9) * (W * .32);
        boss.cd -= dt;
        const rage = boss.final && boss.hp < boss.max / 2;
        if (boss.cd <= 0) {
          const bcd = ramp(lv, 1, .65);
          if (!boss.final) { boss.cd = 1.4 * bcd; for (const a of [-.5, -.25, 0, .25, .5]) orbs.push({x: boss.x, y: boss.y + boss.h * .3, vx: Math.sin(a) * 170, vy: Math.cos(a) * 170, w: 22, h: 22}); }
          else if (!rage) { boss.cd = 1.2 * bcd; for (const a of [-.45, 0, .45]) orbs.push({x: boss.x, y: boss.y + boss.h * .3, vx: Math.sin(a) * 190, vy: Math.cos(a) * 190, w: 24, h: 24}); }
          else {
            boss.cd = .9 * bcd;
            for (let k = 0; k < 8; k++) { const a = boss.ph * 2 + k * Math.PI / 4; orbs.push({x: boss.x, y: boss.y, vx: Math.cos(a) * 150, vy: Math.abs(Math.sin(a)) * 150 + 40, w: 20, h: 20}); }
            if (foes.length < 4 && Math.random() < .3) { const sz = S * .09; foes.push({k: 'Bat', ...ENEMIES.Bat, hp: hpOf(1), x: boss.x, y: boss.y, w: sz, h: sz, ph: 0, vy: 160, vx: 0, cd: 9}); }
          }
        }
      }
      const hurt = () => {
        if (me.inv > 0 || me.eshield > 0 || me.giant > 0) return;
        if (me.shield > 0) { me.shield = 0; me.inv = 1; armorT = armorCd; sfx('pop'); return; }
        lives--; me.inv = 1.8; sfx('hit'); SH.add(10); flash = .15; B.add(me.x, me.y, me.w * 1.2); D.sparks(me.x, me.y, 16, '#ff8787', 300);
        // Trong màn tạm hạ sao súng; kho đồ vẫn giữ sao cao nhất đã có
        if (cur[me.gun] > 1) { cur[me.gun]--; F.text(me.x, me.y - 50, 'Súng yếu đi', '#ced4da'); }
        if (lives <= 0) finish(false);
      };
      // Đạn của bé
      for (let i = shots.length - 1; i >= 0; i--) {
        const s = shots[i];
        if (s.seek) {
          let tg = boss, bd = 1e9;
          if (!tg) for (const f of foes) { if (f.dead) continue; const d = Math.hypot(f.x - s.x, f.y - s.y); if (d < bd) { bd = d; tg = f; } }
          if (tg) { const a = Math.atan2(tg.y - s.y, tg.x - s.x), sp = 620; s.vx += (Math.cos(a) * sp - s.vx) * Math.min(1, dt * 5); s.vy += (Math.sin(a) * sp - s.vy) * Math.min(1, dt * 5); }
          if (Math.random() < .6) D.emit(s.x, s.y, rand(-15, 15), rand(-15, 15), {life: .4, r: 3, grow: 8, c: 'rgba(230,230,230,1)', a: .5});
        }
        // Lốc xoáy: bay lên, chậm dần rồi quay về (lượt về đánh lại được)
        if (s.ay) { s.vy += s.ay * dt; if (!s.back && s.vy > 0) { s.back = true; s.hitSet = null; s.hitB = false; } }
        s.x += s.vx * dt; s.y += s.vy * dt;
        if (s.y < -50 || s.y > H + 50 || s.x < -50 || s.x > W + 50) { shots.splice(i, 1); continue; }
        let used = false;
        for (let j = foes.length - 1; j >= 0 && !used; j--) {
          const f = foes[j];
          if (f.dead || !hit(s, f, .9) || (s.hitSet && s.hitSet.has(f))) continue;
          if (s.pierce) { s.hitSet = s.hitSet || new Set(); s.hitSet.add(f); if (--s.pierce <= 0) used = true; } else used = true;
          if (s.slow) f.slow = 2.5;
          hitFoe(f, s.dmg, s.x, s.y);
        }
        if (!used && boss && !s.hitB && hit(s, boss, .8)) {
          if (s.k === 'vortex') s.hitB = true; else used = true;
          bossHit(s.dmg, s.x, s.y);
        }
        if (used) shots.splice(i, 1);
      }
      // Mưa sao băng: rơi chéo, hạ quái trên đường, trúng trùm một lần (sát thương nhỏ theo % máu trùm)
      for (let i = meteors.length - 1; i >= 0; i--) {
        const m = meteors[i]; m.x += m.vx * dt; m.y += m.vy * dt;
        if (m.y > H + 80) { meteors.splice(i, 1); continue; }
        if (m.y < -40) continue;
        if (Math.random() < .5) D.emit(m.x, m.y - 20, rand(-20, 20), rand(-60, -20), {life: .35, r: 4, grow: 8, c: '#ffa94d', a: .8});
        for (const f of foes) if (!f.dead && hit(m, f, .9)) { hitFoe(f, 4, f.x, f.y); B.add(f.x, f.y, f.w); }
        if (boss && !m.hitB && hit(m, boss, .7)) { m.hitB = true; B.add(m.x, m.y, 90); bossHit(Math.max(1, boss.max * .015), m.x, m.y); }
      }
      for (let i = foes.length - 1; i >= 0; i--) {
        const f = foes[i];
        if (f.dead) { foes.splice(i, 1); continue; }
        f.ph += dt; f.flash = Math.max(0, (f.flash || 0) - dt); f.slow = Math.max(0, (f.slow || 0) - dt);
        const k = f.slow > 0 ? .4 : 1;
        f.y += f.vy * dt * k; f.x += (f.vx || 0) * dt * k;
        if (f.wave) f.x += Math.sin(f.ph * 2) * f.wave * dt * 3 * k;
        if (f.swoop) f.x += Math.sign(me.x - f.x) * 60 * dt * k;
        if (f.gun) { f.cd -= dt * k; if (f.cd <= 0) { f.cd = rand(2, 3.2); const a = Math.atan2(me.y - f.y, me.x - f.x); orbs.push({x: f.x, y: f.y + f.h / 3, vx: Math.cos(a) * 170, vy: Math.sin(a) * 170, w: 20, h: 20}); } }
        if (f.y > H + 60 || f.x < -80 || f.x > W + 80) { foes.splice(i, 1); continue; }
        if (hit(meBox, f, .55)) {
          // Phi thuyền khổng lồ húc tan quái
          if (me.giant > 0) { f.dead = true; kill(f); foes.splice(i, 1); continue; }
          hurt(); foes.splice(i, 1); B.add(f.x, f.y, f.w * 1.3);
        }
      }
      for (let i = orbs.length - 1; i >= 0; i--) {
        const o = orbs[i]; o.x += o.vx * dt; o.y += o.vy * dt;
        if (o.y > H + 30 || o.y < -40 || o.x < -30 || o.x > W + 30) { orbs.splice(i, 1); continue; }
        // Khiên năng lượng đốt đạn địch ở gần
        if (me.eshield > 0 && Math.hypot(o.x - me.x, o.y - me.y) < me.h * me.gs * .9) { D.sparks(o.x, o.y, 6, '#74c0fc', 200); orbs.splice(i, 1); continue; }
        if (hit(meBox, o, .5)) { hurt(); orbs.splice(i, 1); }
      }
      // Xu rơi; nam châm hút
      for (let i = coins.length - 1; i >= 0; i--) {
        const c = coins[i]; c.vy += 260 * dt;
        if (me.magnet > 0 || Math.hypot(me.x - c.x, me.y - c.y) < magR * me.gs) { c.x += (me.x - c.x) * Math.min(1, dt * 8); c.y += (me.y - c.y) * Math.min(1, dt * 8); }
        else c.y += Math.min(c.vy, 160) * dt;
        if (c.y > H + 30) { coins.splice(i, 1); continue; }
        if (hit(meBox, c, .9)) { score++; got++; G.coins++; sfx('coin'); coins.splice(i, 1); D.sparks(c.x, c.y, 5, '#ffe066', 140); if (G.coins - lastSave >= 20) save(); }
      }
      for (let i = items.length - 1; i >= 0; i--) {
        const it = items[i]; it.y += 110 * dt;
        if (it.y > H + 40) { items.splice(i, 1); continue; }
        if (!hit(meBox, it, .9)) continue;
        sfx('power'); items.splice(i, 1); D.sparks(it.x, it.y, 14, '#74c0fc', 260); pop = .3;
        if (it.k === 'gun') {
          const g = it.gun, Gn = GUNS[g];
          if (!own[g]) { own[g] = cur[g] = 1; me.gun = G.gun = g; F.text(it.x, it.y - 20, 'SÚNG MỚI: ' + Gn.vi + '!', Gn.c); sfx('win'); }
          else if (cur[g] >= MAXS) {
            // Súng đã max: đổi thành xu thưởng
            const b = 15 + Math.floor(lv / 4); G.coins += b; got += b; score += b; me.gun = G.gun = g;
            F.text(it.x, it.y - 20, `MAX! +${b} XU`, '#ffd43b'); sfx('coin'); D.sparks(it.x, it.y, 20, '#ffd43b', 320);
          } else { cur[g]++; own[g] = Math.max(own[g], cur[g]); me.gun = G.gun = g; F.text(it.x, it.y - 20, `${Gn.vi} ${'★'.repeat(cur[g])}`, Gn.c); }
        } else if (it.k === 'Shield') { me.shield = 10; F.text(it.x, it.y - 20, 'KHIÊN!', '#74c0fc'); }
        else if (it.k === 'Bomb') {
          if (G.bombs < MAX_BOMBS) { G.bombs++; F.text(it.x, it.y - 20, '+1 BOM', '#ff922b'); }
          else { G.coins += 5; got += 5; F.text(it.x, it.y - 20, '+5 XU', '#ffd43b'); }
        } else if (it.k === 'Satellite') {
          if (G.drones < MAX_DRONES) { G.drones++; F.text(it.x, it.y - 20, 'MÁY BAY PHỤ!', '#4dabf7'); }
          else { G.coins += 5; got += 5; F.text(it.x, it.y - 20, '+5 XU', '#ffd43b'); }
        } else if (it.k === 'Magnet') { me.magnet = 10; F.text(it.x, it.y - 20, 'NAM CHÂM!', '#ff6b6b'); }
        else { lives = Math.min(maxLives, lives + 1); F.text(it.x, it.y - 20, '+❤', '#ff6b6b'); }
        save();
      }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save();
      SH.apply(ctx);
      // Nền: ô sao Kenney cuộn chậm + 3 lớp sao parallax + hành tinh xa
      if (sp) tile(ctx, sp, bgK, 256, 0, -scrollY, -20, -20, W + 40, H + 40);
      else { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, space[0]); g.addColorStop(1, space[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
      if (boss && boss.final) { ctx.fillStyle = 'rgba(80,0,60,.25)'; ctx.fillRect(-20, -20, W + 40, H + 40); }
      ctx.fillStyle = '#fff';
      for (const s of stars) { ctx.globalAlpha = s.s / 3; ctx.fillRect(s.x, s.y, s.s, s.s * (1 + s.v / 80)); }
      ctx.globalAlpha = 1;
      draw(ctx, 'Ringed planet', W * .85, (t * 8) % (H + 200) - 100, S * .2, S * .2, {alpha: .9});
      draw(ctx, 'Crescent moon', W * .12, ((t * 5) + H * .5) % (H + 200) - 100, S * .14, S * .14, {alpha: .8});
      D.draw(ctx);
      // Chùm laser liên tục (vài hình chữ nhật, không gradient)
      if (me.gun === 'beam' && !end) {
        const bw = beamW(), top = me.y - me.h * me.gs * .45, fl = .85 + Math.sin(t * 40) * .15;
        ctx.globalAlpha = .3 * fl; ctx.fillStyle = GUNS.beam.c; ctx.fillRect(me.x - bw * .9, 0, bw * 1.8, top);
        ctx.globalAlpha = .75 * fl; ctx.fillRect(me.x - bw / 2, 0, bw, top);
        ctx.globalAlpha = 1; ctx.fillStyle = '#fff'; ctx.fillRect(me.x - bw * .16, 0, bw * .32, top);
        ctx.beginPath(); ctx.arc(me.x, top, bw * .7, 0, 7); ctx.fill();
      }
      for (const s of shots) {
        if (s.k === 'laser') spr(ctx, sp, 'laserBlue01', s.x, s.y, 34);
        else if (s.k === 'spread') spr(ctx, sp, 'laserGreen14', s.x, s.y, 20, {rot: t * 12});
        else if (s.k === 'plasma') {
          ctx.fillStyle = 'rgba(218,119,242,.45)'; ctx.beginPath(); ctx.arc(s.x, s.y, s.w / 2, 0, 7); ctx.fill();
          ctx.fillStyle = '#e599f7'; ctx.beginPath(); ctx.arc(s.x, s.y, s.w * .32, 0, 7); ctx.fill();
          ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(s.x, s.y, s.w * .15, 0, 7); ctx.fill();
        } else if (s.k === 'ice') draw(ctx, 'Snowflake', s.x, s.y, s.w * 1.1, s.w * 1.1, {rot: t * 6});
        else if (s.k === 'vortex') draw(ctx, 'Tornado', s.x, s.y, s.w, s.w, {rot: t * 14});
        else spr(ctx, sp, 'missile', s.x, s.y, 30, {rot: Math.atan2(s.vy, s.vx) + Math.PI / 2});
      }
      // Tia sét: viền xanh to + lõi trắng
      for (const z of zaps) {
        ctx.globalAlpha = Math.min(1, z.life * 8); ctx.lineJoin = 'round';
        for (const [c, lw] of [['#4dabf7', 9], ['#fff', 3]]) {
          ctx.strokeStyle = c; ctx.lineWidth = lw; ctx.beginPath();
          z.line.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.stroke();
        }
        ctx.globalAlpha = 1;
      }
      for (const m of meteors) if (m.y > -60) { spr(ctx, sp, 'meteorBrown_med1', m.x, m.y, m.h, {rot: t * 5}); anim(ctx, sp, 'fireB', t + m.x, m.x + 10, m.y - m.h * .6, m.h * .7, {rot: Math.PI - .15}); }
      for (const o of orbs) spr(ctx, sp, 'laserRed08', o.x, o.y, o.w * 1.4, {rot: t * 8});
      for (const f of foes) {
        const k = LOOK[f.k] || 'enemyGreen1';
        // Nghiêng theo hướng lượn, đĩa bay xoay, thiên thạch lăn; bị trúng thì nháy
        const rot = f.k === 'Comet' ? f.ph * 2 : f.k === 'Flying saucer' ? 0 : Math.max(-.5, Math.min(.5, -(f.vx || 0) / 300 + (f.wave ? Math.cos(f.ph * 2) * .25 : 0) + (f.swoop ? Math.sign(me.x - f.x) * -.25 : 0)));
        if (f.k === 'Flying saucer') spr(ctx, sp, k, f.x, f.y, f.h * (1 + Math.sin(f.ph * 6) * .04), {rot: f.ph * 3, alpha: f.flash > 0 ? .5 : 1});
        else spr(ctx, sp, k, f.x, f.y, f.h * .9, {rot, alpha: f.flash > 0 ? .5 : 1});
        if (f.k !== 'Comet' && f.k !== 'Flying saucer') anim(ctx, sp, 'fireB', t + f.ph, f.x, f.y - f.h * .55, f.h * .3, {rot: Math.PI, alpha: .8});
        if (f.slow > 0) draw(ctx, 'Snowflake', f.x + f.w * .35, f.y - f.h * .35, 22);
      }
      for (const c of coins) coin(ctx, fxs, t + c.x * .01, c.x, c.y, c.w);
      for (const it of items) {
        const bob = Math.sin(t * 4 + it.x) * 4;
        if (it.k === 'gun') {
          gunIcon(ctx, sp, it.gun, it.x, it.y + bob, 26 + Math.sin(t * 8) * 2);
          // Súng chưa có: lấp lánh "MỚI"
          if (!own[it.gun]) { ctx.fillStyle = '#fff'; ctx.font = '800 16px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('MỚI', it.x, it.y + bob - 32); }
        } else if (it.k === 'Shield') spr(ctx, sp, 'powerupBlue_shield', it.x, it.y + bob, 40, {rot: Math.sin(t * 4) * .2});
        else if (it.k === 'Satellite') spr(ctx, sp, 'playerShip3_green', it.x, it.y + bob, 38, {rot: Math.sin(t * 4) * .2});
        else draw(ctx, it.k, it.x, it.y + bob, it.w, it.w, {rot: Math.sin(t * 4) * .2});
      }
      if (boss) {
        const bk = boss.final ? 'boss2' : 'boss1', rage = boss.final && boss.hp < boss.max / 2;
        anim(ctx, sp, 'fireB', t, boss.x - boss.w * .2, boss.y - boss.h * .5, boss.h * .35, {rot: Math.PI});
        anim(ctx, sp, 'fireB', t + .1, boss.x + boss.w * .2, boss.y - boss.h * .5, boss.h * .35, {rot: Math.PI});
        spr(ctx, sp, bk, boss.x + (rage ? Math.sin(t * 40) * 3 : 0), boss.y, boss.h * .8, {rot: Math.sin(boss.ph * 3) * .08 + Math.cos(boss.ph * .9) * -.15, alpha: boss.flash > 0 ? .6 : 1});
      }
      if (!end || end.win) {
        const blink = me.inv > 0 && Math.floor(me.inv * 10) % 2 === 0, gs = me.gs;
        if (!blink) {
          // Lửa động cơ (sprite) + thân nghiêng khi lượn (co ngang)
          anim(ctx, sp, 'fire', t, me.x - me.w * .18 * gs, me.y + me.h * .45 * gs, me.h * .4 * gs * (1 + Math.random() * .2), {rot: Math.PI});
          anim(ctx, sp, 'fire', t + .05, me.x + me.w * .18 * gs, me.y + me.h * .45 * gs, me.h * .4 * gs * (1 + Math.random() * .2), {rot: Math.PI});
          ctx.save(); ctx.translate(me.x, me.y); ctx.rotate(me.bank * .25); ctx.scale(1 - Math.abs(me.bank) * .25, 1);
          spr(ctx, sp, me.giant > 0 ? 'playerShip1_red' : 'playerShip1_blue', 0, 0, me.h * .8 * gs);
          ctx.restore();
          for (let k = 0; k < G.drones; k++) spr(ctx, sp, 'playerShip3_green', me.x + (k ? 1 : -1) * me.w * .9 * gs, me.y + Math.sin(t * 5 + k) * 6, me.w * .4, {rot: me.bank * .3});
        }
        if (me.shield > 0) spr(ctx, sp, 'shield3', me.x, me.y - me.h * .1, me.h * 1.4 * gs, {alpha: .6 + .3 * Math.sin(t * 8)});
        if (me.eshield > 0) { spr(ctx, sp, 'shield3', me.x, me.y - me.h * .1, me.h * 1.9 * gs, {alpha: .5 + .3 * Math.sin(t * 12)}); spr(ctx, sp, 'shield1', me.x, me.y - me.h * .1, me.h * 1.6 * gs, {alpha: .4}); }
        if (me.magnet > 0) draw(ctx, 'Magnet', me.x - me.w * .7, me.y - me.h * .5, 26);
      }
      B.draw(ctx);
      F.draw(ctx);
      ctx.restore();
      if (flash > 0) { ctx.fillStyle = `rgba(255,255,255,${flash})`; ctx.fillRect(0, 0, W, H); }
      // HUD lõi (điểm, đồng hồ, máu trùm); tim tự vẽ vì máu tối đa có thể tới 7
      hud(ctx, W, {score, lives: 0, time: boss ? null : Math.max(0, (midDone ? 60 : 28) - t), boss});
      const hs = narrow ? 22 : 30, hg = narrow ? 25 : 36;
      for (let i = 0; i < maxLives; i++) {
        const row = narrow && i >= 5 ? 1 : 0, j = row ? i - 5 : i;
        draw(ctx, 'Red heart', W - (narrow ? 30 : 40) - j * hg, 32 + row * 28, hs, hs, {alpha: i < lives ? 1 : .22});
      }
      // Thanh súng: các súng đã có, súng đang dùng to + sao; chạm để đổi súng
      const o = owned(), bw = barW();
      ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, gunBar.x, gunBar.y, bw, gunBar.h, 22); ctx.fill();
      o.forEach((g, i) => { const on = g === me.gun; gunIcon(ctx, sp, g, gunBar.x + 24 + i * step(), gunBar.y + gunBar.h / 2, on ? 19 : 14, on ? 1 : .6); });
      const G0 = GUNS[me.gun], ci = o.indexOf(me.gun);
      ctx.font = '800 18px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.5)';
      const st = '★'.repeat(cur[me.gun]) + '☆'.repeat(MAXS - cur[me.gun]), sx = Math.max(gunBar.x + 4, Math.min(W - 110, gunBar.x + 24 + ci * step() - 30));
      ctx.strokeText(st, sx, gunBar.y + gunBar.h + 18); ctx.fillStyle = G0.c; ctx.fillText(st, sx, gunBar.y + gunBar.h + 18);
      if (o.length > 1 && t < 6) { ctx.fillStyle = '#fff'; ctx.textAlign = 'left'; ctx.font = '800 16px "Baloo 2", sans-serif'; ctx.fillText('👆 đổi súng', Math.min(W - 100, gunBar.x + bw + 8), gunBar.y + 28); }
      // Nút bom
      ctx.fillStyle = G.bombs ? 'rgba(255,146,43,.9)' : 'rgba(255,255,255,.35)'; ctx.beginPath(); ctx.arc(bombBtn.x, bombBtn.y, btnR, 0, 7); ctx.fill();
      ctx.strokeStyle = '#fff'; ctx.lineWidth = 4; ctx.stroke();
      draw(ctx, 'Bomb', bombBtn.x, bombBtn.y - 4, btnR * 1.1, btnR * 1.1, {alpha: G.bombs ? 1 : .4});
      ctx.fillStyle = '#fff'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('×' + G.bombs, bombBtn.x + btnR * .6, bombBtn.y + btnR * .8);
      // Nút chiêu: vòng nạp quanh nút, đầy thì sáng và nhún
      for (const b of skBtn) {
        const e = G.en[b.id], full = e >= 1, act = (b.id === 'shield' && me.eshield > 0) || (b.id === 'giant' && me.giant > 0), r = skR * (full ? 1 + Math.sin(t * 6) * .06 : 1);
        ctx.fillStyle = full ? b.c : 'rgba(0,0,0,.4)'; ctx.beginPath(); ctx.arc(b.x, b.y, r, 0, 7); ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,.3)'; ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(b.x, b.y, r - 3, 0, 7); ctx.stroke();
        ctx.strokeStyle = full ? '#fff' : b.c; ctx.beginPath(); ctx.arc(b.x, b.y, r - 3, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (act ? 1 : e)); ctx.stroke();
        draw(ctx, b.f, b.x, b.y, r * 1.15, r * 1.15, {alpha: full || act ? 1 : .45});
      }
      if (t < 2.8) levelBanner(ctx, W, H, lv, 'Hạ trùm cuối', 'Kéo để lái · Nhặt quả cầu súng lên sao · Nút sáng là chiêu mạnh');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT!', `${score} điểm · +${got + end.bonus} xu`);
    }
  }, opts.alive);
}
