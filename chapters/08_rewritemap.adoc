[[Chapter_rewritemap]]
== RewriteMap

The `RewriteMap` directive gives you a way to call external mapping
routines to simplify a `RewriteRule`. This external mapping can be a
flat text file containing one-to-one mappings, or a database, or a
script that produces mapping rules, or a variety of other similar
things. In this chapter we'll discuss how to use a `RewriteMap` in a
`RewriteRule` or `RewriteCond`.

[[creating-a-rewritemap]]
=== Creating a RewriteMap

The `RewriteMap` directive creates an alias which you can then invoke in
either a `RewriteRule` or `RewriteCond` directive. You can think of it
as defining a function that you can call later on.

The syntax of the `RewriteMap` directive is as follows:

----
RewriteMap MapName MapType:MapSource
----

Where the various parts of that syntax are defined as:

MapName::
  The name of the 'function' that you're creating
MapType::
  The type of the map. The various available map types are discussed
  below.
MapSource::
  The location from which the map definition will be obtained, such as a
  file, database query, or predefined function.

The `RewriteMap` directive must be used either in virtualhost context,
or in global server context. This is because a `RewriteMap` is loaded at
server startup time, rather than at request time, and, as such, cannot
be specified in a `.htaccess` file.

[[using-a-rewritemap]]
=== Using a RewriteMap

Once you have defined a `RewriteMap`, you can then use it in a
`RewriteRule` or `RewriteCond` as follows:

----
RewriteMap examplemap txt:/path/to/file/map.txt
RewriteRule ^/ex/(.*) ${examplemap:$1}
----

Note in this example that the `RewriteMap`, named 'examplemap', is
passed an argument, `$1`, which is captured by the `RewriteRule`
pattern. It can also be passed an argument of another known variable.
For example, if you wanted to invoke the `examplemap` map on the entire
requested URI, you could use the variable `%{REQUEST_URI}` rather than
`$1` in your invocation:

----
RewriteRule ^ ${examplemap:%{REQUEST_URI}}
----

[[rewritemap-types]]
=== RewriteMap Types

There are a number of different map types which may be used in a
`RewriteMap`.

[[int]]
==== int

An `int` map type is an internal function, pre-defined by `mod_rewrite`
itself. There are four such functions:

[[toupper]]
==== toupper

The `toupper` internal function converts the provided argument text to
all upper case characters.

----
# Convert any lower-case request to upper case and redirect
RewriteMap uc int:toupper
RewriteRule (.*?[a-z]+.*) ${uc:$1} [R=301]
----

[[tolower]]
==== tolower

The `tolower` is the opposite of `toupper`, converting any argument text
to lower case characters.

----
# Convert any upper-case request to lower case and redirect
RewriteMap lc int:tolower
RewriteRule (.*?[A-Z]+.*) ${lc:$1} [R=301]
----

[[escape]]
==== escape

[[unescape]]
==== unescape

[[txt]]
=== txt

A `txt` map defines a one-to-one mapping from argument to target.

[[rnd]]
=== rnd

A `rnd` map will randomly select one value from the specified text file.

[[dbm]]
=== dbm

[[prg]]
=== prg

[[dbd]]
=== dbd


