#!/bin/bash
# Build all output formats for mod_rewrite And Friends
set -e

cd "$(dirname "$0")"

echo "=== Cleaning previous build ==="
rm -rf _build

echo "=== Building HTML ==="
uv run --with sphinx -- sphinx-build -b html -d _build/doctrees . _build/html

echo "=== Building ePub ==="
uv run --with sphinx -- sphinx-build -b epub -d _build/doctrees . _build/epub

echo "=== Building PDF (via LaTeX) ==="
uv run --with sphinx -- sphinx-build -b latex -d _build/doctrees . _build/latex
if command -v latexmk &> /dev/null; then
    make -C _build/latex all-pdf
else
    echo "  ⚠ LaTeX not installed — skipping PDF compilation."
    echo "  Install with: brew install mactex-no-gui"
    echo "  LaTeX source is still available at _build/latex/"
fi

echo ""
echo "=== Done ==="
echo "  HTML:  _build/html/index.html"
echo "  ePub:  _build/epub/"
if command -v latexmk &> /dev/null; then
    echo "  PDF:   _build/latex/mod_rewrite_and_friends.pdf"
else
    echo "  PDF:   (skipped — install LaTeX to enable)"
fi
