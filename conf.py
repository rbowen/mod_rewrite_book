
# -- Path setup for local extensions -----------------------------------------

import sys, os
sys.path.insert(0, os.path.abspath('_ext'))

# -- Custom roles ------------------------------------------------------------

from docutils.parsers.rst import roles
from docutils import nodes

def module_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    """Custom role for Apache module names: :module:`mod_rewrite`"""
    node = nodes.literal(rawtext, text, classes=['module'])
    return [node], []

roles.register_local_role('module', module_role)


# mod_rewrite And Friends
# by Rich Bowen

# -- Project information -----------------------------------------------------

project = 'mod_rewrite And Friends'
copyright = '2013–2026, Rich Bowen. Licensed under the Apache License, Version 2.0'
author = 'Rich Bowen'

# The full version, including alpha/beta/rc tags
release = '3.8.0'
version = '3.8'

# -- General configuration ---------------------------------------------------

extensions = [
    'sphinx.ext.intersphinx',
    'sphinx.ext.todo',
    'version_badge',
]

# The master toctree document
master_doc = 'index'

# List of patterns to exclude from source
exclude_patterns = [
    '_build',
    'Thumbs.db',
    '.DS_Store',
    'README.md',
    'CHANGES.rst',
]

# The suffix of source filenames
source_suffix = '.rst'

# -- Options for HTML output -------------------------------------------------

html_theme = 'alabaster'

html_theme_options = {
    'description': 'A Guide to URL Manipulation and Mapping with the Apache HTTP Server',
    'github_user': 'rbowen',
    'github_repo': 'mod_rewrite_book',
    'fixed_sidebar': True,
    'sidebar_width': '260px',
}

html_static_path = ['_static']

# -- Options for LaTeX/PDF output --------------------------------------------

latex_documents = [
    (master_doc, 'mod_rewrite_and_friends.tex',
     'mod\\_rewrite And Friends',
     'Rich Bowen', 'manual'),
]

# -- KDP print-ready vs standard PDF -----------------------------------------
# Set KDP_PRINT=1 environment variable to build 6x9 trade paperback PDF.
# Default (unset) builds standard letter-size PDF for web/screen use.

_kdp_print = os.environ.get('KDP_PRINT', '') == '1'

if _kdp_print:
    latex_elements = {
        'papersize': '',  # handled by geometry package
        'pointsize': '11pt',
        'preamble': r'''
\geometry{paperwidth=6in, paperheight=9in,
          inner=0.75in, outer=0.5in,
          top=0.75in, bottom=0.75in}
\setlength{\headheight}{14pt}
\usepackage{makeidx}
\makeindex
''',
        'fncychap': r'\usepackage[Bjarne]{fncychap}',
        'extraclassoptions': 'openany',
    }
else:
    latex_elements = {
        'papersize': 'letterpaper',
        'pointsize': '11pt',
        'preamble': r'''
\setlength{\headheight}{14pt}
\usepackage{makeidx}
\makeindex
''',
    }

# -- Options for EPUB output -------------------------------------------------

epub_title = project
epub_author = author
epub_publisher = author
epub_copyright = copyright
epub_show_urls = 'footnote'
epub_use_index = True

# -- Options for todo extension ----------------------------------------------

# Set to True during development to see todo items in the rendered output
todo_include_todos = False

# -- Intersphinx configuration -----------------------------------------------

intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}

# -- Numbered figures and tables ---------------------------------------------

numfig = False
