//
//  IShell.h
//  OCdemo
//
//  Created by Sian Cao on 13-5-24.
//  Copyright (c) 2013年 rf. All rights reserved.
//

#import <histedit.h>
#import <Foundation/Foundation.h>
#import "Command.h"
#import <v8.h>

@interface IShell: NSObject

- (EditLine*) editLine;
- (History *) hist;

/**
 * @param line
 * @return nil if parse failed, or the completed parsed command info
 */
- (Command*) parseLine: (NSString*) cmdline;

/**
 * @return a completed cmdline ( may spawn multiple lines )
 */
- (NSString *) readline;

// helper
- (void) writeMessage:(NSString *)msg;
@end

