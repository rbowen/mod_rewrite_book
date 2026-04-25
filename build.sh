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
echo "  --- Standard (letter-size) PDF ---"
uv run --with sphinx -- sphinx-build -b latex -d _build/doctrees . _build/latex
if command -v latexmk &> /dev/null; then
    make -C _build/latex all-pdf
else
    echo "  ⚠ LaTeX not installed — skipping PDF compilation."
    echo "  Install with: brew install mactex-no-gui"
fi

echo "  --- KDP print-ready (6×9) PDF ---"
KDP_PRINT=1 uv run --with sphinx -- sphinx-build -b latex -d _build/doctrees_kdp . _build/latex_kdp
if command -v latexmk &> /dev/null; then
    make -C _build/latex_kdp all-pdf
    KDP_PDF="_build/latex_kdp/mod_rewrite_and_friends.pdf"
    PAGES=$(pdfinfo "$KDP_PDF" 2>/dev/null | awk '/^Pages:/ {print $2}')
    if [ -n "$PAGES" ]; then
        SPINE=$(echo "$PAGES * 0.002252" | bc)
        echo "  KDP page count: $PAGES → spine width: ${SPINE}in"
    fi
else
    echo "  ⚠ LaTeX not installed — skipping KDP PDF compilation."
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
if [ -f "_build/latex_kdp/mod_rewrite_and_friends.pdf" ]; then
    echo "  KDP PDF: _build/latex_kdp/mod_rewrite_and_friends.pdf"
    [ -n "$PAGES" ] && echo "           $PAGES pages, spine width: ${SPINE}in"
else
    echo "  KDP PDF: (skipped — install LaTeX to enable)"
fi
if command -v ebook-convert &> /dev/null; then
    echo "  Kindle: _build/mod_rewrite_and_friends.azw3"
else
    echo "  Kindle: (skipped — install Calibre to enable)"
fi
echo ""
echo "  TIP: To send to Kindle, email the .epub file to your @kindle.com address."
