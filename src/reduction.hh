#ifndef reduction_hh_
#define reduction_hh_

#include "term.hh"

bool term_to_boolean(bool& value, Term* term);
Term* unsigned_nat_to_term(int value, bool abstr);
bool term_to_signed_nat(int& value, Term* term);
bool term_to_unsigned_nat(int& value, Term* term);
bool normal_order_reduction(Term **term);

#endif