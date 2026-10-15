// Bố con thi tài: chia đôi màn hình, cùng một câu hỏi, ai bấm đúng trước được điểm.
// iPad nằm ngang: trái (bố mẹ) – phải (bé). iPad dựng đứng / điện thoại: nửa trên xoay ngược cho bố mẹ ngồi đối diện.
import {h, img, sample, shuffle, wait, confetti, overlay} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sayPhrase, sfx, stopVoice} from '../audio.js?v=4c51d34a6e';
import {t} from '../i18n.js?v=4c51d34a6e';

const ROUNDS = 10;
const PICS = ['Red apple', 'Star', 'Fish', 'Soccer ball', 'Duck', 'Hibiscus', 'Balloon', 'Cupcake'];

function makeQ(topic, content) {
  if (topic === 'count') {
    const n = 1 + Math.floor(Math.random() * 10), pic = sample(PICS, 1)[0];
    const others = shuffle([n - 2, n - 1, n + 1, n + 2].filter(k => k >= 1 && k <= 10)).slice(0, 2);
    return {visual: () => h('div', {class: 'dgroup'}, Array.from({length: n}, () => img(pic))), choices: [n, ...others], answer: n,
      label: k => k, say: null, after: tpl('num', content.nums[n])};
  }
  if (topic === 'letters') {
    const L = sample(content.letters, 1)[0];
    const others = sample(content.letters.filter(x => x.ch !== L.ch), 2).map(x => x.ch);
    return {visual: () => h('div', {class: 'dear'}, '🔊'), choices: [L.ch, ...others], answer: L.ch,
      label: k => k, say: tpl('findLetter', L), after: tpl('letterWord', L)};
  }
  const add = Math.random() < .5;
  const f = sample((add ? content.addFacts : content.subFacts).filter(x => x.a >= 1 && x.b >= 1 && x.a <= 10 && (add ? x.c <= 10 : true)), 1)[0];
  const others = shuffle([f.c - 2, f.c - 1, f.c + 1, f.c + 2].filter(k => k >= 0 && k <= 10)).slice(0, 2);
  return {visual: () => h('div', {class: 'deq'}, `${f.a} ${add ? '+' : '−'} ${f.b}`), choices: [f.c, ...others], answer: f.c,
    label: k => k, say: tpl(add ? 'addQ' : 'subQ', f), after: tpl(add ? 'addA' : 'subA', f)};
}

export function duel(root, {content, kidImg, kidName, onExit}) {
  const pickTopic = () => {
    sayPhrase('duelIntro');
    const topics = [['count', 'Abacus', t('duelCount')], ['letters', 'Books', t('duelLetters')], ['math', 'Plus', t('duelMath')]];
    root.replaceChildren(
      h('div', {class: 'topbar'}, h('button', {class: 'icon-btn', onclick: onExit}, '⬅️'), h('h1', {}, t('duelTitle')), h('span', {class: 'spacer'})),
      h('div', {class: 'duel-vs'}, h('span', {}, img('Woman'), img('Man')), h('b', {}, 'VS'), h('span', {}, img(kidImg))),
      h('div', {class: 'levels duel-topics'}, topics.map(([id, pic, label]) =>
        h('button', {class: 'level', style: {'--c': '#845ef7'}, onclick: () => { sfx('tap'); play(id); }},
          h('span', {class: 'num'}, img(pic)), h('span', {class: 'lname'}, label))))
    );
  };

  async function play(topic) {
    let alive = true;
    const score = [0, 0];
    const sides = [0, 1].map(k => {
      const sc = h('b', {class: 'dscore'}, '0');
      const vis = h('div', {class: 'dvis'});
      const ch = h('div', {class: 'dchoices'});
      const el = h('div', {class: `dside s${k}`},
        h('div', {class: 'dhead'}, k === 0 ? h('span', {class: 'dav'}, img('Woman'), img('Man')) : h('span', {class: 'dav'}, img(kidImg)),
          h('span', {class: 'dname'}, k === 0 ? t('parent') : kidName), sc),
        vis, ch);
      return {el, sc, vis, ch, locked: false};
    });
    const quit = h('button', {class: 'icon-btn dquit', onclick: () => { alive = false; stopVoice(); pickTopic(); }}, '✕');
    root.replaceChildren(h('div', {class: 'duel'}, sides[0].el, sides[1].el), quit);
    await sayPhrase('ready');
    for (let r = 0; r < ROUNDS && alive && root.isConnected; r++) {
      const q = makeQ(topic, content);
      let won = false;
      await new Promise(resolve => {
        sides.forEach((s, k) => {
          s.locked = false; s.el.classList.remove('win', 'lock');
          s.vis.replaceChildren(q.visual());
          s.ch.replaceChildren(...shuffle(q.choices).map(c => {
            const b = h('button', {class: 'dch'}, q.label(c));
            b.addEventListener('pointerdown', async e => {
              e.preventDefault();
              if (won || s.locked || !alive) return;
              if (c === q.answer) {
                won = true;
                score[k]++; s.sc.textContent = score[k];
                b.classList.add('right'); s.el.classList.add('win');
                sfx('correct');
                await Promise.all([say(q.after), wait(1100)]);
                resolve();
              } else {
                s.locked = true; s.el.classList.add('lock'); b.classList.add('wrong'); sfx('wrong');
                await wait(1300);
                s.locked = false; s.el.classList.remove('lock');
              }
            });
            return b;
          }));
        });
        if (q.say && root.isConnected) say(q.say);
      });
    }
    if (!alive || !root.isConnected) return;  // rời màn bằng back/vuốt: không hiện kết quả đè màn mới
    const [p, kid] = score;
    const res = kid > p ? 'duelKid' : p > kid ? 'duelParent' : 'duelTie';
    sfx('win'); confetti();
    sayPhrase(res);
    const ov = overlay(
      h('h2', {}, kid > p ? `🏆 ${kidName}` : p > kid ? `🏆 ${t('parent')}` : '🤝'),
      h('div', {class: 'duel-final'}, h('span', {}, img('Woman'), img('Man'), h('b', {}, p)), h('i', {}, ':'), h('span', {}, h('b', {}, kid), img(kidImg))),
      h('div', {class: 'row'},
        h('button', {class: 'btn ghost', onclick: () => { ov.remove(); onExit(); }}, '🗺️ ', t('map')),
        h('button', {class: 'btn blue', onclick: () => { ov.remove(); pickTopic(); }}, '🔄 ', t('rematch')))
    );
  }

  pickTopic();
}
