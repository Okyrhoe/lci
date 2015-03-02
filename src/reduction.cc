#include <iostream>
#include <cstring>
#include <cassert>
#include <cstdlib>
#include <set>

#include "reduction.hh"

using namespace std;

static inline char *cc_strdup(const char *str){
	char *aux;
	assert((aux = new char[strlen(str)+1]()));
	strcpy(aux,str);
	return aux;
}

bool term_to_boolean(bool& value, Term* term){
	Abstraction *a, *b; 
	Variable *var; 
	if((a = dynamic_cast<Abstraction *>(term)) && 
	   (b = dynamic_cast<Abstraction *>(a->term)) &&
	   (var = dynamic_cast<Variable *>(b->term))){
		if(!strcmp(a->var->name,var->name) &&
			strcmp(b->var->name,var->name))
			return (value = true);
		if(!strcmp(b->var->name,var->name) &&
			strcmp(a->var->name,var->name))
			return !(value = false);
	}
	return false;
}

Term* unsigned_nat_to_term(int value, bool abstr = true){
	return	abstr ? (Term *) new Abstraction(new Variable(cc_strdup("f")), 
							 new Abstraction(new Variable(cc_strdup("x")),
							 unsigned_nat_to_term(value, false))) :
			value ? (Term *) new Application(new Variable(cc_strdup("f")),
							 unsigned_nat_to_term(value-1, false)) :
					(Term *) new Variable(cc_strdup("x"));
}

bool term_to_signed_nat(int& value, Term* term){
	Application *a, *b;
	Abstraction *f;
	int fst, snd;
	if((f = dynamic_cast<Abstraction *>(term)) &&
	   (a = dynamic_cast<Application *>(f->term)) &&
	   (b = dynamic_cast<Application *>(a->lterm)) &&
	   term_to_unsigned_nat(fst, b->rterm) &&
	   term_to_unsigned_nat(snd, a->rterm)){
		value = fst - snd;
		return true;
	}
	return false;
}

static bool freevar(const char* name,Term* term){
	switch(term->type){
		case variable:
			return !strcmp(static_cast<Variable*>(term)->name,name) ? true : false;
		case application:
			return freevar(name,static_cast<Application*>(term)->lterm) ||
				   freevar(name,static_cast<Application*>(term)->rterm);
		case abstraction:
			return strcmp(static_cast<Abstraction*>(term)->var->name,name) &&
				   freevar(name,static_cast<Abstraction*>(term)->term);
	}
	assert(0);	//should never reach this point.
	return false;
}

bool term_to_unsigned_nat(int& value, Term* term){
	Abstraction *f, *x;
	Application *a;
	Variable *v;
	Term *t;
	if((f = dynamic_cast<Abstraction *>(term))){
		// (\x.x) := 1 (after eta-conversion)
		if((v = dynamic_cast<Variable *>(f->term)) &&
			!strcmp(f->var->name,v->name))
	   		return value = true;
		else if((x = dynamic_cast<Abstraction *>(f->term)) &&
				strcmp(f->var->name,x->var->name)){
			t = x->term; value = 0;
			cond:
			if((v = dynamic_cast<Variable *>(t)) &&
				!strcmp(v->name,x->var->name))
				return true;
			else if((a = dynamic_cast<Application *>(t)) &&
					(v = dynamic_cast<Variable *>(a->lterm)) &&
					!strcmp(v->name, f->var->name)){
				t = a->rterm;
				++value;
				goto cond;
			}
		}
	}
	return false;
}

static Variable* genetate_freevar(Term* t1, Term* t2, int length = 5){
    char *name;
    assert((name = new char[length+1]()));  //filled with zero's
    for(int i=0; i<length; ++i){
        for(int j=0; j<i+1; ++j)
            name[j] = 'a';
        int pow = 1, base = 26, exp = i+1;
        while(exp){
            if(exp & 1)     // mod 2
                pow *= base;
            exp >>= 1;      // div 2
            base *= base;
        }
        for(int k=0; k<pow; ++k){
        	if(!freevar(name,t1) && !freevar(name,t2))
        		return new Variable(name);
            for(int j=i; j>=0; --j)
                if(name[j] == 'z')
                    name[j] = 'a';
                else {
                    ++name[j];
                    break;
                }
        }
    }
    delete name;
    assert(0);  //should never reach this point.
    return NULL;
}

static bool substitute(Term** Mterm,Term *xterm,Term *Nterm){
	if(xterm->type != variable)
		return false;
	Variable *x = static_cast<Variable*>(xterm);
	if((*Mterm)->type == variable){
		Variable *y = static_cast<Variable*>(*Mterm);
		// y[x:=N] ≡ y , y≠x (do nothing)
		if(strcmp(y->name,x->name))
			;
		else {
			// x[x:=N] ≡ N , y=x
			delete *Mterm;
			*Mterm = Nterm->clone();
		}
		return true;
	}
	bool value = false;
	if((*Mterm)->type == application){
		Application *ap = static_cast<Application*>(*Mterm);
		Term** P = &ap->lterm;
		Term** Q = &ap->rterm;
		// (PQ)[x:=N] ≡ P[x:=N]Q[x:=N]
		value = substitute(P,xterm,Nterm);
		value = substitute(Q,xterm,Nterm) || value;
		return  value;
	}
	if((*Mterm)->type == abstraction){
		Abstraction *M = static_cast<Abstraction*>(*Mterm);
		Term **Pterm = &M->term;
		Variable *z, **y = &M->var;
		//( \x.P)[x:=N] ≡ \x.P (do nothing, y is already bound inside P)
		if(!strcmp(M->var->name,x->name))
			return true;
		// page 40/109, ch9.pdf
		// i.e. ((\x.(\y.(z (x y)))) (w y)) => (\a.(z ((w y) a)))
		// P = "(\y.(z (x y)))", y = "y", x = "x", N = "(w y)"
		else if(!freevar((*y)->name,Nterm) || !freevar(x->name,*Pterm)){
			// (\\y.P)[x:=N] ≡ \\y.P[x:=N] ,
			// y≠x ^ (y ∉ freevars(N) ∨ x ∉ freevars(P))
			return substitute(Pterm,xterm,Nterm);
		}
		else {
			// case: (\\y.P)[x:=N] ≡ \\z.P[y:=z][x:=N] 
			// y≠x ^ (y ∈ freevars(N) ^ x ∈ freevars(P)) ^ 
			// z ∉ freevars(N) ∪ freevars(P)" 
			z = genetate_freevar(*Pterm,Nterm); // P N
			value = substitute(Pterm,*y,z);
			delete *y;
			*y = z;
			value = substitute(Pterm,xterm,Nterm) || value;
			return value;
		}
	}
	return false;	//never reached
}

// bool __trace = true;

// bool trace(Term *term){
// 	if(__trace){
// 		cout << "trace: " << *term << endl;
// 		string answer;
// 		do {
// 			cout << "Continue (c), Step(s), Abort(a)? : ";
// 			getline(cin,answer);
// 			if(cin.eof())
// 				return false;
// 		} while (cin.fail() || answer.empty() ||
// 				(tolower(answer[0]) != 'c' && tolower(answer[0]) != 's' && tolower(answer[0]) != 'a'));
// 		switch(tolower(answer[0])){
// 			case 'a': return false;
// 			case 'c': __trace = false; break;
// 			case 's': __trace = true; break;
// 		}
// 	}
// 	return true;
// }

bool normal_order_reduction(Term **term){
	// if(!trace(*term))
	// 	return false;
	bool value;
	if((*term)->type == variable)
		return false;
	if((*term)->type == application){
		Application *ap = static_cast<Application*>(*term);
		// no b-redex on the left
		// try to reduce left term and on failure the right one
		if(ap->lterm->type != abstraction)
			return (value = normal_order_reduction(&ap->lterm)) ?
					value : normal_order_reduction(&ap->rterm);
		//case: ((\x.M) N)
    	Abstraction *ab = static_cast<Abstraction*>(ap->lterm);
		Variable *x = ab->var;
    	Term **M = &ab->term;
    	Term *N = ap->rterm;
		substitute(M,x,N);
		Term *aux = *term;
		*term = (*M)->clone();
		delete aux;
		return true;
	}
	if((*term)->type == abstraction){
		Abstraction *ab = static_cast<Abstraction*>(*term);
		Term **Mterm = &ab->term;
		if((*Mterm)->type == application){
			Variable *x = ab->var;
			Application *ap = static_cast<Application*>(*Mterm);
			//try to apply an eta-conversion \x.(M y) , y=x
			if(ap->rterm->type == variable){
				Variable *y = static_cast<Variable*>(ap->rterm);
				Term *M = ap->lterm;
				if(!strcmp(x->name,y->name) && !freevar(x->name,M)){
					//eta-conversion (\x.(M x)) => M, x ∉ freevars(M)
					// cout << "case: (\\x.(M x)) => M, x ∉ freevars(M)" << endl;
					Term *aux = *term;
					*term = M->clone();
					delete aux;
					return true;
				}
			}
		}
		//try to reduce a term inside M
		return normal_order_reduction(Mterm);
	}
	return false;
}

// unused:

bool term_is_combinator(Term* term,set<char*, Comparator> bound_variables){
	if(term->type == variable)
		return bound_variables.count(static_cast<Variable*>(term)->name) ? true : false;
	else if(term->type == application){
		set<char*,Comparator> left(bound_variables);
		set<char*,Comparator> right(bound_variables);
		Application* app = static_cast<Application*>(term);
		return (term_is_combinator(app->lterm,left) && term_is_combinator(app->rterm,right));
	}
	else if(term->type == abstraction){
		Abstraction* ab = static_cast<Abstraction*>(term);
		bound_variables.insert(ab->var->name);
		return term_is_combinator(ab->term,bound_variables);
	}
	assert(0);
	return false;
}

// take a Term and decide if it is a term_is_combinator
bool term_is_combinator(Term* term){
	set<char*,Comparator> bound_variables;
	bool result = term_is_combinator(term,bound_variables);
	bound_variables.clear();
	return result;
}
