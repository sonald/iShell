//
//  funcs.c
//  iShell
//
//  Created by Sian Cao on 13-6-27.
//  Copyright (c) 2013年 Freedom. All rights reserved.
//

#include <stdio.h>
#import "funcs.h"
#import "IShell.h"

const char *lprompt(EditLine *el) {
    return "> ";
}

static unsigned char elfn_quit(EditLine *e, int ch) {
    NSLog(@"elfn_quit: %d", ch);
    IShell __unsafe_unretained * shell;
    el_get(e, EL_CLIENTDATA, &shell);
    Command *cmd = [[Command alloc] init];
    cmd.cmd = @"exit";
    cmd.shell = shell;
    [cmd execute];
    return CC_EOF;
}

static unsigned char elfn_complete_dwim(EditLine *e, int ch) {
    NSLog(@"complete it");
    return CC_NORM;
}

static unsigned char elfn_hist_list(EditLine *e, int ch) {
    IShell __unsafe_unretained *shell;
    el_get(e, EL_CLIENTDATA, &shell);
    Command *cmd = [[Command alloc] init];
    cmd.cmd = @"h";
    cmd.shell = shell;
    [cmd execute];
    return CC_NEWLINE;
}

builtin_func_descriptor builtin_funcs[] = {
    {"el-quit", "quit shell", elfn_quit},
    {"el-complete-dwim", "complete right here", elfn_complete_dwim},
    {"el-h", "show history", elfn_hist_list}
};

int builtin_funcs_length = sizeof(builtin_funcs)/sizeof(builtin_funcs[0]);