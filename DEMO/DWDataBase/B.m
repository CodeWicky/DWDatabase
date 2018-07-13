//
//  B.m
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "B.h"

@implementation B
+(NSDictionary *)dw_ModelKeyToDataBaseMap {
    static NSDictionary * map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{@"b":@"c"};
    });
    return map;
}

+(NSArray *)dw_DataBaseBlackList {
    static NSArray * list = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        list = @[@"a"];
    });
    return list;
}
@end
