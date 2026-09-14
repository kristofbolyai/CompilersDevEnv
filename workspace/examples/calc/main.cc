#include <iostream>

#include "parser.h"

// A four-function integer calculator: one expression per line, results printed
// as they are reduced. It exists to prove the toolchain end to end -
// flexc++ -> bisonc++ -> g++ 6.3.0 - and to serve as a starting skeleton.
//
//     $ echo '1 + 2 * (10 - 4)' | ./calc
//     13
int main()
{
    Parser parser;
    return parser.parse();
}
