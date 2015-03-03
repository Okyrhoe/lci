#ifndef reduction_hh_
#define reduction_hh_

#include "expr.hh"

bool term_to_boolean(bool& value, Expression* expr);
Expression* unsigned_nat_to_term(int value, bool abstr);
bool term_to_signed_nat(int& value, Expression* expr);
bool term_to_unsigned_nat(int& value, Expression* expr);
bool reduce(Expression **expr);

#endif
