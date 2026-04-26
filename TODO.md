# mod_rewrite And Friends — TODO for v3.9

**Last updated:** April 25, 2026 (after 20-year mailing list synthesis)
**Current version:** 3.8.0 (published to KDP April 25, 2026)
**Source:** `ml_research/SYNTHESIS.md` — full analysis of users@httpd.apache.org 2006–2025

---

## Notes for Rich & Quick

The synthesis of 20 years of mailing list Q&A revealed that the same 10–15 question types recur *every single year*. Peak volume was 2007–2009 (~350–389 threads/year), declining steadily as support migrated to Stack Overflow. By 2023–2025, only 10–20 threads/year — but the confusion hasn't changed, only the venue. The late-era threads (post-2018) tend to be higher quality edge cases.

The full synthesis is at `ml_research/SYNTHESIS.md` with 20 individual year reports in `ml_research/{year}.md`.

---

## Priority 1: Must Add (appeared 15+ years, no current coverage)

These are the biggest gaps — topics that tripped users *every single year* and the book doesn't cover.

- [ ] **REDIRECT_ env var prefix** — When Apache does an internal redirect, `[E=FOO:val]` becomes `REDIRECT_FOO`. Add sidebar in Ch6 (Flags) and Ch3 (.htaccess section). This was asked about from 2006 through 2025.

- [ ] **mod_alias vs mod_rewrite processing order** — Mixing `Redirect`/`RedirectMatch` with `RewriteRule` in the same context causes unpredictable behavior because they run in different phases. Add new section in Ch3 or Ch12 with a processing-order diagram.

- [ ] **mod_rewrite behind SSL terminators/load balancers** — `%{HTTPS}` calls mod_ssl directly, it is NOT an env var. `SetEnvIf ... HTTPS=on` doesn't affect `%{HTTPS}`. Behind a proxy: use `%{HTTP:X-Forwarded-Proto}`. Add new recipe + warning callout.

- [ ] **`<If>` and `<Location>` change RewriteRule context** — Placing RewriteRule inside `<If>` or `<Location>` silently switches to per-directory context behavior, even inside a `<VirtualHost>`. Add warning box in Ch4 and Ch12.

- [ ] **URL encoding deep dive** — The decode pipeline, `%{THE_REQUEST}` vs `%{REQUEST_URI}`, `AllowEncodedSlashes`, `[B]`/`[NE]`/`[BNP]` trio, `&` encoding in redirects, non-ASCII/UTF-8, the `+` sign ambiguity. Consider a dedicated section or major expansion of the existing "Special Characters" recipe.

- [ ] **Expression engine vs. RewriteRule substitution** — Users expect `%{md5:...}` to work in substitutions. It doesn't — `%{name:key}` in substitutions refers exclusively to RewriteMap lookups. Clarify in Ch4 and Ch8.

## Priority 2: Should Add (appeared 10+ years, thin or no coverage)

- [ ] **[L] vs [END] definitive explanation** — Expand Ch6 treatment with a visual diagram of the .htaccess re-invocation cycle. The #1 cause of rewrite loops.

- [ ] **.htaccess performance penalty** — Empirically measured: 20-directory-deep path with .htaccess is ~2x slower than AllowOverride None. Even AllowOverride All with NO .htaccess files adds ~47% overhead from stat() calls. Performance note in Ch3.

- [ ] **Debugging workflow** — Expand Ch5 into a full practical guide: enable trace → filter output → interpret log lines → test with `curl -v` → clear 301 browser cache. The "301 caching" problem alone was asked about across 15 years.

- [ ] **RewriteMap for IP-based access control** — Using txt: or prg: maps as a scalable alternative to hundreds of RewriteCond lines. New recipe in Ch8 or Ch11.

- [ ] **HSTS-compliant redirect chain** — The specific order required for HSTS preload: `http://example.com` → `https://example.com` → `https://www.example.com`. New recipe.

- [ ] **prg: RewriteMap gotchas** — Stdout flush, root privileges, concurrency under threaded MPMs, Python 3 interpreter path. Expand Ch8 with working examples in Perl, Python 3, and shell.

- [ ] **FallbackResource prominence** — For front-controller patterns, `FallbackResource /index.php` replaces the entire 4-line RewriteRule block. Mention more prominently in "When NOT" section and clean-URLs recipe.

- [ ] **WebSocket proxying via mod_rewrite** — The `%{HTTP:Upgrade} websocket` + `ws://...` [P] pattern and its limitations vs. mod_proxy_wstunnel. New recipe in Ch9.

## Priority 3: Nice to Have (5+ years, niche but valuable)

- [ ] **Time-based rewrites** — `%{TIME_HOUR}` for maintenance windows. The AND/OR condition logic gotcha.

- [ ] **Maintenance mode via RewriteMap** — Hot-reloadable text file that toggles 503 without restart.

- [ ] **Let's Encrypt / ACME challenge exemption** — `RewriteRule ^.well-known/ - [L]` before HTTPS redirect. Sub-recipe.

- [ ] **`[R=4xx]` misconception** — `[R=404]` sends a *redirect* with status 404, not a 404 response. Warning box in Ch6.

- [ ] **Filesystem path substitution gotcha** — Substitution starting with `/lib`, `/var`, `/bin` treated as filesystem path. `[PT]` flag forces URL interpretation. Warning box in Ch4.

- [ ] **CVE-2023-25690 and B/BNP/NE interaction** — Security hardening in 2.4.56+ broke rules passing user-controlled captures through [P]. Security note in Ch9.

## Common Misconceptions — Add Warning Boxes

These should become dedicated "Common Mistake" sidebars or `.. warning::` directives at relevant points in the text:

- [ ] "RewriteRule matches the full URL including scheme and query string" (Ch4)
- [ ] "[L] stops all rewrite processing" (Ch6)
- [ ] "In .htaccess, my pattern should start with /" (Ch4)
- [ ] "%{HTTPS} is an environment variable" (Ch7)
- [ ] "The # fragment is sent to the server" (Ch4)
- [ ] "mod_rewrite can inspect POST body data" (Ch4)
- [ ] "mod_rewrite can rewrite response bodies" (Ch13)
- [ ] "RewriteBase is a magic fix for .htaccess problems" (Ch3)
- [ ] "Environment variables survive across redirects" (Ch6)
- [ ] "RewriteEngine On in global config applies everywhere" (Ch3)
- [ ] "Query parameter order is reliable for matching" (Ch7)

## Book Housekeeping

- [ ] **Update README.md** with version 3.8.0 and any new chapters/sections
- [ ] **KDP verification** — Check publication status ~72 hours after submission (reminder set for Tue Apr 28 9AM)
- [ ] **Consider:** Dedicated URL encoding chapter vs. expanding the existing recipe
- [ ] **Consider:** Processing-order diagram (Rich — this probably wants to be a visual/SVG)

---

*This file lives at the project root and is excluded from the Sphinx build via `exclude_patterns` in conf.py.*
