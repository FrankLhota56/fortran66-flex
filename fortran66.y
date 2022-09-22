%{
  #include <stdint.h>

  #include "field_desc.h"
  extern int yylex(void);
  extern void yyerror(char *s);
%}

  /*
   * This is a grammar for Fortran 66, basically enough to define the tokens
   * required for such a grammar, which is require for the flex parser.
   */

%union {
  char      id[7];
  uint16_t  oct;
  intptr_t  integer;
  float     real;
  double    dbl_pres;
  char*     hol;      /* allocated string, caller needs to free it */

  field_desc_t field_desc;
};

%token <id>    ID
%token <oct>   OCTAL

%token <integer>  INT_LIT
%token <real>     REAL_LIT
%token <dbl_pres> DBL_PREC_LIT
%token <hol>      HOLLERITH_LIT

%token <field_desc> FIELD_DESC
%token FIELD_SEP

%token EOS

%token FALSE
%token TRUE
%token AND
%token OR
%token NOT

%token LT
%token LE
%token EQ
%token NE
%token GT
%token GE

%token EXPONENTIATION

%token ASSIGN
%token BACKSPACE
%token BLOCK
%token CALL
%token COMMON
%token COMPLEX
%token CONTINUE
%token DATA
%token DIMENSION
%token DOUBLE
%token DO
%token END
%token ENDFILE
%token EQUIVALENCE
%token EXTERNAL
%token FORMAT
%token FUNCTION
%token GO
%token IF
%token INTEGER
%token LOGICAL
%token PAUSE
%token PRECISION
%token READ
%token REAL
%token RETURN
%token REWIND
%token STOP
%token SUBROUTINE
%token TO
%token WRITE

%%

program:
  /* empty */
  | program program_unit
  ;

program_unit:
  main_program
  | subprogram
  ;

main_program: program_body;

subprogram: subprogram_header program_body;

program_body: statement_sequence END;

statement_sequence:
  /* empty */
  | statement_sequence statement
  ;

opt_id: /* empty */ | ID;
id_list: ID | id_list ',' ID;
dummy_parameters: /* empty */ | '(' id_list ')';

constant:
  INT_LIT
  | REAL_LIT
  | DBL_PREC_LIT
  | HOLLERITH_LIT
  ;

type:
  COMPLEX
  | DOUBLE PRECISION
  | INTEGER
  | LOGICAL
  | REAL
  ;

function_type:
  /* empty */
  | type
  ;

subprogram_header:
  SUBROUTINE ID dummy_parameters EOS
  | function_type FUNCTION ID dummy_parameters EOS
  | BLOCK DATA opt_id EOS
  ;

label_list:
  INT_LIT
  | label_list ',' INT_LIT
  ;

opt_octal:
  /* empty */
  | OCTAL
  ;

io_unit:
  ID
  | INT_LIT
  ;

io_format:
  INT_LIT
  | ID
  ;

io_list:
  io_list_item
  | io_list ',' io_list_item
  ;

io_list_item:
  simple_list
  | '(' simple_list ')'
  | do_implied_list
  ;

simple_list:
  simple_list_item
  | simple_list ',' simple_list_item
  ;

simple_list_item:
  ID
  | array_element
  ;

do_implied_list:
  '(' io_list ',' ID '=' do_params ')'
  ;

opt_io_list:
  /* empty */
  | io_list
  ;

/*
 * if_statement_action represents the action that a logical IF statemeent can
 * perform if the logical expression evaluates as true.
 */
if_statement_action:
  lvalue '=' expression
  | ASSIGN INT_LIT TO ID
  | BACKSPACE io_unit
  | CONTINUE
  | CALL ID opt_arglist
  | ENDFILE io_unit
  | GO TO INT_LIT
  | GO TO ID ',' '(' label_list ')' 
  | GO TO '(' label_list ')' ',' ID
  | IF '(' arithmetic_expression ')' INT_LIT ',' INT_LIT ',' INT_LIT
  | PAUSE opt_octal
  | READ '(' io_unit ')' opt_io_list
  | READ '(' io_unit ',' io_format ')' opt_io_list
  | RETURN
  | REWIND io_unit
  | STOP opt_octal
  | WRITE '(' io_unit ')' opt_io_list
  | WRITE '(' io_unit ',' io_format ')' opt_io_list
  ;

opt_label:
  /* empty */
  | INT_LIT
  ;

statement:
  executable_statement
  | non_executable_statement
  ;

do_param:
  ID
  | INT_LIT
  ;

do_params:
  do_param ',' do_param ',' do_param
  | do_param ',' do_param
  ;

executable_statement:
  opt_label if_statement_action EOS
  | opt_label DO INT_LIT ID '=' do_params EOS
  | opt_label IF '(' logical_expression ')' if_statement_action EOS
  ;

non_executable_statement:
  specification_statement
  DATA data_setting_list EOS
  FORMAT '(' format_list ')' EOS
  ;

specification_statement:
  DIMENSION array_declarator_list EOS
  | COMMON common_list EOS
  | EQUIVALENCE equivalence_list EOS
  | EXTERNAL id_list EOS
  | type id_list EOS
  ;

opt_arglist:
  /* empty */
  | '(' arglist ')'
  ;

arglist: arg | arglist ',' arg;

arg: HOLLERITH_LIT | expression ;

fixed_array_declarator:
  ID '(' fixed_declarator_subscript ')'
  ;

fixed_declarator_subscript:
  INT_LIT ',' INT_LIT ',' INT_LIT
  | INT_LIT ',' INT_LIT
  | INT_LIT
  ;

fixed_list_item:
  fixed_array_declarator
  | ID
  ;

fixed_list:
  fixed_list_item
  | fixed_list ',' fixed_list_item
  ;

array_declarator_list:
  array_declarator
  | array_declarator_list ',' array_declarator
  ;

array_declarator:
  ID '(' declarator_subscript ')'
  ;

declarator_subscript:
  array_dimension ',' array_dimension ',' array_dimension
  | array_dimension ',' array_dimension
  | array_dimension
  ;

array_dimension:
  INT_LIT
  | ID
  ;

data_item:
  constant
  | INT_LIT '*' constant
  ;

data_list:
  data_item
  | data_list ',' data_item
  ;

data_setting:
  fixed_list '/' data_list '/'
  ;

data_setting_list:
  data_setting
  | data_setting_list ',' data_setting
  ;

equivalence_list_item:
  '(' fixed_list_item ',' fixed_list ')'
  ;

equivalence_list:
  equivalence_list_item
  | equivalence_list ',' equivalence_list_item
  ;

field_sep:
  ','
  | FIELD_SEP
  ;

opt_field_sep:
  /* empty */
  | FIELD_SEP
  ;

field_list:
  field_desc
  | field_list field_sep field_desc
  ;

field_desc:
  single_file_desc
  | INT_LIT '*' single_file_desc
  ;

single_file_desc:
  FIELD_DESC
  | HOLLERITH_LIT
  | '(' field_list ')'
  ;

format_list:
  opt_field_sep
  | opt_field_sep field_list opt_field_sep
  ;

block_item: ID | array_declarator;

block_list:
  block_item
  | block_list ',' block_item
  ;

block_name:
  '/' ID '/'
  | '/' '/'
  ;

common_list:
  block_list
  | block_name block_list
  | common_list block_name block_list
  ;

expression:
  arithmetic_expression
  | relational_expression
  | logical_expression
  ;

primary:
  '(' arithmetic_expression ')'
  | INT_LIT
  | REAL_LIT
  | DBL_PREC_LIT
  | ID 
  | function_call
  ;

factor:
  primary
  | primary EXPONENTIATION primary
  ;

termp:
  | factor
  | termp '*' factor
  ;

term:
  termp
  | termp '/' factor
  ;

simple_arithmetic_expression:
  term
  | simple_arithmetic_expression sign term
  ;

arithmetic_expression:
  optional_sign simple_arithmetic_expression
  ;

sign: '+' | '-';
optional_sign:
  /* empty */
  | sign
  ;

optional_index_scale:
  /* empty */
  | INT_LIT '*'
  ;

optional_index_offset:
  /* empty */
  | sign INT_LIT
  ;

subscript:
  INT_LIT
  | optional_index_scale ID optional_index_offset
  ;

subscript_list:
  subscript ',' subscript ',' subscript
  | subscript ',' subscript
  | subscript
  ;

array_element:
  ID '(' subscript_list ')'
  ;

lvalue:
  ID
  | array_element
  ;

function_call:
  ID '(' arglist ')'
  ;

relational_operator: LT | LE | EQ | NE | GT | GE ;

relational_expression: arithmetic_expression relational_operator arithmetic_expression ;

logical_constant: FALSE | TRUE ;

logical_primary:
  '(' logical_expression ')'
  | relational_expression
  | logical_constant
  | ID
  | function_call
  ;

logical_factor:
  logical_primary
  | NOT logical_primary
  ;

logical_term:
  logical_factor
  | logical_term AND logical_factor
  ;

logical_expression:
  logical_term
  | logical_expression OR logical_term
  ;

%%
