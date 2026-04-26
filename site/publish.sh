#!/bin/bash
# Publish mod_rewrite And Friends to mod-rewrite.org
#
# Layout on the server:
#   /var/www/vhosts/mod-rewrite.org/
#   ├── index.html          ← landing page
#   ├── book/               ← HTML version of the book
#   └── download/
#       ├── mod_rewriteAndFriends.epub
#       ├── mod_rewrite_and_friends.pdf
#       └── mod_rewrite_book_html.zip
#
set -e

# --- Who are you? ------------------------------------------------------------

if [ "$(whoami)" != "rcbowen" ] && [ "$(whoami)" != "rbowen" ]; then
    echo "Hmm. It doesn't look like you."
    exit 1
fi

REMOTE="rbowen@fagin.rcbowen.com"
DOCROOT="/var/www/vhosts/mod-rewrite.org"
SITEDIR="$(cd "$(dirname "$0")" && pwd)"
BUILDDIR="$(cd "$SITEDIR/.." && pwd)"

# --- Preflight checks -------------------------------------------------------

echo "=== Preflight checks ==="

if [ ! -d "$BUILDDIR/_build/html" ]; then
    echo "ERROR: _build/html not found. Run ./build.sh first."
    exit 1
fi

EPUB="$BUILDDIR/_build/epub/mod_rewriteAndFriends.epub"
if [ ! -f "$EPUB" ]; then
    echo "ERROR: ePub not found at $EPUB. Run ./build.sh first."
    exit 1
fi

PDF="$BUILDDIR/_build/latex/mod_rewrite_and_friends.pdf"
if [ ! -f "$PDF" ]; then
    echo "WARNING: PDF not found at $PDF — skipping PDF upload."
    PDF=""
fi

# --- Build the HTML zip ------------------------------------------------------

echo "=== Packaging HTML zip ==="
ZIPFILE="$BUILDDIR/_build/mod_rewrite_book_html.zip"
rm -f "$ZIPFILE"
(cd "$BUILDDIR/_build" && zip -rq "$ZIPFILE" html/)
echo "  → $ZIPFILE"

# --- Create remote directories -----------------------------------------------

echo "=== Ensuring remote directories exist ==="
ssh "$REMOTE" "mkdir -p $DOCROOT/book $DOCROOT/download"

# --- Upload landing page -----------------------------------------------------

echo "=== Uploading landing page ==="
rsync -az "$SITEDIR/site_index.html" "$REMOTE:$DOCROOT/index.html"
rsync -az "$SITEDIR/Netscape_icon.svg" "$REMOTE:$DOCROOT/Netscape_icon.svg"
rsync -az "$SITEDIR/kdp_cover_front.png" "$REMOTE:$DOCROOT/kdp_cover_front.png"

# --- Upload HTML book --------------------------------------------------------

echo "=== Uploading HTML book ==="
rsync -az --delete "$BUILDDIR/_build/html/" "$REMOTE:$DOCROOT/book/"

# --- Upload downloads --------------------------------------------------------

echo "=== Uploading downloads ==="
rsync -az "$EPUB" "$REMOTE:$DOCROOT/download/"
rsync -az "$ZIPFILE" "$REMOTE:$DOCROOT/download/mod_rewrite_book_html.zip"
if [ -n "$PDF" ]; then
    rsync -az "$PDF" "$REMOTE:$DOCROOT/download/"
fi

# --- Done --------------------------------------------------------------------

echo ""
echo "=== Published ==="
echo "  Site:      https://mod-rewrite.org/"
echo "  Book:      https://mod-rewrite.org/book/"
echo "  Downloads: https://mod-rewrite.org/download/"
