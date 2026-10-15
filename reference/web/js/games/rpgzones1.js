// Thế giới phiêu lưu: 5 vùng kiểu đấu trường (động cơ arena trong rpgcore.js).
// Vùng 1 Rừng Xanh, 2 Biển Ngọc, 6 Thành Mây, 9 Đầm Lầy Ma, 10 Lâu Đài Rồng.
import {arena, dist, draw, foeStats, pick, rand, roundRect, sfx, spr, sprA, strike} from './rpgcore.js?v=4c51d34a6e';
import {prerender} from './motionb.js?v=4c51d34a6e';
import {COSTUMES, drawFigure} from './figure.js?v=4c51d34a6e';

const NEED = Z => Z.boss ? 1 : 6 + Z.s * 2;
// Sinh quái dần: tối đa `live` con cùng lúc, tổng `need` con.
function spawner(G, need, live, every, make) {
  const d = G.data; d.spawned = d.spawned || 0; d.spT = (d.spT ?? .5) - G.dt;
  if (d.spawned < need && G.foes.length < live && d.spT <= 0) { d.spT = every; d.spawned++; make(); }
}
const withDt = fn => (G, dt) => { G.dt = dt; fn(G, dt); };
const killsGoal = G => G.Z.boss ? null : `⚔️ ${Math.min(G.kills, NEED(G.Z))}/${NEED(G.Z)}`;
// Nền lát ô (Kenney Tiny Town / Tiny Dungeon, pixel) vẽ sẵn một lần. base: các ô nền (ô đầu nhiều nhất),
// deco: [[ô, số lượng, cỡ]] rải ngẫu nhiên (tránh dải HUD trên cùng). Trả null nếu chưa có sprite.
export function tileBg(G, sheet, base, deco = [], {ts = null, top = null} = {}) {
  const T = G.SP?.[sheet]; if (!T || !T.img.naturalWidth) return null;
  if (G.data.bgc) return G.data.bgc;
  const size = ts || Math.max(32, Math.round(G.S / 13 / 8) * 8);
  G.data.bgc = prerender(G.W, G.H, g => {
    g.imageSmoothingEnabled = false;
    let seed = 7; const rnd = () => { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; };
    for (let y = 0; y < G.H; y += size) for (let x = 0; x < G.W; x += size) {
      const fr = rnd() < .8 ? base[0] : base[1 + Math.floor(rnd() * (base.length - 1))] || base[0];
      const f = T.frames[fr]; g.drawImage(T.img, f[0], f[1], f[2], f[3], x, y, size, size);
    }
    if (top) for (let x = 0; x < G.W; x += size) { const f = T.frames[top[Math.floor(rnd() * top.length)]]; g.drawImage(T.img, f[0], f[1], f[2], f[3], x, 56, size, size); }
    const items = [];
    for (const [fr, n, k] of deco) for (let i = 0; i < n; i++) items.push([fr, rnd() * G.W, 110 + rnd() * (G.H - 130), k]);
    items.sort((a, b) => a[2] - b[2]);
    for (const [fr, x, y, k] of items) { const f = T.frames[fr]; const s = size * k; g.drawImage(T.img, f[0], f[1], f[2], f[3], x - s / 2, y - s, s, s); }
  });
  return G.data.bgc;
}
const sceneDeco = (G, imgs, n) => { if (!G.data.deco) G.data.deco = Array.from({length: n}, () => ({img: pick(imgs), x: rand(0, G.W), y: rand(90, G.H), s: rand(.8, 1.3)})).sort((a, b) => a.y - b.y); return G.data.deco; };

// Quái đuổi theo bé
const chase = (f, G, dt) => { const h = G.hero, a = Math.atan2(h.y - f.y, h.x - f.x); f.x += Math.cos(a) * f.spd * dt; f.y += Math.sin(a) * f.spd * dt; f.flip = h.x > f.x; };
// Lao tới: đứng nhắm rồi lao thẳng
const charger = (f, G, dt) => {
  f.ph = f.ph || 'walk'; f.pt = (f.pt || 0) + dt; f.wind = f.ph === 'aim' ? f.pt / .5 : 0;
  if (f.ph === 'walk') { chase(f, G, dt * .6); if (f.pt > 2.2) { f.ph = 'aim'; f.pt = 0; } }
  else if (f.ph === 'aim') { if (f.pt > .5) { f.ph = 'dash'; f.pt = 0; const a = Math.atan2(G.hero.y - f.y, G.hero.x - f.x); f.dx = Math.cos(a); f.dy = Math.sin(a); } }
  else { f.x += f.dx * f.spd * 3 * dt; f.y += f.dy * f.spd * 3 * dt; f.x = Math.max(20, Math.min(G.W - 20, f.x)); f.y = Math.max(80, Math.min(G.H - 20, f.y)); if (f.pt > .6) { f.ph = 'walk'; f.pt = 0; } }
};

// ---------- 1. Rừng Xanh: chém yêu tinh, heo rừng, nhện; trùm Quỷ Đá ----------
export const forest = (box, Z) => arena(box, Z, {
  name: 'Rừng Xanh', goalText: Z.boss ? 'Đánh bại Quỷ Đá' : `Đánh bại ${NEED(Z)} con quái`,
  hint: 'Kéo bên trái để đi · bấm ⚔️ để chém · ✨ chiêu xoáy',
  imgs: ['Goblin', 'Boar', 'Spider', 'Troll', 'Deciduous tree', 'Evergreen tree', 'Mushroom', 'Herb', 'Sunflower', 'Rock'],
  bg(ctx, G) {
    const bgc = tileBg(G, 'kenney-tiny-town/town', ['t0', 't1', 't2', 't1'], [['t16', 5, 1.6], ['t28', 4, 1.4], ['t5', 4, 1.1], ['t15', 2, 1.6], ['t27', 2, 1.4], ['t29', 4, .8], ['t17', 4, .8]]);
    if (bgc) { ctx.drawImage(bgc, 0, 0, G.W, G.H); return; }
    const g = ctx.createLinearGradient(0, 0, 0, G.H); g.addColorStop(0, '#b2f2bb'); g.addColorStop(1, '#69db7c');
    ctx.fillStyle = g; ctx.fillRect(0, 0, G.W, G.H);
    ctx.fillStyle = 'rgba(255,255,255,.18)'; for (let i = 0; i < 18; i++) { ctx.beginPath(); ctx.ellipse((i * 137) % G.W, 90 + (i * 89) % (G.H - 90), 40, 14, 0, 0, 7); ctx.fill(); }
    for (const d of sceneDeco(G, ['Deciduous tree', 'Evergreen tree', 'Mushroom', 'Herb', 'Sunflower', 'Rock'], 12)) draw(ctx, d.img, d.x, d.y, G.S * .09 * d.s);
  },
  start(G) {
    if (Z.boss) {
      const s = foeStats(0, 5, 10);
      G.add({img: 'Troll', name: 'Quỷ Đá', boss: true, x: G.W * .8, y: G.H * .45, size: G.S * .3, spd: G.S * .1, ...s,
        ai(f, G, dt) { chase(f, G, dt); if (f.cd <= 0) { f.cd = 2.6; G.tele({x: G.hero.x, y: G.hero.y, r: G.S * .14, dmg: f.dmg * 1.4}); if (f.hp < f.max * .6 && G.foes.length < 4) G.add({img: 'Spider', sheet: 'kenney-platformer/enemies', anim: 'slime_spike', x: f.x, y: f.y, size: G.S * .08, spd: G.S * .25, ...foeStats(0, 2), gold: .5, ai: chase}); } }});
    }
  },
  tick: withDt((G) => {
    if (Z.boss) return;
    spawner(G, NEED(Z), 2 + Math.floor(Z.s / 2), 1.4, () => {
      const k = pick(Z.s >= 2 ? ['Goblin', 'Spider', 'Boar'] : ['Goblin', 'Spider']);
      const s = foeStats(0, Z.s, k === 'Spider' ? .6 : k === 'Boar' ? 1.3 : 1);
      // Nhện thường đổi thành chú nhớt xanh (sprite Kenney có khung đi), yêu tinh + heo rừng giữ hình
      G.edge({img: k, ...(k === 'Spider' ? {sheet: 'kenney-platformer/enemies', anim: 'slime_normal'} : {}), size: G.S * (k === 'Spider' ? .09 : .11), spd: G.S * (k === 'Spider' ? .26 : .16), ...s, ai: k === 'Boar' ? charger : chase});
    });
  }),
  done: G => Z.boss ? G.foes.every(f => !f.boss) : G.kills >= NEED(Z),
  goal: killsGoal
});

// ---------- 2. Biển Ngọc: lái thuyền, đại bác tự bắn; trùm Mực Khổng Lồ ----------
export const sea = (box, Z) => arena(box, Z, {
  name: 'Biển Ngọc', goalText: Z.boss ? 'Đánh chìm Mực Khổng Lồ' : `Bắn chìm ${NEED(Z)} kẻ địch`,
  hint: 'Kéo bên trái để lái thuyền · đại bác tự bắn · né đạn nhé',
  imgs: ['Sailboat', 'Shark', 'Octopus', 'Ship', 'Pirate flag', 'Squid', 'Bomb', 'Droplet', 'Desert island', 'Spiral shell', 'Water wave'],
  melee: false, mount: 'Sailboat', mountSpr: {sheet: 'kenney-pirate/ships', frame: 'ship5'}, autoFire: {rate: .55, img: 'Bomb', speed: 1.2, mul: .9, size: .045},
  bounds: G => ({x0: 40, x1: G.W - 40, y0: G.H * .35, y1: G.H - 50}),
  start(G) {
    G.hero.y = G.H * .78;
    if (Z.boss) {
      const s = foeStats(1, 5, 10);
      G.add({img: 'Squid', name: 'Mực Khổng Lồ', boss: true, x: G.W / 2, y: G.H * .22, size: G.S * .3, noTouch: true, ...s, shoot: {rate: 1.6, img: 'Droplet', speed: .45},
        ai(f, G, dt) { f.x = G.W / 2 + Math.sin(f.t * .7) * G.W * .3; if (f.t % 4 < dt) { const w = G.W / 5, c = Math.floor(G.hero.x / w); G.tele({x: (c + .5) * w, y: G.H * .66, w, h: G.H * .68, dmg: f.dmg * 1.3, t: 1.4}); } }});
    }
  },
  bg(ctx, G) {
    const g = ctx.createLinearGradient(0, 0, 0, G.H); g.addColorStop(0, '#1971c2'); g.addColorStop(1, '#4dabf7');
    ctx.fillStyle = g; ctx.fillRect(0, 0, G.W, G.H);
    const wt = G.SP?.['kenney-pirate/tiles'];
    if (wt?.img.naturalWidth) { if (!G.data.wpat) { const c = document.createElement('canvas'), f = wt.frames.tile_73; c.width = c.height = 96; c.getContext('2d').drawImage(wt.img, f[0], f[1], f[2], f[3], 0, 0, 96, 96); G.data.wpat = ctx.createPattern(c, 'repeat'); }
      ctx.save(); ctx.globalAlpha = .55; ctx.translate(0, (G.t * 30) % 96); ctx.fillStyle = G.data.wpat; ctx.fillRect(0, -96, G.W, G.H + 96); ctx.restore(); }
    ctx.strokeStyle = 'rgba(255,255,255,.3)'; ctx.lineWidth = 3;
    for (let i = 0; i < 14; i++) { const y = ((i * 70 + G.t * 60) % (G.H + 70)) - 35, x = (i * 173) % G.W; ctx.beginPath(); ctx.arc(x, y, 18, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke(); }
    for (let i = 0; i < 3; i++) draw(ctx, i % 2 ? 'Desert island' : 'Spiral shell', ((i * 311) % G.W), ((i * 260 + G.t * 40) % (G.H + 200)) - 100, G.S * (i % 2 ? .14 : .06));
  },
  tick: withDt((G) => {
    if (Z.boss) { if (G.foes.length < 3 && G.t % 5 < G.dt) G.edge({side: 0, img: 'Shark', size: G.S * .1, spd: G.S * .2, ...foeStats(1, 2), gold: .5, ai: (f, G, dt) => { f.y += f.spd * dt; f.x += Math.sin(f.t * 3) * 60 * dt; }}); return; }
    spawner(G, NEED(Z), 3 + Math.floor(Z.s / 2), 1.2, () => {
      const k = pick(Z.s >= 1 ? ['Shark', 'Octopus', 'Ship'] : ['Shark', 'Octopus']);
      const s = foeStats(1, Z.s, k === 'Ship' ? 1.6 : 1);
      if (k === 'Shark') G.edge({side: 0, img: k, size: G.S * .11, spd: G.S * .18, ...s, flip: false, fly: true, ai: (f, G, dt) => { f.y += f.spd * dt; f.x += Math.sin(f.t * 2.5) * G.S * .2 * dt; if (f.y > G.H + 30) { f.y = -30; } }});
      else G.edge({side: 0, img: k, size: G.S * (k === 'Ship' ? .14 : .1), spd: G.S * .07, ...s, noTouch: k === 'Ship', fly: true,
        // Tàu cướp biển: sprite Kenney nhìn từ trên, mũi hướng xuống, lắc theo sóng
        drawFn: k === 'Ship' ? (ctx, f, G) => { const a = Math.PI + Math.sin(f.t * 1.5) * .12; if (!spr(ctx, G.SP['kenney-pirate/ships'], 'ship14', f.x, f.y, f.size * 1.5, {rot: a, alpha: f.hurt > 0 ? .6 : 1})) draw(ctx, 'Ship', f.x, f.y, f.size); if (f.hp < f.max) { ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.fillRect(f.x - f.size * .35, f.y - f.size * .8, f.size * .7, 7); ctx.fillStyle = '#ff6b6b'; ctx.fillRect(f.x - f.size * .35, f.y - f.size * .8, f.size * .7 * f.hp / f.max, 7); } if (f.atkT > .2) sprA(ctx, G.SP['kenney-pirate/ships'], 'explode', .35 - f.atkT, f.x, f.y + f.size * .6, f.size * .5); } : null, shoot: {rate: k === 'Ship' ? 2.2 : 2.8, img: k === 'Ship' ? 'Bomb' : 'Droplet', speed: .42},
        ai: (f, G, dt) => { if (f.y < G.H * .3) f.y += f.spd * dt * 2; f.x += Math.sin(f.t + f.max) * G.S * .15 * dt; f.flip = false; }});
    });
  }),
  done: G => Z.boss ? G.foes.every(f => !f.boss) : G.kills >= NEED(Z),
  goal: killsGoal
});

// ---------- 6. Thành Mây: cưỡi đại bàng bay, tự bắn sao chổi; trùm Mây Sấm ----------
export const sky = (box, Z) => arena(box, Z, {
  name: 'Thành Mây', goalText: Z.boss ? 'Đánh tan Mây Sấm' : `Hạ ${NEED(Z)} kẻ địch trên trời`,
  hint: 'Kéo bên trái để bay · đại bàng tự bắn về phía trước',
  imgs: ['Eagle', 'Comet', 'Bat', 'Cloud with lightning', 'Tornado', 'High voltage', 'Cloud', 'Rainbow', 'Classical building', 'Owl'],
  melee: false, mount: 'Eagle', autoFire: {rate: .32, img: 'Comet', dir: 'right', speed: 1.6, mul: .6, size: .055},
  bounds: G => ({x0: 50, x1: G.W * .55, y0: 90, y1: G.H - 60}),
  start(G) {
    G.hero.x = G.W * .2; G.hero.y = G.H * .5;
    if (Z.boss) {
      const s = foeStats(5, 5, 10);
      G.add({img: 'Cloud with lightning', name: 'Mây Sấm', boss: true, fly: true, x: G.W * .82, y: G.H * .5, size: G.S * .32, noTouch: true, flip: false, ...s, shoot: {rate: 1.4, img: 'High voltage', speed: .5},
        ai(f, G, dt) { f.y = G.H * .5 + Math.sin(f.t * .8) * G.H * .28; if (f.t % 3.5 < dt) { const w = G.W * .12; G.tele({x: Math.min(G.W * .5, Math.max(w, G.hero.x)), y: G.H / 2 + 35, w, h: G.H - 70, dmg: f.dmg * 1.3, t: 1.3}); } }});
    }
  },
  bg(ctx, G) {
    const g = ctx.createLinearGradient(0, 0, 0, G.H); g.addColorStop(0, '#91a7ff'); g.addColorStop(1, '#e5dbff');
    ctx.fillStyle = g; ctx.fillRect(0, 0, G.W, G.H);
    draw(ctx, 'Rainbow', G.W * .7, G.H * .3, G.S * .5, G.S * .5, {alpha: .4});
    for (let i = 0; i < 8; i++) { const x = G.W - ((i * 190 + G.t * (40 + i * 12)) % (G.W + 240)) + 120; draw(ctx, 'Cloud', x, 100 + (i * 97) % (G.H - 120), G.S * (.12 + (i % 3) * .05), G.S * (.08 + (i % 3) * .03), {alpha: .85}); }
    draw(ctx, 'Classical building', G.W - ((G.t * 25) % (G.W + 300)) + 150, G.H - G.S * .08, G.S * .18);
  },
  tick: withDt((G) => {
    if (Z.boss) { if (G.foes.length < 4 && G.t % 3 < G.dt) G.edge({side: 1, img: 'Bat', sheet: 'kenney-platformer/enemies', anim: 'bee', fly: true, size: G.S * .08, spd: G.S * .25, ...foeStats(5, 2), gold: .5, flip: false, ai: (f, G, dt) => { f.x -= f.spd * dt; f.y += Math.sin(f.t * 4) * 120 * dt; }}); return; }
    spawner(G, NEED(Z), 3 + Math.floor(Z.s / 2), 1.1, () => {
      const k = pick(Z.s >= 2 ? ['Bat', 'Owl', 'Cloud with lightning', 'Tornado'] : ['Bat', 'Owl', 'Cloud with lightning']);
      const s = foeStats(5, Z.s, k === 'Tornado' ? 1.8 : k === 'Bat' ? .7 : 1);
      G.edge({side: 1, img: k, ...(k === 'Bat' ? {sheet: 'kenney-platformer/enemies', anim: 'fly'} : {}), fly: true, size: G.S * (k === 'Tornado' ? .13 : .1), spd: G.S * (k === 'Tornado' ? .14 : .2), ...s, flip: false,
        shoot: k === 'Cloud with lightning' ? {rate: 2.2, img: 'High voltage', speed: .45} : null,
        ai: (f, G, dt) => { if (k === 'Cloud with lightning' && f.x < G.W * .78) f.x += 0; else f.x -= f.spd * dt; f.y += Math.sin(f.t * (k === 'Bat' ? 4 : 1.5)) * 90 * dt; if (f.x < -40) f.x = G.W + 40; }});
    });
  }),
  done: G => Z.boss ? G.foes.every(f => !f.boss) : G.kills >= NEED(Z),
  goal: killsGoal
});

// ---------- 9. Đầm Lầy Ma: trời tối, đèn quanh bé; nhặt đom đóm sáng, ✨ chớp sáng làm ma choáng; trùm Vua Ma ----------
const ORBS = Z => Z.boss ? 0 : 5 + Z.s;
export const swamp = (box, Z) => arena(box, Z, {
  name: 'Đầm Lầy Ma', goalText: Z.boss ? 'Chớp sáng ✨ cho Vua Ma choáng rồi chém' : `Nhặt ${ORBS(Z)} đốm sáng`,
  hint: 'Trời tối! Bấm ✨ để chớp sáng, ma sẽ bị choáng',
  imgs: ['Ghost', 'Woman zombie', 'Bat', 'Sparkles', 'Frog', 'Crocodile', 'Fallen leaf', 'Mushroom'],
  skillCd: 4, skillLabel: '💡',
  dark: G => G.S * (.26 + (G.data.flash || 0) * .9),
  skill(G) {
    G.data.flash = 1; G.F.burst(G.hero.x, G.hero.y, 30, ['#fff9db', '#ffe066', '#fff']);
    for (const f of G.foes) if (dist(f, G.hero) < G.S * .5) { f.stun = 2.5; if (f.boss) f.shield = false; const s = strike(G.Z.st, 1.2); G.hit(f, s.d, s.crit); }
  },
  start(G) {
    G.data.orbs = Array.from({length: ORBS(Z)}, () => ({x: rand(60, G.W - 60), y: rand(110, G.H - 60), ph: rand(0, 6)}));
    G.data.got = 0;
    G.data.pools = Array.from({length: 4}, () => ({x: rand(0, G.W), y: rand(100, G.H), r: rand(40, 80)}));
    if (Z.boss) {
      const s = foeStats(8, 5, 9);
      G.add({img: 'Ghost', name: 'Vua Ma', boss: true, crown: true, shield: true, fly: true, x: G.W * .75, y: G.H * .4, size: G.S * .26, spd: G.S * .09, ...s,
        ai(f, G, dt) {
          f.stun = Math.max(0, (f.stun || 0) - dt); if (!f.stun) f.shield = true;
          if (!f.stun) { const h = G.hero, a = Math.atan2(h.y - f.y, h.x - f.x); f.x += Math.cos(a) * f.spd * dt; f.y += Math.sin(a) * f.spd * dt; }
          if (f.cd <= 0 && !f.stun) { f.cd = 3.2; G.F.burst(f.x, f.y, 16, ['#e5dbff', '#b197fc']); f.x = rand(80, G.W - 80); f.y = rand(120, G.H - 80); if (G.foes.length < 4) G.add({img: 'Bat', x: f.x, y: f.y, size: G.S * .07, spd: G.S * .2, ...foeStats(8, 1, .5), gold: .5}); }
        }});
    }
  },
  bg(ctx, G) {
    ctx.fillStyle = '#2b8a3e'; ctx.fillRect(0, 0, G.W, G.H);
    ctx.fillStyle = '#1b5e20'; for (let i = 0; i < 30; i++) { ctx.beginPath(); ctx.arc((i * 151) % G.W, 80 + (i * 113) % G.H, 22, 0, 7); ctx.fill(); }
    for (const p of G.data.pools) { ctx.fillStyle = '#495057'; ctx.beginPath(); ctx.ellipse(p.x, p.y, p.r, p.r * .5, 0, 0, 7); ctx.fill(); }
    for (const d of sceneDeco(G, ['Mushroom', 'Fallen leaf', 'Frog'], 9)) { if (d.img === 'Frog' && sprA(ctx, G.SP?.['kenney-platformer/enemies'], 'frog', G.t + d.x, d.x, d.y + G.S * .03, G.S * .07 * d.s)) continue; draw(ctx, d.img, d.x, d.y, G.S * .06 * d.s); }
  },
  tick: withDt((G, dt) => {
    const d = G.data; d.flash = Math.max(0, (d.flash || 0) - dt * 1.2);
    for (const o of d.orbs) { o.ph += dt; if (!o.got && dist(o, G.hero) < 40) { o.got = true; d.got++; sfx('star'); G.F.star(o.x, o.y); G.xp += 4; } }
    d.lights = d.orbs.filter(o => !o.got).map(o => ({x: o.x, y: o.y, r: 34 + Math.sin(o.ph * 3) * 6}));
    if (Z.boss) return;
    const live = 2 + Math.floor(Z.s / 2);
    if (G.foes.length < live && (d.spT = (d.spT ?? 1) - dt) <= 0) {
      d.spT = 2.4; const k = pick(Z.s >= 2 ? ['Ghost', 'Ghost', 'Woman zombie', 'Bat'] : ['Ghost', 'Bat']);
      G.edge({img: k, fly: k !== 'Woman zombie', size: G.S * (k === 'Bat' ? .07 : .1), spd: G.S * (k === 'Woman zombie' ? .07 : k === 'Bat' ? .2 : .12), ...foeStats(8, Z.s, k === 'Woman zombie' ? 1.4 : .9),
        ai(f, G, dt) {
          f.stun = Math.max(0, (f.stun || 0) - dt); if (f.stun) return;
          const h = G.hero, near = dist(f, h) < G.S * .38;
          if (near) { const a = Math.atan2(h.y - f.y, h.x - f.x); f.x += Math.cos(a) * f.spd * dt; f.y += Math.sin(a) * f.spd * dt; }
          else { f.wa = f.wa ?? rand(0, 6); f.wa += rand(-1, 1) * dt; f.x += Math.cos(f.wa) * f.spd * .5 * dt; f.y += Math.sin(f.wa) * f.spd * .5 * dt; if (f.x < 30 || f.x > G.W - 30 || f.y < 90 || f.y > G.H - 30) f.wa += Math.PI; }
        }});
    }
  }),
  afterDark(ctx, G) {
    for (const o of G.data.orbs) if (!o.got) draw(ctx, 'Sparkles', o.x, o.y, 30 + Math.sin(o.ph * 3) * 4);
    for (const f of G.foes) if (f.stun) { ctx.fillStyle = '#ffe066'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('💫', f.x, f.y - f.size * .5); }
    const b = G.foes.find(f => f.boss);
    if (b) { ctx.globalAlpha = .55; draw(ctx, 'Ghost', b.x, b.y, b.size); draw(ctx, 'Crown', b.x, b.y - b.size * .55, b.size * .35); ctx.globalAlpha = 1; if (b.shield) { ctx.strokeStyle = 'rgba(177,151,252,.8)'; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(b.x, b.y, b.size * .6, 0, 7); ctx.stroke(); } }
  },
  done: G => Z.boss ? G.foes.every(f => !f.boss) : G.data.got >= ORBS(Z),
  goal: G => Z.boss ? null : `✨ ${G.data.got}/${ORBS(Z)}`
});

// ---------- 10. Lâu Đài Rồng: cùng 3 bạn phiêu lưu đánh lính lâu đài; trùm Rồng Lửa ----------
// Ba bạn phiêu lưu là người que: pháp sư (áo tím, đũa phép), cung thủ (áo xanh lá, cung), ninja (dao)
const ALLIES = [
  {c: {shirt: '#7048e8', pants: '#5f3dc4', dress: true, hair: '#ced4da', long: true}, wp: 'Magic wand', name: 'Bé Mây', shot: 'Sparkles', ranged: true},
  {c: {shirt: '#40c057', pants: '#2b8a3e', hair: '#fab005', long: true, hat: 'ears', ear: 'cat', hatC: '#fab005'}, wp: 'Bow and arrow', name: 'Bé Lá', shot: 'Bow and arrow', ranged: true},
  {c: {...COSTUMES['Ninja']}, wp: 'Dagger', name: 'Bé Gió'}];
export const castle = (box, Z) => arena(box, Z, {
  name: 'Lâu Đài Rồng', goalText: Z.boss ? 'Cả đội đánh bại Rồng Lửa' : `Đánh bại ${NEED(Z) + 2} lính lâu đài`,
  hint: 'Đi cùng 3 bạn phiêu lưu · né vòng đỏ · ⚔️ chém, ✨ chiêu xoáy',
  imgs: ['Skull', 'Man vampire', 'Ogre', 'Bat', 'Dragon', 'Fire', 'Castle', 'Crossed swords', ...ALLIES.flatMap(a => [a.wp, a.shot || 'Dagger'])],
  start(G) {
    G.data.allies = ALLIES.map((a, i) => ({...a, x: G.hero.x - 60 + i * 50, y: G.hero.y + 60, cd: rand(.3, 1), hp: 1, down: 0, ox: [-70, 70, 0][i], oy: [40, 40, -70][i]}));
    if (Z.boss) {
      const s = foeStats(9, 5, 14);
      G.add({img: 'Dragon', name: 'Rồng Lửa', boss: true, x: G.W * .78, y: G.H * .45, size: G.S * .36, spd: G.S * .06, ...s, noTouch: false,
        ai(f, G, dt) {
          const h = G.hero, rage = f.hp < f.max * .5;
          f.x += Math.sign(G.W * .72 - f.x) * f.spd * dt; f.y += (h.y - f.y) * .4 * dt; f.flip = h.x > f.x;
          if (f.cd <= 0) {
            f.cd = rage ? 2 : 2.8; const m = Math.floor(rand(0, 3));
            if (m === 0) { for (let i = 0; i < (rage ? 5 : 3); i++) G.tele({x: rand(80, G.W - 80), y: rand(120, G.H - 60), r: G.S * .1, dmg: f.dmg, t: 1.3 + i * .15}); G.tele({x: h.x, y: h.y, r: G.S * .11, dmg: f.dmg, t: 1.3}); }
            else if (m === 1) { const y = h.y; G.tele({x: (f.x - G.S * .2) / 2, y, w: f.x - G.S * .2, h: G.S * .16, dmg: f.dmg * 1.3, t: 1.4}); }
            else { for (let k = -2; k <= 2; k++) { const a = Math.atan2(h.y - f.y, h.x - f.x) + k * .25; G.eshots.push({x: f.x, y: f.y, vx: Math.cos(a) * G.S * .45, vy: Math.sin(a) * G.S * .45, d: f.dmg, img: 'Fire', size: G.S * .07, life: 4}); } sfx('boom'); }
            if (rage && G.foes.length < 4) G.add({img: 'Bat', x: f.x, y: f.y, size: G.S * .07, spd: G.S * .2, ...foeStats(9, 1, .5), gold: .5});
          }
        }});
    }
  },
  bg(ctx, G) {
    const bgc = tileBg(G, 'kenney-tiny-dungeon/dungeon', ['t48', 't49', 't50'], [['t64', 2, 1], ['t65', 2, 1], ['t82', 3, 1], ['t63', 2, 1]], {top: ['t40', 't40', 't57', 't58']});
    if (bgc) {
      ctx.drawImage(bgc, 0, 0, G.W, G.H);
      ctx.fillStyle = 'rgba(201,42,42,.75)'; ctx.fillRect(G.W * .42, 100, G.W * .16, G.H); ctx.fillStyle = '#ffd43b'; ctx.fillRect(G.W * .42, 100, 4, G.H); ctx.fillRect(G.W * .58 - 4, 100, 4, G.H);
      const T = G.SP['kenney-tiny-dungeon/dungeon']; for (const x of [G.W * .12, G.W * .3, G.W * .7, G.W * .88]) spr(ctx, T, 't29', x, 80 + Math.sin(G.t * 9 + x) * 1.5, 40, {pixel: true});
      draw(ctx, 'Castle', G.W * .5, 92, G.S * .12);
      return;
    }
    ctx.fillStyle = '#495057'; ctx.fillRect(0, 0, G.W, G.H);
    const t = 64; for (let y = 70; y < G.H; y += t) for (let x = ((y / t) % 2) * t / 2 - t; x < G.W; x += t) { ctx.fillStyle = (x / t + y / t) % 2 < 1 ? '#5c636a' : '#545b62'; ctx.fillRect(x + 2, y + 2, t - 4, t - 4); }
    ctx.fillStyle = '#c92a2a'; ctx.fillRect(G.W * .4, 70, G.W * .2, G.H);
    draw(ctx, 'Castle', G.W * .5, 110, G.S * .16);
    for (const x of [G.W * .1, G.W * .9]) draw(ctx, 'Fire', x, 110 + Math.sin(G.t * 6) * 3, G.S * .06);
  },
  tick: withDt((G, dt) => {
    // Bạn phiêu lưu (máy điều khiển): đi theo bé, tự đánh quái gần nhất
    for (const a of G.data.allies) {
      const h = G.hero, tx = h.x + a.ox, ty = h.y + a.oy;
      let tg = null, bd = G.S * (a.ranged ? .7 : .45); for (const f of G.foes) { const d = dist(f, a); if (!f.dead && d < bd) { bd = d; tg = f; } }
      const gx = !a.ranged && tg ? tg.x : tx, gy = !a.ranged && tg ? tg.y : ty;
      const ax = a.x, ay = a.y; a.x += (gx - a.x) * Math.min(1, dt * 2.5); a.y += (gy - a.y) * Math.min(1, dt * 2.5); a.cd -= dt;
      a.mv = Math.hypot(a.x - ax, a.y - ay) > dt * 25; if (Math.abs(a.x - ax) > dt * 8) a.face = a.x > ax ? 1 : -1; if (tg) a.face = tg.x > a.x ? 1 : -1; a.sw = Math.max(0, (a.sw || 0) - dt);
      if (tg && a.cd <= 0) {
        a.cd = a.ranged ? 1.1 : .8; a.sw = .25; const d = Math.round(G.Z.st.atk * .35);
        if (a.ranged) { const an = Math.atan2(tg.y - a.y, tg.x - a.x); G.shots.push({x: a.x, y: a.y, vx: Math.cos(an) * G.S * 1.2, vy: Math.sin(an) * G.S * 1.2, d, img: a.shot, size: G.S * .05, life: 1.5, rot: a.shot === 'Bow and arrow' ? an : undefined}); }
        else if (dist(a, tg) < tg.size * .6 + 30) G.hit(tg, d);
      }
    }
    if (Z.boss) return;
    spawner(G, NEED(Z) + 2, 3 + Math.floor(Z.s / 2), 1.1, () => {
      const k = pick(Z.s >= 2 ? ['Skull', 'Man vampire', 'Ogre', 'Bat'] : ['Skull', 'Bat', 'Man vampire']);
      const s = foeStats(9, Z.s, k === 'Ogre' ? 1.8 : k === 'Bat' ? .6 : 1);
      G.edge({img: k, size: G.S * (k === 'Ogre' ? .14 : k === 'Bat' ? .08 : .11), spd: G.S * (k === 'Bat' ? .24 : k === 'Ogre' ? .1 : .15), ...s, ai: k === 'Ogre' ? charger : chase,
        shoot: k === 'Man vampire' ? {rate: 2.6, img: 'Bat', speed: .4, size: .05} : null});
    });
  }),
  after(ctx, G) {
    for (const a of G.data.allies) {
      drawFigure(ctx, a.x, a.y + G.S * .05, G.S * .12, {c: a.c, pose: a.sw > 0 ? (a.ranged ? 'throw' : 'swing') : a.mv ? 'run' : 'idle', act: 1 - (a.sw || 0) / .25, t: G.t + a.ox, face: a.face || 1, weapon: a.wp});
      ctx.font = '800 13px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; const tw = ctx.measureText(a.name).width + 12;
      ctx.fillStyle = 'rgba(0,0,0,.45)'; roundRect(ctx, a.x - tw / 2, a.y - G.S * .08 - 16, tw, 18, 9); ctx.fill();
      ctx.fillStyle = '#b2f2bb'; ctx.fillText(a.name, a.x, a.y - G.S * .08 - 3);
    }
  },
  done: G => Z.boss ? G.foes.every(f => !f.boss) : G.kills >= NEED(Z) + 2,
  goal: G => Z.boss ? null : `⚔️ ${Math.min(G.kills, NEED(Z) + 2)}/${NEED(Z) + 2}`
});
