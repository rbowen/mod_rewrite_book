[[Chapter_mod_rewrite]]
== Introduction to mod_rewrite

mod_rewrite is the power tool of Apache httpd URL mapping. Of course,
sometimes you just need a screwdriver, but when you need the power tool,
it's good to know where to find it.

mod_rewrite provides sophisticated URL via regular expressions, and the
ability to do a variety of transformations,including, but not limited
to, modification of the request URL. You can additionally return a
variety of status codes, set cookies and environment variables, proxy
requests to another server, or send redirects to the client.

In this chapter we'll cover mod_rewrite syntax and usage, and in the
next chapter we'll give a variety of examples of using mod_rewrite in
common scenarios.

[[loading-mod_rewrite]]
=== Loading mod_rewrite

To use mod_rewrite in any context, you need to have the module loaded.
If you're the server administrator, this means having the following line
somewhere in your Apache httpd configuration:

----
LoadModule rewrite_module modules/mod_rewrite.so
----

This tells httpd that it needs to load mod_rewrite at startup time, so
as to make its functionality available to your configuration files.

If you are not the server administrator, then you'll need to ask your
server administrator if the module is available, or experiment to see if
it is. If you're not sure, you can test to see whether it's enabled in
the following manner.

Create a subdirectory in your document directory. Let's call it
test_rewrite

Create a file in that directory called .htaccess and put the following
text in it:

----
RewriteEngine on
----

Create another file in that directory called index.html containing the
following text:

----
<html>
Hello, mod_rewrite
</html>
----

Now, point your browser at that location:

----
http://example.com/test_rewrite/index.html
----

You'll see one of two things. Either you'll see the words
Hello, mod_rewrite in your browser, or you'll see the ominous words
Internal Server Error. In the former case, everything is fine -
mod_rewrite is loaded and your `.htacces` file worked just fine. If you
got an Internal Server Error, that was httpd complaining that it didn't
know what to do with the `RewriteEngine` directive, because mod_rewrite
wasn't loaded.

If you have access to the server's error log file, you'll see the
following in it:

----
Invalid command 'RewriteEngine', perhaps misspelled or defined by a module not included in the server configuration
----

Which is httpd's way of saying that you used a directive
(`RewriteEngine`) without first loading the module that defines that
directive.

If you see the Internal Server Error message, or that log file message,
it's time to contact your server administrator and ask if they'll load
mod_rewrite for you.

However, this is fairly unlikely, since mod_rewrite is a fairly standard
part of any Apache http server's bag of tricks.

[[rewriteengine]]
=== RewriteEngine

In the section above, we used the `RewriteEngine` directive without
defining what it does.

The `RewriteEngine` directive enables or disables the runtime rewriting
engine. The directive defaults to `off`, so the result is that rewrite
directives will be ignored in any scope where you don't have the
following:

----
RewriteEngine On
----

While we won't always include that in every example in this book, it
should be assumed, from this point forward, that every use of
mod_rewrite occurs in a scope where `RewriteEngine` has been turned on.

[[mod_rewrite-in-.htaccess-files]]
=== mod_rewrite in .htaccess files

Before we go any further, it's critical to note that things are
different, in several important ways, if you have to use .htaccess files
for configuration.

[[what-are-.htaccess-files]]
==== What are .htaccess files?

`.htaccess` files are per-directory configuration files, for use by people
who don't have access to the main server configuration file. For the
most part, you put configuration directives into .htaccess files just as
you would in a `<Directory>` block in the server configuration, but
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
`AllowOverride`, has a default value of `All`. In 2.4 and later, it has
a default value of `None`, so .htaccess files are disabled by default.

A typical configuration to permit the use of .htaccess files looks like:

----
<Directory />
    AllowOverride None
</Directory>

DocumentRoot /var/www/html
<Directory /var/www/html>
    AllowOverride All
    Options +FollowSymLinks
</Directory>
----

That is to say, .htaccess files are disallowed for the entire
filesystem, starting at the root, but then are permitted in the document
directories. This prevents httpd
from looking for .htaccess files in `/`, `/var`, and `/var/www` on the way to
looking in `/var/www/html`.footnote:[Or, more to the point, it prevents 
malicious end-users from finding ways to look there.]

Note that in order to enable the use of mod_rewrite directives in
`.htaccess` files, you also need to enable `Options FollowSymLinks`. A
`RewriteRule` may be thought of as a kind of symlink, because it allows
you to serve content from other directories via a rewrite. Thus, for
reasons of security, it is necessary to enable symlinks in order to use
mod_rewrite.

[[ok-so-whats-the-deal-with-mod_rewrite-in-.htaccess-files]]
==== Ok, so, what's the deal with mod_rewrite in .htaccess files?

There are two major differences that you must be aware of before we
proceed any further. The exact implications of these differences will
become more apparent as we go, but I wouldn't want them to surprise you.

First, there are two directives that you cannot use in .htaccess files.
These directives are `RewriteMap` and (prior to httpd 2.4) `RewriteLog`.
These must be defined in the main server configuration. The reasons for
this will be discussed in greater length when we get to the sections
about those directives RewriteMap and RewriteLogging, respectively.).

Second, and more importantly, the syntax of `RewriteRule` directives
changes in .htaccess context in a way that you'll need to be aware of
every time you write a `RewriteRule`. Specifically, the directory path
that you're in will be removed from the URL path before it is presented
to the `RewriteRule`.

The exact implications of this will become clearer as we show you
examples. And, indeed, every example in this book will be presented in a
form for the main config, and a form for .htaccess files, whenever there
is a difference between the two forms. But we'll start with a simple
example to illustrate the idea.

Some of this, you'll need to take on faith at the moment, since we've
not yet introduced several of the concepts presented in this example, so
please be patient for now.

Consider a situation where you want to apply a rewrite to content in the
`/images/puppies/` subdirectory of your website. You have four options:
You can put the `RewriteRule` in the main server configuration file; You
can place it in a .htacess file in the root of your website; You can
place it in a .htaccess file in the `images` directory; Or you can place
it in a .htaccess file in the `images/puppies` directory.

Here's what the rule might look like in those various scenarios:

[cols=",",options="header",]
|===================================================================
|Location |Rule
|Main config |`RewriteRule ^/images/puppies/(.*).jpg /dogs/$1.gif`
|Root directory |`RewriteRule ^images/puppies/(.*).jpg /dogs/$1.gif`
|images directory |`RewriteRule ^puppies/(.*).jpg /dogs/$1.gif`
|images/puppies directory |`RewriteRule ^(.*).jpg /dogs/$1.gif`
|===================================================================

For the moment, don't worry too much about what the individual rules do.
Look instead at the URL path that is being considered in each rule, and
notice that for each directory that a .htaccess file is placed in, the
directory path that `RewriteRule` may consider is relative to that
directory, and anything above that becomes invisible for the purpose of
mod_rewrite.

Don't worry too much if this isn't crystal clear at this point. It will
become more clear as we proceed and you see more examples.

[[so-what-do-i-do]]
==== So, what do I do?

If you don't have access to the main server configuration file, as it
the case for many of the readers of this book, don't despair.
mod_rewrite is still a very powerful tool, and can be persuaded to do
almost anything that you need it to do. You just need to be aware of its
limitations, and adjust accordingly when presented with an example rule.

We aim to help you do that at each step along this journey.

[[rewriteoptions]]
=== RewriteOptions

RewriteOptions TODO

[[rewritebase]]
=== RewriteBase

TODO

