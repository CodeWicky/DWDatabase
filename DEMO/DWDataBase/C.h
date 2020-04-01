//
//  C.h
//  DWDataBase
//
//  Created by Wicky on 2018/7/11.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "B.h"
@interface C : NSObject
@property (nonatomic ,strong) NSString * a;

@property (nonatomic ,assign) float aNum;

@property (nonatomic ,strong) B * classB;

@property (nonatomic ,strong) NSArray <A *>* array;

@property (nonatomic ,strong) NSDictionary * dic;

@property (nonatomic ,strong) NSDictionary * modelDic;

@property (nonatomic ,strong) NSDictionary * dicFromArray;

@property (nonatomic ,strong) NSObject * obj;

@property (nonatomic ,strong) C * classC;

@end
