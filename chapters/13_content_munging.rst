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
   |    Lived the Yonghy-Bonghy-Bò.

   -- Edward Lear, *The Courtship of the Yonghy-Bonghy-Bò*



While mod_rewrite modifies aspects of the HTTP request - most commonly
the REQUEST_URI, sometimes you want to modify the content which is
served to the client. There are several modules that do this, which can
be used in a variety of circumstances.

We're going to look at three of these modules, and then at Filters in
general.

.. _mod_substitute:


.. index:: mod_substitute
.. index:: pair: modules; mod_substitute

mod_substitute
--------------

.. todo:: ``mod_substitute`` performs search-and-replace on the response
   body using ``sed``-like syntax: ``Substitute s/pattern/replacement/[flags]``.
   Flags: ``i`` (case-insensitive), ``n`` (treat pattern as literal string),
   ``f`` (flatten line breaks — process as one buffer), ``q`` (quote/escape
   the replacement). Common uses: rewriting absolute URLs in HTML served
   from a backend, replacing hostnames after a migration, injecting
   tracking snippets. Show the ``SubstituteMaxLineLength`` directive for
   handling long lines. Note that this operates on the output filter
   chain — it modifies the response, not the request.

   Example: rewrite all references to the old domain in proxied content::

      Substitute "s|http://old.example.com|https://new.example.com|ni"


.. _mod_sed:


.. index:: mod_sed
.. index:: pair: modules; mod_sed

mod_sed
-------

.. todo:: ``mod_sed`` applies the full ``sed`` stream-editing language
   to request and response bodies. ``OutputSed`` filters response
   content; ``InputSed`` filters request content (e.g., POST bodies).
   More powerful than ``mod_substitute`` — supports ``sed`` addresses,
   multiple commands, hold/pattern space — but also more complex and
   less commonly needed. Show a simple example using ``OutputSed`` to
   strip a particular HTML element from proxied content.

   Compare with ``mod_substitute``: for simple search-and-replace,
   ``mod_substitute`` is easier and sufficient. Reach for ``mod_sed``
   when you need ``sed``'s full addressing and multi-command capability.


.. _mod_proxy_html:


.. index:: mod_proxy_html
.. index:: pair: modules; mod_proxy_html

mod_proxy_html
--------------

.. todo:: ``mod_proxy_html`` is purpose-built for reverse proxy
   scenarios: it parses HTML and rewrites URLs in links, forms, and
   other elements so that they point to the proxy's address rather
   than the backend's. Directives: ``ProxyHTMLURLMap`` (the main
   rewrite rule), ``ProxyHTMLEnable``, ``ProxyHTMLExtended`` (also
   fix URLs in inline CSS and JavaScript), ``ProxyHTMLDocType``.

   Compare with ``mod_substitute``: ``mod_proxy_html`` understands
   HTML structure (elements, attributes) and rewrites only actual URLs,
   not arbitrary text matches. This makes it safer for link rewriting
   but useless for non-HTML content.

   Common use case: you proxy ``/app`` to ``http://backend:8080/``
   and need all ``href`` and ``src`` attributes in the response
   rewritten from ``/`` to ``/app/``. Show a worked example with
   ``ProxyHTMLURLMap``.


.. _filters:


.. index:: filters
.. index:: pair: Apache HTTP Server; filters

Filters
-------

.. todo:: Generalize the above: all three modules are implemented as
   httpd output filters. Briefly explain the filter chain concept —
   content passes through a pipeline of filters before reaching the
   client. ``AddOutputFilterByType`` controls which filters apply
   to which content types. ``FilterChain``, ``FilterDeclare``,
   ``FilterProvider`` (from ``mod_filter``) offer a more flexible
   way to conditionally apply filters.

   Mention ``mod_ext_filter`` as an escape hatch: it pipes the
   response body through an arbitrary external program. Powerful
   but slow — use it only when no built-in module does what you need.

   Key point for the book's narrative: ``mod_rewrite`` transforms
   the *request* (URL, headers, environment); the filter modules
   discussed here transform the *response* (body content). They're
   complementary tools, and understanding both gives you full control
   over the request-response lifecycle.
