# SAKUM_HINGLISH.md — Canonical Hinglish Keyword Glossary (single source)

> Per user doctrine (2026-07-18): Sakum Lang keywords are **Hinglish (romanized)
> Sanskrit) only** — typeable ASCII, no Devanagari required, no pure-English
> keywords. This file is the ONE place the keyword spelling is defined. Every
> other doc, the assembly registry (`assembly/sakum_keywords.s`), and the
> compiler lexer must agree with this table.

## 1. Core language keywords

| Hinglish keyword | Meaning            | Replaces (old)        |
|------------------|--------------------|-----------------------|
| aarambh          | program / main     | आरम्भ                 |
| naam             | declare variable   | नाम / चर              |
| kriya            | function           | क्रिया / सूत्र        |
| yadi             | if / conditional   | यदि                   |
| anyatha          | else               | अन्यथा                |
| yavat            | loop (while)       | यावत् / जबतक         |
| paryantam        | counted loop (for) | पर्यन्तम्             |
| vapsa            | return             | प्रत्यागम / वापस      |
| satya            | true               | सत्य                  |
| asatya           | false              | असत्य                 |
| shunya           | nil / none         | शून्य                 |
| lek              | output / print     | लेख / मुद्रण          |
| hriday           | engine allocator   | हृदय                  |
| spand            | engine tick        | स्पन्द                 |
| naadi            | signal bus         | नाडी                  |
| sutra            | creator key / thread | सूत्र / सूत्र        |
| varg             | class              | वर्ग                   |
| vyakhya          | explain error      | व्याख्या              |
| svadhyaya        | self-learn         | स्वाध्याय             |
| santripti        | saturating arith   | संतृप्तिः             |
| vektor           | SIMD vector        | वेक्टर                |
| ank              | integer elem type  | अङ्क                  |
| paripath         | quantum circuit    | परिपथ                |
| dvar             | quantum gate       | द्वार                 |
| map              | measure            | माप                   |
| brahma           | web crawler        | ब्रम्ह                |
| pariksha         | self-test block    | परीक्षा              |
| aur              | logical and        | और                   |
| athava           | logical or         | अथवा                 |
| lambai           | length             | लंबाई                 |
| sanchay          | database engine    | सञ्चय                 |
| kech             | key/value store    | केच                   |
| anukra           | vectorless index   | अनुक्र               |
| grantha          | graph store        | ग्रन्थ                |
| tantra           | systems engineering| तन्त्र               |
| anvesh           | search / lookup    | अन्वेष               |
| sarani           | hash table         | सारणी               |
| chakra           | ring buffer        | चक्र                 |
| pravah           | pipe operator |>   | प्रवाह (pipeline)    |

## 2. Domain keyword registry (148 reserved, Hinglish spellings)

The 148 domain keywords keep their romanized (Hinglish) spellings already used
in `assembly/sakum_keywords.s` (e.g. `vastu`, `sutra`, `hriday`, `prajna`).
They are reserved on every target. Category ids (0..12) are unchanged:

```
0 TYPES  1 FUNC  2 CONC  3 MEM   4 FS    5 NET   6 AI
7 ROBOT  8 QUANT 9 COMPILER 10 SEC 11 DIST 12 LIVING
```

The full 148-row table lives in `assembly/sakum_keywords.s` (machine-level
registry) and is mirrored in `spec/spec_keywords.sak`.

## 3. New machine-level DB shapes (requirement 2 & 3)

The `sanchay` engine implements FIVE primitive data shapes, all at machine
level in `assembly/sakum_db.s`:

| Hinglish  | Shape            | Notes                                  |
|-----------|------------------|----------------------------------------|
| kech      | key/value        | sutra-encrypted at rest                |
| vektor    | vector (ANN)     | SIMD L2 distance, stateful index       |
| anukra    | vectorless       | B-tree / inverted classical index      |
| sthit     | stateful store   | mutable, persisted, addressable by hash|
| asthit    | stateless store  | pure key->value, no persistence        |
| grantha   | graph            | typed edges + naadi-driven traversal   |

> Note: `sthit` (stateful) and `asthit` (stateless) are NEW shapes added to the
> sanchay engine per the user's requirement. They join the original kech /
> vektor / anukra / grantha four.
