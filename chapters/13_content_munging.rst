.. _Chapter_content_munging:


.. index:: content munging
.. index:: pair: content; modification
.. index:: output filters

===============
Content Munging
===============

.. epigraph::

   | On the Coast of Coromandel
   |    Where the early pumpkins blow,
   |       In the middle of the woods
   |    Lived the Yonghy-Bonghy-Bo.

   -- Edward Lear, *The Courtship of the Yonghy-Bonghy-Bo*



Everything we've discussed so far in this book transforms the *request*
— the URL, the query string, headers, environment variables. The server
decides *what* to serve, but the content itself passes through
untouched.

Sometimes that's not enough. You may need to modify the *response* —
the actual HTML, CSS, or other content that the server sends back to the
client. Perhaps you've placed a reverse proxy in front of a backend
application and the HTML it returns is full of hardcoded URLs pointing
to the backend's internal hostname. Or perhaps you need to inject a
tracking snippet into every page, or strip out a legacy banner that the
backend still inserts.

:module:`mod_rewrite` can't help you here. It has already done its work
by the time the response body is being assembled. For response
transformation, you need the output filter modules. We're going to look
at three of them — :module:`mod_substitute`, :module:`mod_sed`, and
:module:`mod_proxy_html` — and then at the filter framework that ties
them all together.


.. _mod_substitute:


.. index:: mod_substitute
.. index:: pair: modules; mod_substitute
.. index:: Substitute directive
.. index:: SubstituteMaxLineLength

mod_substitute
--------------

:module:`mod_substitute` performs search-and-replace on the response body
using a syntax borrowed from ``sed``. It's the simplest of the content
transformation modules, and the one you'll reach for most often.

The core directive is ``Substitute``, which takes a substitution
expression in the familiar ``s/pattern/replacement/flags`` form. Any
single character can serve as the delimiter — you don't have to use
``/`` — which is handy when your patterns contain slashes, as URLs
tend to.


Basic usage
~~~~~~~~~~~

The most common use case is rewriting URLs in proxied content. Suppose
you have a reverse proxy in front of a backend server at
``http://backend.internal:8080``. The backend generates HTML with
absolute URLs pointing to itself:

.. code-block:: html

   <a href="http://backend.internal:8080/dashboard">Dashboard</a>
   <img src="http://backend.internal:8080/images/logo.png">

You need these rewritten so they point to your public-facing proxy.
``ProxyPassReverse`` handles ``Location`` and other *headers*, but it
doesn't touch the *body*. That's where ``Substitute`` comes in:

.. code-block:: apache

   ProxyPass        "/app" "http://backend.internal:8080"
   ProxyPassReverse "/app" "http://backend.internal:8080"

   <Location "/app">
       AddOutputFilterByType SUBSTITUTE text/html
       Substitute "s|http://backend.internal:8080|/app|ni"
   </Location>

Let's break down the flags:

``n``
   Treat the pattern as a literal string, not a regular expression. This
   is what you want when you're matching a fixed URL — no need to worry
   about escaping dots and slashes.

``i``
   Case-insensitive match. Useful because some backends generate mixed
   case in URLs (``HTTP://`` vs ``http://``).

Other available flags are:

``f``
   Flatten line breaks. Normally, :module:`mod_substitute` processes the
   response one line at a time. The ``f`` flag collapses the entire
   response (or the current buffer) into a single line before applying
   the substitution. Use this when the text you're trying to match spans
   multiple lines — for example, an HTML tag with attributes split across
   lines.

``q``
   Quote (escape) special characters in the replacement string. Use this
   when your replacement contains characters that would otherwise be
   interpreted as regex backreferences.

You can stack multiple ``Substitute`` directives — they're applied in
order:

.. code-block:: apache

   <Location "/app">
       AddOutputFilterByType SUBSTITUTE text/html
       Substitute "s|http://backend.internal:8080|/app|ni"
       Substitute "s|backend.internal|www.example.com|ni"
   </Location>


.. index:: SubstituteMaxLineLength

Handling long lines
~~~~~~~~~~~~~~~~~~~

By default, :module:`mod_substitute` processes lines up to 1 MiB in
length. If your backend produces minified HTML or JSON where the entire
response is a single line, you may hit this limit. Increase it with:

.. code-block:: apache

   SubstituteMaxLineLength 10m

The value accepts ``k`` (kilobytes) and ``m`` (megabytes) suffixes.


Using regular expressions
~~~~~~~~~~~~~~~~~~~~~~~~~

When literal matching isn't enough, drop the ``n`` flag and use a full
regular expression. For example, to strip all ``onclick`` attributes
from the response:

.. code-block:: apache

   Substitute "s/\s+onclick=\"[^\"]*\"//i"

Or to rewrite a family of image URLs:

.. code-block:: apache

   Substitute "s|/old-images/(.*?\.(?:png|jpg|gif))|/new-images/$1|i"

Be conservative with regex substitutions on response bodies. A
poorly-anchored pattern applied to a large HTML document can produce
surprising results — or silently corrupt content. Always test
thoroughly, and prefer the ``n`` (literal) flag when exact string
matching will do.


Content type filtering
~~~~~~~~~~~~~~~~~~~~~~

Notice the ``AddOutputFilterByType`` directive in the examples above.
This is important: you almost certainly don't want to run text
substitutions on binary content like images or PDFs. Always scope your
``Substitute`` directives to the appropriate content types:

.. code-block:: apache

   # Only apply to HTML and CSS
   AddOutputFilterByType SUBSTITUTE text/html text/css

If you need to apply substitutions to *all* text content, you can add
``text/plain``, ``application/javascript``, ``application/json``, and
so on — but think twice before casting too wide a net.


.. _mod_sed:


.. index:: mod_sed
.. index:: pair: modules; mod_sed
.. index:: OutputSed
.. index:: InputSed

mod_sed
-------

Where :module:`mod_substitute` gives you a single ``s/find/replace/``
operation per directive, :module:`mod_sed` gives you the full ``sed``
stream-editing language. It's more powerful, but also more complex, and
you'll need it far less often.

:module:`mod_sed` provides two directives:

``OutputSed``
   Applies a ``sed`` command to the response body (output filter).

``InputSed``
   Applies a ``sed`` command to the request body (input filter). This is
   unusual — it means you can transform POST data before your
   application sees it. There aren't many use cases for this in
   practice, but it's there if you need it.


Basic usage
~~~~~~~~~~~

Here's a simple example: stripping all ``<script>`` blocks from proxied
HTML, perhaps as a crude XSS mitigation on a legacy backend:

.. code-block:: apache

   <Location "/legacy">
       AddOutputFilterByType Sed text/html
       OutputSed "s/<script[^>]*>.*<\/script>//gi"
   </Location>

Note the filter name is ``Sed`` (capital S), not ``SUBSTITUTE``.


When to reach for mod_sed
~~~~~~~~~~~~~~~~~~~~~~~~~

For simple search-and-replace, :module:`mod_substitute` is easier and
sufficient. Reach for :module:`mod_sed` when you need capabilities that
go beyond a single substitution:

- **Address ranges**: Apply a command only to lines matching a pattern
  or falling within a line range. For example, transform only lines
  inside a ``<div class="legacy">`` block.

- **Multiple commands**: Chain several ``sed`` commands in sequence. You
  can use ``OutputSed`` multiple times, or separate commands with
  semicolons if your ``sed`` syntax supports it.

- **Delete operations**: The ``d`` command deletes entire lines matching
  a pattern, which is cleaner than substituting them with an empty
  string.

.. code-block:: apache

   # Delete all HTML comment lines from the response
   OutputSed "/^<!--/d"

In practice, if you find yourself writing complex ``sed`` programs inside
your Apache configuration, it's worth stepping back and asking whether
the transformation should happen at the application level instead. A
few lines of ``sed`` in the config is fine; a 20-line ``sed`` script
embedded in ``OutputSed`` directives is a maintenance hazard.


.. _mod_proxy_html:


.. index:: mod_proxy_html
.. index:: pair: modules; mod_proxy_html
.. index:: ProxyHTMLURLMap
.. index:: ProxyHTMLEnable
.. index:: ProxyHTMLExtended

mod_proxy_html
--------------

:module:`mod_proxy_html` takes a fundamentally different approach from the
two modules above. Instead of doing blind text search-and-replace, it
actually *parses* the HTML and rewrites only the URLs it finds in
elements and attributes. It understands ``<a href>``, ``<img src>``,
``<form action>``, ``<link href>``, and all the other places where URLs
appear in HTML.

This makes it both safer and more precise for URL rewriting — it won't
accidentally mangle text that happens to look like a URL, because it
only touches actual attribute values in HTML elements. On the other
hand, it's useless for non-HTML content, and it does nothing for URLs
embedded in JavaScript strings or inline CSS (unless you enable
``ProxyHTMLExtended``).


A worked example
~~~~~~~~~~~~~~~~

Here's the classic reverse proxy scenario. You proxy ``/app`` to a
backend at ``http://backend:8080/``, and the backend generates HTML with
absolute paths rooted at ``/``:

.. code-block:: html

   <a href="/dashboard">Dashboard</a>
   <link rel="stylesheet" href="/css/style.css">
   <form action="/api/submit" method="post">

These paths are wrong from the client's perspective — the client needs
to see ``/app/dashboard``, ``/app/css/style.css``, and
``/app/api/submit``. Here's how :module:`mod_proxy_html` handles it:

.. code-block:: apache

   ProxyPass        "/app" "http://backend:8080"
   ProxyPassReverse "/app" "http://backend:8080"

   <Location "/app">
       ProxyHTMLEnable On
       ProxyHTMLURLMap "/" "/app/"
   </Location>

``ProxyHTMLURLMap`` takes a *from* pattern and a *to* string, similar to
``Substitute`` but operating on parsed URL attributes rather than raw
text. This single directive will rewrite every ``href``, ``src``,
``action``, and similar attribute in the HTML response.


Extending to CSS and JavaScript
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, :module:`mod_proxy_html` only processes HTML element
attributes. If your backend also embeds URLs in inline CSS (``url(...)``
values) or JavaScript strings, you'll need:

.. code-block:: apache

   ProxyHTMLExtended On

This enables a more aggressive mode that scans for URL-like patterns
beyond just HTML attributes. It's slower and has a higher risk of false
positives, so only enable it if you actually need it.


Setting the output doctype
~~~~~~~~~~~~~~~~~~~~~~~~~~

:module:`mod_proxy_html` re-serializes the HTML after rewriting, which
means it needs to know whether to produce HTML 4, XHTML, or HTML 5.
Use ``ProxyHTMLDocType`` to control this:

.. code-block:: apache

   # Output as HTML 5
   ProxyHTMLDocType "<!DOCTYPE html>" HTML

   # Or for legacy XHTML
   ProxyHTMLDocType "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
   \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">" XHTML


Comparison with mod_substitute
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Use :module:`mod_proxy_html` when:

- You need to rewrite URLs in HTML attributes, and you want something
  that understands HTML structure.
- Your backend produces well-formed HTML and the URLs follow standard
  patterns.
- You want to avoid accidentally rewriting text content that happens to
  contain URL-like strings.

Use :module:`mod_substitute` when:

- You need to rewrite content that isn't HTML, or that appears outside
  of standard HTML attributes (e.g., in ``<script>`` blocks, JSON
  responses, plain text).
- You need regex-powered transformations, not just URL mapping.
- The response isn't well-formed HTML and would confuse a parser.

In a complex reverse proxy setup, you may end up using *both* —
:module:`mod_proxy_html` for the structural URL rewriting and
:module:`mod_substitute` for the edge cases it doesn't cover.


.. _filters:


.. index:: filters
.. index:: pair: Apache HTTP Server; filters
.. index:: output filter chain
.. index:: AddOutputFilterByType

Filters
-------

All three modules above are implemented as httpd output filters. To use
them effectively, it helps to understand what that means.

When httpd generates or receives a response, the content doesn't go
directly to the client. Instead, it passes through a chain of *filters*
— a pipeline of modules that can inspect, transform, or replace the
content as it flows through. You've already been using this concept
implicitly: ``mod_deflate`` (gzip compression) is a filter,
``mod_ssl`` (encryption) is a filter, and the content transformation
modules in this chapter are filters.


Adding filters to the chain
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. index:: AddOutputFilterByType
.. index:: SetOutputFilter

The most common way to add a filter is ``AddOutputFilterByType``, which
applies the filter only to responses of a specific MIME type:

.. code-block:: apache

   AddOutputFilterByType SUBSTITUTE text/html
   AddOutputFilterByType DEFLATE text/html text/css application/javascript

You can also use ``SetOutputFilter`` to apply a filter unconditionally
to everything in a given context:

.. code-block:: apache

   <Location "/api">
       SetOutputFilter Sed
   </Location>

But this is rarely what you want — applying text transformations to
binary content will corrupt it.


Filter ordering
~~~~~~~~~~~~~~~

Filters run in a defined order. Content transformation filters
(SUBSTITUTE, Sed, proxy-html) run before compression (DEFLATE),
which runs before encryption (SSL). This means your substitutions
operate on the uncompressed, unencrypted content — which is what
you want.

If you stack multiple content transformation filters, they run in
the order they were added. A ``Substitute`` applied before an
``OutputSed`` will see the original content; the ``OutputSed`` will see
the already-substituted content.

.. index:: mod_filter
.. index:: FilterDeclare
.. index:: FilterProvider
.. index:: FilterChain

Conditional filtering with mod_filter
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``AddOutputFilterByType`` is good enough for most cases, but
:module:`mod_filter` gives you much finer control. You can apply a
filter based on request headers, environment variables, response
headers, or content type — and you can build conditional pipelines:

.. code-block:: apache

   FilterDeclare  rewrite_urls CONTENT_SET
   FilterProvider rewrite_urls SUBSTITUTE "%{Content_Type} =~ /text\/html/"
   FilterChain    rewrite_urls

This declares a filter called ``rewrite_urls``, tells httpd to use the
SUBSTITUTE provider when the content type is ``text/html``, and adds it
to the filter chain. The ``FilterProvider`` directive can test against
any of the standard httpd variables, giving you conditional logic that
``AddOutputFilterByType`` alone can't express.


.. index:: mod_ext_filter
.. index:: ExtFilterDefine

The escape hatch: mod_ext_filter
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When none of the built-in filter modules do what you need,
:module:`mod_ext_filter` lets you pipe the response body through an
arbitrary external program. Define the filter, then add it to the
chain:

.. code-block:: apache

   ExtFilterDefine fix-encoding cmd="/usr/bin/iconv -f ISO-8859-1 -t UTF-8"

   <Location "/legacy-app">
       SetOutputFilter fix-encoding
   </Location>

This is powerful — you can use any command-line tool — but it comes at
a cost. Every request that triggers the filter forks a new process, which
is slow and resource-intensive under load. Use :module:`mod_ext_filter`
as a last resort: for prototyping, for low-traffic endpoints, or when
the transformation is truly impossible with the built-in modules.


Putting it all together
~~~~~~~~~~~~~~~~~~~~~~~

The key insight for this book's narrative: :module:`mod_rewrite`
transforms the *request* — the URL, headers, and environment variables
that determine what content the server will produce or fetch.  The
filter modules discussed in this chapter transform the *response* — the
actual content that the client receives.

They're complementary tools. A typical reverse proxy configuration might
use :module:`mod_rewrite` (or ``ProxyPass``) to route requests to the
correct backend, ``ProxyPassReverse`` to fix response headers, and then
:module:`mod_substitute` or :module:`mod_proxy_html` to fix URLs
embedded in the response body. Understanding both sides of the
request-response lifecycle gives you full control over how your server
behaves.
