# Configuration file for the Sphinx documentation builder.
#
# mod_rewrite And Friends
# by Rich Bowen

# -- Project information -----------------------------------------------------

project = 'mod_rewrite And Friends'
copyright = '2013–2025, Rich Bowen'
author = 'Rich Bowen'

# The full version, including alpha/beta/rc tags
release = '3.0'
version = '3.0'

# -- General configuration ---------------------------------------------------

extensions = [
    'sphinx.ext.intersphinx',
    'sphinx.ext.todo',
]

# The master toctree document
master_doc = 'index'

# List of patterns to exclude from source
exclude_patterns = [
    '_build',
    'Thumbs.db',
    '.DS_Store',
    'README.md',
]

# The suffix of source filenames
source_suffix = '.rst'

# -- Options for HTML output -------------------------------------------------

html_theme = 'alabaster'

html_theme_options = {
    'description': 'A guide to Apache mod_rewrite and related modules',
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

latex_elements = {
    'papersize': 'letterpaper',
    'pointsize': '11pt',
    'preamble': r'''
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

todo_include_todos = True

# -- Intersphinx configuration -----------------------------------------------

intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}

# -- Numbered figures and tables ---------------------------------------------

numfig = False
