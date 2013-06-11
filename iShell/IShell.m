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
#import <v8.h>

static const char *lprompt(EditLine *el) {
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

struct builtin_func_descriptor_ {
    const char* name;
    const char* desc;
    unsigned char (*func)(EditLine*, int);
};

#ifndef ARRAY_LEN
#define ARRAY_LEN(arr) (sizeof(arr)/sizeof(arr[0]))
#endif

static struct builtin_func_descriptor_ builtin_funcs[] = {
    {"el-quit", "quit shell", elfn_quit}
};


/**
 * shell implementation
 */
@implementation IShell {
    NSFileHandle *_outputHandle;
    EditLine* _editLine;
    History* _hist;
    BOOL _quitLoop;

    // local vars here, make it KVC compliant
    NSMutableDictionary* _environ;
}

- (id) init {
    self = [super init];
    if (self) {
        _quitLoop = NO;
        _outputHandle = [NSFileHandle fileHandleWithStandardOutput];
        _environ = [@{@"SHELL": @"/bin/ishell"} mutableCopy];

        _hist = history_init();
        _editLine = el_init("ishell", stdin, stdout, stderr);

        el_set(_editLine, EL_HIST, history, _hist);
        el_set(_editLine, EL_SIGNAL, 1);
        el_set(_editLine, EL_TERMINAL, NULL);
        el_set(_editLine, EL_PROMPT, lprompt);
        el_set(_editLine, EL_EDITOR, "emacs");
        
        el_set(_editLine, EL_CLIENTDATA, (__bridge void*)self);
        
        NSUInteger len = ARRAY_LEN(builtin_funcs);
        for (int i = 0; i < len; ++i) {
            el_set(_editLine, EL_ADDFN, builtin_funcs[i].name, builtin_funcs[i].desc,
                   builtin_funcs[i].func);
        }
//        el_set(_editLine, EL_ADDFN, "el-quit", "quit shell", elfn_quit);
        el_set(_editLine, EL_BIND, "^D", "el-quit", NULL);

        NSString *rcpath = [NSString stringWithFormat:@"%s/.ishellrc", getenv("HOME")];
        el_source(_editLine, [rcpath UTF8String]);
    }
    return self;
}

- (void) setQuitLoop: (BOOL)val {
    NSLog(@"mark quitloop: %d", val);
    _quitLoop = val;
}

- (void) dealloc {
    NSLog(@"dealloc ishell");
    [_outputHandle closeFile];
    history_end(_hist);
    el_end(_editLine);
}

// KVC compliant implementation
// the tricky thing here is enumerator returns with keys
// by mutators handling with NSArray
- (NSUInteger)countOfEnviron {
    NSLog(@"countOfEnviron");
    return [_environ count];
}

- (NSEnumerator*)enumeratorOfEnviron {
    NSLog(@"enumeratorOfEnviron");
    NSArray* keys = [_environ allKeys];
    NSMutableSet *result = [[NSMutableSet alloc] init];
    for (NSString* key in keys) {
        [result addObject:@[key, [_environ objectForKey:key]]];
    }
    
    return [result objectEnumerator];
}

- (NSArray*)memberOfEnviron: (NSString*)key {
    NSLog(@"memberOfEnviron: %@", key);
    for (NSString* var in _environ) {
        if ([var isEqualToString:key]) {
            return [NSArray arrayWithObjects:key, [_environ objectForKey:key], nil];
        }
    }
    
    return nil;
}

- (void)addEnvironObject:(NSArray*)kvPair {
    NSLog(@"addEnvironObject: %@", kvPair);
    [_environ setObject:kvPair[1] forKey:kvPair[0]];
}

- (void)removeEnvironObject:(NSArray*)kvPair {
    [_environ removeObjectForKey:kvPair[0]];
}
//~

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

int yyparse(IShell* ishell);

- (Command*) parseLine: (NSString*) cmdline {
    if (!cmdline) {
        return nil;
    }
    const char* buf = [cmdline UTF8String];
    NSLog(@"parsing [%s]", buf);

    
    /* unknown builtin, do parsing */
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

