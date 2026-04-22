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

echo "=== Fixing ePub footnotes for Kindle ==="
python3 fix_epub_footnotes.py

echo "=== Converting ePub to Kindle (azw3) ==="
echo "  NOTE: Amazon's Send to Kindle service accepts ePub directly."
echo "  The azw3 conversion is for sideloading via USB only."
echo "  To send to Kindle via email, use the .epub file."
EPUB_FILE=$(find _build/epub -name '*.epub' -maxdepth 1 | head -1)
if [ -n "$EPUB_FILE" ] && command -v ebook-convert &> /dev/null; then
    # Convert to both azw3 (USB sideload) and kepub (Kobo)
    ebook-convert "$EPUB_FILE" _build/mod_rewrite_and_friends.azw3
elif [ -n "$EPUB_FILE" ]; then
    echo "  ⚠ Calibre not installed — skipping Kindle conversion."
    echo "  Install with: brew install calibre"
    echo "  ePub is still available for non-Kindle readers."
fi

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
echo "  ePub:  $EPUB_FILE"
if command -v latexmk &> /dev/null; then
    echo "  PDF:   _build/latex/mod_rewrite_and_friends.pdf"
else
    echo "  PDF:   (skipped — install LaTeX to enable)"
fi
if command -v ebook-convert &> /dev/null; then
    echo "  Kindle: _build/mod_rewrite_and_friends.azw3"
else
    echo "  Kindle: (skipped — install Calibre to enable)"
fi
echo ""
echo "  TIP: To send to Kindle, email the .epub file to your @kindle.com address."
