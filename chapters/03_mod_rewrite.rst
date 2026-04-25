.. _Chapter_mod_rewrite:


.. index:: mod_rewrite
.. index:: pair: modules; mod_rewrite
.. index:: pair: mod_rewrite; introduction

===========================
Introduction to mod_rewrite
===========================

.. epigraph::

   In the high and far-off times the Elephant, O Best Beloved, had no trunk.

   -- Rudyard Kipling, *The Elephant's Child*



:module:`mod_rewrite` is the power tool of Apache httpd URL mapping. Of course,
sometimes you just need a screwdriver, but when you need the power tool,
it's good to know where to find it.

:module:`mod_rewrite` provides sophisticated URL manipulation via regular expressions, and the
ability to do a variety of transformations, including, but not limited
to, modification of the request URL. You can additionally return a
variety of status codes, set cookies and environment variables, proxy
requests to another server, or send redirects to the client.

In this chapter we'll cover :module:`mod_rewrite` syntax and usage, and in the
next chapter we'll give a variety of examples of using :module:`mod_rewrite` in
common scenarios.

.. _loading-mod_rewrite:


.. index:: LoadModule
.. index:: pair: directives; LoadModule
.. index:: pair: mod_rewrite; loading

Loading mod_rewrite
-------------------


To use :module:`mod_rewrite` in any context, you need to have the module loaded.
If you're the server administrator, this means having the following line
somewhere in your Apache httpd configuration:


.. code-block:: none

   LoadModule rewrite_module modules/mod_rewrite.so


This tells httpd that it needs to load :module:`mod_rewrite` at startup time, so
as to make its functionality available to your configuration files.

If you are not the server administrator, then you'll need to ask your
server administrator if the module is available, or experiment to see if
it is. If you're not sure, you can test to see whether it's enabled in
the following manner.

Create a subdirectory in your document directory. Let's call it
test_rewrite

Create a file in that directory called .htaccess and put the following
text in it:


.. code-block:: none

   RewriteEngine on


Create another file in that directory called index.html containing the
following text:


.. code-block:: none

   <html>
   Hello, mod_rewrite
   </html>


Now, point your browser at that location:


.. code-block:: none

   http://example.com/test_rewrite/index.html


.. index:: Internal Server Error
.. index:: pair: errors; Internal Server Error

You'll see one of two things. Either you'll see the words
Hello, :module:`mod_rewrite` in your browser, or you'll see the ominous words
Internal Server Error. In the former case, everything is fine -
:module:`mod_rewrite` is loaded and your :file:`.htaccess` file worked just fine. If you
got an Internal Server Error, that was httpd complaining that it didn't
know what to do with the ``RewriteEngine`` directive, because :module:`mod_rewrite`
wasn't loaded.

If you have access to the server's error log file, you'll see the
following in it:


.. code-block:: none

   Invalid command 'RewriteEngine', perhaps misspelled or defined by a module not included in the server configuration


Which is httpd's way of saying that you used a directive
(``RewriteEngine``) without first loading the module that defines that
directive.

If you see the Internal Server Error message, or that log file message,
it's time to contact your server administrator and ask if they'll load
:module:`mod_rewrite` for you.

However, this is fairly unlikely, since :module:`mod_rewrite` is a fairly standard
part of any Apache HTTP Server's bag of tricks.

.. _rewriteengine:


.. index:: RewriteEngine
.. index:: pair: directives; RewriteEngine

RewriteEngine
-------------


In the section above, we used the ``RewriteEngine`` directive without
defining what it does.

The ``RewriteEngine`` directive enables or disables the runtime rewriting
engine. The directive defaults to ``off``, so the result is that rewrite
directives will be ignored in any scope where you don't have the
following:


.. code-block:: none

   RewriteEngine On


While we won't always include that in every example in this book, it
should be assumed, from this point forward, that every use of
:module:`mod_rewrite` occurs in a scope where ``RewriteEngine`` has been turned on.

.. _mod_rewrite-in-.htaccess-files:


.. index:: .htaccess
.. index:: pair: mod_rewrite; .htaccess files
.. index:: per-directory context

mod_rewrite in .htaccess files
------------------------------


Before we go any further, it's critical to note that things are
different, in several important ways, if you have to use .htaccess files
for configuration.

.. _what-are-.htaccess-files:


.. index:: pair: .htaccess; overview
.. index:: AllowOverride
.. index:: pair: directives; AllowOverride

What are .htaccess files?
~~~~~~~~~~~~~~~~~~~~~~~~~


:file:`.htaccess` files are per-directory configuration files, for use by people

.. index:: server context
.. index:: pair: configuration; server context

who don't have access to the main server configuration file. For the
most part, you put configuration directives into .htaccess files just as
you would in a ``<Directory>`` block in the server configuration, but
there are some differences.

The most important of these differences is that the .htaccess file is
consulted every time a resource is requested from the directory in
question, whereas configurations placed in the main server configuration
file are loaded once, at server startup.

The positive side of this is that you can modify the contents of a
.htaccess file and have the change take effect immediately, as of the
next request received by the server.

The negative is that the .htaccess file needs to be loaded from the
filesystem on every request, resulting in an incremental slowdown for
every request. Additionally, because httpd doesn't know ahead of time
what directories contain .htaccess files, it has to look in each
directory for them, all along the path to the requested resource, which
results in a slowdown that grows with the depth of the directory tree.

In Apache httpd 2.2 and earlier, .htaccess files are enabled by default
- that is the configuration directive that enables them,
``AllowOverride``, has a default value of ``All``. In 2.4 and later, it has
a default value of ``None``, so .htaccess files are disabled by default.

A typical configuration to permit the use of .htaccess files looks like:


.. code-block:: none

   <Directory />
       AllowOverride None
   </Directory>
   DocumentRoot /var/www/html
   <Directory /var/www/html>
       AllowOverride All
       Options +FollowSymLinks
   </Directory>


.. index:: pair: directives; Options FollowSymLinks

That is to say, .htaccess files are disallowed for the entire
filesystem, starting at the root, but then are permitted in the document
directories. This prevents httpd
from looking for .htaccess files in ``/``, ``/var``, and :file:`/var/www` on the way to
looking in :file:`/var/www/html`. [#htaccess-security]_

.. [#htaccess-security] Or, more to the point, it prevents malicious end-users from finding ways to look there.

Note that in order to enable the use of :module:`mod_rewrite` directives in
:file:`.htaccess` files, you also need to enable ``Options FollowSymLinks``. A
``RewriteRule`` may be thought of as a kind of symlink, because it allows
you to serve content from other directories via a rewrite. Thus, for
reasons of security, it is necessary to enable symlinks in order to use
:module:`mod_rewrite`.

.. _ok-so-whats-the-deal-with-mod_rewrite-in-.htaccess-files:


.. index:: RewriteMap
.. index:: pair: .htaccess; restrictions
.. index:: pair: .htaccess; path stripping

Ok, so, what's the deal with mod_rewrite in .htaccess files?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


There are two major differences that you must be aware of before we
proceed any further. The exact implications of these differences will
become more apparent as we go, but I wouldn't want them to surprise you.

First, there are two directives that you cannot use in .htaccess files.
These directives are ``RewriteMap`` and (prior to httpd 2.4) ``RewriteLog``.
These must be defined in the main server configuration. The reasons for
this will be discussed in greater length when we get to the sections
about those directives RewriteMap and RewriteLogging, respectively).

Second, and more importantly, the syntax of ``RewriteRule`` directives
changes in .htaccess context in a way that you'll need to be aware of
every time you write a ``RewriteRule``. Specifically, the directory path
that you're in will be removed from the URL path before it is presented
to the ``RewriteRule``.

The exact implications of this will become clearer as we show you
examples. And, indeed, every example in this book will be presented in a
form for the main config, and a form for .htaccess files, whenever there
is a difference between the two forms. But we'll start with a simple
example to illustrate the idea.

Some of this, you'll need to take on faith at the moment, since we've
not yet introduced several of the concepts presented in this example, so
please be patient for now.

Consider a situation where you want to apply a rewrite to content in the
``/images/puppies/`` subdirectory of your website. You have four options:
You can put the ``RewriteRule`` in the main server configuration file; You
can place it in a .htaccess file in the root of your website; You can
place it in a .htaccess file in the ``images`` directory; Or you can place
it in a .htaccess file in the :file:`images/puppies` directory.

Here's what the rule might look like in those various scenarios:


.. list-table::
   :header-rows: 1
   :widths: auto

   * - Location
     - Rule
   * - Main config
     - ``RewriteRule ^/images/puppies/(.*).jpg /dogs/$1.gif``
   * - Root directory
     - ``RewriteRule ^images/puppies/(.*).jpg /dogs/$1.gif``
   * - images directory
     - ``RewriteRule ^puppies/(.*).jpg /dogs/$1.gif``
   * - images/puppies directory
     - ``RewriteRule ^(.*).jpg /dogs/$1.gif``

For the moment, don't worry too much about what the individual rules do.
Look instead at the URL path that is being considered in each rule, and
notice that for each directory that a .htaccess file is placed in, the
directory path that ``RewriteRule`` may consider is relative to that
directory, and anything above that becomes invisible for the purpose of
:module:`mod_rewrite`.

Don't worry too much if this isn't crystal clear at this point. It will
become more clear as we proceed and you see more examples.

.. _so-what-do-i-do:


.. index:: pair: .htaccess; limitations

So, what do I do?
~~~~~~~~~~~~~~~~~


If you don't have access to the main server configuration file, as it
the case for many of the readers of this book, don't despair.
:module:`mod_rewrite` is still a very powerful tool, and can be persuaded to do
almost anything that you need it to do. You just need to be aware of its
limitations, and adjust accordingly when presented with an example rule.

We aim to help you do that at each step along this journey.

.. _rewriteoptions:


.. index:: RewriteOptions
.. index:: pair: directives; RewriteOptions
.. index:: pair: RewriteOptions; Inherit
.. index:: pair: RewriteOptions; InheritBefore
.. index:: pair: RewriteOptions; InheritDown
.. index:: pair: RewriteOptions; InheritDownBefore
.. index:: pair: RewriteOptions; IgnoreInherit
.. index:: pair: RewriteOptions; AllowNoSlash
.. index:: pair: RewriteOptions; AllowAnyURI
.. index:: pair: RewriteOptions; MergeBase
.. index:: pair: RewriteOptions; IgnoreContextInfo
.. index:: pair: RewriteOptions; LegacyPrefixDocRoot
.. index:: pair: RewriteOptions; LongURLOptimization

RewriteOptions
--------------


The ``RewriteOptions`` directive controls several special behaviors of
the rewrite engine. You can specify multiple options separated by
spaces.


Inherit and InheritBefore
~~~~~~~~~~~~~~~~~~~~~~~~~

By default, rewrite rules are *not* inherited from parent contexts.
A ``<VirtualHost>`` does not inherit rules from the main server config;
a :file:`.htaccess` file does not inherit rules from a parent directory's
:file:`.htaccess`.

``RewriteOptions Inherit`` forces the current context to inherit the
parent's rules, maps, and conditions. The inherited rules run *after*
the local rules.

``RewriteOptions InheritBefore`` does the same, but the inherited
rules run *before* the local rules.


.. code-block:: apache

   # In a .htaccess or <Directory> block:
   RewriteOptions Inherit


InheritDown and InheritDownBefore
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These are the inverse of ``Inherit``: instead of a child saying "give
me my parent's rules," the parent says "push my rules into all
children." This avoids needing ``RewriteOptions Inherit`` in every
child configuration.

``InheritDown`` pushes the parent's rules to run *after* each child's
local rules. ``InheritDownBefore`` pushes them to run *before*.

:version:`2.4.8` Available in httpd 2.4.8 and later.


IgnoreInherit
~~~~~~~~~~~~~

If a parent has ``InheritDown`` set but a particular child should *not*
inherit, the child can use ``RewriteOptions IgnoreInherit`` to opt out.

:version:`2.4.8` Available in httpd 2.4.8 and later.


AllowNoSlash
~~~~~~~~~~~~

By default, :module:`mod_rewrite` ignores URLs that map to a directory on
disk but lack a trailing slash — it assumes :module:`mod_dir` will handle the
redirect. If you've set ``DirectorySlash Off``, enable
``AllowNoSlash`` so that rewrite rules can match directory URLs without
a trailing slash.

:version:`2.4` Available in httpd 2.4.0 and later.


AllowAnyURI
~~~~~~~~~~~

In server/vhost context (since httpd 2.2.22), :module:`mod_rewrite` only
processes requests whose URI is a valid URL-path. This is a security
measure (see CVE-2011-3368 and CVE-2011-4317). ``AllowAnyURI`` lifts
that restriction.

.. warning::

   Enabling this makes the server vulnerable to security issues if
   rewrite rules are not carefully authored. Use with extreme caution.

:version:`2.4.3` Available in httpd 2.4.3 and later.


MergeBase
~~~~~~~~~

Copies the value of ``RewriteBase`` from where it's explicitly defined
into any sub-directory or sub-location that doesn't define its own.
This was the default behavior in httpd 2.4.0–2.4.3; the option restores
it.

:version:`2.4.4` Available in httpd 2.4.4 and later.


IgnoreContextInfo
~~~~~~~~~~~~~~~~~

When a relative substitution is made in per-directory context and
``RewriteBase`` has not been set, :module:`mod_rewrite` uses extended URL
and filesystem context information (provided by modules like
:module:`mod_userdir` and :module:`mod_alias`) to resolve the substitution back
into a URL. This option disables that behavior.

:version:`2.4.16` Available in httpd 2.4.16 and later.


LegacyPrefixDocRoot
~~~~~~~~~~~~~~~~~~~

Prior to 2.4.26, when a substitution was an absolute URL matching the
current virtual host, the URL could be reduced to a local path and
the document root would be prepended. This option restores that
legacy behavior.

:version:`2.4.26` Available in httpd 2.4.26 and later.


LongURLOptimization
~~~~~~~~~~~~~~~~~~~

Reduces memory usage for long, unoptimized rule sets that repeatedly
expand long values in ``RewriteCond`` and ``RewriteRule`` variables.

:version:`trunk` Available in httpd trunk (future 2.5.x) only — not yet in any stable release.

.. _rewritebase:


.. index:: RewriteBase
.. index:: pair: directives; RewriteBase

RewriteBase
-----------


The ``RewriteBase`` directive sets the base URL for per-directory
rewrites. It is only valid in per-directory context (:file:`.htaccess` files
and ``<Directory>`` blocks) and is ignored in server or virtual host
context.

When :module:`mod_rewrite` processes a rule in :file:`.htaccess`, it strips the
local directory prefix from the URL before matching, then prepends it
back after substitution. ``RewriteBase`` overrides what gets prepended.

Consider a :file:`.htaccess` file in :file:`/var/www/html/app/`, where the
URL :file:`/app/` maps to that directory:


.. code-block:: apache

   # /var/www/html/app/.htaccess
   RewriteEngine On
   RewriteBase /app/
   RewriteRule ^page/(.*)$ index.php?page=$1 [L]


Without ``RewriteBase /app/``, the substitution ``index.php?page=foo``
would be interpreted relative to the filesystem path, not the URL path,
and the result might not be what you expect.

The most common value is simply:


.. code-block:: apache

   RewriteBase /


This tells :module:`mod_rewrite` that all substitutions should be treated as
relative to the document root.

**When do you need RewriteBase?**

- In :file:`.htaccess` files when your rewrite substitutions are relative
  paths (not starting with ``/``).
- When the URL path to the directory containing the :file:`.htaccess`
  differs from the filesystem path (e.g., due to ``Alias``).
- You do *not* need it in ``<VirtualHost>`` or server config — there,
  ``RewriteRule`` operates on the full URL-path and no prefix stripping
  occurs.

**When can you omit it?**

- When all your substitutions use absolute URL-paths (starting with
  ``/``).
- When the URL-to-filesystem mapping is straightforward
  (``DocumentRoot`` + URL-path = filesystem path).

A common source of confusion: people put ``RewriteBase`` in server
config or ``<VirtualHost>`` blocks where it has no effect, then wonder
why their rules behave unexpectedly. If you're not in a :file:`.htaccess`
or ``<Directory>`` context, you don't need it.

