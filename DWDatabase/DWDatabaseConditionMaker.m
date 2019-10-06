//
//  DWDatabaseConditionMaker.m
//  DWDatabase
//
//  Created by Wicky on 2019/9/30.
//

#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"

typedef NS_ENUM(NSUInteger, DWDatabaseValueRelation) {
    DWDatabaseValueRelationEqual,
    DWDatabaseValueRelationGreater,
    DWDatabaseValueRelationLess,
    DWDatabaseValueRelationGreaterOrEqual,
    DWDatabaseValueRelationLessOrEqual,
    DWDatabaseValueRelationInValues,
    DWDatabaseValueRelationNotInValues,
    DWDatabaseValueRelationLike,
    DWDatabaseValueRelationBetween,
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
        NSString * conditionString = [self conditioinStringWithKey:obj];
        NSArray * values = [self conditionValuesWithKey:obj];
        DWPrefix_YYClassPropertyInfo * property = self.maker.propertyInfos[obj];
        NSString * tblName = propertyInfoTblName(property, self.maker.databaseMap);
        if (conditionString && values.count && tblName.length) {
            [self.validKeys addObject:tblName];
            [self.arguments addObjectsFromArray:values];
            [conditionStrings addObject:conditionString];
        }
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
-(NSString *)conditioinStringWithKey:(NSString *)key {
    if (![self.maker.propertyInfos.allKeys containsObject:key]) {
        return nil;
    }
    switch (self.relation) {
        case DWDatabaseValueRelationEqual:
            return [NSString stringWithFormat:@"%@ = ?",key];
        case DWDatabaseValueRelationGreater:
            return [NSString stringWithFormat:@"%@ > ?",key];
        case DWDatabaseValueRelationLess:
            return [NSString stringWithFormat:@"%@ < ?",key];
        case DWDatabaseValueRelationGreaterOrEqual:
            return [NSString stringWithFormat:@"%@ >= ?",key];
        case DWDatabaseValueRelationLessOrEqual:
            return [NSString stringWithFormat:@"%@ <= ?",key];
        case DWDatabaseValueRelationInValues:
            return [NSString stringWithFormat:@"%@ IN ?",key];
        case DWDatabaseValueRelationNotInValues:
            return [NSString stringWithFormat:@"%@ NOT IN ?",key];
        case DWDatabaseValueRelationLike:
            return [NSString stringWithFormat:@"%@ LIKE ?",key];
        case DWDatabaseValueRelationBetween:
            return [NSString stringWithFormat:@"%@ BETWEEN ? AND ?",key];
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
                return @[[NSString stringWithFormat:@"('%@')",[(NSArray *)self.value componentsJoinedByString:@"','"]]];
            }
            return nil;
        }
        default:
        {
            ///尝试做自动类型转换
            DWPrefix_YYClassPropertyInfo * propertyInfo = self.maker.propertyInfos[key];
            id value = transformValueWithPropertyInfo(self.value, propertyInfo);
            if (value) {
                return @[value];
            }
            return nil;
        }
            
    }
}

#pragma mark --- tool func ---
NS_INLINE id transformValueWithPropertyInfo(id value,DWPrefix_YYClassPropertyInfo * property) {
    switch (property.type & DWPrefix_YYEncodingTypeMask) {
        case DWPrefix_YYEncodingTypeBool:
        case DWPrefix_YYEncodingTypeInt8:
        case DWPrefix_YYEncodingTypeUInt8:
        case DWPrefix_YYEncodingTypeInt16:
        case DWPrefix_YYEncodingTypeUInt16:
        case DWPrefix_YYEncodingTypeInt32:
        case DWPrefix_YYEncodingTypeUInt32:
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            if ([value isEqual:[NSNull null]]) {
                return @(NAN);
            } else if ([value isKindOfClass:[NSNumber class]]) {
                return value;
            } else if ([value isKindOfClass:[NSString class]]) {
                if ([value containsString:@"."]) {
                    return @([value floatValue]);
                } else {
                    return @([value integerValue]);
                }
            } else {
                return nil;
            }
        }
        ///不支持NAN
        case DWPrefix_YYEncodingTypeInt64:
        case DWPrefix_YYEncodingTypeUInt64:
        {
            if ([value isEqual:[NSNull null]]) {
                return @(0);
            } else if ([value isKindOfClass:[NSNumber class]]) {
                return value;
            } else if ([value isKindOfClass:[NSString class]]) {
                if ([value containsString:@"."]) {
                    return @([value floatValue]);
                } else {
                    return @([value integerValue]);
                }
            } else {
                return nil;
            }
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                {
                    if ([value isKindOfClass:[NSString class]]) {
                        return [value copy];
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        return [value stringValue];
                    } else if ([value isKindOfClass:[NSData class]]) {
                        return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                    } else if ([value isKindOfClass:[NSDate class]]) {
                        return [dateFormatter() stringFromDate:value];
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        return [value absoluteString];
                    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                        NSData * dV = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
                        if (!dV) {
                            return nil;
                        }
                        return [[NSString alloc] initWithData:dV encoding:NSUTF8StringEncoding];
                    } else if ([value isKindOfClass:[NSSet class]]) {
                        NSData * dV = [NSJSONSerialization dataWithJSONObject:[value allObjects] options:0 error:nil];
                        if (!dV) {
                            return nil;
                        }
                        return [[NSString alloc] initWithData:dV encoding:NSUTF8StringEncoding];
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    if ([value isEqual:[NSNull null]]) {
                        return @(NAN);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        return value;
                    } else if ([value isKindOfClass:[NSString class]]) {
                        if ([value containsString:@"."]) {
                            return @([value floatValue]);
                        } else {
                            return @([value integerValue]);
                        }
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSData:
                case DWPrefix_YYEncodingTypeNSMutableData:
                {
                    if ([value isKindOfClass:[NSData class]]) {
                        return [value copy];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        return [value dataUsingEncoding:NSUTF8StringEncoding];
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSDate:
                {
                    if ([value isKindOfClass:[NSDate class]]) {
                        return [dateFormatter() stringFromDate:value];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        if ([dateFormatter() dateFromString:value]) {
                            return value;
                        } else {
                            return nil;
                        }
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    if ([value isKindOfClass:[NSURL class]]) {
                        return [value absoluteString];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        return value;
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSArray:
                case DWPrefix_YYEncodingTypeNSMutableArray:
                case DWPrefix_YYEncodingTypeNSDictionary:
                case DWPrefix_YYEncodingTypeNSMutableDictionary:
                case DWPrefix_YYEncodingTypeNSSet:
                case DWPrefix_YYEncodingTypeNSMutableSet:
                {
                    if ([value isEqual:[NSNull null]]) {
                        return nil;
                    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSSet class]]) {
                        if ([value isKindOfClass:[NSSet class]]) {
                            value = [value allObjects];
                        }
                        return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
                    } else if ([value isKindOfClass:[NSData class]] || [value isKindOfClass:[NSString class]]) {
                        id tmp = value;
                        if ([tmp isKindOfClass:[NSString class]]) {
                            tmp = [tmp dataUsingEncoding:NSUTF8StringEncoding];
                        }
                        id obj = [NSJSONSerialization JSONObjectWithData:tmp options:0 error:nil];
                        if (obj) {
                            return tmp;
                        } else {
                            return nil;
                        }
                    } else {
                        return nil;
                    }
                }
                default:
                    return nil;
            }
        }
        case DWPrefix_YYEncodingTypeClass:
        case DWPrefix_YYEncodingTypeSEL:
        case DWPrefix_YYEncodingTypeCString:
        {
            if ([value isKindOfClass:[NSString class]]) {
                return value;
            } else {
                return nil;
            }
        }
        default:
            return nil;
    }
}

///时间转换格式化
NS_INLINE NSDateFormatter *dateFormatter(){
    static NSDateFormatter * formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return formatter;
}

///获取property对应的表名
static NSString * propertyInfoTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap) {
    NSString * name = property.tblName;
    if (!name.length) {
        ///取出原字段名，若转换表中存在转换关系，则替换为转换名
        if ([databaseMap.allKeys containsObject:name]) {
            id mapped = [databaseMap valueForKey:name];
            if ([mapped isKindOfClass:[NSString class]]) {
                name = mapped;
            } else {
                name = property.name;
            }
        } else {
            name = property.name;
        }
        property.tblName = name;
    }
    return name;
}

#pragma mark --- override ---
-(NSString *)description {
    NSString * superDes = [super description];
    return [NSString stringWithFormat:@"%@ Keys:%@ Relation:%ld Value:%@",superDes,self.conditionKeys,self.relation,self.value];
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
        if (self.conditionA.validKeys.count > 1) {
            conditionString1 = [NSString stringWithFormat:@"(%@)",conditionString1];
        }
        
        if (self.conditionB.validKeys.count > 1) {
            conditionString2 = [NSString stringWithFormat:@"(%@)",conditionString2];
        }
        
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

#pragma mark --- test ---
-(void)test {
    [self make];
    NSLog(@"vk = %@",[self fetchValidKeys]);
    NSLog(@"a = %@",[self fetchArguments]);
    NSLog(@"c = %@",[self fetchConditions]);
}

#pragma mark --- interface method ---

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
        ///范围条件值为一个数组，如果不是数组则包装成一个数组
        if (![value isKindOfClass:[NSArray class]]) {
            value = @[value];
        }
        NSLog(@"Setup condition with a in values:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationInValues);
    };
}

-(DWDatabaseConditionValue)notInValues {
    return ^(id value) {
        ///范围条件值为一个数组，如果不是数组则包装成一个数组
        if (![value isKindOfClass:[NSArray class]]) {
            value = @[value];
        }
        NSLog(@"Setup condition with a not in values:%@",value);
        return installCondition(self, value, DWDatabaseValueRelationNotInValues);
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

#pragma mark --- tool func ---
NS_INLINE DWDatabaseCondition * installCondition(DWDatabaseConditionMaker * maker,id value,DWDatabaseValueRelation relation) {
    if (!value) {
        NSLog(@"Attemp to create an invalid condition whose value is nil.");
        return maker.conditions.lastObject;
    }
    
    DWDatabaseCondition * conf = maker.currentCondition;
    conf.value = value;
    conf.relation = relation;
    conf.maker = maker;
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
