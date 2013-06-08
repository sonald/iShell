//
//  main.m
//  OCdemo
//
//  Created by Sian Cao on 05/18/13.
//  Copyright (c) 2013 rf. All rights reserved.
//

#import "IShell.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        IShell* ishell = [[IShell alloc] init];

        [ishell writeMessage:(@"Welcome to iShell\n")];
        while (1) {
            NSString* line = [ishell readline];
            Command* cmd = [ishell parseLine:line];
            [cmd execute];

            if ([[ishell valueForKey:@"quitLoop"] boolValue]) {
                break;
            }
        }
    }
    
    return 0;
}
