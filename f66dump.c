#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "field_desc.h"
#include "y.tab.h"

extern FILE *yyin;
extern int yylineno;

extern int yylex(void);

YYSTYPE yylval;

int main(int argc, char *argv[])
{
    int token;

    if (argc > 1)
    {
        yyin = fopen(argv[1], "rt");
        if (yyin == NULL)
        {
            printf("ERROR: cannot open %s\n", argv[1]);
            return 1;
        }
    }
    else
    {
        yyin = stdin;
    }

    while ((token = yylex()) > 0)
    {
        printf("Line %5d: ", yylineno);

        switch (token)
        {
#undef DUMP_TOKEN
#define DUMP_TOKEN(__token)        \
        case __token:              \
            printf(#__token "\n"); \
            break

        DUMP_TOKEN(AND);
        DUMP_TOKEN(ASSIGN);
        DUMP_TOKEN(BACKSPACE);
        DUMP_TOKEN(BLOCK);
        DUMP_TOKEN(CALL);
        DUMP_TOKEN(COMPLEX);
        DUMP_TOKEN(CONTINUE);
        DUMP_TOKEN(DATA);
        DUMP_TOKEN(DIMENSION);
        DUMP_TOKEN(DO);
        DUMP_TOKEN(DOUBLE);
        DUMP_TOKEN(END);
        DUMP_TOKEN(EOS);
        DUMP_TOKEN(EQ);
        DUMP_TOKEN(EQUIVALENCE);
        DUMP_TOKEN(EXPONENTIATION);
        DUMP_TOKEN(EXTERNAL);
        DUMP_TOKEN(FALSE);
        DUMP_TOKEN(FORMAT);
        DUMP_TOKEN(FUNCTION);
        DUMP_TOKEN(FIELD_SEP);
        DUMP_TOKEN(GE);
        DUMP_TOKEN(GO);
        DUMP_TOKEN(GT);
        DUMP_TOKEN(IF);
        DUMP_TOKEN(INTEGER);
        DUMP_TOKEN(LE);
        DUMP_TOKEN(LOGICAL);
        DUMP_TOKEN(LT);
        DUMP_TOKEN(NE);
        DUMP_TOKEN(NOT);
        DUMP_TOKEN(OR);
        DUMP_TOKEN(PAUSE);
        DUMP_TOKEN(PRECISION);
        DUMP_TOKEN(READ);
        DUMP_TOKEN(REAL);
        DUMP_TOKEN(RETURN);
        DUMP_TOKEN(REWIND);
        DUMP_TOKEN(STOP);
        DUMP_TOKEN(SUBROUTINE);
        DUMP_TOKEN(TO);
        DUMP_TOKEN(TRUE);
        DUMP_TOKEN(WRITE);

        case ID:
            printf("ID(%s)\n", yylval.id);
            break;

        case OCTAL:
            printf("OCTAL(%05" PRIo16 ")\n", yylval.oct);
            break;

        case INT_LIT:
            printf("INT_LIT(%" PRIdPTR ")\n", yylval.integer);
            break;

        case REAL_LIT:
            printf("REAL_LIT(%f)\n", yylval.real);
            break;

        case DBL_PREC_LIT:
            printf("DBL_PREC_LIT(%f)\n", yylval.dbl_pres);
            break;

        case HOLLERITH_LIT:
            printf("HOLLERITH_LIT(%s)\n", yylval.hol);
            free(yylval.hol);
            break;

        case FIELD_DESC:
            switch (yylval.field_desc.conversion)
            {
            case 'A':
            case 'I':
            case 'L':
                printf("FIELD_DESC(%d%c%d)\n",
                       yylval.field_desc.repeat, yylval.field_desc.conversion,
                       yylval.field_desc.width);
                break;

            case 'D':
            case 'E':
            case 'F':
            case 'G':
                printf("FIELD_DESC(%dP%d%c%d.%d)\n",
                       yylval.field_desc.scale, yylval.field_desc.repeat,
                       yylval.field_desc.conversion, yylval.field_desc.width,
                       yylval.field_desc.fract);
                break;

            case 'X':
                printf("FIELD_DESC(%d%c)\n",
                       yylval.field_desc.width, yylval.field_desc.conversion);
                break;

            default:
                printf("FIELD_DESC(%c)\n",
                       yylval.field_desc.conversion);
                break;
            }
            break;

        default:
            if (token < 256)
            {
                printf("'%c'\n", token);
            }
            else
            {
                printf("Unknown token <%d>\n", token);
            }

            break;
        }
    }
    return 0;
}
