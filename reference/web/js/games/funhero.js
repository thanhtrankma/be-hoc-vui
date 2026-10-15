// Siêu nhân diệt quái vật bản nâng cấp: 7 loại chưởng (thường, lửa xuyên, ba tia, băng làm chậm, sấm sét từ trời, bão xoáy hút quái,
// sóng đất), mỗi chưởng 5 cấp; giày tên lửa, khiên, nam châm, siêu chưởng nạp năng lượng; trùm có đòn dậm đất (nhảy qua sóng).
// Kho đồ giữ qua màn (opts.carry): chưởng đã mở + cấp cao nhất, chưởng đang dùng, nâng cấp vĩnh viễn, xu, tên lửa/khiên còn lại, siêu chưởng đã nạp.
// Màn "Kho chưởng" (DOM) trước cấp đầu của lượt: chọn chưởng mang vào, dùng xu mua/nâng cấp.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {h, src} from '../ui.js?v=4c51d34a6e';
import {drawFigure, heroOf} from './figure.js?v=4c51d34a6e';
import {anim, approach, backHills, booms, dust, groundTiles, shaker, sheets, spr, coin} from './funfx.js?v=4c51d34a6e';
import {LIVES, banner, canvasIn, draw, endText, fx, hit, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';

const POWERS = {
  basic: {c: '#ffe066', vi: 'CHƯỞNG', img: 'Collision'},
  fire: {c: '#ff922b', vi: 'CHƯỞNG LỬA', img: 'Fire'},
  triple: {c: '#ffd43b', vi: 'BA TIA', img: 'Glowing star'},
  ice: {c: '#74c0fc', vi: 'CHƯỞNG BĂNG', img: 'Snowflake'},
  thunder: {c: '#fcc419', vi: 'SẤM SÉT', img: 'Cloud with lightning'},
  tornado: {c: '#63e6be', vi: 'BÃO XOÁY', img: 'Tornado'},
  quake: {c: '#d9480f', vi: 'SÓNG ĐẤT', img: 'Volcano'}
};
const PK = Object.keys(POWERS), PMAX = 5;
// Nâng cấp vĩnh viễn ở Kho chưởng (giá tăng theo cấp; chơi 2-4 lượt mua được 1 món)
const UPS = {
  hp: {img: 'Red heart', vi: 'Máu', max: 3, cost: n => 250 * (n + 1)},
  armor: {img: 'Shield', vi: 'Giáp', max: 3, cost: n => 200 * (n + 1)},
  rate: {img: 'Comet', vi: 'Bắn nhanh', max: 4, cost: n => 150 * (n + 1)},
  super: {img: 'High voltage', vi: 'Siêu chưởng', max: 4, cost: n => 150 * (n + 1)},
  dash: {img: 'Running shoe', vi: 'Lướt', max: 1, cost: () => 300},
  jump3: {img: 'Wing', vi: 'Nhảy 3 lần', max: 1, cost: () => 300},
  pound: {img: 'Flexed biceps', vi: 'Đấm đất', max: 1, cost: () => 350}
};
const UNLOCK = 200, lvCost = n => 100 + 60 * (n - 1), ROCKET_COST = 60, STOCK_MAX = 3;
const int = (v, a, b) => Math.max(a, Math.min(b, Math.floor(+v) || 0));

// Đọc kho đồ phòng thủ: thiếu trường thì mặc định; chưởng thường luôn có (sàn 1).
function norm(c) {
  c = c && typeof c === 'object' ? c : {};
  const o = c.own && typeof c.own === 'object' ? c.own : {}, u = c.up && typeof c.up === 'object' ? c.up : {};
  const own = {}, up = {};
  for (const k of PK) own[k] = int(o[k], 0, PMAX);
  own.basic = Math.max(1, own.basic);
  for (const k in UPS) up[k] = int(u[k], 0, UPS[k].max);
  return {v: 1, coins: int(c.coins, 0, 1e7), own, power: own[c.power] > 0 ? c.power : 'basic', up,
    fly: int(c.fly, 0, STOCK_MAX), shield: int(c.shield, 0, STOCK_MAX), charge: Math.max(0, Math.min(1, +c.charge || 0))};
}

// Màn Kho chưởng: chọn chưởng mang vào + mua/nâng cấp bằng xu. Mỗi lần mua lưu ngay.
const CSS = `.hk-wrap{position:absolute;inset:0;z-index:3;overflow:auto;padding:64px 12px 20px;background:linear-gradient(#4263eb,#1c7ed6);font-family:"Baloo 2",sans-serif;color:#fff;text-align:center}
.hk-wrap h2{margin:0 0 4px;font-size:2em;text-shadow:0 3px 0 rgba(0,0,0,.2)}.hk-coins{display:inline-flex;align-items:center;gap:6px;background:rgba(0,0,0,.25);border-radius:30px;padding:2px 18px;font-size:1.8em;font-weight:800}
.hk-coins img{width:38px;height:38px}.hk-sec{font-size:1.15em;font-weight:800;margin:14px 0 6px;opacity:.9}
.hk-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(112px,1fr));gap:10px;max-width:900px;margin:0 auto}
.hk-card{position:relative;background:#fff;color:#23324d;border-radius:22px;padding:8px 4px 8px;box-shadow:0 5px 0 rgba(0,0,0,.18);border:4px solid transparent;display:flex;flex-direction:column;align-items:center;gap:2px}
.hk-card.on{border-color:#ffd43b;background:#fff9db}.hk-card.off img.hk-ic{opacity:.35;filter:grayscale(1)}.hk-card img.hk-ic{width:58px;height:58px}
.hk-card b{font-size:.95em;line-height:1.1}.hk-st{color:#f59f00;font-size:1.05em;letter-spacing:1px;line-height:1}.hk-st i{color:#ced4da;font-style:normal}
.hk-ok{position:absolute;top:-8px;right:-6px;background:#2f9e44;color:#fff;border-radius:50%;width:30px;height:30px;font-size:20px;line-height:30px;font-weight:800}
.hk-buy{display:inline-flex;align-items:center;gap:3px;border:0;border-radius:16px;background:#2f9e44;color:#fff;font:800 1.05em "Baloo 2",sans-serif;padding:2px 10px;margin-top:2px}
.hk-buy img{width:20px;height:20px}.hk-buy[disabled]{background:#adb5bd}.hk-max{font-weight:800;color:#2f9e44}
.hk-play{position:sticky;bottom:8px;z-index:2;margin:18px auto 0;display:block;border:0;border-radius:40px;background:#ffd43b;color:#23324d;font:800 2em "Baloo 2",sans-serif;padding:8px 54px;box-shadow:0 6px 0 #e67700}
.hk-card:active,.hk-play:active{transform:scale(.96)}`;
function armory(box, G, save) {
  return new Promise(resolve => {
    if (!document.getElementById('hk-css')) document.head.append(h('style', {id: 'hk-css'}, CSS));
    const wrap = h('div', {class: 'hk-wrap'});
    const stars = (n, m) => h('span', {class: 'hk-st'}, '★'.repeat(n), h('i', {}, '★'.repeat(Math.max(0, m - n))));
    const buy = (cost, act) => h('button', {class: 'hk-buy', disabled: G.coins < cost, onclick: e => { e.stopPropagation(); if (G.coins < cost) return; G.coins -= cost; act(); sfx('power'); save(); render(); }}, h('img', {src: src('Coin'), alt: ''}), cost);
    const render = () => {
      wrap.replaceChildren(
        h('h2', {}, '🦸 Kho chưởng'),
        h('div', {class: 'hk-coins'}, h('img', {src: src('Coin'), alt: ''}), G.coins),
        h('div', {class: 'hk-sec'}, '👆 Chọn chưởng mang vào'),
        h('div', {class: 'hk-grid'}, PK.map(k => {
          const P = POWERS[k], n = G.own[k];
          return h('div', {class: 'hk-card' + (G.power === k ? ' on' : '') + (n ? '' : ' off'), onclick: () => { if (!n) return; G.power = k; sfx('pop'); save(); render(); }},
            G.power === k ? h('span', {class: 'hk-ok'}, '✔') : null,
            h('img', {class: 'hk-ic', src: src(P.img), alt: ''}), h('b', {}, P.vi), stars(n, PMAX),
            !n ? buy(UNLOCK, () => { G.own[k] = 1; G.power = k; }) : n < PMAX ? buy(lvCost(n), () => { G.own[k] = n + 1; }) : h('span', {class: 'hk-max'}, 'MAX'));
        })),
        h('div', {class: 'hk-sec'}, '💪 Nâng cấp'),
        h('div', {class: 'hk-grid'}, Object.entries(UPS).map(([k, U]) => {
          const n = G.up[k];
          return h('div', {class: 'hk-card' + (n ? '' : ' off')}, h('img', {class: 'hk-ic', src: src(U.img), alt: ''}), h('b', {}, U.vi), stars(n, U.max),
            n < U.max ? buy(U.cost(n), () => { G.up[k] = n + 1; }) : h('span', {class: 'hk-max'}, 'MAX'));
        }), h('div', {class: 'hk-card' + (G.fly ? '' : ' off')}, h('img', {class: 'hk-ic', src: src('Rocket'), alt: ''}), h('b', {}, 'Giày tên lửa'),
          h('span', {class: 'hk-st'}, '🚀'.repeat(G.fly) || '0'), G.fly < STOCK_MAX ? buy(ROCKET_COST, () => { G.fly++; }) : h('span', {class: 'hk-max'}, 'MAX'))),
        h('button', {class: 'hk-play', onclick: () => { sfx('power'); wrap.remove(); resolve(); }}, 'Chơi ▶'));
    };
    render();
    box.append(wrap);
  });
}

export async function hero(box, opts) {
  // Cấp: quái nhanh và dày hơn, trùm nhiều máu và đánh dồn dập hơn; trùm đổi Ogre/Rồng mỗi 10 cấp.
  const lv = opts.level || 0, th = theme(lv), bossK = Math.floor(lv / 10) % 2 ? 'Dragon' : 'Ogre';
  const G = norm(opts.carry);
  const out = () => JSON.parse(JSON.stringify({...G, charge: Math.round(charge * 100) / 100}));
  const save = () => { const c = out(); opts.carry = c; if (opts.saveGear) opts.saveGear(c); };
  let charge = G.charge;
  // Kho chưởng chỉ hiện ở cấp đầu của lượt (opts dùng chung giữa các cấp trong leveled())
  if (!opts.heroArmory) { opts.heroArmory = true; await armory(box, G, save); }
  const FOES = ['Alien monster', 'Ghost', 'Bat', 'Goblin', 'Spider'];
  const [[en, tl, bgs, fxs, fly]] = await Promise.all([sheets(['plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx', 'creatures/flyers']), loadAll([opts.hero, ...FOES, 'Ogre', 'Dragon', th.sun, 'Rock', 'Construction', 'Coin', 'Fire', 'Red heart', 'Cloud', 'Sun with face', 'Glowing star',
    'Snowflake', 'Rocket', 'Shield', 'Magnet', 'High voltage', 'Collision', 'Cloud with lightning', 'Tornado', 'Volcano', 'Running shoe', 'Wing', 'Flexed biceps', 'Comet'])]);
  if (opts.alive && !opts.alive()) return null;
  // Quái là sinh vật Kenney có hoạt ảnh (khoá luật chơi vẫn theo tên cũ)
  const LOOK = {'Alien monster': 'slime', 'Ghost': 'fly', 'Bat': 'bee', 'Goblin': 'sslime', 'Spider': 'ladybug'};
  const D = dust(260), B = booms(fxs), SH = shaker();
  let land = 0, wasAir = false, runDust = 0;
  const {cv, ctx, W, H} = canvasIn(box);
  const ground = H * .8, S = Math.min(W, H), HX = W * .2;
  const me = {x: HX, y: ground, w: S * .17, h: S * .17, vy: 0, jumps: 0, inv: 0, cd: 0, punch: 0, power: G.power, fly: 0, shield: 0, magnet: 0, dash: 0, dashCd: 0, pound: false};
  const shots = [], foes = [], coins = [], fire = [], waves = [], items = [], clouds = [], bolts = [], rings = [], F = fx();
  const city = Array.from({length: 14}, (_, i) => ({x: i * 110, w: rand(70, 110), h: rand(H * .15, H * .4), c: pick(['#a5d8ff', '#bac8ff', '#d0bfff', '#99e9f2'])}));
  for (let i = 0; i < 5; i++) clouds.push({x: rand(0, W), y: rand(20, H * .25), s: rand(70, 120)});
  // Sức mạnh đồ (0..1): quái/trùm tăng máu nhẹ theo đồ để cấp cao vẫn thử thách
  const best = Math.max(...PK.map(k => G.own[k])), ownSum = PK.reduce((a, k) => a + G.own[k], 0) - 1;
  const gp = Math.min(1, (best - 1) / 4 * .5 + ownSum / 34 * .15 + (G.up.hp + G.up.armor + G.up.rate + G.up.super) / 14 * .35);
  const maxLives = LIVES + G.up.hp, cdM = 1 - .08 * G.up.rate, maxJ = G.up.jump3 ? 3 : 2, sup = G.up.super;
  let score = 0, lives = maxLives, armor = G.up.armor, t = 0, spawn = 1.5, boss = null, end = null, endT = 0, scroll = 0, beam = 0, holdUp = false;
  const btnR = Math.min(66, S * .105), sR = btnR * .72;
  const jumpBtn = {x: btnR + 24, y: H - btnR - 20}, shotBtn = {x: W - btnR - 24, y: H - btnR - 20}, superBtn = {x: W - btnR - 24, y: H - btnR * 3.4 - 20};
  const dashBtn = {x: jumpBtn.x, y: jumpBtn.y - btnR * 2.3}, swapBtn = {x: shotBtn.x - btnR * 2.25, y: shotBtn.y};
  const rocketBtn = {x: superBtn.x - btnR * 1.9, y: superBtn.y}, shieldBtn = {x: superBtn.x - btnR * 3.5, y: superBtn.y};
  const owned = () => PK.filter(k => G.own[k] > 0);
  const earn = n => { G.coins += n; };
  const jump = () => {
    if (me.fly > 0) { holdUp = true; return; }
    if (me.jumps < maxJ) { me.vy = -Math.sqrt(2 * 2600 * H * .3) * (me.jumps ? .85 : 1); me.jumps++; me.pound = false; sfx('jump'); }
    // Đấm đất: hết lượt nhảy mà còn trên không thì chạm nhảy để lao xuống
    else if (G.up.pound && !me.pound && me.y < ground - 30) { me.pound = true; me.vy = 2400; sfx('shoot'); }
  };
  const dash = () => { if (!G.up.dash || me.dashCd > 0) return; me.dash = .35; me.dashCd = 1.2; sfx('shoot'); F.text(me.x, me.y - me.h * 1.2, 'LƯỚT!', '#63e6be'); };
  const swap = () => { const o = owned(); if (o.length < 2) return; me.power = o[(o.indexOf(me.power) + 1) % o.length]; G.power = me.power; sfx('pop'); F.text(me.x + me.w, me.y - me.h * 1.2, POWERS[me.power].vi, POWERS[me.power].c); };
  // Đánh một quái (đá thì vỡ luôn); trả về sau khi đã xoá nếu chết
  const hitFoe = (f, dmg, c) => {
    const j = foes.indexOf(f); if (j < 0) return;
    if (f.rock) { D.debris(f.x, f.y, 12, '#868e96', 320); B.add(f.x, f.y, f.w * 1.2, 'smoke'); foes.splice(j, 1); score++; return; }
    f.hp -= dmg;
    if (f.hp <= 0) { kill(f); foes.splice(j, 1); } else { D.sparks(f.x, f.y, 6, c, 200); f.flash = .1; f.x += 14; }
  };
  const shoot = () => {
    if (me.cd > 0 || beam > 0 || shots.length > 36) return;
    me.punch = .18; sfx('shoot');
    const y = me.y - me.h * .55, x = me.x + me.w * .4, p = me.power, L = G.own[p] || 1;
    if (p === 'basic') { me.cd = .28; const n = [1, 2, 2, 3, 3][L - 1], sz = 30 + L * 5; for (let i = 0; i < n; i++) shots.push({x, y: y + (i - (n - 1) / 2) * 26, w: sz, h: sz, vx: 760, vy: 0, dmg: [1, .8, 1, .8, 1][L - 1], k: p}); }
    else if (p === 'fire') { me.cd = .38; const sz = 44 + L * 10; shots.push({x, y, w: sz, h: sz, vx: 620, vy: 0, dmg: 1 + L * .5, k: p, pierce: 2 + L}); }
    else if (p === 'triple') { me.cd = .3; const n = [3, 3, 5, 5, 7][L - 1], sz = 24 + L * 3; for (let i = 0; i < n; i++) shots.push({x, y, w: sz, h: sz, vx: 720, vy: (i - (n - 1) / 2) * (n > 5 ? 110 : 150), dmg: [.5, .6, .6, .7, .7][L - 1], k: p}); }
    else if (p === 'ice') { me.cd = .3; const sz = 32 + L * 6; shots.push({x, y, w: sz, h: sz, vx: 700, vy: 0, dmg: .8 + L * .4, k: p, freeze: 1.5 + L * .5, splash: L >= 4 ? S * (L >= 5 ? .3 : .22) : 0}); }
    else if (p === 'thunder') {
      // Sấm sét đánh từ trời xuống quái gần nhất (cấp cao đánh nhiều quái cùng lúc)
      me.cd = .55; const n = [1, 1, 2, 2, 3][L - 1], dmg = 1.5 + L * .6, bw = 5 + L * 3;
      const tg = foes.filter(f => f.x > me.x && f.x < W + 10).sort((a, b) => a.x - b.x).slice(0, n);
      for (const f of tg) { bolts.push({x: f.x, y: f.y, life: .3, w: bw}); hitFoe(f, dmg, POWERS.thunder.c); }
      if (boss && tg.length < n) { bolts.push({x: boss.x, y: boss.y, life: .3, w: bw}); boss.hp -= dmg; boss.flash = .1; D.sparks(boss.x, boss.y - boss.h * .3, 8, '#fff3bf', 260); }
      if (!tg.length && !boss) bolts.push({x: me.x + W * .35, y: ground, life: .3, w: bw});
      SH.add(2 + L);
      while (bolts.length > 12) bolts.shift();
    }
    else if (p === 'tornado') { me.cd = .7; const sz = 56 + L * 14; shots.push({x, y: ground - sz / 2, w: sz, h: sz, vx: 320, vy: 0, dmg: 1 + L * .5, k: p, sweep: true, pull: S * (.22 + L * .05)}); }
    else { me.cd = .6; const hg = S * (.1 + L * .035); shots.push({x, y: ground - hg / 2, w: 60 + L * 8, h: hg, vx: 650, vy: 0, dmg: 1.2 + L * .5, k: 'quake', sweep: true}); D.debris(x, ground, 6 + L * 2, '#8d5524', 300); SH.add(2 + L); }
    me.cd *= cdM;
  };
  const superMove = () => { if (charge < 1 || beam > 0) return; charge = 0; beam = 1.6 + sup * .4; sfx('win'); SH.add(12 + sup * 2); F.text(W / 2, H * .3, 'SIÊU CHƯỞNG!', '#ffd43b'); };
  const useRocket = () => { if (G.fly < 1 || me.fly > 0) return; G.fly--; me.fly = 8; sfx('power'); F.text(me.x, me.y - me.h * 1.2, 'GIÀY TÊN LỬA!', '#ff922b'); };
  const useShield = () => { if (G.shield < 1 || me.shield > 0) return; G.shield--; me.shield = 10; sfx('power'); F.text(me.x, me.y - me.h * 1.2, 'KHIÊN!', '#74c0fc'); };
  const local = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  const near = (x, y, b, r = btnR) => Math.hypot(x - b.x, y - b.y) < r;
  cv.addEventListener('pointerdown', e => {
    const [x, y] = local(e);
    if (near(x, y, superBtn)) return superMove();
    if (G.up.dash && near(x, y, dashBtn)) return dash();
    if (owned().length > 1 && near(x, y, swapBtn, sR * 1.15)) return swap();
    if (G.fly > 0 && near(x, y, rocketBtn, sR * 1.1)) return useRocket();
    if (G.shield > 0 && near(x, y, shieldBtn, sR * 1.1)) return useShield();
    if (x < W / 2) jump(); else shoot();
  });
  cv.addEventListener('pointerup', () => { holdUp = false; });
  cv.addEventListener('pointercancel', () => { holdUp = false; });

  const drop = (x, y) => {
    coins.push({x, y: y - 10, w: 36, h: 36});
    const r = Math.random();
    if (r < .09) items.push({k: pick(PK), x, y: y - 40, w: 54, h: 54});
    else if (r < .12) items.push({k: 'fly', x, y: y - 40, w: 54, h: 54});
    else if (r < .145) items.push({k: 'shield', x, y: y - 40, w: 54, h: 54});
    else if (r < .165) items.push({k: 'heart', x, y: y - 40, w: 54, h: 54});
    else if (r < .185) items.push({k: 'magnet', x, y: y - 40, w: 54, h: 54});
  };
  const ITEM_IMG = {fly: 'Rocket', shield: 'Shield', heart: 'Red heart', magnet: 'Magnet'};
  for (const k of PK) ITEM_IMG[k] = POWERS[k].img;
  const kill = f => { B.add(f.x, f.y, f.w * 1.4); D.sparks(f.x, f.y, 12, '#ffe066', 300); SH.add(3); F.star(f.x, f.y); sfx('boom'); score += f.pts; F.text(f.x, f.y - 30, '+' + f.pts, '#ffd43b'); charge = Math.min(1, charge + .12 * (1 + sup * .15)); drop(f.x, f.y); };
  const hpM = 1 + gp * .6;
  const makeFoe = () => {
    const sz = S * .14, k = pick(t < 20 ? ['Alien monster', 'Ghost', 'Bat'] : FOES), hp0 = (1 + Math.floor(lv / 20)) * hpM;
    const base = {k, x: W + 80, w: sz, h: sz, v: rand(20, 70) + ramp(lv, 0, 70), ph: rand(0, 6), hp: hp0, pts: 2, slow: 0};
    if (k === 'Bat') return {...base, y: ground - S * .3, pts: 3};
    if (k === 'Ghost') return {...base, y: ground - S * .2, float: true};
    if (k === 'Goblin') return {...base, y: ground - sz / 2, hp: hp0 + hpM, pts: 4};
    if (k === 'Spider') return {...base, y: -sz, drop: true, ty: ground - S * rand(.15, .35), pts: 3};
    return {...base, y: ground - sz / 2};
  };

  return loop({
    update(dt) {
      t += dt; SH.update(dt); D.update(dt); B.update(dt); land = Math.max(0, land - dt);
      for (let i = bolts.length - 1; i >= 0; i--) if ((bolts[i].life -= dt) <= 0) bolts.splice(i, 1);
      for (let i = rings.length - 1; i >= 0; i--) if ((rings[i].life -= dt) <= 0) rings.splice(i, 1);
      if (end) { endT += dt; F.update(dt); if (endT > 2) { G.power = me.power; return {...end, carry: out()}; } return null; }
      const v = boss ? 0 : (230 + t * 1.5) * ramp(lv, 1, 1.35);
      scroll += v * dt;
      // Bay bằng giày tên lửa: giữ nửa trái để bay lên
      if (me.fly > 0) {
        me.fly -= dt;
        me.vy += (holdUp ? -1900 : 900) * dt; me.vy = Math.max(-520, Math.min(420, me.vy));
        if (Math.random() < .8) D.emit(me.x - me.w * .2, me.y - me.h * .2, rand(-40, 0), rand(150, 260), {life: .3, r: 5, grow: 6, c: Math.random() < .5 ? '#ff922b' : '#ffd43b', a: .9});
      } else me.vy += 2600 * dt;
      me.y += me.vy * dt;
      if (me.y < me.h + 40) { me.y = me.h + 40; me.vy = 0; }
      if (me.y >= ground) {
        if (wasAir && me.vy > 300) { land = .18; D.puff(me.x, ground, 6, 'rgba(230,220,200,1)', 90, 7); }
        if (me.pound) {
          // Đấm đất: sóng chấn động hai bên, quái mặt đất gần đó trúng đòn
          me.pound = false; me.inv = Math.max(me.inv, .3); SH.add(12); sfx('boom'); rings.push({x: me.x, life: .45});
          D.debris(me.x, ground, 18, '#8d5524', 420);
          for (const f of [...foes]) if (Math.abs(f.x - me.x) < S * .5 && f.y > ground - S * .32) hitFoe(f, 3, '#ffd43b');
          if (boss && Math.abs(boss.x - me.x) < S * .5 + boss.w / 2) { boss.hp -= 3; boss.flash = .1; }
        }
        me.y = ground; me.vy = 0; me.jumps = 0;
      }
      wasAir = me.y < ground - 2;
      // Lướt: phóng tới trước, chạm quái là hạ, xong thì từ từ về chỗ cũ
      if (me.dash > 0) { me.dash -= dt; me.x = Math.min(W * .55, me.x + 1500 * dt); D.emit(me.x - me.w * .4, me.y - me.h * .5, -300, rand(-30, 30), {life: .3, r: 8, grow: 8, c: 'rgba(99,230,190,1)', a: .6}); }
      else me.x += (HX - me.x) * Math.min(1, dt * 2.5);
      // Bụi chân khi chạy
      runDust -= dt; if (!wasAir && v > 0 && runDust <= 0) { runDust = .12; D.emit(me.x - me.w * .15, ground - 4, -v * .3 + rand(-20, 20), rand(-40, -10), {life: .4, r: 4, grow: 10, c: 'rgba(230,220,200,1)', a: .6}); }
      for (const k of ['inv', 'cd', 'punch', 'shield', 'magnet', 'dashCd']) me[k] = Math.max(0, me[k] - dt);
      // Siêu chưởng: tia lớn quét ngang (nâng cấp: lâu hơn, to hơn, mạnh hơn)
      if (beam > 0) {
        beam -= dt;
        const by = me.y - me.h * .55, bh = S * .22 * (1 + sup * .12);
        for (let j = foes.length - 1; j >= 0; j--) if (foes[j].x > me.x && Math.abs(foes[j].y - by) < bh) { if (foes[j].rock) hitFoe(foes[j], 1, '#fff'); else { kill(foes[j]); foes.splice(j, 1); } }
        if (boss && Math.abs(boss.y - by) < boss.h) { boss.hp -= dt * (7 + sup * 3); boss.flash = .1; }
      }
      if (!boss) {
        spawn -= dt;
        if (spawn <= 0 && t < 55) {
          spawn = Math.max(1, 1.8 - t / 60) * ramp(lv, 1, .68);
          const r = Math.random(), sz = S * .14;
          if (r < .58) foes.push(makeFoe());
          else if (r < .78) foes.push({k: Math.random() < .5 ? 'Rock' : 'Construction', x: W + 80, y: ground - sz * .4, w: sz * .9, h: sz * .8, v: 0, rock: true});
          else { const hgt = rand(.12, .45) * H; for (let c = 0; c < 5; c++) coins.push({x: W + 60 + c * 60, y: ground - hgt - Math.sin(c / 4 * Math.PI) * 50, w: 40, h: 40}); }
        }
        if (t >= 55 && !foes.length) { const hp = Math.round(ramp(lv, 40, 115) * (1 + gp)); boss = {k: bossK, x: W + 200, y: ground - S * .2, w: S * .4, h: S * .4, hp, max: hp, cd: 2, ph: 0, flash: 0, stomp: 5}; sfx('power'); F.text(W / 2, H * .3, 'QUÁI VẬT TRÙM!', '#ff6b6b'); }
      } else {
        boss.ph += dt; boss.flash = Math.max(0, boss.flash - dt);
        boss.x += (W * .78 - boss.x) * Math.min(1, dt * 1.2);
        boss.y = ground - boss.h / 2 - Math.abs(Math.sin(boss.ph * 2)) * 20;
        boss.cd -= dt; boss.stomp -= dt;
        const rage = boss.hp < boss.max / 2;
        if (boss.cd <= 0) { boss.cd = (rage ? rand(1, 1.5) : rand(1.4, 2.2)) * ramp(lv, 1, .65); for (let k = 0; k < (rage ? 2 : 1); k++) fire.push({x: boss.x - boss.w * .3, y: boss.y, vx: -rand(260, 380), vy: -rand(300, 650), w: 46, h: 46}); }
        // Dậm đất: sóng chạy sát đất, bé phải nhảy qua
        if (boss.stomp <= 0) { boss.stomp = (rage ? 3 : 4.5) * ramp(lv, 1, .7); waves.push({x: boss.x - boss.w * .4, y: ground - 18, w: 60, h: 36, v: 380}); SH.add(10); D.debris(boss.x - boss.w * .3, ground, 14, '#8d5524', 360); sfx('boom'); F.text(boss.x, boss.y - boss.h * .6, 'RẦM!', '#ff6b6b'); }
        if (boss.hp <= 0) { for (let k = 0; k < 9; k++) B.add(boss.x + rand(-boss.w * .4, boss.w * .4), boss.y + rand(-boss.h * .4, boss.h * .4), rand(100, 170)); SH.add(16); D.sparks(boss.x, boss.y, 30, '#ffd43b', 420); score += 40; earn(20); F.text(W / 2, H * .38, '+20 XU', '#ffd43b'); sfx('win'); end = {win: true, score}; boss = null; save(); }
      }
      const hurt = () => {
        if (me.inv > 0 || me.dash > 0) return;
        if (me.shield > 0) { me.shield = 0; me.inv = 1; sfx('pop'); return; }
        if (armor > 0) { armor--; me.inv = 1.2; sfx('pop'); SH.add(5); F.text(me.x, me.y - me.h * 1.2, 'GIÁP!', '#74c0fc'); return; }
        lives--; me.inv = 1.8; sfx('hit'); SH.add(9); D.sparks(me.x, me.y - me.h / 2, 14, '#ff8787', 300); me.vy = Math.min(me.vy, -500); me.pound = false;
        if (lives <= 0) end = {win: false, score};
      };
      for (let i = shots.length - 1; i >= 0; i--) {
        const s = shots[i]; s.x += s.vx * dt; s.y += s.vy * dt;
        if (s.x > W + 80 || s.y < -40 || s.y > H + 40) { shots.splice(i, 1); continue; }
        const c = POWERS[s.k].c;
        // Bão xoáy / sóng đất: đi xuyên, mỗi quái trúng một lần; bão hút quái lại gần
        if (s.sweep) {
          s.hitSet = s.hitSet || new Set();
          for (let j = foes.length - 1; j >= 0; j--) {
            const f = foes[j];
            if (s.pull && !f.rock && Math.abs(f.x - s.x) < s.pull && Math.abs(f.y - s.y) < s.pull * 1.4) { f.x += (s.x - f.x) * Math.min(1, dt * 3); if (!f.float) f.y += (s.y - f.y) * Math.min(1, dt * 2); }
            if (s.hitSet.has(f) || !hit(s, f, .85)) continue;
            s.hitSet.add(f); hitFoe(f, s.dmg, c);
          }
          if (boss && hit(s, boss, .8)) {
            if (s.k === 'tornado') { boss.hp -= s.dmg * 1.6 * dt; boss.flash = .08; if (Math.random() < .3) D.sparks(boss.x - boss.w * .3, s.y, 3, c, 200); }
            else if (!s.hitBoss) { s.hitBoss = true; boss.hp -= s.dmg * 1.5; boss.flash = .1; D.debris(boss.x - boss.w * .3, ground, 8, '#8d5524', 300); }
          }
          continue;
        }
        let used = false;
        for (let j = foes.length - 1; j >= 0 && !used; j--) {
          const f = foes[j];
          if (!hit(s, f, .9) || (s.hitSet && s.hitSet.has(f))) continue;
          if (s.pierce) { s.hitSet = s.hitSet || new Set(); s.hitSet.add(f); if (--s.pierce <= 0) used = true; } else used = true;
          if (f.rock) { if (s.k === 'fire') hitFoe(f, 1, c); else D.sparks(s.x, s.y, 6, '#ced4da', 200); continue; }
          if (s.freeze) { f.slow = s.freeze; if (s.splash) for (const o of foes) if (!o.rock && Math.hypot(o.x - f.x, o.y - f.y) < s.splash) o.slow = s.freeze; }
          hitFoe(f, s.dmg, c);
        }
        if (!used && boss && hit(s, boss, .8)) { used = true; boss.hp -= s.dmg; boss.flash = .08; D.sparks(s.x, s.y, 6, c, 220); }
        if (used) shots.splice(i, 1);
      }
      const meBox = {x: me.x, y: me.y - me.h / 2, w: me.w, h: me.h};
      for (let i = foes.length - 1; i >= 0; i--) {
        const f = foes[i]; f.ph += dt; f.slow = Math.max(0, (f.slow || 0) - dt);
        const sp = f.slow > 0 ? .35 : 1;
        f.x -= (v + (f.v || 0)) * dt * (f.rock ? 1 : sp);
        if (f.k === 'Bat') f.y += Math.sin(f.ph * 3) * 60 * dt;
        if (f.float) f.y = ground - S * .2 + Math.sin(f.ph * 2) * S * .08;
        if (f.drop) f.y += (f.ty - f.y) * Math.min(1, dt * 2);
        if (f.x < -120) { foes.splice(i, 1); continue; }
        f.flash = Math.max(0, (f.flash || 0) - dt);
        if (hit(meBox, f, .55)) {
          if (me.dash > 0) { hitFoe(f, 3, '#63e6be'); continue; }
          hurt(); if (!f.rock) { foes.splice(i, 1); B.add(f.x, f.y, f.w * 1.2); }
        }
      }
      for (let i = coins.length - 1; i >= 0; i--) {
        const c = coins[i]; c.x -= v * dt;
        if (me.magnet > 0 && Math.abs(c.x - me.x) < W * .5) { c.x += (me.x - c.x) * Math.min(1, dt * 6); c.y += (me.y - me.h / 2 - c.y) * Math.min(1, dt * 6); }
        if (c.x < -60) { coins.splice(i, 1); continue; }
        if (hit(meBox, c, .9)) { score++; earn(1); sfx('coin'); F.text(c.x, c.y - 20, '+1', '#ffd43b'); D.sparks(c.x, c.y, 5, '#ffe066', 140); coins.splice(i, 1); }
      }
      for (let i = items.length - 1; i >= 0; i--) {
        const it = items[i]; it.x -= v * dt; it.y += Math.sin(t * 3) * 20 * dt;
        if (it.x < -60) { items.splice(i, 1); continue; }
        if (!hit(meBox, it, .9)) continue;
        items.splice(i, 1); sfx('power'); D.sparks(it.x, it.y, 14, '#fff3bf', 260);
        const P = POWERS[it.k];
        if (P) {
          // Nhặt chưởng: chưa có thì mở, có rồi thì lên sao, đã max thì đổi thành xu
          const n = G.own[it.k]; me.power = G.power = it.k;
          if (n >= PMAX) { earn(15); F.text(it.x, it.y - 20, '+15 XU', '#ffd43b'); }
          else { G.own[it.k] = n + 1; F.text(it.x, it.y - 20, (n ? P.vi + ' ' + '★'.repeat(n + 1) : 'MỚI! ' + P.vi), P.c); }
          save();
        }
        else if (it.k === 'fly') { if (me.fly > 0) { G.fly = Math.min(STOCK_MAX, G.fly + 1); F.text(it.x, it.y - 20, '+1 🚀', '#ff922b'); save(); } else { me.fly = 8; F.text(it.x, it.y - 20, 'GIÀY TÊN LỬA!', '#ff922b'); } }
        else if (it.k === 'shield') { if (me.shield > 0) { G.shield = Math.min(STOCK_MAX, G.shield + 1); F.text(it.x, it.y - 20, '+1 KHIÊN', '#74c0fc'); save(); } else { me.shield = 10; F.text(it.x, it.y - 20, 'KHIÊN!', '#74c0fc'); } }
        else if (it.k === 'magnet') { me.magnet = 10; F.text(it.x, it.y - 20, 'NAM CHÂM!', '#ff6b6b'); }
        else { lives = Math.min(maxLives, lives + 1); F.text(it.x, it.y - 20, '+❤', '#ff6b6b'); }
      }
      for (let i = fire.length - 1; i >= 0; i--) { const f = fire[i]; f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 900 * dt; if (f.y > ground + 20 || f.x < -60) { fire.splice(i, 1); continue; } if (Math.random() < .5) D.emit(f.x, f.y, rand(-20, 20), rand(-20, 20), {life: .35, r: 5, grow: 10, c: 'rgba(120,120,120,1)', a: .4}); if (hit(meBox, f, .6)) { hurt(); fire.splice(i, 1); } }
      for (let i = waves.length - 1; i >= 0; i--) { const w = waves[i]; w.x -= w.v * dt; if (Math.random() < .6) D.emit(w.x, ground - 4, rand(40, 120), rand(-160, -60), {life: .5, r: 4, grow: 0, c: '#8d5524', k: 2, g: 800, a: 1}); if (w.x < -80) { waves.splice(i, 1); continue; } if (me.y > ground - 40 && hit(meBox, w, .7)) { hurt(); waves.splice(i, 1); } }
      for (const c of clouds) { c.x -= (v * .1 + 10) * dt; if (c.x < -150) { c.x = W + 150; c.y = rand(20, H * .25); } }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save();
      SH.apply(ctx);
      const sky = ctx.createLinearGradient(0, 0, 0, ground);
      sky.addColorStop(0, boss ? '#845ef7' : th.sky[0]); sky.addColorStop(1, th.sky[1]);
      ctx.fillStyle = sky; ctx.fillRect(-20, -20, W + 40, H + 40);
      draw(ctx, th.sun, W * .85, H * .14, S * .16);
      for (const c of clouds) draw(ctx, 'Cloud', c.x, c.y, c.s, c.s * .6);
      // Nền nhiều lớp: đồi xa chậm, thành phố giữa, mặt đất lát gạch chạy theo tốc độ
      backHills(ctx, bgs, lv, scroll * .12, ground + 8, H * .42, W);
      const span = city.length * 110;
      ctx.globalAlpha = .75;
      for (const b of city) {
        const x = ((b.x - scroll * .3) % span + span) % span - 110;
        ctx.fillStyle = b.c; ctx.fillRect(x, ground - b.h * .7, b.w, b.h * .7);
        ctx.fillStyle = 'rgba(255,255,255,.55)';
        for (let wy = ground - b.h * .7 + 14; wy < ground - 20; wy += 28) for (let wx = x + 12; wx < x + b.w - 18; wx += 26) ctx.fillRect(wx, wy, 12, 14);
      }
      ctx.globalAlpha = 1;
      groundTiles(ctx, tl, lv, scroll, ground - 6, W, H + 20, Math.max(48, S * .08));
      for (const c of coins) coin(ctx, fxs, t + c.x * .01, c.x, c.y, c.w);
      for (const it of items) {
        ctx.fillStyle = 'rgba(255,255,255,.7)'; ctx.beginPath(); ctx.arc(it.x, it.y, it.w * .6, 0, 7); ctx.fill();
        draw(ctx, ITEM_IMG[it.k], it.x, it.y, it.w, it.w, {rot: it.k === 'fly' ? -Math.PI / 4 : Math.sin(t * 4) * .2});
      }
      for (const f of foes) {
        if (f.drop) { ctx.strokeStyle = 'rgba(255,255,255,.8)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(f.x, 0); ctx.lineTo(f.x, f.y - f.h / 2); ctx.stroke(); }
        if (f.rock) { ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(f.x, ground, f.w * .45, 6, 0, 0, 7); ctx.fill(); }
        if (f.rock) { if (f.k === 'Rock') spr(ctx, tl, 'rock', f.x, f.y - f.h * .1, f.h * 1.15); else anim(ctx, en, 'saw', t, f.x, f.y, f.h * 1.1, {rot: -t * 8}); }
        else {
          const sq = 1 + Math.sin(f.ph * 10) * .06;  // nhún khi bò/bay
          ctx.save(); ctx.translate(f.x, f.y + f.h * .45); ctx.scale(1 / sq, sq);
          anim(ctx, en, LOOK[f.k] || 'slime', f.ph, 0, -f.h * .45, f.h, {alpha: f.flash > 0 ? .55 : 1});
          ctx.restore();
        }
        if (f.slow > 0) { ctx.fillStyle = 'rgba(116,192,252,.45)'; ctx.beginPath(); ctx.arc(f.x, f.y, f.w * .6, 0, 7); ctx.fill(); draw(ctx, 'Snowflake', f.x + f.w * .35, f.y - f.h * .4, 22); }
      }
      for (const f of fire) spr(ctx, tl, 'fireball', f.x, f.y, f.h * 1.1, {rot: Math.atan2(f.vy, f.vx) + Math.PI});
      for (const w of waves) { ctx.fillStyle = 'rgba(132,94,247,.75)'; ctx.beginPath(); ctx.ellipse(w.x, w.y, w.w / 2, w.h / 2 + Math.sin(t * 20) * 4, 0, Math.PI, 0); ctx.fill(); draw(ctx, 'Collision', w.x, w.y - 10, 34); }
      if (boss) {
        ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.beginPath(); ctx.ellipse(boss.x, ground, boss.w * .4, 12, 0, 0, 7); ctx.fill();
        const rage = boss.hp < boss.max / 2, jx = rage ? Math.sin(t * 50) * 2 : 0;
        if (boss.k === 'Dragon') anim(ctx, fly, 'dragon', t, boss.x + jx, boss.y - boss.h * .1 + Math.sin(boss.ph * 3) * 10, boss.h * .85, {flip: true, alpha: boss.flash > 0 ? .6 : 1});
        else {
          // Quái vật trùm: slime khối khổng lồ nhún theo nhịp nhảy
          const hop = Math.abs(Math.sin(boss.ph * 2)), sq = 1 + (1 - hop) * .12;
          ctx.save(); ctx.translate(boss.x + jx, ground); ctx.scale(sq, 1 / sq);
          anim(ctx, en, rage ? 'fslime' : 'bslime', boss.ph, 0, -boss.h * .5 - hop * 20, boss.h, {alpha: boss.flash > 0 ? .6 : 1});
          ctx.restore();
        }
      }
      for (const s of shots) {
        const c = POWERS[s.k].c;
        if (s.k === 'tornado') {
          // Bão xoáy: vòng gió + hình lốc xoáy lắc lư (không gradient)
          ctx.globalAlpha = .35; ctx.fillStyle = c; ctx.beginPath(); ctx.ellipse(s.x, s.y + s.h * .1, s.w * .62, s.h * .55, 0, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
          draw(ctx, 'Tornado', s.x + Math.sin(t * 18) * 4, s.y, s.w * 1.1, s.h * 1.1, {flip: Math.floor(t * 8) % 2 === 0});
          continue;
        }
        if (s.k === 'quake') {
          ctx.fillStyle = 'rgba(141,85,36,.85)'; ctx.beginPath(); ctx.ellipse(s.x, ground, s.w / 2, s.h, 0, Math.PI, 0); ctx.fill();
          ctx.fillStyle = c; ctx.beginPath(); ctx.ellipse(s.x, ground, s.w * .3, s.h * .7, 0, Math.PI, 0); ctx.fill();
          spr(ctx, tl, 'rock', s.x - s.w * .2, ground - s.h * .95, s.h * .45); spr(ctx, tl, 'rock', s.x + s.w * .15, ground - s.h * .75, s.h * .35);
          continue;
        }
        const g = ctx.createRadialGradient(s.x, s.y, 2, s.x, s.y, s.w * .65);
        g.addColorStop(0, '#fff'); g.addColorStop(.4, c); g.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(s.x, s.y, s.w * .65, 0, 7); ctx.fill();
        if (s.k === 'fire') draw(ctx, 'Fire', s.x, s.y, s.w * .8, s.w * .8, {rot: Math.PI / 2});
        if (s.k === 'ice') draw(ctx, 'Snowflake', s.x, s.y, s.w * .7, s.w * .7, {rot: t * 8});
        if (s.k === 'basic' && s.w > 50) draw(ctx, 'Collision', s.x, s.y, s.w * .6);
      }
      // Sấm sét: tia zíc zắc từ mây xuống quái
      for (const b of bolts) {
        ctx.globalAlpha = Math.min(1, b.life * 5);
        draw(ctx, 'Cloud with lightning', b.x, 120, 70);
        ctx.strokeStyle = '#fcc419'; ctx.lineWidth = b.w; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(b.x, 140);
        const n = 6; for (let k = 1; k <= n; k++) ctx.lineTo(b.x + (k < n ? (k % 2 ? 1 : -1) * (14 + b.w) : 0), 140 + (b.y - 140) * k / n);
        ctx.stroke(); ctx.strokeStyle = '#fff'; ctx.lineWidth = b.w * .35; ctx.stroke();
        ctx.globalAlpha = 1;
      }
      // Vòng chấn động của đấm đất
      for (const r of rings) { const k = 1 - r.life / .45; ctx.strokeStyle = `rgba(255,212,59,${1 - k})`; ctx.lineWidth = 8; ctx.beginPath(); ctx.ellipse(r.x, ground, S * .5 * k + 20, 24 * (1 - k) + 6, 0, 0, 7); ctx.stroke(); }
      // Siêu chưởng
      if (beam > 0) {
        const by = me.y - me.h * .55, th = S * .18 * (1 + sup * .12) * (.7 + .3 * Math.sin(t * 40));
        const g = ctx.createLinearGradient(0, by - th, 0, by + th);
        const ec = sup >= 3 ? 'rgba(255,107,107,0)' : 'rgba(255,212,59,0)';
        g.addColorStop(0, ec); g.addColorStop(.5, 'rgba(255,255,255,.95)'); g.addColorStop(1, sup >= 2 ? 'rgba(116,192,252,0)' : ec);
        ctx.fillStyle = g; ctx.fillRect(me.x + me.w * .3, by - th, W, th * 2);
      }
      const blink = me.inv > 0 && me.dash <= 0 && Math.floor(me.inv * 10) % 2 === 0;
      if (!blink) {
        ctx.fillStyle = 'rgba(0,0,0,.15)'; ctx.beginPath(); ctx.ellipse(me.x, ground + 4, me.w * .4, 8, 0, 0, 7); ctx.fill();
        if (me.fly > 0) { draw(ctx, 'Rocket', me.x - me.w * .25, me.y - me.h * .2, me.w * .45, me.w * .45, {rot: Math.PI * .75}); }
        // Bé mặc trang phục theo linh vật, luôn có áo choàng siêu nhân
        const cos = heroOf(opts.hero); cos.cape = cos.cape || '#e03131';
        // Nhún khi tiếp đất, nghiêng nhẹ theo vận tốc rơi
        const sq = land > 0 ? 1 - Math.sin(land / .18 * Math.PI) * .12 : 1;
        ctx.save(); ctx.translate(me.x, me.y); ctx.scale(2 - sq, sq); ctx.rotate(me.dash > 0 ? .25 : Math.max(-.15, Math.min(.15, me.vy / 4000))); ctx.translate(-me.x, -me.y);
        drawFigure(ctx, me.x, me.y, me.h * 1.25, {c: cos, pose: me.punch > 0 || me.dash > 0 ? 'punch' : me.y < ground - 2 ? 'jump' : 'run', act: me.punch > 0 ? 1 - me.punch / .18 : 0, t, face: 1});
        ctx.restore();
        if (me.pound) draw(ctx, 'Flexed biceps', me.x, me.y + 10, me.w * .5);
        if (me.shield > 0) { ctx.strokeStyle = 'rgba(116,192,252,.85)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(me.x, me.y - me.h / 2, me.w * .75, 0, 7); ctx.stroke(); }
      }
      D.draw(ctx); B.draw(ctx);
      F.draw(ctx);
      ctx.restore();
      // Nút bấm lớn
      const btn = (b, r, on, fill = 'rgba(255,255,255,.75)') => { ctx.fillStyle = fill; ctx.globalAlpha = on ? 1 : .5; ctx.beginPath(); ctx.arc(b.x, b.y, r, 0, 7); ctx.fill(); ctx.globalAlpha = 1; };
      for (const [b, label] of [[jumpBtn, me.fly > 0 ? '🚀' : '⬆'], [shotBtn, '💥']]) {
        btn(b, btnR, true);
        ctx.font = `${btnR * .9}px sans-serif`; ctx.textAlign = 'center'; ctx.fillStyle = '#23324d'; ctx.fillText(label, b.x, b.y + btnR * .32);
      }
      if (G.up.dash) { btn(dashBtn, btnR * .85, me.dashCd <= 0); draw(ctx, 'Running shoe', dashBtn.x, dashBtn.y, btnR, btnR, {alpha: me.dashCd > 0 ? .4 : 1}); }
      // Nút đổi chưởng: hình chưởng đang dùng + sao + mũi tên vòng
      const own = owned();
      if (own.length > 1) {
        btn(swapBtn, sR, true, 'rgba(255,255,255,.85)');
        ctx.strokeStyle = POWERS[me.power].c; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(swapBtn.x, swapBtn.y, sR, 0, 7); ctx.stroke();
        draw(ctx, POWERS[me.power].img, swapBtn.x, swapBtn.y - 4, sR * 1.2);
        ctx.font = `800 ${Math.round(sR * .34)}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.fillStyle = '#f59f00'; ctx.fillText('★'.repeat(G.own[me.power]), swapBtn.x, swapBtn.y + sR * .78);
        ctx.font = `${Math.round(sR * .5)}px sans-serif`; ctx.fillText('🔄', swapBtn.x + sR * .8, swapBtn.y - sR * .6);
      }
      if (G.fly > 0) { btn(rocketBtn, sR, me.fly <= 0); draw(ctx, 'Rocket', rocketBtn.x, rocketBtn.y, sR * 1.2, sR * 1.2, {alpha: me.fly > 0 ? .4 : 1}); ctx.font = `800 ${Math.round(sR * .55)}px "Baloo 2", sans-serif`; ctx.fillStyle = '#e8590c'; ctx.textAlign = 'center'; ctx.fillText('×' + G.fly, rocketBtn.x + sR * .6, rocketBtn.y + sR * .95); }
      if (G.shield > 0) { btn(shieldBtn, sR, me.shield <= 0); draw(ctx, 'Shield', shieldBtn.x, shieldBtn.y, sR * 1.2, sR * 1.2, {alpha: me.shield > 0 ? .4 : 1}); ctx.font = `800 ${Math.round(sR * .55)}px "Baloo 2", sans-serif`; ctx.fillStyle = '#1c7ed6'; ctx.textAlign = 'center'; ctx.fillText('×' + G.shield, shieldBtn.x + sR * .6, shieldBtn.y + sR * .95); }
      // Nút siêu chưởng: vòng nạp năng lượng
      ctx.fillStyle = charge >= 1 ? `rgba(255,212,59,${.8 + .2 * Math.sin(t * 10)})` : 'rgba(255,255,255,.5)';
      ctx.beginPath(); ctx.arc(superBtn.x, superBtn.y, btnR * .85, 0, 7); ctx.fill();
      ctx.strokeStyle = '#ff922b'; ctx.lineWidth = 7; ctx.beginPath(); ctx.arc(superBtn.x, superBtn.y, btnR * .85, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * charge); ctx.stroke();
      draw(ctx, 'High voltage', superBtn.x, superBtn.y, btnR, btnR, {alpha: charge >= 1 ? 1 : .45});
      if (sup) { ctx.font = `800 ${Math.round(btnR * .3)}px "Baloo 2", sans-serif`; ctx.fillStyle = '#f59f00'; ctx.textAlign = 'center'; ctx.fillText('★'.repeat(sup), superBtn.x, superBtn.y + btnR * 1.1); }
      // HUD: lõi vẽ điểm/đồng hồ/máu trùm; tim tự vẽ vì máu tối đa có thể hơn 5
      hud(ctx, W, {score, lives: 0, time: boss ? null : Math.max(0, 55 - t), boss});
      const narrow = W < 520, hs = narrow ? 22 : 30, hg = narrow ? 25 : 36;
      for (let i = 0; i < maxLives; i++) { const row = narrow && i >= 5 ? 1 : 0, col = row ? i - 5 : i; draw(ctx, 'Red heart', W - (narrow ? 30 : 40) - col * hg, 32 + row * 26, hs, hs, {alpha: i < lives ? 1 : .22}); }
      const P = POWERS[me.power], py = narrow && boss ? 88 : 62;
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, 72, py, 232, 36, 18); ctx.fill();
      draw(ctx, P.img, 92, py + 18, 28);
      ctx.fillStyle = P.c; ctx.font = '800 19px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.fillText(`${P.vi} ${'★'.repeat(G.own[me.power])}`, 110, py + 25);
      let ix = 86;
      for (let i = 0; i < armor; i++, ix += 30) draw(ctx, 'Shield', ix, py + 56, 26);
      if (me.fly > 0) { ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, ix - 12, py + 42, 130, 28, 14); ctx.fill(); ctx.fillStyle = '#ff922b'; roundRect(ctx, ix - 4, py + 51, 114 * me.fly / 8, 10, 5); ctx.fill(); }
      // Đầu màn: dải chưởng đã có (bé thấy đồ mang theo)
      if (t < 3.6) {
        const n = own.length, sz = Math.min(52, (W - 40) / n - 8), x0 = W / 2 - (n * (sz + 8) - 8) / 2 + sz / 2, y0 = H / 2 + 124;
        ctx.fillStyle = 'rgba(0,0,0,.4)'; roundRect(ctx, x0 - sz / 2 - 10, y0 - sz / 2 - 8, n * (sz + 8) + 12, sz + 34, 16); ctx.fill();
        own.forEach((k, i) => {
          const x = x0 + i * (sz + 8);
          if (k === me.power) { ctx.strokeStyle = '#ffd43b'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(x, y0, sz * .58, 0, 7); ctx.stroke(); }
          draw(ctx, POWERS[k].img, x, y0, sz * .85);
          ctx.font = `800 ${Math.max(10, Math.round(sz * .26))}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.fillStyle = '#ffd43b'; ctx.fillText('★'.repeat(G.own[k]), x, y0 + sz * .5 + 14);
        });
      }
      if (t < 2.8) levelBanner(ctx, W, H, lv, `Hạ ${bossK === 'Dragon' ? 'rồng' : 'quái vật'} trùm`, 'Trái: nhảy (giữ để bay) · Phải: bắn chưởng · ⚡ siêu chưởng');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT!', `${score} điểm`);
    }
  }, opts.alive);
}
