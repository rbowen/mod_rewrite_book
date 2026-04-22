.. _Chapter_rewriterule:


.. index:: RewriteRule
.. index:: pair: directives; RewriteRule
.. index:: pair: RewriteRule; syntax

===========
RewriteRule
===========

.. epigraph::

   | Them that takes cakes
   | Which the Parsee-man bakes
   | Makes dreadful mistakes.

   -- Rudyard Kipling, *How the Rhinoceros Got His Skin*



We'll start the main technical discussion of :module:`mod_rewrite` with the
RewriteRule directive, as it is the workhorse of :module:`mod_rewrite`, and the
directive that you'll encounter most frequently.

RewriteRule performs manipulation of a requested URL, and along the way
can do a number of additional things.

The syntax of a RewriteRule is fairly simple, but you'll find that
exploring all of the possible permutations of it will take a while. So
we'll provide a lot of examples along the way to illustrate.

If you learn best by example, you may want to jump back and forth
between this section and :ref:`Chapter_recipes` to help you make sense
of this all.


.. _syntax:


.. index:: pair: RewriteRule; PATTERN
.. index:: pair: RewriteRule; TARGET
.. index:: pair: RewriteRule; FLAGS

Syntax
------


A RewriteRule directive has two required directives and optional flags.
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
before the query string. For example, in the URL
<http://example.com/dogs/index.html?dog=collie>, the pattern will be
matched against :file:`/dogs/index.html`.

In Directory and htaccess context, ``PATTERN`` will be matched against the
filesystem path, after removing the prefix that led the server to the
current ``RewriteRule`` (e.g. either "dogs/index.html" or "index.html"
depending on where the directives are defined).

Subsequent ``RewriteRule`` patterns are matched against the output of the
last matching ``RewriteRule``.

It is assumed, at this point, that you've already read the chapter
Introduction to Regular Expressions, and/or are familiar with what a
regular expression is, and how to craft one.

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


