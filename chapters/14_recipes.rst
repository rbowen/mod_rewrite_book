.. _Chapter_recipes:


=======
Recipes
=======

.. epigraph::

   | Not to know that no space of regret can make amends
   | for one life's opportunity misused!

   -- Charles Dickens, *A Christmas Carol*



In this chapter, we'll present various common problems, and a variety of
ways to solve them using :module:`mod_rewrite`, or one of the other tools
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

**Approach:** ``Redirect`` (preferred), or :module:`mod_rewrite`, or ``<If>``

A common pitfall, seen in threads like "Virtual Host - Port 80 to 443,"
is putting SSL directives and rewrite rules in the same ``<VirtualHost>``
block. The correct pattern is to use *two* virtual host blocks: one for
port 80 that does nothing but redirect, and one for port 443 that holds
the actual site configuration.

The simplest and clearest approach uses two ``<VirtualHost>`` blocks and a
single ``Redirect`` directive:

.. code-block:: apache

   # Port 80: redirect everything to HTTPS
   <VirtualHost *:80>
       ServerName www.example.com
       Redirect permanent / https://www.example.com/
   </VirtualHost>

   # Port 443: the real site
   <VirtualHost *:443>
       ServerName www.example.com
       SSLEngine on
       SSLCertificateFile    /etc/pki/tls/certs/example.com.crt
       SSLCertificateKeyFile /etc/pki/tls/private/example.com.key
       DocumentRoot /var/www/html
   </VirtualHost>

The ``Redirect permanent`` on port 80 sends a 301 for every request,
preserving the original path and query string. The client's browser will
cache this redirect, so subsequent visits go straight to HTTPS.

.. warning::

   Do **not** put ``SSLEngine on`` and ``Redirect`` in the same
   ``<VirtualHost>`` block. The port-80 block handles plaintext HTTP; the
   port-443 block handles TLS. Mixing them is the single most common
   mistake seen on the mailing list.

If you need :module:`mod_rewrite` for this (perhaps because you're in a
:file:`.htaccess` file and can't define virtual hosts):

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTPS} off
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

The ``RewriteCond %{HTTPS} off`` ensures this only fires for plaintext
connections, preventing a redirect loop. See
:ref:`Chapter 7 <Chapter_rewritecond>` for details on ``RewriteCond``.

Starting with httpd 2.4, you can also use an ``<If>`` expression inside
the port-80 virtual host:

.. code-block:: none

   <If "%{HTTPS} == 'off'">
       Redirect permanent / https://www.example.com/
   </If>

The ``<If>`` approach reads more naturally than ``RewriteCond``, but
the two-``VirtualHost`` pattern with a bare ``Redirect`` remains the
cleanest solution. The ``<If>`` form is most useful when you cannot
separate the configuration into two virtual host blocks.

Another common mistake: using ``_default_:443`` as the virtual host
address. This creates a catch-all SSL host that matches *any* hostname,
which can cause certificate mismatch warnings if you have multiple
domains. Always use an explicit ``ServerName`` in your SSL virtual host.


.. index:: pair: recipes; www canonicalization
.. index:: pair: recipes; canonical hostname

Canonicalizing the Hostname (www vs. non-www)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``www.example.com`` and ``example.com`` to resolve
to a single canonical URL, to avoid duplicate content in search engines.
This comes up frequently on the mailing list, often intertwined with the
HTTP-to-HTTPS redirect question.

**Approach:** Separate ``<VirtualHost>`` blocks (preferred), or
:module:`mod_rewrite` with ``RewriteCond %{HTTP_HOST}``

As noted in the "redirect vs. rewrite" thread on the httpd users list,
the recommended approach from experienced responders is to use separate
virtual hosts for hostname canonicalization, rather than ``RewriteCond``.
This keeps the configuration clearer and avoids accidental interactions
with other rewrite rules.

The cleanest approach uses separate ``<VirtualHost>`` blocks — one canonical,
one that redirects:

.. code-block:: apache

   # Redirect non-www to www
   <VirtualHost *:443>
       ServerName example.com
       SSLEngine on
       SSLCertificateFile    /etc/pki/tls/certs/example.com.crt
       SSLCertificateKeyFile /etc/pki/tls/private/example.com.key
       Redirect permanent / https://www.example.com/
   </VirtualHost>

   # Canonical host
   <VirtualHost *:443>
       ServerName www.example.com
       SSLEngine on
       SSLCertificateFile    /etc/pki/tls/certs/example.com.crt
       SSLCertificateKeyFile /etc/pki/tls/private/example.com.key
       DocumentRoot /var/www/html
   </VirtualHost>

To redirect in the *other* direction (www → non-www), swap the
``ServerName`` values.

The separate-VirtualHost approach is preferred because:

- It makes the intent obvious to anyone reading the config.
- The redirect VirtualHost contains no ``DocumentRoot``, no rewrite
  rules, and no application config — just a single ``Redirect``.
- There's no risk of rewrite-rule interactions.

If you can't use separate virtual hosts (e.g., you're in :file:`.htaccess`),
use ``RewriteCond``:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_HOST} !^www\. [NC]
   RewriteRule ^ https://www.%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

.. note::

   The ``[NC]`` (no-case) flag handles mixed-case hostnames. Without it,
   ``Example.COM`` would not match.

To combine hostname canonicalization with the HTTPS redirect, put them
in order — the HTTPS redirect first, then the hostname redirect:

.. code-block:: apache

   # In .htaccess or a single VirtualHost:
   RewriteEngine On

   # Step 1: Force HTTPS
   RewriteCond %{HTTPS} off
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

   # Step 2: Force www
   RewriteCond %{HTTP_HOST} !^www\. [NC]
   RewriteRule ^ https://www.%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

This results in at most two redirects for ``http://example.com/page``:
first to ``https://example.com/page``, then to
``https://www.example.com/page``. If you want a single redirect, combine
the conditions in the VirtualHost approach — the port-80 redirect points
directly to the canonical ``https://www.`` URL.


.. index:: pair: recipes; trailing slash redirect
.. index:: pair: recipes; DirectorySlash

Adding or Removing Trailing Slashes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want consistent URLs---either always with a trailing
slash or always without. :module:`mod_dir`'s ``DirectorySlash`` directive
interacts with this in ways that confuse many users.

**Approach:** :module:`mod_dir` / ``DirectorySlash``, or :module:`mod_rewrite`

A mailing list thread on "Limiting redirects with rewriterule/rewritecond"
discusses combining trailing-slash removal with other rewrites to reduce
the number of redirects a client experiences. One respondent notes:
"be careful about not creating loops, especially if using .htaccess files."

**Adding a trailing slash** is the default behavior of :module:`mod_dir`. When
a request for ``/about`` matches a directory on disk, :module:`mod_dir`
automatically redirects to ``/about/``. The ``DirectorySlash`` directive
controls this:

.. code-block:: apache

   # Default behavior — adds trailing slash to directories
   DirectorySlash On

If you want to *enforce* trailing slashes on all URLs (not just
directories), use :module:`mod_rewrite`:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_URI} !(.*)/$
   RewriteRule ^(.*)$ /$1/ [R=301,L]

The ``!-f`` condition prevents adding a slash to actual files (you
don't want ``/style.css/``).

**Removing trailing slashes** requires disabling ``DirectorySlash``
and handling it yourself:

.. code-block:: apache

   DirectorySlash Off

   RewriteEngine On
   # Remove trailing slash (except for root /)
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^(.+)/$ /$1 [R=301,L]

.. warning::

   Setting ``DirectorySlash Off`` means :module:`mod_dir` will no longer
   automatically redirect ``/about`` to ``/about/``, which can cause
   relative links within that directory to break. You must ensure your
   application generates absolute URLs or handles this itself.

**Avoiding redirect loops:** In :file:`.htaccess`, the URI is re-evaluated
after each internal rewrite. A rule that adds a slash can interact with
:module:`mod_dir`'s own slash-adding logic, creating a loop. The safest
pattern is:

.. code-block:: apache

   # In .htaccess — add slash without looping
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} -d
   RewriteCond %{REQUEST_URI} !/$
   RewriteRule ^ %{REQUEST_URI}/ [R=301,L]

The ``-d`` check ensures the rule only fires for actual directories,
and the ``!/$`` condition ensures it doesn't fire if the slash is
already present. See :ref:`Chapter 11 <Chapter_access>` for more
on avoiding loops.


.. index:: pair: recipes; domain migration
.. index:: pair: recipes; old domain to new domain

Redirecting an Entire Site to a New Domain
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You've moved your site to a new domain and want to redirect
all old URLs to the new domain, preserving the path. This comes up
frequently on the mailing list---a thread on "rewrite in .htaccess" shows
a user migrating a WordPress site who gets partial redirects because
their rewrite rules are in the wrong order.

**Approach:** ``Redirect`` (preferred for simple cases), or :module:`mod_rewrite`

The key mistake in the mailing list thread: placing the domain-migration
rewrite rules *after* the WordPress :file:`.htaccess` rules, which short-circuit
with ``[L]`` before the migration rules are reached.

The simplest approach is a single ``Redirect`` directive:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName old.example.com
       Redirect permanent / https://new.example.com/
   </VirtualHost>

This redirects every request while preserving the path.
``/blog/my-post?id=42`` becomes ``https://new.example.com/blog/my-post?id=42``.

The :module:`mod_rewrite` equivalent:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName old.example.com
       RewriteEngine On
       RewriteRule ^ https://new.example.com%{REQUEST_URI} [R=301,L]
   </VirtualHost>

Use the :module:`mod_rewrite` version when you need to add conditions — for
example, redirecting only certain paths or excluding an API endpoint
from the redirect.

**Rule ordering with CMS .htaccess files:** If you're migrating a
WordPress (or similar CMS) site, the CMS :file:`.htaccess` typically
contains:

.. code-block:: apache

   # WordPress default
   RewriteEngine On
   RewriteBase /
   RewriteRule ^index\.php$ - [L]
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.php [L]

If you add your domain-migration redirect *after* these rules, the
``[L]`` flag on the WordPress rules will stop processing before your
redirect is ever reached. Place domain-migration rules **before** any
CMS rules:

.. code-block:: apache

   # Domain migration — must come FIRST
   RewriteEngine On
   RewriteRule ^ https://new.example.com%{REQUEST_URI} [R=301,L]

   # WordPress rules below (never reached because of the [L] above)
   # ...

Better yet, put the ``Redirect`` in server config rather than
:file:`.htaccess` — it will be processed before any :file:`.htaccess` rules
are even loaded.


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

For a handful of redirects, use ``Redirect``:

.. code-block:: apache

   Redirect permanent /old-page.html /new-page.html
   Redirect permanent /blog/2019/post /archive/2019/post

For pattern-based redirects, use ``RedirectMatch``:

.. code-block:: apache

   # Redirect all /blog/YYYY/slug to /archive/YYYY/slug
   RedirectMatch permanent ^/blog/([0-9]{4})/(.+)$ /archive/$1/$2

For **large numbers** of redirects (hundreds or thousands), individual
``Redirect`` or ``RewriteRule`` directives become unwieldy and slow.
Use a ``RewriteMap`` instead:

.. code-block:: apache

   # In server config (not .htaccess — RewriteMap can't go there)
   RewriteMap redirects "txt:/etc/httpd/conf/redirect-map.txt"

   RewriteEngine On
   RewriteCond ${redirects:$1} !=""
   RewriteRule ^(.+)$ ${redirects:$1} [R=301,L]

The map file is a simple two-column text file:

.. code-block:: text

   # /etc/httpd/conf/redirect-map.txt
   /old-page.html  /new-page.html
   /blog/2019/post /archive/2019/post
   /products/widget /shop/widgets

For even better performance with thousands of entries, convert the text
map to DBM format using ``httxt2dbm``:

.. code-block:: bash

   httxt2dbm -i redirect-map.txt -o redirect-map.dbm

Then reference the DBM map:

.. code-block:: apache

   RewriteMap redirects "dbm:/etc/httpd/conf/redirect-map.dbm"

DBM lookups are O(1) hash-table lookups regardless of map size, while
a text file is scanned linearly. For 10,000+ redirects, the difference
is significant. See :ref:`Chapter 8 <Chapter_rewritemap>` for full
details on ``RewriteMap`` types.


.. index:: pair: recipes; wildcard subdomain redirect

Redirecting Wildcard Subdomains
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to redirect ``*.oldsite.com`` to ``newsite.com``,
possibly preserving certain allowed subdomains. A detailed thread on
"Apache Rewrite - Redirect Wildcard Subdomain" shows a user with complex
requirements: some wildcard subdomains should redirect to the base domain,
while others should be preserved on the new domain.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{HTTP_HOST}``

This requires :module:`mod_rewrite` because ``Redirect`` and ``RedirectMatch``
cannot match against the hostname. The key is getting the ``ServerAlias``
right (``*.oldsite.com``) and using ``RewriteCond`` to capture and
selectively route subdomain patterns.

First, ensure DNS is configured with a wildcard record
(``*.oldsite.com → your server IP``), and that your virtual host
accepts wildcard connections:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName  oldsite.com
       ServerAlias *.oldsite.com

       RewriteEngine On
       RewriteRule ^ https://newsite.com%{REQUEST_URI} [R=301,L]
   </VirtualHost>

This redirects every subdomain (``blog.oldsite.com``, ``shop.oldsite.com``,
etc.) to the base domain ``newsite.com``, preserving the path.

**Preserving the subdomain** on the new domain requires capturing it from
the ``Host`` header:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName  oldsite.com
       ServerAlias *.oldsite.com

       RewriteEngine On
       RewriteCond %{HTTP_HOST} ^(.+)\.oldsite\.com$ [NC]
       RewriteRule ^ https://%1.newsite.com%{REQUEST_URI} [R=301,L]
   </VirtualHost>

Here ``%1`` is the first capture group from the ``RewriteCond`` — the
subdomain portion.

**Selective handling** — redirect most subdomains but keep a few:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName  oldsite.com
       ServerAlias *.oldsite.com

       RewriteEngine On
       # Don't redirect mail or api subdomains
       RewriteCond %{HTTP_HOST} !^(mail|api)\.oldsite\.com$ [NC]
       RewriteCond %{HTTP_HOST} ^(.+)\.oldsite\.com$ [NC]
       RewriteRule ^ https://%1.newsite.com%{REQUEST_URI} [R=301,L]
   </VirtualHost>

The first ``RewriteCond`` excludes ``mail`` and ``api``; the second
captures the subdomain for redirection. Because multiple
``RewriteCond`` lines before a single ``RewriteRule`` are ANDed by
default, both conditions must be true for the rule to fire.


Clean and Pretty URLs
---------------------

Making URLs user-friendly and hiding implementation details.


.. index:: pair: recipes; remove file extension
.. index:: pair: recipes; extensionless URLs

Removing File Extensions (.php, .html)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``/about`` to serve :file:`/about.php` without the user
seeing the ``.php`` extension. A thread on "Remove .php extension but
still pass it to PHP-FPM" shows this is especially tricky when PHP-FPM is
in the mix, because the proxy handler needs to know the actual file path.

**Approach:** :module:`mod_rewrite` (with ``-f`` check), or ``MultiViews``
(content negotiation)

``MultiViews`` (enabled via ``Options +MultiViews``) can handle this
without any rewrite rules at all, but its behavior can be surprising and
it has performance implications. The :module:`mod_rewrite` approach gives more
control.

**MultiViews (simplest):** Enable content negotiation, and Apache will
automatically serve :file:`/about.php` when the client requests ``/about``:

.. code-block:: apache

   <Directory /var/www/html>
       Options +MultiViews
   </Directory>

That's it — no rewrite rules needed. Apache looks for files matching the
requested path with any known extension and serves the best match.

.. note::

   ``MultiViews`` can produce unexpected results if you have both
   :file:`about.html` and :file:`about.php` — Apache will choose based on content
   negotiation headers. It also adds a small overhead because Apache
   must scan the directory for matching files on every request.

**:module:`mod_rewrite` approach (more control):**

.. code-block:: apache

   RewriteEngine On

   # If the request doesn't match an existing file or directory
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d

   # And the request with .php appended IS a real file
   RewriteCond %{REQUEST_FILENAME}.php -f
   RewriteRule ^(.+)$ $1.php [L]

The ``-f`` checks are essential. Without the final ``RewriteCond``, a
request for ``/nonexistent`` would be rewritten to :file:`/nonexistent.php`,
which also doesn't exist, producing a confusing 404.

**PHP-FPM / ProxyPassMatch consideration:** When PHP is handled by
PHP-FPM via ``ProxyPassMatch``, the proxy handler needs the ``.php``
extension to know which requests to forward:

.. code-block:: apache

   # Typical PHP-FPM proxy config
   ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:9000/var/www/html/$1

   # Extensionless rewrite (in .htaccess or <Directory>)
   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteCond %{REQUEST_FILENAME}.php -f
   RewriteRule ^(.+)$ $1.php [L]

The rewrite appends ``.php`` internally, and then ``ProxyPassMatch``
matches the ``.php`` extension and forwards to PHP-FPM. The order
matters: the rewrite happens first (in ``<Directory>`` context), then
the proxy match is evaluated against the rewritten URI.


.. index:: pair: recipes; path-based routing
.. index:: pair: recipes; front controller

Front Controller Pattern (CMS/Framework Routing)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your application framework (WordPress, Laravel, Symfony,
etc.) uses a front controller pattern where all requests that don't match
a real file should be routed to :file:`index.php`. This is the single most
common :file:`.htaccess` configuration on the web, and it generates a steady
stream of mailing list questions when it doesn't work.

**Approach:** :module:`mod_rewrite` in :file:`.htaccess`

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
with the :file:`.htaccess` rewrite rules in an unexpected way, causing the
rewrite to loop infinitely.

Here is the standard pattern, annotated line by line:

.. code-block:: apache

   # Enable the rewrite engine
   RewriteEngine On

   # Set the base URL for relative substitutions in .htaccess.
   # If your site lives at /blog/, change this to /blog/.
   RewriteBase /

   # If the request is literally for index.php, stop here.
   # The [L] flag means "last rule" — don't process further.
   # The - substitution means "don't rewrite, pass through."
   RewriteRule ^index\.php$ - [L]

   # If the requested file exists on disk, don't rewrite.
   RewriteCond %{REQUEST_FILENAME} !-f

   # If the requested directory exists on disk, don't rewrite.
   RewriteCond %{REQUEST_FILENAME} !-d

   # Everything else: rewrite to index.php.
   # The "." pattern matches any non-empty URI.
   RewriteRule . /index.php [L]

**Why the ``^index\.php$`` rule?** Without it, the rewrite creates a
loop. After the last ``RewriteRule`` rewrites to :file:`/index.php`, the
:file:`.htaccess` is re-evaluated against the *new* URI. The first rule
matches :file:`index.php` and stops, breaking the loop.

**What breaks when ``AllowOverride`` is wrong:** If the server config has
``AllowOverride None`` (the default in many distributions), :file:`.htaccess`
files are completely ignored — no errors, no log entries, nothing. The
fix:

.. code-block:: apache

   <Directory /var/www/html>
       AllowOverride FileInfo
   </Directory>

``FileInfo`` is the minimum needed for ``RewriteRule`` directives.
``AllowOverride All`` also works but grants more than necessary.

**What breaks when ``RewriteBase`` is missing:** In :file:`.htaccess`,
:module:`mod_rewrite` strips the directory prefix from the URI before matching,
then prepends it back after substitution. ``RewriteBase`` tells it what
to prepend. If omitted and the site is in a subdirectory, rewrites
produce incorrect paths. For a site at ``http://example.com/blog/``,
you need ``RewriteBase /blog/``.

**The PHP-FPM loop interaction:** When PHP runs via ``ProxyPassMatch``:

.. code-block:: apache

   ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:9000/var/www/html/$1

A request for ``/my-page`` gets rewritten to :file:`/index.php` by the
:file:`.htaccess` rules, then ``ProxyPassMatch`` forwards it to PHP-FPM.
PHP-FPM processes it and returns a response. The loop occurs if
``ProxyPassMatch`` triggers a *subrequest* that re-enters :file:`.htaccess`
processing. In httpd 2.4.51+, the ``PT`` (passthrough) flag behavior
changed slightly, which can trigger this. The fix: use ``SetHandler``
instead of ``ProxyPassMatch``:

.. code-block:: apache

   <FilesMatch "\.php$">
       SetHandler "proxy:fcgi://127.0.0.1:9000"
   </FilesMatch>

``SetHandler`` avoids the regex-matching path entirely and doesn't
trigger rewrite re-entry.


.. index:: pair: recipes; clean URLs
.. index:: pair: recipes; path to query string

Mapping Clean URL Paths to Query Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want ``/products/widget-42`` to internally map to
``/product.php?id=widget-42``. This is a classic :module:`mod_rewrite` use case
and appears in many mailing list threads. A common mistake (seen in
"RewriteRule not working, 404 error obtained") is that ``AllowOverride``
is not set correctly, so the :file:`.htaccess` rules are silently ignored.

**Approach:** :module:`mod_rewrite`

**Simple one-segment mapping** — ``/products/shoes`` to
``/products.php?cat=shoes``:

.. code-block:: apache

   RewriteEngine On
   RewriteRule ^products/([a-zA-Z0-9_-]+)$ /products.php?cat=$1 [L]

The ``$1`` backreference captures whatever matched inside the
parentheses. See :ref:`Chapter 1 <Chapter_regex>` for regex details.

**Multi-segment paths** — ``/products/shoes/running`` to
``/products.php?cat=shoes&sub=running``:

.. code-block:: apache

   RewriteRule ^products/([^/]+)/([^/]+)$ /products.php?cat=$1&sub=$2 [L]

**With optional segments** — ``/products/shoes`` or
``/products/shoes/running``:

.. code-block:: apache

   RewriteRule ^products/([^/]+)(/([^/]+))?$ /products.php?cat=$1&sub=$3 [L]

If the second segment is absent, ``$3`` is empty and the query parameter
``sub=`` has no value, which the application should handle.

**The ``AllowOverride`` pitfall:** If these rules are in :file:`.htaccess`
and ``AllowOverride`` does not include ``FileInfo``, the rules are
silently ignored. There's no error message, no log entry — the
:file:`.htaccess` file simply has no effect. Enable tracing to confirm
rules are being processed:

.. code-block:: apache

   # In server config
   <Directory /var/www/html>
       AllowOverride FileInfo
   </Directory>

   # Temporarily enable rewrite logging
   LogLevel alert rewrite:trace3

If you see no rewrite log entries at all for a request that should match
your :file:`.htaccess` rules, ``AllowOverride`` is the likely culprit.

.. tip::

   These patterns assume :module:`mod_rewrite` in :file:`.htaccess`. In server
   config (``<VirtualHost>`` or ``<Directory>``), the URI includes the
   leading slash, so the pattern becomes ``^/products/([^/]+)$``. See
   :ref:`Chapter 11 <Chapter_access>` for the full list of
   context differences.


Access Control
--------------

Using URL manipulation for access control purposes. (Note: :module:`mod_rewrite`
is generally *not* the best tool for access control---``Require``,
``<If>``, and ``mod_authz_*`` are usually better choices.)


.. index:: pair: recipes; block by referrer
.. index:: pair: recipes; hotlink protection

Blocking Hotlinking (Referrer-Based Access)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Other sites are embedding your images directly, consuming
your bandwidth. You want to block or redirect requests that come from
other domains.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{HTTP_REFERER}``
(traditional), or ``<If>`` expression (modern, preferred)

**:module:`mod_rewrite` approach** (traditional):

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_REFERER} !^$ [NC]
   RewriteCond %{HTTP_REFERER} !^https?://(www\.)?example\.com [NC]
   RewriteRule \.(jpg|jpeg|png|gif|webp|svg)$ - [F]

Line by line:

1. ``!^$`` — allow empty referrers (direct visits, bookmarks, privacy
   extensions). Without this, your own users following bookmarks would
   be blocked.
2. ``!^https?://(www\.)?example\.com`` — allow requests from your own
   domain.
3. The ``RewriteRule`` matches image extensions and returns 403 Forbidden
   (``[F]``).

To serve a placeholder image instead of a 403:

.. code-block:: apache

   RewriteRule \.(jpg|jpeg|png|gif|webp|svg)$ /images/hotlink-notice.png [L]

**SetEnvIf + Require approach** (modern, preferred):

.. code-block:: apache

   SetEnvIf Referer "^$" local_ref
   SetEnvIf Referer "^https?://(www\.)?example\.com" local_ref

   <FilesMatch "\.(jpg|jpeg|png|gif|webp|svg)$">
       Require env local_ref
   </FilesMatch>

This approach is cleaner — the access control logic lives in the
authorization layer where it belongs, not in URL rewriting.

.. warning::

   The ``Referer`` header is trivially spoofed and frequently absent.
   Privacy-focused browsers, extensions, and corporate proxies strip it.
   Hotlink protection is a deterrent, not a security boundary. Don't use
   it to protect genuinely sensitive content — use authentication instead.


.. index:: pair: recipes; block by user agent
.. index:: pair: recipes; bot blocking

Blocking Requests by User-Agent
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to block specific bots, scrapers, or vulnerability
scanners based on their User-Agent string. Several mailing list threads
discuss this in the context of "Unknown accepted traffic" and bot
mitigation.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{HTTP_USER_AGENT}``
(traditional), or ``<If>`` / ``SetEnvIf`` with ``Require`` (modern,
preferred)

**SetEnvIf + Require approach** (recommended):

.. code-block:: none

   SetEnvIf User-Agent "BadBot" bad_bot
   SetEnvIf User-Agent "EvilScraper" bad_bot
   SetEnvIf User-Agent "VulnScanner" bad_bot

   <Directory /var/www/html>
       <If "reqenv('bad_bot') != ''">
           Require all denied
       </If>
   </Directory>

Or more concisely with ``Require``:

.. code-block:: apache

   SetEnvIf User-Agent "BadBot|EvilScraper|VulnScanner" bad_bot

   <Directory /var/www/html>
       Require not env bad_bot
   </Directory>

**:module:`mod_rewrite` approach** (traditional):

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_USER_AGENT} (BadBot|EvilScraper|VulnScanner) [NC]
   RewriteRule ^ - [F]

The ``SetEnvIf`` approach is preferred because:

- It separates *identification* (``SetEnvIf``) from *authorization*
  (``Require``), making the config easier to read and maintain.
- The ``Require`` directive integrates with httpd's authorization
  framework, producing proper 403 responses with correct logging.
- :module:`mod_rewrite`'s ``[F]`` flag works, but using the rewrite engine for
  access control is using the wrong tool for the job.

.. note::

   User-Agent strings are trivially spoofed. Any bot that wants to
   evade detection can send a browser-like User-Agent. This technique
   is useful against lazy bots and automated scanners but is not
   a substitute for rate limiting or WAF rules.


.. index:: pair: recipes; cookie-based access
.. index:: pair: recipes; authentication redirect

Cookie-Based Redirect to Login Page
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to redirect users to a login page if a specific
authentication cookie is not present. A thread on "redirects on Apache
2.4" shows a user trying to check for a ``web_route`` cookie and redirect
unauthenticated users to a login portal.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{HTTP_COOKIE}``

The common mistake from the mailing list: the rewrite rules are in the
wrong order, and the ``[L]`` flag on the front controller rule prevents
the cookie check from ever being evaluated.

Check for the absence of an authentication cookie and redirect:

.. code-block:: apache

   RewriteEngine On

   # Don't redirect the login page itself (avoid loop)
   RewriteCond %{REQUEST_URI} !^/login
   # Don't redirect static assets
   RewriteCond %{REQUEST_URI} !^/(css|js|images)/

   # Check if the auth cookie is missing
   RewriteCond %{HTTP_COOKIE} !auth_token=
   RewriteRule ^ /login?redirect=%{REQUEST_URI} [R=302,L]

Key points:

- The ``!^/login`` exclusion prevents a redirect loop — without it,
  the login page itself would trigger another redirect.
- Static asset exclusions prevent CSS and images from being inaccessible
  on the login page.
- Use ``[R=302]`` (temporary), not ``[R=301]`` (permanent). A permanent
  redirect gets cached by the browser, so even after the user logs in
  and obtains the cookie, the browser may still redirect to ``/login``.
- The ``%{REQUEST_URI}`` in the query string passes the original URL to
  the login handler, enabling redirect-after-login.

**Rule ordering matters.** If you combine this with a front controller
pattern, the cookie check must come *before* the front controller rules:

.. code-block:: apache

   RewriteEngine On

   # 1. Cookie check (redirect to login)
   RewriteCond %{REQUEST_URI} !^/login
   RewriteCond %{REQUEST_URI} !^/(css|js|images)/
   RewriteCond %{HTTP_COOKIE} !auth_token=
   RewriteRule ^ /login?redirect=%{REQUEST_URI} [R=302,L]

   # 2. Front controller (send everything else to index.php)
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.php [L]

If the front controller rules come first, their ``[L]`` flag stops
processing and the cookie check never runs.

.. tip::

   This pattern is a lightweight guard, not a security mechanism. The
   cookie can be forged, and the check runs on every request. For real
   authentication, use :module:`mod_auth_form` (httpd's built-in form-based
   auth), :module:`mod_auth_openidc` (for OAuth2/OIDC), or handle
   authentication in your application or reverse proxy layer.


.. index:: pair: recipes; IP-based access control
.. index:: pair: recipes; block by IP

IP-Based Access Control
~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to restrict access to certain paths based on client
IP address.

**Approach:** ``Require ip`` (strongly preferred), ``<If>`` expressions,
or :module:`mod_rewrite` with ``RewriteCond %{REMOTE_ADDR}`` (not recommended)

**Require ip** (strongly preferred):

.. code-block:: apache

   <Location /admin>
       Require ip 10.0.0.0/8
       Require ip 192.168.1.0/24
       Require ip 2001:db8::/32
   </Location>

To allow a specific IP *and* deny everything else:

.. code-block:: apache

   <Location /admin>
       Require ip 10.1.2.3
   </Location>

To combine IP restrictions with authentication (require *both*):

.. code-block:: apache

   <Location /admin>
       <RequireAll>
           Require ip 10.0.0.0/8
           Require valid-user
       </RequireAll>
   </Location>

**<If> expression approach:**

.. code-block:: none

   <If "%{REMOTE_ADDR} -ipmatch '10.0.0.0/8'">
       # Allowed
   </If>
   <Else>
       Require all denied
   </Else>

**:module:`mod_rewrite` approach** (do not use for this):

.. code-block:: apache

   # This works, but don't do it
   RewriteEngine On
   RewriteCond %{REMOTE_ADDR} !^10\.
   RewriteRule ^/admin - [F]

This is worse than ``Require ip`` in every way:

- The regex ``!^10\.`` is an approximation of ``10.0.0.0/8`` — it
  doesn't actually do CIDR matching, so it's easy to get wrong.
- It bypasses the authorization framework, so ``Require`` directives
  in the same scope may not behave as expected.
- It doesn't log the denial through the standard authorization log.
- It doesn't support IPv6 CIDR notation.

Use ``Require ip``. It exists precisely for this purpose, handles CIDR
correctly for both IPv4 and IPv6, integrates with the authorization
framework, and is far easier to read and audit.


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
":module:`mod_proxy_http` rewrite problem" shows a user struggling with balancer
configuration where the rewrite rule incorrectly strips the application
context path, causing authentication to break.

**Approach:** ``ProxyPass`` path mapping (preferred), or :module:`mod_rewrite`
with ``[P]`` flag

The recommended approach is to let ``ProxyPass`` and ``ProxyPassReverse``
handle the path mapping. Using :module:`mod_rewrite` with ``[P]`` should be a
last resort, because it bypasses the connection pooling and other
optimizations of :module:`mod_proxy`.

**ProxyPass path mapping** (preferred):

.. code-block:: apache

   # Forward /app/ to a backend running on port 8080 at /
   ProxyPass        /app/ http://backend.local:8080/
   ProxyPassReverse /app/ http://backend.local:8080/

``ProxyPass`` maps the incoming path to the backend path.
``ProxyPassReverse`` rewrites ``Location`` headers in the backend's
responses so that redirects issued by the backend (e.g.,
``Location: http://backend.local:8080/login``) are translated back to
the client-facing URL (``/app/login``).

**Stripping a prefix:**

.. code-block:: apache

   # Client requests /api/v2/users
   # Backend expects  /v2/users (no /api prefix)
   ProxyPass        /api/ http://backend.local:8080/
   ProxyPassReverse /api/ http://backend.local:8080/

The path mapping in ``ProxyPass`` handles the prefix stripping
automatically — ``/api/v2/users`` becomes ``/v2/users`` on the backend.

**:module:`mod_rewrite` with [P] flag** (last resort):

.. code-block:: apache

   RewriteEngine On
   RewriteRule ^/app/(.*)$ http://backend.local:8080/$1 [P]
   ProxyPassReverse /app/ http://backend.local:8080/

.. warning::

   The ``[P]`` flag forces the request through :module:`mod_proxy`, but it
   **bypasses** ``ProxyPass``'s connection pooling and worker
   configuration. Each ``[P]`` request creates a new connection to the
   backend. For high-traffic sites, this is significantly less efficient.

   You still need ``ProxyPassReverse`` even when using ``[P]`` — the
   flag handles the *request* path but not the *response* headers.

**Do not mix ProxyPass and RewriteRule [P]** for the same path:

.. code-block:: apache

   # WRONG — these will conflict
   ProxyPass /app/ http://backend.local:8080/
   RewriteRule ^/app/special/(.*)$ http://other-backend:8080/$1 [P]

``ProxyPass`` is processed before ``RewriteRule`` in most contexts,
so the rewrite rule may never be reached. If you need conditional
proxying, use ``RewriteRule [P]`` for *all* paths in that scope, or use
``ProxyPass`` with ``<Location>`` blocks and ``<If>`` conditions.


.. index:: pair: recipes; TLS termination proxy
.. index:: pair: recipes; X-Forwarded-Proto

Redirects Behind a TLS-Terminating Proxy
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your httpd sits behind a load balancer or CDN that terminates
TLS. The ``%{HTTPS}`` variable is always ``off`` from httpd's perspective,
causing redirect loops when you try to force HTTPS. A thread on
"Configuring redirects httpd behind a TLS-terminating proxy" discusses
this exact scenario.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{HTTP:X-Forwarded-Proto}``
or ``<If>`` with ``req('X-Forwarded-Proto')``

When httpd sits behind a load balancer or CDN that terminates TLS, the
connection between the proxy and httpd is plain HTTP. From httpd's
perspective, ``%{HTTPS}`` is always ``off``. The standard "force HTTPS"
redirect creates an infinite loop:

.. code-block:: apache

   # This loops behind a TLS-terminating proxy!
   RewriteCond %{HTTPS} off
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

The fix: check the ``X-Forwarded-Proto`` header set by the proxy instead:

.. code-block:: none

   RewriteEngine On
   RewriteCond %{HTTP:X-Forwarded-Proto} =http
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

Or with an ``<If>`` expression (cleaner):

.. code-block:: none

   <If "req('X-Forwarded-Proto') == 'http'">
       Redirect permanent / https://www.example.com/
   </If>

**Using :module:`mod_remoteip`** to make ``%{HTTPS}`` work correctly:

:module:`mod_remoteip` can be configured to trust the proxy's forwarded
headers, allowing the standard ``%{HTTPS}`` variable to reflect the
client's actual connection:

.. code-block:: apache

   # Trust the proxy at 10.0.0.0/8
   RemoteIPHeader X-Forwarded-For
   RemoteIPTrustedProxy 10.0.0.0/8

Note that :module:`mod_remoteip` handles the client IP (``X-Forwarded-For``),
not the protocol. For protocol detection, you still need to check
``X-Forwarded-Proto`` explicitly. Some setups use
``RequestHeader set X-Forwarded-Proto "https"`` on the proxy side and
then check it on the httpd side.

.. warning::

   Only trust ``X-Forwarded-Proto`` from known proxies. If a client
   sends this header directly (bypassing the proxy), they can trick
   httpd into thinking the connection is secure. Use firewall rules
   or ``<If>`` conditions to ensure only your proxy can set this header.


.. index:: pair: recipes; WebSocket proxy
.. index:: pair: recipes; wss proxy

WebSocket Proxying
~~~~~~~~~~~~~~~~~~

**Problem:** Your application uses WebSockets and you need to proxy
``ws://`` or ``wss://`` traffic through httpd. A recurring thread on
"Web sockets & proxypass - No protocol handler was valid for the URL"
shows users struggling to get :module:`mod_proxy_wstunnel` working.

**Approach:** :module:`mod_proxy_wstunnel` with ``ProxyPass``, sometimes
combined with :module:`mod_rewrite` for upgrade detection

**Basic WebSocket proxy with :module:`mod_proxy_wstunnel`:**

.. code-block:: apache

   # Enable required modules
   LoadModule proxy_module        modules/mod_proxy.so
   LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so

   # Proxy WebSocket connections at /ws/ to the backend
   ProxyPass        /ws/ ws://backend.local:8080/ws/
   ProxyPassReverse /ws/ ws://backend.local:8080/ws/

For secure WebSockets (``wss://``), the TLS termination happens at httpd;
the backend connection can remain plain ``ws://``:

.. code-block:: apache

   <VirtualHost *:443>
       SSLEngine on
       # ... SSL config ...

       # Client connects via wss://, httpd proxies as ws://
       ProxyPass        /ws/ ws://backend.local:8080/ws/
       ProxyPassReverse /ws/ ws://backend.local:8080/ws/
   </VirtualHost>

**Upgrade detection with :module:`mod_rewrite`** — for applications where the same
URL handles both HTTP and WebSocket (e.g., Socket.IO):

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP:Upgrade} websocket [NC]
   RewriteRule ^/app/(.*)$ ws://backend.local:8080/$1 [P,L]

   # Non-WebSocket requests go through normal HTTP proxy
   ProxyPass        /app/ http://backend.local:8080/
   ProxyPassReverse /app/ http://backend.local:8080/

The ``RewriteCond`` checks for the ``Upgrade: websocket`` header that
initiates the WebSocket handshake. Only those requests are routed to the
``ws://`` backend; everything else goes through the normal ``ProxyPass``.

**Common pitfalls:**

1. **"No protocol handler was valid for the URL"** — :module:`mod_proxy_wstunnel`
   is not loaded. Add ``LoadModule proxy_wstunnel_module``.
2. **Timeout disconnects** — WebSocket connections are long-lived. Set
   a higher timeout:

   .. code-block:: apache

      ProxyTimeout 600
      ProxyPass /ws/ ws://backend.local:8080/ws/ timeout=600

3. **httpd 2.4.47+** added ``ProxyWebsocketFallbackToProxyHttp`` which
   allows :module:`mod_proxy_http` to handle WebSocket upgrades directly,
   without :module:`mod_proxy_wstunnel`. If you're on a recent version:

   .. code-block:: apache

      ProxyPass /ws/ http://backend.local:8080/ws/ upgrade=websocket

   The ``upgrade=websocket`` parameter tells :module:`mod_proxy_http` to
   handle the ``Upgrade`` header and tunnel the connection.


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

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{QUERY_STRING}`` and
``[QSA]`` or ``[QSD]`` flags

The solution from the mailing list: the original ``RewriteRule ^(.*)$``
pattern was matching the redirect *target* as well, causing an infinite
loop. Changing to ``^/$`` (matching only the root) fixed the loop.

``RewriteRule`` matches only the URL path---it never sees the query
string. To match or capture query string parameters, use
``RewriteCond %{QUERY_STRING}``:

.. code-block:: apache

   # Redirect /?code=ABC123 to /welcome?track=ABC123
   RewriteEngine On
   RewriteCond %{QUERY_STRING} ^code=([a-zA-Z0-9]+)$
   RewriteRule ^/?$ /welcome?track=%1 [R=301,L]

Here ``%1`` is a backreference to the first capture group in the
``RewriteCond`` pattern (not ``$1``, which refers to the ``RewriteRule``
pattern). See :ref:`Chapter 1 <Chapter_regex>` for the full
backreference syntax.

**The** ``[QSA]`` **flag** (Query String Append): by default, if the
``RewriteRule`` substitution contains a query string, it *replaces* the
original. ``[QSA]`` appends the original query string to the new one
instead:

.. code-block:: apache

   # /products/widget?color=red
   # Without QSA -> /catalog.php?item=widget  (color=red is lost)
   # With QSA    -> /catalog.php?item=widget&color=red

   RewriteRule ^/products/(.+)$ /catalog.php?item=$1 [QSA,L]

**The** ``[QSD]`` **flag** (Query String Discard): removes the query
string entirely from the rewritten URL. See the next recipe for details.

**Avoiding redirect loops with query strings:** The most common loop
occurs when the ``RewriteRule`` pattern is too broad:

.. code-block:: apache

   # BUG: ^(.*)$ matches /welcome too, causing a loop
   RewriteCond %{QUERY_STRING} ^code=(.+)$
   RewriteRule ^(.*)$ /welcome?track=%1 [R=301,L]

   # FIX: match only the specific source URL
   RewriteCond %{QUERY_STRING} ^code=(.+)$
   RewriteRule ^/?$ /welcome?track=%1 [R=301,L]

Another anti-loop technique is to add a condition that checks whether the
rewrite has already happened:

.. code-block:: apache

   RewriteCond %{QUERY_STRING} ^code=(.+)$
   RewriteCond %{QUERY_STRING} !track=     # don't re-rewrite
   RewriteRule ^/?$ /welcome?track=%1 [R=301,L]


.. index:: pair: recipes; strip query string
.. index:: pair: recipes; remove query string

Stripping Query Strings
~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to remove query strings from URLs, either for
SEO cleanliness or to prevent parameter injection, but you need to
preserve query strings on certain specific URLs. A thread on
"Stripping query string except from specific URL" shows this exact use
case.

**Approach:** :module:`mod_rewrite` with ``[QSD]`` flag and ``RewriteCond``
exceptions

**Blanket query string removal** with ``[QSD]`` (Query String Discard,
available since httpd 2.4.0):

.. code-block:: apache

   # Strip query strings from all requests
   RewriteEngine On
   RewriteCond %{QUERY_STRING} .
   RewriteRule ^ %{REQUEST_URI} [QSD,R=301,L]

The ``RewriteCond`` ensures this only fires when a query string is
actually present, avoiding a redirect loop on requests that already
have no query string.

**Excluding specific paths** from query string stripping:

.. code-block:: apache

   RewriteEngine On
   # Don't strip query strings from the search page or API
   RewriteCond %{REQUEST_URI} !^/search
   RewriteCond %{REQUEST_URI} !^/api/
   RewriteCond %{QUERY_STRING} .
   RewriteRule ^ %{REQUEST_URI} [QSD,R=301,L]

**The pre-2.4 method** (the trailing ``?`` trick): Before ``[QSD]``
existed, you discarded the query string by appending a bare ``?`` to
the substitution target:

.. code-block:: apache

   # Old method: trailing ? discards the original query string
   RewriteRule ^/old-page$ /new-page? [R=301,L]

This works because the ``?`` starts a new (empty) query string,
replacing the original. It still works in 2.4+, but ``[QSD]`` is
clearer about intent:

.. code-block:: apache

   # Equivalent, but more readable
   RewriteRule ^/old-page$ /new-page [QSD,R=301,L]

**Stripping only specific parameters** (keeping the rest):

.. code-block:: apache

   # Remove the 'fbclid' tracking parameter, keep everything else
   RewriteEngine On
   RewriteCond %{QUERY_STRING} ^(.*)(?:^|&)fbclid=[^&]*(.*)$
   RewriteRule ^ %{REQUEST_URI}?%1%2 [R=301,L]

This is fiddly regex work. For stripping multiple tracking parameters
(``utm_*``, ``fbclid``, ``gclid``), consider whether a
``RewriteMap prg:`` script would be more maintainable than a wall of
regex.


.. index:: pair: recipes; SetEnvIf query string

Using SetEnvIf with Query Strings
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to set environment variables or control logging
based on query string parameters. A thread on "Using SetEnvIf for query
string" shows a user trying to conditionally set environment variables.

**Approach:** ``SetEnvIf`` with ``QUERY_STRING`` variable, or
:module:`mod_rewrite` with ``[E=VAR:value]`` flag

**SetEnvIf** can match against ``Query_String`` (note the underscore)
to set environment variables without involving :module:`mod_rewrite` at all:

.. code-block:: apache

   # Set an environment variable when a debug parameter is present
   SetEnvIf Query_String "debug=true" IS_DEBUG

   # Suppress logging for health-check requests with ?ping
   SetEnvIf Query_String "^ping$" no_log

   # Use the no_log variable to exclude from access log
   CustomLog /var/log/httpd/access_log combined env=!no_log

**Conditional cache headers based on query string:**

.. code-block:: apache

   # Don't cache URLs with a session ID in the query string
   SetEnvIf Query_String "sid=" NO_CACHE
   Header set Cache-Control "no-store" env=NO_CACHE

**:module:`mod_rewrite`** ``[E=]`` **flag** --- set environment variables during
rewrite processing:

.. code-block:: apache

   # Tag requests with a tracking parameter
   RewriteEngine On
   RewriteCond %{QUERY_STRING} utm_source=([^&]+)
   RewriteRule ^ - [E=TRACKING_SOURCE:%1]

   # Use the variable in a log format
   # In server config:
   LogFormat "%h %l %u %t \"%r\" %>s %b \"%{TRACKING_SOURCE}e\"" tracking
   CustomLog /var/log/httpd/tracking.log tracking env=TRACKING_SOURCE

The ``-`` target means "don't rewrite the URL"---just set the variable
and move on.

.. note::

   In :file:`.htaccess` context, environment variables set by ``[E=]`` are
   prefixed with ``REDIRECT_`` after the rewrite completes. So
   ``TRACKING_SOURCE`` becomes ``REDIRECT_TRACKING_SOURCE``. This catches
   many people off guard. To access it in later directives, use
   ``%{ENV:REDIRECT_TRACKING_SOURCE}`` or set it with ``SetEnv`` to copy
   it to a non-prefixed name.

**When to use which:** Use ``SetEnvIf`` when you just need to set a
variable based on a simple pattern match---it's faster and clearer. Use
``[E=]`` when you're already writing rewrite rules and need to capture
part of the query string into a variable using backreferences.


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

**Step 1: Enable the rewrite log.**

.. code-block:: apache

   LogLevel warn rewrite:trace3

Reproduce the "too many redirects" error and examine the error log.
You'll see the rewrite engine processing the same URI repeatedly.

**Step 2: Identify the looping rule.**

Look for a pattern like this in the log::

   rewrite 'welcome' -> '/index.php'
   rewrite 'index.php' -> '/index.php'
   rewrite 'index.php' -> '/index.php'
   ...

The repeated line tells you which rule is firing in a loop and what it's
matching.

**Step 3: Fix it.** The cause is almost always one of these patterns:

**Pattern A --- Overly broad rule matching its own target:**

.. code-block:: apache

   # BUG: ^(.*)$ matches everything, including /welcome itself
   RewriteRule ^(.*)$ /welcome [R=301,L]
   # Request for /about -> 301 /welcome -> 301 /welcome -> loop!

   # FIX: add a condition to exclude the target
   RewriteCond %{REQUEST_URI} !^/welcome$
   RewriteRule ^(.*)$ /welcome [R=301,L]

**Pattern B --- .htaccess re-processing after rewrite:**

.. code-block:: apache

   # BUG: in .htaccess, [L] restarts processing from the top
   RewriteRule ^old-page$ /new-page [R=301,L]
   # If /new-page also lives under this .htaccess, the rules re-run

   # FIX: the rule only matches 'old-page', so /new-page won't match.
   # But if you used ^(.*)$, you need a stop condition:
   RewriteCond %{ENV:REDIRECT_STATUS} ^$
   RewriteRule ^(.*)$ /new-page [R=301,L]

The ``REDIRECT_STATUS`` variable is empty on the first pass and set to
the status code (e.g., ``200``) on subsequent passes. This is a reliable
way to detect re-processing.

**Pattern C --- Query string rewrite creates a loop:**

.. code-block:: apache

   # BUG: rewrites /?code=123 to /welcome?track=123
   # then /welcome?track=123 matches ^(.*)$ again
   RewriteCond %{QUERY_STRING} ^code=(.+)$
   RewriteRule ^(.*)$ /welcome?track=%1 [R=301,L]

   # FIX: match only the original URL, not the rewritten one
   RewriteCond %{QUERY_STRING} ^code=(.+)$
   RewriteRule ^/?$ /welcome?track=%1 [R=301,L]

**Pattern D --- WordPress/PHP-FPM interaction:**

When PHP runs as a ``ProxyPassMatch`` backend, the proxy subrequest can
re-trigger :file:`.htaccess` rewrite rules:

.. code-block:: apache

   # In server config
   ProxyPassMatch "^/(.*\.php)$" "fcgi://127.0.0.1:9000/var/www/html/$1"

   # In .htaccess (WordPress default)
   RewriteRule . /index.php [L]

The rewrite sends the request to :file:`/index.php`. The ``ProxyPassMatch``
proxies it to PHP-FPM. But the proxy subrequest re-enters the
:file:`.htaccess` processing, and ``.`` matches :file:`index.php` again.

Fix: add a condition to skip the rewrite if the request is already for a
PHP file, or use ``SetHandler`` instead of ``ProxyPassMatch``:

.. code-block:: apache

   <FilesMatch "\.php$">
       SetHandler "proxy:fcgi://127.0.0.1:9000"
   </FilesMatch>

**The nuclear option:** httpd's built-in loop detection stops processing
after 10 internal redirects (configurable with ``LimitInternalRecursion``).
If you see ``Request exceeded the limit of 10 internal redirects`` in the
error log, you have a loop.


.. index:: pair: recipes; .htaccess context
.. index:: pair: recipes; AllowOverride
.. index:: pair: recipes; per-directory rewrite

.htaccess vs. Server Config Context Differences
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your rewrite rules work in :file:`httpd.conf` but not in
:file:`.htaccess` (or vice versa). This is one of the most frequent sources
of confusion on the mailing list. In "Rewrite not applied?" a user has
rules in server config that are silently not being evaluated, with no
log entries even at ``rewrite:trace5``.

**Approach:** Understanding the ``per-dir`` context

The key differences:

- In :file:`.htaccess`, the leading slash is stripped from the URI before
  matching
- ``RewriteBase`` matters in :file:`.htaccess` but not in server config
- ``AllowOverride`` must include ``FileInfo`` for rewrite rules to work
  in :file:`.htaccess`
- ``[L]`` in :file:`.htaccess` doesn't truly stop processing---the rewritten
  URL goes through the entire :file:`.htaccess` again

**Side-by-side: the same rewrite in both contexts.**

Rewriting ``/products/widget`` to ``/catalog.php?item=widget``:

.. code-block:: apache

   # In server config (httpd.conf or <VirtualHost>)
   RewriteEngine On
   RewriteRule ^/products/(.+)$ /catalog.php?item=$1 [L]

.. code-block:: apache

   # In .htaccess (at document root)
   RewriteEngine On
   RewriteRule ^products/(.+)$ catalog.php?item=$1 [L]

Key difference: in :file:`.htaccess`, the leading slash is stripped. The
rewrite engine operates on the path *relative to the directory* containing
the :file:`.htaccess` file.

**RewriteBase** tells :module:`mod_rewrite` what URL prefix corresponds to the
directory containing the :file:`.htaccess` file. It matters when your
:file:`.htaccess` is in a subdirectory:

.. code-block:: apache

   # .htaccess in /var/www/html/myapp/
   # Without RewriteBase, the rewrite target is relative to /
   # With it, the target is relative to /myapp/

   RewriteEngine On
   RewriteBase /myapp/
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteRule ^ index.php [L]
   # Resolves to /myapp/index.php, not /index.php

Without ``RewriteBase /myapp/``, the rule would produce :file:`/index.php`
(at the document root) instead of :file:`/myapp/index.php`.

**The** ``AllowOverride`` **pitfall:** If ``AllowOverride`` does not
include ``FileInfo``, :file:`.htaccess` rewrite rules are silently ignored.
No error, no log entry, nothing---the rules simply don't run:

.. code-block:: apache

   # This silently disables ALL .htaccess rewrite rules
   <Directory "/var/www/html">
       AllowOverride None
   </Directory>

   # This enables them
   <Directory "/var/www/html">
       AllowOverride FileInfo
   </Directory>

   # Or allow everything (common but less secure)
   <Directory "/var/www/html">
       AllowOverride All
   </Directory>

**Diagnostic tip:** If your :file:`.htaccess` rules do nothing and even
``LogLevel rewrite:trace8`` produces no output for that directory, check
``AllowOverride`` first. The rewrite engine isn't ignoring your
rules---it was never invoked.

**Performance note:** :file:`.htaccess` files are read on every request.
The server walks the directory tree from the document root to the
requested file, reading each :file:`.htaccess` file along the way. For
high-traffic sites, putting rules in server config (which is parsed
once at startup) is measurably faster.


.. index:: pair: recipes; rewrite rule ordering
.. index:: pair: recipes; rule order

Rule Ordering and the [L] Flag
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Your rewrite rules aren't behaving as expected because of
ordering issues. The "rewrite in .htaccess" thread shows a user whose
domain migration redirect is placed *after* WordPress rewrite rules that
include ``[L]``---the migration rules are never reached.

**Approach:** Understanding rule processing order

**How** ``[L]`` **works in server config:** It means "stop processing
rules now." The rewritten URL is the final result.

**How** ``[L]`` **works in** :file:`.htaccess`: It means "stop processing
rules *for this pass*." The rewritten URL then goes back through the
entire :file:`.htaccess` file from the top. This re-processing continues until
no rule matches, or until :module:`mod_rewrite`'s internal redirect limit (10 by
default) is reached.

This is the single most common source of confusion in :module:`mod_rewrite`.

**Example:** The WordPress :file:`.htaccess` pattern:

.. code-block:: apache

   RewriteEngine On
   RewriteBase /
   RewriteRule ^index\.php$ - [L]
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.php [L]

Here's what happens with a request for ``/about``:

1. **Pass 1:** ``/about`` doesn't match ``^index\.php$``. It does match
   ``.`` (with the conditions satisfied). Rewritten to :file:`/index.php`.
   ``[L]`` stops this pass.
2. **Pass 2:** :file:`/index.php` matches ``^index\.php$``. The ``-`` target
   means "don't rewrite." ``[L]`` stops this pass.
3. **Pass 3:** No rule changes the URI. Processing ends.

The ``^index\.php$ - [L]`` rule exists solely to break the re-processing
loop. Without it, ``.`` would match :file:`index.php` again, rewriting it to
:file:`/index.php`... which would match ``.`` again, and so on until the
redirect limit.

**Rule processing order between server config and** :file:`.htaccess`:

1. Server config (:file:`httpd.conf` / ``<VirtualHost>``) rules run first
2. Then per-directory :file:`.htaccess` rules run
3. ``[L]`` in server config does *not* prevent :file:`.htaccess` rules from
   running

**RewriteCond binds only to the immediately following RewriteRule:**

.. code-block:: apache

   # WRONG: this condition does NOT apply to both rules
   RewriteCond %{HTTP_HOST} ^www\.example\.com$
   RewriteRule ^/foo /bar [L]
   RewriteRule ^/baz /qux [L]      # No condition! Matches all hostnames.

   # CORRECT: repeat the condition for each rule
   RewriteCond %{HTTP_HOST} ^www\.example\.com$
   RewriteRule ^/foo /bar [L]
   RewriteCond %{HTTP_HOST} ^www\.example\.com$
   RewriteRule ^/baz /qux [L]

This surprises people who expect conditions to act like ``if`` blocks in
programming languages. Each ``RewriteCond`` is consumed by the first
``RewriteRule`` that follows it.


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

Enable the rewrite log by setting ``LogLevel`` for the rewrite module:

.. code-block:: apache

   # Useful levels:
   # rewrite:trace1 --- shows which rules match
   # rewrite:trace2 --- adds rewriting result
   # rewrite:trace3 --- adds condition evaluation (the sweet spot)
   # rewrite:trace4-8 --- increasingly verbose internals

   LogLevel warn rewrite:trace3

.. warning::

   **Never leave** ``rewrite:trace3`` **or higher enabled in production.**
   It generates enormous amounts of log data---one entry per condition
   per rule per request. Enable it temporarily for debugging, then
   turn it off.

**Reading the log output:** At ``trace3``, each request produces entries
like this:

::

   [rewrite:trace3] [pid 1234] mod_rewrite.c(475): [client 10.0.0.1:54321]
     10.0.0.1 - - [perdir /var/www/html/] strip per-dir prefix: /var/www/html/about -> about
   [rewrite:trace3] [pid 1234] mod_rewrite.c(475): [client 10.0.0.1:54321]
     10.0.0.1 - - [perdir /var/www/html/] applying pattern '^index\.php$' to uri 'about'
   [rewrite:trace2] [pid 1234] mod_rewrite.c(475): [client 10.0.0.1:54321]
     10.0.0.1 - - [perdir /var/www/html/] rewrite 'about' -> '/index.php'

Key things to look for:

- ``strip per-dir prefix`` --- confirms you're in per-directory
  (:file:`.htaccess`) context
- ``applying pattern`` --- shows which rule is being tested against what URI
- ``rewrite '...' -> '...'`` --- the actual rewrite result
- If you see the *same* URI being rewritten repeatedly, you have a loop

**Filtering the log to focus on specific URLs:**

You can set the log level per-directory or per-location:

.. code-block:: apache

   # Only trace rewrites for the /api/ path
   <Location "/api/">
       LogLevel warn rewrite:trace3
   </Location>

Or filter the log file after the fact:

.. code-block:: bash

   # Show only entries for a specific URI
   grep 'about-us' /var/log/httpd/error_log | grep rewrite

   # Show only the rewrite results (not every condition check)
   grep 'rewrite:trace2' /var/log/httpd/error_log

   # Watch in real time
   tail -f /var/log/httpd/error_log | grep rewrite

**Tip:** When debugging in :file:`.htaccess`, remember that ``[L]`` does not
stop processing---it restarts the rule set. So you'll see the same URI
processed multiple times in the log. This is normal behavior, not a bug.
See the recipe on :ref:`Rule Ordering and the [L] Flag <Chapter_recipes>`
earlier in this chapter.

.. note::

   In httpd 2.2 and earlier, the rewrite log was configured with the
   separate ``RewriteLog`` and ``RewriteLogLevel`` directives. These were
   removed in 2.4 in favor of the unified ``LogLevel`` mechanism.


.. index:: pair: recipes; conditional fallback
.. index:: pair: recipes; file not found fallback

Serving a Fallback Resource When a File Is Missing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want to serve a default image, page, or resource when
the requested file doesn't exist. A thread on "Show Alternate Image if
Requested Image is Missing" shows a user trying to display a placeholder
sketch image when the actual property sketch JPG is missing.

**Approach:** :module:`mod_rewrite` with ``RewriteCond %{REQUEST_FILENAME} !-f``
(traditional), or ``FallbackResource`` directive (modern, preferred)

The mailing list thread reveals the common mistake: mixing ``Redirect``
(which doesn't check file existence) with ``RewriteCond`` conditions.
The ``FallbackResource`` directive, available since 2.2.16, is often the
simplest solution.

**FallbackResource** (simplest---no :module:`mod_rewrite` needed):

.. code-block:: apache

   # Serve /index.html for any request that doesn't match a real file
   FallbackResource /index.html

This is ideal for single-page applications (React, Vue, Angular) that
handle routing client-side.

**:module:`mod_rewrite` approach** (when you need more control):

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^ /index.html [L]

This does the same thing but with three lines instead of one. Use it when
you need additional conditions (e.g., excluding API paths from the
fallback).

**Image fallback** --- serve a placeholder when the requested image
doesn't exist:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteRule \.(jpg|jpeg|png|gif|webp)$ /images/placeholder.png [L]

This checks whether the requested file exists (``!-f``), and if it's an
image extension that's missing, serves a placeholder instead of a 404.

**More targeted fallback** --- only for a specific directory:

.. code-block:: apache

   <Directory "/var/www/html/sketches">
       RewriteEngine On
       RewriteCond %{REQUEST_FILENAME} !-f
       RewriteRule \.jpg$ /sketches/no-sketch-available.jpg [L]
   </Directory>

**Common mistake:** Combining ``Redirect`` with ``RewriteCond``. The
``Redirect`` directive (from :module:`mod_alias`) does not respect
``RewriteCond``---it fires unconditionally. If you need a conditional
redirect, you must use ``RewriteRule`` with ``[R]``.


.. index:: pair: recipes; maintenance mode
.. index:: pair: recipes; 503 response

Maintenance Mode (503 Service Unavailable)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You need to put your site into maintenance mode, returning
a 503 response to all requests while you work on the backend. A thread on
"enforce 503 response using RewriteRule or Redirect due to temporary
maintenance" notes that ``Redirect`` supports ``gone`` (410) but not
503.

**Approach:** :module:`mod_rewrite` with ``[R=503]``, or ``ErrorDocument 503``
combined with ``<If>``

**:module:`mod_rewrite` approach** (the classic method):

.. code-block:: apache

   # Return 503 for all requests except the maintenance page itself
   ErrorDocument 503 /maintenance.html

   RewriteEngine On
   # Don't rewrite the maintenance page or its assets
   RewriteCond %{REQUEST_URI} !^/maintenance\.html$
   RewriteCond %{REQUEST_URI} !^/css/
   RewriteCond %{REQUEST_URI} !^/images/
   # Allow your own IP through for testing
   RewriteCond %{REMOTE_ADDR} !^203\.0\.113\.10$
   RewriteRule ^ - [R=503,L]

.. note::

   ``[R=503]`` requires that ``ErrorDocument 503`` points to a *local*
   path (not a URL). If you use a URL like ``http://...``, httpd sends
   a 302 redirect to the maintenance page instead of a 503---which search
   engines interpret as "this page has moved," not "this site is temporarily
   down."

**File-existence toggle** (enable/disable without editing config):

.. code-block:: apache

   # Enable maintenance mode by creating /var/www/maintenance-flag
   # Disable it by removing the file
   RewriteEngine On
   RewriteCond /var/www/maintenance-flag -f
   RewriteCond %{REMOTE_ADDR} !^203\.0\.113\.10$
   RewriteCond %{REQUEST_URI} !^/maintenance\.html$
   RewriteRule ^ - [R=503,L]

   ErrorDocument 503 /maintenance.html

This is convenient---deploy maintenance mode with ``touch /var/www/maintenance-flag``
and disable with ``rm /var/www/maintenance-flag``. No config reload needed.

**<If> approach** (httpd 2.4+, no :module:`mod_rewrite` needed):

.. code-block:: none

   <If "-f '/var/www/maintenance-flag' && \
        ! %{REMOTE_ADDR} -ipmatch '203.0.113.10' && \
        ! %{REQUEST_URI} =~ m#^/maintenance\.html$#">
       ErrorDocument 503 /maintenance.html
       Redirect 503 /
   </If>

**Per-application maintenance with RewriteMap** (for multi-tenant setups):

.. code-block:: apache

   # Map file: app-status.txt
   # app1  down
   # app2  up
   # app3  down

   RewriteMap appstatus "txt:/etc/httpd/conf/app-status.txt"

   # /app1/* returns 503 because app1 is "down"
   RewriteCond ${appstatus:$1} =down
   RewriteRule ^/([^/]+)/ - [R=503,L]

   ErrorDocument 503 /maintenance.html

Toggling an app into or out of maintenance is a one-line edit to the
map file---no restart required, since httpd re-reads text maps
automatically.


.. index:: pair: recipes; special characters in URLs
.. index:: pair: recipes; URL encoding

Handling Special Characters and Encoded URLs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** Rewrite rules break when URLs contain special characters
(spaces as ``%20``, international characters, backslashes, etc.). A thread
on "404 rewrite error using special character \\" shows issues with
backslashes, while "chinese char URL encoding/decoding fails" documents
problems with multibyte character encoding.

**Approach:** :module:`mod_rewrite` with ``[B]`` flag and ``[NE]`` flag

**How httpd handles URL encoding:** Before rewrite rules see the URI,
httpd decodes percent-encoded characters. So a request for ``/caf%C3%A9``
arrives at the rewrite engine as ``/café``. This is usually helpful, but
it creates problems when backreferences are substituted into the
target---the decoded characters may need to be re-encoded.

**The** ``[B]`` **flag** (escape backreferences): tells the rewrite engine
to percent-encode special characters in backreferences before substituting
them into the target. Without it, spaces, ampersands, and other special
characters in captured groups can break the resulting URL.

.. code-block:: apache

   # Without [B]: /search/hello world -> /results?q=hello world (broken URL)
   # With [B]:    /search/hello world -> /results?q=hello%20world (correct)
   RewriteRule ^/search/(.*)$ /results?q=$1 [B,L]

**The** ``[NE]`` **flag** (no-escape output): prevents the rewrite engine
from escaping special characters in the *output*. Useful when your
target URL intentionally contains characters like ``#`` (fragment
identifiers) or ``%`` (already-encoded sequences):

.. code-block:: apache

   # Redirect to a URL with a fragment identifier
   # Without [NE]: /old#section -> /new%23section (broken)
   # With [NE]:    /old#section -> /new#section   (correct)
   RewriteRule ^/old$ /new#section [NE,R=301,L]

   # Preserve already-encoded characters in a redirect
   # Without [NE]: %20 gets double-encoded to %2520
   RewriteRule ^/(.*)$ https://new.example.com/$1 [NE,R=301,L]

**Encoded slashes** (``%2F``): By default, httpd rejects URLs containing
``%2F`` with a 404, because a percent-encoded slash could be used to
bypass ``<Directory>`` or ``<Location>`` restrictions. If your application
legitimately uses ``%2F`` in path segments (e.g., Base64-encoded tokens),
enable it:

.. code-block:: apache

   # Allow %2F in URLs (use with caution)
   AllowEncodedSlashes On

   # Or decode them to real slashes (even more caution)
   AllowEncodedSlashes NoDecode

With ``NoDecode``, the ``%2F`` is passed through to the backend without
decoding, so the application sees the literal ``%2F``. With ``On``, httpd
decodes it to ``/`` before the application sees it.

**Backslashes:** On Windows, httpd converts backslashes to forward slashes
automatically. On Unix, a backslash in a URL is technically legal but unusual.
If your URLs contain backslashes, use ``[B]`` to ensure they're properly
encoded:

.. code-block:: apache

   # Handles paths like /files/path\to\file
   RewriteRule ^/files/(.*)$ /download?path=$1 [B,L]

**Common mistake:** Combining ``[B]`` and ``[NE]`` on the same rule.
They have opposite effects---``[B]`` encodes backreferences while ``[NE]``
prevents encoding of the output. Use one or the other depending on
whether your problem is under-encoding or over-encoding.


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

Individual ``RewriteRule`` directives are evaluated sequentially---httpd
tests each regex in order until one matches. Ten rules are fine. A hundred
is manageable. But at 1,000+, each request walks through a long chain of
regex evaluations, and the cost adds up.

**Rough guidance:**

- **< 100 redirects**: Individual ``Redirect`` or ``RewriteRule`` directives
  are fine. No measurable performance impact.
- **100--1,000 redirects**: You may notice a few milliseconds of added
  latency per request. Consider switching to a map.
- **1,000+ redirects**: Use a ``RewriteMap``. The sequential regex scan
  becomes the dominant cost of request processing.

**Migrating to a RewriteMap:**

Convert individual rules to a text map file:

.. code-block:: apache

   # Before: 5,000 individual rules in httpd.conf
   RewriteRule ^/old/page-1$ /new/page-1 [R=301,L]
   RewriteRule ^/old/page-2$ /new/page-2 [R=301,L]
   # ... 4,998 more ...

   # After: a single rule with a map lookup
   RewriteMap redirects "txt:/etc/httpd/conf/redirect-map.txt"

   RewriteCond ${redirects:$1|NOT_FOUND} !NOT_FOUND
   RewriteRule ^/(.*)$ ${redirects:$1} [R=301,L]

The map file:

::

   # redirect-map.txt (one key/value pair per line)
   old/page-1   /new/page-1
   old/page-2   /new/page-2

For maximum performance, convert the text map to DBM format:

.. code-block:: bash

   httxt2dbm -i redirect-map.txt -o redirect-map.db

Then reference the DBM map:

.. code-block:: apache

   RewriteMap redirects "dbm:/etc/httpd/conf/redirect-map.db"

A DBM lookup is a hash table operation---O(1) regardless of whether the
map contains 100 or 100,000 entries. The text map is also O(1) after
initial load (httpd reads it into a hash table at startup), but the DBM
format loads faster and uses less memory for very large maps.

**Updating the map:** Edit the text file and run ``httxt2dbm`` again.
For the text map type, httpd detects file changes and reloads
automatically. For DBM maps, a graceful restart is needed:

.. code-block:: bash

   httxt2dbm -i redirect-map.txt -o redirect-map.db
   apachectl graceful

See :ref:`Chapter 8 <Chapter_rewritemap>` for a detailed treatment of
all map types and their performance characteristics.


When NOT to Use mod_rewrite
---------------------------

As discussed throughout this book, :module:`mod_rewrite` is powerful but often
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

**Approach:** ``Redirect`` / ``RedirectMatch`` from :module:`mod_alias`

The answer from the mailing list: for simple redirects, they're
functionally equivalent, but ``Redirect`` is clearer, faster (no regex
engine involved for plain ``Redirect``), and less error-prone. As one
respondent notes: "Golden rule: if source ends in trailing slash, target
must also end in trailing slash."

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Task
     - ``Redirect``
     - ``RedirectMatch``
     - ``RewriteRule [R]``
   * - Single page redirect
     - **Best** |checkmark|
     - Works
     - Overkill
   * - Redirect preserving path
     - **Best** |checkmark|
     - Works
     - Overkill
   * - Regex-based redirect
     - No
     - **Best** |checkmark|
     - Works
   * - Conditional redirect (header, IP, etc.)
     - No
     - No
     - **Required** |checkmark|
   * - Redirect with query string manipulation
     - No
     - No
     - **Required** |checkmark|

.. |checkmark| unicode:: U+2713

Examples:

.. code-block:: apache

   # Single page --- Redirect is simplest
   Redirect permanent /old-page.html /new-page.html

   # Entire directory --- Redirect preserves path automatically
   Redirect permanent /blog/ https://blog.example.com/

   # Pattern-based --- RedirectMatch when you need regex
   RedirectMatch 301 ^/user/([0-9]+)$ /profile/$1

   # Conditional --- RewriteRule only when you need RewriteCond
   RewriteEngine On
   RewriteCond %{HTTP_HOST} ^old\.example\.com$
   RewriteRule ^/(.*)$ https://new.example.com/$1 [R=301,L]

**The golden rule of trailing slashes:** when using ``Redirect`` to
redirect a directory, if the source ends with a trailing slash, the
target must also end with a trailing slash. Otherwise, the path
appending produces mangled URLs:

.. code-block:: apache

   # CORRECT: both end with /
   Redirect permanent /old-section/ /new-section/
   # /old-section/page.html -> /new-section/page.html

   # WRONG: missing trailing slash on target
   Redirect permanent /old-section/ /new-section
   # /old-section/page.html -> /new-sectionpage.html  (broken!)

``Redirect`` has no regex engine overhead. For a plain path-to-path
redirect, it's the fastest option. Reaching for ``RewriteRule`` when
``Redirect`` would do the job is the most common case of :module:`mod_rewrite`
overuse in the wild.


.. index:: pair: recipes; ProxyPass vs mod_rewrite proxy
.. index:: pair: recipes; mod_proxy

Proxying: Use ProxyPass, Not RewriteRule [P]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You're using ``RewriteRule`` with the ``[P]`` flag to proxy
requests to a backend server.

**Approach:** ``ProxyPass`` / ``ProxyPassReverse`` from :module:`mod_proxy`

``ProxyPass`` is the right tool for reverse proxying:

.. code-block:: apache

   ProxyPass        "/app/"  "http://backend.local:8080/app/"
   ProxyPassReverse "/app/"  "http://backend.local:8080/app/"

The equivalent :module:`mod_rewrite` approach:

.. code-block:: apache

   RewriteEngine On
   RewriteRule ^/app/(.*)$ http://backend.local:8080/app/$1 [P]
   ProxyPassReverse "/app/" "http://backend.local:8080/app/"

Both proxy the request, but ``ProxyPass`` is preferred for several reasons:

.. list-table::
   :header-rows: 1
   :widths: 40 30 30

   * - Feature
     - ``ProxyPass``
     - ``RewriteRule [P]``
   * - Connection pooling
     - Yes (keeps persistent connections to backend)
     - No (new connection per request)
   * - Load balancing
     - Yes (``BalancerMember``)
     - Manual only
   * - Health checks
     - Yes (:module:`mod_proxy_hcheck`)
     - No
   * - Error handling
     - ``ProxyErrorOverride``, retry logic
     - Minimal
   * - Header rewriting
     - ``ProxyPassReverse`` integrated
     - Still need ``ProxyPassReverse``
   * - WebSocket support
     - Via :module:`mod_proxy_wstunnel`
     - Fragile

**When** ``[P]`` **is actually needed:** Use it when you need conditional
proxying that ``ProxyPass`` can't express---for example, proxying only
when a specific cookie is present, or routing to different backends based
on a regex capture:

.. code-block:: apache

   # Route to different backends based on API version in the URL
   RewriteEngine On
   RewriteRule ^/api/v1/(.*)$ http://backend-v1:8080/$1 [P]
   RewriteRule ^/api/v2/(.*)$ http://backend-v2:8080/$1 [P]

Even here, consider ``ProxyPass`` with ``<Location>`` blocks first.
``[P]`` should be your last resort, not your first instinct.


.. index:: pair: recipes; If expression
.. index:: pair: recipes; mod_rewrite alternatives

Conditional Logic: Use <If> Expressions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You're using :module:`mod_rewrite` for conditional configuration
that doesn't involve URL rewriting---like setting headers based on
request properties or denying access based on complex conditions.

**Approach:** ``<If>`` expressions (available since httpd 2.4)

The ``<If>`` directive supports a rich expression language that can test
request headers, environment variables, IP addresses, and more---without
the cognitive overhead of ``RewriteCond``/``RewriteRule`` syntax.

Here are common ``RewriteCond`` patterns and their ``<If>`` equivalents.

**Blocking by User-Agent:**

.. code-block:: none

   # mod_rewrite approach
   RewriteEngine On
   RewriteCond %{HTTP_USER_AGENT} (BadBot|EvilScraper) [NC]
   RewriteRule ^ - [F]

   # <If> approach --- clearer intent
   <If "%{HTTP_USER_AGENT} =~ /BadBot|EvilScraper/i">
       Require all denied
   </If>

**Checking a request header:**

.. code-block:: none

   # mod_rewrite: set header based on another header
   RewriteCond %{HTTP:X-Forwarded-Proto} =https
   RewriteRule ^ - [E=PROTO:https]

   # <If> approach
   <If "req('X-Forwarded-Proto') == 'https'">
       Header set Strict-Transport-Security "max-age=31536000"
   </If>

**Checking source IP:**

.. code-block:: none

   # mod_rewrite --- awkward regex on IP
   RewriteCond %{REMOTE_ADDR} !^10\.
   RewriteRule ^/admin - [F]

   # <If> --- proper CIDR matching
   <If "! %{REMOTE_ADDR} -ipmatch '10.0.0.0/8'">
       <Location "/admin">
           Require all denied
       </Location>
   </If>

**Combining multiple conditions** (AND / OR):

.. code-block:: none

   # mod_rewrite: conditions are implicitly AND
   RewriteCond %{REMOTE_ADDR} !^10\.
   RewriteCond %{HTTP_USER_AGENT} !InternalMonitor
   RewriteRule ^/status - [F]

   # <If>: explicit boolean operators
   <If "! %{REMOTE_ADDR} -ipmatch '10.0.0.0/8' && \
        %{HTTP_USER_AGENT} !~ /InternalMonitor/">
       <Location "/status">
           Require all denied
       </Location>
   </If>

The ``<If>`` approach is preferred when you're not actually rewriting the
URL---you're just making access control or header decisions. The expression
syntax is documented in the `Apache Expressions
<https://httpd.apache.org/docs/current/expr.html>`_ reference.


.. index:: pair: recipes; FallbackResource
.. index:: pair: recipes; ErrorDocument

Fallback Resources: Use FallbackResource, Not RewriteRule
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Problem:** You want all requests for non-existent files to be handled
by a single script (the front controller pattern). The traditional approach
uses :module:`mod_rewrite`, but ``FallbackResource`` does this in a single line.

**Approach:** ``FallbackResource`` directive

::

    FallbackResource /index.php

This single line replaces the entire WordPress-style rewrite block for the
common case. It was added in httpd 2.2.16 specifically to address this
extremely common use case.

The traditional :module:`mod_rewrite` front controller block looks like this:

.. code-block:: apache

   RewriteEngine On
   RewriteBase /
   RewriteRule ^index\.php$ - [L]
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.php [L]

``FallbackResource`` replaces all four lines with one:

.. code-block:: apache

   FallbackResource /index.php

Both achieve the same result: if the requested file or directory doesn't
exist, serve :file:`/index.php` instead. The ``FallbackResource`` version is
faster (no regex evaluation), clearer, and immune to the :file:`.htaccess`
re-processing loop that trips up so many users.

**To disable** ``FallbackResource`` in a subdirectory (e.g., an ``/admin``
area that should show real 404s):

.. code-block:: apache

   <Directory "/var/www/html/admin">
       FallbackResource disabled
   </Directory>

**Limitations of** ``FallbackResource``:

- Cannot apply conditions (e.g., "only for certain file extensions")
- Cannot route to different scripts based on URL pattern
- Cannot rewrite the URL---it always serves the fallback as-is
- Does not set ``PATH_INFO`` the way :module:`mod_rewrite` does

If you need conditional routing or multiple front controllers, you still
need :module:`mod_rewrite`. But for the overwhelmingly common case of a single
front controller (WordPress, Laravel, Symfony, Drupal), ``FallbackResource``
is the right tool.


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

``RewriteMap`` defines a named mapping function that can be called from
``RewriteRule`` and ``RewriteCond`` substitutions. It must be defined in
server config (not :file:`.htaccess`), but the maps it creates can be used
anywhere. See :ref:`Chapter 8 <Chapter_rewritemap>` for the full treatment.

**Text file map (``txt``)** --- simple key/value pairs:

.. code-block:: apache

   # Define the map (server config only)
   RewriteMap redirects "txt:/etc/httpd/conf/redirect-map.txt"

   # Use it
   RewriteEngine On
   RewriteCond ${redirects:$1} !=""
   RewriteRule ^/(.*)$ ${redirects:$1} [R=301,L]

The map file is a plain text file with one key/value pair per line:

::

   # redirect-map.txt
   old-page.html   /new-section/updated-page.html
   products/legacy  /catalog/current

**DBM map (``dbm``)** --- hashed lookup, O(1) performance:

.. code-block:: apache

   RewriteMap redirects "dbm:/etc/httpd/conf/redirect-map.db"

Convert a text map to DBM format using ``httxt2dbm``:

.. code-block:: bash

   httxt2dbm -i redirect-map.txt -o redirect-map.db

This is the right choice for maps with thousands of entries. See
the performance recipe later in this chapter.

**External program map (``prg``)** --- call an external script:

.. code-block:: apache

   RewriteMap mymap "prg:/usr/local/bin/rewrite-lookup.py"

   RewriteRule ^/user/(.+)$ ${mymap:$1} [L]

The program receives lookup keys on stdin (one per line) and must
return results on stdout (one per line). **Critical pitfalls:**

1. **Buffering**: stdout *must* be line-buffered or unbuffered. In Python,
   use ``print(..., flush=True)`` or run with ``PYTHONUNBUFFERED=1``. In
   Perl, set ``$| = 1;``. If the program buffers its output, httpd will
   hang waiting for a response.

2. **Persistence**: the program starts once and runs for the lifetime of
   the httpd process. It must loop forever reading stdin.

3. **Crashes**: if the program exits, all subsequent lookups return empty
   strings with no error in the log. Check the error log for startup
   failures.

A minimal Python example:

.. code-block:: python

   #!/usr/bin/env python3
   import sys
   # Must flush every line --- httpd is waiting for the response
   for line in sys.stdin:
       key = line.strip()
       # Your lookup logic here
       result = lookup_user(key)
       print(result or "NOT_FOUND", flush=True)

**Database map (``dbd``)** --- SQL lookup via :module:`mod_dbd`:

.. code-block:: apache

   # Requires mod_dbd to be configured with a database connection
   RewriteMap mymap "dbd:SELECT target FROM redirects WHERE source = %s"

   RewriteRule ^/(.*)$ ${mymap:$1} [R=301,L]

This queries the database for every request that matches the rule.
Use connection pooling (``DBDMin``, ``DBDKeep``, ``DBDMax``) to
manage database load.

**Built-in functions (``int``)** --- string transformations:

.. code-block:: apache

   RewriteMap lowercase "int:tolower"
   RewriteRule ^/(.*)$ /${lowercase:$1} [R=301,L]

Available functions: ``tolower``, ``toupper``, ``escape``, ``unescape``.


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

The simplest approach uses the ``<If>`` directive with the ``-ipmatch``
operator, available since httpd 2.4:

.. code-block:: none

   # Block access from a specific CIDR range
   <If "%{REMOTE_ADDR} -ipmatch '192.168.0.0/16'">
       Require all denied
   </If>

   # Redirect internal users to an intranet version
   <If "%{REMOTE_ADDR} -ipmatch '10.0.0.0/8'">
       RedirectMatch ^/portal(.*)$ https://intranet.example.com$1
   </If>

You can combine multiple ranges:

.. code-block:: none

   <If "%{REMOTE_ADDR} -ipmatch '10.0.0.0/8' || %{REMOTE_ADDR} -ipmatch '172.16.0.0/12'">
       # Allow access for both RFC 1918 ranges
       Require all granted
   </If>

For dynamic CIDR lookups---where the ranges change frequently or are
stored externally---use a ``RewriteMap`` with an external program:

.. code-block:: apache

   # In server config (not .htaccess)
   RewriteMap cidrcheck "prg:/usr/local/bin/cidr-check.py"

   RewriteEngine On
   RewriteCond ${cidrcheck:%{REMOTE_ADDR}} =blocked
   RewriteRule ^ - [F]

The external program reads an IP address on stdin and returns ``blocked``
or ``allowed`` on stdout, checking it against a list of CIDR ranges:

.. code-block:: python

   #!/usr/bin/env python3
   import sys
   import ipaddress

   BLOCKED_RANGES = [
       ipaddress.ip_network('198.51.100.0/24'),
       ipaddress.ip_network('203.0.113.0/24'),
   ]

   # Line-buffered output is critical
   for line in sys.stdin:
       ip = line.strip()
       try:
           addr = ipaddress.ip_address(ip)
           if any(addr in net for net in BLOCKED_RANGES):
               print("blocked", flush=True)
           else:
               print("allowed", flush=True)
       except ValueError:
           print("allowed", flush=True)

**Recommendation:** For static CIDR ranges, ``<If> -ipmatch`` is
dramatically simpler and performs better. Use the ``RewriteMap`` approach
only when the ranges must be loaded from an external source or change
without restarting httpd.

See :ref:`Chapter 8 <Chapter_rewritemap>` for more on external program
maps and their buffering requirements.