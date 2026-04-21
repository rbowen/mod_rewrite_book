
========
Glossary
========

.. glossary::
   :sorted:

   .htaccess
      A per-directory configuration file, placed in a directory served by
      httpd, that applies directives to that directory and its children.
      Rewrite rules in ``.htaccess`` behave differently than those in
      server config — see :ref:`rewritebase` and Chapter 3.

   AllowOverride
      A directive that controls which types of directives are permitted
      in ``.htaccess`` files. ``AllowOverride All`` enables everything;
      ``AllowOverride None`` (the 2.4 default) disables ``.htaccess``
      entirely.

   Apache HTTP Server
      The web server software, commonly called "httpd." This book covers
      version 2.4 and later, with notes on trunk (future 2.5.x) features.

   backreference
      A captured group from a regular expression match, referenced as
      ``$1`` through ``$9`` in ``RewriteRule`` substitutions and ``%1``
      through ``%9`` for ``RewriteCond`` captures. ``$0`` and ``%0``
      refer to the entire matched string.

   CGI
      Common Gateway Interface — a protocol for web servers to execute
      external programs and return their output as HTTP responses.
      ``ScriptAlias`` designates a directory whose contents are treated
      as CGI programs.

   content negotiation
      The process by which httpd selects the best representation of a
      resource based on the client's ``Accept-*`` headers.
      ``mod_negotiation`` and ``MultiViews`` implement this. See
      Chapter 2.

   CondPattern
      The second argument to ``RewriteCond`` — the pattern or expression
      that the ``TestString`` is compared against.

   directive
      A configuration command in the httpd configuration file (or
      ``.htaccess``). Examples: ``RewriteRule``, ``DocumentRoot``,
      ``ProxyPass``.

   DocumentRoot
      The directory from which httpd serves static files by default.
      A request for ``/page.html`` maps to ``DocumentRoot/page.html``.

   ErrorDocument
      A directive that specifies a custom response for a given HTTP
      status code. ``ErrorDocument 404 /not-found.html`` serves a
      custom 404 page.

   FallbackResource
      A ``mod_dir`` directive that specifies a default handler for
      requests that don't match any existing file — the mechanism behind
      most front-controller frameworks. See Chapter 2.

   flag
      A modifier enclosed in square brackets at the end of a
      ``RewriteRule``, such as ``[L]``, ``[R=301]``, or ``[P]``.
      Flags alter how the rule is processed. See Chapter 6.

   front controller
      A web application design pattern where all requests are routed
      through a single entry point (typically ``index.php`` or
      ``app.py``). ``FallbackResource`` and ``mod_rewrite`` both
      support this pattern.

   handler
      An internal httpd representation of the action to be taken when a
      file is called. The ``[H]`` flag (or ``SetHandler``) assigns a
      handler to matched requests.

   httpd
      The Apache HTTP Server daemon. The executable is typically called
      ``httpd`` or ``apache2`` depending on the distribution.

   MIME type
      A label identifying the type of content, such as ``text/html`` or
      ``image/png``. httpd uses MIME types (via ``mod_mime``) to
      determine how to serve files.

   mod_alias
      The module providing ``Alias``, ``AliasMatch``, ``Redirect``,
      ``RedirectMatch``, ``ScriptAlias``, and ``ScriptAliasMatch``
      directives. Simpler and faster than ``mod_rewrite`` for static
      URL mapping.

   mod_proxy
      The core proxy module. By itself it provides the framework
      (``ProxyPass``, ``ProxyPassReverse``); pair it with a protocol
      module like ``mod_proxy_http`` or ``mod_proxy_fcgi`` for actual
      proxying. See Chapter 9.

   mod_rewrite
      The rule-based URL rewriting engine. Uses PCRE regular expressions
      to match and transform request URLs. The subject of most of this
      book.

   MultiViews
      An ``Options`` setting that enables content negotiation via
      ``mod_negotiation``. A request for ``/doc`` will match
      ``doc.en.html``, ``doc.fr.html``, etc., based on the client's
      language preferences.

   PCRE
      Perl Compatible Regular Expressions — the regex library used by
      ``mod_rewrite``. Syntax is documented in ``man pcre2pattern`` or
      ``man perlre``.

   per-directory context
      Configuration that applies within a ``<Directory>`` block or
      ``.htaccess`` file. Rewrite rules in this context operate on the
      URL-path with the directory prefix stripped. See ``RewriteBase``.

   ProxyPass
      The primary ``mod_proxy`` directive for reverse proxying. Maps a
      local URL prefix to a backend server URL.

   ProxyPassReverse
      Rewrites ``Location``, ``Content-Location``, and ``URI`` headers
      in the backend's response so redirects point to the proxy's URL
      rather than the backend's internal URL.

   regex
      Regular expression — a pattern-matching language. In the context
      of this book, PCRE regex as used by ``RewriteRule`` and
      ``RewriteCond``. See Chapter 1.

   RewriteBase
      A directive that sets the base URL for per-directory rewrites.
      Only meaningful in ``.htaccess`` or ``<Directory>`` context.
      See Chapter 3.

   RewriteCond
      A directive that attaches a condition to the following
      ``RewriteRule``. The rule fires only if all preceding conditions
      match. See Chapter 7.

   RewriteEngine
      Enables or disables the rewriting engine. Must be set to ``On``
      in each context (server, virtual host, directory) where you want
      rules to be processed.

   RewriteMap
      A directive that defines a named mapping function (text file, DBM,
      program, database query, or internal function) for use in
      ``RewriteRule`` and ``RewriteCond`` substitutions. See Chapter 8.

   RewriteOptions
      Controls special behaviors of the rewrite engine — rule
      inheritance, URI handling, and other edge cases. See Chapter 3.

   RewriteRule
      The central directive of ``mod_rewrite``. Matches a URL pattern
      and transforms it into a new URL or triggers an action (redirect,
      proxy, forbid, etc.). See Chapter 4.

   reverse proxy
      A server that accepts client requests and forwards them to one or
      more backend servers, returning the response as if it originated
      from the proxy itself. ``mod_proxy`` with ``ProxyPass`` is the
      standard httpd reverse proxy. The ``[P]`` flag in ``RewriteRule``
      also triggers proxying.

   server context
      Configuration that applies at the top level of ``httpd.conf`` or
      within a ``<VirtualHost>`` block, as opposed to per-directory
      context.

   server variable
      A value available for testing in ``RewriteCond`` via the
      ``%{VARIABLE_NAME}`` syntax. Examples: ``%{HTTP_HOST}``,
      ``%{REQUEST_URI}``, ``%{REMOTE_ADDR}``. See Chapter 7.

   substitution
      The second argument to ``RewriteRule`` — the replacement URL or
      path. May contain backreferences (``$1``), server variables, and
      ``RewriteMap`` expansions.

   TestString
      The first argument to ``RewriteCond`` — the string to test,
      which can contain server variables, backreferences, and map
      expansions.

   URL mapping
      The process by which httpd determines what resource corresponds
      to a requested URL. Involves ``DocumentRoot``, ``Alias``,
      ``Redirect``, ``mod_rewrite``, and other modules. See Chapter 2.

   URL-path
      The path component of a URL, without the scheme, host, or query
      string. For ``http://example.com/one/two?q=x``, the URL-path
      is ``/one/two``.

   virtual host
      A configuration block (``<VirtualHost>``) that allows a single
      httpd instance to serve multiple websites. Virtual hosts can be
      name-based (distinguished by ``Host:`` header) or IP-based.
      See Chapter 10.
