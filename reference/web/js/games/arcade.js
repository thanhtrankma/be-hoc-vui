// Đảo Trò chơi nhanh: bắn bóng bay (chữ, số, dấu thanh, tiếng Anh) và đua xe tính nhẩm.
import {h, img, sample, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sayPhrase, sfx} from '../audio.js?v=4c51d34a6e';
import {placeTone as toned} from './spell.js?v=4c51d34a6e';
import {starsFor} from './quiz.js?v=4c51d34a6e';
import {sheet} from './funfx.js?v=4c51d34a6e';
import {drawFrame} from './sheets.js?v=4c51d34a6e';

// Xe đua nhìn từ trên (Kenney Racing Pack) vẽ vào canvas, đầu xe quay trái (CSS .car lật lại sang phải).
function carCanvas(frame, fallback) {
  const cv = h('canvas', {width: 260, height: 150, style: {width: '100%', display: 'block'}});
  sheet('racing/racing').then(sh => {
    if (!sh || !sh.frames[frame]) { cv.replaceWith(img(fallback, {photo: false})); return; }
    drawFrame(cv.getContext('2d'), sh, frame, 130, 75, 236, {rot: -Math.PI / 2});
  });
  return cv;
}

const GOAL = 8;
const COLORS = ['#ff6b6b', '#ff922b', '#fcc419', '#51cf66', '#22b8cf', '#4c6ef5', '#9775fa', '#f06595'];
const TONES = ['ngang', 'huyền', 'sắc', 'hỏi', 'ngã', 'nặng'];

// Mỗi chế độ: tạo mục tiêu {id, say, label|img} và danh sách nhãn nhiễu.
function target(mode, content) {
  if (mode === 'letters') {
    const L = sample(content.letters, 1)[0];
    return {id: L.ch, say: tpl('findLetter', L), make: () => sample(content.letters, 1)[0].ch, face: x => x};
  }
  if (mode === 'numbers') {
    const n = Math.floor(Math.random() * 21);
    return {id: String(n), say: tpl('findNum', content.nums[n]), make: () => String(Math.floor(Math.random() * 21)), face: x => x};
  }
  if (mode === 'tones') {
    const w = sample(content.vnwords, 1)[0];
    return {id: w.w, say: tpl('vnWord', w), make: () => w.c + toned(w.v, sample(TONES, 1)[0]), face: x => x};
  }
  const set = [...content.en_animals, ...content.en_fruits];
  const it = sample(set, 1)[0];
  return {id: it.img, say: tpl('findEnThe', it), make: () => sample(set, 1)[0].img, face: x => img(x, {photo: false})};
}

function balloon(g, lv, content) {
  const sky = h('div', {class: 'bsky'});
  const promptBtn = h('button', {class: 'prompt-btn bprompt'}, h('span', {class: 'spk'}, '🔊'));
  g.stage.replaceChildren(h('div', {class: 'barena'}, promptBtn, sky));
  g.progress(0, GOAL);
  let hits = 0, mistakes = 0, tgt = null, alive = true, speed = 1, raf = 0, spawnT = 0, sinceTarget = 0;
  const balloons = new Set();
  const newTarget = () => { tgt = target(lv.mode, content); sinceTarget = 0; say(tgt.say); };
  promptBtn.onclick = () => tgt && say(tgt.say);

  function spawn() {
    // Bảo đảm mục tiêu xuất hiện đều: tối đa 3 quả nhiễu liền nhau.
    const isT = sinceTarget >= 3 || Math.random() < .38;
    let id = isT ? tgt.id : tgt.make();
    if (!isT && id === tgt.id) id = tgt.make();
    sinceTarget = id === tgt.id ? 0 : sinceTarget + 1;
    const w = sky.clientWidth, size = Math.min(130, Math.max(86, w / 7));
    const b = h('button', {class: 'balloon', style: {'--c': COLORS[Math.floor(Math.random() * COLORS.length)], width: size + 'px', height: size * 1.2 + 'px'}},
      h('span', {class: 'bl'}, tgt.face(id)));
    const st = {el: b, id, x: Math.random() * (w - size), y: sky.clientHeight + 20, vy: (55 + Math.random() * 30) * speed, phase: Math.random() * 6};
    b.style.transform = `translate(${st.x}px, ${st.y}px)`;
    b.addEventListener('pointerdown', e => { e.preventDefault(); pop(st); });
    sky.append(b); balloons.add(st);
  }

  function pop(st) {
    if (!alive || !balloons.has(st)) return;
    if (st.id === tgt.id) {
      balloons.delete(st);
      st.el.classList.add('popped'); sfx('pop'); sfx('correct'); g.cheer();
      setTimeout(() => st.el.remove(), 300);
      hits++; g.progress(hits, GOAL);
      speed = 1 + hits * .09;
      if (hits >= GOAL) return finish();
      newTarget();
    } else {
      mistakes++; sfx('wrong'); g.sad();
      st.el.classList.remove('shake'); void st.el.offsetWidth; st.el.classList.add('shake');
    }
  }

  let last = performance.now(), resolveFn;
  function tick(now) {
    if (!alive || g.aborted()) { alive = false; return; }
    const dt = Math.min(.05, (now - last) / 1000); last = now;
    spawnT -= dt;
    if (spawnT <= 0) { spawn(); spawnT = 1.15 / speed; }
    for (const st of balloons) {
      st.y -= st.vy * dt; st.phase += dt * 2;
      st.el.style.transform = `translate(${st.x + Math.sin(st.phase) * 10}px, ${st.y}px)`;
      if (st.y < -200) { balloons.delete(st); st.el.remove(); }
    }
    raf = requestAnimationFrame(tick);
  }
  async function finish() {
    alive = false; cancelAnimationFrame(raf);
    for (const st of balloons) st.el.classList.add('popped');
    await wait(600);
    resolveFn({stars: starsFor(Math.max(0, mistakes - 1))});
  }
  return new Promise(async resolve => {
    resolveFn = resolve;
    await sayPhrase('balloonQ');
    newTarget();
    raf = requestAnimationFrame(t => { last = t; tick(t); });
  });
}

// ---------- Đua xe ----------
function raceQ(lv, content) {
  const kind = lv.mode === 'mix' ? (Math.random() < .5 ? 'add' : 'sub') : lv.mode;
  const facts = (kind === 'add' ? content.addFacts : content.subFacts).filter(f => f.a >= 1 && f.b >= 1 && f.a <= lv.max && (kind === 'sub' || f.c <= lv.max));
  const f = sample(facts, 1)[0];
  const opts = new Set([f.c]);
  while (opts.size < 3) { const k = f.c + sample([-2, -1, 1, 2], 1)[0]; if (k >= 0 && k <= 10) opts.add(k); }
  return {text: `${f.a} ${kind === 'add' ? '+' : '−'} ${f.b}`, answer: f.c, choices: shuffle([...opts])};
}

function race(g, lv, content) {
  const STEPS = 10;
  const kidCar = h('div', {class: 'car kid'}, carCanvas('car_red_1', 'Racing car'), h('img', {src: g.buddySrc, class: 'driver', alt: ''}));
  // .bot trùng lớp robot của game Lập trình (css .bot đặt width/top theo lưới): ghi đè tại chỗ
  const botCar = h('div', {class: 'car bot', style: {width: 'clamp(80px, 12vw, 120px)', top: '50%', padding: '0', transition: 'left .35s ease-out'}}, carCanvas('car_blue_3', 'Police car'));
  const track = h('div', {class: 'track'},
    h('div', {class: 'lane'}, botCar), h('div', {class: 'lane'}, kidCar), h('div', {class: 'finish'}));
  const qEl = h('div', {class: 'eq rq'});
  const choices = h('div', {class: 'choices nums', style: {'--n': 3}});
  g.stage.replaceChildren(h('div', {class: 'race'}, track, qEl, choices));
  g.progress(0, STEPS);
  let kid = 0, bot = 0, mistakes = 0, alive = true, stall = 0;
  const place = () => {
    kidCar.style.left = `calc(${(kid / STEPS) * 88}% )`;
    botCar.style.left = `calc(${(Math.min(bot, STEPS) / STEPS) * 88}% )`;
  };
  place();
  // Xe máy chạy đều: cần ~5 giây mỗi bước (bài khó hơn chậm hơn chút).
  const botSpeed = 1 / (lv.max > 5 ? 5.6 : 4.6);
  return new Promise(async resolve => {
    await sayPhrase('raceIntro');
    let last = performance.now();
    const loop = now => {
      if (!alive || g.aborted()) return;
      const dt = Math.min(.1, (now - last) / 1000); last = now;
      bot += botSpeed * dt; place();
      if (bot >= STEPS) return end(false);
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    const next = () => {
      const q = raceQ(lv, content);
      qEl.textContent = q.text + ' = ?';
      choices.replaceChildren(...q.choices.map(c => {
        const b = h('button', {class: 'choice'}, h('span', {}, c));
        b.addEventListener('pointerdown', e => {
          e.preventDefault();
          if (!alive || performance.now() < stall) return;
          if (c === q.answer) {
            sfx('correct'); kid++; g.progress(kid, STEPS); place();
            kidCar.classList.remove('boost'); void kidCar.offsetWidth; kidCar.classList.add('boost');
            if (kid >= STEPS) return end(true);
            next();
          } else {
            mistakes++; sfx('wrong'); b.classList.add('wrong'); stall = performance.now() + 900;
          }
        });
        return b;
      }));
    };
    next();
    async function end(win) {
      if (!alive) return;
      alive = false;
      sfx(win ? 'win' : 'wrong');
      if (win) g.cheer(); else g.sad();
      await sayPhrase(win ? 'raceWin' : 'raceLose');
      resolve({stars: win ? (mistakes <= 2 ? 3 : 2) : 1});
    }
  });
}

export const levels = (island, content) => content.arcadeLevels.map(l => ({name: l.name, img: l.img}));

export function run(g, island, content, li) {
  const lv = content.arcadeLevels[li];
  g.hideBuddy();
  return lv.kind === 'race' ? race(g, lv, content) : balloon(g, lv, content);
}
