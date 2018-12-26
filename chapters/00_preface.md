[[preface]]
== Preface

`mod_rewrite` is one of the most powerful modules that comes with the
Apache http server. It's also one of the most frequently misused, and
least understood. Thousands of examples are posted daily on various
websites, showing beginners how to do things with `mod_rewrite`, and,
unfortunately, the vast majority of them are wrong in various ways,
subtle or grevious, due to misunderstandings of how `mod_rewrite` works,
or how regular expressions work.

This book is a humble attempt to disperse some of the mystery
surrounding `mod_rewrite` and make its power accessible to all users of
the Apache web server.

It will also cover many of the cases in which you should not use
`mod_rewrite`, and what you should use instead in those situations.

=== About This Book

The first incarnation of this book, 
*The Definitive Guide to Apache mod_rewrite* - <http://drbacchus.com/book/rewrite>,
was published in 2006.  
Since then, so much has changed that while that book is still useful,
it's far from complete.

In February of 2012, Apache httpd version 2.4 was released, with a huge
number of enhancements and changes. Many of the things that people have
been using `mod_rewrite` for now have better solutions. Meanwhile,
`mod_rewrite` itself improved quite a bit, too, and can do many new
things.

This book still focuses primarily on `mod_rewrite`, but will touch on
many of the surrounding topics and modules.

That said, the scope of this book has expanded (since the earlier
incarnation) to include not merely URL
rewriting, but also methods for munging (modifying) content, and
dynamic conditional configuration. In many cases, these techniques make
mod_rewrite unnecessary, or, at least, provide easier alternatives, so
they fit the scope of the book very well.

These techniques include mod_substitute, mod_proxy_html, the `Define`
directive, the `<If>` container, `mod_macro`, and many more. Along the
way, we'll also discuss the various parts of URL mapping, the
understanding of which allows you to avoid using these more complicated
techniques.

=== How this book is organized

This book consists of 13 chapters. Depending on your level of existing
expertise, some of them can be safely skipped.

Chapter 1 - <<Chapter_regular_expressions>>  - This chapter gives an
introduction to regular expressions, which are the language of
`mod_rewrite`. 

Chapter 2 - <<Chapter_url_mapping>> - URL rewriting is a portion of a
larger topic called URL mapping - the process by which Apache httpd
translates a requested URL into an actual resource that it will serve.

Chapter 3 - <<Chapter_mod_rewrite>> - An introduction to `mod_rewrite`,
covering some of the configuration directives that need to be set up
before you start rewriting.

Chapter 4 - <<Chapter_rewriterule>> - The `RewriteRule` directive is the
one you'll be using most often. This chapter covers its syntax and
usage.

Chapter 5 - <<Chapter_rewrite_logging>> - The rewrite log is a great
debugging tool, and also a good way to learn about how `mod_rewrite`
thinks about things.

Chapter 6 - <<Chapter_rewriterule_flags>> - Flags modify the behavior of
`RewriteRule`. They've been introduced in the previous chapter, but this
chapter covers each flag in detail, with examples.

Chapter 7 - <<Chapter_rewritecond>> - `RewriteCond` allows you to put
conditions on the running of a particular `RewriteRule`.

Chapter 8 - <<Chapter_rewritemap>> - The `RewriteMap` directive allows
you to craft your own `RewriteRule` logic and lookup tables.

Chapter 9 - <<Chapter_proxy>> - `RewriteRule`'s `[P]` flag lets you pass
a request through a proxy. This chapter digs into that in greater
detail.

Chapter 10 - <<Chapter_vhosts>> - Using `RewriteRule` to manage virtual
hosts.

Chapter 11 - <<Chapter_access>> - Using `RewriteRule` to control or
restrict access to resources.

Chapter 12 - <<Chapter_configurable_configuration>> - New in version 2.4
of the web server is a class of directives that let you add intelligence
and request-time decisions to the configuration. These techniques
replace many of the things that people used to use `mod_rewrite` for.

Chapter 13 - <<Chapter_content_munging>> - In this chapter, we
discuss rewriting content sent to the client, which is not something
that `mod_rewrite` does.

=== Other Sources of Wisdom

A brief word about the documentation. The official docs, at <http://httpd.apache.org/docs/current>,
are great, and are the work of many dedicated people. I'm one of many. This book is 
intended to augment those docs, and not replace them. If it appears sometimes that 
I have copied shamelessly from the documentation, I humbly ask you to remember that 
I participated in writing those docs, and the edits flowed both directions -- that 
is, sometimes it was the docs that shamelessly copied from the book.

This book does *not* attempt to be a comprehensive book about the
Apache web server. For that, I encourage you to look the documentation
and also at my other book,
*Apache Cookbook, Third Edition*, by Rich Bowen and Ken Coar,
which should be available around the
same time that this book is published.

You should also acquire a copy of Jeffrey Friedl's excellent book,
*Mastering Regular Expressions* -
<http://shop.oreilly.com/product/9780596528126.do>  While the book is
several years old, it is still the best book on the topic.

=== Technical details

This book is written in Asciidoc - <http://asciidoc.org/> - 
and is processed into various other formats
using Asciidoctor - <http://asciidoctor.org/>

Previous incarnations were written in LaTeX,
ReStructuredText, Markdown, and who knows what else. There always seems
to be a new book format out there. It's exhausting.

You can always obtain the most recent version of
the book at `http://mod-rewrite.org/`, and you'll usually be able to buy a 
fairly recent version in the Amazon Kindle store. Some day, there will 
hopefully be a printed version, too.

=== Contact information, and errata reporting

If you'd like to get involved in the creation of this book, or if you'd like to 
tell me about something that needs fixed, Go to GitHub -
<https://github.com/rbowen/modrewrite_book> - and either submit pull requests
or open a ticket. If you don't know what that means, you are welcome to 
submit errata to <rbowen@rcbowen.com>, and some day there will be a handy
way to do this on the website. Not today.

This book is a work in progress. If you purchased the book in electronic
form, you should be eligible to receive updates from wherever you bought
it. If you're not, send me your email receipt <rbowen@rcbowen.com>, 
and I'll send you an updated version.

=== About the Author

Rich Bowen has been involved on the Apache http server documentation
since about 1998. He is also the author of *Apache Cookbook*, and *The
Definitive Guide to Apache mod_rewrite*. You can frequently find him in
#httpd, on `irc.freenode.net`. under the name of DrBacchus or rbowen.

Rich works at Red Hat, in the OSAS (Open Source and Standards) group,
where he is an Open Source Community Manager. See
<http://community.redhat.com/> for details.

He lives in Lexington, Kentucky, with his wife and kids. 

=== Acknowledgements

Thanks to `fajita`, and the other regulars on #httpd (on the `irc.freenode.net` 
network). `fajita` is my research assistant, and knows more than everyone else on
the channel put together. And the folks on #ahd who keep me sane. Or insane. 
Depending on how you measure. A warm hog to each of you.

None of this would be possible without `mod_rewrite`
itself, so a big thank you to Ralf Engelschall for creating it, and
all the many people who have worked on the code and documentation since
then.

Finally, a thank you to my muses, Rhi, Z, and E. And to Maria, who makes
everything beatiful. And so that's all right, Best Beloved, do you see?

