//
//  DWDatabaseConditionMaker.m
//  DWDatabase
//
//  Created by Wicky on 2019/9/30.
//

#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabaseFunction.h"
#import <objc/runtime.h>
#import "DWDatabase+Private.h"

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

@property (nonatomic ,strong) NSString * tblName;

@property (nonatomic ,copy ,readonly) NSDictionary * propertyInfos;

@property (nonatomic ,strong) NSDictionary * databaseMap;

@property (nonatomic ,strong) NSMutableArray * validKeys;

@property (nonatomic ,strong) NSMutableArray * arguments;

@property (nonatomic ,strong) NSMutableArray * conditionStrings;

@property (nonatomic ,strong) NSMutableSet * joinTables;

@property (nonatomic ,assign) BOOL hasSubProperty;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblNameMap;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblMapCtn;

@property (nonatomic ,strong) NSMutableDictionary * inlineTblDataBaseMap;

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
    __block BOOL hasSubProperty = self.maker.hasSubProperty;
    
    ///不包含副属性的话，要先检测是否包含，包含的话就不用检测了。第一个condition就包含副属性的话，能优化后续条件的组装过程
    if (hasSubProperty) {
        [self.conditionKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            DWDatabaseConditionValueWrapper * wrapper = [self conditionValuesWithKey:obj];
            if (!wrapper) {
                return ;
            }
            ///如果当前记录
            if (!hasSubProperty && wrapper.subProperty) {
                hasSubProperty = YES;
            }
            wrapper.key = obj;
            
            NSString * conditionString = [self conditioinStringWithPropertyWrapper:wrapper valueCount:wrapper.valueCount hasSubProperty:hasSubProperty];
            
            if (!conditionString) {
                return ;
            }
            
            if (!wrapper.subProperty) {
                ///目前validKeys进查询的时候用，为了合并查询键值。所以这里如果是副属性，不添加至validKeys，因为查询的时候也用不到

                if (!wrapper.fieldName.length) {
                    return;
                }
                
                [self.validKeys addObject:wrapper.fieldName];
            }
            ///Null不需要添加参数
            if (self.relation != DWDatabaseValueRelationIsNull && self.relation != DWDatabaseValueRelationNotNull) {
                if (wrapper.multiValue) {
                    [self.arguments addObjectsFromArray:wrapper.value];
                } else {
                    [self.arguments addObject:wrapper.value];
                }
            }
            [conditionStrings addObject:conditionString];
        }];
    } else {
        NSMutableArray <DWDatabaseConditionValueWrapper *>* wrappers = @[].mutableCopy;
        ///现根据propertyValue的状态获取所有合法的value及对应的wrapper
        [self.conditionKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            DWDatabaseConditionValueWrapper * wrapper = [self conditionValuesWithKey:obj];
            if (!wrapper) {
                return ;
            }
            ///如果当前记录
            if (!hasSubProperty && wrapper.subProperty) {
                hasSubProperty = YES;
            }
            wrapper.key = obj;
            [wrappers addObject:wrapper];
        }];
        
        ///根据wrapper获取条件字符串
        [wrappers enumerateObjectsUsingBlock:^(DWDatabaseConditionValueWrapper * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString * conditionString = [self conditioinStringWithPropertyWrapper:obj valueCount:obj.valueCount hasSubProperty:hasSubProperty];
            
            if (!conditionString) {
                return ;
            }
            
            if (!obj.subProperty) {
                ///目前validKeys进查询的时候用，为了合并查询键值。所以这里如果是副属性，不添加至validKeys，因为查询的时候也用不到
                if (!obj.fieldName.length) {
                    return;
                }
                
                [self.validKeys addObject:obj.fieldName];
            }
            ///Null不需要添加参数
            if (self.relation != DWDatabaseValueRelationIsNull && self.relation != DWDatabaseValueRelationNotNull) {
                if (obj.multiValue) {
                    [self.arguments addObjectsFromArray:obj.value];
                } else {
                    [self.arguments addObject:obj.value];
                }
            }
            [conditionStrings addObject:conditionString];
        }];
    }
    
    if (conditionStrings.count) {
        _conditionString = [conditionStrings componentsJoinedByString:@" AND "];
    } else {
        _conditionString = @"";
    }
    
    if (!self.maker.hasSubProperty && hasSubProperty) {
        self.maker.hasSubProperty = YES;
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
-(NSString *)conditioinStringWithPropertyWrapper:(DWDatabaseConditionValueWrapper *)wrapper valueCount:(NSInteger)valueCount hasSubProperty:(BOOL)hasSubProperty  {
    if (!wrapper) {
        return nil;
    }

    NSString * fieldName = wrapper.fieldName;
    if (hasSubProperty) {
        fieldName = [wrapper.tblName stringByAppendingFormat:@".%@",fieldName];
    }
    
    switch (self.relation) {
        case DWDatabaseValueRelationEqual:
            return [NSString stringWithFormat:@"%@ = ?",fieldName];
        case DWDatabaseValueRelationNotEqual:
            return [NSString stringWithFormat:@"%@ != ?",fieldName];
        case DWDatabaseValueRelationGreater:
            return [NSString stringWithFormat:@"%@ > ?",fieldName];
        case DWDatabaseValueRelationLess:
            return [NSString stringWithFormat:@"%@ < ?",fieldName];
        case DWDatabaseValueRelationGreaterOrEqual:
            return [NSString stringWithFormat:@"%@ >= ?",fieldName];
        case DWDatabaseValueRelationLessOrEqual:
            return [NSString stringWithFormat:@"%@ <= ?",fieldName];
        case DWDatabaseValueRelationInValues:
        {
            if (valueCount > 0) {
                NSString * tmp = [NSString stringWithFormat:@"%@ IN (",fieldName];
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
                NSString * tmp = [NSString stringWithFormat:@"%@ NOT IN (",fieldName];
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
            return [NSString stringWithFormat:@"%@ LIKE ?",fieldName];
        case DWDatabaseValueRelationBetween:
            return [NSString stringWithFormat:@"%@ BETWEEN ? AND ?",fieldName];
        case DWDatabaseValueRelationIsNull:
            return [NSString stringWithFormat:@"%@ IS NULL",fieldName];
        case DWDatabaseValueRelationNotNull:
            return [NSString stringWithFormat:@"%@ IS NOT NULL",fieldName];
        default:
            return nil;
    }
}

-(DWDatabaseConditionValueWrapper *)conditionValuesWithKey:(NSString *)key {
    if (!self.value || !key.length) {
        return nil;
    }
    DWPrefix_YYClassPropertyInfo * propertyInfo = self.maker.propertyInfos[key];
    DWDatabaseConditionValueWrapper * wrapper = nil;
    NSString * fieldName = [self tblFieldNameForKey:key dataBaseMap:self.maker.databaseMap propertyInfo:propertyInfo];
    switch (self.relation) {
        case DWDatabaseValueRelationBetween:
        {
            if (!propertyInfo) {
                return nil;
            }
            wrapper = [DWDatabaseConditionValueWrapper new];
            wrapper.propertyInfo = propertyInfo;
            if ([self.value isKindOfClass:[NSValue class]]) {
                if (strcmp([self.value objCType], @encode(DWBetweenFloatValue)) == 0) {
                    DWBetweenFloatValue betweenValue;
                    [self.value getValue:&betweenValue];
                    wrapper.value = @[@(betweenValue.start),@(betweenValue.end)];
                    wrapper.multiValue = YES;
                    wrapper.tblName = self.maker.tblName;
                    wrapper.fieldName = fieldName;
                    return wrapper;
                } else if (strcmp([self.value objCType], @encode(DWBetweenIntegerValue)) == 0) {
                    DWBetweenIntegerValue betweenValue;
                    [self.value getValue:&betweenValue];
                    wrapper.value = @[@(betweenValue.start),@(betweenValue.end)];
                    wrapper.multiValue = YES;
                    wrapper.tblName = self.maker.tblName;
                    wrapper.fieldName = fieldName;
                    return wrapper;
                } else {
                    return nil;
                }
            }
            return nil;
        }
        case DWDatabaseValueRelationInValues:
        case DWDatabaseValueRelationNotInValues:
        {
            if (!propertyInfo) {
                return nil;
            }
            if ([self.value isKindOfClass:[NSArray class]] && [self.value count] > 0) {
                wrapper = [DWDatabaseConditionValueWrapper new];
                wrapper.propertyInfo = propertyInfo;
                wrapper.value = self.value;
                wrapper.multiValue = YES;
                wrapper.tblName = self.maker.tblName;
                wrapper.fieldName = fieldName;
                return wrapper;
            }
            return nil;
        }
        default:
        {
            ///转换成number
            if ([key isEqualToString:kUniqueID]) {
                DWDatabaseConditionValueWrapper * wrapper = [DWDatabaseConditionValueWrapper new];
                wrapper.value = transformValueWithType(self.value, DWPrefix_YYEncodingTypeObject, DWPrefix_YYEncodingTypeNSNumber);
                wrapper.tblName = self.maker.tblName;
                wrapper.fieldName = fieldName;
                return wrapper;
            } else {
                ///尝试做自动类型转换
                if (propertyInfo) {
                    ///一级属性
                    return [self valueWithPropertyInfo:propertyInfo subProperty:NO tblName:self.maker.tblName fieldName:fieldName];
                } else {
                    if (self.maker.clazz) {
                        ///二级属性
                        return [self subPropertyValueWithKey:key tblName:self.maker.tblName];
                    }
                    ///没有class的话，无法构建二级条件
                    return nil;
                }
            }
        }
    }
}

-(DWDatabaseConditionValueWrapper *)valueWithPropertyInfo:(DWPrefix_YYClassPropertyInfo *)propertyInfo subProperty:(BOOL)subPropertyInfo tblName:(NSString *)tblName fieldName:(NSString *)fieldName {
    DWDatabaseConditionValueWrapper * wrapper = [DWDatabaseConditionValueWrapper new];
    wrapper.propertyInfo = propertyInfo;
    wrapper.subProperty = subPropertyInfo;
    wrapper.tblName = tblName;
    wrapper.fieldName = fieldName;
    if (propertyInfo.type == DWPrefix_YYEncodingTypeObject && propertyInfo.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
        wrapper.value = transformValueWithType(self.value, DWPrefix_YYEncodingTypeObject, DWPrefix_YYEncodingTypeNSNumber);
    } else {
        wrapper.value = transformValueWithPropertyInfo(self.value, propertyInfo);
    }
    return wrapper;
}

-(DWDatabaseConditionValueWrapper *)subPropertyValueWithKey:(NSString *)key tblName:(NSString *)tblName {
    
    if (![self validateSubPropertyInfoKey:key]) {
        return nil;
    }
    
    NSArray * seperatedKeys = [self seperatePropertyKey:key];
    NSString * mainPropertyKey = seperatedKeys.firstObject;
    NSString * subPropertyKey = seperatedKeys.lastObject;
    
    DWPrefix_YYClassPropertyInfo * propertyInfo = self.maker.propertyInfos[mainPropertyKey];
    if (!propertyInfo) {
        return nil;
    }
    
    return [self subPropertyValueWithMainProperty:propertyInfo dataBaseMap:self.maker.databaseMap subPropertyKey:subPropertyKey tblName:tblName];
}

-(DWDatabaseConditionValueWrapper *)subPropertyValueWithMainProperty:(DWPrefix_YYClassPropertyInfo *)mainPropertyInfo dataBaseMap:(NSDictionary *)dataBaseMap subPropertyKey:(NSString *)subPropertyKey tblName:(NSString *)tblName {
    if (!mainPropertyInfo) {
        return nil;
    }
    if (!subPropertyKey.length) {
        return nil;
    }
    
    NSString * classkey = NSStringFromClass(mainPropertyInfo.cls);///此处取嵌套模型对应地表名
    NSDictionary * inlineTblNameMap = self.maker.inlineTblMapCtn[classkey];
    if (!inlineTblNameMap) {
        inlineTblNameMap = inlineModelTblNameMapFromClass(mainPropertyInfo.cls);
        self.maker.inlineTblMapCtn[classkey] = inlineTblNameMap;
    }
    
    NSString * inlineTblName = self.maker.inlineTblNameMap[classkey];
    if (!inlineTblName) {
        inlineTblName = inlineModelTblName(mainPropertyInfo, inlineTblNameMap, tblName,nil);
        self.maker.inlineTblNameMap[classkey] = inlineTblName;
    }
    
    if (!inlineTblName.length) {
        return nil;
    }
    
    NSString * joinFieldName = propertyInfoTblName(mainPropertyInfo, dataBaseMap);
    if (!joinFieldName.length) {
        return nil;
    }
    
    if ([subPropertyKey isEqualToString:kUniqueID]) {
        DWDatabaseConditionValueWrapper * wrapper = [DWDatabaseConditionValueWrapper new];
        wrapper.value = transformValueWithType(self.value, DWPrefix_YYEncodingTypeObject, DWPrefix_YYEncodingTypeNSNumber);
        wrapper.subProperty = YES;
        wrapper.tblName = inlineTblName;
        wrapper.fieldName = kUniqueID;
        [self.joinTables addObject:[NSString stringWithFormat:@"LEFT JOIN %@ ON %@.%@ = %@.%@",inlineTblName,inlineTblName,kUniqueID,tblName,joinFieldName]];
        return wrapper;
    }
    
    NSDictionary * subPropertyInfos = mainPropertyInfo.subPropertyInfos;
    if (!subPropertyInfos) {
        subPropertyInfos = [[DWDatabase shareDB] propertyInfosForSaveKeysWithClass:mainPropertyInfo.cls];
        mainPropertyInfo.subPropertyInfos = subPropertyInfos;
    }
    
    if (!subPropertyInfos) {
        return nil;
    }
    
    DWPrefix_YYClassPropertyInfo * propertyInfo = subPropertyInfos[subPropertyKey];
    dataBaseMap = self.maker.inlineTblDataBaseMap[classkey];
    if (!dataBaseMap) {
        dataBaseMap = databaseMapFromClass(mainPropertyInfo.cls);
        self.maker.inlineTblDataBaseMap[classkey] = dataBaseMap;
    }
    
    if (propertyInfo) {
        NSString * fieldName = propertyInfoTblName(propertyInfo, dataBaseMap);
        [self.joinTables addObject:[NSString stringWithFormat:@"LEFT JOIN %@ ON %@.%@ = %@.%@",inlineTblName,inlineTblName,kUniqueID,tblName,joinFieldName]];
        return [self valueWithPropertyInfo:propertyInfo subProperty:YES tblName:inlineTblName fieldName:fieldName];
    }
    
    if (![self validateSubPropertyInfoKey:subPropertyKey]) {
        return nil;
    }
    
    NSArray * seperatedKeys = [self seperatePropertyKey:subPropertyKey];
    NSString * mainPropertyKey = seperatedKeys.firstObject;
    subPropertyKey = seperatedKeys.lastObject;
    
    propertyInfo = subPropertyInfos[mainPropertyKey];
    if (!propertyInfo) {
        return nil;
    }
    [self.joinTables addObject:[NSString stringWithFormat:@"LEFT JOIN %@ ON %@.%@ = %@.%@",inlineTblName,inlineTblName,kUniqueID,tblName,joinFieldName]];
    return [self subPropertyValueWithMainProperty:propertyInfo dataBaseMap:dataBaseMap subPropertyKey:subPropertyKey tblName:inlineTblName];
}

-(BOOL)validateSubPropertyInfoKey:(NSString *)key {
    ///不包含子属性，所以不可能取到转换value
    if (![key containsString:@"."]) {
        return NO;
    }
    
    ///头部或尾部是点，也不是合法的子属性
    if ([key hasPrefix:@"."] || [key hasSuffix:@"."]) {
        return NO;
    }
    
    return YES;
}

-(NSArray <NSString *>*)seperatePropertyKey:(NSString *)key {
    NSArray * components = [key componentsSeparatedByString:@"."];
    NSString * mainPropertyKey = components.firstObject;
    NSString * subPropertyKey = [key substringFromIndex:mainPropertyKey.length + 1];
    return @[mainPropertyKey,subPropertyKey];
}

-(NSString *)tblFieldNameForKey:(NSString *)key dataBaseMap:(NSDictionary *)dataBaseMap propertyInfo:(DWPrefix_YYClassPropertyInfo *)propertyInfo {
    if (!key.length) {
        return nil;
    }
    if ([key isEqualToString:kUniqueID]) {
        return key;
    }
    
    return propertyInfoTblName(propertyInfo, dataBaseMap);
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

-(NSMutableSet *)joinTables {
    if (!_joinTables) {
        _joinTables = [NSMutableSet set];
    }
    return _joinTables;
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
        [self.joinTables addObjectsFromArray:[self.conditionA.joinTables allObjects]];
        [self.joinTables addObjectsFromArray:[self.conditionB.joinTables allObjects]];
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
        maker.currentCondition = nil;
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

-(NSMutableDictionary *)inlineTblNameMap {
    if (!_inlineTblNameMap) {
        _inlineTblNameMap = [NSMutableDictionary dictionary];
    }
    return _inlineTblNameMap;
}

-(NSMutableDictionary *)inlineTblMapCtn {
    if (!_inlineTblMapCtn) {
        _inlineTblMapCtn = [NSMutableDictionary dictionary];
    }
    return _inlineTblMapCtn;
}

-(NSMutableDictionary *)inlineTblDataBaseMap {
    if (_inlineTblDataBaseMap) {
        _inlineTblDataBaseMap = [NSMutableDictionary dictionary];
    }
    return _inlineTblDataBaseMap;
}

@end

@implementation DWDatabaseConditionMaker (Private)

-(void)configWithTblName:(NSString *)tblName propertyInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)propertyInfos databaseMap:(NSDictionary *)databaseMap {
    _tblName = tblName;
    _propertyInfos = [propertyInfos copy];
    _databaseMap = [databaseMap copy];
}

-(void)make {
    self.validKeys = nil;
    self.arguments = nil;
    self.conditionStrings = nil;
    self.inlineTblNameMap = nil;
    self.inlineTblDataBaseMap = nil;
    self.inlineTblMapCtn = nil;
    NSString * classString = NSStringFromClass(self.clazz);
    self.inlineTblDataBaseMap[classString] = self.databaseMap;
    self.inlineTblNameMap[classString] = self.tblName;
    __block BOOL initialized = NO;
    [self.conditions enumerateObjectsUsingBlock:^(DWDatabaseCondition * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj make];
        if (obj.conditionString.length) {
            if (!initialized) {
                initialized = YES;
                self.validKeys = @[].mutableCopy;
                self.arguments = @[].mutableCopy;
                self.conditionStrings = @[].mutableCopy;
                self.joinTables = [NSMutableSet set];
            }
            [self.conditionStrings addObject:obj.conditionString];
            [self.arguments addObjectsFromArray:obj.arguments];
            [self.validKeys addObjectsFromArray:obj.validKeys];
            [self.joinTables addObjectsFromArray:[obj.joinTables allObjects]];
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

-(NSArray *)fetchJoinTables {
    return [self.joinTables allObjects];
}

@end

@implementation DWDatabaseConditionMaker (AutoTip)
@dynamic dw_loadClass,dw_conditionWith;

@end
