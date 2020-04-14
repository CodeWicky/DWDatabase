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
#import "DWDatabaseConditionMaker+Private.h"

@implementation DWDatabaseCondition
#pragma mark --- interface method ---
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
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationEqual];
    };
}

-(DWDatabaseConditionValue)notEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with an not equal value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationNotEqual];
    };
}

-(DWDatabaseConditionValue)greaterThan {
    return ^(id value) {
        NSLog(@"Setup condition with a greater value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationGreater];
    };
}

-(DWDatabaseConditionValue)lessThan {
    return ^(id value) {
        NSLog(@"Setup condition with a less value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationLess];
    };
}

-(DWDatabaseConditionValue)greaterThanOrEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with a greater or equal value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationGreaterOrEqual];
    };
}

-(DWDatabaseConditionValue)lessThanOrEqualTo {
    return ^(id value) {
        NSLog(@"Setup condition with a less or equal value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationLessOrEqual];
    };
}

-(DWDatabaseConditionValue)inValues {
    return ^(id value) {
        ///范围条件值为一个数组，如果不是转化成等于条件
        if (![value isKindOfClass:[NSArray class]]) {
            NSLog(@"Setup condition with a in values:%@,But the single value will be transform to equal value",value);
            return [self installConditionWithValue:value relation:DWDatabaseValueRelationEqual];
        } else {
            ///如果是数组且无元素，转化成无结果的条件
            NSArray * arrValue = value;
            if (arrValue.count == 0) {
                NSLog(@"Setup condition with a in values:%@,But the single value will be transform to error value with no result",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationErrorNone];
            } else if (arrValue.count == 1) {
                ///如果是数组仅一个元素，转换成等于条件
                NSLog(@"Setup condition with a in values:%@,But the single value will be transform to equal value",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationEqual];
            } else {
                NSLog(@"Setup condition with a in values:%@",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationInValues];
            }
        }
    };
}

-(DWDatabaseConditionValue)notInValues {
    return ^(id value) {
        if (![value isKindOfClass:[NSArray class]]) {
            NSLog(@"Setup condition with a not in values:%@,But the single value will be transform to not equal value",value);
            return [self installConditionWithValue:value relation:DWDatabaseValueRelationNotEqual];
        } else {
            NSArray * arrValue = value;
            if (arrValue.count == 0) {
                ///如果是数组且无元素，转化成匹配所有结果的条件
                NSLog(@"Setup condition with a not in values:%@,But the empty value will be transform to error value which lead to all data",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationErrorALL];
            } else if (arrValue.count == 1) {
                NSLog(@"Setup condition with a not in values:%@,But the single value will be transform to not equal value",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationNotEqual];
            } else {
                NSLog(@"Setup condition with a not in values:%@",value);
                return [self installConditionWithValue:value relation:DWDatabaseValueRelationNotInValues];
            }
        }
    };
}

-(DWDatabaseConditionValue)like {
    return ^(id value) {
        NSLog(@"Setup condition with a like value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationLike];
    };
}

-(DWDatabaseConditionValue)between {
    return ^(id value) {
        NSLog(@"Setup condition with a between value:%@",value);
        return [self installConditionWithValue:value relation:DWDatabaseValueRelationBetween];
    };
}

-(DWDatabaseConditionVoidValue)isNull {
    return ^(void) {
        NSLog(@"Setup condition with a null value");
        return [self installConditionWithValue:[NSNull null] relation:DWDatabaseValueRelationIsNull];
    };
}

-(DWDatabaseConditionVoidValue)notNull {
    return ^(void) {
        NSLog(@"Setup condition with a not null value");
        return [self installConditionWithValue:[NSNull null] relation:DWDatabaseValueRelationNotNull];
    };
}

@end

@implementation DWDatabaseConditionMaker (AutoTip)
@dynamic dw_loadClass,dw_conditionWith;

@end
