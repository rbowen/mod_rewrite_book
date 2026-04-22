#!/usr/bin/env python3
"""
Post-build script to fix ePub footnote markup for Kindle compatibility.

Sphinx 9.x generates ePub3 footnotes using DPUB-ARIA roles:
    <a role="doc-noteref" ...>
    <aside role="doc-footnote" ...>

Kindle doesn't handle these correctly — footnotes appear as blue text
but aren't clickable. This script adds epub:type attributes that Kindle
understands:
    <a epub:type="noteref" role="doc-noteref" ...>
    <aside epub:type="footnote" role="doc-footnote" ...>

Usage:
    # After building the epub:
    uv run --with sphinx -- sphinx-build -b epub . _build/epub
    python3 fix_epub_footnotes.py

    # Or as a one-liner:
    uv run --with sphinx -- sphinx-build -b epub . _build/epub && python3 fix_epub_footnotes.py
"""

import os
import re
import zipfile
import shutil
import sys

EPUB_DIR = os.path.join(os.path.dirname(__file__), '_build', 'epub')
EPUB_NS = 'xmlns:epub="http://www.idpf.org/2007/ops"'


def fix_xhtml_file(filepath):
    """Add epub:type attributes to footnote elements in an xhtml file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    fixes = 0

    # Add epub namespace to <html> tag if not present
    if 'xmlns:epub' not in content:
        content = content.replace(
            'xmlns="http://www.w3.org/1999/xhtml"',
            'xmlns="http://www.w3.org/1999/xhtml" ' + EPUB_NS
        )

    # Fix footnote references: add epub:type="noteref"
    # Match: <a ... role="doc-noteref" ...> without existing epub:type
    pattern = r'(<a\b(?:(?!epub:type)[^>])*)(role="doc-noteref")'
    replacement = r'\1epub:type="noteref" \2'
    content, n = re.subn(pattern, replacement, content)
    fixes += n

    # Fix footnote definitions: add epub:type="footnote"
    # Match: <aside ... role="doc-footnote" ...> without existing epub:type
    pattern = r'(<aside\b(?:(?!epub:type)[^>])*)(role="doc-footnote")'
    replacement = r'\1epub:type="footnote" \2'
    content, n = re.subn(pattern, replacement, content)
    fixes += n

    # Fix back-links: add epub:type="noteref" to doc-backlink
    pattern = r'(<a\b(?:(?!epub:type)[^>])*)(role="doc-backlink")'
    replacement = r'\1epub:type="noteref" \2'
    content, n = re.subn(pattern, replacement, content)
    fixes += n

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

    return fixes


def rebuild_epub(epub_dir):
    """Rebuild the .epub file from the directory contents."""
    # Find the epub file
    epub_files = [f for f in os.listdir(epub_dir) if f.endswith('.epub')]
    if not epub_files:
        print("  No .epub file found in build directory")
        return

    epub_path = os.path.join(epub_dir, epub_files[0])

    # Create new epub (which is just a zip with specific structure)
    tmp_path = epub_path + '.tmp'
    with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        # mimetype must be first and uncompressed
        mimetype_path = os.path.join(epub_dir, 'mimetype')
        if os.path.exists(mimetype_path):
            zf.write(mimetype_path, 'mimetype', compress_type=zipfile.ZIP_STORED)

        # Walk the directory and add everything else
        for root, dirs, files in os.walk(epub_dir):
            for f in files:
                if f.endswith('.epub') or f.endswith('.epub.tmp') or f == '.buildinfo':
                    continue
                full_path = os.path.join(root, f)
                arc_name = os.path.relpath(full_path, epub_dir)
                if arc_name == 'mimetype':
                    continue  # Already added
                zf.write(full_path, arc_name)

    # Replace original
    shutil.move(tmp_path, epub_path)
    print(f"  Rebuilt {epub_files[0]}")


def main():
    if not os.path.isdir(EPUB_DIR):
        print(f"ePub build directory not found: {EPUB_DIR}")
        print("Run 'sphinx-build -b epub . _build/epub' first.")
        sys.exit(1)

    total_fixes = 0

    # Process all xhtml files
    chapters_dir = os.path.join(EPUB_DIR, 'chapters')
    xhtml_dirs = [EPUB_DIR, chapters_dir] if os.path.isdir(chapters_dir) else [EPUB_DIR]

    for search_dir in xhtml_dirs:
        if not os.path.isdir(search_dir):
            continue
        for f in sorted(os.listdir(search_dir)):
            if f.endswith('.xhtml'):
                filepath = os.path.join(search_dir, f)
                fixes = fix_xhtml_file(filepath)
                if fixes > 0:
                    print(f"  {f}: {fixes} footnote fixes")
                    total_fixes += fixes

    if total_fixes > 0:
        print(f"\nTotal: {total_fixes} footnote attributes added")
        rebuild_epub(EPUB_DIR)
    else:
        print("No footnote fixes needed")


if __name__ == '__main__':
    main()
