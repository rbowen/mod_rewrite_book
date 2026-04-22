.. index:: appendix

====
TODO
====


This book is a work in progress, and I expect it to remain such for years to come. This is the place to check to see if you've purchased the latest version, and what changed from one version to another.

While the version number starts with 0.something, you can expect that there's quite a bit of work yet to do. Once it is 1.something, you can expect that changes will be fairly minor. I think. We'll see.


TODO
~~~~


* Write Content Munging chapter (Chapter 13 — outlined)
* Write Proxy chapter content (Chapter 9 — outlined)
* Write Virtual Hosts chapter content (Chapter 10 — outlined)
* Write Access Control chapter content (Chapter 11 — outlined)
* Provide issue tracker where people can log errata
* Verify all desired formats (pdf, html, epub)
* Automated publishing tools
* Update/Replace the section on regex testing tools, since these appear
  and vanish pretty quickly


.. index:: revision history
.. index:: pair: book; revision history
.. index:: pair: book formats; LaTeX
.. index:: pair: book formats; AsciiDoc
.. index:: pair: book formats; reStructuredText
.. index:: pair: book formats; Sphinx
.. index:: pair: book formats; Markdown

Revision History
----------------


* 0.00 Started March 7, 2013. Started TOC and a little of the initial text. Published HTML version to website at http://rewrite.rcbowen.com/
* 0.01 March 12, 2013. Initial publish to Amazon.com in Kindle form.
* 0.02 March 18, 2013. Munged the TOC around a bit to make the chapters less crowded. Will end up with some sparse chapters initially. So what.
* 0.03 March 18, 2013. Added a bunch about flags. Completed reorg of TOC. I hope.
* ...
* 0.12 April 16, 2013. Started RewriteMap stuff, and various other tweaks and fixes.
* 0.15 August 10, 2013. Attended Flock. Decided to convert all LaTeX to rST instead. Many benefits, but quite a bit of work. Should have a rebuild in the next few days.
* 0.20 August 12, 2013. Completed conversion from LaTeX to rST. I'm sure there's still some orts here and there, but it's good enough to tag.
* 0.30 - Christmas 2017. Yet another conversion, this time, to ASCIIdoc. Borrowed tools and templates from https://github.com/akosma/eBook-Template to get started. Website has been moved to http://mod-rewrite.org. We'll start publising it there again once we have a shippable version.
* 0.31 - Christmas 2018. Will the format changing never end? Converted to MarkDown and GitBook. https://toolchain.gitbook.com/ But I'm starting to remember that I rejected GitBook because it doesn't seem like there's a way to generate an index easily.
* 0.32 - The brief experiement with going back to Markdown abandoned, since Gitbook supports asciidoc. I'm going to focus on writing, and figure out indexing at some later date.
* 3.0 - April 2026. Converted back to reStructuredText / Sphinx. Full circle. Sphinx handles indexing, footnotes, cross-references, and multi-format output (HTML, ePub, PDF) natively — all the things that were missing or broken in every other toolchain. Ruby dependency replaced by Python. Build via ``uv run --with sphinx`` with no global install required.
* 3.1.0 - April 21, 2026. Rich index entries added across all chapters: 355+ entries covering every directive, flag, module, concept, and proper noun. Chapter 2 (URL Mapping) expanded with new sections for FallbackResource, AliasMatch/ScriptAliasMatch, RedirectMatch, :module:`mod_vhost_alias`, :module:`mod_proxy_express`, :module:`mod_userdir`, and :module:`mod_speling`; all TODO stubs (Proxying, :module:`mod_actions`, :module:`mod_imagemap`, :module:`mod_negotiation`, File Not Found) fleshed out.
* 3.1.1 - April 21, 2026. Epigraphs: converted chapter-opening quotes to ``.. epigraph::`` directives for proper rendering; added epigraphs to all 15 chapters (Kipling, Pratchett, Lear); created List of Epigraphs backmatter page. Outlines: detailed section outlines with ``.. todo::`` stubs for the four empty chapters (9 Proxy, 10 Vhosts, 11 Access, 13 Content Munging). Build fixes: resolved 16 Sphinx warnings (blank-line formatting after index entries across 8 files, duplicate cross-reference labels, code-block lexing errors, index directives inserted inside code blocks).
* 3.1.2 - April 21, 2026. Completeness pass: all 28 RewriteRule flags documented (added BNP, BCTLS, BNE, QSL, UnsafeAllow3F, UnsafePrefixStat, UNC; updated B flag with selective escaping syntax). Full RewriteOptions section (11 values: Inherit, InheritBefore, InheritDown, InheritDownBefore, IgnoreInherit, AllowNoSlash, AllowAnyURI, MergeBase, IgnoreContextInfo, LegacyPrefixDocRoot, LongURLOptimization). Full RewriteBase section. Chapter 8 (RewriteMap) fleshed out: Default Values, escape, unescape, txt, rnd, dbm, prg, dbd. Chapter 9 expanded with all 15 :module:`mod_proxy` family modules. Version badge system (:file:`_ext/version_badge.py`) with shape-based styling for grayscale/print. Chapter 7 server variables reformatted as ``hlist`` columns. Glossary populated with 43 terms. Toctree restructured: unnumbered Preface, numbered chapters 1–14, unnumbered back matter. ``man perlre`` reference added to Chapter 1. Log dates updated to 2026. Chapter-level labels added for cross-referencing.
* 3.2.0 - April 22, 2026. Chapter 14 (Recipes): all 33 recipe stubs replaced with full working content — 126 code examples covering HTTP→HTTPS redirects, hostname canonicalization, trailing slashes, domain migration, clean URLs, front controllers, hotlink blocking, user-agent filtering, cookie-based redirects, IP access control, reverse proxy URL rewriting, TLS-terminating proxies, WebSocket proxying, query string manipulation, rewrite loop diagnosis, :file:`.htaccess` vs server config differences, ``[L]`` flag behavior, rewrite log debugging, fallback resources, maintenance mode, special characters, performance with large redirect sets, and "when not to use :module:`mod_rewrite`" guidance. Chapter 7 (RewriteCond): examples section rewritten with 6 practical scenarios (query string matching, hostname routing, file existence, time-based rules, HTTPS detection, OR conditions). Every chapter now has substantive content.
