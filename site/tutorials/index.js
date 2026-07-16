/* tutorials/index.js — step-by-step Sakum Lang course.
 * Each lesson is data: { id, title, dev (Hinglish focus), theory, code, task }.
 * Rendered by the Tutorials section in index.html. Lessons run live in the
 * same in-browser interpreter (sakum.js) as the playground.
 *
 * KEYWORDS: type in Hinglish (Romanized). The converter transliterates
 * Hinglish -> Devanagari. All three forms are accepted by the interpreter:
 *   Hinglish      Devanagari     ASCII
 *   naam          नाम            let
 *   kriya         क्रिया          fn
 *   yadi          यदि            if
 *   anyatha       अन्यथा          else
 *   yavat        यावत्          while
 *   paryantam    पर्यन्तम्        for
 *   pratyagam    प्रत्यागम        return
 *   satya         सत्य            true
 *   asatya       असत्य          false
 *   shunya        शून्य          null
 *   lek           लेख            print
 *   vektr         वेक्टर          vektor
 *   puls          पल्स            pulse
 */
window.SAKUM_TUTORIALS = [
  {
    id: "l01",
    title: "1 · Your first Sakum program",
    dev: "naam · lek",
    theory:
      "Every Sakum program is a sequence of statements. <code>naam</code> (Devanagari: नाम, ASCII: <code>let</code>) " +
      "declares a variable; <code>lek</code> (Devanagari: लेख, ASCII: <code>print</code>) writes to output. " +
      "Comments start with <code>#</code>. Type in Hinglish — the converter turns it into Devanagari — or use the ASCII alias.",
    code:
`# my first program
naam greeting = "namaste sakum";
lek(greeting);
lek("the answer is ");
naam x = 21 * 2;
lek(x);`,
    task: "Change x to 6 * 7 and re-run. Try the ASCII alias: replace naam with let and lek with print.",
  },
  {
    id: "l02",
    title: "2 · Arithmetic & types",
    dev: "numbers · booleans",
    theory:
      "Sakum has numbers, strings, booleans (satya/asatya = true/false), and shunya (null). " +
      "Operators: <code>+ - * / %</code> and comparisons <code>&lt; &gt; &lt;= &gt;= == !=</code>. " +
      "Use parentheses to group. Truthiness: 0 is false, everything else is true.",
    code:
`naam a = 10;
naam b = 3;
lek(a + b);     # 13
lek(a - b);     # 7
lek(a * b);     # 30
lek(a / b);     # 3.333...
lek(a % b);     # 1
lek(a > b);     # satya
lek(a == b);    # asatya`,
    task: "Add a line computing (a + b) * 2 and print it. What does lek(satya) print?",
  },
  {
    id: "l03",
    title: "3 · Functions",
    dev: "kriya · pratyagam",
    theory:
      "Define a function with <code>kriya</code> (Devanagari: क्रिया, ASCII: <code>fn</code>) and return a value with " +
      "<code>pratyagam</code> (Devanagari: प्रत्यागम, ASCII: <code>return</code>). Functions are first-class; call them by name with arguments in parens.",
    code:
`kriya square(n) {
    pratyagam n * n;
}

kriya add(a, b) {
    pratyagam a + b;
}

lek(square(5));      # 25
lek(add(3, 4));     # 7
lek(square(add(1, 2))); # 9`,
    task: "Write a function `factorial(k)` using a loop, and print factorial(5) (should be 120).",
  },
  {
    id: "l04",
    title: "4 · Conditionals",
    dev: "yadi · anyatha",
    theory:
      "Branch with <code>yadi</code> / <code>anyatha</code> (if / else). Chain with <code>anyatha yadi</code> (else if). " +
      "Blocks use braces <code>{ }</code>.",
    code:
`kriya sign(n) {
    yadi (n > 0) {
        pratyagam "positive";
    } anyatha yadi (n < 0) {
        pratyagam "negative";
    } anyatha {
        pratyagam "zero";
    }
}

lek(sign(10));
lek(sign(-4));
lek(sign(0));`,
    task: "Write a function `max(a,b)` that returns the larger of two numbers using yadi/anyatha.",
  },
  {
    id: "l05",
    title: "5 · Loops (while & for)",
    dev: "yavat · paryantam",
    theory:
      "Repeat with <code>yavat</code> (while) and <code>paryantam</code> (for). The for-header is " +
      "<code>(init; condition; increment)</code> — exactly like C, but with Sakum keywords.",
    code:
`# while: sum 1..5
naam i = 1;
naam sum = 0;
yavat (i <= 5) {
    sum = sum + i;
    i = i + 1;
}
lek(sum);   # 15

# for: print squares 0..4
paryantam (naam k = 0; k < 5; k = k + 1) {
    lek(k * k);
}`,
    task: "Use a for-loop to compute and print the sum of even numbers 2..10.",
  },
  {
    id: "l06",
    title: "6 · Vectors (first-class SIMD)",
    dev: "vektr · vec",
    theory:
      "Vectors are first-class. <code>vec(...)</code> builds one; you can add/subtract/multiply " +
      "vector-by-vector or vector-by-scalar (broadcast). Index with <code>v[i]</code>, get length with <code>len(v)</code>. " +
      "The backend emits AVX2 / NEON / RVV for these ops automatically.",
    code:
`naam a = vec(1, 2, 3, 4);
naam b = vec(5, 6, 7, 8);
lek(a + b);        # [6, 8, 10, 12]
lek(a * 2);        # [2, 4, 6, 8]
lek(a[0]);         # 1
a[1] = 99;
lek(a[1]);        # 99
lek(len(a));       # 4`,
    task: "Create vec(2,4,6) and vec(1,1,1); print their element-wise product. Then set index 2 of the first to 0.",
  },
  {
    id: "l07",
    title: "7 · Built-in math & LaTeX",
    dev: "latex · dot · norm",
    theory:
      "Sakum carries a scientific core — no import needed. Try <code>dot</code>, <code>cross</code>, " +
      "<code>norm</code>, <code>gcd</code>, <code>factorial</code>, <code>fib</code>, <code>isprime</code>. " +
      "<code>latex(expr)</code> returns a TeX string the site renders with KaTeX.",
    code:
`naam v1 = vec(1, 2, 3);
naam v2 = vec(4, 5, 6);
lek(dot(v1, v2));     # 32
lek(cross(vec(1,0,0), vec(0,1,0))); # (0,0,1)
lek(norm(v1));        # sqrt(14)
lek(gcd(48, 18));     # 6
lek(factorial(5));     # 120
lek(isprime(97));      # satya
lek(latex(v1));        # renders as a bmatrix`,
    task: "Print latex(vec(2, 4, 6)) so it renders as a matrix. Compute fib(10).",
  },
  {
    id: "l08",
    title: "8 · The self engine (puls)",
    dev: "puls · heartbeat",
    theory:
      "Sakum has a living engine: <code>puls</code> (Devanagari: पल्स, ASCII: <code>pulse</code>) emits a tick on the nerve bus. " +
      "Real programs use it to drive the learning loop and record survivability. The playground " +
      "shows the pulse count in the output header.",
    code:
`naam ticks = 0;
paryantam (naam i = 0; i < 3; i = i + 1) {
    ticks = puls(ticks + 1);   # emit a pulse, keep count
}
lek("total pulses: ");
lek(ticks);`,
    task: "Emit 5 pulses in a while loop and print the final count. It should read 5.",
  },
  {
    id: "l09",
    title: "9 · Mini project: survivability simulator",
    dev: "loops · vectors · functions · latex",
    theory:
      "Combine everything: read a vector of samples, compute mean & peak with a loop, " +
      "classify with a function, and output a LaTeX summary. This mirrors the site's own demo app.",
    code:
`naam samples = vec(60, 72, 81, 65, 90);
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

lek("mean: ");   lek(mean);
lek("peak: ");   lek(peak);
lek("dx: ");     lek(status(peak));
lek(latex(vec(mean, peak)));`,
    task: "Add a new sample (e.g. 110) to the vector and confirm the diagnosis becomes tachycardia.",
  },
];
