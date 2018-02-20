all: pdf html
.PHONY: all

img/%.pdf: imgsrc/%.svg
	 inkscape $< --export-pdf=$@
	

img/%.svg: imgsrc/%.svg
	mkdir -p `dirname $<`
	inkscape $< --export-text-to-path --export-plain-svg=$@

%.pdf: %.md header.tex Makefile
	pandoc -H header.tex\
		--pdf-engine=xelatex\
		--default-image-extension=pdf\
		--pdf-engine-opt '-shell-escape'\
		-V subparagraph \
		--toc \
		--number-sections\
		-V verbatim-in-note\
		-V papersize=a4\
		$< -o $@

		# --listings \
		# --highlight-style=tango\
		#--number-sections\
		# --latex-engine=xelatex\
	#--filter pandoc-minted
	# pandoc -V subparagraph $< -o $@
	# pandoc  -H header.tex -V subparagraph -V classoption=twocolumn $< -o $@

%.html: %.md
	pandoc --filter=pandoc-sidenote \
		   --toc \
		   --toc-depth=2\
		   --default-image-extension=svg\
		   -t html5 -f markdown+smart -c style.css $< -o $@

SVGPDF   := $(patsubst imgsrc/%.svg,img/%.pdf,$(wildcard imgsrc/*.svg))
PLAINSVG := $(patsubst imgsrc/%.svg,img/%.svg,$(wildcard imgsrc/*.svg))
PDF      := $(patsubst %.md,%.pdf,$(wildcard *.md))
HTML     := $(patsubst %.md,%.html,$(wildcard *.md))
SLIDES   := $(patsubst %.md,%.html,$(wildcard *.md))


pdfimgs: $(SVGPDF)
htmlimgs: $(PLAINSVG)
pdf: pdfimgs $(PDF) 
html: htmlimgs $(HTML) 
slides:  $(SLIDES)
