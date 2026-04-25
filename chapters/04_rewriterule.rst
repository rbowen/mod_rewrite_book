.. _Chapter_rewriterule:


.. index:: RewriteRule
.. index:: pair: directives; RewriteRule
.. index:: pair: RewriteRule; syntax

===========
RewriteRule
===========

.. epigraph::

   | Quickly, bring me a beaker of wine, that I may wet
   | my brain and say something clever.

   -- Aristophanes (attributed)



I'll start the main technical discussion of :module:`mod_rewrite` with the
RewriteRule directive, as it is the workhorse of :module:`mod_rewrite`, and the
directive that you'll encounter most frequently.

RewriteRule performs manipulation of a requested URL, and along the way
can do a number of additional things. It's where the actual rewriting
happens — everything else in :module:`mod_rewrite` exists to support it.

The syntax of a RewriteRule is fairly simple, but you'll find that
exploring all of the possible permutations of it will take a while. So
I'll provide a lot of examples along the way to illustrate.

If you learn best by example, you may want to jump back and forth
between this section and :ref:`Chapter_recipes` to help you make sense
of this all.


.. _syntax:


.. index:: pair: RewriteRule; PATTERN
.. index:: pair: RewriteRule; TARGET
.. index:: pair: RewriteRule; FLAGS

Syntax
------


A RewriteRule directive has two required arguments and optional flags.
It looks like:


.. code-block:: none

   RewriteRule PATTERN TARGET [FLAGS]


The following sections will discuss each of those arguments in great
detail, but these are defined as:

PATTERN
   A regular expression to be applied to the requested URI.
TARGET
   What the URI will be rewritten to.
FLAGS
   Optional flags that modify the behavior of the rule.

.. _pattern:


.. index:: pair: RewriteRule; pattern matching
.. index:: regular expressions
.. index:: PCRE
.. index:: VirtualHost context
.. index:: per-directory context
.. index:: backreferences

Pattern
-------


The ``PATTERN`` argument of the ``RewriteRule`` is a regular expression that
is applied to the URL path, or file path, depending on the context.


.. index:: query string
.. index:: pair: RewriteRule; query string

In VirtualHost context, or in server-wide context, ``PATTERN`` will be
matched against the part of the URL after the hostname and port, and
before the query string (the %-decoded URL-path). For example, in the URL
<http://example.com/dogs/index.html?dog=collie>, the pattern will be
matched against :file:`/dogs/index.html`.

In Directory and htaccess context, ``PATTERN`` will be matched against the
filesystem path, after removing the prefix that led the server to the
current ``RewriteRule`` (e.g. either "dogs/index.html" or "index.html"
depending on where the directives are defined). See
:ref:`per_directory_gotchas` below for the gory details of how this
prefix stripping works — it's one of the most common sources of
confusion.

Subsequent ``RewriteRule`` patterns are matched against the output of the
last matching ``RewriteRule``.

It is assumed, at this point, that you've already read the chapter
Introduction to Regular Expressions, and/or are familiar with what a
regular expression is, and how to craft one.

.. _negated_patterns:


.. index:: pair: RewriteRule; negation
.. index:: pair: RewriteRule; ! (NOT)

Negated patterns
~~~~~~~~~~~~~~~~


You can prefix the pattern with an exclamation mark (``!``) to negate
it. This means the rule fires when the URL does *not* match the
pattern. I find this useful for "everything except" rules — for
example, redirecting all requests that are *not* for a specific path:

.. code-block:: apache

   # Redirect everything that ISN'T the maintenance page
   RewriteRule !^maintenance\.html$ /maintenance.html [R=302,L]

There's one important caveat: when you negate a pattern, there's nothing
to capture. The pattern didn't match, so there are no groups, and
``$1``, ``$2``, etc. are empty. If you need backreferences in the
target *and* you need a negated match, use a ``RewriteCond`` instead:

.. code-block:: apache

   # This does NOT work — $1 is empty because the pattern is negated
   RewriteRule !^secret/ /public/$1 [L]

   # Do this instead
   RewriteCond %{REQUEST_URI} !^/secret/
   RewriteRule ^(.*)$ /public/$1 [L]

See :ref:`Chapter_rewritecond` for more on conditions.

.. _target:


.. index:: pair: RewriteRule; substitution
.. index:: pair: RewriteRule; target

Target
------


The target of a ``RewriteRule`` can be one of the following:

.. _a-file-system-path:


.. index:: file-system path
.. index:: pair: RewriteRule target; file-system path

A file-system path
~~~~~~~~~~~~~~~~~~


Designates the location on the file-system of the resource to be
delivered to the client. Substitutions are only treated as a file-system
path when the rule is configured in server (virtualhost) context and the
first component of the path in the substitution exists in the
file-system

.. _url-path:


.. index:: URL-path
.. index:: pair: RewriteRule target; URL-path
.. index:: pair: RewriteRule flags; PT (passthrough)

URL-path
~~~~~~~~


A DocumentRoot-relative path to the resource to be served. Note that
:module:`mod_rewrite` tries to guess whether you have specified a file-system path
or a URL-path by checking to see if the first segment of the path exists
at the root of the file-system. For example, if you specify a
Substitution string of :file:`/www/file.html`, then this will be treated as a
URL-path unless a directory named www exists at the root or your
file-system (or, in the case of using rewrites in a .htaccess file,
relative to your document root), in which case it will be treated as a
file-system path. If you wish other URL-mapping directives (such as
Alias) to be applied to the resulting URL-path, use the ``[PT]`` flag as
described below.

.. _absolute-url:


.. index:: pair: RewriteRule target; absolute URL
.. index:: redirect
.. index:: pair: RewriteRule flags; R (redirect)

Absolute URL
~~~~~~~~~~~~


If an absolute URL is specified, :module:`mod_rewrite` checks to see whether the
hostname matches the current host. If it does, the scheme and hostname
are stripped out and the resulting path is treated as a URL-path.
Otherwise, an external redirect is performed for the given URL. To force
an external redirect back to the current host, see the ``[R]`` flag below.

.. _dash:


.. index:: pair: RewriteRule target; - (dash)
.. index:: pass-through

\- (dash)
~~~~~~~~~


A dash indicates that no substitution should be performed (the existing
path is passed through untouched). This is used when a flag (see below)
needs to be applied without changing the path.

For example, to set an environment variable without rewriting the URL:

.. code-block:: apache

   RewriteRule ^/secret - [E=NEED_AUTH:1]


.. _backreferences:


.. index:: backreferences
.. index:: pair: RewriteRule; $1
.. index:: pair: RewriteRule; backreferences
.. index:: pair: RewriteCond; %1

Backreferences
--------------


If the Pattern section was the "input" side of RewriteRule, backreferences
are where things get interesting on the "output" side. Any parenthesized
group in the pattern creates a backreference that you can use in the
target string. These are numbered ``$1`` through ``$9``, left to right,
by opening parenthesis.

.. code-block:: apache

   # Request: /products/widgets/42
   RewriteRule ^/products/([^/]+)/([0-9]+)$ /catalog.php?category=$1&id=$2 [L]
   # Result:  /catalog.php?category=widgets&id=42

Here, ``$1`` captures ``widgets`` and ``$2`` captures ``42``. The
numbering follows the same rules as PCRE backreferences, which I
covered in :ref:`Chapter_regex`.

You can also use backreferences from ``RewriteCond`` patterns in the
target. These use the ``%N`` syntax (``%1`` through ``%9``) rather than
``$N``, which helps you tell at a glance which part of the rule
generated a particular capture:

.. code-block:: apache

   RewriteCond %{HTTP_HOST} ^([^.]+)\.example\.com$
   RewriteRule ^/(.*)$ /sites/%1/$1 [L]

In that example, ``%1`` is the subdomain captured by the
``RewriteCond``, and ``$1`` is the path captured by the
``RewriteRule``. A request for ``http://blog.example.com/hello``
becomes ``/sites/blog/hello``.

Roy Fielding's original design for HTTP kept the URL opaque to the
server — just a string to be resolved. ``mod_rewrite`` cheerfully
violates that principle by tearing URLs apart and reassembling them from
captured pieces. It's tremendously useful, but do keep in mind that
you're working against the grain of the protocol's architecture every
time you do it.


.. index:: pair: RewriteRule; server variables
.. index:: pair: RewriteRule; %{VARNAME}

Server variables in the target
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


In addition to backreferences, the target string can contain server
variables using the ``%{VARNAME}`` syntax — the same variables
available in ``RewriteCond`` (see :ref:`Chapter_rewritecond`).

.. code-block:: apache

   # Redirect HTTP to HTTPS, preserving the host and path
   RewriteCond %{HTTPS} off
   RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]

Common variables you'll use in targets include ``%{HTTP_HOST}``,
``%{SERVER_PORT}``, ``%{REQUEST_URI}``, and ``%{QUERY_STRING}``.

You can also reference ``RewriteMap`` functions in the target
using the ``${mapname:key|default}`` syntax. I'll cover that in detail
in :ref:`Chapter_rewritemap`.


.. index:: pair: RewriteRule; expansion order

The order in which these are expanded matters: backreferences (``$N``
and ``%N``) are expanded first, then server variables (``%{VARNAME}``),
then map function calls (``${mapname:...}``). In practice this means
you can use a backreference *inside* a map lookup key, which is exactly
how dynamic RewriteMap-based routing works.


.. _query_string_handling:


.. index:: query string
.. index:: pair: RewriteRule; query string manipulation
.. index:: pair: RewriteRule flags; QSA
.. index:: pair: RewriteRule flags; QSD

Query string handling
---------------------


This trips up almost everyone the first time: **the query string is not
part of the pattern match**. If a user requests
``/search?q=kittens``, the pattern only sees ``/search``. The query
string passes through to the rewritten URL unchanged, silently, behind
your back.

That's usually what you want. But when it isn't, here's how to take
control:

**Replacing the query string** — put a ``?`` in the target. Everything
after it becomes the new query string, and the old one is discarded:

.. code-block:: apache

   # /old-search?q=kittens → /new-search?type=cat
   # (the original ?q=kittens is thrown away)
   RewriteRule ^/old-search$ /new-search?type=cat [L]

**Erasing the query string** — end the target with a bare ``?``:

.. code-block:: apache

   # /page?tracking=utm_garbage → /page (clean)
   RewriteRule ^/page$ /page? [L]

**Appending to the existing query string** — use the ``[QSA]``
(Query String Append) flag:

.. code-block:: apache

   # /products/widgets → /catalog.php?category=widgets&q=kittens
   # (preserves the original query string)
   RewriteRule ^/products/(.+)$ /catalog.php?category=$1 [QSA,L]

**Discarding the query string explicitly** — use the ``[QSD]`` flag
(available since httpd 2.4.0):

.. code-block:: apache

   RewriteRule ^/clean-path$ /target [QSD,L]

There's also ``[QSL]`` (Query String Last), which changes how
:module:`mod_rewrite` identifies the split between the path and the query
string when the target itself contains a literal ``?``. See
:ref:`Chapter_rewriterule_flags` for the full details on all of these.


.. _per_directory_gotchas:


.. index:: pair: RewriteRule; per-directory context
.. index:: pair: RewriteRule; .htaccess
.. index:: pair: RewriteRule; prefix stripping

Per-directory context gotchas
-----------------------------


I mentioned earlier that in per-directory context (``<Directory>``
blocks and :file:`.htaccess` files), the directory prefix is stripped
before matching. Let me be more specific, because this is where I see
the most head-scratching on Stack Overflow and the httpd users mailing
list.

The stripped prefix always ends with a slash. So if your rules live
in :file:`/var/www/html/.htaccess` and someone requests
``/images/logo.png``, the pattern sees ``images/logo.png`` — no
leading slash. This means a pattern that starts with ``^/`` will
**never** match in per-directory context:

.. code-block:: apache

   # In .htaccess — this NEVER matches
   RewriteRule ^/images/(.*)$ /img/$1 [L]

   # This is what you want
   RewriteRule ^images/(.*)$ /img/$1 [L]

If you need to match against the full original URL-path from within a
:file:`.htaccess` file, use a ``RewriteCond`` with ``%{REQUEST_URI}``:

.. code-block:: apache

   RewriteCond %{REQUEST_URI} ^/images/(.*)$
   RewriteRule ^ /img/%1 [L]

One more thing: although ``RewriteRule`` is syntactically valid inside
``<Location>`` and ``<Files>`` blocks (and their regex variants), this
is unsupported and you should not do it. Relative substitutions in
particular will break in creative and frustrating ways. Stick to
``<Directory>``, ``<VirtualHost>``, server config, and
:file:`.htaccess`.


.. _home_directory_expansion:


.. index:: pair: RewriteRule; home directory
.. index:: pair: RewriteRule; ~user

Home directory expansion
------------------------


Here's an obscure one that has bitten a few people: when the target
string begins with something that looks like ``/~user`` (whether from
literal text or from a backreference), :module:`mod_rewrite` performs home
directory expansion automatically — even if :module:`mod_userdir` is not
loaded or configured. This happens because the expansion is built into
:module:`mod_rewrite` itself.

If this behavior surprises you (and it will, the first time it bites),
you can suppress it with the ``[PT]`` (passthrough) flag, which hands
the rewritten URL back to the normal URL mapping pipeline rather than
letting :module:`mod_rewrite` resolve it directly.


.. _rule_processing_flow:


.. index:: pair: RewriteRule; processing order
.. index:: pair: RewriteRule; rule chaining

How rules are processed
-----------------------


RewriteRules in a given context are processed in order, top to bottom.
Each rule's pattern is matched against the result of the *previous*
matching rule — not against the original request. This is important:

.. code-block:: apache

   RewriteRule ^/dogs/(.*)$ /pets/$1    [L]
   RewriteRule ^/pets/(.*)$ /animals/$1 [L]

A request for ``/dogs/fido`` matches the first rule and is rewritten to
``/pets/fido``. But the ``[L]`` flag stops processing, so the second
rule never fires. Without the ``[L]``, the second rule *would* match
the output of the first — ``/pets/fido`` — and rewrite it to
``/animals/fido``. This cascading behavior is powerful but can create
unintentional loops if you're not careful. See
:ref:`Chapter_rewriterule_flags` for more on ``[L]``, ``[END]``, and
other flags that control the processing flow.

When ``RewriteCond`` directives precede a rule, the engine evaluates
them only after the pattern matches — despite the fact that they appear
*before* the rule in the config file. If any condition fails, the rule
is skipped entirely. This is covered in detail in
:ref:`Chapter_rewritecond`.


.. _flags_summary:


.. index:: pair: RewriteRule; flags summary

Flags at a glance
-----------------


Flags are the third argument to ``RewriteRule`` and modify its behavior
in various ways. I cover each flag in detail in
:ref:`Chapter_rewriterule_flags`, but here's a quick reference so you
can orient yourself:

.. list-table:: RewriteRule flag summary
   :header-rows: 1
   :widths: 15 85

   * - Flag
     - Purpose
   * - ``B``
     - Escape backreferences before applying them
   * - ``C``
     - Chain this rule to the next rule
   * - ``CO``
     - Set a cookie
   * - ``DPI``
     - Discard path info
   * - ``E``
     - Set an environment variable
   * - ``END``
     - Stop processing and don't re-run in per-directory context
   * - ``F``
     - Return 403 Forbidden
   * - ``G``
     - Return 410 Gone
   * - ``H``
     - Force a content handler
   * - ``L``
     - Last rule — stop processing this ruleset
   * - ``N``
     - Re-run from the top (next round)
   * - ``NC``
     - Case-insensitive match
   * - ``NE``
     - Don't escape special characters in the output
   * - ``NS``
     - Skip if this is an internal sub-request
   * - ``P``
     - Proxy the request
   * - ``PT``
     - Pass through to the next URL mapping handler
   * - ``QSA``
     - Append the original query string
   * - ``QSD``
     - Discard the original query string
   * - ``QSL``
     - Use the last ``?`` as the query string delimiter
   * - ``R``
     - External redirect (optionally with status code)
   * - ``S``
     - Skip the next N rules
   * - ``T``
     - Set the MIME type

