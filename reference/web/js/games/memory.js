// Đảo Trí nhớ: lật thẻ tìm cặp giống nhau. Mỗi lần lật, bé nghe tên con vật.
import {h, img, sample, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sfx, preload} from '../audio.js?v=4c51d34a6e';
import {lang} from '../i18n.js?v=4c51d34a6e';

export const levels = (island, content) => content.memoryLevels.map(l => ({name: l.name}));

export async function run(g, island, content, li) {
  const lv = content.memoryLevels[li];
  // Bài có chủ đề (lv.theme) lấy thẻ trong memItems, bài thường lấy kho words (con vật).
  const pool = lv.theme ? content.memItems.filter(x => x.theme === lv.theme) : content.words;
  const words = sample(pool, lv.pairs);
  const voiceOf = w => tpl(lang() === 'en' ? 'wordEn' : 'wordVi', w);
  preload(words.map(voiceOf));
  const deck = shuffle([...words, ...words]);
  const grid = h('div', {class: 'memory', style: {'--cols': lv.cols, '--rows': Math.ceil(lv.pairs * 2 / lv.cols)}});
  g.stage.replaceChildren(grid);
  g.progress(0, lv.pairs);
  let open = [], found = 0, misses = 0, busy = false;

  return new Promise(resolve => {
    deck.forEach(w => {
      const card = h('button', {class: 'mcard', onclick: async () => {
        if (busy || card.classList.contains('open') || card.classList.contains('done')) return;
        card.classList.add('open');
        sfx('flip');
        say(voiceOf(w));
        open.push([card, w]);
        if (open.length < 2) return;
        busy = true;
        const [[c1, w1], [c2, w2]] = open;
        open = [];
        if (w1.id === w2.id) {
          await wait(450);
          c1.classList.add('done'); c2.classList.add('done');
          sfx('correct'); g.cheer();
          found++;
          g.progress(found, lv.pairs);
          busy = false;
          if (found === lv.pairs) {
            await wait(900);
            resolve({stars: misses <= lv.pairs ? 3 : misses <= lv.pairs * 2 ? 2 : 1});
          }
        } else {
          misses++;
          await wait(1000);
          c1.classList.remove('open'); c2.classList.remove('open');
          busy = false;
        }
      }}, h('div', {class: 'face back'}, img('Star', {photo: false})), h('div', {class: 'face front'}, img(w.img)));
      grid.append(card);
    });
  });
}
