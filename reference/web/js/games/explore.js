// Đảo Khám phá (Tự nhiên & Xã hội): xếp từng hình vào đúng nhóm. Kéo thả hoặc chạm vào giỏ đều được.
import {h, img, sample, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sayPhrase, sfx, retry, preload} from '../audio.js?v=4c51d34a6e';
import {starsFor} from './quiz.js?v=4c51d34a6e';

const ROUND = 8;

export const levels = (island, content) => content.exploreLevels.map(l => ({name: l.name, img: l.img}));

export async function run(g, island, content, li) {
  const set = content.sortSets.find(s => s.id === content.exploreLevels[li].set);
  const A = set.items.filter(i => i.side === 'a'), B = set.items.filter(i => i.side === 'b');
  const items = shuffle([...sample(A, Math.min(A.length, ROUND / 2)), ...sample(B, Math.min(B.length, ROUND / 2))]);
  const nameOf = name => tpl('sortName', {name});
  preload([...items.map(i => nameOf(i.name)), nameOf(set.a.vi), nameOf(set.b.vi)]);
  let mistakes = 0;

  const basket = (side, d) => h('div', {class: `basket b-${side}`, 'data-side': side},
    h('div', {class: 'bhead'}, img(d.img, {photo: false}), h('span', {}, d.vi)), h('div', {class: 'bin'}));
  const ba = basket('a', set.a), bb = basket('b', set.b);
  const slot = h('div', {class: 'sort-slot'});
  g.stage.replaceChildren(h('div', {class: 'sort'}, ba, slot, bb));
  g.progress(0, items.length);
  await sayPhrase('exploreIntro');
  if (g.aborted()) return null;
  await say(nameOf(set.a.vi));
  if (g.aborted()) return null;
  await say(nameOf(set.b.vi));

  for (let i = 0; i < items.length; i++) {
    if (g.aborted()) return null;
    const it = items[i];
    const card = h('div', {class: 'sort-card'}, img(it.img), h('span', {}, it.name));
    slot.replaceChildren(card);
    say(nameOf(it.name));
    await new Promise(resolve => {
      let drag = null, busy = false;
      const target = side => side === 'a' ? ba : bb;
      async function drop(side) {
        if (busy) return;
        busy = true;
        if (side === it.side) {
          sfx('correct'); g.cheer();
          card.classList.add('fly');
          target(side).querySelector('.bin').append(h('span', {class: 'mini'}, img(it.img, {photo: false})));
          await wait(350);
          resolve();
        } else {
          mistakes++; sfx('wrong'); g.sad();
          card.style.transform = '';
          card.classList.remove('shake'); void card.offsetWidth; card.classList.add('shake');
          await retry();
          busy = false;
        }
      }
      card.onpointerdown = e => {
        e.preventDefault();
        card.setPointerCapture(e.pointerId);
        drag = {x: e.clientX, y: e.clientY};
        card.classList.add('drag');
      };
      card.onpointermove = e => {
        if (!drag) return;
        card.style.transform = `translate(${e.clientX - drag.x}px, ${e.clientY - drag.y}px) rotate(${(e.clientX - drag.x) / 20}deg)`;
        for (const b of [ba, bb]) {
          const r = b.getBoundingClientRect();
          b.classList.toggle('over', e.clientX > r.left && e.clientX < r.right && e.clientY > r.top && e.clientY < r.bottom);
        }
      };
      card.onpointerup = card.onpointercancel = e => {
        if (!drag) return;
        card.classList.remove('drag');
        const moved = Math.hypot(e.clientX - drag.x, e.clientY - drag.y);
        drag = null;
        const over = [ba, bb].find(b => b.classList.contains('over'));
        [ba, bb].forEach(b => b.classList.remove('over'));
        if (over) drop(over.dataset.side);
        else { card.style.transform = ''; if (moved < 8) say(nameOf(it.name)); }
      };
      ba.onclick = () => drop('a');
      bb.onclick = () => drop('b');
    });
    g.progress(i + 1, items.length);
  }
  // Câu giải thích ngắn của bộ (nếu có): hiện chữ và đọc to.
  const fact = (content.exploreFacts || []).find(x => x.set === set.id);
  if (fact && !g.aborted()) {
    const card = h('div', {class: 'reward'}, h('div', {class: 'card'}, img(set.a.img, {photo: false}), h('p', {class: 'fact'}, fact.fact)));
    g.stage.append(card);
    await Promise.all([say(tpl('exploreFact', fact)), wait(1500)]);
    card.remove();
  }
  return {stars: starsFor(mistakes)};
}
