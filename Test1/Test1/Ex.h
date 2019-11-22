//
//  Ex.h
//  Test1
//
//  Created by Wicky on 2019/11/8.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class Ax;
@interface Ex : NSObject

@property (nonatomic ,assign) int num;

@property (nonatomic ,strong) NSString * name;

@property (nonatomic ,strong) Ex * obj;

@property (nonatomic ,strong) Ax * aObj;

@end

NS_ASSUME_NONNULL_END
