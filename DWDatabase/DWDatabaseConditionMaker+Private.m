//
//  DWDatabaseConditionMaker+Private.m
//  DWDatabase
//
//  Created by Wicky on 2020/4/14.
//

#import "DWDatabaseConditionMaker+Private.h"
#import <objc/runtime.h>
#import "DWDatabaseMacro.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase.h"
#import "DWDatabase+Private.h"

#define DWDatabaseLazyValue(key,cls,method) \
({\
    NSMutableDictionary * ctn = self.propertiesCtn;\
    cls * ret = ctn[@#key];\
    if (!ret) {\
        ret = [cls method];\
        ctn[@#key] = ret;\
    }\
    @selector(key),ret;\
})

#define DWDatabaseLazyNewValue(key,cls) DWDatabaseLazyValue(key,cls,new)

#define DWDatabaseSetValue(value) (self.propertiesCtn[@#value] = value)

#define DWDatabaseSetNumberValue(value) (self.propertiesCtn[@#value] = @(value))

#define DWDatabaseGetValue(key) (@selector(key),self.propertiesCtn[@#key])

@interface DWDatabaseConditionValueWrapper : NSObject

@property (nonatomic ,strong) DWPrefix_YYClassPropertyInfo * propertyInfo;

@property (nonatomic ,strong) id value;

@property (nonatomic ,assign) BOOL subProperty;

@property (nonatomic ,assign) BOOL multiValue;

@property (nonatomic ,assign ,readonly) NSInteger valueCount;

@property (nonatomic ,copy) NSString * tblName;

@property (nonatomic ,copy) NSString * fieldName;

@property (nonatomic ,copy) NSString * key;

@end

@implementation DWDatabaseConditionValueWrapper

-(NSInteger)valueCount {
    if (self.multiValue && [self.value isKindOfClass:[NSArray class]]) {
        return [self.value count];
    }
    return 1;
}

@end

@interface DWDatabaseCondition ()

@property (nonatomic ,strong) NSMutableDictionary * propertiesCtn;

@property (nonatomic ,copy) NSString * conditionString;

@property (nonatomic ,assign) DWDatabaseValueRelation relation;

@property (nonatomic ,strong) id value;

@end

@interface DWDatabaseConditionMaker ()

@property (nonatomic ,strong) NSMutableDictionary * propertiesCtn;

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

@end

@implementation DWDatabaseConditionMaker (Private)

#pragma mark --- interface method ---
-(void)configWithTblName:(NSString *)tblName propertyInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)propertyInfos databaseMap:(NSDictionary *)databaseMap enableSubProperty:(BOOL)enableSubProperty {
    self.tblName = tblName;
    self.propertyInfos = [propertyInfos copy];
    self.databaseMap = [databaseMap copy];
    self.subPropertyEnabled = enableSubProperty;
}

-(void)make {
    self.validKeys = nil;
    self.arguments = nil;
    self.conditionStrings = nil;
    self.joinTables = nil;
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

-(DWDatabaseBindKeyWrapperContainer)fetchBindKeys {
    if (self.bindKeyWrappers) {
        return self.bindKeyWrappers;
    }
    NSMutableDictionary * tmpDic = [NSMutableDictionary dictionaryWithCapacity:0];
    [self.bindKeys enumerateObjectsUsingBlock:^(DWDatabaseBindKeyWrapper * _Nonnull wrapper, NSUInteger idx, BOOL * _Nonnull stop) {
        [wrapper.bindKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.length) {
                DWDatabaseBindKeyWrapper * tmp = [wrapper copy];
                tmp.key = obj;
                [tmpDic setObject:tmp forKey:obj];
            }
        }];
    }];
    self.bindKeyWrappers = tmpDic;
    return self.bindKeyWrappers;
}

-(DWDatabaseCondition *)installConditionWithValue:(id)value relation:(DWDatabaseValueRelation)relation {
    return installCondition(self, value, relation);
}

-(void)reset {
    self.conditions = nil;
    self.currentCondition = nil;
    self.conditionOperator = DWDatabaseConditionLogicalOperatorNone;
    self.validKeys = nil;
    self.arguments = nil;
    self.joinTables = nil;
    self.conditionStrings = nil;
    self.inlineTblNameMap = nil;
    self.inlineTblDataBaseMap = nil;
    self.inlineTblMapCtn = nil;
    self.bindKeys = nil;
    self.bindKeyWrappers = nil;
    self.hasSubProperty = NO;
}

#pragma mark --- tool func ---
DWDatabaseCondition * installCondition(DWDatabaseConditionMaker * maker,id value,DWDatabaseValueRelation relation) {
    if (!value) {
        NSLog(@"Attemp to create an invalid condition whose value is nil.");
        maker.currentCondition = nil;
        return maker.conditions.lastObject;
    }
    
    DWDatabaseCondition * condition = maker.currentCondition;
    switch (relation) {
        case DWDatabaseValueRelationErrorALL:
        {
            NSMutableArray * fixKeys = [NSMutableArray arrayWithCapacity:condition.conditionKeys.count];
            while (fixKeys.count < condition.conditionKeys.count) {
                [fixKeys addObject:@"1"];
            }
            condition.conditionKeys = fixKeys;
            condition.value = @"1";
            condition.relation = DWDatabaseValueRelationEqual;
            condition.maker = maker;
        }
            break;
        case DWDatabaseValueRelationErrorNone:
        {
            NSMutableArray * fixKeys = [NSMutableArray arrayWithCapacity:condition.conditionKeys.count];
            while (fixKeys.count < condition.conditionKeys.count) {
                [fixKeys addObject:kUniqueID];
            }
            condition.conditionKeys = fixKeys;
            condition.value = @"0";
            condition.relation = DWDatabaseValueRelationEqual;
            condition.maker = maker;
        }
            break;
        default:
        {
            condition.value = value;
            condition.relation = relation;
            condition.maker = maker;
        }
            break;
    }
    [maker.conditions addObject:condition];
    maker.currentCondition = nil;
    ///如果当前maker包含逻辑运算状态，代表当前条件是与上一个条件存在逻辑关系，则将逻辑关系及上一个条件保存在当前条件中，当调用combine时根据就近原则组合最后两个具有逻辑关系的条件
    if (maker.conditionOperator != DWDatabaseConditionLogicalOperatorNone) {
        condition.conditionOperator = maker.conditionOperator;
        condition.operateCondition = maker.conditions.lastObject;
        maker.conditionOperator = DWDatabaseConditionLogicalOperatorNone;
    }
    return condition;
}

#pragma mark --- override ---
-(NSString *)description {
    NSString * superDes = [super description];
    return [NSString stringWithFormat:@"%@ Conditions:%@",superDes,self.conditions];
}

#pragma mark --- setter/getter ---
-(DWDatabaseBindKeyWithWrappers)bindKeyWithWrappers {
    return ^(DWDatabaseBindKeyWrapperContainer wrappers) {
        if (wrappers.allKeys.count) {
            self.bindKeyWrappers = wrappers;
        }
        return self;
    };
}

-(NSMutableDictionary *)propertiesCtn {
    NSMutableDictionary * ctn = objc_getAssociatedObject(self, _cmd);
    if (!ctn) {
        ctn = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, _cmd, ctn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return ctn;
}

-(NSMutableArray<DWDatabaseCondition *> *)conditions {
    return DWDatabaseLazyValue(conditions, NSMutableArray, array);
}

-(void)setConditions:(NSMutableArray<DWDatabaseCondition *> *)conditions {
    DWDatabaseSetValue(conditions);
}

-(DWDatabaseCondition *)currentCondition {
    return DWDatabaseLazyNewValue(currentCondition, DWDatabaseCondition);
}

-(void)setCurrentCondition:(DWDatabaseCondition *)currentCondition {
    DWDatabaseSetValue(currentCondition);
}

-(Class)clazz {
    return DWDatabaseGetValue(clazz);
}

-(void)setClazz:(Class)clazz {
    DWDatabaseSetValue(clazz);
}

-(DWDatabaseConditionLogicalOperator)conditionOperator {
    return [DWDatabaseGetValue(conditionOperator) integerValue];
}

-(void)setConditionOperator:(DWDatabaseConditionLogicalOperator)conditionOperator {
    DWDatabaseSetNumberValue(conditionOperator);
}

-(NSString *)tblName {
    return DWDatabaseGetValue(tblName);
}

-(void)setTblName:(NSString *)tblName {
    DWDatabaseSetValue(tblName);
}

-(NSDictionary *)propertyInfos {
    return DWDatabaseGetValue(propertyInfos);
}

-(void)setPropertyInfos:(NSDictionary *)propertyInfos {
    DWDatabaseSetValue(propertyInfos);
}

-(NSDictionary *)databaseMap {
    return DWDatabaseGetValue(databaseMap);
}

-(void)setDatabaseMap:(NSDictionary *)databaseMap {
    DWDatabaseSetValue(databaseMap);
}

-(NSMutableArray *)validKeys {
    return DWDatabaseGetValue(validKeys);
}

-(void)setValidKeys:(NSMutableArray *)validKeys {
    DWDatabaseSetValue(validKeys);
}

-(NSMutableArray *)arguments {
    return DWDatabaseGetValue(arguments);
}

-(void)setArguments:(NSMutableArray *)arguments {
    DWDatabaseSetValue(arguments);
}

-(NSMutableArray *)conditionStrings {
    return DWDatabaseGetValue(conditionStrings);
}

-(void)setConditionStrings:(NSMutableArray *)conditionStrings {
    DWDatabaseSetValue(conditionStrings);
}

-(NSMutableSet *)joinTables {
    return DWDatabaseGetValue(joinTables);
}

-(void)setJoinTables:(NSMutableSet *)joinTables {
    DWDatabaseSetValue(joinTables);
}

-(BOOL)subPropertyEnabled {
    return [DWDatabaseGetValue(subPropertyEnabled) boolValue];
}

-(void)setSubPropertyEnabled:(BOOL)subPropertyEnabled {
    DWDatabaseSetNumberValue(subPropertyEnabled);
}

-(BOOL)hasSubProperty {
    return [DWDatabaseGetValue(hasSubProperty) boolValue];
}

-(void)setHasSubProperty:(BOOL)hasSubProperty {
    DWDatabaseSetNumberValue(hasSubProperty);
}

-(NSMutableDictionary *)inlineTblNameMap {
    return DWDatabaseLazyValue(inlineTblNameMap, NSMutableDictionary, dictionary);
}

-(void)setInlineTblNameMap:(NSMutableDictionary *)inlineTblNameMap {
    DWDatabaseSetValue(inlineTblNameMap);
}

-(NSMutableDictionary *)inlineTblMapCtn {
    return DWDatabaseLazyValue(inlineTblMapCtn, NSMutableDictionary, dictionary);
}

-(void)setInlineTblMapCtn:(NSMutableDictionary *)inlineTblMapCtn {
    DWDatabaseSetValue(inlineTblMapCtn);
}

-(NSMutableDictionary *)inlineTblDataBaseMap {
    return DWDatabaseLazyValue(inlineTblDataBaseMap, NSMutableDictionary, dictionary);
}

-(void)setInlineTblDataBaseMap:(NSMutableDictionary *)inlineTblDataBaseMap {
    DWDatabaseSetValue(inlineTblDataBaseMap);
}

-(DWDatabaseBindKeyWrapper *)currentBindKeyWrapper {
    return DWDatabaseGetValue(currentBindKeyWrapper);
}

-(void)setCurrentBindKeyWrapper:(DWDatabaseBindKeyWrapper *)currentBindKeyWrapper {
    DWDatabaseSetValue(currentBindKeyWrapper);
}

-(NSMutableArray *)bindKeys {
    return DWDatabaseLazyValue(bindKeys, NSMutableArray, array);
}

-(void)setBindKeys:(NSMutableArray *)bindKeys {
    DWDatabaseSetValue(bindKeys);
}

-(NSMutableDictionary *)bindKeyWrappers {
    return DWDatabaseGetValue(bindKeyWrappers);
}

-(void)setBindKeyWrappers:(NSMutableDictionary *)bindKeyWrappers {
    DWDatabaseSetValue(bindKeyWrappers);
}

@end

@implementation DWDatabaseCondition (Private)
@dynamic validKeys,arguments,joinTables;

-(void)make {
    [self.validKeys removeAllObjects];
    NSMutableArray * conditionStrings = @[].mutableCopy;
    __block BOOL hasSubProperty = self.maker.hasSubProperty;
    BOOL subPropertyEnabled = self.maker.subPropertyEnabled;
    
    ///不包含副属性的话，要先检测是否包含，包含的话就不用检测了。第一个condition就包含副属性的话，能优化后续条件的组装过程
    if (!subPropertyEnabled || hasSubProperty) {
        [self.conditionKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            DWDatabaseConditionValueWrapper * wrapper = [self conditionValuesWithKey:obj];
            if (!wrapper) {
                return ;
            }
            ///如果当前记录
            if (subPropertyEnabled && !hasSubProperty && wrapper.subProperty) {
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
        self.conditionString = [conditionStrings componentsJoinedByString:@" AND "];
    } else {
        self.conditionString = @"";
    }
    
    if (!self.maker.hasSubProperty && hasSubProperty) {
        self.maker.hasSubProperty = YES;
    }
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
                    if (self.maker.subPropertyEnabled && self.maker.clazz) {
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

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)propertiesCtn {
    NSMutableDictionary * ctn = objc_getAssociatedObject(self, _cmd);
    if (!ctn) {
        ctn = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, _cmd, ctn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return ctn;
}

-(NSString *)conditionString {
    NSString * ret = DWDatabaseGetValue(conditionString);
    if (!ret) {
        [self make];
        ret = DWDatabaseGetValue(conditionString);
    }
    return ret;
}

-(void)setConditionString:(NSString *)conditionString {
    DWDatabaseSetValue(conditionString);
}

-(NSMutableArray *)conditionKeys {
    return DWDatabaseLazyValue(conditionKeys, NSMutableArray, array);
}

-(void)setConditionKeys:(NSMutableArray<NSString *> *)conditionKeys {
    DWDatabaseSetValue(conditionKeys);
}

-(NSMutableArray<NSString *> *)validKeys {
    return DWDatabaseLazyValue(validKeys, NSMutableArray, array);
}

-(NSMutableArray *)arguments {
    return DWDatabaseLazyValue(arguments, NSMutableArray, array);
}

-(NSMutableSet *)joinTables {
    return DWDatabaseLazyValue(joinTables, NSMutableSet, set);
}

-(DWDatabaseValueRelation)relation {
    return [DWDatabaseGetValue(relation) integerValue];
}

-(void)setRelation:(DWDatabaseValueRelation)relation {
    DWDatabaseSetNumberValue(relation);
}

-(id)value {
    return DWDatabaseGetValue(value);
}

-(void)setValue:(id)value {
    DWDatabaseSetValue(value);
}

-(DWDatabaseConditionMaker *)maker {
    return DWDatabaseGetValue(maker);
}

-(void)setMaker:(DWDatabaseConditionMaker *)maker {
    DWDatabaseSetValue(maker);
}

-(DWDatabaseCondition *)operateCondition {
    return DWDatabaseGetValue(operateCondition);
}

-(void)setOperateCondition:(DWDatabaseCondition *)operateCondition {
    DWDatabaseSetValue(operateCondition);
}

-(DWDatabaseConditionLogicalOperator)conditionOperator {
    return [DWDatabaseGetValue(conditionOperator) integerValue];
}

-(void)setConditionOperator:(DWDatabaseConditionLogicalOperator)conditionOperator {
    DWDatabaseSetNumberValue(conditionOperator);
}

@end

@implementation DWDatabaseOperateCondition
#pragma mark --- override ---

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
        self.conditionString = [NSString stringWithFormat:@"(%@ %@ %@)",conditionString1,self.combineOperator == DWDatabaseConditionLogicalOperatorAnd?@"AND":@"OR",conditionString2];
    } else {
        self.conditionString = @"";
    }
}

-(NSString *)description {
    NSString * superDes = [NSString stringWithFormat:@"<%@: %p>",NSStringFromClass([self class]),self];
    return [NSString stringWithFormat:@"%@ (%@ %@ %@)",superDes,self.conditionA,(self.combineOperator == DWDatabaseConditionLogicalOperatorAnd)?@"AND":@"OR",self.conditionB];
}

@end

@implementation DWDatabaseBindKeyWrapper

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _recursively = YES;
    }
    return self;
}

-(id)copyWithZone:(NSZone *)zone {
    DWDatabaseBindKeyWrapper * copy = [[[self class] allocWithZone:zone] init];
    if (_bindKeys) {
        copy.bindKeys = [self.bindKeys mutableCopy];
    }
    copy.key = [self.key copy];
    copy.recursively = self.recursively;
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    DWDatabaseBindKeyWrapper * copy = [[[self class] allocWithZone:zone] init];
    if (_bindKeys) {
        copy.bindKeys = [self.bindKeys mutableCopy];
    }
    copy.key = [self.key mutableCopy];
    copy.recursively = self.recursively;
    return copy;
}

#pragma mark --- setter/getter ---
-(NSMutableArray<NSString *> *)bindKeys {
    if (!_bindKeys) {
        _bindKeys = [NSMutableArray arrayWithCapacity:0];
    }
    return _bindKeys;
}

@end
