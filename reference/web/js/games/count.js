// Đảo Số đếm: chạm từng hình để đếm (bé nghe "một, hai, ba…"), rồi chọn số đúng.
import {h, img, sample, shuffle} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sfx} from '../audio.js?v=4c51d34a6e';
import {runQuiz} from './quiz.js?v=4c51d34a6e';

const ROUND = 6;

// Số 1–10 dùng numbers, 11–20 dùng nums (cùng câu đọc "mười một"...).
const numOf = (content, n) => n <= 10 ? content.numbers[n - 1] : content.nums100[n];
const sayN = (content, n) => say(n <= 10 ? tpl('number', content.numbers[n - 1]) : tpl('n100', content.nums100[n]));

function board(n, thing, content) {
  let counted = 0;
  const cols = n <= 5 ? n : n <= 10 ? Math.ceil(n / 2) : 5;
  const el = h('div', {class: `count-board ${n > 10 ? 'many' : ''}`, style: {display: 'grid', gridTemplateColumns: `repeat(${cols}, auto)`}});
  for (let i = 0; i < n; i++) {
    const it = h('button', {class: 'count-item', onclick: () => {
      if (it.classList.contains('counted')) return;
      counted++;
      it.classList.add('counted');
      it.append(h('span', {class: 'tag'}, counted));
      sfx('count');
      sayN(content, counted);
    }}, img(thing.img, {photo: false}));
    el.append(it);
  }
  return el;
}

// Đếm theo chục (số lớn tới 100): mỗi thanh 10 hình, chạm thanh đếm "mười, hai mươi…", rồi chạm từng hình lẻ.
function boardTens(n, thing, content) {
  let counted = 0;
  const tens = Math.floor(n / 10), ones = n % 10;
  const tag = h('div', {class: 'tens-total'}, '0');
  const bump = (by, el) => {
    counted += by; el.classList.add('counted'); tag.textContent = counted;
    tag.classList.remove('pop'); void tag.offsetWidth; tag.classList.add('pop');
    sfx('count'); sayN(content, counted);
  };
  const bars = Array.from({length: tens}, () => {
    const b = h('button', {class: 'ten-bar'}, Array.from({length: 10}, () => img(thing.img, {photo: false})));
    b.onclick = () => { if (!b.classList.contains('counted')) bump(10, b); };
    return b;
  });
  const singles = Array.from({length: ones}, () => {
    const b = h('button', {class: 'count-item one'}, img(thing.img, {photo: false}));
    b.onclick = () => { if (b.classList.contains('counted')) return; if (bars.some(x => !x.classList.contains('counted'))) { sfx('wrong'); bars.find(x => !x.classList.contains('counted')).classList.add('hint'); return; } bump(1, b); };
    return b;
  });
  return h('div', {class: 'tens-board'}, tag, h('div', {class: 'ten-bars'}, bars), singles.length ? h('div', {class: 'ten-ones'}, singles) : null);
}

function questions(content, li) {
  const lv = content.countLevels[li];
  const range = [];
  for (let k = lv.min; k <= lv.max; k++) if (!lv.round || k % 10 === 0) range.push(k);
  const picks = [];
  while (picks.length < ROUND) {
    const n = range[Math.floor(Math.random() * range.length)];
    if (picks[picks.length - 1] !== n || range.length === 1) picks.push(n);
  }
  const things = shuffle(lv.max > 10 ? content.things.filter(x => !x.big) : content.things);
  return picks.map((n, i) => {
    const thing = things[i % things.length];
    const num = numOf(content, n);
    // Số nhiễu: ưu tiên số gần đáp án để bé phải đếm thật.
    // Số lớn: nhiễu lệch 1 và lệch 10 (nhầm số chục) để bé phải đếm cả chục lẫn đơn vị.
    const near = shuffle((lv.tens ? (lv.round ? [n - 10, n + 10, n - 20, n + 20] : [n - 1, n + 1, n - 10, n + 10]) : [n - 2, n - 1, n + 1, n + 2])
      .filter(k => k >= 1 && k <= Math.max(10, lv.max, 100) && (lv.tens || k <= Math.max(10, lv.max))));
    const choices = shuffle([n, ...near.slice(0, lv.choices - 1)]);
    return {
      say: tpl('howMany', thing), label: tpl('howMany', thing)[1],
      stage: () => lv.tens ? boardTens(n, thing, content) : board(n, thing, content),
      choices: choices.map(k => ({id: k, node: () => h('span', {}, k)})), cls: 'nums',
      answer: n, reward: n <= 10 ? tpl('countAnswer', {...num, ...thing}) : tpl('n100', num),
      rewardNode: () => [img(thing.img, {photo: false}), h('div', {class: 'big'}, n), h('div', {class: 'small'}, `${num.num} ${thing.name}`)]
    };
  });
}

export const levels = (island, content) => content.countLevels.map(l => ({name: l.name}));
export const run = (g, island, content, li) => runQuiz(g, questions(content, li));
