code: sf.d
doc:  doc/sf.pdf

sf.d: sf.nw
	notangle -L -Rsf.d sf.nw >sf.d

doc/sf.pdf: sf.nw
	noweave -delay sf.nw >doc/sf1.tex
	latexmk -outdir=doc -pdf doc/sf.tex
	latexmk -c -pdf doc/sf.tex

clean:
	rm -rf *~ *.o sf

.PHONY: clean
