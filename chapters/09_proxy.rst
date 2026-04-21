.. _Chapter_proxy:


==================================
Chapter 9: Proxies and mod_rewrite
==================================

.. epigraph::

   | And the Animals said, 'O Eldest Magician, what shall we
   | play at?' and he said, 'I will show you.'

   -- Rudyard Kipling, *The Crab That Played with the Sea*


This chapter explores the intersection of ``mod_rewrite`` and
``mod_proxy`` — using rewrite rules to make proxying decisions
dynamically.

Chapter 2 introduced ``ProxyPass`` and ``ProxyPassReverse`` as static
URL mapping tools. Here we go further: using the ``[P]`` flag to proxy
selectively, conditionally, and with URL transformations that
``ProxyPass`` alone cannot express.


When to use [P] vs ProxyPass
-----------------------------

.. todo:: Explain the tradeoffs. ProxyPass is simpler, faster, and
   handles connection pooling natively. [P] is needed when you must
   transform the URL with regex or make the proxy decision conditional
   (e.g., based on headers, cookies, or RewriteCond tests). Include the
   httpd docs' own advice: "Consider using ProxyPass or ProxyPassMatch
   whenever possible in preference to mod_rewrite."


Basic proxying with [P]
-----------------------

.. todo:: Simple example: ``RewriteRule ^/app/(.*)$ http://backend:8080/$1 [P]``
   plus the mandatory ``ProxyPassReverse``. Explain why ProxyPassReverse
   is still needed even when using [P] — it rewrites Location headers
   in the response.


Conditional proxying
--------------------

.. todo:: Proxy only when a local file doesn't exist (migration
   scenario): ``RewriteCond %{REQUEST_FILENAME} !-f`` before the [P]
   rule. Proxy based on a cookie or header value. Proxy different
   backends based on URL patterns — a poor man's load balancer (with
   caveats about why mod_proxy_balancer is better for that).


Proxying with RewriteMap
------------------------

.. todo:: Use a RewriteMap (txt or dbm) to look up the backend server
   dynamically based on hostname, path, or other variables. Compare
   with mod_proxy_express (introduced in ch02) for the simple case.


SSL/TLS considerations
----------------------

.. todo:: Proxying to HTTPS backends. The ``SSLProxy*`` directives.
   Common pitfall: proxying HTTP→HTTPS or HTTPS→HTTP and getting
   infinite redirect loops. ProxyPreserveHost and when you need it.


Rewriting proxied responses
---------------------------

.. todo:: Brief forward-reference to Chapter 13 (Content Munging) for
   mod_proxy_html and mod_substitute — tools for rewriting URLs inside
   the response body, not just the headers.


Common pitfalls
---------------

.. todo:: Forgetting ProxyPassReverse. Forgetting to load mod_proxy
   and the appropriate protocol module (mod_proxy_http, mod_proxy_fcgi).
   Using [P] with [R] (they're mutually exclusive). DNS resolution at
   startup vs. request time. Timeout and retry behavior.

