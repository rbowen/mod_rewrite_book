# Makefile for Sphinx documentation
#
# mod_rewrite And Friends

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
SOURCEDIR     = .
BUILDDIR      = _build

.PHONY: help clean html epub pdf latexpdf linkcheck

help:
	@echo "Available targets:"
	@echo "  html      - Build HTML documentation"
	@echo "  epub      - Build EPUB ebook"
	@echo "  latexpdf  - Build PDF via LaTeX"
	@echo "  pdf       - Alias for latexpdf"
	@echo "  linkcheck - Check external links"
	@echo "  clean     - Remove build artifacts"

html:
	$(SPHINXBUILD) -b html $(SPHINXOPTS) $(SOURCEDIR) $(BUILDDIR)/html
	@echo "Build finished. The HTML pages are in $(BUILDDIR)/html."

epub:
	$(SPHINXBUILD) -b epub $(SPHINXOPTS) $(SOURCEDIR) $(BUILDDIR)/epub
	@echo "Build finished. The EPUB file is in $(BUILDDIR)/epub."

latexpdf:
	$(SPHINXBUILD) -b latex $(SPHINXOPTS) $(SOURCEDIR) $(BUILDDIR)/latex
	$(MAKE) -C $(BUILDDIR)/latex all-pdf
	@echo "Build finished. The PDF is in $(BUILDDIR)/latex."

pdf: latexpdf

linkcheck:
	$(SPHINXBUILD) -b linkcheck $(SPHINXOPTS) $(SOURCEDIR) $(BUILDDIR)/linkcheck
	@echo "Link check complete. Results are in $(BUILDDIR)/linkcheck."

clean:
	rm -rf $(BUILDDIR)
