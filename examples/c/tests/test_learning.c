#include "learning.h"

#include <limits.h>
#include <stdio.h>

int main(void)
{
    const struct {
        int left;
        int right;
        int expected;
    } cases[] = {
        {3, 7, 7},
        {7, 3, 7},
        {-3, -7, -3},
        {0, 0, 0},
        {INT_MIN, INT_MAX, INT_MAX},
    };

    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        const int actual = maximum(cases[i].left, cases[i].right);
        if (actual != cases[i].expected) {
            fprintf(stderr, "case %zu: expected %d, got %d\n",
                    i, cases[i].expected, actual);
            return 1;
        }
    }
    return 0;
}
