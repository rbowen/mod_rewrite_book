# mod_rewrite And Friends

A guide to Apache `mod_rewrite` and related URL mapping modules, by [Rich Bowen](https://github.com/rbowen).

This book covers `mod_rewrite` in depth — regular expressions, `RewriteRule`, `RewriteCond`, `RewriteMap`, flags, logging, proxying, virtual hosts, access control, and more — along with the many other Apache httpd modules that can often do the job better.

## Status

This is a **work in progress** (v3.0). See the appendix for revision history and the TODO list.

## Building

The book is written in [reStructuredText](https://docutils.sourceforge.io/rst.html) and built with [Sphinx](https://www.sphinx-doc.org/). No global install required — use [uv](https://docs.astral.sh/uv/) to run in an ephemeral environment:

### Prerequisites

- **Python 3.8+** (any recent version)
- **[uv](https://docs.astral.sh/uv/)** (recommended) — or `pip install sphinx` if you prefer a global install
- **LaTeX distribution** (for PDF only) — e.g. `brew install mactex-no-gui` on macOS, or `apt install texlive-full` on Debian/Ubuntu

### HTML

```bash
uv run --with sphinx -- sphinx-build -b html . _build/html
```

Open `_build/html/index.html` in your browser to view.

### ePub

```bash
uv run --with sphinx -- sphinx-build -b epub . _build/epub
```

The ePub file will be at `_build/epub/mod_rewrite And Friends.epub`.

### PDF (via LaTeX)

```bash
uv run --with sphinx -- sphinx-build -b latex . _build/latex
cd _build/latex && make
```

The PDF will be at `_build/latex/mod_rewrite_and_friends.pdf`.

### Using Make

If you have Sphinx installed globally (or in a virtualenv), you can use the Makefile shortcuts:

```bash
make html
make epub
make latexpdf
make linkcheck   # verify external links
make clean       # remove all build output
```

### All formats at once

```bash
uv run --with sphinx -- sphinx-build -b html . _build/html && \
uv run --with sphinx -- sphinx-build -b epub . _build/epub && \
uv run --with sphinx -- sphinx-build -b latex . _build/latex && \
cd _build/latex && make
```

## Structure

```
├── conf.py                 — Sphinx configuration
├── index.rst               — Master table of contents
├── Makefile                — Build targets
├── cover.jpg
├── images/                 — Figures and screenshots
└── chapters/
    ├── 00_preface.rst
    ├── 01_regex.rst        — Regular Expressions
    ├── 02_url_mapping.rst  — URL Mapping
    ├── 03_mod_rewrite.rst  — Introduction to mod_rewrite
    ├── 04_rewriterule.rst  — RewriteRule
    ├── 05_rewrite_logging.rst — Rewrite Logging
    ├── 06_rewrite_flags.rst   — RewriteRule Flags
    ├── 07_rewritecond.rst  — RewriteCond
    ├── 08_rewritemap.rst   — RewriteMap
    ├── 09_proxy.rst        — Proxying with mod_rewrite
    ├── 10_vhosts.rst       — Virtual Hosts
    ├── 11_access.rst       — Access Control
    ├── 12_configurable_configuration.rst — Conditional Configuration
    ├── 13_content_munging.rst — Content Munging Modules
    ├── 14_recipes.rst      — Recipes
    ├── appendix.rst        — Revision History / TODO
    └── glossary.rst
```

## Format History

This book has been through a few format migrations:

- **2013** — Started in LaTeX
- **2013** — Converted to reStructuredText / Sphinx
- **2017** — Converted to AsciiDoc
- **2018** — Brief detour through Markdown / GitBook
- **2018** — Back to AsciiDoc
- **2026** — Back to reStructuredText / Sphinx (full circle)

## License

Copyright © 2013–2025 Rich Bowen. All rights reserved.
