// Đảo Toán vui: cộng trừ có hình, so sánh, số đến 20, cộng trừ nhẩm, xem đồng hồ, hình học.
import {h, img, sample, shuffle} from '../ui.js?v=4c51d34a6e';
import {tpl, phrase} from '../audio.js?v=4c51d34a6e';
import {runQuiz} from './quiz.js?v=4c51d34a6e';

const ROUND = 8;
const PICS = ['Red apple', 'Star', 'Fish', 'Soccer ball', 'Tangerine', 'Duck', 'Hibiscus', 'Cupcake', 'Balloon', 'Strawberry'];
const SVG = 'http://www.w3.org/2000/svg';
const pickN = (arr, n) => Array.from({length: n}, () => arr[Math.floor(Math.random() * arr.length)]);

function s(tag, attrs = {}, ...kids) {
  const el = document.createElementNS(SVG, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  el.append(...kids);
  return el;
}

// Đáp án nhiễu gần đáp án đúng, trong khoảng [lo, hi].
function near(ans, n, lo, hi) {
  const c = new Set([ans]);
  for (let d = 1; c.size < n && d <= hi - lo; d++) {
    for (const k of shuffle([ans - d, ans + d])) if (k >= lo && k <= hi && c.size < n) c.add(k);
  }
  return shuffle([...c]);
}

const group = (n, pic, crossFrom = n) => h('div', {class: 'group'},
  Array.from({length: n}, (_, i) => h('span', {class: `gi ${i >= crossFrom ? 'gone' : ''}`}, img(pic, {photo: false}))));

const eq = text => h('div', {class: 'eq'}, text);
const numChoices = (list) => list.map(k => ({id: k, node: () => h('span', {}, k)}));

function addSub(content, lv, kind) {
  const facts = (kind === 'add' ? content.addFacts : content.subFacts)
    .filter(f => f.a <= lv.max && f.b >= 1 && (kind === 'add' ? f.a >= 1 && f.c <= lv.max && f.c >= (lv.min || 0) : f.a >= (lv.min || 0)));
  return sample(facts, ROUND).map(f => {
    const pic = PICS[Math.floor(Math.random() * PICS.length)];
    const sign = kind === 'add' ? '+' : '−';
    const stage = lv.pics
      ? () => h('div', {class: 'mathbox'},
          kind === 'add'
            ? h('div', {class: 'groups'}, group(f.a, pic), h('b', {class: 'op'}, '+'), group(f.b, pic))
            : h('div', {class: 'groups'}, group(f.a, pic, f.a - f.b)),
          eq(`${f.a} ${sign} ${f.b} = ?`))
      : () => h('div', {class: 'mathbox'}, eq(`${f.a} ${sign} ${f.b} = ?`));
    return {
      say: tpl(kind === 'add' ? 'addQ' : 'subQ', f), stage,
      choices: numChoices(near(f.c, 4, 0, Math.max(10, lv.max))), cls: 'nums',
      answer: f.c, reward: tpl(kind === 'add' ? 'addA' : 'subA', f),
      rewardNode: () => h('div', {class: 'big'}, `${f.a} ${sign} ${f.b} = ${f.c}`)
    };
  });
}

function mix(content, lv) {
  const a = addSub(content, {...lv, pics: false}, 'add').slice(0, ROUND / 2);
  const b = addSub(content, {...lv, pics: false}, 'sub').slice(0, ROUND / 2);
  return shuffle([...a, ...b]);
}

function cmp(content, lv) {
  const facts = content.cmpFacts.filter(f => f.a <= lv.max && f.b <= lv.max && f.a >= 1 && f.b >= 1);
  // Cân đối: khoảng 1/5 câu "bằng nhau".
  const eqs = facts.filter(f => f.a === f.b), neq = facts.filter(f => f.a !== f.b);
  const picks = shuffle([...sample(eqs, 2), ...sample(neq, ROUND - 2)]);
  const SIGN = {'lớn hơn': '>', 'bé hơn': '<', 'bằng': '='};
  return picks.map(f => {
    const pic = PICS[Math.floor(Math.random() * PICS.length)];
    return {
      say: phrase('cmpQ', 'vi'),
      stage: () => h('div', {class: 'cmp'},
        h('div', {class: 'side'}, group(f.a, pic), h('div', {class: 'eq'}, f.a)),
        h('div', {class: 'eq q'}, '?'),
        h('div', {class: 'side'}, group(f.b, pic), h('div', {class: 'eq'}, f.b))),
      choices: ['>', '<', '='].map(x => ({id: x, node: () => h('span', {}, x)})), cls: 'nums',
      answer: SIGN[f.rel], reward: tpl('cmpA', f),
      rewardNode: () => h('div', {class: 'big'}, `${f.a} ${SIGN[f.rel]} ${f.b}`)
    };
  });
}

function tenFrame(n) {
  return h('div', {class: 'frame'}, Array.from({length: 10}, (_, i) => h('i', {class: i < n ? 'on' : ''})));
}

function tens(content) {
  const picks = sample([11, 12, 13, 14, 15, 16, 17, 18, 19, 20], ROUND);
  return picks.map(n => ({
    say: phrase('tensQ', 'vi'),
    stage: () => h('div', {class: 'frames'}, tenFrame(10), tenFrame(n - 10)),
    choices: numChoices(near(n, 4, 10, 20)), cls: 'nums',
    answer: n, reward: tpl('num', content.nums[n]),
    rewardNode: () => h('div', {class: 'big'}, `10 + ${n - 10} = ${n}`)
  }));
}

function clockFace(hour) {
  const marks = [];
  for (let k = 1; k <= 12; k++) {
    const a = (k / 12) * Math.PI * 2;
    marks.push(s('text', {x: 100 + Math.sin(a) * 74, y: 100 - Math.cos(a) * 74 + 9, 'text-anchor': 'middle', class: 'cn'}, String(k)));
  }
  const ha = (hour % 12) / 12 * 360;
  return s('svg', {viewBox: '0 0 200 200', class: 'clock'},
    s('circle', {cx: 100, cy: 100, r: 94, class: 'rim'}), ...marks,
    s('line', {x1: 100, y1: 100, x2: 100, y2: 30, class: 'mh'}),
    s('line', {x1: 100, y1: 100, x2: 100, y2: 52, class: 'hh', transform: `rotate(${ha} 100 100)`}),
    s('circle', {cx: 100, cy: 100, r: 7, class: 'hub'}));
}

function clock(content) {
  return sample(content.clockHours, ROUND).map(hh => ({
    say: phrase('clockQ', 'vi'), stage: () => clockFace(hh.n),
    choices: near(hh.n, 3, 1, 12).map(k => ({id: k, node: () => h('span', {class: 'hour'}, `${k} giờ`)})), cls: 'nums',
    answer: hh.n, reward: tpl('clockA', hh),
    rewardNode: () => [clockFace(hh.n), h('div', {class: 'small'}, `${hh.n} giờ`)]
  }));
}

const COLORS = ['#ff6b6b', '#4fb3ff', '#3ccf91', '#ffc93c', '#b388ff', '#ff922b', '#ff6fae'];
function shapeSvg(id) {
  const fill = COLORS[Math.floor(Math.random() * COLORS.length)];
  const rot = id === 'circle' ? 0 : Math.floor(Math.random() * 4) * 15 - 15;
  const a = {fill, stroke: 'rgba(0,0,0,.15)', 'stroke-width': 4, transform: `rotate(${rot} 50 50)`};
  const el = {
    circle: () => s('circle', {cx: 50, cy: 50, r: 38, ...a}),
    square: () => s('rect', {x: 14, y: 14, width: 72, height: 72, rx: 6, ...a}),
    triangle: () => s('polygon', {points: '50,10 90,84 10,84', 'stroke-linejoin': 'round', ...a}),
    rect: () => s('rect', {x: 6, y: 28, width: 88, height: 46, rx: 6, ...a})
  }[id]();
  return s('svg', {viewBox: '0 0 100 100', class: 'shape'}, el);
}

function shape(content) {
  return pickN(content.shapes, ROUND).map(sh => ({
    say: tpl('shapeQ', sh), label: sh.name,
    choices: shuffle(content.shapes).map(x => ({id: x.id, node: () => shapeSvg(x.id)})),
    answer: sh.id, reward: tpl('shapeA', sh),
    rewardNode: () => [shapeSvg(sh.id), h('div', {class: 'small'}, sh.name)]
  }));
}

// ---------- Số đến 100: khối chục và đơn vị, liền trước/liền sau, so sánh, cộng trừ chục ----------
const blocks = (n) => h('div', {class: 'blocks'},
  h('div', {class: 'tens'}, Array.from({length: Math.floor(n / 10)}, () => h('span', {class: 'rod'}, Array.from({length: 10}, () => h('i'))))),
  h('div', {class: 'ones'}, Array.from({length: n % 10}, () => h('i', {class: 'cube'}))));

// Đáp án nhiễu cho số hai chữ số: cùng chục khác đơn vị, và cùng đơn vị khác chục.
function near100(n, count = 4) {
  const c = new Set([n]);
  const t = Math.floor(n / 10), o = n % 10;
  const pool = shuffle([n + 1, n - 1, n + 10, n - 10, t * 10 + (o + 2) % 10, ((t + 1) % 10) * 10 + o, o * 10 + t].filter(k => k > 0 && k < 100 && k !== n));
  for (const k of pool) if (c.size < count) c.add(k);
  return shuffle([...c]);
}

function blocksQ(content) {
  return sample(Array.from({length: 88}, (_, i) => i + 11), ROUND).map(n => ({
    say: phrase('blocksQ', 'vi'),
    stage: () => blocks(n),
    choices: numChoices(near100(n)), cls: 'nums',
    answer: n, reward: tpl('n100', content.nums100[n]),
    rewardNode: () => [blocks(n), h('div', {class: 'big'}, n), h('div', {class: 'small'}, `${Math.floor(n / 10)} chục ${n % 10 ? n % 10 + ' đơn vị' : ''}`)]
  }));
}

function nextQ(content) {
  return Array.from({length: ROUND}, (_, i) => {
    const after = i % 2 === 0;
    const n = after ? 1 + Math.floor(Math.random() * 98) : 2 + Math.floor(Math.random() * 98);
    const ans = after ? n + 1 : n - 1;
    const q = tpl(after ? 'nextQ' : 'prevQ', content.nums100[n]);
    return {
      say: q, label: q[1],
      choices: numChoices(shuffle([...new Set([ans, ans + 2, ans - 2, after ? n - 1 : n + 1].filter(k => k >= 0 && k <= 100))])), cls: 'nums',
      answer: ans, reward: tpl('n100', content.nums100[ans]),
      rewardNode: () => h('div', {class: 'big'}, after ? `${n} → ${ans}` : `${ans} ← ${n}`)
    };
  });
}

function cmp100(content) {
  return Array.from({length: ROUND}, (_, i) => {
    const bigger = i % 2 === 0;
    let a, b;
    do { a = 10 + Math.floor(Math.random() * 90); b = Math.random() < .5 ? a + (Math.random() < .5 ? 1 : -1) * (1 + Math.floor(Math.random() * 9)) : 10 + Math.floor(Math.random() * 90); } while (a === b || b < 10 || b > 99);
    const ans = bigger ? Math.max(a, b) : Math.min(a, b);
    const key = bigger ? 'biggerQ' : 'smallerQ';
    return {
      say: phrase(key, 'vi'), label: phrase(key, 'vi')[1],
      choices: shuffle([a, b]).map(k => ({id: k, node: () => h('span', {}, k)})), cls: 'nums',
      answer: ans, reward: tpl('n100', content.nums100[ans]),
      rewardNode: () => h('div', {class: 'big'}, `${Math.max(a, b)} > ${Math.min(a, b)}`)
    };
  });
}

function addSub100(content, kind) {
  const facts = kind === 'add' ? content.add100 : content.sub100;
  const sign = kind === 'add' ? '+' : '−';
  return sample(facts, ROUND).map(f => ({
    say: tpl(kind === 'add' ? 'add100Q' : 'sub100Q', f),
    stage: () => h('div', {class: 'mathbox'}, eq(`${f.a} ${sign} ${f.b} = ?`)),
    choices: numChoices(near100(f.c)), cls: 'nums',
    answer: f.c, reward: tpl(kind === 'add' ? 'add100A' : 'sub100A', f),
    rewardNode: () => h('div', {class: 'big'}, `${f.a} ${sign} ${f.b} = ${f.c}`)
  }));
}

// ---------- Lớp 1 nâng cao: số còn thiếu, lời văn, cộng trừ liên tiếp, hai chữ số ----------
function missing(content, lv) {
  const pool = [...content.addFacts.map(f => ({...f, k: 'add'})), ...content.subFacts.map(f => ({...f, k: 'sub'}))]
    .filter(f => f.b >= 1 && f.a <= lv.max && f.c <= lv.max && (lv.max <= 10 || Math.max(f.a, f.c) > 10));
  return sample(pool, ROUND).map(f => {
    const sign = f.k === 'add' ? '+' : '−';
    return {
      say: phrase('missQ', 'vi'),
      stage: () => h('div', {class: 'mathbox'}, eq([`${f.a} ${sign} `, h('span', {class: 'blank'}, '?'), ` = ${f.c}`])),
      choices: numChoices(near(f.b, 4, 1, lv.max)), cls: 'nums',
      answer: f.b, reward: tpl(f.k === 'add' ? 'addA' : 'subA', f),
      rewardNode: () => h('div', {class: 'big'}, `${f.a} ${sign} ${f.b} = ${f.c}`)
    };
  });
}

function word(content, lv) {
  const pool = lv.max > 20 ? content.wordProbs100
    : content.wordProbs.filter(w => lv.max <= 10 ? w.a <= 10 && w.c <= 10 : Math.max(w.a, w.c) > 10);
  return sample(pool, ROUND).map(w => ({
    say: tpl('wordQ', w),
    stage: () => h('div', {class: 'wordprob'}, img(w.img), h('p', {}, w.show)),
    choices: numChoices(lv.max > 20 ? near100(w.c) : near(w.c, 4, 0, Math.max(10, lv.max))), cls: 'nums',
    answer: w.c, reward: tpl('wordA', w),
    rewardNode: () => [h('div', {class: 'big'}, `${w.a} ${w.op === '+' ? '+' : '−'} ${w.b} = ${w.c}`), h('div', {class: 'small'}, `${w.c} ${w.unit}`)]
  }));
}

function chain(content) {
  const sg = o => o === '+' ? '+' : '−';
  return sample(content.chainFacts, ROUND).map(f => {
    const text = `${f.a} ${sg(f.o1)} ${f.b} ${sg(f.o2)} ${f.d}`;
    return {
      say: tpl('chainQ', f), stage: () => h('div', {class: 'mathbox'}, eq(`${text} = ?`)),
      choices: numChoices(near(f.c, 4, 0, 10)), cls: 'nums',
      answer: f.c, reward: tpl('chainA', f),
      rewardNode: () => h('div', {class: 'big'}, `${text} = ${f.c}`)
    };
  });
}

// Cộng trừ hai chữ số: đặt tính dọc như vở lớp 1.
function twoDigit(content, kind) {
  const facts = kind === 'add' ? content.add2d : content.sub2d;
  const sign = kind === 'add' ? '+' : '−';
  return sample(facts, ROUND).map(f => ({
    say: tpl(kind === 'add' ? 'add100Q' : 'sub100Q', f),
    stage: () => h('div', {class: 'mathbox'}, h('div', {class: 'vcol'}, h('span', {}, f.a), h('span', {}, h('i', {}, sign), f.b), h('span', {class: 'q'}, '?'))),
    choices: numChoices(near100(f.c)), cls: 'nums',
    answer: f.c, reward: tpl(kind === 'add' ? 'add100A' : 'sub100A', f),
    rewardNode: () => h('div', {class: 'big'}, `${f.a} ${sign} ${f.b} = ${f.c}`)
  }));
}

// Vị trí: vật ở giữa, bốn vật xung quanh. Trái/phải tính theo mắt bé nhìn.
function position(content) {
  return sample(content.posQs, ROUND).map(q => ({
    say: tpl('posQ', q), label: q.t,
    stage: () => h('div', {class: 'posgrid'},
      h('span', {class: 'p-top'}, img(q.items.top)), h('span', {class: 'p-left'}, img(q.items.left)),
      h('span', {class: 'p-center'}, img(q.center)), h('span', {class: 'p-right'}, img(q.items.right)),
      h('span', {class: 'p-bottom'}, img(q.items.bottom))),
    choices: shuffle(Object.values(q.items)).map(x => ({id: x, node: () => img(x)})),
    answer: q.answer, reward: tpl('posA', q)
  }));
}

function maxmin(content, lv) {
  return Array.from({length: ROUND}, (_, i) => {
    const big = i % 2 === 0, set = new Set();
    while (set.size < 4) set.add(lv.max <= 10 ? Math.floor(Math.random() * 11) : 10 + Math.floor(Math.random() * 90));
    const nums = [...set], ans = big ? Math.max(...nums) : Math.min(...nums);
    const key = big ? 'biggestQ' : 'smallestQ';
    return {
      say: phrase(key, 'vi'), label: phrase(key, 'vi')[1],
      choices: numChoices(shuffle(nums)), cls: 'nums',
      answer: ans, reward: ans ? tpl('n100', content.nums100[ans]) : tpl('num', content.nums[0]),
      rewardNode: () => h('div', {class: 'big'}, ans)
    };
  });
}

// Dãy số cách đều: 2, 4, 6, ? hoặc 10, 20, 30, ?
function seqnum(content) {
  return Array.from({length: ROUND}, () => {
    const step = [1, 2, 5, 10][Math.floor(Math.random() * 4)], down = Math.random() < .25;
    const len = 4, maxStart = 99 - step * len;
    let a = step === 10 ? 10 * (1 + Math.floor(Math.random() * 5)) : step === 5 ? 5 * Math.floor(Math.random() * 10) : 1 + Math.floor(Math.random() * Math.max(1, maxStart));
    let seq = Array.from({length: len}, (_, k) => a + k * step);
    if (down) seq.reverse();
    const ans = down ? seq[len - 1] - step : seq[len - 1] + step;
    if (ans <= 0 || ans > 99) return null;
    return {
      say: phrase('nextNumQ', 'vi'), stage: () => h('div', {class: 'mathbox'}, eq([seq.join(', ') + ', ', h('span', {class: 'blank'}, '?')])),
      choices: numChoices(shuffle([...new Set([ans, ans + step, ans - step, ans + 1].filter(k => k > 0 && k < 100))]).slice(0, 4)), cls: 'nums',
      answer: ans, reward: tpl('n100', content.nums100[ans]),
      rewardNode: () => h('div', {class: 'big'}, [...seq, ans].join(', '))
    };
  }).filter(Boolean);
}

function cmpexpr(content) {
  return sample(content.cmpExpr, ROUND).map(f => {
    const sg = f.op === '+' ? '+' : '−';
    return {
      say: phrase('cmpExprQ', 'vi'), stage: () => h('div', {class: 'mathbox'}, eq([`${f.a} ${sg} ${f.b} `, h('span', {class: 'blank'}, '?'), ` ${f.n}`])),
      choices: ['>', '<', '='].map(x => ({id: x, node: () => h('span', {}, x)})), cls: 'nums',
      answer: f.rel, reward: tpl('cmpExprA', f),
      rewardNode: () => h('div', {class: 'big'}, `${f.a} ${sg} ${f.b} ${f.rel} ${f.n}`)
    };
  });
}

const KINDS = {
  position, maxmin, seqnum, cmpexpr,
  missing, word, chain, add2d: c => twoDigit(c, 'add'), sub2d: c => twoDigit(c, 'sub'),
  blocks: blocksQ, next: nextQ, cmp100, add100: c => addSub100(c, 'add'), sub100: c => addSub100(c, 'sub'),
  add: (c, lv) => addSub(c, lv, 'add'), sub: (c, lv) => addSub(c, lv, 'sub'),
  mix, cmp, tens, clock, shape
};

export const levels = (island, content) => content.mathLevels.map(l => ({name: l.name}));
export const run = (g, island, content, li) => {
  const lv = content.mathLevels[li];
  return runQuiz(g, KINDS[lv.kind](content, lv), {intro: lv.kind === 'add' || lv.kind === 'sub' ? 'mathIntro' : lv.kind === 'word' ? 'wordIntro' : null});
};
