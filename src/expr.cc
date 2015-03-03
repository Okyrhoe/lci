#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include "expr.hh"

ostream& operator<<(ostream& os, Expression& t){
	return t.dump(os);
}

/** Expression **/

Expression::Expression(Type type){
	this->type = type;
}

Expression::Expression(const Expression& other){
	type = other.type;
}

Expression& Expression::operator=(const Expression& other){
	if(&other != this)
		type = other.type;
	return *this;
}

/** Variable **/

Variable::Variable(char *name) : Expression(variable){
	this->name = name;
}

Variable::Variable(const Variable& other) : Expression(other){
	assert((name = new char[strlen(other.name)+1]()));
	strcpy(name,other.name);

}

Variable& Variable::operator=(const Variable& other){
	if(&other != this){
		Expression::operator = (static_cast<const Expression &>(other));
		assert((name = new char[strlen(other.name)+1]()));
		strcpy(name,other.name);
	}
	return *this;
}

Variable::~Variable(){
	assert(name);
	delete name;
}

void Variable::accept(Visitor& v){
	v.visit(*this);
}

ostream& Variable::dump(ostream& os){
	return os << name;
}

Expression* Variable::clone(void){ 
	return new Variable(*this);
}

/** Application **/

Application::Application(Expression *lterm,Expression *rterm) : Expression(application){
	this->lterm = lterm;
	this->rterm = rterm;
}

Application::Application(const Application& other) : Expression(other){
	lterm = (&other)->lterm->clone();
	rterm = (&other)->rterm->clone();
}

Application& Application::operator=(const Application& other){
	if(&other != this){
		Expression::operator = (static_cast<const Expression &>(other));
		lterm = (&other)->lterm->clone();
		rterm = (&other)->rterm->clone();
	}
	return *this;
}

Application::~Application(){
	assert(lterm);
	delete lterm;
	assert(rterm);
	delete rterm;
}

void Application::accept(Visitor& v){
	v.visit(*this);
}

ostream& Application::dump(ostream& os){
	os << "("; lterm->dump(os); os << " "; rterm->dump(os); os << ")";
	return os;
}

Expression* Application::clone(void){
	return new Application(*this);
}

/** Abstraction **/

Abstraction::Abstraction(Variable *var,Expression *expr) : Expression(abstraction){
	this->var = var;
	this->expr = expr;
}

Abstraction::Abstraction(const Abstraction& other) : Expression(other){
	var = static_cast<Variable*>((&other)->var->clone());
	expr = (&other)->expr->clone();
}

Abstraction& Abstraction::operator=(const Abstraction& other){
	if(&other != this){
		Expression::operator = (static_cast<const Expression &>(other));
		var = static_cast<Variable*>((&other)->var->clone());
		expr = (&other)->expr->clone();
	}
	return *this;
}

Abstraction::~Abstraction(){
	assert(var);
	delete var;
	assert(expr);
	delete expr;
}

void Abstraction::accept(Visitor& v){
	v.visit(*this);
}

ostream& Abstraction::dump(ostream& os){
	os << "(\\"; var->dump(os); os << "."; expr->dump(os); os << ")";
	return os;
}

Expression* Abstraction::clone(void){
	return new Abstraction(*this);
}
