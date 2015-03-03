%{
	#include <iostream>
	#include <cstring>
	#include <cassert>
	#include "parser.hh"
%}

%x COMMENT

%%
"set"			{ return TK_SET; }
"unset"			{ return TK_UNSET; }
"What is the meaning of life, the universe and everything?"	{ return TK_EE; }
"="				{ return TK_DEF; }
"("				{ return TK_LPAR; }
")"				{ return TK_RPAR; }
"."				{ return TK_DOT; }
\n|\r\n			{ return TK_EOL; }
[ \t]			{ /* ignore whitespaces */ }
\\				{ return TK_LAMBDA; }
[a-zA-Z][_a-zA-Z0-9]*		{
	assert((yylval.str = new char[strlen(yytext)+1]()));
	strcpy(yylval.str, yytext);
	return TK_VAR;
}
[1-9][0-9]*|0 	{
	yylval.val = atoi(yytext);
	return TK_NUM;
}
"/*"			{ BEGIN(COMMENT); }
<COMMENT>"*/"	{ BEGIN(INITIAL); }
<COMMENT>.		{ /* ignore C like comments */ }
"//"[^\r\n]*	{ /* ignore C++ like comment */ }
.				{
	std::cerr << "scanner error: unknown character: " << yytext << std::endl;
	yyterminate();
}
%%