#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include "term.hh"

ostream& operator<<(ostream& os, Term& t){
	return t.dump(os);
}

/** Term **/

Term::Term(Type type){
	this->type = type;
}

Term::Term(const Term& other){
	type = other.type;
}

Term& Term::operator=(const Term& other){
	if(&other != this)
		type = other.type;
	return *this;
}

/** Variable **/

Variable::Variable(char *name) : Term(variable){
	this->name = name;
}

Variable::Variable(const Variable& other) : Term(other){
	assert((name = new char[strlen(other.name)+1]()));
	strcpy(name,other.name);

}

Variable& Variable::operator=(const Variable& other){
	if(&other != this){
		Term::operator = (static_cast<const Term &>(other));
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

Term* Variable::clone(void){ 
	return new Variable(*this);
}

/** Application **/

Application::Application(Term *lterm,Term *rterm) : Term(application){
	this->lterm = lterm;
	this->rterm = rterm;
}

Application::Application(const Application& other) : Term(other){
	lterm = (&other)->lterm->clone();
	rterm = (&other)->rterm->clone();
}

Application& Application::operator=(const Application& other){
	if(&other != this){
		Term::operator = (static_cast<const Term &>(other));
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

Term* Application::clone(void){
	return new Application(*this);
}

/** Abstraction **/

Abstraction::Abstraction(Variable *var,Term *term) : Term(abstraction){
	this->var = var;
	this->term = term;
}

Abstraction::Abstraction(const Abstraction& other) : Term(other){
	var = static_cast<Variable*>((&other)->var->clone());
	term = (&other)->term->clone();
}

Abstraction& Abstraction::operator=(const Abstraction& other){
	if(&other != this){
		Term::operator = (static_cast<const Term &>(other));
		var = static_cast<Variable*>((&other)->var->clone());
		term = (&other)->term->clone();
	}
	return *this;
}

Abstraction::~Abstraction(){
	assert(var);
	delete var;
	assert(term);
	delete term;
}

void Abstraction::accept(Visitor& v){
	v.visit(*this);
}

ostream& Abstraction::dump(ostream& os){
	os << "(\\"; var->dump(os); os << "."; term->dump(os); os << ")";
	return os;
}

Term* Abstraction::clone(void){
	return new Abstraction(*this);
}
