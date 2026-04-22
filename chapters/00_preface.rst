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

The title — *:module:`mod_rewrite` And Friends* — reflects this. We will spend
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
expressions and URL mapping fundamentals before moving into
:module:`mod_rewrite` specifics. If you already know regex and just want the
:module:`mod_rewrite` details, feel free to skip ahead to Chapter 3.

Each chapter includes practical examples, because :module:`mod_rewrite` is
understood far more quickly through examples than through lectures. The
final chapter gathers common recipes in one place for easy reference.

.. index:: pair: Apache HTTP Server; version 2.4
.. index:: pair: Apache HTTP Server; version 2.2

A Note on Versions
------------------

The examples in this book are written for Apache HTTP Server 2.4 and
later. Where behavior differs from earlier versions (particularly 2.2),
this is noted. If you're running something older than 2.4, you should
strongly consider upgrading — not just for :module:`mod_rewrite`, but for the
significant improvements in configuration flexibility, security, and
performance.

.. index:: pair: book formats; reStructuredText
.. index:: pair: book formats; Sphinx

Acknowledgments
---------------

This book has been a work in progress since 2013, and has been through
more format conversions than content revisions — a fact I am not
especially proud of. It has been LaTeX, reStructuredText, AsciiDoc,
Markdown, AsciiDoc again, and finally reStructuredText once more. I am
cautiously optimistic that the format question is now settled.

Thanks are owed to the Apache HTTP Server documentation team, whose
work I have drawn on extensively, and to the many people on the ``#httpd``
IRC channel and the httpd mailing lists who have, over the years, asked
the questions that shaped the content of this book.

And to my muses, Rhi, Z, and E, I love you more than the whole world.

Finally, to Maria, who makes everything beautiful. And so that was all right, Best Beloved. Do you see?

-- Rich Bowen, April 2026
