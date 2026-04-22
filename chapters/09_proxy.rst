.. _Chapter_proxy:


=======================
Proxies and mod_rewrite
=======================

.. epigraph::

   | And the Animals said, 'O Eldest Magician, what shall we
   | play at?' and he said, 'I will show you.'

   -- Rudyard Kipling, *The Crab That Played with the Sea*


This chapter explores the intersection of :module:`mod_rewrite` and
:module:`mod_proxy` — using rewrite rules to make proxying decisions
dynamically.

Chapter 2 introduced ``ProxyPass`` and ``ProxyPassReverse`` as static
URL mapping tools. Here we go further: using the ``[P]`` flag to proxy
selectively, conditionally, and with URL transformations that
``ProxyPass`` alone cannot express.


The mod_proxy family
--------------------

.. index:: mod_proxy
.. index:: pair: proxy; protocol modules

:module:`mod_proxy` is the core module — it provides the framework and the
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

:module:`mod_proxy_http`
   The workhorse. Proxies HTTP and HTTPS requests to backend servers.
   This is what you load for a standard reverse proxy.

:module:`mod_proxy_http2`
   Proxies requests to backends using HTTP/2. The backend must support
   HTTP/2 — there is no fallback to HTTP/1.1. Use this when your backend
   is an HTTP/2 server (e.g., gRPC services). :version:`2.4.19` Available since httpd 2.4.19.

**Application server protocols:**

:module:`mod_proxy_fcgi`
   FastCGI support. The most common way to connect httpd to PHP-FPM,
   Python WSGI servers behind FastCGI adapters, and similar application
   servers. Supports both TCP and Unix domain sockets.

:module:`mod_proxy_ajp`
   Apache JServ Protocol (AJP/1.3) — primarily used with Apache Tomcat
   and other Java servlet containers. AJP is a binary protocol that's
   more efficient than HTTP for proxy-to-backend communication, though
   it requires the backend to support it.

:module:`mod_proxy_uwsgi`
   The uWSGI protocol — used by the uWSGI application server, popular
   in the Python/Django ecosystem. :version:`2.4.30` Available since httpd 2.4.30.

:module:`mod_proxy_scgi`
   The Simple Common Gateway Interface — a simpler alternative to
   FastCGI, used by some Python and Ruby application servers.

**WebSockets and tunneling:**

:module:`mod_proxy_wstunnel`
   WebSocket tunneling. Proxies WebSocket connections (``ws://`` and
   ``wss://``) to a backend WebSocket server. :version:`2.4.5` Available since httpd 2.4.5.
   Note: since httpd :version:`2.4.47`, protocol upgrades (including WebSocket)
   can also be handled by :module:`mod_proxy_http` directly — making
   :module:`mod_proxy_wstunnel` less critical than it once was.

:module:`mod_proxy_connect`
   Handles the HTTP ``CONNECT`` method, used primarily for SSL/TLS
   tunneling through a forward proxy. If you're running a forward proxy
   that needs to pass HTTPS traffic, you need this.

:module:`mod_proxy_fdpass`
   Passes the client socket's file descriptor to another process via
   a Unix domain socket. A niche module for specialized architectures
   where another daemon handles the actual request. Unix only.

**Legacy protocols:**

:module:`mod_proxy_ftp`
   Proxies FTP requests. Allows clients to access FTP resources through
   the web server using HTTP. Limited to ``GET`` — you can retrieve
   files but not upload. Mostly a legacy feature at this point.

**Load balancing and health checks:**

:module:`mod_proxy_balancer`
   Adds load balancing across multiple backend servers. Supports
   several scheduling algorithms (by request count, by traffic, by
   busyness) via the ``mod_lbmethod_*`` modules. Includes a built-in
   web-based Balancer Manager for runtime configuration.

:module:`mod_proxy_hcheck`
   Dynamic health checking of backend workers. Periodically probes
   backends and automatically marks them as unavailable when they fail.
   Replaces the need for external health-check daemons in many
   configurations. :version:`2.4.21` Available since httpd 2.4.21.

**Dynamic configuration:**

:module:`mod_proxy_express`
   Mass reverse proxying via DBM file lookup — maps hostnames to
   backends without per-host configuration. Covered in
   :ref:`ch02_mod_proxy_express`.

**Response rewriting:**

:module:`mod_proxy_html`
   Parses HTML responses and rewrites URLs in links, forms, and
   scripts so they point to the proxy rather than the backend. Covered
   in :ref:`Chapter_content_munging`.


Which modules to load
~~~~~~~~~~~~~~~~~~~~~

You always need :module:`mod_proxy` itself plus at least one protocol module.
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


A common :module:`mod_rewrite` pitfall: using the ``[P]`` flag without
loading the appropriate protocol module. The rewrite will silently fail
or produce a 500 error — check your error log for "No protocol handler
was valid."


When to use [P] vs ProxyPass
----------------------------

.. index:: pair: proxy; ProxyPass vs [P]
.. index:: pair: flags; P (proxy)

The httpd documentation itself says: "Consider using ``ProxyPass`` or
``ProxyPassMatch`` whenever possible in preference to
:module:`mod_rewrite`." That's good advice, and here's why.

``ProxyPass`` is a static mapping. It's fast, simple, and handles
connection pooling to the backend natively. The proxy worker is
pre-configured at startup, so httpd can reuse connections, enforce
timeouts, and manage retry logic without any per-request overhead:

.. code-block:: apache

   ProxyPass        "/app" "http://backend:8080/app"
   ProxyPassReverse "/app" "http://backend:8080/app"

The ``[P]`` flag on a ``RewriteRule`` achieves the same result, but
it creates an *ad hoc* proxy request at the end of the rewrite
processing — it doesn't benefit from a pre-configured worker's
connection pool, and it's evaluated later in the request lifecycle.

So when do you actually need ``[P]``? When ``ProxyPass`` can't express
what you need:

- **Regex-based URL transformation** — you need to capture parts of the
  URL and rearrange them in the backend path.
- **Conditional proxying** — you want to proxy only when certain
  ``RewriteCond`` tests pass (a header value, a cookie, a missing local
  file).
- **Dynamic backend selection** — you're using a ``RewriteMap`` to look
  up which backend to send the request to.

``ProxyPassMatch`` covers some of the regex cases, but it can't do
conditional logic. If you need both regex and conditions, ``[P]`` is
your tool.


Basic proxying with [P]
-----------------------

.. index:: pair: proxy; basic [P] example
.. index:: ProxyPassReverse

The simplest ``[P]`` example looks like this:

.. code-block:: apache

   RewriteEngine On
   RewriteRule   ^/app/(.*)$ http://backend:8080/$1 [P]
   ProxyPassReverse "/app/" "http://backend:8080/"

A request for ``/app/dashboard`` is rewritten to
``http://backend:8080/dashboard`` and proxied to the backend.

Note the ``ProxyPassReverse`` — it's still required even when you're
using ``[P]`` instead of ``ProxyPass``. Here's why: when the backend
sends a redirect response (a ``Location`` header like
``Location: http://backend:8080/login``), ``ProxyPassReverse`` rewrites
that header so the client sees ``/app/login`` instead of the internal
backend URL. Without it, redirects from the backend will expose the
backend's address to the client — or simply break, because the client
can't reach the internal hostname.


Conditional proxying
--------------------

.. index:: pair: proxy; conditional
.. index:: pair: RewriteCond; proxy decisions

This is where ``[P]`` really earns its keep — making the proxy decision
based on conditions that ``ProxyPass`` can't evaluate.

**Proxy when a local file doesn't exist** — a common migration pattern
where you're gradually moving content from a backend to the local
server:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule ^/(.*)$ http://old-backend.internal/$1 [P]
   ProxyPassReverse "/" "http://old-backend.internal/"

Requests for files that exist locally are served directly. Everything
else is proxied to the old backend. As you migrate content, you simply
add the files locally and they take precedence automatically.

**Proxy based on a header or cookie** — for example, routing beta
users to a different backend:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_COOKIE} beta=true
   RewriteRule ^/(.*)$ http://beta-backend:8080/$1 [P]
   ProxyPassReverse "/" "http://beta-backend:8080/"

**Pattern-based backend selection** — sending different URL paths to
different backends:

.. code-block:: apache

   RewriteEngine On
   RewriteRule ^/api/(.*)$    http://api-server:8080/$1    [P]
   RewriteRule ^/static/(.*)$ http://asset-server:9090/$1  [P]

This works, but be cautious about using it as a load balancer. If
you're splitting traffic across multiple backends for the *same* path
to distribute load, use :module:`mod_proxy_balancer` instead — it
handles health checks, failover, session stickiness, and scheduling
algorithms that ``[P]`` rules can't replicate.


Proxying with RewriteMap
------------------------

.. index:: pair: proxy; RewriteMap
.. index:: pair: RewriteMap; dynamic backend selection

For truly dynamic backend selection, combine ``[P]`` with a
``RewriteMap`` (see :ref:`Chapter_rewritemap`). A text map file can
map request paths — or any other variable — to backend URLs:

.. code-block:: none

   # /etc/httpd/conf/backend.map
   widgets   http://widget-server:8080
   gadgets   http://gadget-server:8080
   default   http://fallback-server:8080

.. code-block:: apache

   RewriteMap backends txt:/etc/httpd/conf/backend.map
   RewriteRule ^/store/([^/]+)/(.*)$ ${backends:$1|http://fallback-server:8080}/$2 [P]

A request for ``/store/widgets/product/42`` looks up ``widgets`` in the
map and proxies to ``http://widget-server:8080/product/42``.

For the simpler case of mapping hostnames to backends (mass virtual
hosting), :module:`mod_proxy_express` does this natively with a DBM
file and no rewrite rules — see :ref:`ch02_mod_proxy_express`. Reach
for ``RewriteMap`` + ``[P]`` when you need more complex lookup logic
than a straight hostname-to-backend mapping.


SSL/TLS considerations
----------------------

.. index:: pair: proxy; SSL/TLS
.. index:: SSLProxyEngine
.. index:: SSLProxyVerify
.. index:: ProxyPreserveHost

When your backend uses HTTPS, you need to enable the SSL proxy engine:

.. code-block:: apache

   SSLProxyEngine On
   RewriteRule ^/secure/(.*)$ https://backend.internal/$1 [P]

By default, httpd will verify the backend's SSL certificate. If the
backend uses a self-signed or internal CA certificate, you'll need to
either provide the CA certificate or (in development only) disable
verification:

.. code-block:: apache

   # Point to your internal CA
   SSLProxyCACertificateFile /etc/pki/tls/certs/internal-ca.pem

   # OR, for development only — never in production
   SSLProxyVerify none
   SSLProxyCheckPeerCN off
   SSLProxyCheckPeerName off

**The redirect loop trap**: a common pitfall when proxying between HTTP
and HTTPS. If the backend redirects HTTP to HTTPS (as many applications
do), and your proxy is also doing protocol translation, you can end up
in an infinite redirect loop. The fix is usually to ensure the backend
knows it's behind a proxy — either via ``ProxyPreserveHost On`` (so
the backend sees the original ``Host`` header) or by setting the
``X-Forwarded-Proto`` header so the backend knows the client's original
protocol:

.. code-block:: apache

   RequestHeader set X-Forwarded-Proto "https"
   ProxyPreserveHost On

Most modern web frameworks check ``X-Forwarded-Proto`` and suppress
their HTTP-to-HTTPS redirect when they see the client is already on
HTTPS.


Rewriting proxied responses
---------------------------

``ProxyPassReverse`` rewrites ``Location`` and other response *headers*,
but it doesn't touch the response *body*. If your backend embeds
hardcoded URLs in its HTML, you'll need :module:`mod_proxy_html` or
:module:`mod_substitute` to fix them. These are covered in detail in
:ref:`Chapter_content_munging`.


Common pitfalls
---------------

.. index:: pair: proxy; common mistakes
.. index:: pair: proxy; troubleshooting

A quick rundown of the mistakes you'll make at least once (I certainly
have):

**Forgetting ProxyPassReverse.**
Everything appears to work until the backend sends a redirect, and the
client gets a ``Location`` header pointing to your internal backend
hostname. Always pair ``[P]`` with a matching ``ProxyPassReverse``.

**Not loading the right modules.**
``[P]`` requires :module:`mod_proxy` *and* the appropriate protocol
module (:module:`mod_proxy_http`, :module:`mod_proxy_fcgi`, etc.). A
missing module produces a 500 error and the log message "No protocol
handler was valid for the URL."

**Combining [P] and [R].**
These flags are mutually exclusive. ``[P]`` proxies the request to the
backend silently; ``[R]`` sends a redirect to the client. You can't do
both. If you want to redirect and then have the *client's* new request
be proxied, that's two separate rules.

**DNS resolution timing.**
``ProxyPass`` resolves the backend hostname at server startup.
``RewriteRule ... [P]`` resolves it at request time. This means
``[P]`` is more resilient to DNS changes (the backend IP can change
without a server restart), but it also means a DNS lookup on every
request — which can be slow if your DNS is unreliable. For
``ProxyPass``, a ``disablereuse=On`` option forces per-request DNS,
but at the cost of connection pooling.

**Timeout and retry behavior.**
When a backend is slow or down, the default proxy timeout is inherited
from the server's global ``Timeout`` directive (usually 60 seconds).
You can tune this per-backend with ``ProxyPass`` parameters:

.. code-block:: apache

   ProxyPass "/app" "http://backend:8080/app" timeout=10 retry=30

``timeout`` controls how long to wait for the backend to respond;
``retry`` controls how long a failed backend is taken out of rotation
before httpd tries it again. With ``[P]`` rules, these per-worker
tuning options aren't available — another reason to prefer
``ProxyPass`` when you can.
