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

@implementation IShell {
    NSFileHandle *inputHandle;
    NSFileHandle *outputHandle;
}

- (id) init {
    self = [super init];
    if (self) {
        inputHandle = [NSFileHandle fileHandleWithStandardInput];
        outputHandle = [NSFileHandle fileHandleWithStandardOutput];
    }
    return self;
}

- (void) writeMessage:(NSString *)msg {
    [outputHandle writeData: [msg dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *) readline {
    NSMutableString *result = [[NSMutableString alloc] init];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\\\\\s+$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    
    do {
        NSString *line = [[NSString alloc] initWithData:[inputHandle availableData] encoding:NSUTF8StringEncoding];
//        NSLog(@"GOT: [%@]", line);
        [result appendString:line];

        if ([re numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] == 0) {
            break;
        }

        NSRange range = [re rangeOfFirstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        [result deleteCharactersInRange:range];
    } while (YES);
    
    return [result stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r"]];
            
}

extern int yyparse();

- (Command*) parseLine: (NSString*) cmdline {

    const char* buf = [cmdline UTF8String];
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

