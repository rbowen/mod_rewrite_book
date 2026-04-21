.. _Chapter_recipes:


=======
Recipes
=======

.. epigraph::

   | If you swim to latitude Fifty North, longitude Forty West
   | (that is magic), you will find, sitting on a raft, in the
   | middle of the sea, one ship-wrecked Mariner, who, it is
   | only fair to tell you, is a man of infinite-resource-and-sagacity.

   -- Rudyard Kipling, *How the Whale Got His Throat*



In this chapter, we'll present various common problems, and a variety of
ways to solve them using ``mod_rewrite``, or one of the other tools
discussed in this book.

Some of these recipes have already been presented in other parts of the
book, but are gathered here to make it easier to find them. We'll also
expand, in detail, how they work, and when you might want to use one
solution versus another.

Many of these recipes are drawn from questions that appear regularly on the
``users@httpd.apache.org`` mailing list. They represent real-world problems
that real administrators face every day. Where a question comes up
repeatedly on the mailing list, we note that---it's a signal that the
existing documentation could do a better job of explaining the solution.


Common Redirects
----------------

These are the bread and butter of URL manipulation---the redirects that
every web administrator will need at some point.


.. index:: pair: recipes; HTTP to HTTPS redirect
.. index:: pair: recipes; force SSL

Redirecting HTTP to HTTPS
~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to force all traffic to use HTTPS. This is by far
the most common question on the httpd users mailing list, appearing in
dozens of threads over the years. Users frequently struggle with where to
put the redirect rules, especially when virtual hosts are involved.

**Approach:** ``Redirect`` (preferred), or ``mod_rewrite``, or ``<If>``

A common pitfall, seen in threads like "Virtual Host - Port 80 to 443,"
is putting SSL directives and rewrite rules in the same ``<VirtualHost>``
block. The correct pattern is to use *two* virtual host blocks: one for
port 80 that does nothing but redirect, and one for port 443 that holds
the actual site configuration.

.. todo:: Flesh out this recipe with full example showing the two-VirtualHost
   pattern, the single-line ``Redirect`` approach, the ``mod_rewrite``
   approach, and the ``<If>`` expression approach. Include the common
   mistakes (single VirtualHost, ``_default_:443`` confusion).


.. index:: pair: recipes; www canonicalization
.. index:: pair: recipes; canonical hostname

Canonicalizing the Hostname (www vs. non-www)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``www.example.com`` and ``example.com`` to resolve
to a single canonical URL, to avoid duplicate content in search engines.
This comes up frequently on the mailing list, often intertwined with the
HTTP-to-HTTPS redirect question.

**Approach:** Separate ``<VirtualHost>`` blocks (preferred), or
``mod_rewrite`` with ``RewriteCond %{HTTP_HOST}``

As noted in the "redirect vs. rewrite" thread on the httpd users list,
the recommended approach from experienced responders is to use separate
virtual hosts for hostname canonicalization, rather than ``RewriteCond``.
This keeps the configuration clearer and avoids accidental interactions
with other rewrite rules.

.. todo:: Flesh out this recipe with the separate-VirtualHost approach,
   the ``RewriteCond`` approach, and explain why separate VirtualHosts
   are preferred. Show how to combine with the HTTPS redirect.


.. index:: pair: recipes; trailing slash redirect
.. index:: pair: recipes; DirectorySlash

Adding or Removing Trailing Slashes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want consistent URLs---either always with a trailing
slash or always without. ``mod_dir``'s ``DirectorySlash`` directive
interacts with this in ways that confuse many users.

**Approach:** ``mod_dir`` / ``DirectorySlash``, or ``mod_rewrite``

A mailing list thread on "Limiting redirects with rewriterule/rewritecond"
discusses combining trailing-slash removal with other rewrites to reduce
the number of redirects a client experiences. One respondent notes:
"be careful about not creating loops, especially if using .htaccess files."

.. todo:: Flesh out this recipe with examples for both adding and removing
   trailing slashes. Explain ``DirectorySlash`` interaction. Show how to
   avoid redirect loops.


.. index:: pair: recipes; domain migration
.. index:: pair: recipes; old domain to new domain

Redirecting an Entire Site to a New Domain
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You've moved your site to a new domain and want to redirect
all old URLs to the new domain, preserving the path. This comes up
frequently on the mailing list---a thread on "rewrite in .htaccess" shows
a user migrating a WordPress site who gets partial redirects because
their rewrite rules are in the wrong order.

**Approach:** ``Redirect`` (preferred for simple cases), or ``mod_rewrite``

The key mistake in the mailing list thread: placing the domain-migration
rewrite rules *after* the WordPress ``.htaccess`` rules, which short-circuit
with ``[L]`` before the migration rules are reached.

.. todo:: Flesh out with ``Redirect permanent / https://new.example.com/``
   approach, the ``mod_rewrite`` approach, and explain rule ordering when
   WordPress or other CMS ``.htaccess`` rules are involved.


.. index:: pair: recipes; moved page redirect
.. index:: pair: recipes; 301 redirect

Redirecting Individual Pages That Have Moved
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Specific pages have moved to new URLs (site restructure,
CMS migration, etc.) and you need 301 redirects for SEO. A thread on
"Redirects and rewrites and performance" discusses a site with *10,000*
accumulated redirects from years of migrations, raising the question of
when performance becomes a concern.

**Approach:** ``Redirect`` / ``RedirectMatch`` (preferred), or
``RewriteRule``, or ``RewriteMap`` for large numbers of redirects

For a small number of redirects, ``Redirect`` directives are simplest.
For thousands of redirects, use a ``RewriteMap`` with a DBM or text file
to avoid loading thousands of individual directives.

.. todo:: Flesh out with examples of ``Redirect``, ``RedirectMatch``,
   and ``RewriteMap`` (text and DBM). Discuss performance implications
   of thousands of individual ``RewriteRule`` directives vs. a map lookup.


.. index:: pair: recipes; wildcard subdomain redirect

Redirecting Wildcard Subdomains
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to redirect ``*.oldsite.com`` to ``newsite.com``,
possibly preserving certain allowed subdomains. A detailed thread on
"Apache Rewrite - Redirect Wildcard Subdomain" shows a user with complex
requirements: some wildcard subdomains should redirect to the base domain,
while others should be preserved on the new domain.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{HTTP_HOST}``

This requires ``mod_rewrite`` because ``Redirect`` and ``RedirectMatch``
cannot match against the hostname. The key is getting the ``ServerAlias``
right (``*.oldsite.com``) and using ``RewriteCond`` to capture and
selectively route subdomain patterns.

.. todo:: Flesh out with examples for simple wildcard redirect, selective
   subdomain preservation, and the interaction with ``ServerAlias`` and
   DNS wildcards.


Clean and Pretty URLs
---------------------

Making URLs user-friendly and hiding implementation details.


.. index:: pair: recipes; remove file extension
.. index:: pair: recipes; extensionless URLs

Removing File Extensions (.php, .html)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``/about`` to serve ``/about.php`` without the user
seeing the ``.php`` extension. A thread on "Remove .php extension but
still pass it to PHP-FPM" shows this is especially tricky when PHP-FPM is
in the mix, because the proxy handler needs to know the actual file path.

**Approach:** ``mod_rewrite`` (with ``-f`` check), or ``MultiViews``
(content negotiation)

``MultiViews`` (enabled via ``Options +MultiViews``) can handle this
without any rewrite rules at all, but its behavior can be surprising and
it has performance implications. The ``mod_rewrite`` approach gives more
control.

.. todo:: Flesh out with the ``MultiViews`` approach (simplest),
   the ``mod_rewrite`` approach with ``-f`` file existence check, and
   the special considerations when using PHP-FPM / ``ProxyPassMatch``.


.. index:: pair: recipes; path-based routing
.. index:: pair: recipes; front controller

Front Controller Pattern (CMS/Framework Routing)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your application framework (WordPress, Laravel, Symfony,
etc.) uses a front controller pattern where all requests that don't match
a real file should be routed to ``index.php``. This is the single most
common ``.htaccess`` configuration on the web, and it generates a steady
stream of mailing list questions when it doesn't work.

**Approach:** ``mod_rewrite`` in ``.htaccess``

The standard WordPress ``.htaccess`` pattern is::

    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]

A thread on "WordPress .htaccess rewrite issue between httpd versions"
documents a rewrite loop that appeared when migrating from httpd 2.4.6 to
2.4.51 with PHP-FPM---the ``ProxyPassMatch`` for PHP files interacted
with the ``.htaccess`` rewrite rules in an unexpected way, causing the
rewrite to loop infinitely.

.. todo:: Flesh out with the standard front controller pattern, explain each
   line, show what breaks when ``AllowOverride`` is wrong or ``RewriteBase``
   is missing. Document the PHP-FPM interaction issue.


.. index:: pair: recipes; clean URLs
.. index:: pair: recipes; path to query string

Mapping Clean URL Paths to Query Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``/products/widget-42`` to internally map to
``/product.php?id=widget-42``. This is a classic ``mod_rewrite`` use case
and appears in many mailing list threads. A common mistake (seen in
"RewriteRule not working, 404 error obtained") is that ``AllowOverride``
is not set correctly, so the ``.htaccess`` rules are silently ignored.

**Approach:** ``mod_rewrite``

.. todo:: Flesh out with examples of simple path-to-query mapping,
   multi-segment paths, and the common pitfall of ``AllowOverride None``
   silently disabling ``.htaccess`` rewrite rules.


Access Control
--------------

Using URL manipulation for access control purposes. (Note: ``mod_rewrite``
is generally *not* the best tool for access control---``Require``,
``<If>``, and ``mod_authz_*`` are usually better choices.)


.. index:: pair: recipes; block by referrer
.. index:: pair: recipes; hotlink protection

Blocking Hotlinking (Referrer-Based Access)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Other sites are embedding your images directly, consuming
your bandwidth. You want to block or redirect requests that come from
other domains.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{HTTP_REFERER}``
(traditional), or ``<If>`` expression (modern, preferred)

.. todo:: Flesh out with the ``mod_rewrite`` approach using
   ``%{HTTP_REFERER}``, the ``<If>`` expression approach, and caveats
   about referrer spoofing and empty referrers (direct visits, privacy
   extensions).


.. index:: pair: recipes; block by user agent
.. index:: pair: recipes; bot blocking

Blocking Requests by User-Agent
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to block specific bots, scrapers, or vulnerability
scanners based on their User-Agent string. Several mailing list threads
discuss this in the context of "Unknown accepted traffic" and bot
mitigation.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{HTTP_USER_AGENT}``
(traditional), or ``<If>`` / ``SetEnvIf`` with ``Require`` (modern,
preferred)

.. todo:: Flesh out with both approaches. Explain why ``<If>`` or
   ``SetEnvIf`` + ``Require`` is usually cleaner than ``mod_rewrite``
   for this use case. Note that User-Agent is trivially spoofed.


.. index:: pair: recipes; cookie-based access
.. index:: pair: recipes; authentication redirect

Cookie-Based Redirect to Login Page
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to redirect users to a login page if a specific
authentication cookie is not present. A thread on "redirects on Apache
2.4" shows a user trying to check for a ``web_route`` cookie and redirect
unauthenticated users to a login portal.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{HTTP_COOKIE}``

The common mistake from the mailing list: the rewrite rules are in the
wrong order, and the ``[L]`` flag on the front controller rule prevents
the cookie check from ever being evaluated.

.. todo:: Flesh out with a working example, explain rule ordering issues,
   and discuss whether ``mod_auth_form`` or a reverse proxy approach
   would be more appropriate for real authentication.


.. index:: pair: recipes; IP-based access control
.. index:: pair: recipes; block by IP

IP-Based Access Control
~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to restrict access to certain paths based on client
IP address.

**Approach:** ``Require ip`` (strongly preferred), ``<If>`` expressions,
or ``mod_rewrite`` with ``RewriteCond %{REMOTE_ADDR}`` (not recommended)

.. todo:: Flesh out showing why ``Require ip`` is the right tool here.
   Include ``mod_rewrite`` approach only to show how *not* to do it,
   and explain why the authorization modules are better.


Proxying
--------

Rewriting in the context of reverse proxying is a common source of
confusion, as the mailing list amply demonstrates.


.. index:: pair: recipes; reverse proxy rewrite
.. index:: pair: recipes; ProxyPass and rewrite

Rewriting URLs for a Reverse Proxy Backend
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your reverse proxy needs to strip or add a path prefix when
forwarding requests to a backend application. A detailed thread on
"mod_proxy_http rewrite problem" shows a user struggling with balancer
configuration where the rewrite rule incorrectly strips the application
context path, causing authentication to break.

**Approach:** ``ProxyPass`` path mapping (preferred), or ``mod_rewrite``
with ``[P]`` flag

The recommended approach is to let ``ProxyPass`` and ``ProxyPassReverse``
handle the path mapping. Using ``mod_rewrite`` with ``[P]`` should be a
last resort, because it bypasses the connection pooling and other
optimizations of ``mod_proxy``.

.. todo:: Flesh out with ``ProxyPass`` path mapping examples, the
   ``mod_rewrite`` ``[P]`` flag approach, and ``ProxyPassReverse`` for
   fixing redirect headers from the backend. Show the common mistake
   of mixing ``ProxyPass`` with ``RewriteRule [P]``.


.. index:: pair: recipes; TLS termination proxy
.. index:: pair: recipes; X-Forwarded-Proto

Redirects Behind a TLS-Terminating Proxy
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your httpd sits behind a load balancer or CDN that terminates
TLS. The ``%{HTTPS}`` variable is always ``off`` from httpd's perspective,
causing redirect loops when you try to force HTTPS. A thread on
"Configuring redirects httpd behind a TLS-terminating proxy" discusses
this exact scenario.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{HTTP:X-Forwarded-Proto}``
or ``<If>`` with ``req('X-Forwarded-Proto')``

.. todo:: Flesh out with examples showing how to check the
   ``X-Forwarded-Proto`` header instead of ``%{HTTPS}``, and how to
   configure ``mod_remoteip`` to trust the proxy headers.


.. index:: pair: recipes; WebSocket proxy
.. index:: pair: recipes; wss proxy

WebSocket Proxying
~~~~~~~~~~~~~~~~~~

**Problem:** Your application uses WebSockets and you need to proxy
``ws://`` or ``wss://`` traffic through httpd. A recurring thread on
"Web sockets & proxypass - No protocol handler was valid for the URL"
shows users struggling to get ``mod_proxy_wstunnel`` working.

**Approach:** ``mod_proxy_wstunnel`` with ``ProxyPass``, sometimes
combined with ``mod_rewrite`` for upgrade detection

.. todo:: Flesh out with ``mod_proxy_wstunnel`` configuration,
   the ``RewriteCond %{HTTP:Upgrade} websocket [NC]`` pattern,
   and common pitfalls (missing module, wrong protocol handler).


Query String Manipulation
-------------------------

Rewriting query strings requires special techniques because the query
string is not part of the URL path that ``RewriteRule`` matches against.


.. index:: pair: recipes; query string rewrite
.. index:: pair: recipes; QSA flag

Capturing and Rewriting Query Strings
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to rewrite based on query string parameters, or
transform query strings during a redirect. A thread on "Mod_rewrite
too many redirects" shows a user trying to redirect ``/?1234ab`` to
``/welcome?trackFor=0&trackNo=1234ab`` and getting a redirect loop.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{QUERY_STRING}`` and
``[QSA]`` or ``[QSD]`` flags

The solution from the mailing list: the original ``RewriteRule ^(.*)$``
pattern was matching the redirect *target* as well, causing an infinite
loop. Changing to ``^/$`` (matching only the root) fixed the loop.

.. todo:: Flesh out with examples of query string capture via
   ``RewriteCond %{QUERY_STRING}``, the ``[QSA]`` (append) and ``[QSD]``
   (discard) flags, and how to avoid redirect loops when rewriting
   query strings.


.. index:: pair: recipes; strip query string
.. index:: pair: recipes; remove query string

Stripping Query Strings
~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to remove query strings from URLs, either for
SEO cleanliness or to prevent parameter injection, but you need to
preserve query strings on certain specific URLs. A thread on
"Stripping query string except from specific URL" shows this exact use
case.

**Approach:** ``mod_rewrite`` with ``[QSD]`` flag and ``RewriteCond``
exceptions

.. todo:: Flesh out with examples showing blanket query string removal
   with ``[QSD]``, how to exclude specific paths from stripping, and
   the difference between ``[QSD]`` (2.4+) and the old ``?`` trick
   for discarding query strings.


.. index:: pair: recipes; SetEnvIf query string

Using SetEnvIf with Query Strings
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to set environment variables or control logging
based on query string parameters. A thread on "Using SetEnvIf for query
string" shows a user trying to conditionally set environment variables.

**Approach:** ``SetEnvIf`` with ``QUERY_STRING`` variable, or
``mod_rewrite`` with ``[E=VAR:value]`` flag

.. todo:: Flesh out with ``SetEnvIf`` examples for query string matching
   and the ``mod_rewrite`` ``[E=]`` flag approach. Discuss use cases
   like conditional logging and cache control.


Edge Cases and Gotchas
----------------------

These recipes address the tricky situations that generate the most
confused questions on the mailing list.


.. index:: pair: recipes; rewrite loop
.. index:: pair: recipes; too many redirects
.. index:: pair: recipes; infinite loop

Diagnosing and Fixing Rewrite Loops
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your rewrite rules produce "too many redirects" errors or
infinite internal loops. This is the single most common class of rewrite
problem on the mailing list. Threads include "Mod_rewrite too many
redirects," "SSO Kerberos REMOTE_USER RewriteRule Endless Loop," and
"WordPress .htaccess rewrite issue between httpd versions."

**Approach:** ``RewriteLog`` / ``LogLevel rewrite:trace``, plus rule
design patterns to break loops

The Kerberos/SSO thread shows a particularly interesting edge case: a
``RewriteCond %{LA-U:REMOTE_USER}`` rule that works for 97% of users
but creates an endless loop for the other 3%, due to special characters
in certain usernames interacting with the lookahead mechanism.

.. todo:: Flesh out with a systematic approach to diagnosing rewrite loops:
   1. Enable ``LogLevel rewrite:trace3``, 2. Identify the looping rule,
   3. Common patterns that cause loops (overly broad ``RewriteRule``
   matching its own target, missing ``[L]`` flags, ``.htaccess`` rules
   re-evaluated after internal subrequests). Include the WordPress/PHP-FPM
   loop case.


.. index:: pair: recipes; .htaccess context
.. index:: pair: recipes; AllowOverride
.. index:: pair: recipes; per-directory rewrite

.htaccess vs. Server Config Context Differences
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your rewrite rules work in ``httpd.conf`` but not in
``.htaccess`` (or vice versa). This is one of the most frequent sources
of confusion on the mailing list. In "Rewrite not applied?" a user has
rules in server config that are silently not being evaluated, with no
log entries even at ``rewrite:trace5``.

**Approach:** Understanding the ``per-dir`` context

The key differences:

- In ``.htaccess``, the leading slash is stripped from the URI before
  matching
- ``RewriteBase`` matters in ``.htaccess`` but not in server config
- ``AllowOverride`` must include ``FileInfo`` for rewrite rules to work
  in ``.htaccess``
- ``[L]`` in ``.htaccess`` doesn't truly stop processing---the rewritten
  URL goes through the entire ``.htaccess`` again

.. todo:: Flesh out with side-by-side examples showing the same rule
   in both contexts, explain ``RewriteBase``, and document the
   ``AllowOverride`` pitfall where rules are silently ignored.


.. index:: pair: recipes; rewrite rule ordering
.. index:: pair: recipes; rule order

Rule Ordering and the [L] Flag
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your rewrite rules aren't behaving as expected because of
ordering issues. The "rewrite in .htaccess" thread shows a user whose
domain migration redirect is placed *after* WordPress rewrite rules that
include ``[L]``---the migration rules are never reached.

**Approach:** Understanding rule processing order

.. todo:: Flesh out with examples showing how ``[L]`` works (and doesn't
   work) in ``.htaccess`` context, the order in which rules are applied
   between server config and ``.htaccess``, and how ``RewriteCond`` binds
   only to the immediately following ``RewriteRule``.


.. index:: pair: recipes; rewrite log
.. index:: pair: recipes; RewriteLog
.. index:: pair: recipes; debugging rewrite

Debugging Rewrite Rules with the Rewrite Log
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You can't figure out why your rewrite rules aren't doing what
you expect. The thread on "Redirects and rewrites and performance" shows
a user asking how to trace a *specific* redirect without overwhelming the
log with data from the entire site.

**Approach:** ``LogLevel rewrite:trace1`` through ``rewrite:trace8``

.. todo:: Flesh out with examples of enabling the rewrite log at various
   levels, reading and interpreting the log output, and techniques for
   filtering the log to focus on specific URLs (using ``<If>`` or
   ``<Location>`` to set LogLevel per-path, or grep/awk on the log).


.. index:: pair: recipes; conditional fallback
.. index:: pair: recipes; file not found fallback

Serving a Fallback Resource When a File Is Missing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to serve a default image, page, or resource when
the requested file doesn't exist. A thread on "Show Alternate Image if
Requested Image is Missing" shows a user trying to display a placeholder
sketch image when the actual property sketch JPG is missing.

**Approach:** ``mod_rewrite`` with ``RewriteCond %{REQUEST_FILENAME} !-f``
(traditional), or ``FallbackResource`` directive (modern, preferred)

The mailing list thread reveals the common mistake: mixing ``Redirect``
(which doesn't check file existence) with ``RewriteCond`` conditions.
The ``FallbackResource`` directive, available since 2.2.16, is often the
simplest solution.

.. todo:: Flesh out with the ``FallbackResource`` approach, the
   ``mod_rewrite`` approach with ``!-f`` checks, and the specific case
   of image fallbacks.


.. index:: pair: recipes; maintenance mode
.. index:: pair: recipes; 503 response

Maintenance Mode (503 Service Unavailable)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to put your site into maintenance mode, returning
a 503 response to all requests while you work on the backend. A thread on
"enforce 503 response using RewriteRule or Redirect due to temporary
maintenance" notes that ``Redirect`` supports ``gone`` (410) but not
503.

**Approach:** ``mod_rewrite`` with ``[R=503]``, or ``ErrorDocument 503``
combined with ``<If>``

.. todo:: Flesh out with the ``mod_rewrite`` approach using ``[R=503]``
   plus ``ErrorDocument 503``, a ``RewriteMap`` approach for per-application
   maintenance (toggled by editing the map file without restarting httpd),
   and the ``<If>`` approach with environment variables or file existence
   checks.


.. index:: pair: recipes; special characters in URLs
.. index:: pair: recipes; URL encoding

Handling Special Characters and Encoded URLs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Rewrite rules break when URLs contain special characters
(spaces as ``%20``, international characters, backslashes, etc.). A thread
on "404 rewrite error using special character \\" shows issues with
backslashes, while "chinese char URL encoding/decoding fails" documents
problems with multibyte character encoding.

**Approach:** ``mod_rewrite`` with ``[B]`` flag and ``[NE]`` flag

.. todo:: Flesh out with examples showing the ``[B]`` flag (escape
   backreferences), the ``[NE]`` flag (no-escape output), and how httpd
   handles URL decoding before rewrite rules see the URI. Include the
   ``AllowEncodedSlashes`` directive for paths with ``%2F``.


.. index:: pair: recipes; performance
.. index:: pair: recipes; thousands of redirects

Performance with Large Numbers of Redirects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You have hundreds or thousands of redirects and are concerned
about performance impact. The "Redirects and rewrites and performance"
thread asks directly: "At what point does it begin to affect performance
with the number of redirects?" for a site with ~10,000 accumulated
redirects.

**Approach:** ``RewriteMap`` (DBM or text file), database-backed lookups

.. todo:: Flesh out with benchmarks or guidance on when individual
   ``RewriteRule`` directives become problematic, how ``RewriteMap`` with
   DBM provides O(1) lookups regardless of map size, and how to migrate
   from thousands of individual rules to a map file.


When NOT to Use mod_rewrite
---------------------------

As discussed throughout this book, ``mod_rewrite`` is powerful but often
not the best tool for the job. These recipes show problems that are better
solved with other modules.


.. index:: pair: recipes; Redirect vs RewriteRule
.. index:: pair: recipes; mod_alias

Simple Redirects: Use Redirect, Not RewriteRule
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You're using ``RewriteRule`` with ``[R=301]`` for simple
page-to-page or site-to-site redirects. A mailing list thread titled
"redirect vs. rewrite" directly asks: "What is the difference between
``Redirect permanent /`` and ``RewriteRule ^/?(.*) [R,L]``?"

**Approach:** ``Redirect`` / ``RedirectMatch`` from ``mod_alias``

The answer from the mailing list: for simple redirects, they're
functionally equivalent, but ``Redirect`` is clearer, faster (no regex
engine involved for plain ``Redirect``), and less error-prone. As one
respondent notes: "Golden rule: if source ends in trailing slash, target
must also end in trailing slash."

.. todo:: Flesh out with a comparison table showing when to use
   ``Redirect``, ``RedirectMatch``, and ``RewriteRule [R]``. Include
   the "golden rule" about trailing slashes.


.. index:: pair: recipes; ProxyPass vs mod_rewrite proxy
.. index:: pair: recipes; mod_proxy

Proxying: Use ProxyPass, Not RewriteRule [P]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You're using ``RewriteRule`` with the ``[P]`` flag to proxy
requests to a backend server.

**Approach:** ``ProxyPass`` / ``ProxyPassReverse`` from ``mod_proxy``

.. todo:: Flesh out explaining why ``ProxyPass`` is preferred (connection
   pooling, proper error handling, ``ProxyPassReverse`` header rewriting)
   and when ``[P]`` is actually needed (complex conditional proxying).


.. index:: pair: recipes; If expression
.. index:: pair: recipes; mod_rewrite alternatives

Conditional Logic: Use <If> Expressions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You're using ``mod_rewrite`` for conditional configuration
that doesn't involve URL rewriting---like setting headers based on
request properties or denying access based on complex conditions.

**Approach:** ``<If>`` expressions (available since httpd 2.4)

The ``<If>`` directive supports a rich expression language that can test
request headers, environment variables, IP addresses, and more---without
the cognitive overhead of ``RewriteCond``/``RewriteRule`` syntax.

.. todo:: Flesh out with examples converting common ``RewriteCond``
   patterns to ``<If>`` expressions: checking User-Agent, checking
   request headers, checking source IP, and combining multiple conditions.


.. index:: pair: recipes; FallbackResource
.. index:: pair: recipes; ErrorDocument

Fallback Resources: Use FallbackResource, Not RewriteRule
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want all requests for non-existent files to be handled
by a single script (the front controller pattern). The traditional approach
uses ``mod_rewrite``, but ``FallbackResource`` does this in a single line.

**Approach:** ``FallbackResource`` directive

::

    FallbackResource /index.php

This single line replaces the entire WordPress-style rewrite block for the
common case. It was added in httpd 2.2.16 specifically to address this
extremely common use case.

.. todo:: Flesh out showing the ``FallbackResource`` directive vs. the
   traditional ``mod_rewrite`` front controller block. Discuss limitations
   (``FallbackResource`` doesn't support conditions or complex routing).


.. index:: pair: recipes; RewriteMap
.. index:: pair: recipes; external program map

Advanced: Using RewriteMap for Dynamic Rewrites
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need dynamic URL mapping that's too complex for static
rules---looking up redirects in a database, calling an external program,
or using complex logic. Threads on "Perl prg RewriteMap always returns
blank" and "RewriteMap prg: How to pass value from Python3 script back
to Apache24?" show users struggling with the external program map type.

**Approach:** ``RewriteMap`` with various map types (``txt``, ``dbm``,
``prg``, ``dbd``, ``int``)

.. todo:: Flesh out with examples of each map type, with special attention
   to the ``prg:`` (external program) type---common pitfalls include
   buffering issues (stdout must be line-buffered or unbuffered), the
   program not flushing output, and the program crashing silently.


.. index:: pair: recipes; RewriteMap CIDR
.. index:: pair: recipes; IP range matching

Advanced: IP Range Matching with RewriteMap
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to match client IPs against CIDR ranges in rewrite
rules. A thread on "Apache rewritemap condition that will CIDR-ipmatch
against returned value from the map?" shows this is not straightforward
with standard rewrite conditions.

**Approach:** ``RewriteMap`` with ``prg:`` type for CIDR matching, or
``<If>`` with ``-ipmatch`` operator (preferred for simple cases)

.. todo:: Flesh out with the ``<If> "%{REMOTE_ADDR} -ipmatch '10.0.0.0/8'"``
   approach (simplest), and the ``RewriteMap`` approach for cases where
   the CIDR ranges need to be looked up dynamically.
