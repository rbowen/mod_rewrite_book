.. _conditional-configuration:


.. index:: conditional configuration
.. index:: pair: configuration; conditional

=========================
Conditional Configuration
=========================

.. epigraph::

   | Any sufficiently advanced technology is indistinguishable from magic.

   -- Arthur C. Clarke, *Profiles of the Future*



.. _introduction:


.. index:: pair: Apache HTTP Server; version 2.4 configuration

Introduction
------------


While the Apache httpd configuration files have always had some ways to
make things conditional, with the advent of version 2.4, there's an
explosion in the ways that you can make your configuration file reactive
and programmable. That is, you can make your configuration more
responsive to the specifics of the request that it servicing.

In this part of the book, we discuss some of this functionality. Some of
it is specific to version 2.4 and later, while some of it has been
available for years.

.. index:: IfModule
.. index:: pair: directives; IfModule
.. index:: IfVersion
.. index:: pair: directives; IfVersion


.. _match-directive:


.. index:: FilesMatch
.. index:: pair: directives; FilesMatch
.. index:: RedirectMatch
.. index:: pair: directives; RedirectMatch

Match Directives
----------------


Several Apache httpd directives have ``Match`` variants that accept
regular expressions instead of simple strings. If you're comfortable
with regex (and by now you should be — you read Chapter 1), these give
you a lot of power without reaching for :module:`mod_rewrite`.

``FilesMatch``
   Works like ``<Files>``, but matches filenames against a regex:

   .. code-block:: apache

      # Deny access to editor backup files
      <FilesMatch "\.(bak|orig|swp)$">
          Require all denied
      </FilesMatch>

``DirectoryMatch``
   Like ``<Directory>``, but with a regex path:

   .. code-block:: apache

      <DirectoryMatch "^/var/www/[0-9]{4}/archive">
          Options -Indexes
      </DirectoryMatch>

``LocationMatch``
   Like ``<Location>``, but with a regex URL-path:

   .. code-block:: apache

      <LocationMatch "^/api/v[0-9]+/">
          Header set X-API true
      </LocationMatch>

``RedirectMatch``
   ``Redirect`` with regex support and backreferences:

   .. code-block:: apache

      # /docs/2023/report.html → /archive/2023/report.html
      RedirectMatch 301 "^/docs/([0-9]{4})/(.*)$" "/archive/$1/$2"

``ScriptAliasMatch``
   Maps URL patterns to CGI directories:

   .. code-block:: apache

      ScriptAliasMatch "^/cgi-bin/(admin|user)/(.*)$" "/usr/local/cgi/$1/$2"

These are all worth knowing about because they're often a better fit
than a ``RewriteRule`` for straightforward pattern-based matching. They
make the configuration's intent clear to anyone reading it, and they
don't require ``RewriteEngine On``.

.. _ifdefine:


.. index:: IfDefine
.. index:: pair: directives; IfDefine
.. index:: pair: command-line switches; -D flag

IfDefine
--------


The ``IfDefine`` directive provides a way to make blocks of your
configuration file optional, depending on the presence, or absence, of
an appropriate command-line switch. Specifically, a configuration block
wrapped in an ``<IfDefine XYZ>`` container will be invoked if and only if
the server is started up with a ``-D XYZ`` command line switch.

Consider, for example a configuration as follows:


.. code-block:: apache

   <IfDefine TEST>
       ServerName test.example.com
   </IfDefine>
   <IfDefine !TEST>
       ServerName www.example.com
   </IfDefine>


Now, you can start the server with a ``-D TEST`` command line option:


.. code-block:: apache

   httpd -D TEST -k restart


This will result in the first of the two ``IfDefine`` blocks being loaded.
Conversely, if you omit the ``-D TEST`` flag, the server will start with
the second of the two ``IfDefine`` blocks loaded.

This gives the ability to keep several configurations in the same file,
and load various components on demand. You could even deploy the same
configuration file to several different servers, but start each with
different command line flags (you can specify more than one ``-D`` flag at
startup) to start the servers up in different configurations.

``<IfDefine>`` blocks can be nested, so that you can combine several
conditions, as seen in this example from the docs:


.. code-block:: apache

   <IfDefine ReverseProxy>
       LoadModule proxy_module   modules/mod_proxy.so
       LoadModule proxy_http_module modules/mod_proxy_http.so
       <IfDefine UseCache>
           LoadModule cache_module modules/mod_cache.so
           <IfDefine MemCache>
               LoadModule mem_cache_module modules/mod_mem_cache.so
           </IfDefine>
           <IfDefine !MemCache>
               LoadModule cache_disk_module modules/mod_cache_disk.so
           </IfDefine>
       </IfDefine>
   </IfDefine>


You could then, for example, start the server up with:

.. code-block:: none

   httpd -DReverseProxy -DUseCache -DMemCache -k restart

(The space between ``-D`` and the flag is optional.)

.. _define:


.. index:: Define
.. index:: pair: directives; Define

Define
------


New with the 2.3 (and later) version of the server is the ``Define``
directive, which lets you define variables within the configuration
file, which can then be used later on in the configuration, either as
part of a configuration directive, or in an ``<IfDefine ...>`` directive.

Consider this variation on the earlier example:


.. code-block:: apache

   <IfDefine TEST>
       Define servername test.example.com
   </IfDefine>
   <IfDefine !TEST>
       Define servername www.example.com
       Define SSL
   </IfDefine>
   
   DocumentRoot /var/www/${servername}/htdocs


A variable ``VAR`` defined with the ``Define`` directive can then be used
later using the ``${VAR}`` syntax, as shown here. In the case where no
value is given (see the line ``Define SSL``) the variable is set to
``TRUE``, which can then be tested later using an ``<IfDefine>`` test.

In this example, as before, the server should be started with a ``-DTEST``
command line option to use the first definition of ``servername`` and
without it to use the second.

Or you can use a ``Define`` directive to define something, such as a file
path, which is then used several times in the configuration:


.. code-block:: apache

   Define docroot /var/www/vhosts/www.example.com
   
   DocumentRoot ${docroot}
   
   <Directory ${docroot}>
       Require all granted
   </Directory>


.. _if-elsif-and-else:


.. index:: If directive
.. index:: pair: directives; If
.. index:: ElseIf directive
.. index:: pair: directives; ElseIf
.. index:: Else directive
.. index:: pair: directives; Else
.. index:: ap_expr
.. index:: expression parser

<If>, <Elsif>, and <Else>
-------------------------


New in Apache httpd 2.4 is the ability to put ``<If>`` blocks in your
configuration file to make it truly conditional. This provides a level
of flexibility that was never before available.

Whereas the ``<IfDefine>`` and ``<Define>`` directives are evaluated at
server startup time, ``<If>`` is evaluated at request time, giving you the
chance to make configuration dependant on values that may change from
one HTTP request to another. Naturally, this results in some
request-time overhead, but the flexibility that you gain may be worth
this to you in some situations.

Consider the following examples to give you some ideas:

.. _canonical-hostname:


.. index:: pair: If directive; canonical hostname example

Canonical hostname
^^^^^^^^^^^^^^^^^^


In many situations, it is desirable to enforce a particular hostname on
your website. For example, if you are setting cookies, you need to
ensure that those cookies are valid for all requests to your site, which
requires that the hostname being accessed match the hostname on the
cookie itself. So, when someone accesses your site using the hostname
``example.com``, you want to redirect that request to use the hostname
``www.example.com``.

In previous versions of httpd, you may have used :module:`mod_rewrite` to
perform this redirection, but ``<If>`` provides a more intuitive syntax:


.. code-block:: apache

   # Compare the host name to example.com and 
   # redirect to www.example.com if it matches
   <If "%{HTTP_HOST} == 'example.com'">
       Redirect permanent / http://www.example.com/
   </If>


.. _image-hotlinking:


.. index:: pair: If directive; hotlinking example

Image hotlinking
^^^^^^^^^^^^^^^^


You may wish to prevent another website from embedding your images in
their pages - so-called image hotlinking. This is usually done by
comparing the HTTP_REFERER variable on a request to these images to
ensure that the request originated within a page on your site:


.. code-block:: apache

   # Images ...
   <FilesMatch "\.(gif|jpe?g|png)$">
       # Check to see that the referer is right
       <If "%{HTTP_REFERER} !~ /example.com/" >
           Require all denied
       </If>
   </FilesMatch>


.. _ap-expr:


.. index:: ap_expr
.. index:: expression parser
.. index:: pair: expressions; ap_expr
.. index:: pair: <If>; expression syntax

The expression parser (ap_expr)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


The ``<If>`` examples above use a powerful expression syntax called
``ap_expr``. This is httpd 2.4's general-purpose expression parser, and
it appears in more places than just ``<If>`` blocks:

- ``<If>``, ``<ElseIf>`` — conditional configuration sections
- ``RewriteCond`` with the ``expr`` TestString
  (see :ref:`Chapter_rewritecond`)
- ``SetEnvIfExpr`` — conditional environment variables
- ``CustomLog`` with ``expr=`` — conditional logging
- ``Header`` and ``RequestHeader`` with ``expr=``
- ``<AuthzProviderAlias>`` and ``Require expr``

The expression language supports:

- **String comparisons**: ``==``, ``!=``, ``<``, ``>``, ``<=``, ``>=``
- **Regex matching**: ``=~``, ``!~``
- **Integer comparisons**: ``-eq``, ``-ne``, ``-lt``, ``-le``,
  ``-gt``, ``-ge``
- **Unary file tests**: ``-d``, ``-f``, ``-s``, ``-L``, ``-e``,
  ``-F``, ``-U`` (same ones available in ``RewriteCond``)
- **IP matching**: ``-ipmatch`` for CIDR notation
  (e.g. ``-ipmatch '10.0.0.0/8'``)
- **String functions**: ``tolower()``, ``toupper()``, ``escape()``,
  ``base64()``, ``md5()``, ``sha1()``, ``file()``, ``filesize()``
- **Request functions**: ``req('Header-Name')``, ``resp()``,
  ``reqenv()``, ``osenv()``, ``note()``
- **Boolean logic**: ``&&``, ``||``, ``!``, parentheses for grouping
- **List operator**: ``word -in {list}``

I covered the comparison operators and file tests in detail in
:ref:`Chapter_rewritecond`, since that's where most people first
encounter them. The same operators work identically in ``ap_expr``
contexts.

The full expression syntax is documented at
https://httpd.apache.org/docs/2.4/expr.html. It's a dense reference
page, but it's comprehensive. Bookmark it — you'll refer to it often
once you start using ``<If>`` and ``SetEnvIfExpr`` in earnest.


.. _mod_macro:


.. index:: mod_macro
.. index:: pair: modules; mod_macro

mod_macro
---------


:module:`mod_macro` has been around for a while, but with the 2.4 version of the
server it is now one of the modules that comes with the server itself,
rather than being a third-party module obtained and installed
separately.

It provides the ability - as the name suggests - to create macros within
your configuration file, which can then be invoked multiple times, in
order to produce several similar configuration blocks. Parameters can be
provided to fill in the variables in those macros.

Macros are evaluated at server startup time, and the resulting
configuration is then loaded as though it was a static configuration
file on disk.

.. _mod_proxy_express:


.. index:: mod_proxy_express
.. index:: pair: modules; mod_proxy_express

mod_proxy_express
-----------------


:module:`mod_proxy_express` is a mass reverse-proxy engine. Where
:module:`mod_proxy` with ``ProxyPass`` requires you to define each backend
explicitly, ``mod_proxy_express`` reads a DBM map file and routes
requests based on the incoming ``Host`` header — no per-host
configuration blocks needed.

The setup is minimal. First, create a plain text map:

.. code-block:: none

   # express-map.txt
   www1.example.com  http://192.168.211.2:8080
   www2.example.com  http://192.168.211.12:8088
   www3.example.com  http://192.168.212.10

Convert it to a DBM file:

.. code-block:: bash

   httxt2dbm -i express-map.txt -o express-map

Then enable it in your server config:

.. code-block:: apache

   ProxyExpressEnable on
   ProxyExpressDBMFile /path/to/express-map

That's the entire configuration. A request with
``Host: www2.example.com`` is proxied to
``http://192.168.211.12:8088``. Adding a new backend is a matter of
adding a line to the text file, re-running ``httxt2dbm``, and doing a
graceful restart.

This module doesn't support regex or pattern matching — it's a
straight hostname-to-backend lookup. If you need more sophisticated
routing (path-based proxying, load balancing, failover), use
``ProxyPass`` and ``ProxyPassReverse`` directly. But for the
"I have hundreds of domains that each map to a backend" case,
``mod_proxy_express`` is hard to beat.


.. _mod_vhost_alias:


.. index:: mod_vhost_alias
.. index:: pair: modules; mod_vhost_alias

mod_vhost_alias
---------------


:module:`mod_vhost_alias` dynamically maps hostnames (or IP addresses) to
document roots using interpolation patterns, without defining individual
``<VirtualHost>`` blocks. It's the dedicated, purpose-built solution for
mass virtual hosting.

The core directive is ``VirtualDocumentRoot``. You give it a pattern
string, and it constructs the document root from parts of the
requested hostname:

.. code-block:: apache

   UseCanonicalName Off
   VirtualDocumentRoot /var/www/vhosts/%0

A request for ``http://blog.example.com/index.html`` serves
``/var/www/vhosts/blog.example.com/index.html``. The ``%0`` is replaced
by the full hostname.

The interpolation syntax supports extracting parts of the hostname by
position (``%1`` for the first dot-separated component, ``%2`` for the
second, and so on) and even individual characters within those parts.
This lets you create directory hierarchies that spread the load across
the filesystem:

.. code-block:: apache

   # blog.example.com → /var/www/vhosts/example.com/b/l/blog
   VirtualDocumentRoot /var/www/vhosts/%3+/%2.1/%2.2/%2

There's also ``VirtualScriptAlias`` for CGI directories, and ``IP``
variants of both directives (``VirtualDocumentRootIP``,
``VirtualScriptAliasIP``) that interpolate based on the server's IP
address rather than the hostname.

I covered this module briefly in :ref:`Chapter_vhosts` and recommended
it over ``mod_rewrite``-based mass vhosting in most cases. The reason
it belongs in this chapter too is that it's a prime example of
configurable configuration — one line replaces thousands of
``<VirtualHost>`` blocks.


.. _conditional-logging:


.. index:: pair: logging; conditional

Conditional logging
-------------------


There are times when you want to exclude certain requests from your
access logs — health checks from a load balancer, requests for
``robots.txt``, asset requests that would drown out the interesting
traffic. Apache's ``CustomLog`` directive supports this through
environment variable conditions and, since 2.4, through expressions.

The basic idea: set an environment variable on requests you want to
filter, then use the ``env=`` clause on ``CustomLog`` to include or
exclude those requests. You can also use conditional format strings
that log different fields depending on the HTTP response code.

I wrote the original version of this section in the httpd docs, and
it remains one of the more useful but under-discovered features.


.. _env:


.. index:: pair: logging; environment variables

env=
^^^^


The ``env=`` clause on ``CustomLog`` includes or excludes log entries
based on whether an environment variable is set. There are four
directives for setting these variables, each suited to different
situations.

``SetEnv`` (from :module:`mod_env`) unconditionally sets a variable on
every request. It's useful as a baseline that other modules may clear:

.. code-block:: apache

   # Set on every request — mod_cache will suppress it on cache hits
   SetEnv CACHE_MISS 1

``SetEnvIf`` (from :module:`mod_setenvif`) sets a variable conditionally,
based on a request attribute and a regex. The attribute can be any HTTP
request header (``User-Agent``, ``Referer``, ``Accept-Language``, etc.),
or one of the special attributes ``Remote_Addr``, ``Remote_Host``,
``Request_Method``, ``Request_Protocol``, or ``Request_URI``:

.. code-block:: apache

   # Mark requests from loopback and for robots.txt
   SetEnvIf Remote_Addr "127\.0\.0\.1" dontlog
   SetEnvIf Request_URI "^/robots\.txt$" dontlog

   # Match a specific browser family
   SetEnvIf User-Agent "Googlebot" is_bot

You can also set the value, unset a variable with ``!``, or set
multiple variables in a single directive:

.. code-block:: apache

   SetEnvIf Request_URI "^/api/" api_request !dontlog source=api

``SetEnvIfNoCase`` works identically to ``SetEnvIf`` but the regex
match is case-insensitive — useful for header values where case varies:

.. code-block:: apache

   SetEnvIfNoCase User-Agent "googlebot" is_bot
   SetEnvIfNoCase User-Agent "bingbot" is_bot

``SetEnvIfExpr`` (available since 2.4.2) uses an ``ap_expr``
expression instead of an attribute/regex pair, giving you access to the
full expression syntax — comparisons, functions, boolean logic, IP
matching, and more. See :ref:`ap-expr` above for what's available in
an expression:

.. code-block:: apache

   # Mark slow requests (> 5 seconds)
   SetEnvIfExpr "%{DURATION} -ge 5000000" slow_request

   # Mark internal network requests
   SetEnvIfExpr "-R '10.0.0.0/8'" internal

Once you've set variables, reference them in ``CustomLog`` with
``env=`` (include) or ``env=!`` (exclude):

.. code-block:: apache

   # Log everything except loopback and robots
   CustomLog logs/access_log common env=!dontlog

   # Separate log for bots
   CustomLog logs/bot_log common env=is_bot

The ``!`` negates the test — log the request only if ``dontlog`` is
*not* set.

You can also split traffic into separate logs. For example, logging
English-speaking visitors to one file and everyone else to another:

.. code-block:: apache

   SetEnvIf Accept-Language "en" english
   CustomLog logs/english_log common env=english
   CustomLog logs/non_english_log common env=!english

A clever use of this technique is measuring cache efficiency. Set an
environment variable that :module:`mod_cache` will suppress on a cache
hit:

.. code-block:: apache

   SetEnv CACHE_MISS 1
   LogFormat "%h %l %u %t \"%r\" %>s %b %{CACHE_MISS}e" common-cache
   CustomLog logs/access_log common-cache

Because :module:`mod_cache` runs before :module:`mod_env`, a cache hit
serves the content without ``mod_env`` ever executing — so
``CACHE_MISS`` logs as ``-``. A cache miss lets ``mod_env`` run
normally, logging ``1``. Scan the log for the ratio of dashes to ones
and you have your hit rate.


.. index:: pair: logging; response code conditional

Response-code conditional format strings
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


``LogFormat`` also supports logging values *conditional on the HTTP
response code*. Prefix the format token's header name with a
comma-separated list of status codes:

.. code-block:: apache

   # Log User-Agent only for 400 and 501 responses
   LogFormat "%400,501{User-agent}i" browserlog

   # Log Referer only for non-success responses
   LogFormat "%!200,304,302{Referer}i" refererlog

In the first example, the ``User-agent`` is logged if the response
status is 400 or 501; otherwise a literal ``-`` is logged. In the
second, the ``Referer`` is logged if the status is *not* 200, 304, or
302 — note the ``!`` before the status codes.

This is useful for keeping logs compact. If you only care about the
referring page when something goes wrong, there's no reason to log it
on every successful request.

Since httpd 2.4, you can also use ``expr=`` for more complex
conditions without a separate ``SetEnvIf``:

.. code-block:: apache

   # Log requests that took more than 5 seconds
   CustomLog logs/slow_log combined "expr=%D -ge 5000000"

Although conditional logging is powerful, it's worth noting that log
files are generally more useful when they contain a *complete* record of
server activity. It's often easier to log everything and post-process
the logs to remove what you don't need, rather than trying to predict at
configuration time what you'll want to see later.


.. _per-module-logging:


.. index:: pair: logging; per-module

Per-module logging
^^^^^^^^^^^^^^^^^^


As I discussed in :ref:`Chapter_rewrite_logging`, the ``LogLevel``
directive accepts per-module granularity. This isn't limited to
:module:`mod_rewrite` — you can set the log level for *any* module:

.. code-block:: apache

   # Global level warn, but trace SSL handshakes and rewrite processing
   LogLevel warn ssl:info rewrite:trace3

You can reference a module by its identifier (``ssl_module``), its
source filename (``mod_ssl.c``), or the shorthand form without the
``_module`` suffix (``ssl``). All three are equivalent.

This is invaluable for debugging — you can turn up the verbosity of
one module without drowning in output from every other module on the
server.


.. _per-directory-logging:


.. index:: pair: logging; per-directory

Per-directory logging
^^^^^^^^^^^^^^^^^^^^^


Since httpd 2.3.6, ``LogLevel`` can also be set inside ``<Directory>``,
``<Location>``, and ``<VirtualHost>`` blocks. This lets you debug a
specific path or vhost without flooding the global error log:

.. code-block:: apache

   # Debug rewrites only for the /checkout/ path
   <Location "/checkout/">
       LogLevel warn rewrite:trace4
   </Location>

I covered this in detail in :ref:`perdir-loglevel` in the Rewrite
Logging chapter. The key thing to remember is that per-directory log
level changes only affect messages generated *after* the request has
been parsed and associated with that directory context. Connection-level
messages are still controlled by the server-wide ``LogLevel``.




.. index:: pair: logging; piped

Piped logging
^^^^^^^^^^^^^


Instead of writing to a file, you can pipe log output to an external
program. The most common use is ``rotatelogs``, which ships with httpd
and handles automatic log rotation:

.. code-block:: apache

   # Rotate the access log every 24 hours (86400 seconds)
   CustomLog "|/usr/bin/rotatelogs /var/log/httpd/access_log.%Y%m%d 86400" combined

   # Rotate when the log reaches 10MB
   CustomLog "|/usr/bin/rotatelogs /var/log/httpd/access_log 10M" combined

The pipe character (``|``) tells httpd to spawn the program and send
log lines to its standard input. You can pipe to any program — people
use this for real-time log analysis, forwarding to syslog, or feeding
into monitoring pipelines.

A few things to watch out for:

- If the piped program crashes, httpd may stop logging (or buffer and
  retry, depending on the implementation). Use ``||`` (two pipes) to
  tell httpd to restart the program if it dies.
- Piped logging has a small performance overhead compared to direct
  file writes. For most sites it's negligible, but on very
  high-traffic servers it's worth benchmarking.
- The ``BufferedLogs`` directive can batch log writes for better I/O
  performance, but be aware that a crash could lose buffered entries.

For production use, ``rotatelogs`` with the ``-l`` flag (use local
time instead of UTC) and ``-f`` flag (force opening the log file on
startup) covers most rotation needs without third-party tools like
``logrotate``.
