/* site.js — UI controller for the Sakum Lang website.
 * Wires the in-browser interpreter (sakum.js) to the playground,
 * renders the pipeline visualizer, and streams the self-learning
 * engine state from memory.md / learn.md.
 */
(function () {
  "use strict";

  // -------- sample programs ------------------------------------------------
  const SAMPLES = {
    app:
 `# heartbeat.sakum — a survivability simulator on the self engine
# Type in Hinglish; the converter transliterates to Devanagari.
naam rate = 60;
naam samples = vec(60, 72, 81, 65, 90);
naam peak = 0;
naam total = 0;
naam i = 0;

yavat (i < 5) {
    naam s = samples[i];
    total = total + s;
    yadi (s > peak) { peak = s; }
    i = i + 1;
}

naam mean = total / 5;

kriya status(hr) {
    yadi (hr > 100) { pratyagam "tachycardia"; }
    anyatha yadi (hr < 50) { pratyagam "bradycardia"; }
    anyatha { pratyagam "nominal"; }
}

lek("mean bpm: ");
lek(mean);
lek("peak bpm: ");
lek(peak);
lek("diagnosis: ");
lek(status(peak));
lek(latex(vec(mean, peak)));
lek(puls(1));
`,
    math:
`# math.sakum — built-in scientific core
naam v1 = vec(1, 2, 3);
naam v2 = vec(4, 5, 6);
lek(v1 + v2);          # [5, 7, 9]
lek(dot(v1, v2));      # 32
lek(norm(v1));         # sqrt(14)
lek(gcd(48, 18));      # 6
lek(factorial(5));     # 120
lek(fib(10));          # 55
lek(isprime(97));      # satya
lek(latex(v1));
`,
    vec:
`# vectors.sakum — first-class SIMD
naam a = vec(1, 2, 3, 4);
naam b = vec(5, 6, 7, 8);
lek(a + b);            # lane-wise add
lek(a * 2);            # broadcast scalar
lek(cross(vec(1,0,0), vec(0,1,0)));  # (0,0,1)
lek(simd_info());      # reported by the backend
`,
  };

  // -------- Hinglish -> Devanagari live converter ----------------------
  // Type a word in Hinglish; on Space it is transliterated to Devanagari.
  // A suggestion bar shows candidates; click to accept.
  function attachHinglish(ta, bar) {
    if (!bar || !window.Hinglish) return;
    function currentWord() {
      const p = ta.selectionStart;
      const v = ta.value;
      let s = p;
      while (s > 0 && !/[\s(.,;){}=+\-*/%<>]/.test(v[s - 1])) s--;
      return { start: s, end: p, text: v.slice(s, p) };
    }
    function showSug(word) {
      bar.innerHTML = "";
      if (!word) return;
      const cands = window.Hinglish.suggest(word, 5);
      cands.forEach((c) => {
        const b = document.createElement("button");
        b.className = "px-2 py-0.5 rounded-md bg-sakum-500/15 border border-sakum-500/40 text-sakum-200 hover:bg-sakum-500/30 text-sm dev";
        b.textContent = c || "∅";
        b.addEventListener("click", () => {
          const p = ta.selectionStart;
          ta.setRangeText(c, wordStart, p, "end");
          bar.innerHTML = "";
          ta.focus();
        });
        bar.appendChild(b);
      });
    }
    let wordStart = 0;
    ta.addEventListener("input", () => {
      const w = currentWord();
      wordStart = w.start;
      showSug(w.text);
    });
    ta.addEventListener("keydown", (e) => {
      if (e.key === " " || e.key === "Spacebar") {
        const w = currentWord();
        if (w.text && window.Hinglish.convertWord(w.text) !== w.text) {
          e.preventDefault();
          const conv = window.Hinglish.convertWord(w.text);
          const p = ta.selectionStart;
          ta.setRangeText(conv + " ", w.start, p, "end");
          bar.innerHTML = "";
        } else {
          bar.innerHTML = "";
        }
      }
    });
  }
  attachHinglish(document.getElementById("code"), document.getElementById("sugBar"));
  attachHinglish(document.getElementById("tutCode"), document.getElementById("tutSug"));

  // -------- playground -----------------------------------------------------
  const codeEl = document.getElementById("code");
  const outEl = document.getElementById("out");
  const latexEl = document.getElementById("latex");
  const pulseBadge = document.getElementById("pulseBadge");

  function runCode() {
    outEl.textContent = "";
    latexEl.innerHTML = "";
    let captured = [];
    let pulses = 0;
    try {
      const res = Sakum.run(codeEl.value, (s) => captured.push(s));
      pulses = res.pulses;
      outEl.textContent = captured.join("\n");
      // render any latex output lines
      const tex = captured.filter((s) => s.trim().startsWith("\\begin")).pop();
      if (tex && window.katex) {
        try { katex.render(tex, latexEl, { throwOnError: false }); }
        catch (e) { latexEl.textContent = tex; }
      } else if (tex) {
        latexEl.textContent = tex;
      }
    } catch (e) {
      outEl.textContent = "⚠ " + e.message;
      outEl.className = outEl.className.replace("text-emerald-300", "text-rose-400");
      setTimeout(() => outEl.className = outEl.className.replace("text-rose-400", "text-emerald-300"), 50);
    }
    pulseBadge.textContent = "puls " + pulses;
  }

  document.getElementById("runBtn").addEventListener("click", runCode);
  codeEl.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") { e.preventDefault(); runCode(); }
  });
  document.querySelectorAll("[data-sample]").forEach((b) => {
    b.addEventListener("click", () => { codeEl.value = SAMPLES[b.dataset.sample]; runCode(); });
  });
  codeEl.value = SAMPLES.app;

  // -------- pipeline visualizer -------------------------------------------
  const PIPES = {
    c: {
      title: "Classic C Pipeline (stages 71–78)",
      stages: ["SOURCE", "71 Text Encoding", "72 Lexical Analysis", "73 Parsing (AST)",
        "74 Semantic Analysis", "75 Intermediate Repr.", "76 Optimizations",
        "77 CodeGen+Asm+Link", "78 Loader→CPU", "Sandbox + Prod Gate"],
    },
    sakum: {
      title: "Sakum Full Pipeline (stages 13–62)",
      stages: ["SHARED 1–12", "13 Ownership/Lifetime", "14 Borrow/Memory Safety",
        "15 Generics", "16 CTFE", "17 Const Fold", "18 HIR", "19 HIR Verify",
        "20 HIR Opt", "21 MIR/SSA", "22 CFG", "23 Dataflow", "24 Alias/Escape",
        "25 Mem Opt", "26 Security", "27 DCE/Inline", "28 Loop/Vec", "29 LIR",
        "30 Backend Check", "31–47 Native/VM/WASM", "48–57 Link+Sign+Sec",
        "58 OS Loader", "59 CRT Init", "60 Mem Layout", "61 Fetch/Decode/Exec",
        "62 Sandbox", "Prod Gate (ask_patch)"],
    },
    wasm: {
      title: "WASM-Only Pipeline (stages 81–88)",
      stages: ["SHARED 1–12", "81 Text Encoding", "82 Lex+Semantic", "83 WASM IR",
        "84 Verify+Opt", "85 .wasm Emit", "86 WASM Linker", "87 WASM Binary",
        "88 WASM Runtime→CPU", "Sandbox + Prod Gate"],
    },
  };

  const pipeView = document.getElementById("pipeView");
  function renderPipe(key) {
    const p = PIPES[key];
    let html = `<div class="text-white font-semibold mb-3">${p.title}</div><div class="flex flex-wrap gap-2">`;
    p.stages.forEach((s, i) => {
      const cls = s.startsWith("SHARED") ? "stage-ok" : (s.includes("Gate") ? "stage-run" : "bg-white/5 border-white/10");
      html += `<div class="px-3 py-1.5 rounded-lg border text-xs text-slate-200 ${cls}">${s}</div>`;
      if (i < p.stages.length - 1) html += `<span class="text-slate-600 self-center">→</span>`;
    });
    html += `</div>`;
    pipeView.innerHTML = html;
  }
  document.querySelectorAll(".pipe-card").forEach((c) => {
    c.addEventListener("click", () => renderPipe(c.dataset.pipe));
  });
  renderPipe("sakum");

  // -------- self-learning engine (from memory.md / learn.md) --------------
  async function loadEngine() {
    try {
      const [mem, learn] = await Promise.all([
        fetch("memory.md").then((r) => r.text()).catch(() => ""),
        fetch("learn.md").then((r) => r.text()).catch(() => ""),
      ]);
      const text = mem + "\n" + learn;
      const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
      const ledger = document.getElementById("ledger");
      const items = lines.filter((l) => /fail|error|bug|fix|mistake|ledger|patch|learned|survive/i.test(l)).slice(0, 8);
      ledger.innerHTML = items.length
        ? items.map((t) => `<li class="border-l-2 border-sakum-500 pl-3">${escapeHtml(t.slice(0, 120))}</li>`).join("")
        : `<li class="text-slate-500">no entries yet — run the engine.</li>`;
      // survivability: derive from memory.md's own counters
      const survive = parseInt((text.match(/survive:\s*(\d+)/) || [])[1] || "0", 10);
      const mistakes = (text.match(/^mistake\s/gm) || []).length;
      const total = survive + mistakes || 1;
      const score = Math.round((survive / total) * 100);
      document.getElementById("survScore").textContent = score + "%";
      document.getElementById("survBar").style.width = score + "%";
      const last = (text.match(/last_cycle:\s*(\S+)/) || [])[1] || lines.filter((l) => /cycle|pulse|update|patch/i.test(l)).pop() || "—";
      document.getElementById("lastCycle").textContent = "last cycle: " + String(last).slice(0, 80);
    } catch (e) {
      document.getElementById("ledger").innerHTML = `<li class="text-rose-400">could not load engine state.</li>`;
    }
  }
  function escapeHtml(s) {
    return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
  }
  loadEngine();

  // -------- tutorials (step-by-step course) -------------------------------
  (function tutorials() {
    if (!window.SAKUM_TUTORIALS) return;
    const LS = "sakum_tut_done";
    let done = {};
    try { done = JSON.parse(localStorage.getItem(LS) || "{}"); } catch (e) {}
    const list = window.SAKUM_TUTORIALS;
    const nav = document.getElementById("tutNav");
    const titleEl = document.getElementById("tutTitle");
    const devEl = document.getElementById("tutDev");
    const theoryEl = document.getElementById("tutTheory");
    const codeEl = document.getElementById("tutCode");
    const outEl = document.getElementById("tutOut");
    const taskEl = document.getElementById("tutTask");
    const msgEl = document.getElementById("tutMsg");
    const progEl = document.getElementById("tutProgress");
    let cur = 0;

    function renderNav() {
      nav.innerHTML = list.map((l, i) =>
        `<button data-i="${i}" class="w-full text-left px-3 py-2 rounded-lg text-sm flex items-center gap-2 ${i === cur ? "bg-sakum-500/20 border border-sakum-500 text-white" : "border border-transparent text-slate-300 hover:bg-white/5"}">
           <span class="${done[l.id] ? "text-emerald-400" : "text-slate-600"}">${done[l.id] ? "✓" : "○"}</span>
           <span class="truncate">${l.title}</span>
         </button>`).join("");
      nav.querySelectorAll("button").forEach((b) => b.addEventListener("click", () => load(+b.dataset.i)));
      const n = list.filter((l) => done[l.id]).length;
      progEl.textContent = n + " / " + list.length + " done";
    }
    function load(i) {
      cur = i;
      const l = list[i];
      titleEl.textContent = l.title;
      devEl.textContent = "Devanagari: " + l.dev;
      theoryEl.innerHTML = l.theory;
      codeEl.value = l.code;
      taskEl.innerHTML = "<span class='text-amber-300 font-medium'>Task:</span> " + l.task;
      outEl.textContent = "";
      msgEl.textContent = done[l.id] ? "completed ✓" : "";
      msgEl.className = "text-xs " + (done[l.id] ? "text-emerald-400" : "text-slate-400");
      renderNav();
    }
    function runTut() {
      outEl.textContent = "";
      try {
        const o = [];
        Sakum.run(codeEl.value, (s) => o.push(s));
        outEl.textContent = o.join("\n");
      } catch (e) {
        outEl.textContent = "⚠ " + e.message;
      }
    }
    document.getElementById("tutRun").addEventListener("click", runTut);
    document.getElementById("tutDone").addEventListener("click", () => {
      done[list[cur].id] = true;
      localStorage.setItem(LS, JSON.stringify(done));
      msgEl.textContent = "completed ✓";
      msgEl.className = "text-xs text-emerald-400";
      renderNav();
    });
    document.getElementById("tutReset").addEventListener("click", () => {
      done = {};
      localStorage.removeItem(LS);
      renderNav();
      msgEl.textContent = "";
    });
    codeEl.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") { e.preventDefault(); runTut(); }
    });
    renderNav();
    load(0);
  })();

  // boot
  runCode();
})();
