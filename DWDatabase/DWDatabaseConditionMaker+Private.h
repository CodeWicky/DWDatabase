//
//  DWDatabaseConditionMaker+Private.h
//  DWDatabase
//
//  Created by Wicky on 2020/4/14.
//

typedef NS_ENUM(NSUInteger, DWDatabaseConditionLogicalOperator) {
    DWDatabaseConditionLogicalOperatorNone,
    DWDatabaseConditionLogicalOperatorAnd,
    DWDatabaseConditionLogicalOperatorOR,
};

typedef NS_ENUM(NSUInteger, DWDatabaseValueRelation) {
    DWDatabaseValueRelationEqual,
    DWDatabaseValueRelationNotEqual,
    DWDatabaseValueRelationGreater,
    DWDatabaseValueRelationLess,
    DWDatabaseValueRelationGreaterOrEqual,
    DWDatabaseValueRelationLessOrEqual,
    DWDatabaseValueRelationInValues,
    DWDatabaseValueRelationNotInValues,
    DWDatabaseValueRelationLike,
    DWDatabaseValueRelationBetween,
    DWDatabaseValueRelationIsNull,
    DWDatabaseValueRelationNotNull,
    
    ///以下类型为错误处理类型
    DWDatabaseValueRelationErrorALL,///创建一个可以匹配所有的条件
    DWDatabaseValueRelationErrorNone,///创建一个什么也匹配不到的条件
};

#import "DWDatabaseConditionMaker.h"

@interface DWDatabaseConditionMaker (Private)

@property (nonatomic ,strong) NSMutableArray <DWDatabaseCondition *>* conditions;

@property (nonatomic ,strong) DWDatabaseCondition * currentCondition;

@property (nonatomic ,strong) Class clazz;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator conditionOperator;

@property (nonatomic ,strong) NSString * tblName;

@property (nonatomic ,strong) NSDictionary * propertyInfos;

@property (nonatomic ,strong) NSDictionary * databaseMap;

@property (nonatomic ,strong) NSMutableArray * validKeys;

@property (nonatomic ,strong) NSMutableArray * arguments;

@property (nonatomic ,strong) NSMutableArray * conditionStrings;

@property (nonatomic ,strong) NSMutableSet * joinTables;

@property (nonatomic ,assign) BOOL hasSubProperty;

@property (nonatomic ,assign) BOOL subPropertyEnabled;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblNameMap;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblMapCtn;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblDataBaseMap;

@property (nonatomic ,strong) NSMutableArray * bindKeys;

-(void)configWithTblName:(NSString *)tblName propertyInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)propertyInfos databaseMap:(NSDictionary *)databaseMap enableSubProperty:(BOOL)enableSubProperty;

-(void)make;

-(NSArray *)fetchValidKeys;

-(NSArray *)fetchArguments;

-(NSArray *)fetchConditions;

-(NSArray *)fetchJoinTables;

-(Class)fetchQueryClass;

-(DWDatabaseCondition *)installConditionWithValue:(id)value relation:(DWDatabaseValueRelation)relation;

@end

@interface DWDatabaseCondition (Private)

@property (nonatomic ,copy) NSString * conditionString;

@property (nonatomic ,strong) NSMutableArray <NSString *>* validKeys;

@property (nonatomic ,strong) NSMutableArray * arguments;

@property (nonatomic ,strong) NSMutableArray <NSString *>* conditionKeys;

@property (nonatomic ,strong) NSMutableSet * joinTables;

@property (nonatomic ,assign) DWDatabaseValueRelation relation;

@property (nonatomic ,strong) id value;

@property (nonatomic ,weak) DWDatabaseConditionMaker * maker;

@property (nonatomic ,weak) DWDatabaseCondition * operateCondition;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator conditionOperator;

-(void)make;

@end

@interface DWDatabaseOperateCondition : DWDatabaseCondition

@property (nonatomic ,strong) DWDatabaseCondition * conditionA;

@property (nonatomic ,strong) DWDatabaseCondition * conditionB;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator combineOperator;

@end