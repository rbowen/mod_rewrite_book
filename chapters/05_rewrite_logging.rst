.. _Chapter_rewrite_logging:


.. index:: rewrite logging
.. index:: pair: mod_rewrite; logging
.. index:: pair: debugging; mod_rewrite

===============
Rewrite Logging
===============


.. epigraph::

   | Oh, I have slipped the surly bonds of earth
   | And danced the skies on laughter-silvered wings.

   -- John Gillespie Magee Jr., *High Flight*



I can't overstate how important the rewrite log is. When your
``RewriteRule`` doesn't do what you expected — and it won't, at least the
first three times — the rewrite log is where you go to find out what
actually happened. It's the difference between debugging and guessing.

Rewrite logging uses the ``LogLevel`` directive with per-module trace
levels. If you remember nothing else from this chapter, remember this
one line:

.. code-block:: apache

   LogLevel warn rewrite:trace3

That turns on enough :module:`mod_rewrite` logging to see what's happening
without drowning in noise. The rewrite log entries show up in your main
error log (the file specified by ``ErrorLog``), tagged with
``[rewrite:traceN]`` so you can find them.


.. _trace-levels:

.. index:: pair: rewrite logging; trace levels
.. index:: pair: LogLevel; trace levels
.. index:: pair: mod_rewrite; trace levels

Trace Levels
------------

The ``LogLevel`` directive accepts trace levels from ``trace1`` through
``trace8`` for :module:`mod_rewrite`. Each level includes everything from the
levels above it, so ``trace3`` gives you ``trace1`` and ``trace2`` output as
well. Here's what each level gives you:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Level
     - What it logs
   * - ``trace1``
     - Rule match/no-match results — the high-level outcome
   * - ``trace2``
     - Rewrite results and pass-through decisions — what the URL was rewritten to
   * - ``trace3``
     - Rule pattern application — which pattern was applied to which URI
   * - ``trace4``
     - ``RewriteCond`` evaluation details — the input string, the pattern, and whether it matched
   * - ``trace5``
     - ``RewriteMap`` lookups — map name, lookup key, and result (or failure)
   * - ``trace6``
     - Map cache behavior — cache hits and misses
   * - ``trace7``
     - Large data dumps (rarely useful)
   * - ``trace8``
     - Even larger data dumps (almost never useful)

In practice, ``trace3`` is the sweet spot for most debugging. It shows you
which rule is being tried against which URI, without burying you in
condition details. Step up to ``trace4`` or ``trace5`` when you need to
understand *why* a condition didn't match, or when a ``RewriteMap`` lookup
is returning something unexpected.

.. warning::

   Running at ``trace6`` or higher on a production server will slow things
   down noticeably. The server has to write a log entry for practically
   every internal operation :module:`mod_rewrite` performs. Use high trace
   levels only for debugging, and turn them back down when you're done.


Enabling Rewrite Logging
------------------------

.. index:: LogLevel
.. index:: pair: directives; LogLevel
.. index:: pair: logging; httpd 2.4
.. index:: pair: mod_rewrite; trace level

The basic form is simple:

.. code-block:: apache

   LogLevel warn rewrite:trace3

This sets the general log level to ``warn`` (so you're not flooded with
info-level messages from every module) and then cranks :module:`mod_rewrite`
up to ``trace3``. Rewrite log entries show up in your error log, tagged
so they're easy to find.

To view just the rewrite entries in real time, filter the error log:

.. code-block:: bash

   tail -f /var/log/httpd/error_log | fgrep '[rewrite:'


.. _perdir-loglevel:

.. index:: pair: LogLevel; per-directory
.. index:: pair: debugging; per-directory
.. index:: pair: LogLevel; Directory block
.. index:: pair: LogLevel; Location block

Per-Directory Logging
---------------------

Here's something I wish I'd known years earlier: since httpd 2.3.6, you
can set ``LogLevel`` inside a ``<Directory>``, ``<Location>``, or
``<VirtualHost>`` block. This means you can turn on rewrite tracing for
*one specific path* without flooding the log with trace output from every
request to the entire server.

.. code-block:: apache

   # Only debug rewrites under /api/
   <Location "/api/">
       LogLevel warn rewrite:trace4
   </Location>

Or scope it to a single virtual host:

.. code-block:: apache

   <VirtualHost *:443>
       ServerName staging.example.com
       LogLevel warn rewrite:trace3
       # ... your rewrite rules ...
   </VirtualHost>

This is enormously useful on a busy server where a global ``trace3``
would produce an unreadable flood of log entries. Narrow the scope to the
path or vhost you're actually debugging, fix the problem, and remove the
directive. I cannot stress enough how much easier this makes life.

.. note::

   Per-directory log level changes only affect messages generated *after*
   the request has been parsed and associated with a directory. Very early
   request-processing messages (connection-level events) are still
   controlled by the server-level ``LogLevel``.


.. _whats-in-the-rewrite-log---an-example:


.. index:: pair: rewrite logging; examples
.. index:: ErrorLog
.. index:: pair: directives; ErrorLog

What's in the Rewrite Log? — An Example
----------------------------------------

The best way to talk about what's in the rewrite log is to show you some
examples of the kinds of things that :module:`mod_rewrite` logs.

Consider a simple rewrite scenario such as follows:


.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_URI} !index.php
   RewriteRule . /index.php [PT,L]

   LogLevel warn rewrite:trace6


This ruleset says "If it's not already :file:`index.php`, rewrite it to
:file:`index.php`."

Now, I'll make a request for the URL http://localhost/example and see
what gets logged:


.. code-block:: none

   [Thu Sep 10 20:22:13.363463 2026] [rewrite:trace2] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite engine with requested uri /example

   [Thu Sep 10 20:22:13.363510 2026] [rewrite:trace3] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] applying pattern '.' to uri '/example'

   [Thu Sep 10 20:22:13.363525 2026] [rewrite:trace4] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] RewriteCond: input='/example' pattern='!index.php' => matched

   [Thu Sep 10 20:22:13.363533 2026] [rewrite:trace2] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] rewrite '/example' -> 'index.php'

   [Thu Sep 10 20:22:13.363542 2026] [rewrite:trace2] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] local path result: index.php

   [Thu Sep 10 20:22:13.575877 2026] [rewrite:trace2] [pid 11881] mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite engine with requested uri /favicon.ico

   [Thu Sep 10 20:22:13.575920 2026] [rewrite:trace3] [pid 11881] mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] applying pattern '.' to uri '/favicon.ico'

   [Thu Sep 10 20:22:13.575935 2026] [rewrite:trace4] [pid 11881] mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] RewriteCond: input='/favicon.ico' pattern='!index.php' => matched

   [Thu Sep 10 20:22:13.575943 2026] [rewrite:trace2] [pid 11881] mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] rewrite '/favicon.ico' -> 'index.php'

   [Thu Sep 10 20:22:13.575955 2026] [rewrite:trace2] [pid 11881] mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] local path result: index.php


Let's look at the first log entry in detail:


.. code-block:: none

   [Thu Sep 10 20:22:13.363463 2026] [rewrite:trace2] [pid 11879] mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - - [localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite engine with requested uri /example


That's a lot to process all at once, so I'll break it down one field at
a time.


.. index:: pair: rewrite logging; log entry format
.. index:: pair: rewrite logging; process id

``[Thu Sep 10 20:22:13.363463 2026]``
   The date and time when the event occurred.
``[rewrite:trace2]``
   The name of the module logging, and the trace level at which it is
   logging.
``[pid 11879]``
   The process id of the httpd process handling this request. This will
   be the same across a given request. Note that in this example there
   are two separate requests being handled, as you'll see in a moment.
``mod_rewrite.c(468):``
   For in-depth debugging, this is the line number in the module source
   code which is handling the current rewrite.
``[client 127.0.0.1:56623]``
   The client IP address, and TCP port number on which the request
   connection was made.
``-``
   This field contains the client's username in the event that the
   request was authenticated. In this example the request was not
   authenticated, so a blank value is logged.
``-``
   In the event that the request sent ident information, this will be
   logged here. This hardly ever happens, and so this field will almost
   always be ``-``.
``[localhost/sid#7f985f445348][rid#7f985f949040/initial]``
   This is the unique identifier for the request.
``init rewrite engine with requested uri /example``
   Ahah! Finally! The actual log message from :module:`mod_rewrite`!

Now that you know what all of the various fields are in the log entry,
let's just look at the ones I actually care about. Here's the log file
again, with a lot of the superfluous information removed:


.. code-block:: none

   init rewrite engine with requested uri /example
   applying pattern '.' to uri '/example'
   RewriteCond: input='/example' pattern='!index.php' => matched
   rewrite '/example' -> 'index.php'
   local path result: index.php

   init rewrite engine with requested uri /favicon.ico
   applying pattern '.' to uri '/favicon.ico'
   RewriteCond: input='/favicon.ico' pattern='!index.php' => matched
   rewrite '/favicon.ico' -> 'index.php'
   local path result: index.php


I've removed the extraneous information, and split the log entries into
two logical chunks.

In the first bit, the requested URL ``/example`` is run through the
ruleset and ends up getting rewritten to :file:`/index.php`, as desired.

In the second bit, the browser requests the URL :file:`/favicon.ico` as a side
effect of the initial request. ``favicon`` is the icon that appears in
your browser address bar next to the URL, and is an automatic feature of
most browsers. As such, you're likely to see mention of :file:`favicon.ico` in
your log files from time to time, and it's nothing to worry too much
about. You can read more about favicons at
<http://en.wikipedia.org/wiki/Favicon>.

Follow through the log lines for the first of the two requests.

First, the rewrite engine is made aware that it needs to consider a URL,
and the ``init rewrite engine`` log entry is made.

Next, the ``RewriteRule`` pattern ``.`` is applied to the requested URI
``/example``, and this comparison is logged. In your configuration file,
the ``RewriteRule`` appears after the ``RewriteCond``, but at request time,
the ``RewriteRule`` pattern is applied first.

Since the pattern does match, in this case, we continue to the
``RewriteCond``, and the pattern ``!index.php`` is applied to the string
``/example``. Both the pattern and the string it is being applied to are
logged, which can be very useful later on in debugging rules that aren't
behaving quite as you intended. This log line also tells you that the
pattern ``matched``.

Since the ``RewriteRule`` pattern and the ``RewriteCond`` both matched, we
continue on to the right hand side of the ``RewriteRule`` and apply the
rewrite, and ``/example`` is rewritten to :file:`index.php`, which is also
logged. A final log entry tells us what the local path result ends up
being after this process, which is :file:`index.php`.

This kind of detailed log trail tells you very specifically what's going
on, and what happened at each step.


.. _rewriterules-in-.htaccess-files---an-example:


.. index:: pair: .htaccess; rewrite logging
.. index:: pair: per-directory context; logging
.. index:: pair: .htaccess; perdir prefix stripping

RewriteRules in .htaccess Files — An Example
---------------------------------------------

.. index:: pair: .htaccess; rewrite log example
.. index:: perdir prefix stripping

I've previously discussed using :module:`mod_rewrite` in :file:`.htaccess` files, but
it's time to see what this actually looks like in practice. Let's
replace the configuration file entry above with a :file:`.htaccess` file
instead, placed in the root document directory of the website. So, I'm
going to comment out several lines in the server configuration:


.. code-block:: apache

   # RewriteEngine On
   # RewriteCond %{REQUEST_URI} !index.php
   # RewriteRule . /index.php [PT,L]

   LogLevel warn rewrite:trace6


And instead, I'm going to place the following :file:`.htaccess` file:


.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REQUEST_URI} !index.php
   RewriteRule . /index.php [PT,L]


Now, see what the log file looks like.

For the sake of brevity, let's look at just the actual log messages, and
ignore all of the extra information:


.. code-block:: none

   [perdir /var/www/html/] strip per-dir prefix: /var/www/html/example -> example
   [perdir /var/www/html/] applying pattern '.' to uri 'example'
   [perdir /var/www/html/] input='/example' pattern='!index.php' => matched
   [perdir /var/www/html/] rewrite 'example' -> '/index.php'
   [perdir /var/www/html/] forcing '/index.php' to get passed through to next API URI-to-filename handler
   [perdir /var/www/html/] internal redirect with /index.php [INTERNAL REDIRECT]
   [perdir /var/www/html/] strip per-dir prefix: /var/www/html/index.php -> index.php
   [perdir /var/www/html/] applying pattern '.' to uri 'index.php'
   [perdir /var/www/html/] RewriteCond: input='/index.php' pattern='!index.php' => not-matched
   [perdir /var/www/html/] pass through /var/www/html/index.php


The first thing you'll notice is that this is much longer
than what I had before. Running rewrite rules in :file:`.htaccess` files
generally takes several more steps than when the rules are in the server
configuration file, which is one of several reasons that using :file:`.htaccess`
files is so much less efficient (i.e., slower) than using the server
configuration file.

Whenever possible, you should use the server configuration file rather
than :file:`.htaccess` files. (There are other reasons for this, too.)

Next, you'll notice that each log entry contains the preface:


.. code-block:: none

   [perdir /var/www/html]


``perdir`` refers to rewrite directives that occur in per-directory
context — i.e., :file:`.htaccess` files or ``<Directory>`` blocks. They are
treated specially in a few different ways, as we'll see.

The first of these is shown in the first log entry:


.. code-block:: none

   strip per-dir prefix: /var/www/html/example -> example


What that means is that in per-directory context, the directory path is removed
from any string before they are considered in the pattern match. Thus,
rather than considering the string ``/example``, as I did the first time
through, now we're looking at the string ``example``. This distinction
matters more than it looks like it should — as we proceed to more complex examples, that
leading slash will be the difference between a pattern matching and not
matching, so you need to be aware of this every time you use :file:`.htaccess`
files.

The next few lines of the log proceed as before, except that we're
looking at ``example`` rather than ``/example`` in each line. Carefully
compare the log entries from the first time through to the ones this
time.

What happens next is a surprise to most first-time users of :module:`mod_rewrite`.
The requested URI ``example`` is redirected to the URI :file:`/index.php`, and
the whole process starts over again with that new URL. This is because,
in per-directory context, once a rewrite has been executed, that target URL
must get passed back to the URL mapping process to determine what that
URL maps to ... which may include invoking a :file:`.htaccess` file.

In this case, this causes the ruleset to be executed all over again,
with the rewritten URL :file:`/index.php`.

The remainder of the log should look very familiar. It's the same as
what we saw before, with :file:`/index.php` getting stripped to :file:`index.php`
and run through the paces. This time around, however, the ``RewriteCond``
does not match, and so the request is passed through unchanged.


.. _debugging-rewritemap:

.. index:: pair: RewriteMap; debugging
.. index:: pair: RewriteMap; logging
.. index:: pair: rewrite logging; map lookups

Debugging RewriteMap Lookups
----------------------------

If you're using a ``RewriteMap`` (see :ref:`Chapter_rewritemap`) and the
lookup isn't returning what you expect, ``trace5`` is where you want to
be. At that level, :module:`mod_rewrite` logs every map lookup — the map name,
the key that was looked up, and the result (or the fact that the lookup
failed).

.. code-block:: apache

   LogLevel warn rewrite:trace5

You'll see log entries like:

.. code-block:: none

   map lookup OK: map=examplemap key=foo -> val=bar
   map lookup FAILED: map=examplemap key=baz

This is invaluable when you're debugging ``txt`` or ``dbm`` maps where a
typo in the map file (an extra space, a missing entry) can silently cause
a lookup to fail and your rule to not match. At ``trace6``, you'll also
see cache-related entries — whether the map result came from the internal
cache or required a fresh lookup. This is mostly useful if you suspect
the map file has been updated but the cached values are stale.


.. _dont-leave-it-on:

.. index:: pair: rewrite logging; performance
.. index:: pair: mod_rewrite; performance impact of logging

Don't Leave It On
-----------------

I want to re-emphasize: don't
leave trace-level rewrite logging enabled on a production server. Every
trace-level log entry requires :module:`mod_rewrite` to format a string, acquire
a lock on the log file, write the entry, and release the lock — for
*every single request* that touches a rewrite rule.

On a server handling thousands of requests per second, ``rewrite:trace6``
can measurably increase response times and generate gigabytes of log data
in short order. I've seen it fill a disk partition in under an hour on a
busy server. 

The workflow is: turn it on, reproduce the problem, read the log, turn
it off. If you're using per-directory logging (see :ref:`perdir-loglevel`
above), the blast radius is already limited — but even so, clean up after
yourself.
