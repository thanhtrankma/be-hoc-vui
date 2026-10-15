// Đảo Ghép vần: dấu thanh, âm đầu, vần, ghép tiếng, nghe đánh vần (Tiếng Việt lớp 1).
import {h, img, sample, shuffle, wait, toneMark} from '../ui.js?v=4c51d34a6e';
import {tpl, praiseItem, phrase} from '../audio.js?v=4c51d34a6e';
import {runQuiz, sequence} from './quiz.js?v=4c51d34a6e';

const ROUND = 8;
const MARK = {'ngang': '', 'huyền': '̀', 'sắc': '́', 'hỏi': '̉', 'ngã': '̃', 'nặng': '̣'};
const TONES = Object.keys(MARK);
// Âm dễ lẫn chính tả: không đưa làm lựa chọn sai của nhau.
const VOWELS1 = ['a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư'];
const TWINS = {c: ['k', 'q'], k: ['c', 'q'], g: ['gh'], gh: ['g'], ng: ['ngh'], d: ['gi']};

// Đặt dấu thanh đúng chỗ trên vần (v: vần không dấu, vd "an", "ua", "ương").
// Quy tắc: một nguyên âm thì đặt trên nó; có nguyên âm mang dấu phụ (ă â ê ô ơ ư) thì đặt trên nguyên âm đó (ươ, iê, uô: chữ sau);
// hai nguyên âm thường (ai, ao, ua, ia, ui…) thì đặt trên chữ đầu.
const VOW = 'aăâeêioôơuưy', MOD = 'ăâêôơư';
export function placeTone(v, tone) {
  if (tone === 'ngang') return v;
  const idx = [...v].map((ch, i) => VOW.includes(ch) ? i : -1).filter(i => i >= 0);
  // Đợt 18: vần có âm đệm o/u (oa, oă, oe, uy, uâ, uê…): không đặt dấu trên âm đệm (hoà, khoẻ, thuỷ, toán, xoài, thuyền).
  if (idx.length > 1 && /^(o[aăe]|u[yâê])/.test(v)) idx.shift();
  let k = idx[0];
  if (idx.length > 1) { const mods = idx.filter(i => MOD.includes(v[i])); if (mods.length) k = mods[mods.length - 1]; }
  return (v.slice(0, k + 1) + MARK[tone] + v.slice(k + 1)).normalize('NFC');
}
export const toned = placeTone;
const syll = (w, tone) => w.c + placeTone(w.v, tone);

// Bài cũ chỉ dùng tiếng có một nguyên âm (như trước); bài mới chọn pool: 'rime' (vần nhiều chữ) hoặc 'all'.
// lv.rimes (bài theo nhóm vần): chỉ lấy tiếng có vần trong nhóm.
// Đợt 18 (Học cùng lớp): lv.words là danh sách tiếng của bài sách; lv.know {c, v, t} là âm đầu/vần/dấu bé đã học tới bài đó,
// lựa chọn sai và hình gây nhiễu chỉ lấy trong đó (bé không gặp chữ chưa học).
const poolOf = (content, lv) => content.vnwords.filter(w => lv.words ? lv.words.includes(w.w) : lv.rimes ? lv.rimes.includes(w.v) : (lv.pool === 'all' || (lv.pool === 'rime' ? w.v.length > 1 : w.v.length === 1)));
const knownWords = (content, lv) => lv.know ? content.vnwords.filter(w => lv.know.c.includes(w.c) && lv.know.v.includes(w.v) && lv.know.t.includes(w.tone)) : [];

const pic = w => h('div', {class: 'word-pic'}, img(w.img));
const word = (text, cls = '') => h('div', {class: `word-show ${cls}`}, text);
const rewardWord = w => () => [img(w.img), h('div', {class: 'big'}, w.w)];

// ---- Đợt 15 giọng: thẻ thưởng đánh vần nhanh, chữ sáng lần lượt theo nhịp "bờ o bo, huyền bò!" ----
// spell trong dữ liệu luôn là 5 phần (âm đầu. vần. tiếng không dấu. dấu. tiếng) hoặc 3 phần (không dấu: âm đầu. vần. tiếng).
function spellNode(w) {
  const ch = (cls, t) => h('span', {class: `sp ${cls}`}, t);
  const sep = t => h('i', {class: 'sp-sep'}, t);
  const line = w.tone !== 'ngang'
    ? [ch('sp-on', w.c), sep('+'), ch('sp-rime', w.v), sep('→'), ch('sp-base', w.base), sep('+'), ch('sp-tone', toneMark(w.tone)), sep('→'), ch('sp-word', w.w)]
    : [ch('sp-on', w.c), sep('+'), ch('sp-rime', w.v), sep('→'), ch('sp-word', w.w)];
  return [img(w.img, {class: 'sp-img'}), h('div', {class: 'spell-line'}, line)];
}
// Nhịp tương đối của từng phần trong câu đánh vần (phần trước dấu phẩy và tiếng cuối dài hơn một chút).
const BEATS = {5: [1, 1, 1.35, 1, 1.25], 3: [1, 1.3, 1.25]};
function animSpell(card, dur) {
  const parts = [...card.querySelectorAll('.sp')], seps = [...card.querySelectorAll('.sp-sep')];
  const beats = BEATS[parts.length] || parts.map(() => 1), sum = beats.reduce((a, b) => a + b, 0);
  const total = (dur || 1.2) * 1000;
  card.classList.add('spelling');
  let t = 0;
  parts.forEach((el, k) => {
    setTimeout(() => { el.classList.add('lit'); if (k) seps[k - 1]?.classList.add('lit'); }, t);
    t += total * beats[k] / sum;
  });
}
// Thưởng khi đúng: đánh vần nhanh khi bé vừa chọn sai (ôn lại cho chắc), ở bước cuối Ghép tiếng, và xen kẽ câu đúng;
// các câu đúng còn lại chỉ đọc tiếng + một lời khen (đỡ lặp, nhịp nhanh).
const fastSpell = w => ({say: tpl('spellFast', w), node: () => spellNode(w), anim: animSpell, min: 700});
const wordPraise = w => ({say: [tpl('vnSay', w), praiseItem()], node: rewardWord(w), min: 700});
const spellReward = (w, always) => ({missed, streak}) => always || missed || streak % 2 === 1 ? fastSpell(w) : wordPraise(w);
const PRAISE = ['praise1', 'praise2', 'praise3', 'praise4', 'praise5', 'praise6'];
const preWord = w => [tpl('spellFast', w), tpl('vnSay', w), ...PRAISE.map(k => phrase(k))];

// Ghép chữ bay vào ô trống (âm đầu/vần/từ), ô trống thành chữ thật rồi cả từ nảy lên.
const still = () => window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
async function fly(btn, stage) {
  const blank = stage.querySelector('.word-show .blank, .sent .blank');
  if (!blank) return;
  const txt = btn.textContent.trim();
  const fill = () => { blank.textContent = txt; blank.classList.remove('blank'); blank.classList.add('filled'); };
  if (still() || !btn.animate) { fill(); return; }
  const a = btn.getBoundingClientRect(), b = blank.getBoundingClientRect();
  const ghost = h('div', {class: 'fly-chip', style: {left: `${a.left + a.width / 2}px`, top: `${a.top + a.height / 2}px`, fontSize: getComputedStyle(blank).fontSize}}, txt);
  document.body.append(ghost);
  const dx = b.left + b.width / 2 - (a.left + a.width / 2), dy = b.top + b.height / 2 - (a.top + a.height / 2);
  try {
    await ghost.animate([{transform: 'translate(-50%, -50%) scale(1.15)'}, {transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(1)`}],
      {duration: 340, easing: 'cubic-bezier(.45, 0, .3, 1.25)'}).finished;
  } catch (e) { /* bị huỷ khi rời bài */ }
  ghost.remove();
  fill();
  blank.closest('.word-show, .sent')?.classList.add('merge');
  await wait(200);
}

function toneQ(content, lv) {
  const pool = poolOf(content, lv).filter(w => lv.tones.includes(w.tone));
  return sequence(pool, ROUND).map(w => {
    const others = shuffle(lv.tones.filter(t => t !== w.tone));
    const extra = shuffle(TONES.filter(t => !lv.tones.includes(t)));
    const tones = shuffle([w.tone, ...[...others, ...extra].slice(0, lv.choices - 1)]);
    return {
      say: tpl('vnAsk', w), stage: () => pic(w),
      choices: tones.map(t => ({id: t, node: () => h('span', {}, syll(w, t))})),
      cls: 'syll', cols: lv.choices > 4 ? 3 : lv.choices,
      answer: w.tone, pickReward: spellReward(w), preload: preWord(w)
    };
  });
}

function onsetChoices(content, w, n, lv = {}) {
  const ban = new Set([w.c, ...(TWINS[w.c] || [])]);
  const known = lv.know ? lv.know.c.filter(c => content.consonants.includes(c) && !ban.has(c)) : [];
  // Bài đầu (mới học 1-2 âm): bớt số lựa chọn chứ không bày âm chưa học.
  if (lv.know && known.length) return shuffle([w.c, ...sample(known, Math.min(n - 1, known.length))]);
  return shuffle([w.c, ...sample(content.consonants.filter(c => !ban.has(c)), n - 1)]);
}

function rimeChoices(content, w, n, lv = {}) {
  const tones = lv.know ? lv.know.t : TONES;
  const sameV = tones.filter(t => t !== w.tone).map(t => placeTone(w.v, t));
  // Vần khác cùng dấu: ưu tiên vần đầu giống (an/ang/anh/at…), rồi mới tới vần bất kỳ.
  const knownV = lv.know ? lv.know.v.filter(r => r !== w.v) : [];
  const others = knownV.length >= 3 ? knownV : (content.rimes || []).concat(VOWELS1).filter(r => r !== w.v);
  const near = others.filter(r => r[0] === w.v[0] || r.length === w.v.length);
  const sameT = sample([...new Set([...near, ...others])].map(r => placeTone(r, w.tone)), n);
  return shuffle([w.vt, ...sample(sameV, Math.ceil((n - 1) / 2)), ...sameT.slice(0, Math.floor((n - 1) / 2))]).slice(0, Math.max(n, 3));
}

function onsetQ(content, lv) {
  return sequence(poolOf(content, lv), ROUND).map(w => ({
    say: tpl('vnAsk', w),
    stage: () => h('div', {class: 'word-row'}, pic(w), word([h('span', {class: 'blank'}, '?'), w.vt])),
    choices: onsetChoices(content, w, lv.choices, lv).map(c => ({id: c, node: () => h('span', {}, c)})), cls: 'syll',
    answer: w.c, pickReward: spellReward(w), preload: preWord(w)
  }));
}

function rimeQ(content, lv) {
  return sequence(poolOf(content, lv), ROUND).map(w => ({
    say: tpl('vnAsk', w),
    stage: () => h('div', {class: 'word-row'}, pic(w), word([w.c, h('span', {class: 'blank'}, '?')])),
    choices: rimeChoices(content, w, lv.choices, lv).map(v => ({id: v, node: () => h('span', {}, v)})), cls: 'syll',
    answer: w.vt, pickReward: spellReward(w), preload: preWord(w)
  }));
}

// Ghép tiếng: mỗi từ 2 bước (chọn âm đầu rồi chọn vần), cuối cùng nghe đánh vần.
function buildQ(content, lv) {
  return sample(poolOf(content, lv), ROUND / 2).flatMap(w => [
    {
      say: tpl('vnAsk', w),
      stage: () => h('div', {class: 'word-row'}, pic(w), word([h('span', {class: 'blank'}, '?'), h('span', {class: 'blank'}, '?')])),
      choices: onsetChoices(content, w, lv.choices, lv).map(c => ({id: c, node: () => h('span', {}, c)})), cls: 'syll',
      answer: w.c, reward: null
    },
    {
      // Bước 2 đã nghe đề ở bước 1: chỉ nhắc lại tiếng cho gọn.
      say: tpl('vnSay', w),
      stage: () => h('div', {class: 'word-row'}, pic(w), word([w.c, h('span', {class: 'blank'}, '?')])),
      choices: rimeChoices(content, w, lv.choices, lv).map(v => ({id: v, node: () => h('span', {}, v)})), cls: 'syll',
      answer: w.vt, pickReward: spellReward(w, true), preload: preWord(w)
    }
  ]);
}

// Hình gây nhiễu: ưu tiên tiếng cùng nhóm vần của bài (khó hơn, đúng trọng tâm), thiếu thì lấy thêm từ cả kho; không trùng hình.
// Đợt 18: không lấy hình cùng nhóm dễ lẫn với đáp án (content.confuse: hoa/bông/sen, tàu/thuyền, chó/cún…).
function distractors(content, lv, w, n) {
  const seen = new Set([w.img]), out = [];
  const grp = new Set((content.confuse || []).filter(g => g.includes(w.w)).flat());
  const add = list => { for (const x of shuffle(list)) { if (out.length >= n) break; if (!seen.has(x.img) && !grp.has(x.w)) { seen.add(x.img); out.push(x); } } };
  add(poolOf(content, lv));
  add(knownWords(content, lv));
  add(content.vnwords.filter(x => lv.pool !== 'rime' || x.v.length > 1));
  add(content.vnwords);
  return out;
}

function listenQ(content, lv) {
  return sequence(poolOf(content, lv), ROUND).map(w => ({
    say: tpl('spell', w), label: '🔤',
    choices: shuffle([w, ...distractors(content, lv, w, lv.choices - 1)]).map(x => ({id: x.id, node: () => img(x.img)})),
    // Đề đã là đánh vần: thưởng chỉ đọc tiếng + lời khen.
    answer: w.id, pickReward: () => wordPraise(w), preload: preWord(w)
  }));
}

// Đọc từ hai tiếng (không đọc to đề, bé tự đọc) rồi chọn hình. Bài "hard": các lựa chọn chung một tiếng (con mèo / con mèo…).
function readWordQ(content, lv) {
  const all = content.twoWords;
  return sample(all, ROUND).map(w => {
    const [first, second] = w.w.split(' ');
    const share = all.filter(x => x !== w && (x.w.startsWith(first + ' ') || x.w.endsWith(' ' + second)));
    const wrong = lv.hard ? sample(share.length >= lv.choices - 1 ? share : all.filter(x => x !== w), lv.choices - 1) : sample(all.filter(x => x !== w), lv.choices - 1);
    return {
      say: null, label: w.w, labelCls: 'readword',
      choices: shuffle([w, ...wrong]).map(x => ({id: x.id, node: () => img(x.img)})),
      answer: w.id, reward: tpl('twoWord', w), rewardNode: () => [img(w.img), h('div', {class: 'big'}, w.w)]
    };
  });
}

// Xếp chữ thành câu: mỗi lần chạm chọn chữ tiếp theo, câu hiện dần; xong thì đọc cả câu.
function sentenceQ(content, lv) {
  const pool = content.sentences.filter(x => lv.max >= 5 ? x.words.length >= 5 : x.words.length <= 4);
  return sample(pool, lv.max >= 5 ? 4 : 5).flatMap(st => st.words.map((wd, i) => {
    const last = i === st.words.length - 1;
    return {
      say: null,
      stage: () => h('div', {class: 'word-row'}, h('div', {class: 'word-pic'}, img(st.img)),
        h('div', {class: 'sent'}, st.words.map((x, k) => k < i ? h('span', {}, x) : h('span', {class: 'blank'}, '?')))),
      choices: shuffle(st.words.slice(i)).map(x => ({id: x, node: () => h('span', {}, x)})), cls: 'syll words',
      answer: wd, reward: last ? tpl('sentence', st) : null,
      rewardNode: last ? () => [img(st.img), h('div', {class: 'big sent-done'}, st.t)] : null
    };
  }));
}

// Chính tả c/k, g/gh, ng/ngh: nghe từ, nhìn hình, chọn cách viết đúng.
function ruleQ(content, lv) {
  return sequence(content.ruleWords.filter(w => w.grp === lv.grp), ROUND).map(w => ({
    say: tpl('ruleSay', w), stage: () => pic(w),
    choices: shuffle([w.w, w.bad]).map(x => ({id: x, node: () => h('span', {}, x)})), cls: 'syll words',
    answer: w.w, reward: tpl('ruleSay', w), rewardNode: () => [img(w.img), h('div', {class: 'big'}, w.w)]
  }));
}

// Đọc câu (không đọc to), chọn hình đúng với câu.
function readSentQ(content, lv) {
  const all = content.sentences;
  return sample(all, ROUND).map(st => ({
    say: null, label: st.t, labelCls: 'readsent',
    choices: shuffle([st, ...sample(all.filter(x => x.img !== st.img), lv.choices - 1)]).map(x => ({id: x.id, node: () => img(x.img)})),
    answer: st.id, reward: tpl('sentence', st), rewardNode: () => [img(st.img), h('div', {class: 'big sent-done'}, st.t)]
  }));
}

// Điền từ còn thiếu vào câu (bỏ trống một từ, không phải từ đầu câu).
function clozeQ(content, lv) {
  const all = content.sentences;
  const pool = [...new Set(all.flatMap(x => x.words.slice(1).map(w => w.toLowerCase())))];
  return sample(all, ROUND).map(st => {
    const k = 1 + Math.floor(Math.random() * (st.words.length - 1)), ans = st.words[k];
    const wrong = sample(pool.filter(w => !st.words.map(x => x.toLowerCase()).includes(w)), lv.choices - 1);
    return {
      say: null,
      stage: () => h('div', {class: 'word-row'}, h('div', {class: 'word-pic'}, img(st.img)),
        h('div', {class: 'sent'}, st.words.map((x, i) => i === k ? h('span', {class: 'blank'}, '?') : h('span', {}, x)))),
      choices: shuffle([ans, ...wrong]).map(x => ({id: x, node: () => h('span', {}, x)})), cls: 'syll words',
      answer: ans, reward: tpl('sentence', st), rewardNode: () => [img(st.img), h('div', {class: 'big sent-done'}, st.t)]
    };
  });
}

const KINDS = {rule: [ruleQ, 'ruleQ'], readsent: [readSentQ, 'readSentQ'], cloze: [clozeQ, 'clozeQ'], readword: [readWordQ, 'readWordQ'], sentence: [sentenceQ, 'sentIntro'], tone: [toneQ, 'toneQ'], onset: [onsetQ, 'onsetQ'], rime: [rimeQ, 'rimeQ'], build: [buildQ, 'onsetQ'], listen: [listenQ, 'listenQ']};

export const levels = (island, content) => content.spellLevels.map(l => ({name: l.name}));

export function run(g, island, content, li) {
  const lv = content.spellLevels[li];
  const [make, intro] = KINDS[lv.kind];
  const qs = make(content, lv);
  for (const q of qs) if (!q.onRight) q.onRight = b => fly(b, g.stage);
  return runQuiz(g, qs, {intro, combo: true, minReward: 800});
}

