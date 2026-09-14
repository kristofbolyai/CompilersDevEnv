#ifndef Scanner_H_INCLUDED_
#define Scanner_H_INCLUDED_

// $insert baseclass_h
#include "scannerbase.h"

// $insert classHead
class Scanner: public ScannerBase
{
    // Semantic value of the most recently matched NUMBER. The parser picks it
    // up in Parser::lex() (see parser.ih) and stores it as the token's value.
    int d_value = 0;

    public:
        explicit Scanner(std::istream &in = std::cin,
                         std::ostream &out = std::cout);

        Scanner(std::string const &infile, std::string const &outfile);

        // $insert lexFunctionDecl
        int lex();

        int value() const;

    private:
        int lex__();
        int executeAction__(size_t ruleNr);

        void setValue();

        void print();
        void preCode();
        void postCode(PostEnum__ type);
};

// $insert scannerConstructors
inline Scanner::Scanner(std::istream &in, std::ostream &out)
:
    ScannerBase(in, out)
{}

inline Scanner::Scanner(std::string const &infile, std::string const &outfile)
:
    ScannerBase(infile, outfile)
{}

// $insert inlineLexFunction
inline int Scanner::lex()
{
    return lex__();
}

inline int Scanner::value() const
{
    return d_value;
}

inline void Scanner::preCode()
{}

inline void Scanner::postCode(PostEnum__ type)
{
    (void)type;
}

inline void Scanner::print()
{
    print__();
}

#endif // Scanner_H_INCLUDED_
