# last modification: Mon Mar  2 22:50:39 EET 2015
all: src/parser.o src/lexer.o src/reduction.o src/expr.o
	g++ -g3 -O2 $^ -ll -o lci

src/reduction.o: src/reduction.cc src/opt.hh
	g++ -o $@ -c $<

src/expr.o: src/expr.cc
	g++ -o $@ -c $<

src/parser.o: src/parser.cc
	g++ -o $@ -c $<

src/lexer.o: src/lexer.cc
	g++ -o $@ -c $<

src/parser.cc: src/parser.y src/expr.hh src/reduction.hh src/ascii_logo.hh src/opt.hh
	bison -o $@ -d $<

src/lexer.cc: src/lexer.l src/parser.hh
	flex -o $@ $<

count:
	wc src/*.{cc,hh,y,l}

clean:
	rm -f lci src/*.o src/parser.{cc,hh} src/lexer.cc
