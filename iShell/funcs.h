//
//  funcs.h
//  iShell
//
//  Created by Sian Cao on 13-6-27.
//  Copyright (c) 2013年 Freedom. All rights reserved.
//


#import <histedit.h>

@class IShell;

typedef struct builtin_func_descriptor_ {
    const char* name;
    const char* desc;
    unsigned char (*func)(EditLine*, int);
} builtin_func_descriptor;

#ifndef ARRAY_LEN
#define ARRAY_LEN(arr) (sizeof(arr)/sizeof(arr[0]))
#endif

#define MAX_FUCNS 128

extern const char *lprompt(EditLine *el);
extern builtin_func_descriptor builtin_funcs[];
extern int builtin_funcs_length;
