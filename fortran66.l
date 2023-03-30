%{
#include <ctype.h>
#include <inttypes.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "field_desc.h"
#include "getcard.h"
#include "y.tab.h"

/*
 * line_type_tag enumerates the Fortran 66 lines types documented in section 3.3
 * of the standard.
 */
typedef enum line_type_tag {
    LINETYPE_COMMENT,
    LINETYPE_END,
    LINETYPE_INITIAL,
    LINETYPE_CONTINUATION,
} line_type_t;
/* line_type is the type of the current line */
static line_type_t line_type = LINETYPE_END;

/* swap_line_type sets the current line type, returns type of the previous line */
static line_type_t swap_line_type(line_type_t new_type);

/*
 * prev_state is used to save / restore the statement start condition when the
 * statement is continued onto multiple lines.
 */
 static int prev_state = 0;

/*
 * f66_card_input fills an input buffer with Fortran 66 card images, returns the
 * number of characters copied to the buffer. This function is used to implement
 * `YY_INPUT`.
 */
static size_t f66_card_input(char* buf, size_t max_size, FILE* in);
#define YY_INPUT(buf,result,max_size) (result = f66_card_input(buf, max_size, yyin))

/*
 * parse_integer parses a section of text as a Fortran 66 integer. This integer
 * may have intersperced blanks.
 */
static intptr_t parse_integer(const char* text, const char* end);
#define PARSE_INTEGER(text) parse_integer(text, (text) + strlen(text))

/*
 * cut_whitespace copies the non-blank characters from a source buffer to
 * a destination buffer. The destination buffer is then null terminated.
 */
static void cut_whitespace(char *dest, const char* src, size_t len);
#define CUT_WHITESPACE(dest, src) cut_whitespace((dest), (src), strlen(src))

/*
 * read_id reads a Fortran 66 identifier into `yylval.id`. In this field, blanks
 * are removed, and letters are lower cased.
 */
static void read_id(const char *yytext);

/*
 * continuation_line_count is used to check that no statement has more than 19
 * continuation lines.
 */
static int continuation_line_count = 0;

/*
 * MULTI_LINE_HOLLERITH_LIT should be defined to allow a Hollerith literal to
 * continue onto the multiple cards.
 */
#define MULTI_LINE_HOLLERITH_LIT 1
/* #undef MULTI_LINE_HOLLERITH_LIT */

/*
 * hollerith is used to build Hollerith constants:
 * - hollerith.start is the start of the allocated buffer for this constant;
 * - hollerith.pos points to the next character to be filled; and
 * - hollerith.end points to the last character in the buffer, which should
 *   contain a null character.
 */
static struct {
    char* start;
    char* pos;
    char* end;
} hollerith = {NULL, NULL, NULL};

/*
 * pre_hollerith_state holds the start condition before starting the latest
 * `HOLLERITH` condition.
 */
static int pre_hollerith_state = 0;

/*
 * token_length returns the length of a given token in text, including leading
 * and interspersed blanks.
 */
static int token_length(const char* token, const char* text);
/* TRIM_TO_TOKEN trims yytext to the token at the starts yytext */
#define TRIM_TO_TOKEN(token) yyless(token_length(#token, yytext))

/*
 * curr_stmt is a token identifying the current statement type,
 * e.g. `BLOCK` or `IF`
 */
static int curr_stmt = END;
/*
 * START_STMT_IN_STATE sets the current statement type and starts a given
 * start condition
 */
#define START_STMT_IN_STATE(__Token, __State) do {  \
    BEGIN(__State);                                 \
    curr_stmt = (__Token);                          \
    return curr_stmt;                               \
    } while (0)
/*
 * START_STMT sets the current statement type and starts the condition
 * `STMT_REST`.
 */
#define START_STMT(__Token) START_STMT_IN_STATE((__Token), STMT_REST)
/* CURR_STMT returns the current statement type */
#define CURR_STMT() (curr_stmt)

/*
 * if_paren_level is the parentheses level when scanning an IF statement condition.
 */
static int if_paren_level = 0;

/*
 * parse_real_field_desc parses a `FORMAT` statement REAL or DOUBLE PRECISION
 * field description
 */
static field_desc_t parse_real_field_desc(const char *text);
/* parse_blank_field_desc parses a `FORMAT` statement blank field description */
static field_desc_t parse_blank_field_desc(const char *text);
/*
 * parse_other_field_desc parses a `FORMAT` statement HOLLERITY, INTEGER, or
 * LOGICAL field description
 */
static field_desc_t parse_other_field_desc(const char *text);
%}

%option yylineno

/* DEFINITIONS */

/* INITIAL start condition is used to determine line type, and return EOS */
/* when the current line ends the previous statement                      */

/* STMT_LABEL condition scans statement label from label field */
%s STMT_LABEL

/* STMT_START condition scans first token of a statement */
%s STMT_START
/* STMT_REST condition scans rest of a statement */
%s STMT_REST
/* HOLLERITH condition assembles a Hollerith constant */
%s HOLLERITH

/* EXPECT_TO condition expects the keywork `TO` as the next token */
%s EXPECT_TO
/* BLOCK_DATA condition scans block data statements */
%s BLOCK_DATA
/* FORMAT_STMT condition scans FORMAT statements */
%s FORMAT_STMT
/* IF_STMT condition scans tokens to determine the kind of IF statement */
%s IF_STMT
/* EXPECT_OCTAL condition expects the next token to be an octal number */
%s EXPECT_OCTAL

/* First character of comment lines;                                          */
/* The Fortran 66 standard specifies that comment lines start with `C`,       */
/* but many contemporary variants of Fortran 66, as well as later versions of */
/* Fortran also allowed comment lines to start with `*` or `!`.               */
COMMENT     ([C*!])

/* CONT_LINE matches the start of a continuation line */
CONT_LINE   (.{5}[^ 0\n])

/* WS matches the spaces between, and often inside, tokens */
WS          (" "*)
/* SEP matches the characters separating most tokens */
SEP         ((" "|"\n"({CONT_LINE}))*)
/* ID matches a Fortran 66 identifier */
ID          ([[:alpha:]](({WS}[[:alnum:]]){0,5}))

BASIC_INT   ([[:digit:]]([ [:digit:]]*))

BASIC_REAL  (({BASIC_INT}{WS}"."(({WS}{BASIC_INT})?))|("."{WS}{BASIC_INT}))

SP_EXP      ({WS}[Ee]{WS}(([-+]{WS})?)[[:digit:]](({WS}[[:digit:]])*))
SP_REAL     (({BASIC_REAL}({SP_EXP}?))|({BASIC_INT}{SP_EXP}))

DP_EXP      ({WS}[Dd]{WS}(([-+]{WS})?)[[:digit:]](({WS}[[:digit:]])*))
DP_REAL     (({BASIC_REAL}|{BASIC_INT}){DP_EXP})

SUBSCRIPT   ({BASIC_INT}|({BASIC_INT}{SEP}"*"{SEP})?{ID}({SEP}[-+]{SEP}{BASIC_INT})?)
ARRAY_IND   ("("{SEP}{SUBSCRIPT}({SEP},{SEP}{SUBSCRIPT})*{SEP}")")

%%

\n {
    prev_state = YYSTATE;
    BEGIN(INITIAL);
}

<INITIAL>{COMMENT}.*\n {
    switch(swap_line_type(LINETYPE_COMMENT)) {
    case LINETYPE_INITIAL:
    case LINETYPE_CONTINUATION:
        return EOS;
    default:
        break;
    }
}

<INITIAL>"     "[ 0] {
    continuation_line_count = 0;

    BEGIN(STMT_START);

    switch(swap_line_type(LINETYPE_INITIAL)) {
    case LINETYPE_INITIAL:
    case LINETYPE_CONTINUATION:
        return EOS;
    default:
        break;
    }
}

<INITIAL>[ [:digit:]]{5}[ 0] {
    continuation_line_count = 0;

    yyless(0);
    BEGIN(STMT_LABEL);

    switch(swap_line_type(LINETYPE_INITIAL)) {
    case LINETYPE_INITIAL:
    case LINETYPE_CONTINUATION:
        return EOS;
    default:
        break;
    }
}

<INITIAL>{CONT_LINE} {
    switch (swap_line_type(LINETYPE_CONTINUATION)) {
    case LINETYPE_INITIAL:
    case LINETYPE_CONTINUATION:
        break;
    default:
        YY_FATAL_ERROR("Misplaced continuation line");
        break;
    }

    if (++continuation_line_count > 19) {
        YY_FATAL_ERROR("More than 19 continuation lines");
    }

    BEGIN(prev_state);
}

<INITIAL>" "{6,}E{WS}N{WS}D{WS}/"\n" {
    switch (swap_line_type(LINETYPE_END)) {
    case LINETYPE_COMMENT:
    case LINETYPE_END:
        return END;
    case LINETYPE_INITIAL:
    case LINETYPE_CONTINUATION:
        /*
         * Return EOS for previous statement, set up rescan to return END
         */
        yyless(0);
        return EOS;
    }
}

<STMT_LABEL>[ [:digit:]]{5}[ 0] {
    BEGIN(STMT_START);
    yylval.integer = parse_integer(yytext, yytext + 5);
    return INT_LIT;
}

    /* Ignore blanks almost everywhere */
<STMT_START,STMT_REST,EXPECT_TO,BLOCK_DATA,FORMAT_STMT,IF_STMT,EXPECT_OCTAL>" "+ {
}

<STMT_START>{ID}/({SEP}{ARRAY_IND})?{SEP}= {
    read_id(yytext);
    START_STMT(ID);
}

<STMT_START>A{WS}S{WS}S{WS}I{WS}G{WS}N {
    START_STMT_IN_STATE(ASSIGN, EXPECT_TO);
}

<STMT_START>B{WS}A{WS}C{WS}K{WS}S{WS}P{WS}A{WS}C{WS}E {
    START_STMT(BACKSPACE);
}

<STMT_START>B{WS}L{WS}O{WS}C{WS}K{SEP}D{WS}A{WS}T{WS}A {
    TRIM_TO_TOKEN(BLOCK);
    START_STMT_IN_STATE(BLOCK, BLOCK_DATA);
}

<STMT_START>C{WS}A{WS}L{WS}L {
    START_STMT(CALL);
}

<STMT_START>C{WS}O{WS}M{WS}P{WS}L{WS}E{WS}X {
    START_STMT(COMPLEX);
}

<STMT_START>C{WS}O{WS}N{WS}T{WS}I{WS}N{WS}U{WS}E {
    START_STMT(CONTINUE);
}

<STMT_START>D{WS}A{WS}T{WS}A {
    START_STMT(DATA);
}

<STMT_START>D{WS}I{WS}M{WS}E{WS}N{WS}S{WS}I{WS}O{WS}N {
    START_STMT(DIMENSION);
}

<STMT_START>D{WS}O{SEP}{BASIC_INT}{SEP}{ID}{SEP}={SEP}({BASIC_INT}|{ID}){SEP}, {
    TRIM_TO_TOKEN(DO);
    START_STMT(DO);
}

<STMT_START>D{WS}O{WS}U{WS}B{WS}L{WS}E/{SEP}P{WS}R{WS}E{WS}C{WS}I{WS}S{WS}I{WS}O{WS}N {
    TRIM_TO_TOKEN(DOUBLE);
    START_STMT(DOUBLE);
}

<STMT_START>E{WS}Q{WS}U{WS}I{WS}V{WS}A{WS}L{WS}E{WS}N{WS}C{WS}E {
    START_STMT(EQUIVALENCE);
}

<STMT_START>E{WS}X{WS}T{WS}E{WS}R{WS}N{WS}A{WS}L {
    START_STMT(EXTERNAL);
}

<STMT_START>F{WS}O{WS}R{WS}M{WS}A{WS}T {
    START_STMT_IN_STATE(FORMAT, FORMAT_STMT);
}

<STMT_START>G{WS}O{SEP}T{WS}O {
    TRIM_TO_TOKEN(GO);
    START_STMT_IN_STATE(GO, EXPECT_TO);
}

<STMT_START>F{WS}U{WS}N{WS}C{WS}T{WS}I{WS}O{WS}N {
    START_STMT(FUNCTION);
}

<STMT_START>I{WS}F/{SEP}"(" {
    if_paren_level = 0;
    START_STMT(IF);
}

<STMT_START>I{WS}N{WS}T{WS}E{WS}G{WS}E{WS}R {
    START_STMT(INTEGER);
}

<STMT_START>L{WS}O{WS}G{WS}I{WS}C{WS}A{WS}L {
    START_STMT(LOGICAL);
}

<STMT_START>P{WS}A{WS}U{WS}S{WS}E {
    START_STMT_IN_STATE(PAUSE, EXPECT_OCTAL);
}

<STMT_START>R{WS}E{WS}A{WS}D {
    START_STMT(READ);
}

<STMT_START>S{WS}T{WS}O{WS}P {
    START_STMT_IN_STATE(STOP, EXPECT_OCTAL);
}

<STMT_START>S{WS}U{WS}B{WS}R{WS}O{WS}U{WS}T{WS}I{WS}N{WS}E {
    START_STMT(SUBROUTINE);
}

<STMT_START>W{WS}R{WS}I{WS}T{WS}E {
    START_STMT(WRITE);
}

<STMT_REST>\*{WS}\* {
    return EXPONENTIATION;
}

<STMT_REST>[-+*/,=] {
    return yytext[0];
}

<STMT_REST>"(" {
    if (CURR_STMT() == IF)
        ++if_paren_level;
    return yytext[0];
}

<STMT_REST>")" {
    if ((CURR_STMT() == IF) && (--if_paren_level == 0))
        BEGIN(IF_STMT);
    return yytext[0];
}

<STMT_REST>{ID} {
    read_id(yytext);
    return ID;
}

<STMT_REST>P{WS}R{WS}E{WS}C{WS}I{WS}S{WS}I{WS}O{WS}N {
    return PRECISION;
}

<STMT_REST,FORMAT_STMT>{BASIC_INT}{WS}"H" {
    const int len = parse_integer(yytext, yytext + yyleng - 1);

    if (len <= 0) {
        YY_FATAL_ERROR("Hollerith literal must have positive length");
    }

    hollerith.start = calloc((size_t)len + 1, sizeof(char));
    hollerith.pos = hollerith.start;
    hollerith.end = hollerith.start + len;

    pre_hollerith_state = YYSTATE;
    BEGIN(HOLLERITH);
}

    /*
     * Check for case where an integer constant is followed by an operator, e.g.
     *
     *   `I .LT. 0 .OR. I .GT. 9`
     *
     * The scanner should *not* make a real constant out of the sequence `0 .`!
     */
<STMT_REST>{BASIC_INT}{WS}"."{WS}(([A-Z]{WS}){2,3})"." {
    const int dot_idx = strchr(yytext, '.') - yytext;
    yyless(dot_idx);
    yylval.integer = PARSE_INTEGER(yytext);

    return INT_LIT;
}

<STMT_REST>{SP_REAL} {
    char buffer[64];

    CUT_WHITESPACE(buffer, yytext);
    sscanf(buffer, "%f", &yylval.real);
    return REAL_LIT;
}

<STMT_REST>{DP_REAL} {
    char buffer[64], *dp;

    CUT_WHITESPACE(buffer, yytext);
    if ((dp = strpbrk(buffer, "Dd")) != NULL) {
        *dp = 'E';
    }
    sscanf(buffer, "%lf", &yylval.dbl_pres);
    return DBL_PREC_LIT;
}

<STMT_REST>{BASIC_INT} {
    yylval.integer = PARSE_INTEGER(yytext);

    return INT_LIT;
}

<STMT_REST>"."{WS}F{WS}A{WS}L{WS}S{WS}E{WS}"." {
    return FALSE;
}

<STMT_REST>"."{WS}T{WS}R{WS}U{WS}E{WS}"." {
    return TRUE;
}

<STMT_REST>"."{WS}A{WS}N{WS}D{WS}"." {
    return AND;
}

<STMT_REST>"."{WS}O{WS}R{WS}"." {
    return OR;
}

<STMT_REST>"."{WS}N{WS}O{WS}T{WS}"." {
    return NOT;
}

<STMT_REST>"."{WS}L{WS}T{WS}"." {
    return LT;
}

<STMT_REST>"."{WS}L{WS}E{WS}"." {
    return LE;
}

<STMT_REST>"."{WS}E{WS}Q{WS}"." {
    return EQ;
}

<STMT_REST>"."{WS}N{WS}E{WS}"." {
    return NE;
}

<STMT_REST>"."{WS}G{WS}T{WS}"." {
    return GT;
}

<STMT_REST>"."{WS}G{WS}E{WS}"." {
    return GE;
}

<BLOCK_DATA>D{WS}A{WS}T{WS}A {
    START_STMT(DATA);
}

<EXPECT_OCTAL>[0-7](({WS}[0-7]){0,4}) {
    char buffer[6];

    CUT_WHITESPACE(buffer, yytext);
    sscanf(buffer, "%" PRIo16, &yylval.oct);
    return OCTAL;
}

<EXPECT_TO>{BASIC_INT} {
    yylval.integer = PARSE_INTEGER(yytext);
    return INT_LIT;
}

<EXPECT_TO>T{WS}O {
    BEGIN(STMT_REST);
    return TO;
}

<FORMAT_STMT>"/"({WS}"/")* {
    return FIELD_SEP;
}

<FORMAT_STMT>(-?{WS}{BASIC_INT}{WS}P{WS})?({BASIC_INT}{WS})?[DEFG]{WS}{BASIC_INT}{WS}"."{WS}{BASIC_INT} {
    yylval.field_desc = parse_real_field_desc(yytext);
    return FIELD_DESC;
}

<FORMAT_STMT>({BASIC_INT}{WS})?[AIL]{WS}{BASIC_INT} {
    yylval.field_desc = parse_other_field_desc(yytext);
    return FIELD_DESC;
}

<FORMAT_STMT>{BASIC_INT}{WS}X {
    yylval.field_desc = parse_blank_field_desc(yytext);
    return FIELD_DESC;
}

<FORMAT_STMT>[(),] {
    return yytext[0];
}

<HOLLERITH>.+ {
    size_t remaining = hollerith.end - hollerith.pos;

    #ifndef MULTI_LINE_HOLLERITH_LIT
    if (yyleng < remaining) {
        YY_FATAL_ERROR("Hollerith constant is incomplete");
    }
    #endif /* ndef MULTI_LINE_HOLLERITH_LIT */

    if (yyleng > remaining) {
        yyless(remaining);
    }

    memcpy(hollerith.pos, yytext, yyleng);
    hollerith.pos += yyleng;

    if (hollerith.pos >= hollerith.end) {
        BEGIN(pre_hollerith_state);
        yylval.hol = hollerith.start;
        hollerith.start = hollerith.pos = hollerith.end = NULL;
        return HOLLERITH_LIT;
    }
}

<IF_STMT>""/[[:digit:]] {
    /* Must be an arithmetic IF, expect three labels. */
    BEGIN(STMT_REST);
}

<IF_STMT>""/[[:alpha:]] {
    /* Must be an logical IF, expect a full statement. */
    BEGIN(STMT_START);
}

. {
    char msg[32];
    sprintf(msg, "Unrecognized character: %s\n", yytext);
    YY_FATAL_ERROR(msg);
}
%%

/* USER CODE */

/******************************************************************************/

line_type_t swap_line_type(line_type_t new_type)
{
    const line_type_t old_type = line_type;

    #ifdef MULTI_LINE_HOLLERITH_LIT
    if (new_type != LINETYPE_CONTINUATION && hollerith.pos != NULL) {
        YY_FATAL_ERROR("Hollerith constant is incomplete");
    }
    #endif /* def MULTI_LINE_HOLLERITH_LIT */

    line_type = new_type;
    return old_type;
}

/******************************************************************************/

#define F66_CARD_LEN 72
/*
 * With tab length of 6, a tab at the beginning of a line will take you to the
 * statement field.
 */
#define F66_TAB_LEN 6

size_t f66_card_input(char* buf, size_t max_size, FILE* in)
{
    char card[F66_CARD_LEN + 2];
    size_t result = 0;

    if (max_size <= F66_CARD_LEN) {
        YY_FATAL_ERROR( "YY_INPUT max_size shorter than one card" );
    }

    while ((max_size - result) > F66_CARD_LEN)
    {
        if (getcard(card, F66_CARD_LEN, F66_TAB_LEN, in) == NULL)
        {
            if (ferror(in)) {
                YY_FATAL_ERROR( "input in flex scanner failed" );
            }

            return (result > 0) ? result : YY_NULL;
        }
        memcpy(buf + result, card, F66_CARD_LEN + 1);
        result += F66_CARD_LEN + 1;
    }

    return result;
}

/******************************************************************************/

intptr_t parse_integer(const char* text, const char* end) {
    const char *p;
    intptr_t integer = 0, sign = 1;

    for (p = text; p < end; ++p) {
        switch (*p) {
        case ' ':
            break;

        case '+':
            break;

        case '-':
            sign = -1;
            break;

        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            integer *= 10;
            integer += sign * (*p - '0');
            break;
        }   /* switch */
    }       /* for */

    return integer;
}

/******************************************************************************/

void cut_whitespace(char *dest, const char* src, size_t len) {
    size_t i;

    for (i = 0; i < len; ++i) {
        switch (src[i])
        {
            case '\n':
            case ' ':
                break;
            default:
                *dest++ = src[i];
                break;
        }
    }
    *dest = '\0';
}

/******************************************************************************/

void read_id(const char *yytext) {
    char *out = yylval.id;
    const char *in;

    for (in = yytext; *in != '\0'; ++in) {
        if (*in != ' ')
            *out++ = tolower(*in);
    }
    *out = '\0';
}

/******************************************************************************/

int token_length(const char* token, const char* text) {
    int result = 0;
    const char *tokptr;

    for (tokptr = token; *tokptr != '\0'; ++tokptr, ++result) {
        result += strspn(text + result, " ");
        if (toupper(*tokptr) != toupper(text[result])) {
            YY_FATAL_ERROR("unexpected token matching error");
        }
    }

    return result;
}

/******************************************************************************/

field_desc_t parse_real_field_desc(const char *text) {
    field_desc_t result;
    const char *conv, *p, *r, *d;

    conv = strpbrk(text, "DEFGdefg");
    p = strpbrk(text, "Pp");
    d = strpbrk(conv + 1, ".");

    if (p != NULL) {
        result.scale = parse_integer(text, p);
        r = p + 1;
    } else {
        result.scale = 0;
        r = text;
    }

    while (*r == ' ') ++r;
    if (isdigit(*r)) {
        result.repeat = parse_integer(r, conv);
    } else {
        result.repeat = 1;
    }

    result.conversion = toupper(*conv);
    result.width = parse_integer(conv + 1, d);
    result.fract = parse_integer(d + 1, text + strlen(text));

    return result;
}

/******************************************************************************/

field_desc_t parse_blank_field_desc(const char *text) {
    field_desc_t result;
    char *x;

    result.scale = 0;
    result.repeat = 1;
    result.conversion = 'X';
    result.width = parse_integer(text, strpbrk(text, "Xx"));
    result.fract = 0;

    return result;
}

/******************************************************************************/

field_desc_t parse_other_field_desc(const char *text) {
    field_desc_t result;
    const char *conv = strpbrk(text, "AILail");
    const char *r;

    result.scale = 0;
    for (r = text; *r == ' '; ++r) {}
    if (isdigit(*r)) {
        result.repeat = parse_integer(r, conv);
    } else {
        result.repeat = 1;
    }
    result.conversion = toupper(*conv);
    result.width = PARSE_INTEGER(conv + 1);
    result.fract = 0;

    return result;
}
