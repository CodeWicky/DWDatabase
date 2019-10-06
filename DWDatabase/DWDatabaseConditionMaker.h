//
//  DWDatabaseConditionMaker.h
//  DWDatabase
//
//  Created by Wicky on 2019/9/30.
//

#import <Foundation/Foundation.h>
#import "NSObject+PropertyInfo.h"
NS_ASSUME_NONNULL_BEGIN

@class DWDatabaseCondition,DWDatabaseConditionMaker;
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseConditionKey)(NSString * key);
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseConditionClass)(Class clazz);
typedef DWDatabaseCondition *_Nonnull(^DWDatabaseConditionValue)(id value);
typedef DWDatabaseCondition *_Nonnull(^DWDatabaseConditionCombine)(void);



@interface DWDatabaseCondition : NSObject

@property (nonatomic ,copy) NSString * conditionString;

@property (nonatomic ,strong) NSMutableArray <NSString *>* validKeys;

@property (nonatomic ,strong) NSMutableArray * arguments;

///以就近原则按照先前指定的逻辑关系组合调用此函数处之前的两个条件
@property (nonatomic ,copy) DWDatabaseConditionCombine combine;

///添加一个且条件（下一个添加的条件与当前条件为且关系）
-(DWDatabaseConditionMaker *)and;

///添加一个或条件（下一个添加的条件与当前条件为或 关系）
-(DWDatabaseConditionMaker *)or;

-(void)make;

@end

@interface DWDatabaseConditionMaker : NSObject

//1.指定条件装载的类
///为当前条件工厂指定索引模型类（必须在其他属性前调用）
@property (nonatomic ,copy) DWDatabaseConditionClass loadClass;

//2.指定条件对应的键值
///指定当前条件对应的键值（此处会根据先前装载的模型类自动推断出该模型类的相关属性，方便快速指定键值。），一个条件可以对应多个键值（即属性a及属性bu均等于某个值时conditionWith 可以连续调用）
@property (nonatomic ,copy) DWDatabaseConditionKey conditionWith;

//3.指定条件对应的值（一个条件只能有一个值关系及指定值）
///指定当前条件为等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue equalTo;

///指定当前条件为大于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue greaterThan;

///指定当前条件为小于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue lessThan;

///指定当前条件为大于等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue greaterThanOrEqualTo;

///指定当前条件为小于等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue lessThanOrEqualTo;

///指定当前条件为在指定值集合中的条件（例如传入@[@"zhangsan",@"lisi"] 则会匹配值为zhangsan或者lisi）
@property (nonatomic ,copy) DWDatabaseConditionValue inValues;

///指定当前条件为不在指定值集合中的条件（例如传入@[@"zhangsan",@"lisi"] 则会匹配值为非zhangsan且非lisi）
@property (nonatomic ,copy) DWDatabaseConditionValue notInValues;

///指定当前条件为模糊匹配的条件（例如传入@"zhangsan" 则会匹配值为zhangsan或者azhangsanbbb）
@property (nonatomic ,copy) DWDatabaseConditionValue like;

///指定当前条件为在指定值范围中的条件（接收值为DWBetweenFloatValue及DWBetweenIntegerValue）
@property (nonatomic ,copy) DWDatabaseConditionValue between;

@end

@interface DWDatabaseConditionMaker (Private)

-(void)configWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)propertyInfos databaseMap:(NSDictionary *)databaseMap;

-(void)make;

-(NSArray *)fetchValidKeys;

-(NSArray *)fetchArguments;

-(NSArray *)fetchConditions;

-(Class)fetchQueryClass;

@end

///没后实际意义，只为了提供自动提示
@interface DWDatabaseConditionMaker (AutoTip)

@property (nonatomic ,copy) DWDatabaseConditionClass dw_loadClass;

@property (nonatomic ,copy) DWDatabaseConditionKey dw_conditionWith;

@end

NS_ASSUME_NONNULL_END
