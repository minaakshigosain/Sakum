# audit_log.s — SAKUM Audit Log (stub)
.intel_syntax noprefix
.text
.global _audit_log_init
.global _audit_log_shutdown
.global _audit_log_flush
_audit_log_init:
    xor rax, rax
    ret
_audit_log_shutdown:
    ret
_audit_log_flush:
    ret
