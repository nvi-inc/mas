all: pdf html docx
.PHONY: all

%.docx: %.md
	pandoc -S -o $@ $<
	
# %.pdf: %.md
# 	pandoc \
# 		--toc \
# 		--number-sections \
# 		-t context\
# 		$< -o $@
 		
%.tex: %.md header.tex
	pandoc -H header.tex\
		--listings \
		-V fontsize=12pt\
		-V subparagraph \
		-V verbatim-in-note\
		$< -o $@

%.pdf: %.md header.tex Makefile
	pandoc -H header.tex\
		--latex-engine=lualatex\
		--latex-engine-opt '-shell-escape'\
		-V fontsize=12pt\
		-V subparagraph \
		-V verbatim-in-note\
		-V papersize=a4\
		--highlight-style=kate\
		$< -o $@

		# --listings \
		#--number-sections\
		# --latex-engine=xelatex\
		#--toc \
	#--filter pandoc-minted
	# pandoc -V subparagraph $< -o $@
	# pandoc  -H header.tex -V subparagraph -V classoption=twocolumn $< -o $@

%.html: %.md
	pandoc --toc --highlight-style monochrome -t html5 -S -c style.css $< -o $@
	
%.html: %.md style.css
	pandoc --self-contained -S -c style.css --mathjax -t slidy -o $@ $<

DOCX := $(patsubst %.md,%.docx,$(wildcard *.md))
PDF := $(patsubst %.md,%.pdf,$(wildcard *.md))
HTML := $(patsubst %.md,%.html,$(wildcard *.md))
SLIDES := $(patsubst %.md,%.html,$(wildcard *.md))



pdf: $(PDF)
html: $(HTML)
docx: $(DOCX)
slides:  $(SLIDES)
