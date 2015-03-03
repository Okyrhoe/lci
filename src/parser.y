%{
	#include <sys/time.h>
	#include <iostream>
	#include <signal.h>
	#include <unistd.h>
	#include <cassert>
	#include <cstring>
	#include <cstdlib>
	#include <cstdio>
	#include <ctime>
	#include <map>
	#include <set>
	#include "term.hh"
	#include "reduction.hh"
	#include "ascii_logo.hh"

	using namespace std;
	
	extern void yyrestart(FILE*);
	extern int yylex();
	void yyerror(const char* errString){
		extern char* yytext;
		cerr << "parse error: \'" << errString \
			 << "\' at \'"  << (!strcmp(yytext,"\n") ? "\\n" : yytext)
			 << "\'" << endl;
	}
	
	static map<char*,Term*,Comparator> usr_alias_map;
	static set<char*,Comparator> sys_alias_set;

	static struct sigaction act;
	
	void sigint_handler(int signo){
		cout << "Clearing internal data structures... ";
		map<char*,Term*>::iterator it = usr_alias_map.begin();
		while(it != usr_alias_map.end()){
			delete it->first;
			delete it->second;
			++it;
		}
		usr_alias_map.clear();
		sys_alias_set.clear();
		cout << "done." << endl;
		exit(EXIT_FAILURE);
	};

	namespace opt {
		bool show_booleans = true;
		bool show_unsigned = true;
		bool show_signed = true;
		bool show_prompt = false;
		bool show_aliases = false;
		bool show_trace = true;
	}
	// unused:
	static PrintTermVisitor printTermVisitor;
	static TermClosureVisitor TermClosureVisitor;
%}
%error-verbose
%union {
	class Term* term;
	char* str;
	int val;
}
%token <str> TK_VAR
%token <val> TK_NUM
%token TK_LPAR TK_RPAR TK_DOT TK_LAMBDA TK_DEF TK_EE TK_EOL
%type <term> Term
%start goal;

/** grammar disambiguation **/
%nonassoc TK_DOT
%nonassoc TK_VAR TK_NUM TK_LAMBDA TK_LPAR TK_RPAR
%right term_assoc
%%

// gcd = (\g.\m.\n. leq m n (g n m) (g m n)) (Y (\g.\x.\y. iszero y x (g y (mod x y))))
// Reduction Strategies
// Normal Order:       Leftmost outermost redex reduced first
// Applicative Order:  Leftmost innermost redex reduced first
// Call by value:      Only outermost redex reduced                Reduction only if right-hand side has been reduced to a value (= variable or abstraction)
// Call by name:       Leftmost outermost redex reduced first      No reductions inside abstractions

goal: /* nothing */
	| goal Term TK_EOL {
		Term* term = $2;
		cout << "before: " << *term << endl;

		term->accept(TermClosureVisitor);
		if(term->unbound.empty())
			cout << "=> Compinator" << endl;
		else {
			cout << "=> Unbound variables: ";
			set<char *>::iterator it;
			for(it=term->unbound.begin(); it != term->unbound.end(); ){
				cout << *it;
				cout << (++it != term->unbound.end() ? ", " : ".\n");
			}
		}

		struct timeval ts,te;
		gettimeofday(&ts, NULL);
		while(normal_order_reduction(&term));
		gettimeofday(&te, NULL);

		int svalue;
		if(opt::show_signed && term_to_signed_nat(svalue, term))
			cout << "Signed value: " << svalue << endl;
		int uvalue;
		if(opt::show_unsigned && term_to_unsigned_nat(uvalue, term))
			cout << "Unsigned value: " << uvalue << endl;
		bool bvalue;
		if(opt::show_booleans && term_to_boolean(bvalue, term))
			cout << "Boolean value: " << (bvalue ? "true" : "false") << endl;

		cout << "Lambda expression: " << *term << endl;
		
		// term->accept(printTermVisitor);
		// cout << endl;
	
		double elapsed = (te.tv_sec-ts.tv_sec) + (te.tv_usec-ts.tv_usec)/1.0e+6;
		cout << fixed << elapsed << " sec." << endl;
		delete term;

		if(opt::show_prompt)
			cout << "?- ";
	}
	| goal TK_VAR TK_DEF Term TK_EOL {
		if (sys_alias_set.count($2)){
			cout << "System alias \"" << $2 << "\" can't be redefined." << endl;
			delete $2;
			delete $4;
		}
		else if (usr_alias_map.count($2)){
			string answer;
			do {
				cout << "Replace previous alias? [y/n]: ";
				getline(cin,answer);
			} while (answer.empty() || cin.fail() ||
					(tolower(answer[0]) != 'y' && tolower(answer[0]) != 'n'));
			if(tolower(answer[0]) != 'y'){
				delete $2;
				delete $4;
			}
			else {
				map<char*,Term*>::iterator it = usr_alias_map.find($2);
				delete it->first;
				delete it->second;
				usr_alias_map.erase(it);
				usr_alias_map.insert(pair<char*,Term*>($2,$4));
				if(opt::show_prompt)
					cout << "User alias \"" << $2 << "\" redefined." << endl;
			}
		}
		else {
			usr_alias_map.insert(pair<char*,Term*>($2,$4));
			if(opt::show_prompt)
				cout << "User alias \"" << $2 << "\" defined." << endl;
		}
		if(opt::show_prompt)
			cout << "?- ";
		else
			sys_alias_set.insert($2);
	}
	| goal TK_EE TK_EOL {
		Term *meaning_of_life = unsigned_nat_to_term(0x2a,true);
		meaning_of_life->accept(printTermVisitor);
		delete meaning_of_life;
		cout << endl;
		cout << "\e[3;49;90m" \
				"Douglas Adams, the only person who knew what this question " \
				"really was about is now dead, unfortunately." << endl;
		cout << "So now you might wonder what the meaning of death is..." \
				"\e[0m" << endl;
		if(opt::show_prompt)
			cout << "?- ";
	}
	| goal TK_EOL {
		if(opt::show_prompt)
			cout << "?- ";
	}
	;

Term:
	TK_VAR {
		if(!usr_alias_map.count($1))
			assert(($$ = new Variable($1)));
		else {
			assert(($$ = usr_alias_map[$1]->clone()));
			delete $1;
		}
	}
	| TK_NUM {
		assert(($$ = unsigned_nat_to_term($1,true)));
	}
	| Term Term %prec term_assoc {
		assert(($$ = new Application($1,$2)));
	}
	| TK_LAMBDA TK_VAR TK_DOT Term {
		assert(($$ = new Abstraction(new Variable($2),$4)));
	}
	| TK_LPAR Term TK_RPAR {
		$$ = $2;
	}
	;
%%

int main(int argc, char** argv){
	extern FILE* yyin;
	cout << asciilogo << endl;
	act.sa_handler = sigint_handler;
	sigemptyset(&act.sa_mask);
	act.sa_flags = 0;
	sigaction(SIGINT, &act, NULL);
	if(argc == 2){
		cout << "Loading aliases from \"" << argv[1] << "\"..." << endl;
		assert((yyin = fopen(argv[1], "r")));
		yyparse();
		map<char*,Term*>::iterator it = usr_alias_map.begin();
		if(opt::show_aliases){
			while(it != usr_alias_map.end()){
				printf("\e[0;34m%8s\e[0m ::= ",it->first);
				it->second->accept(::printTermVisitor);
				cout << endl;
				++it;
			}
		}
		else {
			size_t line_length = 0u;
			while(it != usr_alias_map.end()){
				cout << "\e[0;34m" << it->first << "\e[0m";
				if((line_length += strlen(it->first)+2) > 60)
					line_length = 0u;
				++it;
				cout << (line_length && it != usr_alias_map.end() ? ", " : ".\n");
			}
		}
		cout << "done." << endl;
		fclose(yyin);
		yyrestart((yyin = stdin));
	}
	opt::show_prompt = true;
	cout << "?- ";
	yyparse();
	cout << endl;
	cout << "Clearing internal data structures... ";
	map<char*,Term*>::iterator it = usr_alias_map.begin();
	while(it != usr_alias_map.end()){
		delete it->first;
		delete it->second;
		++it;
	}
	usr_alias_map.clear();
	sys_alias_set.clear();
	cout << "done." << endl;
	exit(EXIT_SUCCESS);
}
