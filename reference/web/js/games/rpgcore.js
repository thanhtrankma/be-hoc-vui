// Thế giới phiêu lưu (nhập vai, đợt 13): lõi chung cho 10 vùng đất.
// Z (ngữ cảnh một màn) do rpg.js truyền vào: {st (chỉ số nhân vật), heroImg, weaponImg, pet, potions, r, s, boss, alive}.
// Mỗi vùng trả về {win, gold, xp, kills, potions} (potions = số bình còn lại).
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, fx, loadAll, loop, pick, rand, roundRect} from './funcore.js?v=4c51d34a6e';
import {buttons, multi} from './funvs1.js?v=4c51d34a6e';
import {drawFigure, petBuddy, heroOf} from './figure.js?v=4c51d34a6e';
import {E, camera, drawMob, fxb, sheetsB, spr, sprA} from './motionb.js?v=4c51d34a6e';

export {banner, canvasIn, draw, fx, loadAll, loop, pick, rand, roundRect, buttons, multi, sfx, E, camera, drawMob, fxb, sheetsB, spr, sprA};
// Sprite Kenney dùng chung cho các vùng (quái có khung hoạt ảnh, ô cảnh, xu)
export const RPG_SHEETS = ['kenney-platformer/enemies', 'kenney-platformer/tiles', 'kenney-tiny-dungeon/dungeon', 'kenney-tiny-town/town', 'kenney-pirate/ships', 'kenney-pirate/tiles', 'kenney-fish/fish'];
export const loadRpgSheets = () => sheetsB(RPG_SHEETS);
// Vẽ quái: hình tĩnh có hoạt ảnh thủ tục, hoặc sprite Kenney (f.sheet + f.anim). f.atkT/f.windT là bộ đếm đòn.
export function drawFoe(ctx, f, SP) {
  f.atk = f.atkT > 0 ? 1 - f.atkT / .35 : 0;
  const sh = f.sheet ? SP?.[f.sheet] : null;
  drawMob(ctx, f.img, f, sh ? {sheet: sh, anim: f.dieT != null && sh.anims?.[f.anim + '_die'] ? f.anim + '_die' : f.anim, frame: f.frame, pixel: f.pixel} : {});
}
// Xu vàng xoay (sprite), rơi ra nảy lên rồi bay về
export function drawCoin(ctx, SP, x, y, size, t) { if (!sprA(ctx, SP?.['kenney-platformer/tiles'], 'coin', t, x, y, size)) draw(ctx, 'Coin', x, y, size); }

export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

// Quái theo vùng r, màn s (0-5), k = hệ số (trùm lớn hơn).
export const foeStats = (r, s, k = 1) => ({
  hp: Math.round((18 + r * r * 4 + r * 16) * (1 + s * .12) * k),
  dmg: Math.round((5 + r * 5) * (1 + s * .08) * Math.sqrt(k))
});
// Sát thương nhận vào sau giáp.
export const taken = (dmg, def) => Math.max(1, Math.round(dmg * 100 / (100 + def * 4)));
// Đòn của bé: có tỉ lệ chí mạng.
export const strike = (st, mult = 1) => { const c = Math.random() < st.crit; return {d: Math.round(st.atk * mult * (c ? 2 : 1) * rand(.9, 1.1)), crit: c}; };

// Đồng đội vẽ bằng bộ thú cưng có chân bước: id lưu cũ giữ nguyên (fairy = Mèo thần, dragon = Cáo lửa)
export const PET_RIG = {dog: 'dog', fairy: 'cat', dragon: 'fox'};
export const BASE_IMGS = ['Coin', 'Red heart', 'Test tube', 'Collision', 'Glowing star', 'Sparkles', 'Crown', 'Fire'];

// Chuyển cảnh: hiện dần từ tối khi vào màn, tối dần trước khi sang bảng kết quả (kết thúc ở giây thứ 2)
export function fade(ctx, W, H, t, endT) {
  const a = Math.max(0, 1 - t / .45, endT ? (endT - 1.55) / .45 : 0);
  if (a > 0) { ctx.fillStyle = `rgba(16,18,40,${Math.min(1, a)})`; ctx.fillRect(0, 0, W, H); }
}
// ---------- HUD ----------
export function hpBar(ctx, x, y, w, h, v, max, c = '#ff6b6b') {
  ctx.fillStyle = 'rgba(0,0,0,.45)'; roundRect(ctx, x, y, w, h, h / 2); ctx.fill();
  ctx.fillStyle = c; roundRect(ctx, x + 2, y + 2, Math.max(0, (w - 4) * clamp(v / max, 0, 1)), h - 4, (h - 4) / 2); ctx.fill();
}
export function topHud(ctx, W, Z, hp, max, gold, goal) {
  const x = 64, w = Math.min(220, W * .3);
  ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, x - 6, 8, w + 70, 46, 23); ctx.fill();
  draw(ctx, 'Red heart', x + 14, 31, 26);
  hpBar(ctx, x + 32, 20, w - 10, 22, hp, max);
  ctx.fillStyle = '#fff'; ctx.font = '800 14px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
  ctx.fillText(`${Math.ceil(hp)}/${max}`, x + 32 + (w - 10) / 2, 36);
  ctx.font = '800 18px "Baloo 2", sans-serif'; ctx.fillStyle = '#ffd43b'; ctx.fillText(`Cấp ${Z.st.lv}`, x + w + 36, 37);
  // Vàng (phải)
  ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W - 132, 8, 120, 46, 23); ctx.fill();
  draw(ctx, 'Coin', W - 108, 31, 28);
  ctx.fillStyle = '#fff'; ctx.textAlign = 'left'; ctx.font = '800 24px "Baloo 2", sans-serif'; ctx.fillText(String(gold), W - 88, 40);
  if (goal) {
    ctx.font = '800 18px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
    const tw = ctx.measureText(goal).width + 28, gy = W < 700 ? 62 : 8, gx = W < 700 ? W / 2 : clamp(W / 2, x + w + 80 + tw / 2, W - 140 - tw / 2);
    ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, gx - tw / 2, gy, tw, 40, 20); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.fillText(goal, gx, gy + 27);
  }
}
export function bossBar(ctx, W, H, f, name, y = H - 30) {
  const bw = Math.min(420, W * .6);
  ctx.fillStyle = '#fff'; ctx.font = '800 16px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
  ctx.strokeStyle = 'rgba(0,0,0,.6)'; ctx.lineWidth = 4; ctx.strokeText(`👑 ${name}`, W / 2, y - 6); ctx.fillText(`👑 ${name}`, W / 2, y - 6);
  hpBar(ctx, W / 2 - bw / 2, y, bw, 18, f.hp, f.max, '#e64980');
}
// Màn mở đầu: tên vùng, màn, mục tiêu.
export function zoneIntro(ctx, W, H, Z, name, goal, hint) {
  ctx.fillStyle = 'rgba(0,0,0,.45)'; ctx.fillRect(0, H / 2 - 95, W, 190);
  ctx.textAlign = 'center';
  const fit = (txt, size, weight) => { let px = size; do { ctx.font = `${weight} ${px}px "Baloo 2", sans-serif`; px -= 1; } while (px > 11 && ctx.measureText(txt).width > W - 24); };
  ctx.fillStyle = '#ffd43b'; fit(Z.boss ? `👑 ${name} · TRÙM` : `${name} · Màn ${Z.s + 1}`, 44, 800); ctx.fillText(Z.boss ? `👑 ${name} · TRÙM` : `${name} · Màn ${Z.s + 1}`, W / 2, H / 2 - 28);
  ctx.fillStyle = '#fff'; fit(`🎯 ${goal}`, 26, 800); ctx.fillText(`🎯 ${goal}`, W / 2, H / 2 + 14);
  if (hint) { ctx.fillStyle = 'rgba(255,255,255,.88)'; fit(hint, 19, 700); ctx.fillText(hint, W / 2, H / 2 + 52); }
}
export const endBanner = (ctx, W, H, win, gold) => banner(ctx, W, H, win ? '🏆 CHIẾN THẮNG!' : '💫 HẾT MÁU RỒI!', win ? `+${gold} vàng` : 'Mua đồ mạnh hơn rồi thử lại nhé');

// Nhân vật: người que mặc trang phục theo linh vật, cầm vũ khí; (x, y) là tâm, chân ở y + size * .45.
// pose tự chọn: vung vũ khí khi đánh, choáng khi vừa trúng đòn, chạy khi đang đi, còn lại đứng thở.
export function drawHero(ctx, x, y, size, Z, {face = 1, swing = 0, hurt = 0, t = 0, moving = false, pose = null} = {}) {
  const c = Z.cos || (Z.cos = heroOf(Z.heroImg));
  const p = pose || (swing > 0 ? 'swing' : hurt > .55 ? 'hurt' : moving ? 'run' : 'idle');
  drawFigure(ctx, x, y + size * .45, size * 1.15, {c, pose: p, t, act: swing > 0 ? 1 - swing / .25 : .9, face, weapon: Z.weaponImg, alpha: hurt > 0 && Math.floor(hurt * 20) % 2 ? .45 : 1});
}

// ---------- Điều khiển ----------
// Cần điều khiển: chạm vào nửa trái màn hình (trừ vùng nút) để đẩy. Có cả phím mũi tên / WASD.
export function joystick(M, cv, W, H, zoneFn = p => p.x < W * .5 && p.y > 70) {
  let id = null, cx = 0, cy = 0, dx = 0, dy = 0;
  const keys = new Set();
  const kd = e => keys.add(e.key.toLowerCase()), ku = e => keys.delete(e.key.toLowerCase());
  addEventListener('keydown', kd); addEventListener('keyup', ku);
  M.on('down', p => { if (id == null && !p.btn && zoneFn(p)) { id = p.id; cx = p.x; cy = p.y; dx = dy = 0; } });
  M.on('move', p => { if (p.id !== id) return; const R = 60; let ax = p.x - cx, ay = p.y - cy; const d = Math.hypot(ax, ay); if (d > R) { cx += ax * (1 - R / d); cy += ay * (1 - R / d); ax = p.x - cx; ay = p.y - cy; } dx = ax / R; dy = ay / R; });
  M.on('up', p => { if (p.id === id) { id = null; dx = dy = 0; } });
  return {
    get() {
      let kx = (keys.has('arrowright') || keys.has('d') ? 1 : 0) - (keys.has('arrowleft') || keys.has('a') ? 1 : 0);
      let ky = (keys.has('arrowdown') || keys.has('s') ? 1 : 0) - (keys.has('arrowup') || keys.has('w') ? 1 : 0);
      if (kx || ky) { const d = Math.hypot(kx, ky); return {x: kx / d, y: ky / d}; }
      const d = Math.hypot(dx, dy); return d > 1 ? {x: dx / d, y: dy / d} : {x: dx, y: dy};
    },
    key: k => keys.has(k),
    draw(ctx) {
      if (id == null) {
        ctx.globalAlpha = .45; ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(90, H - 100, 56, 0, 7); ctx.fill();
        ctx.fillStyle = '#495057'; ctx.beginPath(); ctx.arc(90, H - 100, 24, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
        ctx.fillStyle = '#fff'; ctx.font = '700 14px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('kéo để đi', 90, H - 30);
        return;
      }
      ctx.globalAlpha = .5; ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(cx, cy, 60, 0, 7); ctx.fill();
      ctx.fillStyle = '#339af0'; ctx.beginPath(); ctx.arc(cx + dx * 60, cy + dy * 60, 26, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
    },
    off() { removeEventListener('keydown', kd); removeEventListener('keyup', ku); }
  };
}

// Nút bình máu dùng chung (bên phải, phía trên nút đánh).
export function potionUse(Z, hero, F) {
  if (Z.potions <= 0 || hero.hp >= hero.max) { sfx('wrong'); return false; }
  Z.potions--; hero.hp = Math.min(hero.max, hero.hp + hero.max * .5); sfx('power'); F.text(hero.x, hero.y - 50, '+máu', '#69db7c'); F.burst(hero.x, hero.y, 14, ['#69db7c', '#b2f2bb', '#fff']);
  return true;
}
export function drawPotionCount(ctx, b, n) {
  ctx.fillStyle = '#e03131'; ctx.beginPath(); ctx.arc(b.x + b.r * .7, b.y - b.r * .7, 14, 0, 7); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.font = '800 16px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(n, b.x + b.r * .7, b.y - b.r * .7 + 6);
}

// ---------- Đồng đội (thú đi theo) ----------
// Cún: chạy tới cắn quái. Mèo thần: hồi máu. Cáo lửa: phun lửa.
export function makePet(Z) {
  if (!Z.pet) return null;
  return {kind: Z.pet, x: 0, y: 0, cd: 1, t: 0, tx: null, rig: petBuddy(PET_RIG[Z.pet] || 'dog'), f: 1};
}
export function petUpdate(P, G, dt) {
  if (!P) return;
  const h = G.hero, st = G.Z.st; P.t += dt; P.cd -= dt;
  let tgt = null;
  if (P.kind !== 'fairy') { let bd = 1e9; for (const f of G.foes) { const d = dist(f, h); if (d < bd && d < G.S * .6) { bd = d; tgt = f; } } }
  const gx = P.kind === 'dog' && tgt ? tgt.x : h.x - h.face * G.S * .1, gy = P.kind === 'dog' && tgt ? tgt.y : h.y - G.S * .06 + (P.kind === 'dog' ? G.S * .05 : Math.sin(P.t * 3) * 10);
  const ox = P.x; P.x += (gx - P.x) * Math.min(1, dt * (P.kind === 'dog' ? 4 : 3)); P.y += (gy - P.y) * Math.min(1, dt * 4);
  const vx = (P.x - ox) / Math.max(dt, .001); if (Math.abs(vx) > 8) P.f = vx > 0 ? 1 : -1; P.rig.update(dt, Math.abs(vx) > 15 || Math.abs(gy - P.y) > 6);
  if (P.kind === 'fairy') { if (P.cd <= 0) { P.cd = 1; if (h.hp < h.max) { h.hp = Math.min(h.max, h.hp + h.max * .025); G.F.text(h.x + 20, h.y - 40, '+', '#69db7c'); } } }
  else if (P.kind === 'dog' && tgt && dist(P, tgt) < tgt.size * .6 + 20 && P.cd <= 0) { P.cd = 1; G.hit(tgt, Math.round(st.atk * .4)); sfx('bark'); }
  else if (P.kind === 'dragon' && tgt && P.cd <= 0) { P.cd = 1.2; const a = Math.atan2(tgt.y - P.y, tgt.x - P.x), v = G.S * 1.4; G.shots.push({x: P.x, y: P.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, d: Math.round(st.atk * .6), img: 'Fire', size: G.S * .06, life: 1.5}); }
}
export function petDraw(ctx, P, G) { if (P) P.rig.draw(ctx, P.x, P.y + G.S * .05, G.S * .042, P.f); }

// ---------- Động cơ đấu trường (dùng cho Rừng Xanh, Biển Ngọc, Thành Mây, Đầm Lầy Ma, Lâu Đài Rồng) ----------
// cfg: {name, goal, hint, imgs, bg(ctx,G), heroSize, melee, autoFire:{rate, img, speed, dir}, bounds(G)->{x0,x1,y0,y1},
//       start(G), tick(G,dt) (sinh quái), done(G)->true khi thắng, after(ctx,G) (vẽ thêm trên cùng), dark, flash}
export async function arena(box, Z, cfg) {
  await loadAll([Z.heroImg, Z.weaponImg, ...BASE_IMGS, ...(cfg.imgs || [])]);
  const SP = await loadRpgSheets();
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), M = multi(cv), F = fx(), FB = fxb(), C = camera();
  const st = Z.st, hs = cfg.heroSize || S * .13;
  const br = Math.min(54, S * .085);
  const btnList = [];
  if (cfg.melee !== false) btnList.push({id: 'atk', x: W - br - 18, y: H - br - 22, r: br * 1.15, label: '⚔️', c: '#ff922b'});
  btnList.push({id: 'sk', x: W - br * (cfg.melee !== false ? 3.4 : 1) - 18, y: H - br - 22, r: br * .9, label: cfg.skillLabel || '✨', c: '#b197fc'});
  btnList.push({id: 'pot', x: W - br - 18, y: H - br * (cfg.melee !== false ? 3.6 : 3.2) - 22, r: br * .75, label: '🧪', c: '#69db7c'});
  const B = buttons(M, btnList);
  const J = joystick(M, cv, W, H, p => p.y > 70 && !(p.x > W - br * 5 - 30 && p.y > H - br * 5));
  const G = {Z, W, H, S, F, FB, C, SP, dying: [], flash: 0, t: 0, foes: [], shots: [], eshots: [], zones: [], drops: [], kills: 0, gold: 0, xp: 0,
    hero: {x: W / 2, y: H * .6, hp: st.maxhp, max: st.maxhp, face: 1, inv: 0, swing: 0, size: hs}, pet: makePet(Z),
    atkCd: 0, skCd: 0, skMax: cfg.skillCd || 6, end: null, endT: 0, introT: 2.4, data: {},
    add(f) { f.max = f.hp; f.size = f.size || S * .1; f.hurt = 0; f.cd = f.cd ?? rand(.5, 1.5); f.t = rand(0, 2); f.kx = f.ky = 0; f.atkT = 0; f.born = 0; this.foes.push(f); return f; },
    edge(spec) { const side = spec.side ?? Math.floor(rand(0, 4)); const p = side === 0 ? {x: rand(0, W), y: -40} : side === 1 ? {x: W + 40, y: rand(80, H)} : side === 2 ? {x: rand(0, W), y: H + 40} : {x: -40, y: rand(80, H)}; return this.add({...p, ...spec}); },
    hit(f, d, crit) {
      if (f.dead || f.shield) { if (f.shield) { F.text(f.x, f.y - f.size * .6, '🛡', '#fff'); } return; }
      f.hp -= d; f.hurt = .15; FB.num(f.x, f.y - f.size * .6, crit ? `${d}!` : String(d), {crit});
      FB.sparks(f.x, f.y, crit ? 9 : 5, crit ? '#ffe066' : '#fff');
      if (f.hp <= 0) {
        f.dead = true; this.kills++; sfx(f.boss ? 'boom' : 'pop'); F.burst(f.x, f.y, f.boss ? 40 : 14); FB.ring(f.x, f.y, f.size * .7, '#fff', 6);
        C.shake(f.boss ? 14 : 2.5); if (f.boss) C.stop(.25);
        if (!f.drawFn) this.dying.push({...f, dieT: 0, hurt: .15, shield: false});
        const g = Math.round((2 + Z.r * 3) * (f.boss ? 15 : f.gold || 1) * st.goldMul);
        this.drops.push({x: f.x, y: f.y, v: g, t: 0}); this.xp += Math.round((3 + Z.r * 2) * (f.boss ? 10 : 1));
        if (f.onDie) f.onDie(f, this);
      }
    },
    hurt(d) {
      const h = this.hero; if (h.inv > 0 || this.end) return;
      const v = taken(d, st.def); h.hp -= v; h.inv = .8; sfx('hit'); FB.num(h.x, h.y - hs * .6, `-${v}`, {c: '#ff6b6b'}); C.shake(6); this.flash = .35;
    },
    tele(z) { this.zones.push({t: 1.2, ...z, t0: z.t || 1.2}); }
  };
  G.pet && (G.pet.x = G.hero.x, G.pet.y = G.hero.y);
  if (cfg.start) cfg.start(G);
  const bounds = () => cfg.bounds ? cfg.bounds(G) : {x0: hs / 2, x1: W - hs / 2, y0: 70 + hs / 2, y1: H - hs / 2};
  const nearest = (from, rng = 1e9) => { let b = null, bd = rng; for (const f of G.foes) { if (f.dead || f.hidden) continue; const d = dist(f, from); if (d < bd) { bd = d; b = f; } } return b; };
  let fireT = 0;
  const darkCv = cfg.dark ? document.createElement('canvas') : null;
  if (darkCv) { darkCv.width = Math.ceil(W / 2); darkCv.height = Math.ceil(H / 2); }  // bóng tối vẽ nửa độ phân giải rồi phóng (mềm, nhẹ hơn 4 lần)
  const res = await loop({
    update(rdt) {
      C.update(rdt); const dt = rdt * C.scale(rdt);
      G.t += dt; F.update(dt); FB.update(dt); G.flash = Math.max(0, G.flash - rdt);
      for (const f of G.dying) f.dieT += dt * 2; G.dying = G.dying.filter(f => f.dieT < 1);
      const h = G.hero;
      if (G.end) { G.endT += dt; J.off(); return G.endT > 2 ? {win: G.end === 'win', gold: G.gold, xp: G.xp, kills: G.kills, potions: Z.potions} : null; }
      if (G.introT > 0) { G.introT -= dt; if (G.introT > 0) return null; }
      // Di chuyển
      const j = J.get(), sp = S * .42 * st.spd * (cfg.heroSpeed || 1);
      h.x += j.x * sp * dt; h.y += j.y * sp * dt;
      if (Math.abs(j.x) > .2) h.face = j.x > 0 ? 1 : -1;
      if (cfg.mountSpr && Math.hypot(j.x, j.y) > .2) { const ta = Math.atan2(j.x, -j.y); let da = ta - (h.ang ?? 0); while (da > Math.PI) da -= Math.PI * 2; while (da < -Math.PI) da += Math.PI * 2; h.ang = (h.ang ?? 0) + da * Math.min(1, dt * 6); if (Math.random() < dt * 20) FB.dust(h.x - Math.sin(h.ang) * hs * .6, h.y + Math.cos(h.ang) * hs * .6, 1, 0, 'rgba(255,255,255,.8)'); }
      h.mv = Math.hypot(j.x, j.y) > .15;
      const bd = bounds(); h.x = clamp(h.x, bd.x0, bd.x1); h.y = clamp(h.y, bd.y0, bd.y1);
      h.inv = Math.max(0, h.inv - dt); h.swing = Math.max(0, h.swing - dt);
      if (st.regen) h.hp = Math.min(h.max, h.hp + h.max * st.regen * dt);
      G.atkCd -= dt; G.skCd -= dt;
      // Đánh gần: tự nhắm quái gần nhất
      if ((B.hit('atk') || J.key(' ')) && G.atkCd <= 0) {
        G.atkCd = .32; h.swing = .25; sfx('flip');
        const tg = nearest(h); if (tg && tg.x !== h.x) h.face = tg.x > h.x ? 1 : -1;
        const R = hs * 1.25;
        let any = false;
        for (const f of G.foes) if (!f.dead && !f.hidden && dist(f, h) < R + f.size * .45) { const s = strike(st); G.hit(f, s.d, s.crit); any = true; if (!f.boss) { const a = Math.atan2(f.y - h.y, f.x - h.x); f.kx += Math.cos(a) * S * 1.1; f.ky += Math.sin(a) * S * 1.1; } }
        if (any) { sfx('hit'); C.stop(.05); C.shake(2.5); }
        FB.slash(h.x + h.face * hs * .1, h.y - hs * .05, hs * .75, h.face > 0 ? 0 : Math.PI, h.face);
      }
      if (B.hit('sk') && G.skCd <= 0) {
        G.skCd = G.skMax; sfx('power');
        if (cfg.skill) cfg.skill(G);
        else { const R = S * .3; F.burst(h.x, h.y, 40, ['#b197fc', '#e5dbff', '#fff']); FB.ring(h.x, h.y, R, '#d0bfff', 10, .5); C.shake(5); for (const f of G.foes) if (!f.dead && !f.hidden && dist(f, h) < R + f.size / 2) { const s = strike(st, 2); G.hit(f, s.d, s.crit); } G.data.ring = .4; }
      }
      if (B.hit('pot')) potionUse(Z, h, F);
      // Tự bắn (tàu, đại bàng)
      if (cfg.autoFire) {
        fireT -= dt;
        if (fireT <= 0) {
          const A = cfg.autoFire, tg = A.dir ? null : nearest(h, S * 1.2);
          if (A.dir || tg) {
            fireT = A.rate; const v = S * (A.speed || 1.3);
            let a = A.dir === 'up' ? -Math.PI / 2 : A.dir === 'right' ? 0 : Math.atan2(tg.y - h.y, tg.x - h.x);
            // Bắn thẳng thì tự nhắm nhẹ vào quái phía trước (lệch tối đa ~35°) cho bé dễ trúng
            if (A.dir === 'right') { const fr = G.foes.filter(f => !f.dead && !f.hidden && f.x > h.x + 20).sort((p, q) => dist(p, h) - dist(q, h))[0]; if (fr) a = clamp(Math.atan2(fr.y - h.y, fr.x - h.x), -.6, .6); }
            G.shots.push({x: h.x, y: h.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, d: 0, img: A.img, size: S * (A.size || .05), life: 2, rot: A.spin ? 0 : a});
            sfx('shoot');
          }
        }
      }
      if (cfg.tick) cfg.tick(G, dt);
      petUpdate(G.pet, G, dt);
      // Quái
      for (const f of G.foes) {
        if (f.dead) continue;
        f.t += dt; f.hurt = Math.max(0, f.hurt - dt); f.cd -= dt; f.atkT = Math.max(0, (f.atkT || 0) - dt); f.born = (f.born || 0) + dt;
        if (f.kx || f.ky) { f.x += f.kx * dt; f.y += f.ky * dt; const k = Math.exp(-dt * 9); f.kx *= k; f.ky *= k; if (Math.abs(f.kx) + Math.abs(f.ky) < 4) f.kx = f.ky = 0; }
        const ox = f.x, oy = f.y;
        if (f.ai) f.ai(f, G, dt);
        else { const a = Math.atan2(h.y - f.y, h.x - f.x); f.x += Math.cos(a) * f.spd * dt; f.y += Math.sin(a) * f.spd * dt; }
        f.moving = Math.abs(f.x - ox) + Math.abs(f.y - oy) > dt * 8;
        if (!f.hidden && !f.noTouch && dist(f, h) < (f.size + hs) * .38) { if (h.inv <= 0 && !G.end) f.atkT = .35; G.hurt(f.dmg); }
        if (f.shoot && f.cd <= 0 && !f.hidden) {
          f.cd = f.shoot.rate * rand(.8, 1.2); f.atkT = .35;
          const a = f.shoot.dir != null ? f.shoot.dir : Math.atan2(h.y - f.y, h.x - f.x), v = S * (f.shoot.speed || .5);
          G.eshots.push({x: f.x, y: f.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, d: f.dmg, img: f.shoot.img, size: S * (f.shoot.size || .05), life: 4});
        }
      }
      G.foes = G.foes.filter(f => !f.dead && f.x > -300 && f.x < W + 300 && f.y > -300 && f.y < H + 300);
      // Đạn của bé / đồng đội
      for (const s of G.shots) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
        for (const f of G.foes) if (!f.dead && !f.hidden && dist(s, f) < f.size * .45 + s.size * .3) { const k = s.d ? {d: s.d, crit: false} : strike(st, cfg.autoFire?.mul || .8); G.hit(f, k.d, k.crit); s.life = 0; break; }
      }
      G.shots = G.shots.filter(s => s.life > 0);
      for (const s of G.eshots) { s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt; if (dist(s, h) < hs * .35 + s.size * .3) { G.hurt(s.d); s.life = 0; } }
      G.eshots = G.eshots.filter(s => s.life > 0 && s.x > -50 && s.x < W + 50 && s.y > -50 && s.y < H + 50);
      // Vùng nguy hiểm báo trước (vòng đỏ)
      for (const z of G.zones) {
        z.t -= dt;
        if (z.t <= 0 && !z.done) { z.done = true; F.burst(z.x, z.y, 18, ['#ff6b6b', '#ffa94d', '#ffe066']); FB.ring(z.x, z.y, z.r || z.w / 2, '#ffa94d', 8); C.shake(4); sfx('boom'); const inside = z.w ? (h.x > z.x - z.w / 2 && h.x < z.x + z.w / 2 && h.y > z.y - z.h / 2 && h.y < z.y + z.h / 2) : dist(z, h) < z.r; if (inside) G.hurt(z.dmg); }
      }
      G.zones = G.zones.filter(z => z.t > -.3);
      // Vàng bay về
      for (const d of G.drops) { d.t += dt; if (d.t > .5) { const a = Math.atan2(h.y - d.y, h.x - d.x), v = S * 1.8; d.x += Math.cos(a) * v * dt; d.y += Math.sin(a) * v * dt; if (dist(d, h) < 30) { G.gold += d.v; d.got = true; sfx('coin'); } } }
      G.drops = G.drops.filter(d => !d.got);
      if (G.data.ring) G.data.ring = Math.max(0, G.data.ring - dt);
      if (h.hp <= 0) { h.hp = 0; G.end = 'lose'; sfx('wrong'); }
      else if (cfg.done(G)) { G.end = 'win'; sfx('win'); F.burst(W / 2, H / 2, 60); }
      return null;
    },
    draw() {
      const h = G.hero;
      C.begin(ctx);
      cfg.bg(ctx, G);
      for (const z of G.zones) {
        const k = 1 - Math.max(0, z.t) / z.t0;
        ctx.fillStyle = `rgba(255,59,59,${.15 + k * .3})`; ctx.strokeStyle = 'rgba(255,59,59,.9)'; ctx.lineWidth = 3;
        if (z.w) { ctx.fillRect(z.x - z.w / 2, z.y - z.h / 2, z.w, z.h); ctx.strokeRect(z.x - z.w / 2, z.y - z.h / 2, z.w, z.h); }
        else { ctx.beginPath(); ctx.arc(z.x, z.y, z.r, 0, 7); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.arc(z.x, z.y, z.r * k, 0, 7); ctx.stroke(); }
      }
      for (const d of G.drops) drawCoin(ctx, SP, d.x, d.y - Math.sin(Math.min(1, d.t / .5) * Math.PI) * 40, 28, G.t + d.v);
      for (const f of G.dying) drawFoe(ctx, f, SP);
      const ents = [...G.foes.filter(f => !f.hidden).map(f => ({y: f.y, f})), {y: h.y, h: true}].sort((a, b) => a.y - b.y);
      for (const e of ents) {
        if (e.h) {
          if (cfg.mountSpr) {
            // Thuyền (sprite nhìn từ trên): xoay theo hướng lái, nhấp nhô trên sóng, bọt nước phía sau
            const m = cfg.mountSpr, ang = h.ang ?? 0, bob = Math.sin(G.t * 3) * .04;
            spr(ctx, SP[m.sheet], m.frame, h.x, h.y + hs * .1, hs * 1.5, {rot: ang + bob, alpha: h.inv > 0 && Math.floor(h.inv * 20) % 2 ? .5 : 1});
            drawHero(ctx, h.x, h.y - hs * .12, hs * .62, Z, {face: h.face, swing: h.swing, hurt: h.inv, t: G.t, pose: 'idle'});
          } else if (cfg.mount) { draw(ctx, cfg.mount, h.x, h.y + hs * .15, hs * 1.35, hs * 1.35, {flip: cfg.mount === 'Eagle' ? true : h.face < 0, alpha: h.inv > 0 && Math.floor(h.inv * 20) % 2 ? .5 : 1}); drawHero(ctx, h.x, h.y + hs * (cfg.mount === 'Eagle' ? -.22 : .02), hs * .7, Z, {face: cfg.mount === 'Eagle' ? 1 : h.face, swing: h.swing, hurt: h.inv, t: G.t, pose: 'sit'}); }
          else drawHero(ctx, h.x, h.y, hs, Z, {face: h.face, swing: h.swing, hurt: h.inv, t: G.t, moving: h.mv});
          continue;
        }
        const f = e.f;
        if (f.drawFn) { f.drawFn(ctx, f, G); continue; }
        if (f.flip == null) f.flipAuto = true; if (f.flipAuto) f.flip = h.x > f.x;
        // Quái mới xuất hiện: phóng to dần (outBack)
        const sz0 = f.size; if (f.born < .35) f.size = sz0 * Math.max(.05, E.outBack(f.born / .35));
        drawFoe(ctx, f, SP); f.size = sz0;
        if (f.crown) draw(ctx, 'Crown', f.x, f.y - f.size * .55, f.size * .35);
        if (!f.boss && f.hp < f.max) hpBar(ctx, f.x - f.size * .35, f.y - f.size * .62, f.size * .7, 8, f.hp, f.max);
      }
      petDraw(ctx, G.pet, G);
      for (const s of G.shots) draw(ctx, s.img, s.x, s.y, s.size, s.size, {rot: s.rot ?? G.t * 12});
      for (const s of G.eshots) draw(ctx, s.img, s.x, s.y, s.size, s.size, {rot: G.t * 8});
      if (G.data.ring) { ctx.strokeStyle = `rgba(177,151,252,${G.data.ring * 2})`; ctx.lineWidth = 10; ctx.beginPath(); ctx.arc(h.x, h.y, S * .3 * (1.2 - G.data.ring), 0, 7); ctx.stroke(); }
      if (cfg.after) cfg.after(ctx, G);
      FB.draw(ctx);
      C.end(ctx);
      if (darkCv) {
        const d = darkCv.getContext('2d'), R = cfg.dark(G);
        d.setTransform(.5, 0, 0, .5, 0, 0); d.globalCompositeOperation = 'source-over'; d.clearRect(0, 0, W, H); d.fillStyle = 'rgba(8,10,30,.93)'; d.fillRect(0, 0, W, H);
        d.globalCompositeOperation = 'destination-out';
        const lights = [{x: h.x, y: h.y, r: R}, ...(G.data.lights || [])];
        for (const L of lights) { const g = d.createRadialGradient(L.x, L.y, L.r * .25, L.x, L.y, L.r); g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)'); d.fillStyle = g; d.beginPath(); d.arc(L.x, L.y, L.r, 0, 7); d.fill(); }
        ctx.drawImage(darkCv, 0, 0, W, H);
        if (cfg.afterDark) cfg.afterDark(ctx, G);
      }
      F.draw(ctx);
      if (G.flash > 0) { const g = ctx.createRadialGradient(W / 2, H / 2, S * .3, W / 2, H / 2, Math.max(W, H) * .75); g.addColorStop(0, 'rgba(255,0,0,0)'); g.addColorStop(1, `rgba(255,30,30,${G.flash * 1.2})`); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
      const boss = G.foes.find(f => f.boss && !f.dead);
      if (boss) bossBar(ctx, W, H, boss, boss.name || 'Trùm', W < 700 ? 132 : H - 30);
      topHud(ctx, W, Z, h.hp, h.max, G.gold, cfg.goal(G));
      J.draw(ctx); B.draw(ctx);
      const sk = btnList.find(b => b.id === 'sk');
      if (G.skCd > 0) { ctx.fillStyle = 'rgba(0,0,0,.5)'; ctx.beginPath(); ctx.moveTo(sk.x, sk.y); ctx.arc(sk.x, sk.y, sk.r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * G.skCd / G.skMax); ctx.fill(); }
      drawPotionCount(ctx, btnList.find(b => b.id === 'pot'), Z.potions);
      if (G.introT > 0) zoneIntro(ctx, W, H, Z, cfg.name, cfg.goalText, cfg.hint);
      if (G.end) endBanner(ctx, W, H, G.end === 'win', G.gold);
      fade(ctx, W, H, G.t, G.end ? G.endT : 0);
    }
  }, Z.alive);
  J.off();
  return res;
}
