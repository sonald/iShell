//
//  IShell.m
//  OCdemo
//
//  Created by Sian Cao on 13-5-24.
//  Copyright (c) 2013年 rf. All rights reserved.
//

#import "IShell.h"
#import "lexer.yy.h"
#import "y.tab.h"


static char *lprompt(EditLine *el) {
    return "> ";
}

static unsigned char elfn_quit(EditLine *e, int ch) {
    NSLog(@"elfn_quit: %d", ch);
    IShell* shell;
    el_get(e, EL_CLIENTDATA, &shell);
    Command *cmd = [[Command alloc] init];
    cmd.cmd = @"exit";
    cmd.shell = shell;
    return [cmd execute];
}

@implementation IShell {
    NSFileHandle *_outputHandle;
    EditLine* _editLine;
    History* _hist;
}

- (id) init {
    self = [super init];
    if (self) {
        _outputHandle = [NSFileHandle fileHandleWithStandardOutput];
        
        _editLine = el_init("ishell", stdin, stdout, stderr);
        _hist = history_init();
        
        el_set(_editLine, EL_HIST, history, _hist);
        el_set(_editLine, EL_SIGNAL, 1);
        el_set(_editLine, EL_TERMINAL, NULL);
        el_set(_editLine, EL_PROMPT, lprompt);
        el_set(_editLine, EL_EDITOR, "emacs");
        el_set(_editLine, EL_TELLTC, NULL);
        
        el_set(_editLine, EL_CLIENTDATA, (__bridge void*)self);
        
        el_set(_editLine, EL_ADDFN, "el-quit", "quit shell", elfn_quit);
        el_set(_editLine, EL_BIND, "^D", "el-quit", NULL);
    }
    return self;
}

- (void) dealloc {
    NSLog(@"dealloc ishell");
    [_outputHandle closeFile];
    history_end(_hist);
    el_end(_editLine);
}

- (EditLine*) editLine {
    return _editLine;
}

- (void) writeMessage:(NSString *)msg {
    [_outputHandle writeData: [msg dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *) readline {
    int count = 0;
    const char* line = el_gets(_editLine, &count);
    NSLog(@"readline: [%s]", line);
    if (line) {
        NSMutableString *result = [NSMutableString stringWithUTF8String:line];
        return [result stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r"]];
    }
    
    return nil;
}

extern int yyparse();

- (Command*) parseLine: (NSString*) cmdline {
    if (!cmdline) {
        return nil;
    }
    const char* buf = [cmdline UTF8String];
    NSLog(@"parsing [%s]", buf);

    
    /* unknown bultiin */
    YY_BUFFER_STATE bp = yy_scan_string(buf);
    yy_switch_to_buffer(bp);
    int result = yyparse(self);
    
    Command* cmd = nil;
    if (result == 0) {
        yy_delete_buffer(bp);
        cmd = parsed[cmdptr];
        NSLog(@"parsed: %@ of %@", cmd, [cmd className]);
        
    } else {
        NSLog(@"parse failed");
    }

    return cmd;
}

@end

