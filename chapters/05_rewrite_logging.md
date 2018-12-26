[[Chapter_rewrite_logging]]
== Rewrite Logging

Exactly how you turn on logging for mod_rewrite will depend on what
version of the Apache http server you are running. Logging got some
updates in the 2.4 release of the server, and the rewrite log was one of
the changes that happened at that time.

If you're not sure what version you're running, you can get the `httpd`
binary to tell you with the `-v` flag:

----
httpd -v
----

As with any other logging, the log file is opened when the server is
started up, before the server relinquishes its root privileges. For this
reason, the `RewriteLog` directive may not be used in `.htaccess` files,
but may only be invoked in the server configuration file.

[[and-earlier]]
2.2 and earlier

Prior to httpd 2.4, the way to enable mod_rewrite logging is with the
`RewriteLog` and `RewriteLogLevel` directives.

The `RewriteLog` directive should be set to the location of your rewrite
log file, and the `RewriteLogLevel` is set to a value from 0 to 5 to
indicate the desired verbosity of the log file, with 0 being no log
entries, and 5 being to log every time mod_rewrite even thinks about
doing something.

You'll often find advice online suggesting that `RewriteLogLevel` be set
to 9 for maximum verbosity. Numbers higher than 5 don't make it more
verbose, but they also don't harm anything.

----
RewriteLog logs/rewrite.log
RewriteLogLevel 5
----

[[and-later]]
2.4 and later

In the 2.4 version of the server, many changes were made to the way that
logging works. One of these changes was the addition of per-module log
configurations. This rendered the `RewriteLog` directive superfluous.
So, from 2.4 on, rewrite logging is enabled using the `LogLevel`
directive, specifying a `trace` log level for mod_rewrite.

----
LogLevel info rewrite:trace6
----

Rewrite log entries will now show up in the main error log file, as
specified by the `ErrorLog` directive.

[[whats-in-the-rewrite-log---an-example]]
What's in the Rewrite log? - An example

The best way to talk about what's in the rewrite log is to show you some
examples of the kinds of things that mod_rewrite logs.

Consider a simple rewrite scenario such as follows:

----
RewriteEngine On
RewriteCond %{REQUEST_URI} !index.php
RewriteRule . /index.php [PT,L]

LogLevel info rewrite:trace6

# Or, in 2.2
# RewriteLog Level 5
# RewriteLog /var/log/httpd/rewrite.log
----

This ruleset says "If it's not already `index.php`, rewrite it to
`index.php`.

Now, we'll make a request for the URL http://localhost/example and see
what gets logged:

----
[Thu Sep 12 20:22:13.363463 2013] [rewrite:trace2] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite
engine with requested uri /example

[Thu Sep 12 20:22:13.363510 2013] [rewrite:trace3] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] applying
pattern '.' to uri '/example'

[Thu Sep 12 20:22:13.363525 2013] [rewrite:trace4] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] RewriteCond:
input='/example' pattern='!index.php' => matched

[Thu Sep 12 20:22:13.363533 2013] [rewrite:trace2] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] rewrite
'/example' -> 'index.php'

[Thu Sep 12 20:22:13.363542 2013] [rewrite:trace2] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] local path
result: index.php

[Thu Sep 12 20:22:13.575877 2013] [rewrite:trace2] [pid 11881]
mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite
engine with requested uri /favicon.ico

[Thu Sep 12 20:22:13.575920 2013] [rewrite:trace3] [pid 11881]
mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] applying
pattern '.' to uri '/favicon.ico'

[Thu Sep 12 20:22:13.575935 2013] [rewrite:trace4] [pid 11881]
mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] RewriteCond:
input='/favicon.ico' pattern='!index.php' => matched

[Thu Sep 12 20:22:13.575943 2013] [rewrite:trace2] [pid 11881]
mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] rewrite
'/favicon.ico' -> 'index.php'

[Thu Sep 12 20:22:13.575955 2013] [rewrite:trace2] [pid 11881]
mod_rewrite.c(468): [client 127.0.0.1:56624] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] local path
result: index.php
----

This is an entry from a 2.4 server, and contains a few elements that
will be missing from rewrite log entries for 2.2 and
earlier.footnote:[Future editions of this book will contain full
examples from a 2.2 server, for those still running that version.]

Note that I've inserted linebreaks between each log entry for
legibility. And speaking of legibility, let's consider one single log
entry to see what the various components mean before we go any further.

Let's look at the first log entry.

:

----
[Thu Sep 12 20:22:13.363463 2013] [rewrite:trace2] [pid 11879]
mod_rewrite.c(468): [client 127.0.0.1:56623] 127.0.0.1 - -
[localhost/sid#7f985f445348][rid#7f985f949040/initial] init rewrite
engine with requested uri /example
----

That's a lot to process all at once, so we'll break it down one field at
a time.

`[Thu Sep 12 20:22:13.363463 2013]`::
  The date and time when the event occurred.
`[rewrite:trace2]`::
  The name of the module logging, and the loglevel at which it is
  logging. This is 2.4-specific
`[pid 1879]`::
  The process id of the httpd process handling this request. This will
  be the same across a given request. Note that in this example there
  are two separate requests being handled, as you'll see in a moment.
`mod_rewrite.c(468):`::
  For in-depth debugging, this is the line number in the module source
  code which is handling the current rewrite.
`[client 127.0.0.1:56623]`::
  The client IP address, and TCP port number on which the request
  connection was made.
`-`::
  This field contains the client's username in the event that the
  request was authenticated. In this example the request was not
  authenticated, so a blank value is logged.
`-`::
  In the event that the request sent ident information, this will be
  logged here. This hardly ever happens, and so this field will almost
  always be `-`.
`[localhost/sid#7f985f445348][rid#7f985f949040/initial]`::
  This is the unique identifier for the request.
`init rewrite engine with requested uri /example`::
  Ahah! Finally! The actual log message from mod_rewrite!

Now that you know what all of the various fields are in the log entry,
let's just look at the ones we actually care about. Here's the log file
again, with a lot of the superfluous information removed:

----
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
----

I've removed the extraneous information, and split the log entries into
two logical chunks.

In the first bit, the requested URL `/example` is run through the
ruleset and ends up getting rewritten to `/index.php`, as desired.

In the second bit, the browser requests the URL `/favicon.ico` as a side
effect of the initial request. `favicon` is the icon that appears in
your browser address bar next to the URL, and is an automatic feature of
most browsers. As such, you're likely to see mention of `favicon.ico` in
your log files from time to time, and it's nothing to worry too much
about. You can read more about favicons at
<http://en.wikipedia.org/wiki/Favicon>.

Follow through the log lines for the first of the two requests.

First, the rewrite engine is made aware that it needs to consider a URL,
and the `init rewrite engine` log entry is made.

Next, the `RewriteRule` pattern `.` is applied to the requested URI
`/example`, and this comparison is logged. In your configuration file,
the `RewriteRule` appears after the `RewriteCond`, but at request time,
the `RewriteRule` pattern is applied first.

Since the pattern does match, in this case, we continue to the
`RewriteCond`, and the pattern `!index.php` is applied to the string
`/example`. Both the pattern and the string it is being applied to are
logged, which can be very useful later on in debugging rules that aren't
behaving quite as you intended. This log line also tells you that the
pattern `matched`.

Since the `RewriteRule` pattern and the `RewriteCond` both matched, we
continue on to the right hand side of the `RewriteRule` and apply the
rewrite, and `/example` is rewritten to `index.php`, which is also
logged. A final log entry tells us what the local path result ends up
being after this process, which is `index.php`.

This kind of detailed log trail tells you very specifically what's going
on, and what happened at each step.footnote:[Future editions of this
bill will contain an appendix in which several log traces are explained
in exhaustive detail. I can hardly wait.]

[[rewriterules-in-.htaccess-files---an-example]]
RewriteRules in .htaccess files - An example

We've previously discussed using mod_rewrite in .htaccess files, but
it's time to see what this actually looks like in practice. Let's
replace the configuration file entry above with a .htaccess file
instead, placed in the root document directory of our website. So, I'm
going to comment out several lines in the server configuration:

----
# RewriteEngine On
# RewriteCond %{REQUEST_URI} !index.php
# RewriteRule . /index.php [PT,L]

LogLevel info rewrite:trace6

# Or, in 2.2
# RewriteLog Level 5
# RewriteLog /var/log/httpd/rewrite.log
----

And instead, I'm going to place the following .htaccess file:

----
RewriteEngine On
RewriteCond %{REQUEST_URI} !index.php                                     
RewriteRule . /index.php [PT,L]
----

Now, see what the log file looks like:

For the sake of brevity, let's look at just the actual log messages, and
ignore all of the extra information:

----
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
----

The first thing you'll notice, of course, is that this is much longer
than what we had before. Running rewrite rules in .htaccess files
generally takes several more steps than when the rules are in the server
configuration file, which is one of several reasons that using .htaccess
files is so much less efficient (i.e., slower) than using the server
configuration file.

Whenever possible, you should use the server configuration file rather
than .htaccess files. (There are other reasons for this, too.)

Next, you'll notice that each log entry contains the preface:

----
[perdir /var/www/html]
----

`perdir` refers to rewrite directives that occur in per directory
context - i.e., .htaccess files or `<Directory>` blocks. They are
treated special in a few different ways, as we'll see.

The first of these is shown in the first log entry:

----
strip per-dir prefix: /var/www/html/example -> example
----

What that means is that in perdir context, the directory path is removed
from any string before they are considered in the pattern match. Thus,
rather than considering the string `/example`, as we did the first time
through, now we're looking at the string `example`. While this may seem
trivial at this point, as we proceed to more complex examples, that
leading slash will be the difference between a pattern matching and not
matching, so you need to be aware of this every time you use `.htaccess`
files.

The next few lines of the log proceed as before, except that we're
looking at `example` rather than `/example` in each line. Carefully
compare the log entries from the first time through to the ones this
time.

What happens next is a surprise to most first-time users of mod_rewrite.
The requested URI `example` is redirected to the URI `/index.php`, and
the whole process starts over again with that new URL. This is because,
in perdir context, once a rewrite has been executed, that target URL
must get passed back to the URL mapping process to determine what that
URL maps to ... which may include invoking a .htaccess file.

In this case, this causes the ruleset to be executed all over again,
with the rewritten URL `/index.php`.

The remainder of the log should look very familiar. It's the same as
what we saw before, with `/index.php` getting stripped to `index.php`
and run through the paces. This time around, however, the `RewriteCond`
does not match, and so the request is passed through unchanged.


