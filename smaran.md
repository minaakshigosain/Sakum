# Always check these files this for recall what you have learnt , leanring learn.md, which is stored in memory of your in memory.md 

# Always Learn from Question self evalution use Self AI "Sakum AI" to fix itself.  



# Always do a Production grade project with end to end test after any update or upgrade or edit to the code. 

# Before writing ANY code, recall the designed functionality and verify against it.
# The design is documented and MUST be honored:
#   - docs/LATEX_SYNTAX.md   : closed set of LaTeX syntax allowed in Sakum specs + math->Sakum map
#   - docs/SYMBOL_MAP.md     : LaTeX math symbols (∂ ∇ ∑ ∫ ⟨⟩ → × ·) -> Sakum keywords (नाम/लेख/वेक्टर/हृदय/वर्ग/ब्रम्ह/सूत्र/चर/यदि/वापस/परीक्षा/मुद्रण)
#   - spec/*.sakum           : 18 binary-hash-addressable knowledge nodes (नाम hash = #what <hex64>)
#   - docs/asm/spec_*.s      : 7 ISA targets embedding the 23984-byte spec corpus; FNV1a(spec)=0xC46A785B
#   - assembly/sakum_ai.s    : AI core (85 chunks, 64 neurons, ingestion, self-update ledger, out[0]=132256)
# Survivability gate (keep everything alive on every edit):
#   heartbeat + ingestion imprint + self-update ledger + self-extension loop
# Verify after any edit: mac build prints FNV1a(spec)=0xC46A785B AND bash tools/check.sh => PASS=7 (0 leaks).
# No host-language interpreters (SAKUM_LANG.md §2): output is raw assembly, gcc -arch x86_64 where testable. 