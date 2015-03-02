# last modification: Mon Mar  2 22:50:39 EET 2015
build: src/parser.o src/lexer.o src/reduction.o src/term.o
	g++ -g3 -O2 $^ -ll -o lci

src/reduction.o: src/reduction.cc
	g++ -o $@ -c $<

src/term.o: src/term.cc
	g++ -o $@ -c $<

src/parser.o: src/parser.cc
	g++ -o $@ -c $<

src/lexer.o: src/lexer.cc
	g++ -o $@ -c $<

src/parser.cc: src/parser.y src/term.hh src/reduction.hh src/ascii_logo.hh
	bison -o $@ -d $<

src/lexer.cc: src/lexer.l src/parser.hh
	flex -o $@ $<

count:
	wc src/*.{cc,hh,y,l}

clean:
	rm -f lci src/*.o src/parser.{cc,hh} src/lexer.cc
