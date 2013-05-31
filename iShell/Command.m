//
//  Command.m
//  OCdemo
//
//  Created by Sian Cao on 13-5-24.
//  Copyright (c) 2013年 rf. All rights reserved.
//

#import "Command.h"
#import "IShell.h"

@interface Command() {
    NSDictionary *builtinCommands;
}

- (int) exec; // run Command by exec syscall
@end

@implementation Command

- (Command*)copyWithZone:(NSZone*)zone {
    Command* cmd = [[Command allocWithZone:zone] init];
    return cmd;
}

- (id)init {
    self = [super init];
    if (self) {
        builtinCommands =
        @{
          @"exit": ^() {
              exit(0);
          },
          
          @"cd": ^() {
              const char* path = NULL;
              if ([self.args count] == 0) {
                  path = ".";
              }
              path = [[self.args objectAtIndex:0] UTF8String];
              
              int fd = -1;
              if ((fd = open(path, O_EXCL|O_RDONLY)) < 0) {
                  NSLog(@"open failed: %s", strerror(errno));
                  return;
              }
              
              if (fchdir(fd) < 0) {
                  NSLog(@"fchdir failed: %s", strerror(errno));
                  return;
              }
          },
          
          @"pwd": ^() {
              char *buf = getcwd(NULL, MAXPATHLEN);
              if (buf != NULL) {
                  NSString *msg = [[NSString stringWithUTF8String:buf] stringByAppendingString:@"\n"];
                  [self.shell writeMessage: msg];
              }
          }
        };
    }
    
    return self;
}

- (int) exec {
    //TODO: do PATH searching
    char** argv = [self cmdToCZArray];
    if (execvp(argv[0], argv) < 0) {
        NSLog(@"execvp: %s", strerror(errno));
        free(argv);
        exit(errno);
    }
    
    return 0;
}

- (int) execute {
    //1. try Command builtin
    if ([self isBuiltinCommand:self.cmd]) {
        return [self runBuiltinCommand:self.cmd];
    }
    
    //2. try editLine builtin
    int argc = (int)[self.args count] + 1;
    char** argv = [self cmdToCZArray];
    if (el_parse([self.shell editLine], argc, (const char**)argv) != -1) {
        NSLog(@"el_parse executed");
        free(argv);
        return 0;
    }
    free(argv);
    
    //3. find external executable
    int child = -1;
    switch(child = fork()) {
        case 0:
        {
            [self exec];
            break;
        }
            
        default:
        {
            int stat = 0;
            waitpid(child, &stat, 0);
            if (WIFEXITED(stat)) {
                NSLog(@"exited with %d", WEXITSTATUS(stat));
                if (WEXITSTATUS(stat) != 0) {
                    @throw [NSException exceptionWithName:@"waitpid" reason:
                            [NSString stringWithFormat:@"child exited with %d", WEXITSTATUS(stat)] userInfo:nil];
                }
                
            } else if (WIFSIGNALED(stat)) {
                NSLog(@"signaled with %d", WTERMSIG(stat));
                @throw [NSException exceptionWithName:@"waitpid" reason:@"signal" userInfo:nil];
            }
            
            
            break;
        }
    }

    return 0;
}

- (BOOL) isBuiltinCommand: (NSString*) cmd {
    return [builtinCommands objectForKey:cmd] != nil;
}

- (BOOL) runBuiltinCommand: (NSString*) cmd {
    void (^block)() = [builtinCommands objectForKey:cmd];
    if (block != nil) {
        block();
        return true;
    }
    return false;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"%@(%@)", self.cmd, [self.args componentsJoinedByString:@","], nil];
}


// helpers
- (char**) cmdToCZArray {
    unsigned long len = [self.args count] + 2;
    char** czarr = malloc(sizeof(char*) * len);
    czarr[0] = strdup([self.cmd UTF8String]);

    [self.args enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        czarr[idx+1] = strdup([obj UTF8String]);
    }];
    czarr[len-1] = NULL;
    return czarr;
}

+ (NSArray*) CZArrayToNSArray:(const char**) arr {
    NSMutableArray *ma = [[NSMutableArray alloc] init];
    while (*arr) {
        [ma addObject:[NSString stringWithUTF8String: *arr]];
        ++arr;
    }
    
    return [ma copy];
}

@end



@implementation GroupCommand

- (int)execute {
    int ret = 0;
    for (Command* cmd in [self commands]) {
        @try {
            ret = [cmd execute];
        }
        @catch (NSException *exception) {
            NSLog(@"%@: %@", [exception name], [exception reason]);
        }
    }
    return ret;
}

- (NSString*)description {
    NSMutableString *info = [[NSMutableString alloc] init];
    [self.commands enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            [info appendFormat:@"; %@", obj];
        } else {
            [info appendFormat:@"%@", obj];
        }
    }];
    
    return info;
}
@end


@implementation PipelineCommand

- (int)execute {
    NSLog(@"run PipelineCommand");
    int child = -1;
    switch(child = fork()) {
        case 0:
        {
            int fildes[2];
            if (pipe(fildes)) {
                NSLog(@"pipe failed: %s", strerror(errno));
                return -errno;
            }
            
            Command* cmd1 = [self.commands objectAtIndex:0];
            Command* cmd2 = [self.commands objectAtIndex:1];
            NSLog(@"cmd1: %@, cmd2: %@", cmd1, cmd2);
            
            switch (fork()) {
                case 0:
                    // 2nd cmd
                    close(fildes[1]);
                    if (fildes[0] != STDIN_FILENO) {
                        if (dup2(fildes[0], STDIN_FILENO) != STDIN_FILENO) {
                            NSLog(@"dup2: %s", strerror(errno));
                            exit(errno);
                        }
                        close(fildes[0]);
                    }
                    
                    [cmd2 exec];
                    break;
                    
                default:
                    // 1st cmd
                    close(fildes[0]);
                    if (fildes[1] != STDOUT_FILENO) {
                        if (dup2(fildes[1], STDOUT_FILENO) != STDOUT_FILENO) {
                            NSLog(@"dup2: %s", strerror(errno));
                            exit(errno);
                        }
                        close(fildes[1]);
                    }
                    
                    [cmd1 exec];
                    break;
            }
            break;
        }
            
        default:
        {
            int stat = 0;
            waitpid(child, &stat, 0);
            if (WIFEXITED(stat)) {
                NSLog(@"exited with %d", WEXITSTATUS(stat));
                if (WEXITSTATUS(stat) != 0) {
                    @throw [NSException exceptionWithName:@"waitpid" reason:
                            [NSString stringWithFormat:@"child exited with %d", WEXITSTATUS(stat)] userInfo:nil];
                }
                
            } else if (WIFSIGNALED(stat)) {
                NSLog(@"signaled with %d", WTERMSIG(stat));
                @throw [NSException exceptionWithName:@"waitpid" reason:@"signal" userInfo:nil];
            }
            
            
            break;
        }

    }
    return 0;
}

- (NSString*) description {
    NSMutableString *result = [[NSMutableString alloc] init];
    [self.commands enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            [result appendFormat:@"%@", obj];
        } else {
            [result appendFormat:@"| %@", obj];
        }
    }];
    
    return result;
}

@end