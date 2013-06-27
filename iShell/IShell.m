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
#import "funcs.h"
#import <v8.h>

/**
 * shell implementation
 */
@implementation IShell {
    NSFileHandle *_outputHandle;
    EditLine* _editLine;
    History* _hist;
    BOOL _quitLoop;
    HistEvent *_hev;
    NSString *_histpath;
    
    // local vars here, make it KVC compliant
    NSMutableDictionary* _environ;
}

- (id) init {
    self = [super init];
    if (self) {
        _quitLoop = NO;
        _outputHandle = [NSFileHandle fileHandleWithStandardOutput];
        _environ = [@{@"SHELL": @"/bin/ishell"} mutableCopy];
        
        _histpath = [NSString stringWithFormat:@"%s/.ishistory", getenv("HOME")];
        _hist = history_init();
        _hev = (HistEvent *)malloc(sizeof(HistEvent));
        history(_hist, _hev, H_SETSIZE, 1000);
        history(_hist, _hev, H_LOAD, [_histpath UTF8String]);
        
        _editLine = el_init("ishell", stdin, stdout, stderr);

        el_set(_editLine, EL_HIST, history, _hist);
        el_set(_editLine, EL_SIGNAL, 1);
        el_set(_editLine, EL_TERMINAL, NULL);
        el_set(_editLine, EL_PROMPT, lprompt);
        el_set(_editLine, EL_EDITOR, "emacs");
        
        el_set(_editLine, EL_CLIENTDATA, (__bridge void*)self);
        
        NSUInteger len = builtin_funcs_length;
        for (int i = 0; i < len; ++i) {
            el_set(_editLine, EL_ADDFN, builtin_funcs[i].name, builtin_funcs[i].desc,
                   builtin_funcs[i].func);
        }

        //default bindings
        el_set(_editLine, EL_BIND, "^D", "el-quit", NULL);
        el_set(_editLine, EL_BIND, "^I", "el-complete-dwim", NULL);
        el_set(_editLine, EL_BIND, "^T", "el-h", NULL);

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

    history(_hist, _hev, H_SAVE, [_histpath UTF8String]);
    free(_hev);
    history_end(_hist);
    el_end(_editLine);
}

- (History *) hist {
    return _hist;
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

    if ([cmdline length]) {
        history(_hist, _hev, H_ENTER, buf);
    }
    
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

