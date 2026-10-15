// Khuôn "nghe rồi chọn": dùng cho chữ cái, tiếng Anh, đếm số.
// Mỗi câu hỏi: {say, label, stage?, choices:[{id,node}], answer, reward, rewardNode, cls?}
import {h, wait} from '../ui.js?v=4c51d34a6e';
import {say, sayAll, stopVoice, sfx, retry, preload, sayPhrase, clipDuration} from '../audio.js?v=4c51d34a6e';

// Huy hiệu chuỗi đúng liên tiếp (đợt 15): 3, 4, 5… câu đúng ngay lần đầu; mốc 3/5/8/10 có tiếng nhạc.
function combo(stage, n) {
  const el = h('div', {class: `combo ${[3, 5, 8, 10].includes(n) ? 'big' : ''}`}, '🔥 ', h('b', {}, n), ' liền!');
  stage.append(el);
  if ([3, 5, 8, 10].includes(n)) sfx('power');
  setTimeout(() => el.remove(), 1400);
}

export const starsFor =mistakes => mistakes === 0 ? 3 : mistakes <= 2 ? 2 : 1;

// Lặp danh sách cho đủ n phần tử, xáo trộn, tránh hai câu liền nhau trùng.
export function sequence(items, n) {
  const out = [];
  while (out.length < n) {
    const batch = [...items].sort(() => Math.random() - .5);
    if (out.length && batch[0] === out[out.length - 1] && batch.length > 1) batch.push(batch.shift());
    out.push(...batch);
  }
  return out.slice(0, n);
}

// opts.intro: khoá câu dẫn (voice.json) đọc trước câu đầu tiên.
export async function runQuiz(g, questions, opts = {}) {
  let mistakes = 0;
  // đợt 15 giọng: q.pickReward({missed, streak}) -> {say (câu hoặc mảng câu), node, anim(card, giây), min}; q.preload: câu cần tải trước;
  // q.onRight(nút) chạy hiệu ứng trước thẻ thưởng; opts.minReward (ms), opts.combo: đếm chuỗi đúng liên tiếp.
  let streak = 0;
  preload(questions.flatMap(q => [q.say, q.reward, ...(q.preload || [])]).filter(Boolean));
  // Dựng sẵn thẻ của mọi câu để tải trước hình cả bài, câu sau hiện ngay không phải chờ.
  const built = questions.map(q => q.choices.map(c => c.node()));
  for (const n of built.flat(2)) if (n instanceof Element) for (const im of (n.tagName === 'IMG' ? [n] : n.querySelectorAll('img'))) new Image().src = im.src;
  for (let i = 0; i < questions.length; i++) {
    if (g.aborted()) return null;
    g.progress(i, questions.length);
    const q = questions[i];
    // Câu không có lời đọc (bé tự đọc chữ): bỏ loa, chỉ hiện chữ.
    const promptBtn = !q.say && !q.label ? '' : h('button', {class: `prompt-btn ${q.labelCls || ''}`, onclick: () => speak()},
      q.say ? h('span', {class: 'spk'}, '🔊') : null, q.label ? h('span', {}, q.label) : null);
    async function speak() {
      if (!q.say) return;
      promptBtn.classList.add('talking'); g.stage.classList.add('saying');
      await say(q.say);
      promptBtn.classList.remove('talking'); g.stage.classList.remove('saying');
    }
    const choicesEl = h('div', {class: `choices n${q.choices.length} ${q.cls || ''}`, style: {'--n': q.cols || q.choices.length}});
    await new Promise(resolve => {
      let busy = false;
      const t0 = Date.now(), picks = [];  // đợt 15: ghi kết quả từng câu cho Báo cáo bố mẹ (g.record ở app.js)
      for (const [ci, c] of q.choices.entries()) {
        const b = h('button', {class: 'choice', onclick: async () => {
          if (busy) return;
          busy = true;
          if (c.id === q.answer) {
            try { g.record?.(q, picks, Date.now() - t0); } catch (e) { /* không làm hỏng bài */ }
            b.classList.add('right');
            sfx('correct'); g.cheer(); stopVoice();
            g.stage.classList.remove('saying');
            streak = picks.length ? 0 : streak + 1;
            if (opts.combo && streak >= 3) combo(g.stage, streak);
            if (q.onRight) await q.onRight(b);
            const r = q.pickReward ? q.pickReward({missed: picks.length > 0, streak}) : {say: q.reward, node: q.rewardNode};
            if (r.node) {
              const card = h('div', {class: 'reward'}, h('div', {class: 'card'}, r.node()));
              // Bé chạm vào thẻ thưởng là sang câu sau ngay.
              let skip;
              const skipped = new Promise(res => { skip = res; });
              card.addEventListener('pointerdown', () => { stopVoice(); skip(); });
              g.stage.append(card);
              if (r.anim) r.anim(card, await clipDuration(Array.isArray(r.say?.[0]) ? r.say[0] : r.say));
              await Promise.race([Promise.all([sayAll(r.say), wait(r.min ?? opts.minReward ?? 1100)]), skipped]);
              card.remove();
            } else {
              await Promise.all([sayAll(r.say), wait(opts.minReward ? 400 : 650)]);
            }
            resolve();
          } else {
            mistakes++;
            picks.push(c.id);
            b.classList.add('wrong');
            sfx('wrong'); g.sad();
            await retry();
            if (g.aborted()) return;
            busy = false;
            speak();
          }
        }}, built[i][ci]);
        choicesEl.append(b);
      }
      g.stage.replaceChildren(promptBtn, q.stage ? q.stage() : '', choicesEl);
      // Chờ hình tải: do watchStage (ui.js) lo cho mọi màn học.
      // Câu đầu: hiện đề, đọc câu dẫn, nghỉ một nhịp rồi mới đọc từ (không dính liền, không nuốt câu hỏi).
      // Bé chạm đáp án giữa chừng thì thôi không đọc đề nữa.
      if (i === 0 && opts.intro) {
        (async () => {
          await sayPhrase(opts.intro);
          await wait(350);
          if (!busy && !g.aborted()) speak();
        })();
      } else speak();
    });
  }
  g.progress(questions.length, questions.length);
  return {stars: starsFor(mistakes)};
}
