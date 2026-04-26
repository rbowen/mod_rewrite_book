.. index:: mod_rewrite
.. index:: pair: Apache HTTP Server; mod_rewrite
.. index:: URL mapping

=======
Preface
=======

.. epigraph::

   | They stared at the branch. There wasn't just one flower
   | out there, there were dozens, although the frogs weren't
   | able to think like this because frogs can't count beyond
   | one.
   |
   | They saw lots of ones.

   -- Terry Pratchett, *Wings*

:module:`mod_rewrite` is the Swiss Army knife of the Apache HTTP Server. It is
also, by a wide margin, the most misunderstood module in the entire
server distribution. In my years of answering questions on the httpd
support channels, I've observed that most of the confusion around
:module:`mod_rewrite` comes not from the module itself, but from the regular
expressions it relies on, and from a lack of awareness that simpler
tools often exist to do the job.

This book has two goals. The first is to teach you :module:`mod_rewrite` — how
it works, how to read and write rewrite rules, how to debug them when
they go wrong, and how to know when you've got the right solution. The
second, and perhaps more important, goal is to teach you when *not* to
use :module:`mod_rewrite`. The Apache HTTP Server ships with a remarkable
number of URL mapping tools, and reaching for :module:`mod_rewrite` first is
a common and unnecessary habit.


.. index:: mod_alias
.. index:: mod_proxy
.. index:: If directive
.. index:: content negotiation

The title — *mod_rewrite And Friends* — reflects this. We will spend
considerable time on :module:`mod_rewrite`, but also on :module:`mod_alias`,
:module:`mod_proxy`, ``<If>`` blocks, and the various other modules and
directives that handle URL mapping, content negotiation, and request
routing. Understanding all of these tools means you'll choose the right
one for the job, rather than hammering everything with the same regular
expression–shaped nail.

.. index:: .htaccess
.. index:: pair: configuration; .htaccess

Who This Book Is For
--------------------

This book is for anyone who administers or develops for the Apache HTTP
Server and needs to control how URLs are handled. That includes system
administrators managing virtual hosts, web developers wrangling
redirects, and the occasional desperate soul staring at a :file:`.htaccess`
file at 2 AM wondering why nothing works.

I assume you're comfortable with a text editor and a terminal. I do
*not* assume you already know regular expressions —
:ref:`Chapter 1 <Chapter_regex>` covers them from scratch.

.. index:: regular expressions

How To Read This Book
---------------------

The chapters are arranged to build on one another, starting with regular
expressions (Chapter 1) and URL mapping fundamentals (Chapter 2) before
moving into :module:`mod_rewrite` specifics. If you already know regex and
just want the :module:`mod_rewrite` details, skip ahead to Chapter 3.

Chapters 3 through 8 form the core reference: the ``RewriteRule``
directive, logging, flags, ``RewriteCond``, and ``RewriteMap``. These
build on each other, so reading them in order is worthwhile.

Chapters 9 through 13 are topical — proxying, virtual hosts, access
control, conditional configuration, and content manipulation. Each one
stands alone, so read whichever is relevant to your current problem.

Chapter 14 gathers common recipes in one place for quick reference.
Each chapter includes practical examples, because :module:`mod_rewrite`
is understood far more quickly through examples than through lectures.

.. index:: pair: Apache HTTP Server; version 2.4
.. index:: pair: Apache HTTP Server; version 2.2

A Note on Versions
------------------

The examples in this book target Apache HTTP Server 2.4 and later. If
you're running something older than 2.4, you should strongly consider
upgrading — not just for :module:`mod_rewrite`, but for the significant
improvements in configuration flexibility, security, and performance.

.. index:: pair: book formats; reStructuredText
.. index:: pair: book formats; Sphinx

Errata and Feedback
-------------------

Found an error, have a suggestion, or want to contribute? Please file
an issue at https://github.com/rbowen/mod_rewrite_book/issues.

Acknowledgments
---------------

This book has been a work in progress since 2013, and I expect it to
remain in progress for some time to come. But I think it's time to call
it ... if not done, then ready to see the light.

Thanks are owed to the Apache HTTP Server documentation team, whose
work I have drawn on extensively, and to the many people on the ``#httpd``
IRC channel (and later, Slack channel) and the httpd mailing lists who have, 
over the years, asked the questions that shaped the content of this book.

And to my muses, Rhi, Z, and E: I love you more than the whole world.

Finally, to Maria, who makes everything beautiful. And so that was all right, Best Beloved. Do you see?

-- Rich Bowen, April 2026

.. rubric:: Trademarks

Apache, Apache HTTP Server, and the Apache oak leaf logo are trademarks
of The Apache Software Foundation. All other trademarks are the
property of their respective owners. Use of these trademarks does not
imply endorsement by The Apache Software Foundation. This book is not
affiliated with or endorsed by The Apache Software Foundation.

