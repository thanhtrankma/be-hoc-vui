// Phòng thú cưng: con vật động (vẽ bằng canvas ở petrig.js) tự đi lại trong phòng, có tiếng kêu thật.
// Bé chạm để chơi, vuốt để cưng nựng, chạm sàn để gọi lại; cho ăn/uống vào bát, ném bóng, tắm, đưa đi ngủ, đeo đồ.
// Chỉ số giảm theo giờ thật (kể cả khi tắt app) nhưng không bao giờ về 0: thú cưng chỉ buồn và cần bé, không ốm, không chết.
import * as store from '../store.js?v=4c51d34a6e';
import {h, img, confetti, toast} from '../ui.js?v=4c51d34a6e';
import {sfx, say, sayPhrase, tpl, clip} from '../audio.js?v=4c51d34a6e';
import {t, L} from '../i18n.js?v=4c51d34a6e';
import {loadAll, rand, pick, draw as drawSprite, roundRect} from './funcore.js?v=4c51d34a6e';
import {drawPet, newPose, easePose} from './petrig.js?v=4c51d34a6e';

const STATS = [
  ['food', 'Meat on bone', 9], ['water', 'Droplet', 11], ['clean', 'Soap', 6], ['happy', 'Red heart', 7], ['energy', 'High voltage', 6]
];
const FLOOR = 8, XP_PER_LV = 60, MAX_LV = 10;
const levelOf = pet => Math.min(MAX_LV, 1 + Math.floor(pet.xp / XP_PER_LV));
const clamp = v => Math.max(FLOOR, Math.min(100, v));

// Tiếng kêu thật theo loài (file trong sfx/, xem tools/pet_sounds.py). Hamster dùng tiếng thỏ cao giọng hơn.
const VOICE = {
  dog: {talk: ['dog-bark1', 'dog-bark2', 'dog-bark3'], sad: ['dog-whine'], rate: 1.12},
  cat: {talk: ['cat-meow1', 'cat-meow2', 'cat-meow3'], sad: ['cat-meow1'], purr: 'cat-purr', rate: 1},
  rabbit: {talk: ['rabbit-1', 'rabbit-2', 'rabbit-3'], sad: ['rabbit-2'], rate: 1},
  hamster: {talk: ['rabbit-1', 'rabbit-2', 'rabbit-3'], sad: ['rabbit-2'], rate: 1.5},
  panda: {talk: ['rabbit-1', 'rabbit-3'], sad: ['rabbit-2'], rate: .75},
  fox: {talk: ['dog-bark2', 'dog-bark3'], sad: ['dog-whine'], rate: 1.45}
};

// Cập nhật chỉ số theo thời gian đã trôi qua.
export function tick(pet) {
  const now = Date.now();
  const hours = Math.min(48, (now - (pet.last || now)) / 36e5);
  if (hours > 0) for (const [k, , rate] of STATS) pet[k] = clamp(pet[k] - rate * hours * (k === 'energy' && pet.sleeping ? -3 : 1));
  pet.last = now;
  return pet;
}

// Gọi khi bé học xong một bài (app.js).
export function onLesson(p) {
  if (!p.pet) return false;
  tick(p.pet);
  p.pet.happy = clamp(p.pet.happy + 8); p.pet.xp += 5;
  store.save();
  return true;
}

const SPRITES = ['Red heart', 'Sparkles', 'Droplet', 'Zzz', 'Bubbles', 'Thought balloon', 'Musical note', 'Glowing star', 'Shower', 'Sponge',
  'Meat on bone', 'High voltage', 'Soap', 'Crescent moon', 'Sun', 'Potted plant', 'Framed picture', 'Teddy bear', 'Tennis', 'Yarn', 'Softball'];

export function petScreen(root, {data, onExit}) {
  const p = store.profile();
  if (!p.pet) return adopt(root, data, () => petScreen(root, {data, onExit}), onExit);
  const pet = tick(p.pet);
  pet.sleeping = false;
  const kind = data.pets.find(x => x.id === pet.type) || data.pets[0];
  const V = VOICE[kind.id] || VOICE.dog;
  const voice = key => tpl(key, {p: kind.p});
  const save = () => { pet.last = Date.now(); store.save(); };
  let mode = 'home', lv = levelOf(pet), alive = true;

  const lvEl = h('span', {class: 'pet-lv'});
  const bars = h('div', {class: 'pet-bars'});
  const room = h('div', {class: 'petroom live'});
  const tray = h('div', {class: 'pet-tray'});
  const actions = h('div', {class: 'pet-actions'});
  const exit = () => { alive = false; stopPurr(); save(); onExit(); };
  root.replaceChildren(
    h('div', {class: 'topbar'}, h('button', {class: 'icon-btn', onclick: exit}, '⬅️'),
      h('h1', {}, pet.name, ' ', lvEl), h('span', {class: 'spacer'})),
    bars, room, tray, actions);

  // ---------- Canvas ----------
  const cv = document.createElement('canvas');
  cv.className = 'petcv';
  room.append(cv);
  let ctx, W = 600, H = 400;
  const fit = () => {
    const r = room.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    W = Math.max(280, r.width); H = Math.max(260, r.height);
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  fit();
  const ro = new ResizeObserver(fit); ro.observe(room);

  // Sàn nhà: z = 0 (sát tường) .. 1 (sát bé). Toạ độ màn hình và cỡ theo chiều sâu.
  const floorTop = () => H * .46;
  const sy = z => floorTop() + 18 + z * (H * .95 - floorTop() - 18);
  const kz = z => .78 + .32 * z;
  const unit = z => Math.min(W * .29, H * .4) * kz(z) * (.86 + lv * .025);
  const toZ = y => Math.max(0, Math.min(1, (y - floorTop() - 18) / (H * .95 - floorTop() - 18)));

  const bed = {x: .15, z: .22}, bowlF = {x: .74, z: .12, n: 0, food: kind.foods[0]}, bowlW = {x: .87, z: .28, n: 0};
  let ball = null, tub = null, foamProg = 0;
  const a = {x: .5, z: .6, f: 1, st: 'idle', tm: 1.5, tgt: null, onArrive: null, speed: .28, P: newPose(), foam: [], held: null, bubble: null};
  const parts = [];
  let time = 0, blinkT = 2, taps = [], touching = null, follow = null, purr = null, scrubbing = false, lastSave = 0, lastBars = 0, lastMeow = 0;

  // ---------- Âm thanh ----------
  const speak = (sad = false) => {
    if (time - lastMeow < .6) return;
    lastMeow = time;
    a.P.mouth = 1; setTimeout(() => { a.P.mouth = 0; }, 350);
    clip(pick(sad ? V.sad : V.talk), {rate: V.rate * rand(.95, 1.08)}).then(ok => { if (!ok) sfx(kind.sound); });
  };
  const startPurr = () => { if (V.purr && !purr) purr = clip(V.purr, {loop: true, vol: .8}); };
  function stopPurr() { if (purr) { purr.then(s => s && s()); purr = null; } }

  // ---------- Hiệu ứng nổi ----------
  const float = (x, y, im, {vy = -60, life = 1.2, size = 34, vx = rand(-15, 15), g = 0} = {}) => parts.push({x, y, im, vx, vy, life, max: life, size, g});
  const hearts = (x, y, n = 3, im = 'Red heart') => { for (let i = 0; i < n; i++) float(x + rand(-20, 20), y + rand(-10, 10), im, {vy: rand(-90, -50), size: rand(24, 36)}); };

  // ---------- Hành vi ----------
  const anchors = {};
  const set = (st, tm = 0) => { a.st = st; a.tm = tm; };
  const goTo = (x, z, speed, then) => { a.tgt = {x: Math.max(.08, Math.min(.92, x)), z: Math.max(0, Math.min(1, z))}; a.speed = speed; a.onArrive = then; set('walk'); };
  const busy = () => ['eat', 'drink', 'sleep', 'tub', 'shake', 'carry', 'react', 'petted'].includes(a.st);
  const urgent = () => { const low = STATS.filter(([k]) => pet[k] < 35).sort((x, y) => pet[x[0]] - pet[y[0]]); return low.length ? low[0][0] : null; };

  function gain(fields, xp) {
    const before = levelOf(pet);
    for (const [k, v] of Object.entries(fields)) pet[k] = clamp(pet[k] + v);
    pet.xp += xp;
    lv = levelOf(pet);
    if (lv > before) {
      confetti(); sfx('win');
      say(voice('petGrow'));
      const item = data.petItems.find(i => i.lv === lv);
      if (item) setTimeout(() => { if (!alive || !root.isConnected) return; toast('🎁 ' + t('petNewItem')); sayPhrase('petNewItem'); }, 2600);
    }
    renderBars();
  }

  // Quyết định việc tiếp theo khi rảnh.
  function decide() {
    if (mode === 'bath' && tub) return goTo(tub.x, tub.z, .32, () => { set('tub'); sfx('splash'); });
    if (ball && !ball.held) return chaseBall();
    if (pet.food < 45 && bowlF.n > 0) return goTo(bowlF.x - .07, bowlF.z + .04, .3, () => { a.f = 1; set('eat', 1.1); });
    if (pet.water < 45 && bowlW.n > 0) return goTo(bowlW.x - .07, bowlW.z + .04, .3, () => { a.f = 1; set('drink', 1); });
    if (pet.energy < 22) return goTo(bed.x, bed.z + .05, .2, () => set('sleep', 25));
    const need = urgent();
    if (need === 'food' || need === 'water') {
      const b = need === 'food' ? bowlF : bowlW;
      return goTo(b.x - .1, b.z + .1, .22, () => { a.f = 1; set('beg', 4); speak(true); a.bubble = need; });
    }
    const r = Math.random();
    if (need === 'clean' && r < .4) return set('scratch', 1.6);
    if (r < .38) return goTo(rand(.12, .88), rand(.15, .95), rand(.14, .2), () => set('idle', rand(1, 2.5)));
    if (r < .55) return set('sit', rand(3, 5));
    if (r < .65 && pet.energy < 70) return set('lie', rand(4, 7));
    if (r < .75) return set('sniff', rand(1.5, 2.5));
    if (r < .85 && pet.happy > 60) return goTo(.5 + rand(-.15, .15), .93, .24, () => { set('look', 3); speak(); });
    if (r < .93 && pet.happy > 70) return set('hop', 1.2);
    set('idle', rand(1.5, 3));
  }

  function chaseBall() {
    if (!ball) return;
    a.bubble = null;
    goTo(ball.x - .05 * Math.sign(ball.x - a.x || 1), ball.z, .5, () => {
      if (!ball || ball.held || ball.h > .1) return set('idle', .2);
      a.f = ball.x >= a.x ? 1 : -1;
      if (kind.id === 'dog') { ball.held = true; set('carry'); speak(); goTo(.5, .95, .35, dropBall); }
      else {
        // Mèo, thỏ, hamster: đẩy/đập bóng lăn tiếp.
        const dir = a.f * rand(.3, .7);
        ball.vx = dir; ball.vz = rand(-.4, .4); ball.vh = kind.id === 'cat' ? 1.2 : .5; sfx('pop');
        a.P.jump = kind.id === 'cat' ? .3 : .1;
        hearts(anchors.top[0], anchors.top[1], 1);
        gain({happy: 6, energy: -3, food: -1}, 2);
        ball.bats = (ball.bats || 0) + 1;
        if (ball.bats >= 3) { ball.bats = 0; set('sit', 2.5); } else set('idle', .5);
      }
    });
  }
  function dropBall() {
    if (!ball) return set('idle', 1);
    ball.held = false; ball.x = a.x + a.f * .06; ball.z = Math.min(1, a.z + .02); ball.h = .05; ball.vx = ball.vz = 0; ball.vh = 0;
    a.f = 1; set('look', 2.5); speak();
    hearts(anchors.top[0], anchors.top[1], 3);
    gain({happy: 10, energy: -5, food: -2}, 4);
  }

  function throwBall(vx, vz, vh) {
    if (!ball) ball = {x: .5, z: .95, h: 0, vx: 0, vz: 0, vh: 0, held: false};
    if (ball.held) return;
    Object.assign(ball, {vx, vz, vh, held: false});
    sfx('jump');
    if (!['sleep', 'tub', 'shake'].includes(a.st)) { a.P.earUp = 1; setTimeout(() => chaseBall(), 350); }
  }

  // ---------- Chạm ----------
  const pos = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  const onPet = (x, y) => anchors.body && (Math.hypot(x - anchors.body[0], (y - anchors.body[1]) * 1.2) < anchors.len * .62 || Math.hypot(x - anchors.head[0], y - anchors.head[1]) < anchors.hr * 1.25);
  const ballXY = () => ball && [ball.x * W, sy(ball.z) - ball.h * H * .5 - unit(ball.z) * .1];
  cv.addEventListener('pointerdown', e => {
    const [x, y] = pos(e);
    cv.setPointerCapture(e.pointerId);
    if (mode === 'bath' && a.st === 'tub') { scrubbing = true; scrub(x, y); return; }
    if (onPet(x, y)) {
      if (a.st === 'sleep') { set('wake', 1.2); sfx('tap'); pet.sleeping = false; return; }
      touching = {x, y, t: time, moved: 0, lx: x, ly: y};
      return;
    }
    const b = ballXY();
    if (b && !ball.held && Math.hypot(x - b[0], y - b[1]) < 60) { touching = {ball: true, x, y, t: time, lx: x, ly: y, vx: 0, vy: 0}; return; }
    if (busy() && a.st !== 'react') return;
    // Chạm sàn: gọi bạn ấy chạy lại (mèo rình rồi vồ).
    if (y > floorTop()) { follow = {x: x / W, z: toZ(y)}; a.P.earUp = 1; if (Math.random() < .5) speak(); }
  });
  cv.addEventListener('pointermove', e => {
    const [x, y] = pos(e);
    if (scrubbing) return scrub(x, y);
    if (follow && e.buttons) { follow.x = x / W; follow.z = toZ(Math.max(floorTop(), y)); return; }
    if (!touching) return;
    const d = Math.hypot(x - touching.lx, y - touching.ly);
    if (touching.ball) { touching.vx = (x - touching.lx); touching.vy = (y - touching.ly); touching.lx = x; touching.ly = y; ball.x = x / W; ball.z = toZ(Math.max(floorTop(), y)); ball.h = 0; return; }
    touching.moved += d; touching.lx = x; touching.ly = y;
    if (touching.moved > 30) {
      // Vuốt ve
      if (a.st !== 'petted') { set('petted', 1.5); a.tgt = null; startPurr(); }
      a.tm = 1.2;
      if (touching.moved > 70) {
        touching.moved = 31;
        hearts(x, y - 20, 1);
        pet.happy = clamp(pet.happy + 1.5); pet.xp += .4;
        if (Math.random() < .12) speak();
      }
    }
  });
  const up = () => {
    if (scrubbing) { scrubbing = false; return; }
    if (follow) { follow = null; if (a.st === 'walk' || a.st === 'follow') set('sit', 2.5); return; }
    if (!touching) return;
    const tc = touching; touching = null;
    if (tc.ball) { throwBall(tc.vx / W * 18, -Math.abs(tc.vy) / H * 14 - .2, .9); return; }
    if (a.st === 'petted') { stopPurr(); save(); if (pet.happy > 80 && Math.random() < .4) say(voice('petLove')); set('idle', 1); return; }
    if (time - tc.t < .4) tap();
  };
  cv.addEventListener('pointerup', up);
  cv.addEventListener('pointercancel', up);

  function tap() {
    taps = taps.filter(x => time - x < 1.4); taps.push(time);
    a.tgt = null;
    if (taps.length >= 3) { taps = []; set('roll', 1); sfx('jump'); speak(); hearts(anchors.top[0], anchors.top[1], 4, 'Sparkles'); gain({happy: 6}, 2); return; }
    const r = Math.random();
    a.f = 1;
    if (r < .4) { set('react', .8); a.P.jump = .35; speak(); }
    else if (r < .7) { set('react', 1.1); a.P.tongue = 1; a.P.happy = 1; sfx('pop'); hearts(anchors.top[0], anchors.top[1], 2); }
    else { set('react', 1); speak(); a.P.headRot = .3; }
    gain({happy: 3}, 1);
  }

  // ---------- Tắm ----------
  function scrub(x, y) {
    if (!onPet(x, y) || foamProg >= 100) return;
    foamProg += 1.2;
    if (Math.random() < .35 && a.foam.length < 22) {
      const len = anchors.len, f = a.f;
      a.foam.push([Math.max(-.5, Math.min(.5, (x - anchors.body[0]) * f / len)), Math.max(-.8, Math.min(.5, (y - anchors.body[1]) / (len * .5))), rand(.06, .12)]);
      if (Math.random() < .4) sfx('pop');
    }
    if (Math.random() < .2) float(x, y, 'Bubbles', {vy: -40, size: rand(18, 30)});
    if (foamProg >= 100 && !tray.querySelector('.rinse')) {
      tray.replaceChildren(h('button', {class: 'btn blue rinse', onclick: rinse}, '🚿 ', t('petRinse')));
    }
  }
  function rinse() {
    tray.replaceChildren();
    let n = 0;
    const iv = setInterval(() => {
      if (!alive) return clearInterval(iv);
      for (let k = 0; k < 4; k++) float(anchors.body[0] + rand(-anchors.len * .6, anchors.len * .6), anchors.top[1] - 60, 'Droplet', {vy: 260, size: 18, g: 400, life: .8});
      if (n % 4 === 0) sfx('splash');
      if (++n > 22) {
        clearInterval(iv);
        a.foam = []; foamProg = 0;
        gain({clean: 100, happy: 6}, 8);
        sayPhrase('petClean');
        // Nhảy ra khỏi chậu và lắc mình cho khô
        a.P.jump = .6; set('shake', 1.6); a.x = Math.min(.9, tub.x + .16);
        tub = null; mode = 'home'; setActive();
      }
    }, 70);
  }

  // ---------- Vòng lặp ----------
  function update(dt) {
    time += dt;
    const P = a.P;
    // Chớp mắt
    blinkT -= dt;
    if (blinkT < 0) { P.blink = 1; if (blinkT < -.12) { P.blink = 0; blinkT = rand(2, 5); } }
    // Theo ngón tay
    if (follow && !busy()) {
      const dx = follow.x - a.x, dz = follow.z - a.z;
      if (Math.hypot(dx, dz * .6) > .06) { a.tgt = {x: follow.x - Math.sign(dx) * .05, z: follow.z}; a.speed = kind.id === 'cat' ? .42 : .38; a.onArrive = null; a.st = 'walk'; }
      else if (kind.id === 'cat' && a.st !== 'pounce') { set('pounce', .7); P.jump = .45; sfx('jump'); }
      else if (a.st === 'walk') set('look', .5);
    }
    // Đi tới đích
    if (a.tgt && a.st === 'walk') {
      const dx = a.tgt.x - a.x, dz = a.tgt.z - a.z, d = Math.hypot(dx, dz);
      const v = a.speed * dt;
      if (d <= v || d < .005) {
        a.x = a.tgt.x; a.z = a.tgt.z; a.tgt = null;
        const fn = a.onArrive; a.onArrive = null;
        if (fn) fn(); else set('idle', rand(1, 2));
      } else {
        a.x += dx / d * v; a.z += dz / d * v;
        if (Math.abs(dx) > .01) a.f = dx > 0 ? 1 : -1;
        P.phase += v * 38 / Math.max(.6, kz(a.z));
      }
    }
    // Bóng: lăn trên sàn, nảy, chậm dần.
    if (ball && !ball.held) {
      ball.vh -= 3.2 * dt; ball.h += ball.vh * dt;
      if (ball.h < 0) { ball.h = 0; if (Math.abs(ball.vh) > .4) sfx('pop'); ball.vh = -ball.vh * .45; if (Math.abs(ball.vh) < .15) ball.vh = 0; }
      ball.x += ball.vx * dt; ball.z += ball.vz * dt;
      const fr = ball.h > 0 ? .995 : Math.pow(.25, dt);
      ball.vx *= fr; ball.vz *= fr;
      if (ball.x < .05 || ball.x > .95) { ball.vx *= -.6; ball.x = Math.max(.05, Math.min(.95, ball.x)); }
      if (ball.z < 0 || ball.z > 1) { ball.vz *= -.6; ball.z = Math.max(0, Math.min(1, ball.z)); }
      // Bóng dừng mà bạn ấy đang đuổi chỗ cũ: cập nhật đích
      if (a.st === 'walk' && a.speed >= .5 && a.tgt) { a.tgt.x = ball.x - .05 * Math.sign(ball.x - a.x || 1); a.tgt.z = ball.z; }
    }
    if (ball && ball.held && anchors.mouth) { /* bóng theo miệng, vẽ ở draw */ }
    // Trạng thái
    a.tm -= dt;
    const T = {walk: 0, sit: 0, lie: 0, dip: 0, sleep: 0, happy: 0, sad: 0, crouch: 0, tongue: 0, headRot: 0, roll: 0, bath: 0, shake: 0, earUp: 0, squash: 0};
    const low = urgent();
    T.sad = low && !['petted', 'react', 'roll', 'eat', 'drink'].includes(a.st) ? .7 : 0;
    T.tailAmp = pet.happy > 70 ? .7 : pet.happy > 40 ? .4 : .15; T.tailSpeed = pet.happy > 70 ? 14 : 6;
    switch (a.st) {
      case 'walk': T.walk = a.speed > .35 ? 1 : .8; T.tailAmp = .6; break;
      case 'sit': T.sit = 1; if (a.tm <= 0) decide(); break;
      case 'look': T.sit = 1; T.happy = pet.happy > 70 ? 1 : 0; T.tailAmp = .9; T.tailSpeed = 16; T.headRot = Math.sin(time * 2) * .12; if (a.tm <= 0) decide(); break;
      case 'lie': T.lie = 1; if (a.tm <= 0) decide(); break;
      case 'sniff': T.dip = .55 + Math.sin(time * 12) * .08; T.walk = .3; a.x += a.f * .02 * dt; P.phase += dt * 3; if (a.tm <= 0) decide(); break;
      case 'hop': T.happy = 1; T.tailAmp = 1; T.tailSpeed = 18; if (Math.floor(a.tm * 3) !== Math.floor((a.tm + dt) * 3)) { P.jump = .35; } if (a.tm <= 0) decide(); break;
      case 'beg': T.sit = 1; T.sad = 1; if (a.tm <= 0) { a.bubble = null; decide(); } break;
      case 'scratch': T.sit = 1; T.headRot = .3; P.phase += dt * 25; T.walk = .3; if (Math.random() < dt * 3) float(anchors.body[0], anchors.body[1], 'Sparkles', {size: 16}); if (a.tm <= 0) decide(); break;
      case 'eat': case 'drink': {
        T.dip = 1; T.happy = .4; P.mouth = Math.max(0, Math.sin(time * 14)) * .8; T.tongue = a.st === 'drink' ? Math.max(0, Math.sin(time * 10)) : 0;
        if (a.tm <= 0) {
          const b = a.st === 'eat' ? bowlF : bowlW;
          if (b.n > 0) {
            b.n--; a.tm = 1.1;
            if (a.st === 'eat') { sfx('eat'); gain({food: 14, happy: 2}, 3); float(anchors.mouth[0], anchors.mouth[1] - 10, 'Sparkles', {size: 20}); }
            else { sfx('splash'); gain({water: 18}, 2); float(anchors.mouth[0], anchors.mouth[1], 'Droplet', {size: 16, vy: -40}); }
          }
          if (b.n <= 0 || pet[a.st === 'eat' ? 'food' : 'water'] >= 99) {
            P.mouth = 0; set('react', 1); P.tongue = 1; T.happy = 1; P.jump = .25;
            if (a.st === 'eat' || Math.random() < .5) sayPhrase(a.st === 'eat' ? 'petYum' : 'petDrink');
          }
        }
        break;
      }
      case 'sleep': {
        T.lie = 1; T.sleep = 1; T.tailAmp = .05; pet.sleeping = true;
        if (Math.random() < dt * .8) { float(anchors.top[0] + 20, anchors.top[1], 'Zzz', {vy: -30, size: 30, life: 2}); }
        if (Math.random() < dt * .3) sfx('snore');
        pet.energy = clamp(pet.energy + dt * 4);
        if (pet.energy >= 100 || a.tm <= 0) { pet.sleeping = false; set('wake', 1.2); gain({}, 3); }
        break;
      }
      case 'wake': T.sit = 1; P.mouth = Math.max(0, Math.sin((1.2 - a.tm) * 3)); pet.sleeping = false; if (a.tm <= 0) { P.mouth = 0; speak(); decide(); } break;
      case 'petted': T.happy = 1; T.sit = .6; T.tailAmp = 1; T.tailSpeed = 16; T.headRot = -.15; if (a.tm <= 0) { stopPurr(); set('idle', 1); } break;
      case 'react': T.happy = P.tongue > .3 ? 1 : T.happy; if (a.tm <= 0) { P.tongue = 0; decide(); } break;
      case 'roll': T.roll = Math.min(1, 1 - a.tm); T.happy = 1; if (a.tm <= 0) { P.roll = 0; set('react', .6); P.jump = .3; } break;
      case 'pounce': T.crouch = a.tm > .45 ? 1 : 0; T.happy = 1; if (a.tm <= 0) set(follow ? 'look' : 'idle', .5); break;
      case 'carry': case 'tub': T.bath = a.st === 'tub' ? 1 : 0; T.sit = a.st === 'tub' ? .3 : 0; T.happy = a.st === 'tub' && a.foam.length > 6 ? 1 : 0; break;
      case 'shake': T.shake = 1; T.happy = 1; if (Math.random() < dt * 25) float(anchors.body[0] + rand(-40, 40), anchors.body[1], 'Droplet', {vx: rand(-160, 160), vy: rand(-160, -40), g: 500, size: 14, life: .7}); if (a.tm <= 0) { set('hop', 1); speak(); } break;
      default: if (a.tm <= 0) decide();
    }
    if (a.st === 'carry') T.walk = 1;
    easePose(P, T, dt, a.st === 'roll' ? 30 : 7);
    // Nhảy: rơi tự nhiên
    if (P.jump > 0) { P.jumpV = (P.jumpV ?? 0); }
    P.jump = Math.max(0, P.jump - dt * 1.4 * (P.jump > .2 ? 1 : 1.6));
    if (a.st !== 'eat' && a.st !== 'drink' && a.st !== 'wake' && P.mouth > 0 && a.st !== 'react') P.mouth = Math.max(0, P.mouth - dt * 2);
    // Nhìn theo ngón tay / bóng
    const look = ball && !ball.held ? ball.x : follow ? follow.x : .5;
    P.lookX += ((look - a.x) * a.f * 3 - P.lookX) * Math.min(1, dt * 4);
    P.lookX = Math.max(-1, Math.min(1, P.lookX));
    // Hạt hiệu ứng
    for (let i = parts.length - 1; i >= 0; i--) {
      const q = parts[i]; q.x += q.vx * dt; q.y += q.vy * dt; q.vy += q.g * dt; q.life -= dt;
      if (q.life <= 0) parts.splice(i, 1);
    }
    // Lưu và cập nhật thanh chỉ số định kỳ
    if (time - lastSave > 5) { lastSave = time; save(); }
    if (time - lastBars > 1) { lastBars = time; renderBars(); }
  }

  function drawRoom() {
    const ft = floorTop(), night = a.st === 'sleep';
    // Tường
    const wall = ctx.createLinearGradient(0, 0, 0, ft);
    if (mode === 'bath') { wall.addColorStop(0, '#d0ebff'); wall.addColorStop(1, '#e7f5ff'); }
    else { wall.addColorStop(0, '#ffe3ec'); wall.addColorStop(1, '#fff0f6'); }
    ctx.fillStyle = wall; ctx.fillRect(0, 0, W, ft);
    ctx.fillStyle = mode === 'bath' ? 'rgba(255,255,255,.6)' : 'rgba(255,192,214,.35)';
    if (mode === 'bath') { for (let y = 20; y < ft; y += 34) ctx.fillRect(0, y, W, 2); for (let x = 0; x < W; x += 34) ctx.fillRect(x, 0, 2, ft); }
    else for (let x = 0; x < W; x += 80) ctx.fillRect(x, 0, 40, ft);
    // Cửa sổ: ngày/đêm
    const wx = W * .1, wy = H * .08, ww = Math.min(W * .2, 150), wh = ww * .8;
    ctx.fillStyle = '#fff'; roundRect(ctx, wx - 8, wy - 8, ww + 16, wh + 16, 14); ctx.fill();
    const sky = ctx.createLinearGradient(0, wy, 0, wy + wh);
    sky.addColorStop(0, night ? '#1b1f4b' : '#74c0fc'); sky.addColorStop(1, night ? '#3b3f8f' : '#d0ebff');
    ctx.fillStyle = sky; roundRect(ctx, wx, wy, ww, wh, 8); ctx.fill();
    drawSprite(ctx, night ? 'Crescent moon' : 'Sun', wx + ww * .7, wy + wh * .35, ww * .32);
    ctx.fillStyle = '#fff'; ctx.fillRect(wx + ww / 2 - 3, wy, 6, wh); ctx.fillRect(wx, wy + wh / 2 - 3, ww, 6);
    if (mode !== 'bath') drawSprite(ctx, 'Framed picture', W * .8, H * .18, Math.min(W * .14, 100));
    // Sàn
    const fl = ctx.createLinearGradient(0, ft, 0, H);
    fl.addColorStop(0, mode === 'bath' ? '#a5d8ff' : '#e8c39e'); fl.addColorStop(1, mode === 'bath' ? '#d0ebff' : '#f3d5b5');
    ctx.fillStyle = fl; ctx.fillRect(0, ft, W, H - ft);
    ctx.strokeStyle = 'rgba(0,0,0,.06)'; ctx.lineWidth = 2;
    for (let k = -6; k <= 12; k++) { ctx.beginPath(); ctx.moveTo(W / 2 + k * 60, ft); ctx.lineTo(W / 2 + k * 140 - W * .3, H); ctx.stroke(); }
    ctx.fillStyle = 'rgba(0,0,0,.08)'; ctx.fillRect(0, ft - 4, W, 6);
    if (mode !== 'bath') {
      // Thảm tròn
      ctx.fillStyle = 'rgba(255,146,170,.35)'; ctx.beginPath(); ctx.ellipse(W * .5, sy(.62), W * .26, (H - ft) * .2, 0, 0, 7); ctx.fill();
      drawSprite(ctx, 'Potted plant', W * .94, sy(0) - H * .05, Math.min(W * .12, 90));
    }
  }

  // Đệm ngủ, bát ăn, bát nước, chậu tắm (vẽ theo chiều sâu cùng thú cưng).
  function drawThings(list) {
    for (const it of list) it.draw();
  }
  const bedDraw = () => {
    const x = bed.x * W, y = sy(bed.z), s = unit(bed.z) * 1.1;
    ctx.fillStyle = '#9775fa'; ctx.beginPath(); ctx.ellipse(x, y, s * .75, s * .24, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#b197fc'; ctx.beginPath(); ctx.ellipse(x, y - s * .05, s * .62, s * .17, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#e5dbff'; ctx.beginPath(); ctx.ellipse(x, y - s * .06, s * .5, s * .11, 0, 0, 7); ctx.fill();
  };
  const bowlDraw = (b, color, filled) => () => {
    const x = b.x * W, y = sy(b.z), s = unit(b.z) * .42;
    ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.beginPath(); ctx.ellipse(x, y + 3, s * .62, s * .14, 0, 0, 7); ctx.fill();
    ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(x - s * .6, y - s * .3); ctx.lineTo(x + s * .6, y - s * .3); ctx.lineTo(x + s * .45, y); ctx.lineTo(x - s * .45, y); ctx.closePath(); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.35)'; ctx.fillRect(x - s * .5, y - s * .22, s, s * .06);
    if (b.n > 0) filled(x, y - s * .3, s, b.n);
    else { ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.beginPath(); ctx.ellipse(x, y - s * .3, s * .58, s * .1, 0, 0, 7); ctx.fill(); }
  };
  const foodFill = (x, y, s, n) => { for (let k = 0; k < n + 1; k++) drawSprite(ctx, bowlF.food, x + (k - n / 2) * s * .3, y - s * .1, s * .5); };
  const waterFill = (x, y, s, n) => { ctx.fillStyle = '#4dabf7'; ctx.beginPath(); ctx.ellipse(x, y, s * .58, s * (.06 + n * .02), 0, 0, 7); ctx.fill(); ctx.fillStyle = 'rgba(255,255,255,.6)'; ctx.beginPath(); ctx.ellipse(x - s * .2, y - s * .02, s * .12, s * .03, 0, 0, 7); ctx.fill(); };
  const drawBall = () => {
    if (!ball) return;
    let bx, by, s = unit(ball.z) * .3;
    if (ball.held && anchors.mouth) { bx = anchors.mouth[0] + a.f * s * .3; by = anchors.mouth[1] + s * .2; }
    else {
      bx = ball.x * W; by = sy(ball.z) - ball.h * H * .5 - s * .5;
      ctx.fillStyle = 'rgba(0,0,0,.15)'; ctx.beginPath(); ctx.ellipse(bx, sy(ball.z), s * .5 * (1 - Math.min(.5, ball.h)), s * .14, 0, 0, 7); ctx.fill();
    }
    drawSprite(ctx, kind.toy, bx, by, s, s, {rot: ball.x * 30});
  };
  const tubBack = () => {
    const x = tub.x * W, y = sy(tub.z), s = unit(tub.z);
    ctx.fillStyle = '#e7f5ff'; ctx.beginPath(); ctx.ellipse(x, y - s * .38, s * .72, s * .16, 0, 0, 7); ctx.fill();
    ctx.fillStyle = '#74c0fc'; ctx.beginPath(); ctx.ellipse(x, y - s * .36, s * .64, s * .12, 0, 0, 7); ctx.fill();
  };
  const tubFront = () => {
    const x = tub.x * W, y = sy(tub.z), s = unit(tub.z);
    ctx.fillStyle = '#fff'; ctx.beginPath();
    ctx.moveTo(x - s * .72, y - s * .38); ctx.quadraticCurveTo(x - s * .7, y, x - s * .4, y); ctx.lineTo(x + s * .4, y); ctx.quadraticCurveTo(x + s * .7, y, x + s * .72, y - s * .38);
    ctx.quadraticCurveTo(x, y - s * .22, x - s * .72, y - s * .38); ctx.fill();
    ctx.strokeStyle = '#a5d8ff'; ctx.lineWidth = 3; ctx.stroke();
    for (let k = 0; k < 6; k++) drawSprite(ctx, 'Bubbles', x - s * .55 + k * s * .22, y - s * .36 + Math.sin(time * 2 + k) * 3, s * .2);
  };

  function draw() {
    ctx.clearRect(0, 0, W, H);
    drawRoom();
    const s = unit(a.z);
    // Sắp các vật theo chiều sâu z.
    const objs = [
      {z: bed.z, draw: bedDraw},
      {z: bowlF.z, draw: bowlDraw(bowlF, '#ff6b6b', foodFill)},
      {z: bowlW.z, draw: bowlDraw(bowlW, '#4dabf7', waterFill)},
      {z: a.z + .001, draw: () => {
        if (tub) tubBack();
        const inTub = a.st === 'tub' && tub;
        const y = sy(a.z) - (inTub ? s * .25 : 0);
        const an = drawPet(ctx, kind.id, a.x * W, y, a.P, {u: s, t: time, f: a.f, wear: pet.wear || {}, dirty: pet.clean < 40 ? (40 - pet.clean) / 30 : 0, foam: a.foam});
        Object.assign(anchors, an);
        if (inTub) tubFront();
      }}
    ];
    if (ball && !ball.held) objs.push({z: ball.z, draw: drawBall});
    objs.sort((x, y) => x.z - y.z).forEach(o => o.draw());
    if (ball && ball.held) drawBall();
    // Bong bóng suy nghĩ: đang cần gì
    const need = a.bubble || (['idle', 'sit', 'lie'].includes(a.st) ? urgent() : null);
    if (need && a.st !== 'sleep' && anchors.top) {
      const bx = anchors.top[0] + s * .35 * a.f, by = anchors.top[1] - s * .25 + Math.sin(time * 2) * 4;
      drawSprite(ctx, 'Thought balloon', bx, by, s * .55);
      drawSprite(ctx, need === 'food' ? kind.foods[0] : STATS.find(x => x[0] === need)[1], bx, by - s * .04, s * .26);
    }
    // Ban đêm khi ngủ
    if (a.st === 'sleep') { ctx.fillStyle = 'rgba(20,24,70,.38)'; ctx.fillRect(0, 0, W, H); }
    for (const q of parts) drawSprite(ctx, q.im, q.x, q.y, q.size, q.size, {alpha: Math.min(1, q.life / q.max * 2)});
    if (mode === 'bath' && a.st === 'tub' && foamProg < 100) {
      const w = Math.min(260, W * .5);
      ctx.fillStyle = 'rgba(0,0,0,.25)'; roundRect(ctx, W / 2 - w / 2, 12, w, 18, 9); ctx.fill();
      ctx.fillStyle = '#74c0fc'; roundRect(ctx, W / 2 - w / 2 + 3, 15, (w - 6) * foamProg / 100, 12, 6); ctx.fill();
    }
  }

  // Tạm dừng khi ẩn app (theo sự kiện, vì vài trình duyệt báo document.hidden sai lúc mới mở).
  let last = performance.now(), paused = false;
  const onVis = () => { paused = document.visibilityState === 'hidden'; last = performance.now(); };
  document.addEventListener('visibilitychange', onVis);
  const frame = now => {
    if (!alive || !root.isConnected) { alive = false; ro.disconnect(); stopPurr(); save(); document.removeEventListener('visibilitychange', onVis); return; }
    const dt = Math.min(.05, (now - last) / 1000); last = now;
    if (!paused) { update(dt); draw(); }
    requestAnimationFrame(frame);
  };

  // ---------- Thanh chỉ số ----------
  const ICON = {food: kind.foods[0]};
  function renderBars() {
    lv = levelOf(pet);
    lvEl.textContent = `· ${t('level')} ${lv}`;
    bars.replaceChildren(...STATS.map(([k, icon]) => {
      const v = Math.round(pet[k]);
      return h('div', {class: `pbar ${v < 35 ? 'low' : ''}`}, img(ICON[k] || icon), h('i', {}, h('b', {style: {width: v + '%'}})));
    }), h('div', {class: 'pbar xp'}, img('Glowing star'), h('i', {}, h('b', {style: {width: lv >= MAX_LV ? '100%' : ((pet.xp % XP_PER_LV) / XP_PER_LV * 100) + '%'}}))));
  }

  // ---------- Nút hành động ----------
  const ACTIONS = [
    ['feed', kind.foods[0], t('petFeed')], ['water', 'Droplet', t('petWater')], ['bath', 'Bathtub', t('petBath')],
    ['play', kind.toy, t('petPlay')], ['sleep', 'Crescent moon', t('petSleep')], ['wear', 'Ribbon', t('petWear')]
  ];
  function setActive() {
    actions.querySelectorAll('.pact').forEach(b => b.classList.toggle('on', b.dataset.m === mode));
    if (mode === 'home') tray.replaceChildren(h('span', {class: 'note pettip'}, t('petTip')));
  }
  function setMode(m) {
    if (mode === 'bath' && m !== 'bath') { tub = null; a.foam = []; foamProg = 0; if (a.st === 'tub') set('idle', .5); }
    mode = m; tray.replaceChildren();
    if (m === 'feed') feedTray();
    else if (m === 'play') playTray();
    else if (m === 'wear') wearTray();
    else if (m === 'bath') startBath();
    if (m !== 'play' && ball && !ball.held) ball = null;
    setActive();
  }
  actions.replaceChildren(...ACTIONS.map(([m, im, label]) => h('button', {class: 'pact', 'data-m': m, onclick: () => {
    sfx('tap');
    if (m === 'water') return giveWater();
    if (m === 'sleep') return goSleep();
    setMode(mode === m ? 'home' : m);
  }}, img(im), h('span', {}, label))));

  function feedTray() {
    tray.replaceChildren(...kind.foods.map(f => h('button', {class: 'food', onclick: () => {
      if (pet.food >= 95) { a.P.headRot = -.3; set('react', .6); say(voice('petFull')); return; }
      bowlF.food = f; bowlF.n = 3; sfx('pop');
      float(bowlF.x * W, sy(bowlF.z) - 40, 'Sparkles', {size: 26});
      if (a.st === 'sleep') return;
      a.bubble = null; speak();
      goTo(bowlF.x - .07, bowlF.z + .04, .4, () => { a.f = 1; set('eat', .5); });
    }}, img(f))));
  }
  function giveWater() {
    if (pet.water >= 95) { set('react', .6); a.P.headRot = -.3; return; }
    bowlW.n = 3; sfx('splash');
    float(bowlW.x * W, sy(bowlW.z) - 40, 'Droplet', {size: 22});
    if (a.st === 'sleep') return;
    a.bubble = null;
    goTo(bowlW.x - .07, bowlW.z + .04, .4, () => { a.f = 1; set('drink', .5); });
  }
  function playTray() {
    ball = {x: .5, z: .97, h: 0, vx: 0, vz: 0, vh: 0, held: false};
    tray.replaceChildren(h('button', {class: 'toy', onclick: () => throwBall(rand(-.6, .6), rand(-1.1, -.6), 1.1)}, img(kind.toy)),
      h('span', {class: 'note'}, t('petPlayTip')));
    if (pet.energy < 15) { say(voice('petSleepy')); return; }
    a.P.earUp = 1; speak();
  }
  function startBath() {
    tub = {x: .5, z: .55};
    a.foam = []; foamProg = 0;
    sayPhrase('petScrub');
    tray.replaceChildren(h('div', {class: 'sponge-tip'}, img('Sponge'), ' ', t('petScrubTip')));
    goTo(tub.x, tub.z, .3, () => { set('tub'); sfx('splash'); a.f = 1; });
  }
  function goSleep() {
    if (a.st === 'sleep') { set('wake', 1.2); pet.sleeping = false; return; }
    setMode('home');
    say(voice('petNight'));
    goTo(bed.x, bed.z + .02, .34, () => { a.f = 1; set('sleep', 40); });
  }
  function wearTray() {
    tray.replaceChildren(...data.petItems.map(it => {
      const open = lv >= it.lv, on = (pet.wear || {})[it.slot] === it.img;
      return h('button', {class: `witem ${open ? '' : 'locked'} ${on ? 'on' : ''}`, onclick: () => {
        if (!open) { sfx('wrong'); toast(`${t('level')} ${it.lv}`); return; }
        pet.wear = {...(pet.wear || {})};
        if (on) delete pet.wear[it.slot]; else pet.wear[it.slot] = it.img;
        sfx('pop'); save(); wearTray(); set('look', 2); a.P.happy = 1;
      }}, img(it.img), open ? null : h('span', {class: 'wlock'}, '🔒 ', it.lv));
    }));
  }

  renderBars(); setActive();
  loadAll([...SPRITES, ...kind.foods, kind.toy, ...data.petItems.map(i => i.img)]).then(() => requestAnimationFrame(n => { last = n; frame(n); }));
  // Chào bé khi vào phòng
  const need = urgent();
  a.x = .5; a.z = .7;
  if (need) {
    const key = {food: 'petHungry', water: 'petThirsty', clean: 'petDirty', energy: 'petSleepy', happy: 'petSad'}[need];
    setTimeout(() => { if (!alive || !root.isConnected) return; speak(true); say(voice(key)); }, 600);
  } else setTimeout(() => { if (!alive || !root.isConnected) return; speak(); a.P.jump = .4; set('look', 2.5); say(voice('petLove')); }, 600);
}

// ---- Nhận nuôi: mỗi thẻ có con vật động chạy tại chỗ ----
function adopt(root, data, done, onExit) {
  sayPhrase('petPick');
  let alive = true;
  const minis = [];
  root.replaceChildren(
    h('div', {class: 'topbar'}, h('button', {class: 'icon-btn', onclick: () => { alive = false; onExit(); }}, '⬅️'), h('h1', {}, t('petAdopt')), h('span', {class: 'spacer'})),
    h('div', {class: 'adopt'}, data.pets.map(k => {
      const c = h('canvas', {class: 'adopt-cv', width: 320, height: 260});
      minis.push({c, k: k.id, P: newPose(), ph: rand(0, 6)});
      return h('button', {class: 'adopt-card', onclick: () => { alive = false; nameIt(k); }}, c, h('b', {}, L(k)));
    })));
  let last = performance.now(), tt = 0;
  const loop = now => {
    if (!alive || !root.isConnected) return;
    const dt = Math.min(.05, (now - last) / 1000); last = now; tt += dt;
    for (const m of minis) {
      const ctx = m.c.getContext('2d');
      ctx.clearRect(0, 0, 320, 260);
      const cyc = (tt + m.ph) % 6;
      easePose(m.P, {sit: cyc > 3.5 ? 1 : 0, happy: cyc > 4.5 ? 1 : 0, tailAmp: .8, tailSpeed: 12}, dt, 5);
      if (cyc < 3.5) m.P.phase += dt * 9;
      m.P.walk += ((cyc < 3.5 ? 1 : 0) - m.P.walk) * Math.min(1, dt * 5);
      if (Math.random() < dt * .3) m.P.blink = 1; else m.P.blink *= .7;
      drawPet(ctx, m.k, 160, 232, m.P, {u: 106, t: tt + m.ph, f: 1});
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  function nameIt(k) {
    clip((VOICE[k.id] || VOICE.dog).talk[0], {rate: (VOICE[k.id] || VOICE.dog).rate}).then(ok => { if (!ok) sfx(k.sound); });
    say(tpl('petHello', {p: k.p}));
    let name = k.names[0];
    const input = h('input', {class: 'name-input', maxlength: 14, value: name});
    input.addEventListener('input', () => { name = input.value.trim(); });
    const c = h('canvas', {class: 'adopt-cv big', width: 360, height: 280});
    const P = newPose();
    let on = true, l2 = performance.now(), t2 = 0;
    const spin = now => {
      if (!on || !c.isConnected) return;
      const dt = Math.min(.05, (now - l2) / 1000); l2 = now; t2 += dt;
      easePose(P, {sit: 1, happy: Math.sin(t2) > .3 ? 1 : 0, tailAmp: 1, tailSpeed: 16}, dt, 5);
      if (Math.random() < dt * .3) P.blink = 1; else P.blink *= .7;
      const ctx = c.getContext('2d'); ctx.clearRect(0, 0, 360, 280);
      drawPet(ctx, k.id, 180, 266, P, {u: 146, t: t2, f: 1});
      requestAnimationFrame(spin);
    };
    requestAnimationFrame(spin);
    root.replaceChildren(
      h('div', {class: 'topbar'}, h('button', {class: 'icon-btn', onclick: () => { on = false; adopt(root, data, done, onExit); }}, '⬅️'), h('h1', {}, t('petName')), h('span', {class: 'spacer'})),
      h('div', {class: 'center-col'}, c, input,
        h('div', {class: 'chips'}, k.names.map(n => h('button', {class: 'small-btn', onclick: () => { input.value = n; name = n; sfx('tap'); }}, n))),
        h('button', {class: 'btn green big', onclick: () => {
          if (!name) return;
          on = false;
          const p = store.profile();
          p.pet = {type: k.id, name, xp: 0, food: 70, water: 70, clean: 80, happy: 80, energy: 90, last: Date.now(), wear: {}};
          store.save(); confetti(); sfx('win');
          done();
        }}, '❤️ ', t('petAdoptBtn'))));
  }
}
