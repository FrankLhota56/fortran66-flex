#ifndef __FIELD_DESC__H__
#define __FIELD_DESC__H__ 1

/*
 * field_desc_tag represents the data in a Fortran 66 `FORMAT` statement field
 * descriptor.
 */
struct field_desc_tag
{
    int scale;       /* 0 if not specified */
    int repeat;      /* 1 if not specified */
    char conversion; /* One of 'A', 'D', 'E', 'F', 'G', 'I', 'L', 'X' */
    int width;
    int fract;
};
typedef struct field_desc_tag field_desc_t;

#endif /* ndef __FIELD_DESC__H__ */
