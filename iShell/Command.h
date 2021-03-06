//
//  Command.h
//  OCdemo
//
//  Created by Sian Cao on 13-5-24.
//  Copyright (c) 2013年 rf. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IShell;

@interface Command : NSObject <NSCopying>

@property (nonatomic, retain) NSString* cmd;
@property (nonatomic, retain) NSArray* args;
@property (nonatomic, weak) IShell* shell;

- (int) execute;
- (BOOL) isBuiltinCommand: (NSString*) cmd;
- (BOOL) runBuiltinCommand: (NSString*) cmd;

- (NSString*) description;

// helper
- (char**) cmdToCZArray;
+ (NSArray*) CZArrayToNSArray:(const char**) arr;

@end

// a sequence of commands executed consecutively
@interface GroupCommand : Command
@property (nonatomic, retain) NSArray* commands;
@end

@interface PipelineCommand : Command
@property (nonatomic, retain) NSArray* commands;
@end

@interface JSCommand : Command
@property (nonatomic, retain) NSString* script;
@end


@interface VarAssignCommand : Command
@property (nonatomic, retain) NSString* var;
@property (nonatomic, retain) NSString* value;
@end

@protocol Printing

- (void) printSelf;

@end

// used in parser
extern id parsed[256];
extern int cmdptr;