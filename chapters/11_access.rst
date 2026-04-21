.. _Chapter_access:


===========================================
Chapter 11: Access control with mod_rewrite
===========================================

.. epigraph::

   | And when anybody spoke to him he said 'Humph!'
   | Just 'Humph!' and no more.

   -- Rudyard Kipling, *How the Camel Got His Hump*


This chapter covers using ``mod_rewrite`` to control access to
resources — blocking requests based on IP address, hostname, user
agent, referrer, time of day, or other request characteristics.

As with other chapters, we'll show both the ``mod_rewrite`` approach
and the simpler alternatives. In most access-control scenarios,
``Require``, ``SetEnvIf``, and ``<If>`` blocks are clearer and more
maintainable than rewrite rules.


Forbidding image hotlinking
---------------------------

.. todo:: The classic recipe: block requests for images when the
   ``HTTP_REFERER`` isn't your own site. Show three variants —
   return 403, serve an alternate image, redirect to a different URL.
   Then show the non-rewrite alternative using ``SetEnvIf`` and
   ``Require env``. Discuss the limitations: Referer is optional and
   trivially spoofed.


Blocking specific robots/user agents
-------------------------------------

.. todo:: Using ``RewriteCond %{HTTP_USER_AGENT}`` to block a
   specific bot. Show the ``[F]`` flag. Then show the ``SetEnvIfNoCase``
   alternative. Discuss why this is a weak defense (user agent strings
   are easily changed) and when to escalate to firewall-level blocking.
   Mention ``/robots.txt`` as the polite approach.


Denying by IP address or hostname
----------------------------------

.. todo:: Using a ``RewriteMap`` (txt file) as a deny list, checking
   ``%{REMOTE_ADDR}`` and ``%{REMOTE_HOST}`` against it. Show the map
   file format. Then show the modern alternative: ``Require not ip``
   and ``Require not host`` inside ``<RequireAll>`` blocks.


Referer-based deflection
-------------------------

.. todo:: Redirect visitors who arrive from specific referring sites
   to a different URL. Use a RewriteMap for the referer-to-target
   mapping. Discuss legitimate uses (redirecting from defunct domains)
   vs. dubious ones.


Time-based access control
-------------------------

.. todo:: Using ``RewriteCond %{TIME_HOUR}`` and related time
   variables to restrict access to certain hours. Example: maintenance
   window redirect — during certain hours, send all traffic to a
   "site is down for maintenance" page. Show the ``<If>`` alternative
   using ``%{TIME_HOUR}``.


Requiring HTTPS
---------------

.. todo:: Cross-reference the HTTP→HTTPS redirect recipe from ch14.
   Briefly show the three approaches: ``Redirect`` in a port-80
   ``<VirtualHost>``, ``mod_rewrite`` with ``%{HTTPS}`` or
   ``%{SERVER_PORT}``, and the ``<If>`` approach. Note that this is
   the single most common mod_rewrite question on the mailing list.


Environment variable gating
----------------------------

.. todo:: Using ``RewriteCond`` to check environment variables set
   by ``SetEnvIf`` or ``BrowserMatch``. This is a pattern for
   composing access decisions: one directive sets the variable,
   another acts on it. Show how ``[E=varname:value]`` in a
   RewriteRule can set variables for downstream use.


When not to use mod_rewrite for access control
-----------------------------------------------

.. todo:: Summary of the simpler alternatives: ``Require``,
   ``<RequireAll>``/``<RequireAny>``, ``SetEnvIf``, ``<If>`` with
   ``ap_expr``. Emphasize that access control expressed in rewrite
   rules is harder to audit, doesn't integrate with httpd's
   authorization framework, and doesn't appear in the places security
   reviewers expect to look.

