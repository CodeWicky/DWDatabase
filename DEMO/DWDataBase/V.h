//
//  V.h
//  DWDataBase
//
//  Created by Wicky on 2018/7/10.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface V : NSObject

@property (nonatomic ,assign) short shortNum;

@property (nonatomic ,assign) unsigned short unsignedShortNum;

@property (nonatomic ,assign) int intNum;

@property (nonatomic ,assign) float floatNum;

@property (nonatomic ,assign) double doubleNum;

@property (nonatomic ,assign) long long longlongNum;

@property (nonatomic ,assign) unsigned int unsignedIntNum;

@property (nonatomic ,assign) long double longDoubleNum;

@property (nonatomic ,assign) unsigned long long unsignedLongLongNum;

@property (nonatomic ,assign) char chr;

@property (nonatomic ,assign) unsigned char uChr;

@property (nonatomic ,assign) char * charString;

@property (nonatomic ,strong) NSNumber * nsNum;

@property (nonatomic ,strong) NSString * string;

@property (nonatomic ,strong) NSMutableString * mString;

@property (nonatomic ,strong) NSData * data;

@property (nonatomic ,strong) NSMutableData * mData;

@property (nonatomic ,strong) NSDate * date;

@property (nonatomic ,strong) NSURL * url;

@property (nonatomic ,strong) NSArray * array;

@property (nonatomic ,strong) NSMutableArray * mArray;

@property (nonatomic ,strong) NSDictionary * dictionary;

@property (nonatomic ,strong) NSMutableDictionary * mDictionary;

@property (nonatomic ,strong) NSSet * aSet;

@property (nonatomic ,strong) NSMutableSet * mSet;

@property (nonatomic ,strong) Class cls;

@property (nonatomic ,assign) SEL sel;

@end
