//
//  C.m
//  DWDataBase
//
//  Created by Wicky on 2018/7/11.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "C.h"
#import <DWDatabase/DWDatabase.h>

@implementation C



+(NSDictionary *)dw_containerPropertyGenericClassMap {
    return @{
        @"array":[A class],
        @"modelDic":[A class],
        @"dicFromArray":@"A",
    };
}

+(NSDictionary *)dw_databaseFieldDefaultValueMap {
    return @{
        @"a":@"hello world",
    };
}

@end
