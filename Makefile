all: pdf html
.PHONY: all

figures/%.pdf: figures/%.svg
	 inkscape $< --export-pdf=$@
	

out/html/figures/%.svg: figures/%.svg
	mkdir -p `dirname $<`
	inkscape $< --export-text-to-path --export-plain-svg=$@

%.pdf: %.md header.tex Makefile
	pandoc -H header.tex\
		--latex-engine=lualatex\
		--default-image-extension=pdf\
		--latex-engine-opt '-shell-escape'\
		-V subparagraph \
		-V verbatim-in-note\
		-V papersize=a4\
		--highlight-style=tango\
		$< -o $@

		# --listings \
		#--number-sections\
		# --latex-engine=xelatex\
		#--toc \
	#--filter pandoc-minted
	# pandoc -V subparagraph $< -o $@
	# pandoc  -H header.tex -V subparagraph -V classoption=twocolumn $< -o $@

out/html/%.html: %.md
	mkdir -p out/html
	pandoc --default-image-extension=svg --highlight-style=kate -t html5 -S -c style.css $< -o $@

out/html/%.css: %.css
	cp $< $@

SVGPDF := $(patsubst figures/%.svg,figures/%.pdf,$(wildcard figures/*.svg))
PLAINSVG := $(patsubst figures/%.svg,out/html/figures/%.svg,$(wildcard figures/*.svg))
PDF := $(patsubst %.md,%.pdf,$(wildcard *.md))
HTML := $(patsubst %.md,out/html/%.html,$(wildcard *.md))
SLIDES := $(patsubst %.md,%.html,$(wildcard *.md))


pdfimgs: $(SVGPDF)
htmlimgs: $(PLAINSVG)
css: out/html/style.css
pdf: pdfimgs $(PDF) 
html: htmlimgs css $(HTML) 
slides:  $(SLIDES)
