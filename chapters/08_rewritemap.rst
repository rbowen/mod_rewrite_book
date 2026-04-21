.. _Chapter_rewritemap:


.. index:: RewriteMap
.. index:: pair: directives; RewriteMap

==========
RewriteMap
==========

.. epigraph::

   | He took that skin, and he shook that skin, and he scrubbed
   | that skin, and he rubbed that skin just as full of old,
   | dry, stale, tickly cake-crumbs and some burned currants
   | as ever it could possibly hold.

   -- Rudyard Kipling, *How the Rhinoceros Got His Skin*



The ``RewriteMap`` directive gives you a way to call external mapping
routines to simplify a ``RewriteRule``. This external mapping can be a
flat text file containing one-to-one mappings, or a database, or a
script that produces mapping rules, or a variety of other similar
things. In this chapter we'll discuss how to use a ``RewriteMap`` in a
``RewriteRule`` or ``RewriteCond``.

.. _creating-a-rewritemap:


.. index:: pair: RewriteMap; creating
.. index:: pair: RewriteMap; MapName
.. index:: pair: RewriteMap; MapType
.. index:: pair: RewriteMap; MapSource

Creating a RewriteMap
---------------------


The ``RewriteMap`` directive creates an alias which you can then invoke in
either a ``RewriteRule`` or ``RewriteCond`` directive. You can think of it
as defining a function that you can call later on.

The syntax of the ``RewriteMap`` directive is as follows:


.. code-block:: none

   RewriteMap MapName MapType:MapSource


Where the various parts of that syntax are defined as:

MapName
   The name of the 'function' that you're creating
MapType
   The type of the map. The various available map types are discussed
   below.
MapSource
   The location from which the map definition will be obtained, such as a
   file, database query, or predefined function.

The ``RewriteMap`` directive must be used either in virtualhost context,
or in global server context. This is because a ``RewriteMap`` is loaded at
server startup time, rather than at request time, and, as such, cannot
be specified in a ``.htaccess`` file.

.. _using-a-rewritemap:


.. index:: pair: RewriteMap; usage
.. index:: pair: RewriteMap; syntax

Using a RewriteMap
------------------


Once you have defined a ``RewriteMap``, you can then use it in a
``RewriteRule`` or ``RewriteCond`` as follows:


.. code-block:: none

   RewriteMap examplemap txt:/path/to/file/map.txt
   RewriteRule ^/ex/(.*) ${examplemap:$1}


Note in this example that the ``RewriteMap``, named 'examplemap', is
passed an argument, ``$1``, which is captured by the ``RewriteRule``
pattern. It can also be passed an argument of another known variable.
For example, if you wanted to invoke the ``examplemap`` map on the entire
requested URI, you could use the variable ``%{REQUEST_URI}`` rather than
``$1`` in your invocation:


.. code-block:: none

   RewriteRule ^ ${examplemap:%{REQUEST_URI}}




.. _default-values:

Default Values
--------------

When a key is not found in the map, the lookup returns an empty string
by default. You can specify a fallback using the pipe character (``|``)
followed by a default value:


.. code-block:: none

   ${mapname:key|default}


For example:


.. code-block:: none

   RewriteRule ^/product/(.*) /prods.php?id=${productmap:$1|NOTFOUND} [PT]


If the key ``$1`` is not found in ``productmap``, the value
``NOTFOUND`` is substituted instead. This lets your application handle
the missing-key case gracefully rather than receiving an empty string.

The default value can be any string, including a URL path:


.. code-block:: none

   RewriteRule ^/old/(.*) ${redirectmap:$1|/not-found.html} [R=301]

.. _rewritemap-types:


.. index:: pair: RewriteMap; types

RewriteMap Types
----------------


There are a number of different map types which may be used in a
``RewriteMap``.

.. _int:


.. index:: pair: RewriteMap types; int (internal function)

int
~~~


An ``int`` map type is an internal function, pre-defined by ``mod_rewrite``
itself. There are four such functions:

.. _toupper:


.. index:: pair: RewriteMap internal functions; toupper
.. index:: toupper

toupper
~~~~~~~


The ``toupper`` internal function converts the provided argument text to
all upper case characters.


.. code-block:: none

   # Convert any lower-case request to upper case and redirect
   RewriteMap uc int:toupper
   RewriteRule (.*?[a-z]+.*) ${uc:$1} [R=301]


.. _tolower:


.. index:: pair: RewriteMap internal functions; tolower
.. index:: tolower

tolower
~~~~~~~


The ``tolower`` is the opposite of ``toupper``, converting any argument text
to lower case characters.


.. code-block:: none

   # Convert any upper-case request to lower case and redirect
   RewriteMap lc int:tolower
   RewriteRule (.*?[A-Z]+.*) ${lc:$1} [R=301]


.. _escape:


.. index:: pair: RewriteMap internal functions; escape
.. index:: escape

escape
~~~~~~

The ``escape`` internal function URL-encodes special characters in the
argument, translating them to ``%xx`` hex sequences. This is useful
when a captured backreference might contain characters that would break
a URL — spaces, ampersands, question marks, and so on.


.. code-block:: none

   RewriteMap esc int:escape
   RewriteRule ^/search/(.*)$ /search.php?term=${esc:$1} [PT]


A request for ``/search/x & y`` would result in the query string
``term=x%20%26%20y``, which is properly encoded for use in a URL.

This is similar to what the ``[B]`` flag does to backreferences, but
``escape`` can be applied selectively to specific parts of the
substitution via the map syntax, whereas ``[B]`` affects all
backreferences in the rule.


.. _unescape:


.. index:: pair: RewriteMap internal functions; unescape
.. index:: unescape

unescape
~~~~~~~~

The ``unescape`` internal function is the reverse of ``escape`` — it
decodes ``%xx`` hex sequences back to their original characters.


.. code-block:: none

   RewriteMap unesc int:unescape
   RewriteCond ${unesc:%{QUERY_STRING}} (.*secret.*)
   RewriteRule ^ - [F]


This example decodes the query string before testing it, so that
``%73ecret`` is recognized as ``secret`` even when a client tries to
sneak it past a filter using percent-encoding.

Use ``unescape`` when you need to inspect or match the decoded form of
a URL component that may arrive in encoded form.


.. _txt:


.. index:: pair: RewriteMap types; txt (text file)

txt
~~~


A ``txt`` map is a plain text file containing one key-value pair per
line, separated by whitespace. Lines starting with ``#`` are comments.

The file format looks like this:

.. code-block:: none

   ##
   ##  productmap.txt - Product name to ID mapping
   ##

   television 993
   stereo     198
   fishingrod 043
   basketball 418
   telephone  328


Define the map and use it in a rule:


.. code-block:: none

   RewriteMap productmap txt:/etc/httpd/maps/productmap.txt
   RewriteRule ^/product/(.*) /prods.php?id=${productmap:$1|NOTFOUND} [PT]


A request for ``/product/television`` is internally rewritten to
``/prods.php?id=993``. If the product isn't found in the map, the
default value ``NOTFOUND`` is used instead (see :ref:`default-values`).

**Caching:** httpd caches the contents of a ``txt`` map in memory. The
cache is automatically refreshed when the file's modification time
(``mtime``) changes, so you can update the file while the server is
running — no restart required. However, for very large map files
(thousands of entries), consider using a ``dbm`` map instead for
faster lookups.

**Context restriction:** The ``RewriteMap`` directive itself must
appear in server or virtual host context — you cannot declare it in a
``.htaccess`` file. However, once declared, the map can be *used* in
``RewriteRule`` and ``RewriteCond`` directives anywhere, including
``.htaccess``.

.. _rnd:


.. index:: pair: RewriteMap types; rnd (random)

rnd
~~~


A ``rnd`` map uses the same text file format as ``txt``, but the value
for each key is a pipe-separated list of alternatives. On each lookup,
one value is chosen at random.


.. code-block:: none

   ##
   ##  servers.txt - Backend server map for load balancing
   ##

   static  www1.example.com|www2.example.com|www3.example.com|www4.example.com
   dynamic app1.example.com|app2.example.com


Define the map and use it with the ``[P]`` flag for proxy
load-balancing:


.. code-block:: none

   RewriteMap servers rnd:/etc/httpd/maps/servers.txt
   RewriteRule ^/static/(.*) http://${servers:static}/$1       [P]
   RewriteRule ^/app/(.*)    http://${servers:dynamic}/app/$1   [P]


Each request for ``/static/logo.png`` is proxied to a randomly
selected server from the ``static`` list.

**Weighting trick:** To weight the selection toward a particular server,
list it more than once:


.. code-block:: none

   static  www1|www1|www1|www2


This gives ``www1`` a 75% probability and ``www2`` a 25% probability.

Note that this is a very basic form of load balancing with no health
checking or session affinity. For production load balancing, use
``mod_proxy_balancer`` instead. The ``rnd`` map is most useful for
simple cases like distributing static asset requests or A/B testing.

.. _dbm:


.. index:: pair: RewriteMap types; dbm (hash file)
.. index:: DBM hash file
.. index:: httpddbm

dbm
~~~

A ``dbm`` map stores the same key-value data as a ``txt`` map but in a
DBM hash file, which provides O(1) lookups instead of a linear scan.
This matters when your map file has thousands of entries — a ``txt``
map is read sequentially, while a ``dbm`` lookup is essentially
instantaneous regardless of file size.

Create a DBM file from a text file using the ``httxt2dbm`` utility
that ships with httpd:


.. code-block:: none

   httxt2dbm -i redirectmap.txt -o redirectmap.map


Then reference it in your configuration:


.. code-block:: none

   RewriteMap redirects dbm:/etc/httpd/maps/redirectmap.map
   RewriteRule ^/old/(.*) ${redirects:$1|/gone.html} [R=301]


You can optionally specify the DBM type:


.. code-block:: none

   RewriteMap redirects dbm=sdbm:/etc/httpd/maps/redirectmap.map


Available types include ``sdbm`` (always available), ``gdbm``,
``ndbm``, and ``db``. In practice, use whatever ``httxt2dbm``
produces by default — it chooses the best available type for your
platform.

**Note:** Some DBM implementations create two files (e.g.,
``redirectmap.map.dir`` and ``redirectmap.map.pag``). Always reference
the base name without extensions in the ``RewriteMap`` directive.

**Caching:** Like ``txt`` maps, ``dbm`` maps are cached in memory and
automatically refreshed when the file's modification time changes. To
update a ``dbm`` map, regenerate it with ``httxt2dbm`` and httpd will
pick up the new version on the next lookup.


.. _prg:


.. index:: pair: RewriteMap types; prg (external program)

prg
~~~

A ``prg`` map launches an external program at server startup and
communicates with it via standard input and output. For each lookup,
the key is written to the program's STDIN (followed by a newline), and
the program writes the result to STDOUT (also followed by a newline).

To indicate that a key has no match, the program should return the
string ``NULL`` (case-insensitive).


.. code-block:: none

   RewriteMap dash2under prg:/usr/local/bin/dash2under.py
   RewriteRule - ${dash2under:%{REQUEST_URI}}


Here is an example program that replaces dashes with underscores:


.. code-block:: python

   #!/usr/bin/env python3
   import sys

   def main():
       for line in sys.stdin:
           key = line.strip()
           result = key.replace('-', '_')
           print(result, flush=True)

   if __name__ == '__main__':
       main()


.. warning::

   External program maps come with serious caveats:

   - **Flush your output.** The program must flush STDOUT after every
     response line. Buffered output will cause httpd to hang waiting
     for a reply. In Python, use ``flush=True`` on ``print()`` or set
     ``PYTHONUNBUFFERED=1``.

   - **Single-process bottleneck.** Only one instance of the program
     runs. All requests that trigger the map are serialized through
     it. If the program is slow, it becomes a bottleneck for the
     entire server.

   - **Hangs are fatal.** If the program blocks without responding,
     httpd will hang waiting for it. There is no timeout.

   - **Crashes are permanent.** If the program dies, all subsequent
     lookups fail. You must restart httpd to relaunch it.

   - **Startup only.** The program is launched when httpd starts (or
     restarts). It is not re-launched on failure.

You can run the program as a specific user and group by adding
a third argument:


.. code-block:: none

   RewriteMap mymap prg:/path/to/program user:group


For most use cases, a ``txt`` or ``dbm`` map — or even ``dbd`` — is
a better choice. Use ``prg`` only when you need logic that cannot be
expressed as a static lookup table.


.. _dbd:


.. index:: pair: RewriteMap types; dbd (SQL query)
.. index:: pair: RewriteMap types; fastdbd

dbd
~~~

A ``dbd`` map looks up keys via a SQL query, using a database
connection managed by ``mod_dbd``. This lets you drive rewrite rules
from a database table that can be updated in real time without touching
configuration files or restarting the server.

There are two variants:

``dbd``
   Executes the query on every lookup. Always returns the freshest
   data but incurs a database round-trip per request.

``fastdbd``
   Caches results in memory after the first lookup. Faster, but
   cached entries are not refreshed until httpd is restarted. Use
   this when the data changes infrequently.

The ``MapSource`` is a SQL ``SELECT`` statement with ``%s`` as a
placeholder for the lookup key:


.. code-block:: none

   RewriteMap myquery "fastdbd:SELECT destination FROM redirects WHERE source = %s"
   RewriteRule ^/r/(.*) ${myquery:$1|/not-found.html} [R=301]


You must also configure ``mod_dbd`` with a database connection:


.. code-block:: apache

   DBDriver  pgsql
   DBDParams "host=dbhost dbname=mydb user=httpd password=secret"
   DBDMin    4
   DBDKeep   8
   DBDMax    20
   DBDExptime 300


If the query returns multiple rows, one is selected at random —
similar to how ``rnd`` maps work. If no rows are returned, the
default value (after ``|``) is used.

**When to use dbd vs fastdbd:** Use ``dbd`` when the underlying data
changes frequently and freshness matters (e.g., a vanity URL shortener
updated by a CMS). Use ``fastdbd`` when the data is relatively stable
and you want to minimize database load (e.g., a redirect table that's
updated weekly).

``mod_dbd`` is required — the ``dbd`` and ``fastdbd`` map types will
produce a configuration error if it is not loaded.

