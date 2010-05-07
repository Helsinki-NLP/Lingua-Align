

modulehome = ../lib
modules = Lingua/Align.pm Lingua/Align/Trees.pm Lingua/Align/Corpus.pm \
	Lingua/Align/LinkSearch.pm Lingua/Align/Features.pm \
	Lingua/Align/Corpus/Parallel.pm

binhome = ../bin
scripts = treealign treealigneval convert_treebank \
		sta2moses sta2phrases coocfreq

textdoc = $(patsubst %.pm,%.txt,$(modules))
htmldoc = $(patsubst %.pm,%.html,$(modules))

textdocbin = $(patsubst %,%.txt,$(scripts))
htmldocbin = $(patsubst %,%.html,$(scripts))

# textdoc = $(shell echo "$(modules)" | sed 's|Lingua/||g' | tr '/' '-' | sed 's/.pm/.txt/g')


all: text html index.html index.txt


text: $(textdoc) $(textdocbin)
html: $(htmldoc) $(htmldocbin)


index.html: index.pod
	pod2html --htmlroot='/~'`whoami` \
		--css='/~'`whoami`/css/pod.css \
		index.pod > index.html

index.txt: index.pod
	pod2text index.pod > index.txt

$(textdoc): %.txt: $(modulehome)/%.pm
	mkdir -p `dirname $@`
	pod2text $< > $@

$(textdocbin): %.txt: $(binhome)/%
	mkdir -p `dirname $@`
	pod2text $< > $@


$(htmldoc): %.html: $(modulehome)/%.pm
	mkdir -p `dirname $@`
	pod2html --htmlroot='/~'`whoami` \
		--css='/~'`whoami`/css/pod.css \
		$(modulehome)/$< > $@

$(htmldocbin): %.html: $(binhome)/%
	mkdir -p `dirname $@`
	pod2html --htmlroot='/~'`whoami` \
		--css='/~'`whoami`/css/pod.css \
		$(modulehome)/$< > $@

