.. _Chapter_vhosts:


=============================
Virtual hosts and mod_rewrite
=============================

.. epigraph::

   | But the wildest of all the wild animals was the Cat.
   | He walked by himself, and all places were alike to him.

   -- Rudyard Kipling, *The Cat That Walked by Himself*


This chapter covers using ``mod_rewrite`` for dynamic virtual host
configuration — mapping incoming hostnames to document roots, CGI
directories, or entirely different server configurations on the fly.

Chapter 2 introduced ``mod_vhost_alias`` as the preferred tool for
mass virtual hosting. This chapter shows the ``mod_rewrite`` approach,
which offers more flexibility at the cost of more complexity. The
httpd documentation itself advises: ``mod_rewrite`` is usually not the
best way to configure virtual hosts — consider the alternatives first.


The problem
-----------

.. todo:: Set the scene: you have dozens/hundreds/thousands of
   hostnames all pointing to the same server. You need each hostname
   to serve content from a different directory. Writing a
   ``<VirtualHost>`` block for each one doesn't scale.


Dynamic vhosts with mod_rewrite
-------------------------------

.. todo:: The core recipe: ``RewriteMap lowercase int:tolower`` to
   normalize hostnames, then ``RewriteCond %{HTTP_HOST}`` to capture
   the hostname, then ``RewriteRule`` to map it to a filesystem path.
   Full worked example from the httpd docs. Explain the backreference
   mechanics (%1 from RewriteCond vs $1 from RewriteRule).


Using a map file for vhosts
---------------------------

.. todo:: Instead of deriving the path from the hostname with regex,
   use a ``RewriteMap`` (txt or dbm) that maps hostnames to document
   roots explicitly. More control, easier to audit. Include the
   vhost.map file format and the corresponding RewriteRule.


Handling aliases and CGI in dynamic vhosts
------------------------------------------

.. todo:: The complication: ``mod_rewrite`` runs before ``mod_alias``,
   so ``ScriptAlias`` and ``Alias`` directives get bypassed.
   Show how to explicitly exclude ``/icons/`` and ``/cgi-bin/`` paths
   from rewriting, or use the ``[H=cgi-script]`` handler flag.


Why mod_vhost_alias is usually better
-------------------------------------

.. todo:: Compare the mod_rewrite approach with mod_vhost_alias
   (introduced in ch02). mod_vhost_alias handles Alias resolution,
   CGI, and dynamic content more gracefully. mod_rewrite is needed
   only when you need conditional logic (e.g., different behavior
   for certain hostnames) or transformations that mod_vhost_alias's
   interpolation tokens can't express.


Per-user virtual hosts
----------------------

.. todo:: A common variant: ``~user`` or ``/users/username/`` mapped
   to user home directories dynamically. Cross-reference mod_userdir
   from ch02. Show the mod_rewrite version for cases where mod_userdir
   doesn't suffice (e.g., custom path layouts, conditional access).


Logging for dynamic vhosts
--------------------------

.. todo:: Using ``%{Host}i`` in the LogFormat to get per-vhost
   logging from a single log file. The ``CustomLog`` directive with
   conditional logging. Splitting logs post-hoc with ``split-logfile``.

