//
//  DWDatabaseConfiguration.m
//  DWDatabase
//
//  Created by Wicky on 2019/11/25.
//

#import "DWDatabaseConfiguration.h"


@implementation DWDatabaseConfiguration

-(NSString *)dbPath {
    return self.dbQueue.path;
}

@end
