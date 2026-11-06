#!/usr/bin/env python3
"""Assemble the documentation site source under build/.

The READMEs and docs/ stay the only copy of the content. This script copies
them into build/site-src/ with the repository layout intact, rewrites links
to files that aren't part of the site into GitHub links at DOCS_REF, and
writes build/mkdocs.yml (inherits ../mkdocs.yml, adds the generated nav).
Then: mkdocs build --strict -f build/mkdocs.yml
"""
import json
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
SRC = BUILD / "site-src"
REPO = "https://github.com/cmrh/terraform-scality-storage"
REF = os.environ.get("DOCS_REF") or "main"

LINK = re.compile(r"\]\(([^)\s]+)\)")


def site_pages():
    pages = [Path("README.md"), Path("CHANGELOG.md")]
    pages += sorted(p.relative_to(ROOT) for p in (ROOT / "docs").rglob("*.md"))
    for group in ("modules", "examples"):
        pages += sorted(p.relative_to(ROOT) for p in (ROOT / group).glob("*/README.md"))
    return pages


def rewrite(page, text, pages):
    def fix(m):
        target = m.group(1)
        if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
            return m.group(0)
        path, _, anchor = target.partition("#")
        anchor = f"#{anchor}" if anchor else ""
        resolved = Path(os.path.normpath(page.parent / path))
        if (ROOT / resolved).is_dir() and resolved / "README.md" in pages:
            resolved = resolved / "README.md"
        if resolved in pages:
            rel = os.path.relpath(resolved, page.parent)
            return f"]({rel}{anchor})"
        kind = "tree" if (ROOT / resolved).is_dir() else "blob"
        return f"]({REPO}/{kind}/{REF}/{resolved.as_posix()}{anchor})"

    return LINK.sub(fix, text)


PROVIDER = re.compile(r'source\s*=\s*"cmrh/(artesca|scality)"')


def providers(example):
    """The cmrh providers an example's configuration declares."""
    found = set()
    for tf in (ROOT / example.parent).glob("*.tf"):
        found |= set(PROVIDER.findall(tf.read_text()))
    return found


def nav(pages):
    docs = [p for p in pages if p.parts[0] == "docs"]
    pointers = [p.as_posix() for p in docs if p.parts[1] == "pointers"]
    guides = [p.as_posix() for p in docs if p.parts[1] != "pointers"]
    modules = [p for p in pages if p.parts[0] == "modules"]
    examples = [p for p in pages if p.parts[0] == "examples"]
    by_provider = {"Scality S3": [], "ARTESCA": [], "ARTESCA + Scality S3": []}
    for p in examples:
        found = providers(p)
        key = "ARTESCA + Scality S3" if len(found) > 1 else "ARTESCA" if found == {"artesca"} else "Scality S3"
        by_provider[key].append(p)
    return [
        {"Home": "README.md"},
        {"Modules": [
            {"Scality S3": [p.as_posix() for p in modules if p.parent.name.startswith("scality-")]},
            {"ARTESCA": [p.as_posix() for p in modules if p.parent.name.startswith("artesca-")]},
        ]},
        # Pages take their README titles: a module's is its directory name, an
        # example's "<name> example".
        {"Examples": [{k: [p.as_posix() for p in v]} for k, v in by_provider.items() if v]},
        {"Guides": guides},
        {"Pointers": pointers},
        {"Changelog": "CHANGELOG.md"},
    ]


def main():
    shutil.rmtree(SRC, ignore_errors=True)
    pages = site_pages()
    for page in pages:
        out = SRC / page
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(rewrite(page, (ROOT / page).read_text(), set(pages)))
    # YAML is a superset of JSON, so no YAML library is needed.
    config = {"INHERIT": "../mkdocs.yml", "docs_dir": "site-src",
              "site_dir": "site", "nav": nav(pages)}
    (BUILD / "mkdocs.yml").write_text(json.dumps(config, indent=2) + "\n")


if __name__ == "__main__":
    main()
