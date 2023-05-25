# Fortran 66 Flex Grammar

The legacy compiler development tools Lex and Yacc are geared for Pascal / C derived languages, and are hard to use on first generation languages. In particular, it was frequently noted that it is extremely difficult to write a Lex grammar for Fortran 66. This project proves that such a Lex grammar is possible. It provides a [Flex](https://ftp.gnu.org/old-gnu/Manuals/flex-2.5.4/html_mono/flex.html) grammer for Fortran 66. Flex is a GNU version of lex, with some helpful improvements. This grammar also works for flex run in original lex compatibility mode, and in POSIX lex compatability mode.

Run the command `make help` for building tests for this grammar.

## The World Where Fortran 66 Was Developed (TLDR)

To understand the quirky nature of Fortran 66, we need to take a quick review of the radically different nature of software development in the early decades of software programming.

The software development process was quite different half a century ago. Before Fortran, most programs were written in assembler. In the early decades of computers, programs were often hand written on coding sheets; these sheets would then be handed to card punch operators that would turn the program into a deck of Hollerith (punch) cards, then these cards would be processed by the assembler / compiler.

Early assembler programs would expect that parts of an instruction, such as the label, the operation code, and the operation arguments, appear in certain fields on the card, e.g. that the label appears in columns 1 through 8. To assist card punch operators, the coding sheets had vertical lines delineation the fields for the assembly language, and the Hollerith cards were also printed with the fields labeled.

## Why Scanning Fortran 66 Tokens is Hard

The [Fortran 66 standard](https://archive.org/details/ansi-x-3.9-1966-fortran-66) is quite different from any current language, including recent versions of Fortran. This standard predates many innovations that have become common in modern languages. Other unusual Fortran 66 features are motivated by the coding sheet / Hollerith card process of that era.

The novel nature of the Fortran 66 makes it a particularly difficult to tokenize, for the following reasons.

### Program Lines have a Fixed 72 Character Length

Unlike a line in a text file, a Hollerith card has a fixed length. The most common card length was 80 characters, but cards as short as 72 characters were in use when the standard was written. So, the language standard specifies that each program line is 72 characters long. If you are using longer cards, then anything past column 72 is ignored.

Needless to say, this length requirement makes no sense when the sources are in the form of text files rather than card decks. Also, Lex / Flex does not have implicit support for ignoring everything past a certain column.

### Non-Comment Lines Have Fixed Fields

A Fortran 66 line that starts with the character 'C' is a comment, and the rest of the line can be ignored. Any non-comment line consists of three fields:

| Field Name   | Columns | Description     |
|--------------|---------|-----------------|
| Label        | 1 - 5   | Label for the statement on this line |
| Continuation | 6       | Indicates whether this line continues the statement on previous line |
| Statement    | 7 - 72  | Statement contents |

This field approach provides numerous problems for the token scanner.
- A character's meaning depends on which field it occurs.
- The continuation field needs to be examined to determine if the statement on the previous line has reached its end - even if it is preceded by the label for the next statement.
- If column 6 indicates that this line is a continuation of the previous line, then columns 1 through 5 are to be ignored, and could contain anything.

### Limited Character Set

Due to the limitations of some of the platforms available in 1966, the Fortran 66 standard defines the language using a very small character set, consisting of:
- The letters `A` through `Z` (upper case only);
- The digits `0` through `9`;
- The blank character; and
- The special characters `=`, `+`, `-`, `*`, `/`, `(`, `)`, `,`, `.`, and `$`.

Because this limited character set leaves out lower case letters, virtually all Fortran 66 code samples are written in all caps, which is now viewed as shouting. Also absent from this limited character set is the horizontal tab, so those cannot be used to get text into the proper field.

The Fortran 66 character set lacks many of the characters used comparison and logical operators, such as `<` or `|`. The Fortran 66 version of these operators consist of identifiers placed between two periods, for example the "less than" operator in Fortran 66 is `.LT.` instead of `<`. Given the use of periods in real constants, this can create some tricky problems.

### No Reserved Words

Fortran 66 is one of the few languages that has absolutely no reserved words. Key words such as `IF`, `FORMAT`, and `DO` are perfectly valid Fortran 66 identifiers that could be used to name variables, blocks, functions, or subprograms. This complicates determining whether a word is a key word or an identifier. For example, consider these two statements:
```
      IF(END) GO TO 9000
      IF(I) = -1
```
In the first statement, the `IF` token is a key word; in the second, the `IF` token is an array identifier.

### Hollerith constants

In Fortran 66, String literals are called Hollerith constants. They have a format quite different from  string literals in modern language. A Hollerith constant is written as an integer literal _n_ representing the number of characters in the string, followed by the letter `H`, followed by the _n_ characters of the string. For example, the Hollerith constant for `"I LOVE FORTRAN 66"` would be written as
```
17HI LOVE FORTRAN 66
```
where `17` indicates the length of the string, and the 17 characters after the first `H` are the characters of the string constant.

A real concern for the token scanner is that there is no regular expression for matching a Hollerith constant. Fortunately, these constants can only be used in limited situations where the lack of a regular expression was not an insurmountable problem. Parsing Hollerith constants, however, is more difficult that parsing string literals in newer languages.

### Blanks are Mostly Ignored

To avoid errors caused by misreading where the blanks should go, the Fortran 66 standard treats blanks in a very cavalier fashion: in most cases, they can be added or left out without effecting program correctness.

Blanks are required to place tokens in the right field. They are also significant in Hollerith constants. But outside of these cases, blanks may be used, or excluded, nearly anywhere.
- A Fortran GO TO statement could start with either `GO TO` or `GOTO`.
- Blanks can be inserted in identifiers, e.g. `OLDX` can be written as `OLD X`.
- Numeric literals can also contain blanks, e.g. `13 717 421`.

The Fortran 66 freewheeling approach to blanks, along with the absence of reserved words, creates complications for the token scanner. For example, consider this Fortran 66 statement:
```
      DO 100 I = 1,5
```
This statement is the start of a `DO` loop, ending with the statement labeled 100, where the body of the loop is executed with `I` set to the values 1 through 5 inclusive. Now consider what happens if we replace the comma in this statement with a period:
```
      DO 100 I = 1.5
```
This one character change transformed the DO loop start into a simple assignment statement that assigns the real constant 1.5 to the variable `DO100I`. The change not only changes how the statement should be parsed; it also almost completely changes the tokens the scanner should return.

## Implementation Details

### Simulating Card Input

Hollerith cards are now a historic relic. Soon after Fortran 66, compilers read their programs from text files. The yacc / lex tools are certainly designed with text files in mind. So how do we reconcile file input with the Fortran 66 anticated card format?

#### The `getcard` Function
The function `getcard` was written to provide input to programs expecting a Hollerith card format. One of its parameters is the card length. Like `fgets`, this function reads a line from a file stream. The difference is that when `getcard` reads a line, it adjusts the part before the new line to be exactly as long as a Hollerith card.
- If the line is shorter than the card length, the line is padded on the right with blanks;
- If the line is longer than the card length, it is trimmed on the right.

If successful, `getcard` returns a buffer with the line adjusted to card length, followed by a new line character and a null.

This function also provides support for expanding tab characters. Tabs are not used on Hollerith cards, but they are quite useful in modern text files, especially when you need to place text in particular fields. The `getcard` function takes a parameter for the length of a tab stop. If this parameter is positive, then each tab is converted into one or more blanks to get to the next tab stop. The line length adjustment is done after any tab expansion.

#### Defining `YY_INPUT` for Card Input
Here we make use of the lex / flex `YY_INPUT` macro. This macro is used to get input from the file being compiled. The lex / flex grammar can define its own version of this macro. This grammar defines `YY_INPUT` to read in one or more cards of length 72 using the `getcard` function. The `getcard` calls in this macro use tab stops of length 6, meaning that a tab at the start of a line will the statement field.

### Case Sensitivity

As noted before, the Fortran 66 character set does not include lower case letters, so arguably, the Fortran 66 grammar should require that the programs be written in all caps. That is too ugly to be acceptable by modern standards. Later versions of Fortran are case insensitive.

So should a Fortran 66 compiler be case sensitive? This flex grammar was written to accomidate both an upper case only and a case insensitive compiler.
- This Fortran 66 flex grammar uses upper case letters in the patterns, so this grammer could support an upper case only version of Fortran 66.
- The `Makefile` for this project, however, invokes flex with a command line parameter to generate a case insensitive scanner from this parser. Using this scanner, one could write Fortran 66 programs that are not all shouting.

### Tokens with Intersperced Blanks

Most Fortran 66 tokens can have intersperced blanks. The flex grammar has to reflect this.
- The Fortran 66 patterns for the various numeric literals include blanks among the characters that can be part of the token; these values are ignored to obtain the numeric value of the token.
- Identifiers or literals are detected by patterns that include possible embedded blanks. To put identifiers into canonical form, these blanks are squeezed out and the letters are lower cased.

### Detecting Statement Endings

A Fortran 66 parser requires an indication of statement ending, so this grammar will produce a token `EOS` at the end of every statements. Unlike the C-like languages, there is no text such as `;` that indicates the end of a statement. Instead, the end of a Fortran 66 statement is indicated by a change in the line type.

There are essentially four types of Fortran 66 lines:
1. Comment line;
1. End line;
1. Initial line (start of a statement); and
1. Continuation line (continue the statement on the previous line).

A Fortran 66 statement ends when the line after the statement text has a type other than Continuation.

*Note:* Since the line after the statement text has to be scanned in order to determine if the statement has ended, the `EOS` token will always have the line number of the line after the last statement line. For example, if a statement occupies lines 101 through 103, the `EOS` token for that statement will appear on line 104.

This grammar tracks the line types in order to determine line endings, as well as when to begin certain start conditions. The type `line_type_t` enumerates these four line types, and the variable `line_type` is set to the type of the current line. The `INITIAL` start condition uses patterns to determine the line type, and return `EOS` when appropriate.

### Scanning Statement Labels

The `INITIAL` start condition uses two patterns for detecting initial lines: one for those initial lines with a statement label, and one for those without a label. The reason for this is that labeled statements pose a special challenge: they often require that the scanner return an `EOS` token for the previous statement, followed by the label for the statement starting on this line.

To return these tokens in the appropriate order, there is a start state `STMT_LABEL` that is used specifically for scanning a label from the label field. When the `INITIAL` condition detects a labeled initial line, it takes the following actions:
1. First, it calls `yyless(0)` and begins the `STMT_LABEL` start condition so that the next rule will rescan this line to get the label; then
1. If the previous line was either a initial or continue line, an `EOS` token for that statement is returned.

### Detecting Key Words

The lack of reserved words significantly complicate finding the key words in Fortran 66 code. The key to making this distinction is that virtually all Fortran 66 key words appear at the start of the statement. The only Fortran 66 statements that start with an identifier instead of a key word are:
1. Assignment statements of the form `v = e`; and
1. Statement functions that look like an assignment to an array reference.

At the start of the statement, in the `STMT_START` condition, the very first pattern searched for is one that detects these types of statement. The pattern for these statements has an unusually complex trailing context, but detecting this type of statement first avoids many of the key word detection problems given above.

### Eliminating "dangerous trailing context" Errors

Sometimes, multiple trailing context patterns cannot be properly matched (See [Deficiencies / Bugs](https://ftp.gnu.org/old-gnu/Manuals/flex-2.5.4/html_mono/flex.html#SEC23)). Problematic trailing context patterns will cause `flex` to generate `"dangerous trailing context"` warnings.

To avoid these warning and possibly errors, the patterns for matching statements such as `DO` loops do not use trailing contexts. Instead, enough of the statement is matched to determine when kind of statement we have, then we call `yyless` to resize the buffer to the end of the first token, e.g. the end of the `DO` key word.

### Building Hollerith Constants

When the start of a Hollerith constant is detected, this scanner computes the text length, then begins the start condition `HOLLERITH`. In this conditon, blanks are significant. While in the `HOLLERITH` condition, statement field text is transferred to an allocated buffer until this buffer grows to the specified length. Once we reach that length, the scanner restores the start condition that was active before beginning `HOLLERITH`, and return a Hollerith constant token with this buffer as its value.

This flex grammar allows a Hollerith constant to span multiple lines. The standard does not explicitly require support for this, but the grammar supports it for two reasons:
1. There are 1960's Fortran code samples with multi-line Hollerith constants; and
1. If a Hollerith constant is limited to one line, then no such constant could be longer than 63 characters.

To change this grammar so that Hollerith literals are restricted to a single line, comment out the definition of the macro `MULTI_LINE_HOLLERITH_LIT` in `fortran66.l`.
