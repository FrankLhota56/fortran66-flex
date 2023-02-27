#ifndef __GETCARD__H_
#define __GETCARD__H_

#include <stdio.h>

/**
 * getcard reads a line from a file as a simulated punch card.
 *
 * Cards are of fixed length, usually 80 characters. The tab character is often
 * not supported, so this function can replace tabs with spaces.
 * - If `tablen` is positive, the tab stops are located every `tablen`
 *   characters, and every tab is replaced with enough blanks to reach the next
 *   tab stop or end of card, whichever comes first.
 * - If `tablen` is zero, the tab character is treated like any other character.
 * - If a line read from `in` is shorter than `cardlen` characters long, that
 *   line will be padded on the right with blanks.
 * - If a line read from `in` is longer than `cardlen` characters, the line will
 *   be truncated to `cardlen` characters.
 * - If the last line in a file is not terminated with a newline character, this
 *   function will still return a full card for that line.
 *
 * When successful, this function will store in `card` exactly `cardlen`
 * characters, followed by a newline character and a null. Make sure that the
 * size of `card` is at least `cardlen`+2.
 *
 * Return pointer to the card if successful, NULL if end of file or error.
 */
extern char *getcard(FILE *in, char *card, size_t cardlen, size_t tablen);

#endif /* ndef __GETCARD__H_ */
