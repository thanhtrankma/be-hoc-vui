// Đảo Đọc truyện: truyện tranh chữ sáng theo giọng đọc (chạm từ để nghe), nghe – viết chính tả, bé đọc to.
import {h, img, sample, shuffle, wait, overlay, toneMark} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sayPhrase, sfx, stopVoice, preload, clipDuration, phrase} from '../audio.js?v=4c51d34a6e';
import {t} from '../i18n.js?v=4c51d34a6e';
import {runQuiz, starsFor, sequence} from './quiz.js?v=4c51d34a6e';
import {placeTone as toned} from './spell.js?v=4c51d34a6e';

const line = text => tpl('storyLine', {t: text});
const wordV = w => tpl('storyWord', {w: w.toLowerCase()});
const praise = () => phrase('praise' + (1 + Math.floor(Math.random() * 6)));

// Một dòng chữ: mỗi từ là một nút chạm-để-nghe.
function lineEl(text) {
  const el = h('p', {class: 'sline'});
  for (const tok of text.split(/(\s+)/)) {
    if (/^\s+$/.test(tok)) { el.append(tok); continue; }
    const m = tok.match(/^([\wÀ-ỹ]+)(.*)$/u);
    if (!m) { el.append(tok); continue; }
    const w = h('button', {class: 'sw-word', onclick: e => { e.stopPropagation(); say(wordV(m[1])); }}, m[1]);
    el.append(w, m[2]);
  }
  return el;
}

// Đọc một dòng và tô sáng từng từ theo thời gian ước lượng (theo độ dài chữ và dấu câu).
async function readLine(el, text, alive) {
  const words = [...el.querySelectorAll('.sw-word')];
  const item = line(text);
  const dur = await clipDuration(item);
  const weights = words.map(w => {
    const next = w.nextSibling && w.nextSibling.nodeType === 3 ? w.nextSibling.textContent : '';
    return w.textContent.length + 2 + (/[,.!?]/.test(next) ? 4 : 0);
  });
  const total = weights.reduce((a, b) => a + b, 0) || 1;
  const p = say(item);
  let acc = 0;
  const timers = words.map((w, i) => {
    const at = (acc / total) * dur * 1000 * .96;
    acc += weights[i];
    return setTimeout(() => { if (!alive()) return; words.forEach(x => x.classList.remove('hl')); w.classList.add('hl'); w.classList.add('read'); }, at);
  });
  await p;
  timers.forEach(clearTimeout);
  words.forEach(x => { x.classList.remove('hl'); x.classList.add('read'); });
}

async function story(g, lv, content) {
  const st = content.stories.find(s => s.id === lv.story);
  preload([line(st.title + '.'), ...st.pages.flatMap(p => p.lines.map(line))]);
  const total = st.pages.length + st.qs.length;
  let alive = true;
  const isAlive = () => alive && !g.aborted();
  g.hideBuddy();
  for (let i = 0; i < st.pages.length; i++) {
    if (!isAlive()) return null;
    g.progress(i, total);
    const pg = st.pages[i];
    const lines = pg.lines.map(lineEl);
    const again = h('button', {class: 'btn ghost'}, '🔊 ', t('readAgain'));
    const next = h('button', {class: 'btn green', disabled: true}, t('nextPage'), ' ➜');
    g.stage.replaceChildren(h('div', {class: 'storypage'},
      i === 0 ? h('h2', {class: 'stitle'}, st.title) : null,
      h('div', {class: 'simgs'}, pg.imgs.map(x => img(x))),
      h('div', {class: 'stext'}, lines),
      h('div', {class: 'row'}, again, next)));
    const readAll = async () => {
      again.disabled = true;
      if (i === 0) await say(line(st.title + '.'));
      for (let k = 0; k < lines.length; k++) { if (!isAlive()) return; await readLine(lines[k], pg.lines[k], isAlive); await wait(250); }
      again.disabled = false; next.disabled = false;
    };
    again.onclick = () => { stopVoice(); readAll(); };
    readAll();
    await new Promise(res => { next.onclick = () => { stopVoice(); sfx('flip'); res(); }; });
  }
  if (!isAlive()) return null;
  // Câu hỏi đọc hiểu.
  const qs = st.qs.map(q => {
    let choices, answer = q.a;
    if (q.img) choices = shuffle(q.img).map(x => ({id: x, node: () => img(x)}));
    else if (q.color) choices = shuffle(q.color).map(([name, c]) => ({id: name, node: () => h('span', {class: 'swatch', style: {background: c}})}));
    else choices = shuffle(q.text).map(x => ({id: x, node: () => h('span', {class: 'tword'}, x)}));
    return {say: line(q.q), label: q.q, choices, answer, reward: praise(), cls: q.text ? 'syll' : ''};
  });
  const offset = st.pages.length;
  const g2 = {...g, progress: (i, n) => g.progress(offset + i, total)};
  return runQuiz(g2, qs, {intro: 'storyQ'});
}

// ---------- Nghe – viết: ghép âm đầu + vần + dấu ----------
const VOWELS = ['a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư', 'y'];
// lv.rimes: bài theo nhóm vần (chỉ lấy tiếng có vần trong nhóm).
const poolOf = (content, lv) => content.vnwords.filter(w => lv.words ? lv.words.includes(w.w) : lv.rimes ? lv.rimes.includes(w.v) : (lv.pool === 'all' || (lv.pool === 'rime' ? w.v.length > 1 : w.v.length === 1)));
const TONES = ['ngang', 'huyền', 'sắc', 'hỏi', 'ngã', 'nặng'];

async function dictation(g, lv, content) {
  const words = sequence(poolOf(content, lv).filter(w => lv.tones.includes(w.tone)), 6);
  preload(words.flatMap(w => [tpl('vnWord', w), tpl('spell', w)]));
  let mistakes = 0;
  await sayPhrase('dictIntro');
  for (let i = 0; i < words.length; i++) {
    if (g.aborted()) return null;
    g.progress(i, words.length);
    const w = words[i];
    const pick = {c: null, v: null, t: null};
    const slots = {c: h('span', {class: 'dslot'}), v: h('span', {class: 'dslot'}), t: h('span', {class: 'dslot tone'})};
    const keys = h('div', {class: 'dkeys'});
    const stepLbl = h('div', {class: 'dstep'});
    const speak = h('button', {class: 'prompt-btn'}, h('span', {class: 'spk'}, '🔊'));
    speak.onclick = () => say(tpl('vnWord', w));
    const show = h('div', {class: 'dword'});
    g.stage.replaceChildren(h('div', {class: 'dict'}, speak, h('div', {class: 'dslots'}, slots.c, slots.v, slots.t), show, stepLbl, keys));
    say(tpl('vnWord', w));
    const render = () => {
      slots.c.textContent = pick.c || '?';
      slots.v.textContent = pick.v ? (pick.t ? toned(pick.v, pick.t) : pick.v) : '?';
      slots.t.replaceChildren(pick.t ? toneMark(pick.t) : '?');
      ['c', 'v', 't'].forEach(k => slots[k].classList.toggle('on', !!pick[k]));
      show.textContent = (pick.c || '') + (pick.v ? (pick.t ? toned(pick.v, pick.t) : pick.v) : '');
    };
    await new Promise(resolve => {
      const step = () => {
        render();
        const k = !pick.c ? 'c' : !pick.v ? 'v' : !pick.t ? 't' : null;
        if (!k) return check();
        stepLbl.textContent = {c: t('stepC'), v: t('stepV'), t: t('stepT')}[k];
        // Bàn phím vần: vần đúng + vài vần gây nhiễu (không bày hết 40 vần).
        // Học cùng lớp (lv.know): bàn phím chỉ có âm, vần, dấu bé đã học.
        const K = lv.know;
        const list = k === 'c' ? (K ? content.consonants.filter(c => K.c.includes(c)) : content.consonants)
          : k === 'v' ? shuffle([w.v, ...sample((K ? K.v : [...VOWELS, ...(lv.pool ? (content.rimes || []) : [])]).filter(r => r !== w.v), 11)])
          : (K ? TONES.filter(x => K.t.includes(x)) : TONES);
        keys.className = `dkeys k-${k}`;
        keys.replaceChildren(...list.map(x => h('button', {class: 'dkey', onclick: () => { sfx('tap'); pick[k] = x; step(); }},
          k === 't' ? toned(pick.v, x) : x)));
      };
      const check = async () => {
        keys.replaceChildren();
        const ok = pick.c === w.c && pick.v === w.v && pick.t === w.tone;
        if (ok) {
          sfx('correct'); g.cheer();
          const card = h('div', {class: 'reward'}, h('div', {class: 'card'}, img(w.img), h('div', {class: 'big'}, w.w)));
          g.stage.append(card);
          await Promise.all([say(tpl('spell', w)), wait(1200)]);
          return resolve();
        }
        mistakes++; sfx('wrong'); g.sad();
        if (pick.c !== w.c) slots.c.classList.add('bad');
        if (pick.v !== w.v) slots.v.classList.add('bad');
        if (pick.t !== w.tone) slots.t.classList.add('bad');
        await wait(900);
        Object.values(slots).forEach(s => s.classList.remove('bad'));
        if (pick.c !== w.c) pick.c = null;
        if (pick.v !== w.v) { pick.v = null; pick.t = null; }
        if (pick.t !== w.tone) pick.t = null;
        say(tpl('vnWord', w));
        step();
      };
      // Chạm ô đã chọn để chọn lại.
      slots.c.onclick = () => { pick.c = null; step(); };
      slots.v.onclick = () => { pick.v = null; pick.t = null; step(); };
      slots.t.onclick = () => { pick.t = null; step(); };
      step();
    });
  }
  g.progress(words.length, words.length);
  return {stars: starsFor(Math.max(0, mistakes - 1))};
}

// ---------- Bé đọc to: nhận giọng (nếu máy hỗ trợ) hoặc bố mẹ chấm ----------
// Nhận giọng của trình duyệt gửi tiếng bé tới máy chủ của hãng (Chrome: Google, Safari: Apple).
// Hỏi bố mẹ một lần trước lần bấm micro đầu tiên; từ chối thì chỉ dùng nút "Bố mẹ chấm".
const MIC_KEY = 'bvh.micOK';
const micPref = () => { try { return localStorage.getItem(MIC_KEY); } catch (e) { return null; } };
function micConsent(g) {
  if (micPref() === '1') return Promise.resolve(true);
  return new Promise(resolve => {
    const done = async yes => {
      ov.remove();
      if (yes && g.gate && !(await g.gate())) return resolve(false);
      try { localStorage.setItem(MIC_KEY, yes ? '1' : '0'); } catch (e) { /* trình duyệt chặn lưu: hỏi lại lần sau */ }
      resolve(yes);
    };
    const ov = overlay(
      h('h2', {}, '🎤 Bật micro?'),
      h('p', {class: 'note'}, 'Để nghe bé đọc, trình duyệt gửi giọng của bé tới dịch vụ nhận giọng của hãng (Chrome gửi Google, Safari gửi Apple). DatPilot không ghi âm và không lưu giọng của bé.'),
      h('p', {class: 'note'}, 'Không bật thì bố mẹ nghe bé đọc rồi bấm “Đúng rồi”.'),
      h('div', {class: 'row'},
        h('button', {class: 'btn green', onclick: () => done(true)}, 'Bố mẹ đồng ý'),
        h('button', {class: 'btn ghost', onclick: () => done(false)}, 'Không bật')));
  });
}

const norm = s => s.toLowerCase().normalize('NFC').replace(/[^\p{L}\s]/gu, ' ');

async function aloud(g, content) {
  const words = sample(content.vnwords, 6);
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const useMic = SR && micPref() !== '0';   // bố mẹ đã chọn "Không bật" thì như máy không có micro
  await sayPhrase(useMic ? 'aloudIntro' : 'aloudParent');
  for (let i = 0; i < words.length; i++) {
    if (g.aborted()) return null;
    g.progress(i, words.length);
    const w = words[i];
    const status = h('div', {class: 'astatus'}, useMic ? '' : SR ? t('micOff') : t('micNA'));
    const mic = useMic ? h('button', {class: 'mic'}, '🎤') : null;
    const ok = h('button', {class: 'small-btn good'}, '✔ ', t('correct'));
    const again = h('button', {class: 'small-btn'}, '🔊');
    const skip = h('button', {class: 'small-btn'}, t('skip'), ' ➜');
    g.stage.replaceChildren(h('div', {class: 'aloud'},
      h('div', {class: 'aword'}, img(w.img), h('span', {}, w.w)),
      mic, status,
      h('div', {class: 'acheck'}, h('span', {}, t('parentCheck')), ok, again, skip)));
    await new Promise(resolve => {
      let done = false;
      const win = async () => {
        if (done) return; done = true;
        sfx('correct'); g.cheer();
        await say(praise());
        resolve();
      };
      ok.onclick = win;
      skip.onclick = () => { done = true; resolve(); };
      again.onclick = () => say(tpl('vnWord', w));
      if (!mic) return;
      mic.onclick = async () => {
        if (!(await micConsent(g))) { mic.remove(); status.textContent = t('micOff'); return; }
        if (done || !mic.isConnected) return;
        let rec;
        try { rec = new SR(); } catch (e) { status.textContent = t('micNA'); return; }
        rec.lang = 'vi-VN'; rec.interimResults = false; rec.maxAlternatives = 5;
        mic.classList.add('on'); status.textContent = t('listening');
        rec.onresult = e => {
          const alts = [...e.results[0]].map(a => norm(a.transcript));
          if (alts.some(a => a.split(/\s+/).includes(norm(w.w).trim()))) win();
          else { status.textContent = `“${alts[0].trim()}”`; sfx('wrong'); sayPhrase('aloudTry'); }
        };
        rec.onerror = () => { status.textContent = t('micNA'); };
        rec.onend = () => mic.classList.remove('on');
        try { rec.start(); } catch (e) { status.textContent = t('micNA'); }
      };
    });
  }
  g.progress(words.length, words.length);
  return {stars: 3};
}

export const levels = (island, content) => content.readLevels.map(l => ({name: l.name, img: l.img}));

export function run(g, island, content, li) {
  const lv = content.readLevels[li];
  g.hideBuddy();
  if (lv.kind === 'dictation') return dictation(g, lv, content);
  if (lv.kind === 'aloud') return aloud(g, content);
  return story(g, lv, content);
}
