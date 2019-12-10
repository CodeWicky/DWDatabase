//
//  DWDatabaseConditionMaker.m
//  DWDatabase
//
//  Created by Wicky on 2019/9/30.
//

#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabaseFunction.h"

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

typedef NS_ENUM(NSUInteger, DWDatabaseConditionLogicalOperator) {
    DWDatabaseConditionLogicalOperatorNone,
    DWDatabaseConditionLogicalOperatorAnd,
    DWDatabaseConditionLogicalOperatorOR,
};

@interface DWDatabaseCondition ()

@property (nonatomic ,strong) NSMutableArray <NSString *>* conditionKeys;

@property (nonatomic ,assign) DWDatabaseValueRelation relation;

@property (nonatomic ,strong) id value;

@property (nonatomic ,weak) DWDatabaseConditionMaker * maker;

@property (nonatomic ,weak) DWDatabaseCondition * operateCondition;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator conditionOperator;

@end

@interface DWDatabaseOperateCondition : DWDatabaseCondition

@property (nonatomic ,strong) DWDatabaseCondition * conditionA;

@property (nonatomic ,strong) DWDatabaseCondition * conditionB;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator combineOperator;

@end

@interface DWDatabaseOperateCondition ()
{
    NSString * _conditionString;
}

@end

@interface DWDatabaseConditionMaker()

@property (nonatomic ,strong) NSMutableArray <DWDatabaseCondition *>* conditions;

@property (nonatomic ,strong) DWDatabaseCondition * currentCondition;

@property (nonatomic ,strong) Class clazz;

@property (nonatomic ,assign) DWDatabaseConditionLogicalOperator conditionOperator;

@property (nonatomic ,copy ,readonly) NSDictionary * propertyInfos;

@property (nonatomic ,strong) NSDictionary * databaseMap;

@property (nonatomic ,strong) NSMutableArray * validKeys;

@property (nonatomic ,strong) NSMutableArray * arguments;

@property (nonatomic ,strong) NSMutableArray * conditionStrings;

@end

@implementation DWDatabaseCondition
#pragma mark --- interface method ---
-(NSString *)conditionString {
    if (!_conditionString) {
        [self make];
    }
    return _conditionString;
}

-(void)make {
    [self.validKeys removeAllObjects];
    NSMutableArray * conditionStrings = @[].mutableCopy;
    [self.conditionKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray * values = [self conditionValuesWithKey:obj];
        
        if (!values.count) {
            return ;
        }
        
        NSString * conditionString = [self conditioinStringWithKey:obj valueCount:values.count];
        
        if (!conditionString) {
            return ;
        }
        
        NSString * tblName = nil;
        if ([obj isEqualToString:kUniqueID]) {
            tblName = kUniqueID;
        } else {
            DWPrefix_YYClassPropertyInfo * property = self.maker.propertyInfos[obj];
            tblName = propertyInfoTblName(property, self.maker.databaseMap);
        }
        

        if (!tblName.length) {
            return;
        }

        [self.validKeys addObject:tblName];
        ///Null不需要添加参数
        if (self.relation != DWDatabaseValueRelationIsNull && self.relation != DWDatabaseValueRelationNotNull) {
            [self.arguments addObjectsFromArray:values];
        }
        [conditionStrings addObject:conditionString];

    }];
    if (conditionStrings.count) {
        _conditionString = [conditionStrings componentsJoinedByString:@" AND "];
    } else {
        _conditionString = @"";
    }
}

-(DWDatabaseConditionMaker *)and {
    self.maker.conditionOperator = DWDatabaseConditionLogicalOperatorAnd;
    return self.maker;
}

-(DWDatabaseConditionMaker *)or {
    self.maker.conditionOperator = DWDatabaseConditionLogicalOperatorOR;
    return self.maker;
}

-(DWDatabaseConditionCombine)combine {
    return ^(){
        ///combine时要保证至少有两个条件，且最后一个条件与上一个条件具有逻辑关系
        DWDatabaseOperateCondition * operateCondition = nil;
        if (self.maker.conditions.count > 1 && self.maker.conditions.lastObject.operateCondition) {
            ///组合两个条件为一个逻辑运算条件，这里根据既定规则，相邻两个条件的逻辑关系是存储在后一个条件中的。所以逻辑运算条件中的表示两个条件的逻辑关系的值应从后者中取。
            operateCondition = [DWDatabaseOperateCondition new];
            operateCondition.maker = self.maker;
            DWDatabaseCondition * condition = self.maker.conditions.lastObject;
            operateCondition.conditionB = condition;
            operateCondition.combineOperator = condition.conditionOperator;
            ///这里为了保证逻辑清晰且不引起不必要的歧义，在保证所有逻辑关系复制给新的逻辑运算条件之后，应清除原条件的逻辑运算关系。
            condition.conditionOperator = DWDatabaseConditionLogicalOperatorNone;
            condition.operateCondition = nil;
            ///l原始条件中的逻辑关系复制完成后，即可从maker的condition中移除掉该条件。
            [self.maker.conditions removeLastObject];
            condition = self.maker.conditions.lastObject;
            operateCondition.conditionA = condition;
            ///这里要将conditionA之前的逻辑关系复制给新的逻辑运算条件，保证这个逻辑链的正确性不变
            operateCondition.conditionOperator = condition.conditionOperator;
            operateCondition.operateCondition = condition.operateCondition;
            condition.conditionOperator = DWDatabaseConditionLogicalOperatorNone;
            condition.operateCondition = nil;
            [self.maker.conditions removeLastObject];
            ///新的逻辑条件配置完成后，将新的条件添加至逻辑条件数组，完成条件组合
            [self.maker.conditions addObject:operateCondition];
            return operateCondition;
        } else {
            return operateCondition;
        }
    };
}

#pragma mark --- tool method ---
-(NSString *)conditioinStringWithKey:(NSString *)key valueCount:(NSInteger)valueCount {
    ///如果在属性列表中或者是dw_id都视为合法
    if (![self.maker.propertyInfos.allKeys containsObject:key] && ![key isEqualToString:kUniqueID]) {
        return nil;
    }
    switch (self.relation) {
        case DWDatabaseValueRelationEqual:
            return [NSString stringWithFormat:@"%@ = ?",key];
        case DWDatabaseValueRelationNotEqual:
            return [NSString stringWithFormat:@"%@ != ?",key];
        case DWDatabaseValueRelationGreater:
            return [NSString stringWithFormat:@"%@ > ?",key];
        case DWDatabaseValueRelationLess:
            return [NSString stringWithFormat:@"%@ < ?",key];
        case DWDatabaseValueRelationGreaterOrEqual:
            return [NSString stringWithFormat:@"%@ >= ?",key];
        case DWDatabaseValueRelationLessOrEqual:
            return [NSString stringWithFormat:@"%@ <= ?",key];
        case DWDatabaseValueRelationInValues:
        {
            if (valueCount > 0) {
                NSString * tmp = [NSString stringWithFormat:@"%@ IN (",key];
                for (int i = 0; i < valueCount; ++i) {
                    tmp = [tmp stringByAppendingString:@"?,"];
                }
                tmp = [tmp substringToIndex:tmp.length - 1];
                tmp = [tmp stringByAppendingString:@")"];
                return tmp;
            }
            return nil;
        }
        case DWDatabaseValueRelationNotInValues:
        {
            if (valueCount > 0) {
                NSString * tmp = [NSString stringWithFormat:@"%@ NOT IN (",key];
                for (int i = 0; i < valueCount; ++i) {
                    tmp = [tmp stringByAppendingString:@"?,"];
                }
                tmp = [tmp substringToIndex:tmp.length - 1];
                tmp = [tmp stringByAppendingString:@")"];
                return tmp;
            }
            return nil;
        }
        case DWDatabaseValueRelationLike:
            return [NSString stringWithFormat:@"%@ LIKE ?",key];
        case DWDatabaseValueRelationBetween:
            return [NSString stringWithFormat:@"%@ BETWEEN ? AND ?",key];
        case DWDatabaseValueRelationIsNull:
            return [NSString stringWithFormat:@"%@ IS NULL",key];
        case DWDatabaseValueRelationNotNull:
            return [NSString stringWithFormat:@"%@ IS NOT NULL",key];
        default:
            return nil;
    }
}

-(NSArray *)conditionValuesWithKey:(NSString *)key {
    if (!self.value || !key.length) {
        return nil;
    }
    switch (self.relation) {
        case DWDatabaseValueRelationBetween:
        {
            if ([self.value isKindOfClass:[NSValue class]]) {
                if (strcmp([self.value objCType], @encode(DWBetweenFloatValue)) == 0) {
                    DWBetweenFloatValue betweenValue;
                    [self.value getValue:&betweenValue];
                    return @[@(betweenValue.start),@(betweenValue.end)];
                } else if (strcmp([self.value objCType], @encode(DWBetweenIntegerValue)) == 0) {
                    DWBetweenIntegerValue betweenValue;
                    [self.value getValue:&betweenValue];
                    return @[@(betweenValue.start),@(betweenValue.end)];
                } else {
                    return nil;
                }
            }
            return nil;
        }
        case DWDatabaseValueRelationInValues:
        case DWDatabaseValueRelationNotInValues:
        {
            if ([self.value isKindOfClass:[NSArray class]] && [self.value count] > 0) {
                return self.value;
            }
            return nil;
        }
        default:
        {
            id value = nil;
            ///转换成number
            if ([key isEqualToString:kUniqueID]) {
                value = transformValueWithType(self.value, DWPrefix_YYEncodingTypeObject, DWPrefix_YYEncodingTypeNSNumber);
            } else {
                ///尝试做自动类型转换
                DWPrefix_YYClassPropertyInfo * propertyInfo = self.maker.propertyInfos[key];
                value = transformValueWithPropertyInfo(self.value, propertyInfo);
            }
            
            if (value) {
                return @[value];
            }
            return nil;
        }
            
    }
}


#pragma mark --- override ---
-(NSString *)description {
    NSString * superDes = [super description];
    return [NSString stringWithFormat:@"%@ Keys:%@ Relation:%ld Value:%@",superDes,self.conditionKeys,(unsigned long)self.relation,self.value];
}

#pragma mark --- setter/getteer ---
-(NSMutableArray *)conditionKeys {
    if (!_conditionKeys) {
        _conditionKeys = @[].mutableCopy;
    }
    return _conditionKeys;
}

-(NSMutableArray<NSString *> *)validKeys {
    if (!_validKeys) {
        _validKeys = @[].mutableCopy;
    }
    return _validKeys;
}

-(NSMutableArray *)arguments {
    if (!_arguments) {
        _arguments = @[].mutableCopy;
    }
    return _arguments;
}

@end

@implementation DWDatabaseOperateCondition
#pragma mark --- override ---
-(NSString *)conditionString {
    if (!_conditionString) {
        [self make];
    }
    return _conditionString;
}

-(void)make {
    [self.validKeys removeAllObjects];
    NSString * conditionString1 = self.conditionA.conditionString;
    NSString * conditionString2 = self.conditionB.conditionString;
    if (conditionString1.length && conditionString2.length) {
        [self.validKeys addObjectsFromArray:self.conditionA.validKeys];
        [self.validKeys addObjectsFromArray:self.conditionA.validKeys];
        [self.arguments addObjectsFromArray:self.conditionA.arguments];
        [self.arguments addObjectsFromArray:self.conditionB.arguments];
        _conditionString = [NSString stringWithFormat:@"(%@ %@ %@)",conditionString1,self.combineOperator == DWDatabaseConditionLogicalOperatorAnd?@"AND":@"OR",conditionString2];
    } else {
        _conditionString = @"";
    }
}

-(NSString *)description {
    NSString * superDes = [NSString stringWithFormat:@"<%@: %p>",NSStringFromClass([self class]),self];
    return [NSString stringWithFormat:@"%@ (%@ %@ %@)",superDes,self.conditionA,(self.combineOperator == DWDatabaseConditionLogicalOperatorAnd)?@"AND":@"OR",self.conditionB];
}

@end

@implementation DWDatabaseConditionMaker

#pragma mark --- interface method ---

-(DWDatabaseConditionClass)loadClass {
    return ^(Class class) {
        NSLog(@"Initialize maker with class:%@",NSStringFromClass(class));
        self.clazz = class;
        return self;
    };
}

-(DWDatabaseConditionKey)conditionWith {
    return ^(NSString * key) {
        NSLog(@"Append a condition key:%@",key);
        [self.currentCondition.conditionKeys addObject:key];
        return self;
    };
}

-(DWDatabaseConditionValue)equalTo {
    return ^(id value) {
        NSLog(@"Setup condition with an equal value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationEqual);
    };
}

-(DWDatabaseConditionValue)notEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with an not equal value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationNotEqual);
    };
}

-(DWDatabaseConditionValue)greaterThan {
    return ^(id value) {
        NSLog(@"Setup condition with a greater value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationGreater);
    };
}

-(DWDatabaseConditionValue)lessThan {
    return ^(id value) {
        NSLog(@"Setup condition with a less value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationLess);
    };
}

-(DWDatabaseConditionValue)greaterThanOrEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with a greater or equal value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationGreaterOrEqual);
    };
}

-(DWDatabaseConditionValue)lessThanOrEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with a less or equal value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationLessOrEqual);
    };
}

-(DWDatabaseConditionValue)inValues {
    return ^(id value) {
        ///范围条件值为一个数组，如果不是转化成等于条件
        if (![value isKindOfClass:[NSArray class]]) {
            NSLog(@"Setup condition with a in values:%@,But the single value will be transform to equal value",value);
            return installCondition(self, value, DWDatabaseValueRelationEqual);
        } else {
            ///如果是数组且无元素，转化成无结果的条件
            NSArray * arrValue = value;
            if (arrValue.count == 0) {
                NSLog(@"Setup condition with a in values:%@,But the single value will be transform to error value with no result",value);
                return installCondition(self, arrValue, DWDatabaseValueRelationErrorNone);
            } else if (arrValue.count == 1) {
                ///如果是数组仅一个元素，转换成等于条件
                NSLog(@"Setup condition with a in values:%@,But the single value will be transform to equal value",value);
                return installCondition(self, arrValue.lastObject, DWDatabaseValueRelationEqual);
            } else {
                NSLog(@"Setup condition with a in values:%@",value);
                return installCondition(self, value, DWDatabaseValueRelationInValues);
            }
        }
    };
}

-(DWDatabaseConditionValue)notInValues {
    return ^(id value) {
        if (![value isKindOfClass:[NSArray class]]) {
            NSLog(@"Setup condition with a not in values:%@,But the single value will be transform to not equal value",value);
            return installCondition(self, value, DWDatabaseValueRelationNotEqual);
        } else {
            NSArray * arrValue = value;
            if (arrValue.count == 0) {
                ///如果是数组且无元素，转化成匹配所有结果的条件
                NSLog(@"Setup condition with a not in values:%@,But the empty value will be transform to error value which lead to all data",value);
                return installCondition(self, arrValue, DWDatabaseValueRelationErrorALL);
            } else if (arrValue.count == 1) {
                NSLog(@"Setup condition with a not in values:%@,But the single value will be transform to not equal value",value);
                return installCondition(self, arrValue.lastObject, DWDatabaseValueRelationNotEqual);
            } else {
                NSLog(@"Setup condition with a not in values:%@",value);
                return installCondition(self, value, DWDatabaseValueRelationNotInValues);
            }
        }
    };
}

-(DWDatabaseConditionValue)like {
    return ^(id value) {
        NSLog(@"Setup condition with a like value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationLike);
    };
}

-(DWDatabaseConditionValue)between {
    return ^(id value) {
        NSLog(@"Setup condition with a between value:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationBetween);
    };
}

-(DWDatabaseConditionVoidValue)isNull {
    return ^(void) {
        NSLog(@"Setup condition with a null value");
        return installCondition(self, [NSNull null], DWDatabaseValueRelationIsNull);
    };
}

-(DWDatabaseConditionVoidValue)notNull {
    return ^(void) {
        NSLog(@"Setup condition with a not null value");
        return installCondition(self, [NSNull null], DWDatabaseValueRelationNotNull);
    };
}

#pragma mark --- tool func ---
NS_INLINE DWDatabaseCondition * installCondition(DWDatabaseConditionMaker * maker,id value,DWDatabaseValueRelation relation) {
    if (!value) {
        NSLog(@"Attemp to create an invalid condition whose value is nil.");
        return maker.conditions.lastObject;
    }
    
    DWDatabaseCondition * conf = maker.currentCondition;
    switch (relation) {
        case DWDatabaseValueRelationErrorALL:
        {
            NSMutableArray * fixKeys = [NSMutableArray arrayWithCapacity:conf.conditionKeys.count];
            while (fixKeys.count < conf.conditionKeys.count) {
                [fixKeys addObject:@"1"];
            }
            conf.conditionKeys = fixKeys;
            conf.value = @"1";
            conf.relation = DWDatabaseValueRelationEqual;
            conf.maker = maker;
        }
            break;
        case DWDatabaseValueRelationErrorNone:
        {
            NSMutableArray * fixKeys = [NSMutableArray arrayWithCapacity:conf.conditionKeys.count];
            while (fixKeys.count < conf.conditionKeys.count) {
                [fixKeys addObject:kUniqueID];
            }
            conf.conditionKeys = fixKeys;
            conf.value = @"0";
            conf.relation = DWDatabaseValueRelationEqual;
            conf.maker = maker;
        }
            break;
        default:
        {
            conf.value = value;
            conf.relation = relation;
            conf.maker = maker;
        }
            break;
    }
    [maker.conditions addObject:conf];
    maker.currentCondition = nil;
    ///如果当前maker包含逻辑运算状态，代表当前条件是与上一个条件存在逻辑关系，则将逻辑关系及上一个条件保存在当前条件中，当调用combine时根据就近原则组合最后两个具有逻辑关系的条件
    if (maker.conditionOperator != DWDatabaseConditionLogicalOperatorNone) {
        conf.conditionOperator = maker.conditionOperator;
        conf.operateCondition = maker.conditions.lastObject;
        maker.conditionOperator = DWDatabaseConditionLogicalOperatorNone;
    }
    return conf;
}

#pragma mark --- override ---
-(NSString *)description {
    NSString * superDes = [super description];
    return [NSString stringWithFormat:@"%@ Conditions:%@",superDes,self.conditions];
}

#pragma mark --- setter/getter ---
-(NSMutableArray *)conditions {
    if (!_conditions) {
        _conditions = [NSMutableArray array];
    }
    return _conditions;
}

-(DWDatabaseCondition *)currentCondition {
    if (!_currentCondition) {
        _currentCondition = [DWDatabaseCondition new];
    }
    return _currentCondition;
}

@end

@implementation DWDatabaseConditionMaker (Private)

-(void)configWithPropertyInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)propertyInfos databaseMap:(nonnull NSDictionary *)databaseMap {
    _propertyInfos = [propertyInfos copy];
    _databaseMap = [databaseMap copy];
}

-(void)make {
    self.validKeys = nil;
    self.arguments = nil;
    self.conditionStrings = nil;
    __block BOOL initialized = NO;
    [self.conditions enumerateObjectsUsingBlock:^(DWDatabaseCondition * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj make];
        if (obj.conditionString.length) {
            if (!initialized) {
                initialized = YES;
                self.validKeys = @[].mutableCopy;
                self.arguments = @[].mutableCopy;
                self.conditionStrings = @[].mutableCopy;
            }
            [self.conditionStrings addObject:obj.conditionString];
            [self.arguments addObjectsFromArray:obj.arguments];
            [self.validKeys addObjectsFromArray:obj.validKeys];
        }
    }];
    
    ///转一手，保证顺序为系统默认顺序（相当于排序了）
    if (self.validKeys) {
        self.validKeys = [[NSSet setWithArray:self.validKeys].allObjects mutableCopy];
    }
}

-(NSArray *)fetchValidKeys {
    return [self.validKeys copy];
}

-(NSArray *)fetchConditions {
    return [self.conditionStrings copy];
}

-(NSArray *)fetchArguments {
    return [self.arguments copy];
}

-(Class)fetchQueryClass {
    return self.clazz;
}

@end

@implementation DWDatabaseConditionMaker (AutoTip)
@dynamic dw_loadClass,dw_conditionWith;

@end
