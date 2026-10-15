// Đảo Chữ cái và Tiếng Anh: nghe rồi chọn đúng chữ / hình.
import {h, img, sample, shuffle} from '../ui.js?v=4c51d34a6e';
import {tpl} from '../audio.js?v=4c51d34a6e';
import {t, lang} from '../i18n.js?v=4c51d34a6e';
import {runQuiz, sequence} from './quiz.js?v=4c51d34a6e';

const ROUND = 8;

// Từ ví dụ cho mỗi chữ: lấy ngẫu nhiên trong letterWords (nhiều từ) để mỗi lần học một khác.
function wordFor(content, ch) {
  const ws = (content.letterWords || []).filter(w => w.ch === ch);
  if (!ws.length) { const L = content.letters.find(l => l.ch === ch); return {...L, tplKey: 'letterWord'}; }
  return {...sample(ws, 1)[0], tplKey: 'letterWord2'};
}
const letterReward = W => ({reward: tpl(W.tplKey, W), rewardNode: () => [img(W.img), h('div', {class: 'big'}, W.ch), h('div', {class: 'small'}, W.word)]});

function letters(content, li) {
  const lv = content.letterLevels[li];
  const by = Object.fromEntries(content.letters.map(l => [l.ch, l]));
  const all = content.letters.map(l => l.ch);
  const targets = lv.targets === 'all' ? all : lv.targets;
  const pool = lv.targets === 'all' ? all : [...targets, ...(lv.extra || [])];
  const n = lv.choices || (li < 2 ? 3 : 4);
  const others = ch => sample(pool.filter(x => x !== ch), n - 1);
  // Nhìn hình (nghe tên) chọn chữ đầu tiên của từ.
  if (lv.kind === 'initial') {
    const ws = content.letterWords.filter(w => w.first && targets.includes(w.ch));
    return sequence(ws, ROUND).map(W => ({
      say: tpl('initialQ', W), label: t('initialQ'), stage: () => h('div', {class: 'word-pic'}, img(W.img)),
      choices: shuffle([W.ch, ...others(W.ch)]).map(x => ({id: x, node: () => h('span', {}, x)})),
      answer: W.ch, ...letterReward({...W, tplKey: 'letterWord2'})
    }));
  }
  // Thấy chữ in hoa, tìm chữ thường tương ứng.
  if (lv.kind === 'upper') {
    return sequence(targets, ROUND).map(ch => ({
      say: tpl('findLetter', by[ch]), label: ch.toUpperCase(), labelCls: 'upper',
      choices: shuffle([ch, ...others(ch)]).map(x => ({id: x, node: () => h('span', {}, x)})),
      answer: ch, ...letterReward(wordFor(content, ch))
    }));
  }
  return sequence(targets, ROUND).map(ch => ({
    say: tpl('findLetter', by[ch]), label: t('findLetter'),
    choices: shuffle([ch, ...others(ch)]).map(x => ({id: x, node: () => h('span', {}, x)})),
    answer: ch, ...letterReward(wordFor(content, ch))
  }));
}

function face(item) {
  if (item.img) return img(item.img);
  if (item.color) return h('span', {class: 'swatch', style: {background: item.color}});
  return h('span', {}, item.digit);
}

function english(content, li) {
  const lv = content.englishLevels[li];
  const set = content[lv.set];
  return sequence(set, ROUND).map(item => {
    const prompt = tpl(lv.tpl, item);
    return {
      say: prompt, label: prompt[1],
      choices: shuffle([item, ...sample(set.filter(x => x.id !== item.id), 3)]).map(x => ({id: x.id, node: () => face(x)})),
      answer: item.id, reward: tpl('wordEn', item),
      rewardNode: () => [face(item), h('div', {class: 'big'}, item.en)]
    };
  });
}

export function levels(island, content) {
  if (island === 'letters') return content.letterLevels.map(l => ({name: l.name}));
  return content.englishLevels.map(l => ({name: l.name[lang()] || l.name.vi, img: l.img}));
}

export const run = (g, island, content, li) => runQuiz(g, island === 'letters' ? letters(content, li) : english(content, li));
