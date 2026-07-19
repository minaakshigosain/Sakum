#!/usr/bin/env python3
"""
ADLR Assembly Linter — catches register-safety bugs before they ship.
"""

import re
import sys
from pathlib import Path

CALLEE_SAVED = {'rbx', 'rbp', 'r12', 'r13', 'r14', 'r15'}
CALLER_SAVED = {'rax', 'rcx', 'rdx', 'rsi', 'rdi', 'r8', 'r9', 'r10', 'r11'}

def find_functions(text):
    """Extract function boundaries."""
    funcs = {}
    lines = text.split('\n')
    current = None
    for i, line in enumerate(lines):
        m = re.match(r'^CDECL\((\w+)\):', line)
        if m:
            if current:
                funcs[current]['end'] = i
            current = m.group(1)
            funcs[current] = {'start': i, 'end': len(lines), 'lines': []}
        if current:
            funcs[current]['lines'].append((i, line))
    if current:
        funcs[current]['end'] = len(lines)
    return funcs

def check_function(func_name, lines):
    """Check a single function for register-safety issues."""
    issues = []
    saved_regs = set()
    loop_counters = {}  # reg -> line_num where initialized
    in_loop = False
    call_in_loop = False
    
    for i, (lineno, line) in enumerate(lines):
        stripped = line.strip()
        
        if not stripped or stripped.startswith('#'):
            continue
        
        # Track push/pop of callee-saved regs
        for reg in CALLEE_SAVED:
            if re.search(rf'\bpush\s+{reg}\b', stripped):
                saved_regs.add(reg)
            if re.search(rf'\bpop\s+{reg}\b', stripped):
                saved_regs.discard(reg)
        
        # Detect loop counter initialization
        for reg in CALLER_SAVED | CALLEE_SAVED:
            if re.match(rf'(xor|mov)\s+{reg}\s*,\s*(0|{reg})', stripped):
                loop_counters[reg] = lineno
                in_loop = True
                call_in_loop = False
        
        # Detect loop increment (suggests we're in a loop)
        inc_match = re.search(r'(inc|dec)\s+(\w+)', stripped)
        if inc_match and in_loop:
            reg = inc_match.group(2).lower()
            if reg in loop_counters:
                call_in_loop = True
        
        # Detect call instructions
        call_match = re.search(r'\bcall\s+(CDECL\()?(\w+)\)?', stripped)
        if call_match and not stripped.endswith('ret'):
            called = call_match.group(2)
            if in_loop and call_in_loop:
                # There's a call inside the loop - check loop counters
                for reg, init_line in list(loop_counters.items()):
                    if reg in CALLER_SAVED and reg not in saved_regs:
                        issues.append({
                            'func': func_name,
                            'line': lineno + 1,
                            'issue': f"Loop counter {reg} in caller-saved register used across call to {called} (not saved)",
                            'severity': 'ERROR'
                        })
            # After a call, caller-saved regs are clobbered
            for reg in list(loop_counters):
                if reg in CALLER_SAVED:
                    del loop_counters[reg]
    
    # Check for functions using r15 as loop counter without saving it
    for func in ['adlr_resolve', 'adlr_dependency_resolve', 'adlr_unload_unused', 
                 'adlr_task_mask', 'adlr_kg_lookup']:
        if func_name == func:
            uses_r15 = any(re.search(r'(xor|mov)\s+r15', l) for _, l in lines)
            saves_r15 = any('push r15' in l for _, l in lines)
            if uses_r15 and not saves_r15:
                issues.append({
                    'func': func_name,
                    'line': lines[0][0] + 1,
                    'issue': f"Uses r15 as loop counter but doesn't save/restore it (missing push r15 / pop r15)",
                    'severity': 'ERROR'
                })
    
    return issues

def check_budget(file_text):
    """Check RAM budget is sufficient for max modules."""
    sizes = {}
    for line in file_text.split('\n'):
        m = re.search(r'#\s*(\d+):\s*(\w+).*\.quad\s+\((\d+)', line)
        if m:
            idx, name, mem = m.groups()
            sizes[name] = int(mem)
    
    total = sum(sizes.values())
    
    budget_match = re.search(r'shr\s+rax,\s*(\d+)', file_text)
    if budget_match:
        shift = int(budget_match.group(1))
        budget_mb = (1 << 30) >> shift >> 20
        if total > budget_mb:
            return [{
                'issue': f"RAM budget ({budget_mb} MiB) < max possible load ({total} MiB)",
                'severity': 'WARNING'
            }]
    return []

def main():
    adlr_path = Path(__file__).parent / 'sakum_adlr.s'
    text = adlr_path.read_text()
    
    funcs = find_functions(text)
    all_issues = []
    
    for name, data in funcs.items():
        issues = check_function(name, data['lines'])
        all_issues.extend(issues)
    
    all_issues.extend(check_budget(text))
    
    if all_issues:
        print(f"Found {len(all_issues)} issue(s):")
        for iss in all_issues:
            print(f"  [{iss['severity']}] {iss.get('func','global')}:{iss.get('line','?')} - {iss['issue']}")
        return 1
    else:
        print("OK: No register-safety issues found")
        return 0

if __name__ == '__main__':
    sys.exit(main())