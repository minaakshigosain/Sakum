#!/usr/bin/env python3
# tools/sakum_ext.py - Sakum Lang canonical file-type registrar.
#
# SINGLE SOURCE OF TRUTH for the extension scheme. Every other tool, editor
# integration, and CI step should consult this module instead of hard-coding
# extensions. The mapping is loaded from `sakum_lang.sakproj` (the project
# config) so docs, tooling, and the build stay in lock-step.
#
# Subcommands:
#   list                 print every registered extension + its category
#   classify <path>...   print ext, category, kind for each path
#   kind <ext>           print the category for one extension
#   dispatch <path>      route a file to its handler (view/validate/build/test)
#   check [root]         scan a tree; report any file whose ext is unknown
#
# No third-party deps. Pure stdlib. Doctrine-compliant (portable, no magic).

import json
import os
import sys

# Fallback registry, used only if the .sakproj cannot be read. Keeps the tool
# functional even when invoked from a bare checkout.
_FALLBACK = {
    ".sak":      ("source",  "Sakum source code"),
    ".sakm":     ("source",  "Sakum module / package source"),
    ".sakh":     ("source",  "Header / interface declarations"),
    ".sakpkg":   ("package", "Package manifest"),
    ".sakproj":  ("package", "Project configuration"),
    ".saklock":  ("package", "Dependency lock file"),
    ".sakir":    ("ir",      "Intermediate Representation (SIR)"),
    ".sakast":   ("ast",     "Abstract Syntax Tree"),
    ".sakbc":    ("binary",  "Bytecode"),
    ".sakobj":   ("binary",  "Object file"),
    ".saklib":   ("binary",  "Static library"),
    ".sakdll":   ("binary",  "Dynamic library (Windows)"),
    ".sakso":    ("binary",  "Dynamic library (Linux)"),
    ".sakdylib": ("binary",  "Dynamic library (macOS)"),
    ".sakexe":   ("binary",  "Platform-independent executable bundle"),
    ".sakdoc":   ("doc",     "Language documentation"),
    ".sakapi":   ("doc",     "API documentation"),
    ".saktest":  ("test",    "Unit tests"),
    ".sakbench": ("test",    "Benchmarks"),
    ".sakmath":  ("domain",  "Mathematical formulas / symbolic expressions"),
    ".sakphys":  ("domain",  "Physics formulas"),
    ".sakchem":  ("domain",  "Chemistry equations"),
    ".sakbio":   ("domain",  "Biology / biotechnology models"),
    ".sakquant": ("domain",  "Quantum algorithms and circuits"),
    ".sakml":    ("domain",  "Machine learning models / graphs"),
    ".saktensor":("domain",  "Tensor expressions"),
    ".sakproof": ("domain",  "Formal proofs"),
    ".sakgraph": ("domain",  "Graph / network definitions"),
    ".sakquery": ("script",  "Query language scripts"),
    ".sakschema":("data",    "Data schemas"),
    ".sakcfg":   ("config",  "Configuration"),
    ".sakcache": ("cache",   "Compiler cache"),
    ".sakidx":   ("index",   "Search / index database"),
    ".sakdb":    ("data",    "Embedded database"),
    ".saklog":   ("log",     "Logs"),
}

# Extensions that are NOT part of the Sakum scheme but are expected in this
# repo (docs, assembly, C drivers, site assets, build artifacts). The checker
# treats these as benign so it only flags genuinely unknown Sakum artifacts.
_FOREIGN_OK = {
    # docs / prose
    ".md", ".tex", ".pdf", ".html", ".txt", ".rst",
    # assembly / C / build
    ".s", ".c", ".h", ".inc", ".o", ".sh", ".plist", ".applescript",
    ".json", ".jsonl", ".js", ".rsrc", ".icns", ".car", ".py", ".pyc",
    # app / misc
    ".DS_Store", ".log", ".gitignore", ".pdf", ".pkg", ".app",
    ".scpt", ".rsrc", ".icns", ".car", ".plist", ".pkginfo",
    ".codesig", "",  # dotfiles like .gitignore are handled by basename below
}

# How each category should be handled by the dispatcher. This is what makes
# tooling *honor* the scheme: behaviour is bound to category, not to a name.
_DISPATCH = {
    "source":  "build",    # compile through the pipeline
    "ir":      "build",    # lower / verify
    "ast":     "build",
    "binary":  "link",     # feed to linker / loader
    "package": "manifest", # resolve deps / validate
    "doc":     "view",     # render to human-readable
    "test":    "test",     # run test harness
    "domain":  "view",     # domain-aware render (LaTeX / sim / etc.)
    "script":  "run",      # execute query
    "data":    "validate", # schema-check
    "config":  "validate",
    "cache":   "ignore",   # derived; safe to drop
    "index":   "ignore",   # derived; safe to drop
    "log":     "view",
}


def _load_registry(proj_path=None):
    """Load the extension map from sakum_lang.sakproj if present."""
    reg = dict(_FALLBACK)
    if proj_path is None:
        here = os.path.dirname(os.path.abspath(__file__))
        proj_path = os.path.join(os.path.dirname(here), "sakum_lang.sakproj")
    try:
        with open(proj_path, "r", encoding="utf-8") as fh:
            proj = json.load(fh)
    except (OSError, ValueError):
        return reg, proj_path, False

    dom = proj.get("domain_ext", {})
    source_ext = proj.get("source_ext", [])
    for e in source_ext:
        reg.setdefault(e, ("source", "Sakum source code"))
    for name, e in dom.items():
        reg.setdefault(e, ("domain", name.capitalize() + " domain knowledge"))
    for e in (proj.get("ir_ext"), proj.get("ast_ext"), proj.get("bytecode_ext")):
        if e:
            reg.setdefault(e, ("ir", "Compiler artifact"))
    for e in proj.get("doc_ext", []):
        reg.setdefault(e, ("doc", "Documentation"))
    return reg, proj_path, True


def classify(path, registry=None):
    if registry is None:
        registry, _, _ = _load_registry()
    base = os.path.basename(path)
    # Dotfiles / files without a Sakum extension but on the foreign-OK list
    # are reported as "foreign" (benign), not "unknown".
    if base.startswith(".") or base == "":
        return "", "foreign", "ignore", "repo / dotfile (non-Sakum)"
    # Longest matching extension wins (e.g. .sakdylib before .sak).
    exts = sorted(registry.keys(), key=len, reverse=True)
    for e in exts:
        if base.endswith(e):
            cat, desc = registry[e]
            return e, cat, _DISPATCH.get(cat, "view"), desc
    # Fall back to a simple extension probe for foreign formats.
    dot = base.rfind(".")
    fext = base[dot:] if dot > 0 else ""
    if fext in _FOREIGN_OK:
        return fext, "foreign", "ignore", "external format (non-Sakum)"
    return "", "unknown", "ignore", "unregistered extension"


def cmd_list(registry):
    for e in sorted(registry.keys()):
        cat, desc = registry[e]
        print(f"{e:12} {cat:9} {_DISPATCH.get(cat,'view'):9} {desc}")


def cmd_classify(paths, registry):
    for p in paths:
        ext, cat, action, desc = classify(p, registry)
        print(f"{p}\n    ext={ext or '-'}  category={cat}  action={action}  ({desc})")


def cmd_kind(ext, registry):
    if not ext.startswith("."):
        ext = "." + ext
    if ext in registry:
        cat, desc = registry[ext]
        print(f"{ext} -> {cat} / {_DISPATCH.get(cat,'view')}  ({desc})")
    else:
        print(f"{ext} -> UNKNOWN")
        sys.exit(1)


def cmd_dispatch(path, registry):
    ext, cat, action, desc = classify(path, registry)
    if cat == "unknown":
        print(f"dispatch: {path} -> SKIP (unknown extension)")
        return
    print(f"dispatch: {path}")
    print(f"  category = {cat}")
    print(f"  handler  = {action}")
    print(f"  purpose  = {desc}")


def cmd_check(root, registry):
    root = root or "."
    problems = 0
    known = 0
    foreign = 0
    for dirpath, _, files in os.walk(root):
        if ".git" in dirpath.split(os.sep):
            continue
        for f in files:
            p = os.path.join(dirpath, f)
            ext, cat, _, _ = classify(p, registry)
            if cat == "unknown":
                problems += 1
                print(f"UNKNOWN  {p}")
            elif cat == "foreign":
                foreign += 1
            else:
                known += 1
    print(f"\ncheck: {known} sakum-scheme, {foreign} foreign/expected, "
          f"{problems} UNKNOWN")
    if problems:
        sys.exit(1)


def main(argv):
    registry, proj, loaded = _load_registry()
    if not argv:
        print("usage: sakum_ext.py list|classify|kind|dispatch|check [args]")
        sys.exit(2)
    cmd = argv[0]
    if cmd == "list":
        if loaded:
            print(f"# registry loaded from {proj}\n")
        cmd_list(registry)
    elif cmd == "classify":
        if len(argv) < 2:
            print("classify needs at least one path"); sys.exit(2)
        cmd_classify(argv[1:], registry)
    elif cmd == "kind":
        if len(argv) < 2:
            print("kind needs an extension"); sys.exit(2)
        cmd_kind(argv[1], registry)
    elif cmd == "dispatch":
        if len(argv) < 2:
            print("dispatch needs a path"); sys.exit(2)
        cmd_dispatch(argv[1], registry)
    elif cmd == "check":
        cmd_check(argv[1] if len(argv) > 1 else ".", registry)
    else:
        print(f"unknown subcommand: {cmd}")
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
