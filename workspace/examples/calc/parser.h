#ifndef Parser_h_included
#define Parser_h_included

#include <iostream>

// $insert baseclass
#include "parserbase.h"
// $insert scanner.h
#include "scanner.h"

#undef Parser
class Parser: public ParserBase
{
    // $insert scannerobject
    Scanner d_scanner;

    public:
        Parser() = default;

        explicit Parser(std::istream &in)
        :
            d_scanner(in)
        {}

        int parse();

    private:
        void error(char const *msg);
        int lex();
        void print();

    // support functions for parse():
        void executeAction(int ruleNr);
        void errorRecovery();
        int lookup(bool recovery);
        void nextToken();
        void print__();
        void exceptionHandler__(std::exception const &exc);
};

#endif
