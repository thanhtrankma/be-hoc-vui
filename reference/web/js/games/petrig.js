// Vẽ thú cưng động bằng canvas (cún, mèo, thỏ, hamster): thân, chân bước theo nhịp, đầu, tai, đuôi, mắt chớp.
// Gốc toạ độ là điểm giữa hai chân trên mặt đất; u = chiều dài thân (px). Hướng mặt sang phải, f = -1 thì lật.
// Tư thế (pose) là các số 0..1 được làm mượt dần để chuyển động tự nhiên.
import {sprite} from './funcore.js?v=4c51d34a6e';

// Kiểu chibi: đầu to, thân tròn ngắn, chân ngắn, mắt to long lanh.
export const SPECIES = {
  dog: {len: .86, bh: .56, leg: .27, lw: .17, hr: .6, head: [.4, -.62], ears: 'floppy', tail: 'wag', muzzle: true,
    c: '#f2c27e', dark: '#d79a52', belly: '#fff6e8', ear: '#b8773a', nose: '#3b2a20', inner: '#f5c6a5', patch: '#e0a35e'},
  cat: {len: .82, bh: .54, leg: .26, lw: .15, hr: .58, head: [.4, -.62], ears: 'pointy', tail: 'long', stripes: true,
    c: '#f7b46a', dark: '#e08b43', belly: '#fff3e3', ear: '#e08b43', nose: '#ff8fa3', inner: '#ffc2cc'},
  rabbit: {len: .76, bh: .6, leg: .2, lw: .17, hr: .56, head: [.36, -.6], ears: 'long', tail: 'puff', bigFeet: true,
    c: '#fbfbfd', dark: '#dde2ea', belly: '#ffffff', ear: '#eef0f4', line: 'rgba(90,100,120,.3)', nose: '#ff8fa3', inner: '#ffc9d6'},
  hamster: {len: .74, bh: .66, leg: .12, lw: .13, hr: .54, head: [.3, -.42], ears: 'round', tail: 'none', cheeks: true,
    c: '#f5bf6b', dark: '#dc9a3c', belly: '#fff8e8', ear: '#e7a24a', nose: '#ff8fa3', inner: '#ffc9b0'},
  panda: {len: .8, bh: .6, leg: .22, lw: .19, hr: .6, head: [.36, -.6], ears: 'round', tail: 'puff', panda: true, legC: '#2f2f38',
    c: '#fdfdfd', dark: '#2f2f38', belly: '#ffffff', ear: '#2f2f38', line: 'rgba(60,60,80,.25)', nose: '#2f2f38', inner: '#55556a'},
  fox: {len: .84, bh: .54, leg: .26, lw: .15, hr: .58, head: [.4, -.62], ears: 'pointy', tail: 'fluffy', muzzle: true, mask: true,
    c: '#fb8c3c', dark: '#e26a1c', belly: '#fff6ec', ear: '#e26a1c', nose: '#3b2a20', inner: '#fff0e0'}
};

export function newPose() {
  return {walk: 0, phase: 0, sit: 0, lie: 0, dip: 0, jump: 0, roll: 0, shake: 0, mouth: 0, tongue: 0, eye: 1, happy: 0, sad: 0,
    lookX: 0, lookY: 0, headRot: 0, tailAmp: .4, tailSpeed: 6, earUp: 0, blink: 0, squash: 0, crouch: 0, sleep: 0, bath: 0};
}

// Làm mượt tư thế về đích (target chỉ cần các khoá muốn đổi).
export function easePose(p, target, dt, speed = 8) {
  const k = Math.min(1, dt * speed);
  for (const key in target) p[key] += (target[key] - p[key]) * k;
}

const shade = (ctx, x, y, r, c, light = 'rgba(255,255,255,.55)') => {
  const g = ctx.createRadialGradient(x - r * .35, y - r * .45, r * .1, x, y, r * 1.15);
  g.addColorStop(0, light); g.addColorStop(.45, c); g.addColorStop(1, c);
  return g;
};
const ell = (ctx, x, y, rx, ry, rot = 0) => { ctx.beginPath(); ctx.ellipse(x, y, Math.max(.1, rx), Math.max(.1, ry), rot, 0, Math.PI * 2); };

// Chân: đùi từ hông xuống bàn chân, đầu gối cong ra sau khi chân ngắn hơn khoảng cách.
function leg(ctx, hx, hy, px, py, L, w, color, paw, back) {
  const d = Math.hypot(px - hx, py - hy);
  const bend = d < L ? Math.sqrt(L * L - d * d) * .5 * (back ? 1 : -1) : 0;
  const mx = (hx + px) / 2 + bend, my = (hy + py) / 2;
  ctx.strokeStyle = color; ctx.lineWidth = w; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(hx, hy); ctx.quadraticCurveTo(mx, my, px, py); ctx.stroke();
  ctx.fillStyle = paw; ell(ctx, px + w * .18, py - w * .12, w * .62, w * .42); ctx.fill();
}

/**
 * Vẽ thú cưng.
 * @param o {u, f (1|-1), t (giây), dirty 0..1, foam [[x,y,r]...] theo toạ độ thân, wear {hat,eyes,neck: tên hình}, mood}
 * Trả về các điểm neo (toạ độ màn hình) để gắn hiệu ứng: head, mouth, body, top.
 */
export function drawPet(ctx, kind, x, y, P, o) {
  const s = SPECIES[kind] || SPECIES.dog, u = o.u, t = o.t, f = o.f || 1;
  const len = s.len * u, bh = s.bh * u, L = s.leg * u, lw = s.lw * u, hr = s.hr * u;
  const anchors = {};
  ctx.save();
  ctx.translate(x, y);
  // Bóng đổ
  const air = P.jump * u * .9;
  ctx.fillStyle = `rgba(0,0,0,${.18 - Math.min(.1, air / u * .1)})`;
  ell(ctx, 0, 0, len * .62 * (1 - Math.min(.4, air / u * .3)), u * .09); ctx.fill();
  ctx.scale(f, 1);
  // Lắc mình (sau khi tắm) và lăn tròn
  if (P.shake > .01) ctx.rotate(Math.sin(t * 38) * .12 * P.shake);
  const breathe = Math.sin(t * (P.sleep > .5 ? 1.6 : 3)) * .025;
  const stepBob = Math.abs(Math.sin(P.phase)) * u * .05 * P.walk;
  const sitDrop = P.sit * L * .55, lieDrop = P.lie * L * .92, crouchDrop = P.crouch * L * .4;
  const bodyBase = L + bh * .42;
  const tilt = -P.sit * .5 + P.crouch * .08;
  // Tâm thân (tọa độ cục bộ, y âm là lên)
  const cy = -bodyBase + sitDrop + lieDrop + crouchDrop - air + stepBob * -1 + P.squash * u * .06;
  const piv = {x: -len * .38, y: bh * .38};
  const tr = (lx, ly) => {
    const rx = lx - piv.x, ry = ly - piv.y, c = Math.cos(tilt), sn = Math.sin(tilt);
    return [rx * c - ry * sn + piv.x, rx * sn + ry * c + piv.y + cy];
  };
  if (P.roll > .001) { ctx.translate(0, cy); ctx.rotate(P.roll * Math.PI * 2); ctx.translate(0, -cy); }

  // Nhịp bước: chéo cặp (trước trái + sau phải).
  const stride = len * .22 * P.walk, lift = L * .3 * P.walk;
  const footPos = (hip, off) => {
    const ph = P.phase + off;
    const gx = hip[0] + Math.sin(ph) * stride;
    let gy = -Math.max(0, Math.cos(ph)) * lift;
    // Chân không với tới đất (đang nhảy) thì buông thõng.
    const maxY = hip[1] + L * .98;
    if (gy > maxY) gy = maxY;
    return [gx, Math.min(gy, maxY)];
  };
  const hipF = tr(len * .3, bh * .2), hipB = tr(-len * .3, bh * .2);
  const lying = P.lie > .5 || P.bath > .5;

  // --- Đuôi (sau thân) ---
  const tailBase = tr(-len * .47, -bh * .1);
  const wag = Math.sin(t * P.tailSpeed) * P.tailAmp;
  ctx.lineCap = 'round';
  if (s.tail === 'wag') {
    ctx.strokeStyle = s.c; ctx.lineWidth = lw * .75;
    const a = -1.1 + wag * .9 - P.sad * .9;
    ctx.beginPath(); ctx.moveTo(...tailBase);
    ctx.quadraticCurveTo(tailBase[0] - u * .18, tailBase[1] - u * .05, tailBase[0] + Math.cos(Math.PI + a) * u * .32, tailBase[1] + Math.sin(Math.PI + a) * u * .32 - u * .05);
    ctx.stroke();
  } else if (s.tail === 'fluffy') {
    const sw = Math.sin(t * 2.4) * .25 + wag * .5;
    ctx.save(); ctx.translate(...tailBase); ctx.rotate(-.5 + sw - P.sad * .6);
    ctx.fillStyle = s.c; ell(ctx, -u * .26, -u * .02, u * .3, u * .14); ctx.fill();
    ctx.fillStyle = '#fff'; ell(ctx, -u * .48, -u * .02, u * .1, u * .09); ctx.fill();
    ctx.restore();
  } else if (s.tail === 'long') {
    ctx.strokeStyle = s.c; ctx.lineWidth = lw * .7;
    const sw = Math.sin(t * 2.2) * .5 + wag * .4;
    const ex = tailBase[0] - u * .42, ey = tailBase[1] - u * (.35 - P.sad * .4) + (P.lie * u * .3);
    ctx.beginPath(); ctx.moveTo(...tailBase);
    ctx.bezierCurveTo(tailBase[0] - u * .3, tailBase[1] + u * .05, ex + sw * u * .25, ey + u * .25, ex + sw * u * .15, ey);
    ctx.stroke();
    ctx.strokeStyle = s.dark; ctx.lineWidth = lw * .72;
    ctx.beginPath(); ctx.arc(ex + sw * u * .15, ey, lw * .05, 0, 7); ctx.stroke();
  }

  // --- Chân phía xa (tối hơn) ---
  const far = s.dark, near = s.legC || s.c, pawC = s.legC ? '#55556a' : s.belly;
  if (!lying && P.bath < .3) {
    if (P.sit < .5) leg(ctx, hipB[0] + u * .04, hipB[1], ...footPos([hipB[0] + u * .04, hipB[1]], Math.PI), L, lw, far, far, true);
    leg(ctx, hipF[0] + u * .04, hipF[1], ...footPos([hipF[0] + u * .04, hipF[1]], 0), L, lw, far, far, false);
  }

  // --- Thân ---
  ctx.save();
  ctx.translate(piv.x, piv.y + cy); ctx.rotate(tilt); ctx.translate(-piv.x, -piv.y);
  const bodyW = len * .54 * (1 + breathe), bodyH = bh * .52 * (1 - breathe * .5) * (1 - P.squash * .15);
  ctx.fillStyle = shade(ctx, 0, 0, bodyW, s.c);
  ell(ctx, 0, 0, bodyW, bodyH); ctx.fill();
  ctx.strokeStyle = s.line || 'rgba(0,0,0,.1)'; ctx.lineWidth = 2.5; ctx.stroke();
  ctx.fillStyle = s.belly; ell(ctx, len * .05, bodyH * .45, bodyW * .62, bodyH * .45); ctx.fill();
  if (s.stripes) {
    ctx.strokeStyle = s.dark; ctx.lineWidth = lw * .3;
    for (let k = -2; k <= 1; k++) { ctx.beginPath(); ctx.moveTo(k * len * .14, -bodyH * .95); ctx.quadraticCurveTo(k * len * .14 + len * .04, -bodyH * .5, k * len * .14 - len * .02, -bodyH * .2); ctx.stroke(); }
  }
  if (s.patch) { ctx.fillStyle = s.patch; ell(ctx, -len * .12, -bodyH * .45, bodyW * .32, bodyH * .4, .3); ctx.fill(); }
  if (s.tail === 'puff') { ctx.fillStyle = '#fff'; ell(ctx, -bodyW * .95, -bodyH * .15, u * .11, u * .11); ctx.fill(); ctx.strokeStyle = 'rgba(0,0,0,.06)'; ctx.stroke(); }
  // Bẩn: vết bùn
  if (o.dirty > 0) {
    ctx.fillStyle = `rgba(120,78,40,${.55 * o.dirty})`;
    for (const [dx, dy, r] of [[-.25, -.2, .09], [.15, -.35, .07], [.05, .1, .08], [-.35, .15, .06], [.3, 0, .05]]) { ell(ctx, dx * len, dy * bh, r * u, r * u * .8); ctx.fill(); }
  }
  // Đùi sau khi ngồi / nằm
  if (P.sit > .4 || lying) {
    ctx.fillStyle = shade(ctx, -len * .28, bodyH * .35, u * .2, s.c);
    ell(ctx, -len * .26, bodyH * .4, u * .2, u * .16); ctx.fill();
    ctx.fillStyle = pawC; ell(ctx, -len * .1, bodyH * .95, lw * .7, lw * .4); ctx.fill();
  }
  // Bọt xà phòng
  if (o.foam) for (const [fx, fy, fr] of o.foam) {
    ctx.fillStyle = 'rgba(255,255,255,.92)'; ell(ctx, fx * len, fy * bh, fr * u, fr * u); ctx.fill();
    ctx.strokeStyle = 'rgba(165,216,255,.8)'; ctx.lineWidth = 2; ctx.stroke();
  }
  ctx.restore();
  anchors.body = tr(0, -bh * .1);

  // --- Chân phía gần ---
  if (!lying && P.bath < .3) {
    if (P.sit < .5) leg(ctx, hipB[0], hipB[1], ...footPos(hipB, 0), L, lw, near, pawC, true);
    leg(ctx, hipF[0], hipF[1], ...footPos(hipF, Math.PI), L, lw, near, pawC, false);
    if (s.bigFeet && P.sit < .5) { ctx.fillStyle = pawC; const fp = footPos(hipB, 0); ell(ctx, fp[0] + lw * .3, fp[1] - lw * .1, lw * .9, lw * .38); ctx.fill(); }
  } else if (lying && P.bath < .3) {
    // Nằm: hai chân trước duỗi ra phía trước
    const base = tr(len * .32, bh * .5);
    ctx.fillStyle = s.c; ell(ctx, base[0] + u * .12, -lw * .45, u * .16, lw * .5); ctx.fill();
    ctx.fillStyle = pawC; ell(ctx, base[0] + u * .27, -lw * .4, lw * .55, lw * .45); ctx.fill();
  }

  // --- Đầu ---
  let [hx, hy] = tr(s.head[0] * len, s.head[1] * bh * 1.4 - bh * .1);
  // Cúi đầu ăn/uống: đầu hạ sát đất phía trước
  hx += P.dip * u * .18; hy += P.dip * ((-hr * .75) - hy);
  if (lying) { hy += P.sleep * hr * .35; }
  hy += Math.sin(t * 3) * u * .008 + P.sad * hr * .15;
  const hrot = P.headRot + tilt * .4 + P.sad * .15 - P.dip * .25;
  anchors.head = [hx, hy]; anchors.top = [hx, hy - hr];
  ctx.save();
  ctx.translate(hx, hy); ctx.rotate(hrot);
  // Tai phía xa
  const earFlap = Math.sin(t * 9) * .15 * P.walk + P.earUp * .4;
  drawEar(ctx, s, hr, t, P, earFlap, true);
  // Mặt
  ctx.fillStyle = shade(ctx, 0, 0, hr, s.c);
  ell(ctx, 0, 0, hr * (s.cheeks ? 1.08 : 1), hr * .95); ctx.fill();
  ctx.strokeStyle = s.line || 'rgba(0,0,0,.1)'; ctx.lineWidth = 2.5; ctx.stroke();
  if (s.stripes) { ctx.strokeStyle = s.dark; ctx.lineWidth = hr * .08; for (const dx of [-.25, 0, .25]) { ctx.beginPath(); ctx.moveTo(dx * hr, -hr * .92); ctx.lineTo(dx * hr * 1.1, -hr * .62); ctx.stroke(); } }
  if (s.patch) { ctx.fillStyle = s.patch; ell(ctx, -hr * .42, -hr * .38, hr * .3, hr * .28, -.3); ctx.fill(); }
  // Má phúng phính (hamster) và má hồng
  if (s.cheeks) { ctx.fillStyle = s.belly; ell(ctx, hr * .45, hr * .35, hr * .45, hr * .38); ctx.fill(); }
  ctx.fillStyle = 'rgba(255,110,140,.4)'; ell(ctx, hr * .74, hr * .22, hr * .14, hr * .09); ctx.fill(); ell(ctx, -hr * .14, hr * .24, hr * .13, hr * .085); ctx.fill();
  // Mõm
  const mz = s.muzzle ? [hr * .66, hr * .34] : [hr * .6, hr * .26];
  if (s.mask) { ctx.fillStyle = s.belly; ell(ctx, hr * .45, hr * .38, hr * .52, hr * .42); ctx.fill(); }
  if (s.muzzle) { ctx.fillStyle = s.belly; ell(ctx, hr * .64, hr * .34, hr * .3, hr * .22); ctx.fill(); }
  if (s.panda) { ctx.fillStyle = '#2f2f38'; ell(ctx, -hr * .02, -hr * .02, hr * .25, hr * .3, .5); ctx.fill(); ell(ctx, hr * .5, 0, hr * .25, hr * .3, -.4); ctx.fill(); }
  // Miệng mở (ăn, sủa, kêu)
  if (P.mouth > .05) {
    ctx.fillStyle = '#7a2e3a'; ell(ctx, mz[0] - hr * .05, mz[1] + hr * .2, hr * .16, hr * .16 * P.mouth + 1); ctx.fill();
    ctx.fillStyle = '#ff8fa3'; ell(ctx, mz[0] - hr * .05, mz[1] + hr * .2 + hr * .1 * P.mouth, hr * .1, hr * .06 * P.mouth + .5); ctx.fill();
  } else {
    ctx.strokeStyle = '#4a3328'; ctx.lineWidth = Math.max(1.5, hr * .045);
    ctx.beginPath(); ctx.arc(mz[0] - hr * .12, mz[1] + hr * .1, hr * .09, .2, Math.PI - .4); ctx.stroke();
    ctx.beginPath(); ctx.arc(mz[0] + hr * .05, mz[1] + hr * .1, hr * .09, .4, Math.PI - .2); ctx.stroke();
  }
  if (P.tongue > .05) { ctx.fillStyle = '#ff6b81'; ell(ctx, mz[0] - hr * .02, mz[1] + hr * (.28 + .12 * P.tongue), hr * .1, hr * .16 * P.tongue); ctx.fill(); }
  anchors.mouth = [hx + mz[0], hy + mz[1]];
  // Mũi
  ctx.fillStyle = s.nose;
  if (s.muzzle) { ell(ctx, hr * .88, hr * .22, hr * .1, hr * .075); ctx.fill(); }
  else { ctx.beginPath(); ctx.moveTo(mz[0] - hr * .08, mz[1] - hr * .04); ctx.lineTo(mz[0] + hr * .08, mz[1] - hr * .04); ctx.lineTo(mz[0], mz[1] + hr * .05); ctx.closePath(); ctx.fill(); }
  // Ria mèo
  if (kind === 'cat' || kind === 'rabbit') {
    ctx.strokeStyle = 'rgba(80,60,50,.5)'; ctx.lineWidth = 1.5;
    for (const k of [-1, 0, 1]) { ctx.beginPath(); ctx.moveTo(mz[0] + hr * .1, mz[1] + hr * .05 * k); ctx.lineTo(mz[0] + hr * .5, mz[1] + hr * .1 * k - hr * .03); ctx.stroke(); }
  }
  // Mắt: tròn đen long lanh; nhắm khi ngủ/chớp; ^^ khi vui
  const eyeOpen = Math.max(0, P.eye * (1 - P.blink) * (1 - P.sleep));
  for (const [ex, ey, er] of [[-hr * .02, -hr * .02, hr * .2], [hr * .5, 0, hr * .22]]) {
    if (P.happy > .5 || eyeOpen < .15) {
      ctx.strokeStyle = '#2b2118'; ctx.lineWidth = Math.max(2, hr * .07); ctx.lineCap = 'round';
      ctx.beginPath();
      if (P.happy > .5 && P.sleep < .5) ctx.arc(ex, ey + er * .3, er * .7, Math.PI * 1.15, Math.PI * 1.85);
      else ctx.arc(ex, ey - er * .2, er * .7, Math.PI * .15, Math.PI * .85);
      ctx.stroke();
    } else {
      const lx = P.lookX * er * .25, ly = P.lookY * er * .25;
      const eg = ctx.createLinearGradient(0, ey - er, 0, ey + er);
      eg.addColorStop(0, '#1b1410'); eg.addColorStop(.7, '#3d2b20'); eg.addColorStop(1, '#6b4a33');
      ctx.fillStyle = eg; ell(ctx, ex + lx * .5, ey + ly * .5, er * .8, er * 1.02 * eyeOpen); ctx.fill();
      ctx.fillStyle = '#fff'; ell(ctx, ex + lx - er * .22, ey + ly - er * .42 * eyeOpen, er * .34, er * .34 * eyeOpen); ctx.fill();
      ell(ctx, ex + lx + er * .28, ey + ly + er * .34 * eyeOpen, er * .15, er * .15 * eyeOpen); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.35)'; ell(ctx, ex + lx * .5, ey + ly * .5 + er * .55 * eyeOpen, er * .45, er * .18 * eyeOpen); ctx.fill();
      if (P.sad > .5) { ctx.strokeStyle = '#2b2118'; ctx.lineWidth = hr * .05; ctx.beginPath(); ctx.moveTo(ex - er, ey - er * 1.4); ctx.lineTo(ex + er * .6, ey - er * 1.1); ctx.stroke(); }
    }
  }
  anchors.eyes = [hx + hr * .26 * f, hy - hr * .12];
  // Tai phía gần
  drawEar(ctx, s, hr, t, P, earFlap, false);
  ctx.restore();
  ctx.restore();

  // Đồ đeo (vẽ theo toạ độ màn hình, không lật để hình không bị ngược chữ)
  const W2 = (lx, ly) => [x + lx * f, y + ly];
  const wear = o.wear || {};
  const hs = W2(hx, hy);
  if (wear.neck) drawImg(ctx, wear.neck, x + (hx - hr * .55) * f, y + hy + hr * .85, hr * .9);
  if (wear.eyes) drawImg(ctx, wear.eyes, hs[0] + hr * .26 * f, hs[1] - hr * .1, hr * 1.25, f < 0);
  if (wear.hat) drawImg(ctx, wear.hat, hs[0] - hr * .05 * f, hs[1] - hr * (s.ears === 'long' ? 1.05 : .95), hr * 1.15, f < 0, -.12 * f);
  return {head: W2(hx, hy), top: W2(hx, hy - hr * 1.2), mouth: W2(...anchors.mouth), body: W2(...anchors.body), hr, len};
}

function drawImg(ctx, name, x, y, w, flip = false, rot = 0) {
  const im = sprite(name);
  if (!im.complete || !im.naturalWidth) return;
  ctx.save(); ctx.translate(x, y); if (rot) ctx.rotate(rot); if (flip) ctx.scale(-1, 1);
  ctx.drawImage(im, -w / 2, -w / 2, w, w); ctx.restore();
}

function drawEar(ctx, s, hr, t, P, flap, farSide) {
  ctx.save();
  const col = farSide ? s.dark : s.ear;
  if (s.ears === 'floppy') {
    const x = farSide ? hr * .45 : -hr * .25, y = -hr * .55;
    ctx.translate(x, y); ctx.rotate((farSide ? -.1 : .25) - flap - P.sad * .1);
    ctx.fillStyle = col; ell(ctx, 0, hr * .45, hr * .26, hr * .55); ctx.fill();
  } else if (s.ears === 'pointy') {
    const x = farSide ? hr * .5 : -hr * .25, y = -hr * .7;
    const tw = Math.sin(t * .7 + (farSide ? 1 : 0)) > .97 ? .2 : 0;
    ctx.translate(x, y); ctx.rotate((farSide ? .25 : -.2) + tw - P.sad * .5);
    ctx.fillStyle = col; ctx.beginPath(); ctx.moveTo(-hr * .26, hr * .15); ctx.lineTo(0, -hr * .45); ctx.lineTo(hr * .26, hr * .15); ctx.closePath(); ctx.fill();
    if (!farSide) { ctx.fillStyle = s.inner; ctx.beginPath(); ctx.moveTo(-hr * .14, hr * .1); ctx.lineTo(0, -hr * .28); ctx.lineTo(hr * .14, hr * .1); ctx.closePath(); ctx.fill(); }
  } else if (s.ears === 'long') {
    const x = farSide ? hr * .35 : -hr * .1, y = -hr * .7;
    const sway = Math.sin(t * 1.7 + (farSide ? .7 : 0)) * .08 - flap * .6;
    const droop = P.sad * .9 + P.sleep * 1.1;
    ctx.translate(x, y); ctx.rotate((farSide ? .18 : -.12) + sway - droop);
    ctx.fillStyle = col; ell(ctx, 0, -hr * .6, hr * .2, hr * .68); ctx.fill();
    ctx.fillStyle = s.inner; ell(ctx, 0, -hr * .58, hr * .1, hr * .52); ctx.fill();
  } else {
    const x = farSide ? hr * .45 : -hr * .3, y = -hr * .72;
    ctx.translate(x, y);
    ctx.fillStyle = col; ell(ctx, 0, 0, hr * .22, hr * .2); ctx.fill();
    if (!farSide) { ctx.fillStyle = s.inner; ell(ctx, 0, 0, hr * .12, hr * .11); ctx.fill(); }
  }
  ctx.restore();
}
