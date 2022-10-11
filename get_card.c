#include <stdlib.h>
#include <string.h>
#include "get_card.h"

#ifndef min
#define min(x, y) (((x) < (y)) ? (x) : (y))
#endif

static inline size_t padcard(char *card, size_t pos, size_t cardlen)
{
    memset(card + pos, ' ', cardlen - pos);
    return cardlen;
}

char *get_card(FILE *in, char *card, size_t cardlen, size_t tablen)
{
    size_t pos = 0;
    int c;

    while (pos < cardlen)
    {
        c = fgetc(in);
        switch (c)
        {
        case '\t':
            if (tablen > 0)
            {
                /*
                 * Add blanks to get to next tab stop or the end of the card,
                 * whichever comes first.
                 */
                const size_t next_tab = tablen * (pos / tablen + 1);
                pos = padcard(card, pos, min(next_tab, cardlen));
            }
            else
            {
                card[pos++] = '\t';
            }
            break;
        case '\n':
            /* Add blanks to fill out the rest of the card. */
            pos = padcard(card, pos, cardlen);
            break;
        case EOF:
            if (pos == 0)
            {
                /*
                 * All of the file returned in previous cards,
                 * return NULL to indicate end of file
                 */
                card[0] = '\0';
                return NULL;
            }
            /*
             * The last line in the file did not end with a newline; create a
             * full card for this line, will return NULL next time.
             */
            pos = padcard(card, pos, cardlen);
            break;
        default:
            card[pos++] = c;
            break;
        }
    }

    /* The card is full, discard any remaining characters from this line. */
    while (c != '\n' && c != EOF)
    {
        c = fgetc(in);
    }

    card[pos++] = '\n';
    card[pos] = '\0';

    return card;
}
