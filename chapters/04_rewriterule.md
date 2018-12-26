[[Chapter_rewriterule]]
== RewriteRule

We'll start the main technical discussion of mod_rewrite with the
RewriteRule directive, as it is the workhorse of mod_rewrite, and the
directive that you'll encounter most frequently.

RewriteRule performs manipulation of a requested URL, and along the way
can do a number of additional things.

The syntax of a RewriteRule is fairly simple, but you'll find that
exploring all of the possible permutations of it will take a while. So
we'll provide a lot of examples along the way to illustrate.

If you learn best by example, you may want to jump back and forth
between this section and <<rewrite-examples>> to help you make sense
of this all.


[[syntax]]
=== Syntax

A RewriteRule directive has two required directives and optional flags.
It looks like:

----
RewriteRule PATTERN TARGET [FLAGS]
----

The following sections will discuss each of those arguments in great
detail, but these are defined as:

PATTERN::
  A regular expression to be applied to the requested URI.
TARGET::
  What the URI will be rewritten to.
FLAGS::
  Optional flags that modify the behavior of the rule.

[[pattern]]
=== Pattern

The `PATTERN` argument of the `RewriteRule` is a regular expression that
is applied to the URL path, or file path, depending on the context.

In VirtualHost context, or in server-wide context, `PATTERN` will be
matched against the part of the URL after the hostname and port, and
before the query string. For example, in the URL
<http://example.com/dogs/index.html?dog=collie>, the pattern will be
matched against `/dogs/index.html`.

In Directory and htaccess context, `PATTERN` will be matched against the
filesystem path, after removing the prefix that led the server to the
current `RewriteRule` (e.g. either "dogs/index.html" or "index.html"
depending on where the directives are defined).

Subsequent `RewriteRule` patterns are matched against the output of the
last matching `RewriteRule`.

It is assumed, at this point, that you've already read the chapter
Introduction to Regular Expressions, and/or are familiar with what a
regular expression is, and how to craft one.

[[target]]
=== Target

The target of a `RewriteRule` can be one of the following:

[[a-file-system-path]]
==== A file-system path

Designates the location on the file-system of the resource to be
delivered to the client. Substitutions are only treated as a file-system
path when the rule is configured in server (virtualhost) context and the
first component of the path in the substitution exists in the
file-system

[[url-path]]
==== URL-path

A DocumentRoot-relative path to the resource to be served. Note that
mod_rewrite tries to guess whether you have specified a file-system path
or a URL-path by checking to see if the first segment of the path exists
at the root of the file-system. For example, if you specify a
Substitution string of `/www/file.html`, then this will be treated as a
URL-path unless a directory named www exists at the root or your
file-system (or, in the case of using rewrites in a .htaccess file,
relative to your document root), in which case it will be treated as a
file-system path. If you wish other URL-mapping directives (such as
Alias) to be applied to the resulting URL-path, use the `[PT]` flag as
described below.

[[absolute-url]]
==== Absolute URL

If an absolute URL is specified, mod_rewrite checks to see whether the
hostname matches the current host. If it does, the scheme and hostname
are stripped out and the resulting path is treated as a URL-path.
Otherwise, an external redirect is performed for the given URL. To force
an external redirect back to the current host, see the `[R]` flag below.

[[dash]]
==== - (dash)

A dash indicates that no substitution should be performed (the existing
path is passed through untouched). This is used when a flag (see below)
needs to be applied without changing the path.


