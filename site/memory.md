# memory.md — Sakum self-updater memory ledger

Written and read by `tools/sakum_bot.sh`. Plain text, append-only style.
Each line is a record. `survive:` is the rolling success counter.

survive: 34
last_cycle: 1784201634
patches_applied: 34
last_check: 2026-07-16T11:35:12Z

## learned
(empty — filled by the bot on each successful cycle)

## mistakes
(empty — filled when a recompile fails or a source fetch errors)

## notes
- Bot reads learn.md + this file every pulse.
- Patches written to self/patches/ as patch_<ts>.json.
- Recompile target: assembly/sakum_*.s via gcc -arch x86_64.
learned 1784181583: signal=bounds patch=auto_bounds_1784181583
learned 1784181641: signal=bounds patch=auto_bounds_1784181641
learned 1784181736: signal=bounds patch=auto_bounds_1784181736
learned 1784181741: signal=bounds patch=auto_bounds_1784181741
learned 1784181917: signal=bounds patch=auto_bounds_1784181917
learned 1784181917: signal=bounds patch=auto_bounds_1784181917
learned 1784183231: signal=bounds patch=auto_bounds_1784183231
learned 1784183401: signal=bounds patch=auto_bounds_1784183401
learned 1784183582: signal=bounds patch=auto_bounds_1784183582
learned 1784185580: topic=vector files=
mistake 1784185671: recompile failed: Undefined symbols for architecture x86_64:
  "_main", referenced from:
      <initial-undefines>
ld: symbol(s) not found for architecture x86_64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
learned 1784185692: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784185831: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784185965: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186394: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186425: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186780: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186784: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186873: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784186903: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784187035: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum
learned 1784187102: topic=rvv files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_rvv.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_rvv.sakum
learned 1784187150: topic=simd files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_simd.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_simd.sakum
learned 1784187328: topic=quantum files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_quantum.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_quantum.sakum
learned 1784187779: topic=crypto files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_crypto.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_crypto.sakum
learned 1784188457: topic=bounds files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum
learned 1784189383: topic=overflow files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum
learned 1784189951: topic=memory.safe files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_memory.safe.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_memory.safe.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sir/sir_lib_memory.safe.sir
learned 1784190066: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sir/sir_lib_bounds.sir /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sir/sir_lib_numeric.sir /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sir/sir_lib_overflow.sir /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sir/sir_lib_vector.sir
learned 1784190748: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
mistake 1784191430: recompile failed: assembly/sakum_pipe.s:850:14: error: token is not a valid binary operator in a preprocessor subexpression
  850 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:850:7: error: unterminated conditional directive
  850 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784192036: recompile failed: assembly/sakum_pipe.s:866:14: error: token is not a valid binary operator in a preprocessor subexpression
  866 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:866:7: error: unterminated conditional directive
  866 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784192672: recompile failed: assembly/sakum_pipe.s:859:14: error: token is not a valid binary operator in a preprocessor subexpression
  859 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:859:7: error: unterminated conditional directive
  859 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784193278: recompile failed: assembly/sakum_pipe.s:865:14: error: token is not a valid binary operator in a preprocessor subexpression
  865 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:865:7: error: unterminated conditional directive
  865 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784193885: recompile failed: assembly/sakum_pipe.s:815:14: error: token is not a valid binary operator in a preprocessor subexpression
  815 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:815:7: error: unterminated conditional directive
  815 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784194490: recompile failed: assembly/sakum_pipe.s:857:14: error: token is not a valid binary operator in a preprocessor subexpression
  857 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:857:7: error: unterminated conditional directive
  857 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784195095: recompile failed: assembly/sakum_pipe.s:857:14: error: token is not a valid binary operator in a preprocessor subexpression
  857 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:857:7: error: unterminated conditional directive
  857 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784195700: recompile failed: assembly/sakum_pipe.s:857:14: error: token is not a valid binary operator in a preprocessor subexpression
  857 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:857:7: error: unterminated conditional directive
  857 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
mistake 1784196306: recompile failed: assembly/sakum_pipe.s:857:14: error: token is not a valid binary operator in a preprocessor subexpression
  857 |     # if '#' -> skip to newline
      |          ~~~ ^
assembly/sakum_pipe.s:857:7: error: unterminated conditional directive
  857 |     # if '#' -> skip to newline
      |       ^
2 errors generated.
learned 1784197316: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
learned 1784199588: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
learned 1784200270: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
learned 1784200952: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
learned 1784201634: topic=vector files= /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_bounds.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_bounds.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_numeric.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_numeric.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_overflow.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_overflow.sakum /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly/sakum_lib_vector.s /Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/examples/lib_vector.sakum 
