.. _Chapter_access:


===============================
Access control with mod_rewrite
===============================

.. epigraph::

   | And when anybody spoke to him he said 'Humph!'
   | Just 'Humph!' and no more.

   -- Rudyard Kipling, *How the Camel Got His Hump*


This chapter covers using :module:`mod_rewrite` to control access to
resources — blocking requests based on IP address, hostname, user
agent, referrer, time of day, or other request characteristics.

As with other chapters, we'll show both the :module:`mod_rewrite` approach
and the simpler alternatives. In most access-control scenarios,
``Require``, ``SetEnvIf``, and ``<If>`` blocks are clearer and more
maintainable than rewrite rules.


.. index:: hotlinking
.. index:: pair: access control; image hotlinking
.. index:: pair: RewriteCond; HTTP_REFERER

Forbidding image hotlinking
---------------------------

One of the oldest :module:`mod_rewrite` recipes on the internet:
blocking requests for your images when the ``Referer`` header indicates
they're being embedded on someone else's site. The idea is that if
another site links directly to your images, their visitors consume your
bandwidth while you get none of the traffic.

Here's the basic approach — return a 403 Forbidden for any image
request whose ``Referer`` doesn't match your own domain:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_REFERER} !^$
   RewriteCond %{HTTP_REFERER} !^https?://(www\.)?example\.com [NC]
   RewriteRule \.(png|jpg|gif|svg)$ - [F]

The first ``RewriteCond`` allows requests with an *empty* referer
through — this covers direct visits, bookmarks, and privacy-conscious
browsers that strip the header. The second condition blocks requests
where the referer is *present* but doesn't match your domain. The
``[NC]`` flag makes the match case-insensitive.

**Variant: serve an alternate image** instead of a 403 — the classic
"stop stealing my bandwidth" placeholder:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_REFERER} !^$
   RewriteCond %{HTTP_REFERER} !^https?://(www\.)?example\.com [NC]
   RewriteRule \.(png|jpg|gif|svg)$ /images/hotlink-denied.png [L]

**Variant: redirect to the referring page's homepage:**

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_REFERER} !^$
   RewriteCond %{HTTP_REFERER} !^https?://(www\.)?example\.com [NC]
   RewriteRule \.(png|jpg|gif|svg)$ %{HTTP_REFERER} [R=302,L]


The non-rewrite alternative
~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can do this without :module:`mod_rewrite` using ``SetEnvIf`` and
``Require``:

.. code-block:: apache

   SetEnvIf Referer "^https?://(www\.)?example\.com" local_referer
   SetEnvIf Referer "^$" local_referer

   <FilesMatch "\.(png|jpg|gif|svg)$">
       Require env local_referer
   </FilesMatch>

This is arguably clearer: the access decision is expressed as an
authorization rule, not as a rewrite trick.

**Limitations:** The ``Referer`` header is optional — many clients
don't send it, and some privacy tools strip it. It's also trivially
spoofed by anyone determined to hotlink your images. This technique
stops casual embedding but won't deter a motivated actor.


.. index:: pair: access control; user agent blocking
.. index:: pair: RewriteCond; HTTP_USER_AGENT
.. index:: robots.txt

Blocking specific robots/user agents
-------------------------------------

To block a specific bot by user agent string, test
``%{HTTP_USER_AGENT}`` and return a 403 with the ``[F]`` flag:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_USER_AGENT} BadBot [NC]
   RewriteRule ^ - [F]

To block multiple bots, chain them with ``[OR]``:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTP_USER_AGENT} BadBot     [NC,OR]
   RewriteCond %{HTTP_USER_AGENT} EvilScraper [NC]
   RewriteRule ^ - [F]


The non-rewrite alternative
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: apache

   SetEnvIfNoCase User-Agent "BadBot" bad_bot
   SetEnvIfNoCase User-Agent "EvilScraper" bad_bot

   <RequireAll>
       Require all granted
       Require not env bad_bot
   </RequireAll>

**Why this is a weak defense:** User agent strings are entirely
client-controlled. Any bot that notices it's being blocked can simply
change its user agent string to impersonate a legitimate browser. This
technique is useful for blocking well-behaved bots that respect their
own identity (and for blocking the occasional lazy scraper), but it's
not a security measure.

For well-behaved bots, :file:`/robots.txt` is the polite approach —
it tells crawlers which paths to avoid without any server-side
enforcement. For genuinely abusive traffic, escalate to firewall-level
blocking (iptables, AWS WAF, fail2ban, or similar) where the decision
is based on IP address and request patterns rather than a self-reported
identity.


.. index:: pair: access control; IP address blocking
.. index:: pair: RewriteMap; deny list
.. index:: Require not ip

Denying by IP address or hostname
----------------------------------

For a small number of addresses, inline ``RewriteCond`` tests work:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{REMOTE_ADDR} ^192\.168\.1\.100$
   RewriteRule ^ - [F]

But for a larger deny list, a ``RewriteMap`` is more maintainable.
Create a text file listing the blocked addresses:

.. code-block:: none

   # /etc/httpd/conf/denylist.txt
   192.168.1.100  denied
   10.0.0.50      denied
   203.0.113.42   denied

Then use it in a ``RewriteCond``:

.. code-block:: apache

   RewriteMap denylist txt:/etc/httpd/conf/denylist.txt
   RewriteCond ${denylist:%{REMOTE_ADDR}|OK} =denied
   RewriteRule ^ - [F]

If the client's IP is found in the map, the lookup returns ``denied``
and the condition matches. If it's not found, the default value ``OK``
is returned and the request proceeds normally.

You can also check ``%{REMOTE_HOST}`` (the resolved hostname) in the
same way, though this requires ``HostnameLookups On``, which adds a DNS
lookup to every request — a significant performance cost.


The modern alternative
~~~~~~~~~~~~~~~~~~~~~~

Since httpd 2.4, the ``Require`` directive handles this natively and
integrates with the authorization framework:

.. code-block:: apache

   <RequireAll>
       Require all granted
       Require not ip 192.168.1.100 10.0.0.50 203.0.113.42
   </RequireAll>

Or by hostname:

.. code-block:: apache

   <RequireAll>
       Require all granted
       Require not host evil.example.com
   </RequireAll>

This is shorter, clearer, and shows up where security reviewers expect
to find access control rules. Use it.


.. index:: pair: access control; referer-based redirect
.. index:: pair: RewriteMap; referer mapping

Referer-based deflection
-------------------------

Sometimes you want to redirect visitors who arrive from specific
referring sites to a different URL — perhaps you've moved content and
the old site still links to the wrong location, or you want to provide
a landing page tailored to visitors from a particular source.

A ``RewriteMap`` keeps this clean when you have multiple referrers to
handle:

.. code-block:: none

   # /etc/httpd/conf/referer-redirects.txt
   old-partner.example.com    /welcome/partner
   defunct-blog.example.net   /welcome/blog-readers

.. code-block:: apache

   RewriteMap refmap txt:/etc/httpd/conf/referer-redirects.txt
   RewriteCond %{HTTP_REFERER} ^https?://([^/]+)
   RewriteCond ${refmap:%1|NONE} !=NONE
   RewriteRule ^ ${refmap:%1} [R=302,L]

The first ``RewriteCond`` extracts the hostname from the referer into
``%1``. The second looks it up in the map — if there's no match, the
default ``NONE`` is returned and the rule is skipped.

This is a legitimate technique for managing inbound traffic from
specific sources. Less legitimate uses — redirecting competitors'
referral traffic, serving different content to visitors from review
sites — tend to create a maintenance headache and erode trust.
Use good judgment.


.. index:: pair: access control; time-based
.. index:: pair: RewriteCond; TIME_HOUR

Time-based access control
--------------------------

:module:`mod_rewrite` exposes time variables — ``%{TIME_HOUR}``,
``%{TIME_MIN}``, ``%{TIME_WDAY}``, and others — that you can use in
conditions. The most common use case is a maintenance window redirect:

.. code-block:: apache

   # Redirect all traffic to a maintenance page between 2:00 and 4:00 AM
   RewriteEngine On
   RewriteCond %{TIME_HOUR} ^0[2-3]$
   RewriteCond %{REQUEST_URI} !^/maintenance\.html$
   RewriteRule ^ /maintenance.html [R=302,L]

The second condition prevents a redirect loop — without it, the
request for :file:`/maintenance.html` itself would also be redirected.

You can combine time conditions for more specific windows:

.. code-block:: apache

   # Saturday (6) and Sunday (0) only
   RewriteCond %{TIME_WDAY} ^[06]$
   RewriteRule ^/office-hours - [F]


The <If> alternative
~~~~~~~~~~~~~~~~~~~~

Since httpd 2.4, the ``<If>`` directive with ``ap_expr`` is a much
cleaner way to express time-based logic:

.. code-block:: apache

   <If "%{TIME_HOUR} -ge 2 && %{TIME_HOUR} -lt 4">
       RedirectMatch 302 !^/maintenance\.html$ /maintenance.html
   </If>

This reads like what it is: a conditional block that applies during
certain hours. No rewrite engine, no pattern matching — just a
condition and an action.


.. index:: pair: access control; HTTPS redirect
.. index:: pair: RewriteCond; HTTPS

Requiring HTTPS
----------------

This is the single most common :module:`mod_rewrite` question on the
mailing list — and the one where the alternatives are most compelling.

**Approach 1: Redirect in a port-80 VirtualHost** — the simplest
and best option if you have access to the server config:

.. code-block:: apache

   <VirtualHost *:80>
       ServerName www.example.com
       Redirect permanent "/" "https://www.example.com/"
   </VirtualHost>

No rewrite engine, no conditions, no regex. Just a permanent redirect
from HTTP to HTTPS. This is what you should use.

**Approach 2: mod_rewrite** — when you're in :file:`.htaccess` and
can't define virtual hosts:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{HTTPS} off
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

**Approach 3: <If> with ap_expr:**

.. code-block:: apache

   <If "! %{HTTPS} == 'on'">
       Redirect permanent "/" "https://www.example.com/"
   </If>

All three accomplish the same thing. Approach 1 is preferred because
it's the most explicit and doesn't involve pattern matching. Approach 2
is what you'll use in :file:`.htaccess`. Approach 3 is a good
middle ground when you have server config access but want it expressed
as a condition.

See also the HTTP→HTTPS recipe in :ref:`Chapter_recipes`.


.. index:: pair: access control; environment variables
.. index:: pair: RewriteCond; environment variables
.. index:: pair: flags; E (environment variable)

Environment variable gating
----------------------------

A powerful pattern in httpd configuration is to *separate the decision
from the action*: one directive sets an environment variable based on
some condition, and a later directive acts on that variable.

``SetEnvIf`` and ``BrowserMatch`` are the typical variable-setters:

.. code-block:: apache

   SetEnvIf Remote_Addr "^10\." internal_network
   BrowserMatch "MSIE" legacy_browser

You can then test these variables in a ``RewriteCond``:

.. code-block:: apache

   RewriteEngine On
   RewriteCond %{ENV:internal_network} ^$
   RewriteRule ^/admin - [F]

This blocks access to ``/admin`` for anyone *not* on the internal
network (where the variable would be empty). The logic lives in two
places — the variable assignment and the rewrite condition — but it's
compositional: you can reuse the same variable in multiple rules.

The ``[E=varname:value]`` flag on a ``RewriteRule`` works in the other
direction — the rewrite rule sets a variable for downstream use:

.. code-block:: apache

   RewriteRule ^/api/ - [E=api_request:1]

Other directives — ``Header``, ``CustomLog``, ``<If>`` — can then
check ``%{ENV:api_request}`` to alter their behavior for API requests.
This is a useful technique for making :module:`mod_rewrite` cooperate
with the rest of your configuration rather than trying to do
everything itself.


.. index:: pair: access control; when not to use mod_rewrite

When not to use mod_rewrite for access control
-----------------------------------------------

Throughout this chapter, every recipe has come with a non-rewrite
alternative — and in most cases, the alternative is better. Here's
why.

:module:`mod_rewrite` access control works, but it has real drawbacks:

- **It's invisible to the authorization framework.** httpd has a
  well-defined authorization phase (``Require``, ``<RequireAll>``,
  ``<RequireAny>``). Rewrite rules run *before* that phase. Access
  restrictions expressed as rewrite rules don't show up in the places
  where security reviewers expect to find them, and they don't compose
  with other authorization rules.

- **It's harder to audit.** A ``Require not ip 10.0.0.1`` is
  self-documenting. A ``RewriteCond %{REMOTE_ADDR}`` followed by a
  ``RewriteRule ^ - [F]`` achieves the same thing in more lines with
  more room for subtle bugs.

- **It doesn't integrate with logging.** When ``Require`` denies a
  request, the reason is logged through the authorization framework.
  When a ``RewriteRule`` returns ``[F]``, the log just shows a 403
  with no explanation of *which* rule denied it — you'll need to
  enable ``RewriteLog`` to trace it.

The httpd 2.4 alternatives cover nearly everything:

``Require ip``, ``Require not ip``, ``Require host``
   IP and hostname-based access control, with full CIDR support.

``<RequireAll>``, ``<RequireAny>``, ``<RequireNone>``
   Boolean composition of multiple access rules.

``SetEnvIf`` + ``Require env``
   Header-based decisions (user agent, referer, custom headers).

``<If>`` with ``ap_expr``
   Arbitrary conditions: time of day, SSL variables, request
   characteristics, even complex boolean expressions.

Use :module:`mod_rewrite` for access control only when you genuinely
need something the authorization framework can't express — which, in
httpd 2.4 and later, is rare.
