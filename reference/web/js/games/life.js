// Đảo Toán đời sống: siêu thị mini, dài–ngắn, cao–thấp, nặng–nhẹ, đo bằng kẹp giấy và thước, thứ trong tuần, xem lịch.
import {h, img, sample, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {tpl, phrase, say, sayPhrase, sfx, preload} from '../audio.js?v=4c51d34a6e';
import {t} from '../i18n.js?v=4c51d34a6e';
import {runQuiz, starsFor} from './quiz.js?v=4c51d34a6e';

const NS = 'http://www.w3.org/2000/svg';
const sv = (tag, attrs = {}, ...kids) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); e.append(...kids); return e; };
const praise = () => phrase('praise' + (1 + Math.floor(Math.random() * 6)));
const PENCIL_COLORS = ['#ff6b6b', '#4dabf7', '#51cf66', '#fcc419', '#9775fa', '#ff922b'];

// ---------- Siêu thị ----------
async function shop(g, lv, content) {
  const ROUND = 5;
  let mistakes = 0;
  await sayPhrase('shopIntro');
  for (let r = 0; r < ROUND; r++) {
    if (g.aborted()) return null;
    g.progress(r, ROUND);
    const who = sample(content.customers, 1)[0];
    const items = sample(content.shopItems, lv.types);
    const order = items.map(it => ({it, n: 1 + Math.floor(Math.random() * 5)}));
    const voice = order.map((o, k) => k === 0 ? tpl('shopOrder', {...who, ...content.shopNums[o.n - 1], ...o.it}) : tpl('shopAnd', {...content.shopNums[o.n - 1], ...o.it}));
    preload(voice);
    const basket = {};
    const basketEl = h('div', {class: 'basket-items'});
    const bubble = h('div', {class: 'bubble'}, order.map(o => h('span', {class: 'oitem'}, h('b', {}, o.n), img(o.it.img, {photo: false}))));
    const speakOrder = async () => { for (const v of voice) { if (g.aborted()) return; await say(v); } };
    const shelfItems = shuffle([...items, ...sample(content.shopItems.filter(x => !items.includes(x)), 4 - items.length)]);
    const shelf = h('div', {class: 'shelf'}, shelfItems.map(it => h('button', {class: 'sitem', onclick: () => {
      basket[it.id] = (basket[it.id] || 0) + 1; sfx('pop'); draw();
    }}, img(it.img, {photo: false}))));
    const deliver = h('button', {class: 'btn green'}, '🛍️ ', t('deliver'));
    const draw = () => basketEl.replaceChildren(...Object.entries(basket).filter(([, n]) => n > 0).flatMap(([id, n]) => {
      const it = content.shopItems.find(x => x.id === id);
      return Array.from({length: n}, () => h('button', {class: 'bitem', onclick: () => { basket[id]--; sfx('tap'); draw(); }}, img(it.img, {photo: false})));
    }));
    g.stage.replaceChildren(h('div', {class: 'shop'},
      h('div', {class: 'customer'}, h('button', {class: 'cust', onclick: speakOrder}, img(who.img, {photo: false})), bubble),
      shelf,
      h('div', {class: 'basket-row'}, h('div', {class: 'basket2'}, img('Shopping cart', {class: 'cart'}), basketEl), deliver)));
    speakOrder();
    await new Promise(resolve => {
      deliver.onclick = async () => {
        const ok = order.every(o => (basket[o.it.id] || 0) === o.n) &&
          Object.entries(basket).every(([id, n]) => n === 0 || order.some(o => o.it.id === id));
        if (ok) {
          sfx('correct'); g.cheer();
          bubble.replaceChildren('😊');
          await sayPhrase('shopThanks');
          resolve();
        } else {
          mistakes++; sfx('wrong'); g.sad();
          await sayPhrase('shopWrong');
        }
      };
    });
  }
  g.progress(ROUND, ROUND);
  return {stars: starsFor(mistakes)};
}

// ---------- Bút chì vẽ bằng SVG ----------
function pencil(len, color, unit = 30) {
  const L = len * unit;
  return sv('svg', {viewBox: `0 0 ${L + 4} 34`, width: L + 4, class: 'pencil-svg'},
    sv('rect', {x: 0, y: 6, width: L - 30, height: 22, rx: 4, fill: color}),
    sv('rect', {x: 0, y: 6, width: 12, height: 22, rx: 3, fill: '#ffa8a8'}),
    sv('rect', {x: 12, y: 6, width: 6, height: 22, fill: '#adb5bd'}),
    sv('polygon', {points: `${L - 30},6 ${L},17 ${L - 30},28`, fill: '#ffe8cc'}),
    sv('polygon', {points: `${L - 9},13.5 ${L},17 ${L - 9},20.5`, fill: '#343a40'}));
}

function lengthQ(content) {
  return Array.from({length: 6}, () => {
    const lens = sample([4, 5, 6, 7, 8, 9, 10, 11], 3);
    const longest = Math.random() < .5;
    const target = longest ? Math.max(...lens) : Math.min(...lens);
    const colors = sample(PENCIL_COLORS, 3);
    return {
      say: phrase(longest ? 'longest' : 'shortest', 'vi'), label: phrase(longest ? 'longest' : 'shortest', 'vi')[1],
      choices: lens.map((l, i) => ({id: l, node: () => pencil(l, colors[i])})), cls: 'pencils', cols: 1,
      answer: target, reward: praise()
    };
  });
}

function tower(n, color) {
  return h('div', {class: 'tower'}, Array.from({length: n}, () => h('i', {style: {background: color}})));
}

function heightQ() {
  return Array.from({length: 6}, () => {
    const hs = sample([2, 3, 4, 5, 6, 7, 8], 3);
    const tall = Math.random() < .5;
    const target = tall ? Math.max(...hs) : Math.min(...hs);
    const colors = sample(PENCIL_COLORS, 3);
    return {
      say: phrase(tall ? 'tallest' : 'lowest', 'vi'), label: phrase(tall ? 'tallest' : 'lowest', 'vi')[1],
      choices: hs.map((n, i) => ({id: n, node: () => tower(n, colors[i])})), cls: 'towers',
      answer: target, reward: praise()
    };
  });
}

// Cân đĩa: bé chọn bên nặng hơn, cân nghiêng để kiểm chứng.
function scale(a, b, tilt = 0) {
  const ang = tilt * 12;
  return h('div', {class: 'scale'},
    h('div', {class: 'beam', style: {transform: `rotate(${ang}deg)`}},
      h('div', {class: 'pan left', style: {transform: `rotate(${-ang}deg)`}}, img(a.img)),
      h('div', {class: 'pan right', style: {transform: `rotate(${-ang}deg)`}}, img(b.img))),
    h('div', {class: 'post'}));
}

async function weight(g, content) {
  const ROUND = 6;
  let mistakes = 0;
  for (let r = 0; r < ROUND; r++) {
    if (g.aborted()) return null;
    g.progress(r, ROUND);
    let a, b;
    do { [a, b] = sample(content.weights, 2); } while (Math.abs(a.w - b.w) < 2);
    const heavy = a.w > b.w ? 'a' : 'b';
    const wrap = h('div', {class: 'scale-wrap'}, scale(a, b));
    const btns = h('div', {class: 'choices', style: {'--n': 2}},
      [['a', a], ['b', b]].map(([k, it]) => h('button', {class: 'choice', 'data-k': k}, img(it.img))));
    g.stage.replaceChildren(h('button', {class: 'prompt-btn', onclick: () => sayPhrase('heavyQ')}, h('span', {class: 'spk'}, '🔊'), phrase('heavyQ')[1]), wrap, btns);
    sayPhrase('heavyQ');
    await new Promise(resolve => {
      btns.querySelectorAll('.choice').forEach(btn => btn.onclick = async () => {
        const k = btn.dataset.k;
        wrap.replaceChildren(scale(a, b, heavy === 'a' ? -1 : 1));
        if (k === heavy) {
          btn.classList.add('right'); sfx('correct'); g.cheer();
          await Promise.all([say(tpl('weightA', heavy === 'a' ? a : b)), wait(1200)]);
          resolve();
        } else {
          mistakes++; btn.classList.add('wrong'); sfx('wrong'); g.sad();
          await say(tpl('weightA', heavy === 'a' ? a : b));
          await wait(600);
          resolve();
        }
      });
    });
  }
  g.progress(ROUND, ROUND);
  return {stars: starsFor(mistakes)};
}

function clip() {
  return sv('svg', {viewBox: '0 0 30 14', class: 'clip'},
    sv('path', {d: 'M3,7 a4,4 0 0 1 4,-4 h18 a3,3 0 0 1 0,6 h-15 a1.6,1.6 0 0 1 0,-3.2 h13', fill: 'none', stroke: '#868e96', 'stroke-width': 1.6, 'stroke-linecap': 'round'}));
}

function clipsQ(content) {
  return Array.from({length: 6}, () => {
    const n = 2 + Math.floor(Math.random() * 6);
    const opts = shuffle([...new Set([n, n - 1, n + 1].filter(k => k >= 1))]);
    return {
      say: phrase('clipsQ', 'vi'),
      stage: () => h('div', {class: 'measure'}, pencil(n, sample(PENCIL_COLORS, 1)[0], 56), h('div', {class: 'clips'}, Array.from({length: n}, clip))),
      choices: opts.map(k => ({id: k, node: () => h('span', {}, k)})), cls: 'nums',
      answer: n, reward: tpl('clipsA', content.numbers[n - 1])
    };
  });
}

function ruler(max) {
  const U = 40, W = max * U + 30;
  const kids = [sv('rect', {x: 0, y: 0, width: W, height: 46, rx: 6, fill: '#ffe066', stroke: '#e0a800'})];
  for (let i = 0; i <= max; i++) {
    kids.push(sv('line', {x1: 15 + i * U, y1: 0, x2: 15 + i * U, y2: 18, stroke: '#5c3d00', 'stroke-width': 2}));
    kids.push(sv('text', {x: 15 + i * U, y: 38, 'text-anchor': 'middle', 'font-size': 15, 'font-weight': 800, fill: '#5c3d00'}, String(i)));
    if (i < max) kids.push(sv('line', {x1: 15 + i * U + U / 2, y1: 0, x2: 15 + i * U + U / 2, y2: 10, stroke: '#5c3d00', 'stroke-width': 1.2}));
  }
  return sv('svg', {viewBox: `0 0 ${W} 46`, width: W, class: 'ruler'}, ...kids);
}

function rulerQ(content) {
  return Array.from({length: 6}, () => {
    const n = 3 + Math.floor(Math.random() * 8);
    const opts = shuffle([...new Set([n, n - 1, n + 1, n + 2].filter(k => k >= 1 && k <= 10))]).slice(0, 3);
    if (!opts.includes(n)) opts[0] = n;
    return {
      say: phrase('rulerQ', 'vi'),
      stage: () => h('div', {class: 'measure ruled'}, h('div', {class: 'pen-on-ruler'}, pencil(n, sample(PENCIL_COLORS, 1)[0], 40)), ruler(12)),
      choices: shuffle(opts).map(k => ({id: k, node: () => h('span', {}, `${k} cm`)})), cls: 'nums',
      answer: n, reward: tpl('rulerA', content.numbers[n - 1])
    };
  });
}

// ---------- Thứ trong tuần ----------
async function week(g, content) {
  const ROUND = 6;
  let mistakes = 0;
  for (let r = 0; r < ROUND; r++) {
    if (g.aborted()) return null;
    g.progress(r, ROUND);
    const today = Math.floor(Math.random() * 7);
    const tomorrow = r % 2 === 0;
    const ans = (today + (tomorrow ? 1 : 6)) % 7;
    const q = tpl(tomorrow ? 'weekTomorrow' : 'weekYesterday', content.weekdays[today]);
    const strip = h('div', {class: 'week'}, content.weekdays.map(d => h('button', {class: `day ${d.i === today ? 'today' : ''} ${d.i >= 5 ? 'wkend' : ''}`, 'data-i': d.i},
      h('b', {}, d.short), d.i === today ? img('Glowing star') : null)));
    g.stage.replaceChildren(h('button', {class: 'prompt-btn', onclick: () => say(q)}, h('span', {class: 'spk'}, '🔊'), tomorrow ? t('tomorrow') + '?' : t('yesterday') + '?'), strip);
    say(q);
    await new Promise(resolve => {
      strip.querySelectorAll('.day').forEach(b => b.onclick = async () => {
        const i = Number(b.dataset.i);
        say(tpl('dayName', content.weekdays[i]));
        if (i === ans) { b.classList.add('right'); sfx('correct'); g.cheer(); await wait(1300); resolve(); }
        else { mistakes++; b.classList.remove('shake'); void b.offsetWidth; b.classList.add('shake'); sfx('wrong'); }
      });
    });
  }
  g.progress(ROUND, ROUND);
  return {stars: starsFor(mistakes)};
}

// ---------- Xem lịch: tờ lịch tháng hiện tại ----------
async function calendar(g, content) {
  const now = new Date();
  const y = now.getFullYear(), m = now.getMonth();
  const days = new Date(y, m + 1, 0).getDate();
  const first = (new Date(y, m, 1).getDay() + 6) % 7;  // 0 = thứ hai
  const ROUND = 5;
  let mistakes = 0;
  await sayPhrase('calendarIntro');
  const targets = sample(Array.from({length: days}, (_, i) => i + 1), ROUND);
  for (let r = 0; r < ROUND; r++) {
    if (g.aborted()) return null;
    g.progress(r, ROUND);
    const n = targets[r];
    const wd = (first + n - 1) % 7;
    const grid = h('div', {class: 'cal'},
      h('div', {class: 'calhead'}, `Tháng ${m + 1} / ${y}`),
      h('div', {class: 'calgrid'},
        content.weekdays.map(d => h('span', {class: `cw ${d.i >= 5 ? 'wkend' : ''}`}, d.short)),
        Array.from({length: first}, () => h('span', {})),
        Array.from({length: days}, (_, i) => h('button', {class: `cd ${(first + i) % 7 >= 5 ? 'wkend' : ''} ${i + 1 === now.getDate() ? 'now' : ''}`, 'data-n': i + 1}, i + 1))));
    const q = tpl('findDate', content.calNums[n - 1]);
    g.stage.replaceChildren(h('button', {class: 'prompt-btn', onclick: () => say(q)}, h('span', {class: 'spk'}, '🔊'), q[1]), grid);
    say(q);
    await new Promise(resolve => {
      grid.querySelectorAll('.cd').forEach(b => b.onclick = async () => {
        if (Number(b.dataset.n) === n) {
          b.classList.add('right'); sfx('correct'); g.cheer();
          grid.querySelectorAll('.cw')[wd].classList.add('hl');
          await say(tpl('dateIs', content.calNums[n - 1]));
          if (g.aborted()) return;
          await say(tpl('isDay', content.weekdays[wd]));
          await wait(500);
          resolve();
        } else { mistakes++; sfx('wrong'); b.classList.remove('shake'); void b.offsetWidth; b.classList.add('shake'); }
      });
    });
  }
  g.progress(ROUND, ROUND);
  return {stars: starsFor(mistakes)};
}

export const levels = (island, content) => content.lifeLevels.map(l => ({name: l.name, img: l.img}));

export function run(g, island, content, li) {
  const lv = content.lifeLevels[li];
  switch (lv.kind) {
    case 'shop': g.hideBuddy(); return shop(g, lv, content);
    case 'length': return runQuiz(g, lengthQ(content), {intro: 'lifeIntro'});
    case 'height': return runQuiz(g, heightQ());
    case 'weight': return weight(g, content);
    case 'clips': return runQuiz(g, clipsQ(content));
    case 'ruler': return runQuiz(g, rulerQ(content));
    case 'week': return week(g, content);
    case 'calendar': g.hideBuddy(); return calendar(g, content);
  }
}

