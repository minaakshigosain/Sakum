# health_monitor.s — SAKUM Health Monitor (stub)
.intel_syntax noprefix
.text
.global _health_monitor_init
.global _health_monitor_shutdown
.global _health_monitor_tick
_health_monitor_init:
    xor rax, rax
    ret
_health_monitor_shutdown:
    ret
_health_monitor_tick:
    ret
