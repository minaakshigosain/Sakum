/* hinglish.js — live Hinglish (Romanized Hindi) -> Devanagari converter.
 *
 * Model (per your description): you TYPE in Hinglish with a QWERTY keyboard;
 * when you press SPACE the current word is transliterated to Devanagari.
 * A suggestion bar above the editor shows candidate conversions; click one to
 * accept it. The converted Devanagari is what the Sakum interpreter receives
 * (it accepts Devanagari, Hinglish, or ASCII keywords alike).
 *
 * This is a compact rule-based transliterator (not a full ISO-15919 engine),
 * good enough for typing Sakum programs in Hinglish.
 */
(function (global) {
  "use strict";

  // Hinglish (Romanized) keyword tokens -> canonical token.
  // The converter converts these; arbitrary identifiers are left as-is.
  const KW = {
    naam: "let", kriya: "fn", yadi: "if", anyatha: "else",
    yavat: "while", paryantam: "for", pratyagam: "return",
    satya: "true", asatya: "false", shunya: "null",
    lek: "print", vektr: "vektor", puls: "pulse",
    hriday: "heart", spand: "pulse_engine", nadi: "nerve",
    paripath: "circuit", sutra: "sutra",
  };

  // vowel signs (matras) keyed by the Roman vowel that follows a consonant
  const MATRA = {
    a: "",   // inherent 'a' — no sign
    aa: "ा", a2: "ा",
    i: "ि", ii: "ी",
    u: "ु", uu: "ू",
    e: "े", ai: "ै",
    o: "ो", au: "ौ",
    ri: "ृ",
  };

  // independent vowels
  const VOWEL = {
    a: "अ", aa: "आ", a2: "आ",
    i: "इ", ii: "ई",
    u: "उ", uu: "ऊ",
    e: "ए", ai: "ऐ",
    o: "ओ", au: "औ",
    ri: "ऋ",
  };

  // consonants + their Devanagari base (without inherent 'a').
  // Common Hinglish mapping: single letters -> the dental/non-cerebral,
  // non-aspirated form by default (what a typist writes). Cerebral /
  // aspirated / nasal forms are explicit clusters (tt, kh, ng, ...).
  const CONS = {
    k: "क", kh: "ख", g: "ग", gh: "घ", ng: "ङ",
    c: "च", ch: "छ", j: "ज", jh: "झ", ny: "ञ",
    t: "त", th: "थ", d: "द", dh: "ध", n: "न",
    tt: "ट", tth: "ठ", dd: "ड", ddh: "ढ", nn: "ण",
    p: "प", ph: "फ", b: "ब", bh: "भ", m: "म",
    y: "य", r: "र", l: "ल", v: "व", w: "व",
    sh: "श", ss: "ष", s: "स", h: "ह",
    ksh: "क्ष", tr: "त्र", jny: "ज्ञ",
    khya: "क्ष", gya: "ज्ञ",
    // anusvara / visarga (halant is auto-inserted between consonant clusters)
    n2: "ं", n3: "ः",
    // digits
    "0": "०", "1": "१", "2": "२", "3": "३", "4": "४",
    "5": "५", "6": "६", "7": "७", "8": "८", "9": "९",
  };

  // halant to remove the inherent 'a' before a following consonant
  const HALANT = "्";
  const NUKTA = "़";

  // multi-char consonant tokens, longest first
  const CONS_KEYS = Object.keys(CONS).filter((k) => isNaN(k)).sort((a, b) => b.length - a.length);
  const VOWEL_KEYS = Object.keys(VOWEL).sort((a, b) => b.length - a.length);
  const MATRA_KEYS = Object.keys(MATRA).sort((a, b) => b.length - a.length);

  // special full-word overrides (common Hinglish spellings)
  // word overrides map Hinglish -> the EXACT Devanagari that the
  // interpreter (sakum.js) recognizes, so conversion round-trips cleanly.
  const WORD_OVERRIDE = {
    sakam: "सकम्", sakum: "सकम्", namaste: "नमस्ते",
    hindi: "हिन्दी", devanagari: "देवनागरी",
    naam: "नाम", kriya: "क्रिया", yadi: "यदि", anyatha: "अन्यथा",
    yavat: "यावत्", paryantam: "पर्यन्तम्", pratyagam: "प्रत्यागम",
    satya: "सत्य", asatya: "असत्य", shunya: "शून्य",
    lek: "लेख", vektr: "वेक्टर", puls: "पल्स",
    hriday: "हृदय", spand: "स्पन्द", nadi: "नाडी",
    paripath: "परिपथ", sutra: "सूत्र",
  };

  function isVowelKey(k) { return k in VOWEL; }
  function isConsKey(k) { return k in CONS; }

  // transliterate a single Hinglish word -> Devanagari.
  // Only Sakum keywords / known Hinglish tokens are converted; arbitrary
  // code identifiers (x, i, samples, mean, ...) pass through unchanged.
  const KNOWN = new Set(
    Object.keys(KW).filter((k) => /^[a-z]/i.test(k))
      .concat(Object.keys(WORD_OVERRIDE))
  );
  function convertWord(word) {
    if (!word) return "";
    if (!KNOWN.has(word.toLowerCase())) return word;  // leave identifiers alone

    if (WORD_OVERRIDE[word.toLowerCase()]) return WORD_OVERRIDE[word.toLowerCase()];
    // keep punctuation / digits-as-numbers intact-ish
    const lower = word.toLowerCase();
    let out = "";
    let i = 0;
    let lastWasCons = false;

      while (i < lower.length) {
        // try consonant (longest match)
        let matched = false;
        for (const k of CONS_KEYS) {
          if (lower.substr(i, k.length) === k) {
            if (k === "n2") { out += "ं"; i += 2; matched = true; break; }
            if (k === "n3") { out += "ः"; i += 2; matched = true; break; }
            // consonant cluster: cancel previous inherent 'a' with halant
            if (lastWasCons) out += HALANT;
            out += CONS[k];
            i += k.length;
            lastWasCons = true;
            matched = true;
            break;
          }
        }
        if (matched) continue;

      // try vowel (longest match)
      let vmatched = false;
      for (const k of VOWEL_KEYS) {
        if (lower.substr(i, k.length) === k) {
          if (i === 0 || !lastWasCons) {
            out += VOWEL[k];
          } else if (k === "a") {
            // trailing/embedded 'a' after a consonant -> matra AA (ा)
            out += "ा";
          } else {
            out += MATRA[k] || "";
          }
          i += k.length;
          lastWasCons = false;
          vmatched = true;
          break;
        }
      }
      if (vmatched) continue;

      // fallback: copy char (spaces, punctuation, unknown)
      out += word[i];
      lastWasCons = false;
      i += 1;
    }
    return out;
  }

  // produce up to N candidate suggestions by trying alt vowel splits (lightweight)
  function suggest(word, n) {
    n = n || 5;
    const base = convertWord(word);
    const cands = [base];
    // simple alternates: toggle trailing 'a' matra on/off already covered;
    // add a couple of common double-vowel readings
    if (word && /[aeiou]$/i.test(word)) {
      // if ends in consonant+vowel, also show without final matra
      // (handled by 'a' being empty) — provide a "no final matra" variant
    }
    // dedupe
    return Array.from(new Set(cands)).slice(0, n);
  }

  global.Hinglish = { convertWord, suggest, convert: convertWord };
  if (typeof module !== "undefined" && module.exports) module.exports = global.Hinglish;
})(typeof window !== "undefined" ? window : (typeof globalThis !== "undefined" ? globalThis : this));
