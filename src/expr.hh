#ifndef term_hh_
#define term_hh_

#include <set>

using namespace std;

typedef enum {
	variable, application, abstraction
} Type;


class Comparator {
public:
	bool operator()(const char* a, const char* b) const {
		return strcmp(a,b) < 0;
	}
};

/** abstract syntax tree **/

// forward declaration
class Visitor;

class Expression {
public:
	set<char *,Comparator> unbound;
	Type type;
	Expression(Type);
	Expression(const Expression&);
	virtual ~Expression(){}
	Expression& operator=(const Expression&);
	virtual void accept(Visitor&) = 0;
	virtual Expression* clone(void) = 0;
	virtual ostream& dump(ostream& os) = 0;
};

ostream& operator<<(ostream& os, Expression& t);

class Variable : public Expression {
public:
	char *name;
	Variable(char*);
	Variable(const Variable&);
	~Variable();
	Variable& operator=(const Variable&);
	void accept(Visitor&);
	Expression* clone(void);
	virtual ostream& dump(ostream& os);
};

class Application : public Expression {
public:
	Expression* lterm;
	Expression* rterm;
	Application(Expression*,Expression*);
	Application(const Application&);
	~Application();
	Application& operator=(const Application&);
	void accept(Visitor&);
	Expression* clone(void);
	virtual ostream& dump(ostream& os);
};

class Abstraction : public Expression {
public:
	Expression* expr;
	Variable* var;
	Abstraction(Variable*,Expression*);
	Abstraction(const Abstraction&);
	~Abstraction();
	Abstraction& operator=(const Abstraction&);
	void accept(Visitor&);
	Expression* clone(void);
	virtual ostream& dump(ostream& os);
};

/** visitors **/

class Visitor {
public:
	virtual void visit(Variable& t) = 0;
	virtual void visit(Application& t) = 0;
	virtual void visit(Abstraction& t) = 0;
};

// unused:

class PrintTermVisitor : public Visitor {
	void visit(Variable& t){
		cout << t.name;
	}
	void visit(Application& t){
		cout << "(";
		(&t)->lterm->accept(*this);
		cout << " ";
		(&t)->rterm->accept(*this);
		cout << ")";
	}
	void visit(Abstraction& t){
		cout << "(\\" << t.var->name << ".";
		(&t)->expr->accept(*this);
		cout << ")";
	}
};

class TermClosureVisitor : public Visitor {
	void visit(Variable& v){ 
		v.unbound.insert(v.name);
	}
	void visit(Application& t){
		(&t)->lterm->accept(*this);
		t.unbound.insert(t.lterm->unbound.begin(), t.lterm->unbound.end());
		(&t)->rterm->accept(*this);
		t.unbound.insert(t.rterm->unbound.begin(), t.rterm->unbound.end());
	}
	void visit(Abstraction& t){ 
		(&t)->expr->accept(*this);
		t.unbound.insert(t.expr->unbound.begin(), t.expr->unbound.end());
		t.unbound.erase(t.var->name);
	}
};

#endif