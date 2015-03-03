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
	#include "expr.hh"
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
	
	static map<char*,Expression*,Comparator> usr_alias_map;
	static set<char*,Comparator> sys_alias_set;

	static struct sigaction act;
	
	void sigint_handler(int signo){
		cout << "Clearing internal data structures... ";
		map<char*,Expression*>::iterator it = usr_alias_map.begin();
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

	#include "opt.hh"
	namespace option {
		bool disp_bool		= true;
		bool disp_unsigned	= true;
		bool disp_signed	= true;
		bool disp_prompt	= false;
		bool disp_alias_def	= false;
		bool trace			= false;
		bool strict			= false;	//applicative order (call-by-value)
	}

	static bool set_option(const char *option, bool value){
		if(strcmp(option,"disp_bool") &&
		   strcmp(option,"disp_unsigned") &&
		   strcmp(option,"disp_signed") &&
		   strcmp(option,"trace") && 
		   strcmp(option,"strict")){
			cout << "error: invalid option \'\e[2;49;94m"
				 << option << "\e[0m\'" << endl;
			cout << "system options: disp_bool, disp_unsigned," \
					" disp_signed, trace, strict." << endl;
			return false;
		}
		else if(!strcmp(option,"disp_bool"))
			option::disp_bool = value;
		else if(!strcmp(option,"disp_unsigned"))
			option::disp_unsigned = value;
		else if(!strcmp(option,"disp_signed"))
			option::disp_signed = value;
		else if(!strcmp(option,"trace"))
			option::trace = value;
		else if(!strcmp(option,"strict"))
			option::strict = value;
		cout << "option \'\e[2;49;94m" << option
			 << "\e[0m\' is set to \'\e[2;49;9" 
			 << (value ? "2mtrue":"1mfalse") << "\e[0m\'" << endl;
		return true;
	}

	// unused:
	static PrintTermVisitor printTermVisitor;
	static TermClosureVisitor TermClosureVisitor;
%}
%error-verbose
%union {
	class Expression* expr;
	char* str;
	int val;
}
%token <str> TK_VAR
%token <val> TK_NUM
%token TK_SET TK_UNSET TK_LPAR TK_RPAR TK_DOT TK_LAMBDA TK_DEF TK_EE TK_EOL
%type <expr> Expression
%start goal;

/** grammar disambiguation **/
%nonassoc TK_DOT
%nonassoc TK_SET TK_UNSET TK_LAMBDA TK_LPAR TK_RPAR
%nonassoc TK_VAR TK_NUM
%right term_assoc
%%

// gcd = (\g.\m.\n. leq m n (g n m) (g m n)) (Y (\g.\x.\y. iszero y x (g y (mod x y))))
// (\y.mult 4 y)((\z.plus (mult 2 z) (exp z 2)) 5) = 140

goal: /* nothing */
	| goal Expression TK_EOL {
		Expression* expr = $2;

		expr->accept(TermClosureVisitor);
		if(expr->unbound.empty())
			cout << "Compinator" << endl;
		else {
			cout << "Unbound variables: ";
			set<char *>::iterator it;
			for(it=expr->unbound.begin(); it != expr->unbound.end(); ){
				cout << *it;
				cout << (++it != expr->unbound.end() ? ", " : ".\n");
			}
		}
		
		struct timeval ts,te;
		bool repeat = true;
		int reductions = 0;
		gettimeofday(&ts, NULL);
		do {
			if(option::trace){
				cout << "\e[2;49;96mtrace\e[0m: " << *expr << endl;
				string answer;
				char option;
				do {
					cout << "continue (c), step(s), abort(a)?\e[0m ";
					getline(cin,answer);
					option = tolower(answer[0]);
					if(cin.eof()){
						option::trace = repeat = false;
						break;
					}
				} while (cin.fail() || answer.empty() ||
						(option != 'c' && option != 's' && option != 'a'));
				switch(option){
					case 'a': repeat = false; break;
					case 'c': option::trace = false; break;
				}
			}

		} while(repeat && reduce(&expr) && ++reductions);
		gettimeofday(&te, NULL);

		double elapsed = (te.tv_sec-ts.tv_sec) + (te.tv_usec-ts.tv_usec)/1.0e+6;
		cout << "Performed " << reductions << " reductions in " << fixed << elapsed << " sec." << endl;
		int svalue;
		if(option::disp_signed && term_to_signed_nat(svalue, expr))
			cout << "Signed value: " << svalue << endl;
		int uvalue;
		if(option::disp_unsigned && term_to_unsigned_nat(uvalue, expr))
			cout << "Unsigned value: " << uvalue << endl;
		bool bvalue;
		if(option::disp_bool && term_to_boolean(bvalue, expr))
			cout << "Boolean value: " << (bvalue ? "true" : "false") << endl;
		cout << "Lambda expression: " << *expr << endl;
		
		// expr->accept(printTermVisitor);
		// cout << endl;
		delete expr;

		if(option::disp_prompt)
			cout << "?- ";
	}
	| goal TK_VAR TK_DEF Expression TK_EOL {
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
				map<char*,Expression*>::iterator it = usr_alias_map.find($2);
				delete it->first;
				delete it->second;
				usr_alias_map.erase(it);
				usr_alias_map.insert(pair<char*,Expression*>($2,$4));
				if(option::disp_prompt)
					cout << "User alias \"" << $2 << "\" redefined." << endl;
			}
		}
		else {
			usr_alias_map.insert(pair<char*,Expression*>($2,$4));
			if(option::disp_prompt)
				cout << "User alias \"" << $2 << "\" defined." << endl;
		}
		if(option::disp_prompt)
			cout << "?- ";
		else
			sys_alias_set.insert($2);
	}
	| goal TK_SET TK_VAR TK_EOL {
		set_option($3,true);
		delete $3;
		if(option::disp_prompt)
			cout << "?- ";
	}
	| goal TK_UNSET TK_VAR TK_EOL {
		set_option($3,false);
		delete $3;
		if(option::disp_prompt)
			cout << "?- ";
	}
	| goal TK_EE TK_EOL {
		Expression *meaning_of_life = unsigned_nat_to_term(0x2a,true);
		meaning_of_life->accept(printTermVisitor);
		delete meaning_of_life;
		cout << endl;
		cout << "\e[2;49;37m" \
				"Douglas Adams, the only person who knew what this question " \
				"really was about is now dead, unfortunately." << endl;
		cout << "So now you might wonder what the meaning of death is..." \
				"\e[0m" << endl;
		if(option::disp_prompt)
			cout << "?- ";
	}
	| goal TK_EOL {
		if(option::disp_prompt)
			cout << "?- ";
	}
	;

Expression:
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
	| Expression Expression %prec term_assoc {
		assert(($$ = new Application($1,$2)));
	}
	| TK_LAMBDA TK_VAR TK_DOT Expression {
		assert(($$ = new Abstraction(new Variable($2),$4)));
	}
	| TK_LPAR Expression TK_RPAR {
		$$ = $2;
	}
	;
%%

int main(int argc, char** argv){
	extern FILE* yyin;
	for(int i=0; i<asciilogo.length(); ++i)
		cout << "\e[2;49;9" << (asciilogo.at(i)-'x' ? 4:7) << "m" << asciilogo.at(i) << "\e[0m";
	cout << "\e[2;49;97m" << greet << "\e[0m" << endl;
	act.sa_handler = sigint_handler;
	sigemptyset(&act.sa_mask);
	act.sa_flags = 0;
	sigaction(SIGINT, &act, NULL);
	if(argc == 2){
		cout << "Loading aliases from \"" << argv[1] << "\"..." << endl;
		assert((yyin = fopen(argv[1], "r")));
		yyparse();
		map<char*,Expression*>::iterator it = usr_alias_map.begin();
		if(option::disp_alias_def){
			while(it != usr_alias_map.end()){
				printf("\e[2;49;94m%8s\e[0m ::= ",it->first);
				it->second->accept(::printTermVisitor);
				cout << endl;
				++it;
			}
		}
		else {
			size_t line_length = 0u;
			while(it != usr_alias_map.end()){
				cout << "\e[2;49;94m" << it->first << "\e[0m";
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
	option::disp_prompt = true;
	cout << "?- ";
	yyparse();
	cout << endl;
	cout << "Clearing internal data structures... ";
	map<char*,Expression*>::iterator it = usr_alias_map.begin();
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
