// Đảo Âm nhạc: đàn mộc cầm 8 phím, học bài hát theo phím sáng, trò nhắc lại giai điệu.
import {h, wait} from '../ui.js?v=4c51d34a6e';
import {note, sayPhrase, sfx, stopVoice} from '../audio.js?v=4c51d34a6e';
import {t} from '../i18n.js?v=4c51d34a6e';
import {starsFor} from './quiz.js?v=4c51d34a6e';

const NAMES = ['Đô', 'Rê', 'Mi', 'Fa', 'Son', 'La', 'Si', 'Đô'];
const COLORS = ['#ff6b6b', '#ff922b', '#ffc93c', '#51cf66', '#22b8cf', '#4c6ef5', '#9c5cf5', '#f06595'];

function keyboard(onKey) {
  const keys = NAMES.map((n, i) => {
    const k = h('button', {class: 'xkey', style: {'--c': COLORS[i], '--h': (100 - i * 6) + '%'}}, h('span', {}, n));
    const hit = e => { e.preventDefault(); press(k, i); onKey(i); };
    k.addEventListener('pointerdown', hit);
    return k;
  });
  return {el: h('div', {class: 'xylo'}, keys), keys};
}

function press(k, i) {
  note(i);
  k.classList.remove('hit'); void k.offsetWidth; k.classList.add('hit');
}

function free(g) {
  let taps = 0;
  const doneBtn = h('button', {class: 'btn green', disabled: true}, '✔ ', t('done'));
  const kb = keyboard(() => { if (++taps >= 8) doneBtn.disabled = false; });
  g.stage.replaceChildren(h('div', {class: 'music'}, kb.el, doneBtn));
  g.progress(0, 1);
  sayPhrase('freeQ');
  return new Promise(resolve => { doneBtn.onclick = () => { g.progress(1, 1); resolve({stars: 3}); }; });
}

function song(g, s) {
  let pos = 0, mistakes = 0, demo = false;
  const kb = keyboard(i => {
    if (demo) return;
    if (i === s.notes[pos]) {
      pos++;
      g.progress(pos, s.notes.length);
      if (pos === s.notes.length) { finish(); return; }
      light();
    } else {
      mistakes++;
      kb.keys[i].classList.remove('nope'); void kb.keys[i].offsetWidth; kb.keys[i].classList.add('nope');
    }
  });
  const light = () => kb.keys.forEach((k, i) => k.classList.toggle('next', i === s.notes[pos]));
  const listen = h('button', {class: 'btn blue'}, '▶ ', t('listen'));
  listen.onclick = async () => {
    if (demo) return;
    demo = true; listen.disabled = true; stopVoice();
    kb.keys.forEach(k => k.classList.remove('next'));
    for (const n of s.notes) {
      if (g.aborted()) return;
      press(kb.keys[n], n);
      await wait(420);
    }
    demo = false; listen.disabled = false; light();
  };
  g.stage.replaceChildren(h('div', {class: 'music'}, h('div', {class: 'song-title'}, '🎵 ', s.title), kb.el, listen));
  g.progress(0, s.notes.length);
  sayPhrase('songQ');
  light();
  let finish;
  return new Promise(resolve => {
    finish = async () => {
      kb.keys.forEach(k => k.classList.remove('next'));
      sfx('correct'); g.cheer();
      await wait(500);
      resolve({stars: mistakes <= 3 ? 3 : mistakes <= 8 ? 2 : 1});
    };
  });
}

// Nhắc lại giai điệu: 4 ô màu, chuỗi dài dần tới mục tiêu.
function simon(g, lv) {
  const PADS = [[0, '#ff6b6b'], [2, '#ffc93c'], [4, '#51cf66'], [7, '#4c6ef5']];
  let seq = [], input = 0, listening = false, mistakes = 0;
  const pads = PADS.map(([n, c], i) => {
    const p = h('button', {class: 'pad', style: {'--c': c}});
    p.addEventListener('pointerdown', e => { e.preventDefault(); tap(i); });
    return p;
  });
  const flash = async i => { note(PADS[i][0], .6); pads[i].classList.add('lit'); await wait(380); pads[i].classList.remove('lit'); await wait(140); };
  g.stage.replaceChildren(h('div', {class: 'simon'}, pads));
  g.progress(0, lv.goal);
  let resolveFn;
  async function play() {
    listening = false;
    await wait(600);
    for (const i of seq) { if (g.aborted()) return; await flash(i); }
    input = 0; listening = true;
  }
  async function tap(i) {
    if (!listening) return;
    note(PADS[i][0], .5);
    pads[i].classList.add('lit'); setTimeout(() => pads[i].classList.remove('lit'), 220);
    if (i !== seq[input]) {
      mistakes++; listening = false; sfx('wrong'); g.sad();
      await wait(700); play();
      return;
    }
    input++;
    if (input === seq.length) {
      listening = false;
      g.progress(seq.length, lv.goal);
      if (seq.length >= lv.goal) { sfx('correct'); g.cheer(); await wait(600); return resolveFn({stars: starsFor(mistakes)}); }
      sfx('star'); g.cheer();
      seq.push(Math.floor(Math.random() * 4));
      if (seq.length === 3) await sayPhrase('simonMore');
      play();
    }
  }
  return new Promise(async resolve => {
    resolveFn = resolve;
    await sayPhrase('simonQ');
    seq = [Math.floor(Math.random() * 4), Math.floor(Math.random() * 4)];
    play();
  });
}

export const levels = (island, content) => content.musicLevels.map(l => ({name: l.name, img: l.img}));

export function run(g, island, content, li) {
  const lv = content.musicLevels[li];
  g.hideBuddy();
  if (lv.kind === 'free') return free(g);
  if (lv.kind === 'simon') return simon(g, lv);
  const s = content.songs.find(x => x.id === lv.song);
  return song(g, {...s, title: lv.name});
}

