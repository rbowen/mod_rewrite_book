"""
Sphinx extension providing inline version badges.

Usage in rST::

    This feature is available in httpd :version:`2.4.19`.
    The ``[BCTLS]`` flag :version:`trunk` is only in trunk.

Renders as a styled <span> with distinct shapes for different version
ranges, suitable for HTML, ePub (grayscale), and print (B&W):

- 2.4.x: rounded pill (circle ends)
- trunk: dashed border (indicates unreleased)
- 2.2/legacy: square corners
"""
from docutils import nodes
from sphinx.util.docutils import SphinxRole


class VersionBadgeRole(SphinxRole):
    """Inline role that renders a version number as a styled badge."""

    def run(self):
        version = self.text.strip()

        # Choose a CSS class based on version
        if version.lower() in ('trunk', '2.5', '2.5.0', '2.5.1'):
            css_class = 'version-badge version-trunk'
        elif version.startswith('2.4'):
            css_class = 'version-badge version-24'
        elif version.startswith('2.2') or version.startswith('2.0'):
            css_class = 'version-badge version-legacy'
        else:
            css_class = 'version-badge'

        node = nodes.inline(self.rawtext, version, classes=css_class.split())
        return [node], []


def setup(app):
    app.add_role('version', VersionBadgeRole())
    app.add_css_file('version_badges.css')

    return {
        'version': '1.0',
        'parallel_read_safe': True,
        'parallel_write_safe': True,
    }
