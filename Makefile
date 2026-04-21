BOOK = book
SRCS = $(BOOK).adoc $(wildcard chapters/*.adoc)

all: html pdf

html: $(BOOK).html

pdf: $(BOOK).pdf

$(BOOK).html: $(SRCS)
	bundle exec asciidoctor -o $@ $(BOOK).adoc

$(BOOK).pdf: $(SRCS)
	bundle exec asciidoctor-pdf -o $@ $(BOOK).adoc

setup:
	bundle install

clean:
	rm -f $(BOOK).html $(BOOK).pdf

.PHONY: all html pdf setup clean
