.. _Chapter_proxy:


=======================
Proxies and mod_rewrite
=======================

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


The mod_proxy family
--------------------

.. index:: mod_proxy
.. index:: pair: proxy; protocol modules

``mod_proxy`` is the core module — it provides the framework and the
``ProxyPass``, ``ProxyPassReverse``, and ``ProxyPassMatch`` directives.
By itself it does nothing; you pair it with one or more protocol modules
that handle the actual communication with backends. These are the
protocol modules available as of httpd 2.5 (trunk):


.. index:: mod_proxy_http
.. index:: mod_proxy_http2
.. index:: mod_proxy_fcgi
.. index:: mod_proxy_ajp
.. index:: mod_proxy_uwsgi
.. index:: mod_proxy_scgi
.. index:: mod_proxy_wstunnel
.. index:: mod_proxy_ftp
.. index:: mod_proxy_connect
.. index:: mod_proxy_fdpass
.. index:: mod_proxy_balancer
.. index:: mod_proxy_hcheck
.. index:: mod_proxy_express

**HTTP/HTTPS backends:**

``mod_proxy_http``
   The workhorse. Proxies HTTP and HTTPS requests to backend servers.
   This is what you load for a standard reverse proxy.

``mod_proxy_http2``
   Proxies requests to backends using HTTP/2. The backend must support
   HTTP/2 — there is no fallback to HTTP/1.1. Use this when your backend
   is an HTTP/2 server (e.g., gRPC services). :version:`2.4.19` Available since httpd 2.4.19.

**Application server protocols:**

``mod_proxy_fcgi``
   FastCGI support. The most common way to connect httpd to PHP-FPM,
   Python WSGI servers behind FastCGI adapters, and similar application
   servers. Supports both TCP and Unix domain sockets.

``mod_proxy_ajp``
   Apache JServ Protocol (AJP/1.3) — primarily used with Apache Tomcat
   and other Java servlet containers. AJP is a binary protocol that's
   more efficient than HTTP for proxy-to-backend communication, though
   it requires the backend to support it.

``mod_proxy_uwsgi``
   The uWSGI protocol — used by the uWSGI application server, popular
   in the Python/Django ecosystem. :version:`2.4.30` Available since httpd 2.4.30.

``mod_proxy_scgi``
   The Simple Common Gateway Interface — a simpler alternative to
   FastCGI, used by some Python and Ruby application servers.

**WebSockets and tunneling:**

``mod_proxy_wstunnel``
   WebSocket tunneling. Proxies WebSocket connections (``ws://`` and
   ``wss://``) to a backend WebSocket server. :version:`2.4.5` Available since httpd 2.4.5.
   Note: since httpd :version:`2.4.47`, protocol upgrades (including WebSocket)
   can also be handled by ``mod_proxy_http`` directly — making
   ``mod_proxy_wstunnel`` less critical than it once was.

``mod_proxy_connect``
   Handles the HTTP ``CONNECT`` method, used primarily for SSL/TLS
   tunneling through a forward proxy. If you're running a forward proxy
   that needs to pass HTTPS traffic, you need this.

``mod_proxy_fdpass``
   Passes the client socket's file descriptor to another process via
   a Unix domain socket. A niche module for specialized architectures
   where another daemon handles the actual request. Unix only.

**Legacy protocols:**

``mod_proxy_ftp``
   Proxies FTP requests. Allows clients to access FTP resources through
   the web server using HTTP. Limited to ``GET`` — you can retrieve
   files but not upload. Mostly a legacy feature at this point.

**Load balancing and health checks:**

``mod_proxy_balancer``
   Adds load balancing across multiple backend servers. Supports
   several scheduling algorithms (by request count, by traffic, by
   busyness) via the ``mod_lbmethod_*`` modules. Includes a built-in
   web-based Balancer Manager for runtime configuration.

``mod_proxy_hcheck``
   Dynamic health checking of backend workers. Periodically probes
   backends and automatically marks them as unavailable when they fail.
   Replaces the need for external health-check daemons in many
   configurations. :version:`2.4.21` Available since httpd 2.4.21.

**Dynamic configuration:**

``mod_proxy_express``
   Mass reverse proxying via DBM file lookup — maps hostnames to
   backends without per-host configuration. Covered in
   :ref:`ch02_mod_proxy_express`.

**Response rewriting:**

``mod_proxy_html``
   Parses HTML responses and rewrites URLs in links, forms, and
   scripts so they point to the proxy rather than the backend. Covered
   in :ref:`Chapter_content_munging`.


Which modules to load
~~~~~~~~~~~~~~~~~~~~~

You always need ``mod_proxy`` itself plus at least one protocol module.
A typical reverse proxy configuration loads:


.. code-block:: apache

   LoadModule proxy_module        modules/mod_proxy.so
   LoadModule proxy_http_module   modules/mod_proxy_http.so


For a PHP-FPM setup:


.. code-block:: apache

   LoadModule proxy_module        modules/mod_proxy.so
   LoadModule proxy_fcgi_module   modules/mod_proxy_fcgi.so


For load-balanced backends with health checks:


.. code-block:: apache

   LoadModule proxy_module          modules/mod_proxy.so
   LoadModule proxy_http_module     modules/mod_proxy_http.so
   LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
   LoadModule proxy_hcheck_module   modules/mod_proxy_hcheck.so
   LoadModule lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so


A common ``mod_rewrite`` pitfall: using the ``[P]`` flag without
loading the appropriate protocol module. The rewrite will silently fail
or produce a 500 error — check your error log for "No protocol handler
was valid."


When to use [P] vs ProxyPass
----------------------------

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

