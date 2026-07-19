# scheduler.s — SAKUM Scheduler (stub)
.intel_syntax noprefix
.text
.global _scheduler_init
.global _scheduler_shutdown
.global _scheduler_tick
.global _scheduler_dispatch
_scheduler_init:
    xor rax, rax
    ret
_scheduler_shutdown:
    ret
_scheduler_tick:
    xor rax, rax
    ret
_scheduler_dispatch:
    xor rax, rax
    ret
