.. _Chapter_vhosts:


=============================
Virtual hosts and mod_rewrite
=============================

.. epigraph::

   | When you've only got two ducks, they're always in a row.

   -- Rich Bowen


This chapter covers using :module:`mod_rewrite` for dynamic virtual host
configuration — mapping incoming hostnames to document roots, CGI
directories, or entirely different server configurations on the fly.

Chapter 2 introduced :module:`mod_vhost_alias` as the preferred tool for
mass virtual hosting. This chapter shows the :module:`mod_rewrite` approach,
which offers more flexibility at the cost of more complexity. The
httpd documentation itself advises: :module:`mod_rewrite` is usually not the
best way to configure virtual hosts — consider the alternatives first.


.. index:: pair: virtual hosts; mass hosting
.. index:: pair: virtual hosts; dynamic

The problem
-----------

You have dozens — or hundreds, or thousands — of hostnames all
pointing to the same server. Each hostname needs to serve content from
a different directory. The traditional approach is a ``<VirtualHost>``
block for each one:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName www.alice.example.com
       DocumentRoot /var/www/vhosts/alice
   </VirtualHost>

   <VirtualHost *:80>
       ServerName www.bob.example.com
       DocumentRoot /var/www/vhosts/bob
   </VirtualHost>

   # ... repeat 500 more times

This doesn't scale. Every new hostname requires a config change and a
server restart. For a shared hosting provider or a platform that
provisions sites dynamically, you need the mapping to happen
automatically — derive the document root from the hostname at request
time, without any per-host configuration.


.. index:: pair: virtual hosts; mod_rewrite recipe
.. index:: pair: RewriteMap; int:tolower

Dynamic vhosts with mod_rewrite
--------------------------------

The core recipe uses :module:`mod_rewrite` to capture the incoming
hostname and map it to a filesystem path. Here's the full example:

.. code-block:: apache

   RewriteEngine On

   # Normalize the hostname to lowercase
   RewriteMap lowercase int:tolower

   # Capture the hostname and map it to a directory
   RewriteCond %{HTTP_HOST} ^(.+)$
   RewriteRule ^(.*)$ /var/www/vhosts/${lowercase:%1}/$1 [L]

Let's walk through this:

1. The ``RewriteMap`` defines a mapping called ``lowercase`` using the
   built-in ``int:tolower`` function — this normalizes the hostname so
   that ``WWW.Example.COM`` and ``www.example.com`` resolve to the
   same directory.

2. The ``RewriteCond`` captures the entire ``Host`` header into ``%1``.

3. The ``RewriteRule`` captures the request path into ``$1`` and
   constructs the full filesystem path:
   ``/var/www/vhosts/<hostname>/<path>``.

So a request for ``http://www.alice.example.com/index.html`` is served
from :file:`/var/www/vhosts/www.alice.example.com/index.html`.

.. note::

   Remember the backreference distinction: ``%1`` through ``%9`` are
   captures from the most recent ``RewriteCond``; ``$1`` through ``$9``
   are captures from the ``RewriteRule`` pattern. Getting these mixed
   up is a very common mistake.


Stripping the ``www.`` prefix
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If your directory structure doesn't include the ``www.`` prefix, strip
it:

.. code-block:: apache

   RewriteCond %{HTTP_HOST} ^(?:www\.)?(.+)$
   RewriteRule ^(.*)$ /var/www/vhosts/${lowercase:%1}/$1 [L]

The non-capturing group ``(?:www\.)?`` matches and discards the
``www.`` if present, so ``%1`` contains only the bare domain.


.. index:: pair: RewriteMap; vhost mapping

Using a map file for vhosts
----------------------------

Deriving the path from the hostname with regex is convenient, but it
assumes a predictable directory structure. When you need explicit
control — mapping ``customer-a.example.com`` to :file:`/var/www/sites/customer_a`
rather than the hostname itself — a ``RewriteMap`` is cleaner:

.. code-block:: none

   # /etc/httpd/conf/vhost.map
   customer-a.example.com   /var/www/sites/customer_a
   customer-b.example.com   /var/www/sites/customer_b
   demo.example.com         /var/www/sites/demo

.. code-block:: apache

   RewriteMap vhostmap txt:/etc/httpd/conf/vhost.map
   RewriteMap lowercase int:tolower

   RewriteCond %{HTTP_HOST} ^(.+)$
   RewriteCond ${vhostmap:${lowercase:%1}|NOTFOUND} !=NOTFOUND
   RewriteRule ^(.*)$ ${vhostmap:${lowercase:%1}}/$1 [L]

The second ``RewriteCond`` checks that the hostname actually exists in
the map — if it doesn't, the default ``NOTFOUND`` is returned and the
rule is skipped, which lets the request fall through to a default
virtual host.

For high-traffic servers, convert the text map to a DBM hash for faster
lookups (see :ref:`Chapter_rewritemap` for the ``httxt2dbm`` tool and
``dbm:`` map type).


.. index:: pair: virtual hosts; Alias interaction
.. index:: pair: virtual hosts; ScriptAlias
.. index:: pair: virtual hosts; CGI

Handling aliases and CGI in dynamic vhosts
-------------------------------------------

Here's a complication that catches everyone the first time:
:module:`mod_rewrite` runs before :module:`mod_alias` in the request
processing pipeline. That means ``Alias`` and ``ScriptAlias`` directives
— things like ``Alias /icons/ /usr/share/httpd/icons/`` — get
bypassed by the rewrite rule, because :module:`mod_rewrite` has already
mapped the URL to a filesystem path before :module:`mod_alias` gets a
chance.

The fix is to explicitly exclude those paths from rewriting:

.. code-block:: apache

   # Let Alias and ScriptAlias handle these paths
   RewriteCond %{REQUEST_URI} !^/icons/
   RewriteCond %{REQUEST_URI} !^/cgi-bin/
   RewriteCond %{REQUEST_URI} !^/error/

   # Then the vhost mapping
   RewriteCond %{HTTP_HOST} ^(.+)$
   RewriteRule ^(.*)$ /var/www/vhosts/${lowercase:%1}/$1 [L]

Alternatively, if you need CGI to work within each virtual host's
directory, you can use the ``[H=cgi-script]`` handler flag to force
CGI processing for specific paths:

.. code-block:: apache

   RewriteRule ^/cgi-bin/(.*)$ /var/www/vhosts/${lowercase:%1}/cgi-bin/$1 [H=cgi-script,L]

This maps each vhost's ``/cgi-bin/`` to a directory within its own
docroot and ensures the CGI handler runs.


.. index:: pair: virtual hosts; mod_vhost_alias comparison

Why mod_vhost_alias is usually better
--------------------------------------

Chapter 2 introduced :module:`mod_vhost_alias`, and for mass virtual
hosting, it's almost always the better choice. Here's why:

:module:`mod_vhost_alias` maps hostnames to directories using
interpolation tokens (``%0`` for the full hostname, ``%1``/``%2``/etc.
for individual components), and it does so *before* the ``Alias`` and
``ScriptAlias`` resolution phase — meaning those directives still work
correctly:

.. code-block:: apache

   UseCanonicalName Off
   VirtualDocumentRoot /var/www/vhosts/%0

That single directive replaces the entire :module:`mod_rewrite` recipe
above, including the ``lowercase`` map, the ``RewriteCond``, and the
exclusion conditions for ``/icons/`` and ``/cgi-bin/``.

Use :module:`mod_rewrite` for dynamic virtual hosts only when you need
something :module:`mod_vhost_alias` can't do:

- **Conditional logic** — different behavior for certain hostnames
  (e.g., redirect some to a different server, serve others from a
  special directory).
- **Hostname transformations** that go beyond token interpolation — for
  example, looking up the hostname in a database via a
  ``RewriteMap prg:`` external program.
- **Combining vhost mapping with other rewrite rules** — for example,
  forcing HTTPS *and* mapping to a vhost directory in the same
  ruleset.


.. index:: pair: virtual hosts; user directories
.. index:: pair: mod_userdir; mod_rewrite alternative

Per-user virtual hosts
-----------------------

A common variant of dynamic hosting: mapping ``~user`` or
``/users/username/`` URLs to user home directories. Chapter 2 covered
:module:`mod_userdir`, which handles this natively:

.. code-block:: apache

   UserDir public_html

This maps ``/~alice/`` to :file:`/home/alice/public_html/`. Simple and
effective.

The :module:`mod_rewrite` version is useful when :module:`mod_userdir`
doesn't fit your layout — for example, if user content lives outside
home directories, or you need conditional access:

.. code-block:: apache

   # Map /users/alice/ to /var/www/users/alice/
   RewriteRule ^/users/([^/]+)/?(.*)$ /var/www/users/$1/$2 [L]

Or with access restrictions:

.. code-block:: apache

   # Only allow user pages for users in the map
   RewriteMap validusers txt:/etc/httpd/conf/valid-users.txt
   RewriteCond ${validusers:$1|INVALID} !=INVALID
   RewriteRule ^/users/([^/]+)/?(.*)$ /var/www/users/$1/$2 [L]

   # Everyone else gets a 404
   RewriteRule ^/users/ - [R=404]


.. index:: pair: virtual hosts; logging
.. index:: pair: LogFormat; per-vhost

Logging for dynamic vhosts
----------------------------

When all your virtual hosts share a single configuration, they also
share a single log file. The trick is to include the hostname in each
log entry so you can distinguish them:

.. code-block:: apache

   LogFormat "%V %h %l %u %t \"%r\" %>s %b" vhost_common
   CustomLog /var/log/httpd/access_log vhost_common

The ``%V`` token logs the server name from the request (effectively the
``Host`` header). Now every log line is prefixed with the hostname.

**Conditional logging** — write different vhosts to different log
files:

.. code-block:: apache

   SetEnvIf Host "^alice\.example\.com$" vhost=alice
   SetEnvIf Host "^bob\.example\.com$" vhost=bob

   CustomLog /var/log/httpd/alice_access.log common env=vhost=alice
   CustomLog /var/log/httpd/bob_access.log common env=vhost=bob

This works for a small number of known vhosts, but doesn't scale to
the mass hosting scenario.

**Splitting logs after the fact** — for mass hosting, it's more
practical to log everything to a single file with ``%V`` and split it
later. Apache httpd ships with a ``split-logfile`` utility that reads
a combined log and writes per-vhost log files:

.. code-block:: none

   split-logfile < /var/log/httpd/access_log

This creates files named ``alice.example.com-access_log``,
``bob.example.com-access_log``, and so on. It requires no
per-vhost configuration, and handles the dynamic nature of mass hosting
cleanly.

For real-time per-vhost logging at scale, piped logging through a
script is also an option:

.. code-block:: apache

   CustomLog "|/usr/local/bin/vhost-log-splitter.sh" vhost_common

But that's an exercise left to the reader — and to the reader's
tolerance for debugging shell scripts in a production log pipeline.
