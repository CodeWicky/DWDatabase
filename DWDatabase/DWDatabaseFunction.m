//
//  DWDatabaseFunction.m
//  DWDatabase
//
//  Created by Wicky on 2019/12/3.
//

#import "DWDatabaseFunction.h"
#import "DWDatabase+Private.h"

///获取键值转换表
NSDictionary * databaseMapFromClass(Class cls) {
    NSDictionary * map = nil;
    if ([cls respondsToSelector:@selector(dw_modelKeyToDataBaseMap)]) {
        map = [cls dw_modelKeyToDataBaseMap];
    }
    return map;
}

///获取property对应的表名
NSString * propertyInfoTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap) {
    NSString * name = property.tblName;
    if (!name.length) {
        ///取出原字段名，若转换表中存在转换关系，则替换为转换名
        if ([databaseMap.allKeys containsObject:property.name]) {
            id mapped = [databaseMap valueForKey:property.name];
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

NSDictionary * databaseFieldDefaultValueMapFromClass(Class cls) {
    NSDictionary * map = nil;
    if ([cls respondsToSelector:@selector(dw_databaseFieldDefaultValueMap)]) {
        map = [cls dw_databaseFieldDefaultValueMap];
    }
    return map;
}

///以propertyInfo生成对应字段信息
NSString * tblFieldStringFromPropertyInfo(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap,NSDictionary * defaultValueMap) {
    ///如果属性类型不在支持类型中，则返回nil
    if (!supportSavingWithPropertyInfo(property)) {
        return nil;
    }
    ///取出表字段名
    NSString * name = propertyInfoTblName(property, databaseMap);
    if (!name.length) {
        return nil;
    }
    
    id value = nil;
    if (property.name.length && [defaultValueMap.allKeys containsObject:property.name]) {
        value = defaultValueMap[property.name];
        if (value) {
            value = transformValueWithType(value, property.type, property.nsType);
            if (value && [value isKindOfClass:[NSData class]]) {
                value = [[NSString alloc] initWithData:value encoding:(NSUTF8StringEncoding)];
            }
        }
    }

    ///根据不同类型分配不同的数据类型
    switch (property.type & DWPrefix_YYEncodingTypeMask) {
        case DWPrefix_YYEncodingTypeBool:
        case DWPrefix_YYEncodingTypeInt8:
        case DWPrefix_YYEncodingTypeUInt8:
        case DWPrefix_YYEncodingTypeInt16:
        case DWPrefix_YYEncodingTypeUInt16:
        case DWPrefix_YYEncodingTypeInt32:
        case DWPrefix_YYEncodingTypeUInt32:
        case DWPrefix_YYEncodingTypeInt64:
        case DWPrefix_YYEncodingTypeUInt64:
        {
            if (!value) {
                return [NSString stringWithFormat:@"%@ INTEGER",name];
            }
            return [NSString stringWithFormat:@"%@ INTEGER DEFAULT %@",name,[value stringValue]];
        }
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            if (!value) {
                return [NSString stringWithFormat:@"%@ REAL",name];
            }
            return [NSString stringWithFormat:@"%@ REAL DEFAULT %@",name,[value stringValue]];
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                case DWPrefix_YYEncodingTypeNSDate:
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    if (!value) {
                        return [NSString stringWithFormat:@"%@ TEXT",name];
                    }
                    return [NSString stringWithFormat:@"%@ TEXT DEFAULT '%@'",name,value];
                }
                ///由于建表过程中NSNumber具体值尚未确定，无法推断出整形或浮点型，故此处统一转换为浮点型（因此不推荐使用NSNumber类型数据，建议直接使用基本类型数据）
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    if (!value) {
                        return [NSString stringWithFormat:@"%@ REAL",name];
                    }
                    return [NSString stringWithFormat:@"%@ REAL DEFAULT %@",name,[value stringValue]];
                }
                case DWPrefix_YYEncodingTypeNSData:
                case DWPrefix_YYEncodingTypeNSMutableData:
                case DWPrefix_YYEncodingTypeNSArray:
                case DWPrefix_YYEncodingTypeNSMutableArray:
                case DWPrefix_YYEncodingTypeNSDictionary:
                case DWPrefix_YYEncodingTypeNSMutableDictionary:
                case DWPrefix_YYEncodingTypeNSSet:
                case DWPrefix_YYEncodingTypeNSMutableSet:
                {
                    if (!value) {
                        return [NSString stringWithFormat:@"%@ BLOB",name];
                    }
                    return [NSString stringWithFormat:@"%@ BLOB DEFAULT '%@'",name,value];
                }
                default:
                    ///此时考虑模型嵌套，直接以index保存另一张表中
                {
                    return [NSString stringWithFormat:@"%@ INTEGER",name];
                }
            }
        }
        case DWPrefix_YYEncodingTypeClass:
        case DWPrefix_YYEncodingTypeSEL:
        case DWPrefix_YYEncodingTypeCString:
        {
            if (!value) {
                return [NSString stringWithFormat:@"%@ TEXT",name];
            }
            return [NSString stringWithFormat:@"%@ TEXT DEFAULT '%@'",name,value];
        }
        default:
            break;
    }
    return nil;
}

///获取键值转换表
NSDictionary * inlineModelTblNameMapFromClass(Class cls) {
    NSDictionary * map = nil;
    if ([cls respondsToSelector:@selector(dw_inlineModelTableNameMap)]) {
        map = [cls dw_inlineModelTableNameMap];
    }
    return map;
}

///获取property对应的表名
NSString * inlineModelTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * tblNameMap,NSString * parentTblName,NSString * existTblName) {
    NSString * name = property.inlineModelTblName;
    if (!name.length) {
        ///取出原字段名，若转换表中存在转换关系，则替换为转换名
        if ([tblNameMap.allKeys containsObject:property.name]) {
            id mapped = [tblNameMap valueForKey:property.name];
            if ([mapped isKindOfClass:[NSString class]]) {
                name = mapped;
            } else {
                ///如果未指定inline表名，应该考虑当前是否存在同样模型对应表，如果存在，则返回该表名
                if (existTblName.length) {
                    name = existTblName;
                } else {
                    name = [parentTblName stringByAppendingFormat:@"_inline_%@_tbl",property.name];
                }
            }
        } else {
            if (existTblName.length) {
                name = existTblName;
            } else {
                name = [parentTblName stringByAppendingFormat:@"_inline_%@_tbl",property.name];
            }
        }
        property.inlineModelTblName = name;
    }
    return name;
}

///支持存表的属性
BOOL supportSavingWithPropertyInfo(DWPrefix_YYClassPropertyInfo * property) {
    static NSSet * supportSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportSet = [NSSet setWithObjects:
                      @(DWPrefix_YYEncodingTypeBool),
                      @(DWPrefix_YYEncodingTypeInt8),
                      @(DWPrefix_YYEncodingTypeUInt8),
                      @(DWPrefix_YYEncodingTypeInt16),
                      @(DWPrefix_YYEncodingTypeUInt16),
                      @(DWPrefix_YYEncodingTypeInt32),
                      @(DWPrefix_YYEncodingTypeUInt32),
                      @(DWPrefix_YYEncodingTypeInt64),
                      @(DWPrefix_YYEncodingTypeUInt64),
                      @(DWPrefix_YYEncodingTypeFloat),
                      @(DWPrefix_YYEncodingTypeDouble),
                      @(DWPrefix_YYEncodingTypeLongDouble),
                      @(DWPrefix_YYEncodingTypeObject),
                      @(DWPrefix_YYEncodingTypeClass),
                      @(DWPrefix_YYEncodingTypeSEL),
                      @(DWPrefix_YYEncodingTypeCString),nil];
    });
    return [supportSet containsObject:@(property.type)];
}

///时间转换格式化
NSDateFormatter *dateFormatter(){
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

id transformValueWithPropertyInfo(id value,DWPrefix_YYClassPropertyInfo * property) {
    return transformValueWithType(value, property.type, property.nsType);
}

id transformValueWithType(id value,DWPrefix_YYEncodingType encodingType,DWPrefix_YYEncodingNSType nsType) {
    switch (encodingType & DWPrefix_YYEncodingTypeMask) {
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
            switch (nsType) {
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

///获取两个数组的交集
NSArray * intersectionOfArray(NSArray * arr1,NSArray * arr2) {
    if (!arr1.count || !arr2.count) {
        return nil;
    } else {
        NSMutableSet * set1 = [NSMutableSet setWithArray:arr1];
        NSSet * set2 = [NSSet setWithArray:arr2];
        [set1 intersectSet:set2];
        if (!set1.count) {
            return nil;
        }
        return [set1 allObjects];
    }
}

NSArray * minusArray(NSArray * arr1,NSArray * arr2) {
    if (!arr1.count) {
        return nil;
    } else if (!arr2.count) {
        return arr1;
    } else {
        NSMutableSet * all = [NSMutableSet setWithArray:arr1];
        NSSet * black = [NSSet setWithArray:arr2];
        [all minusSet:black];
        if (!all.count) {
            return nil;
        }
        return [all allObjects];
    }
}

NSString * const dbErrorDomain = @"com.DWDatabase.error";
///快速生成NSError
NSError * errorWithMessage(NSString * msg,NSInteger code) {
    NSDictionary * userInfo = nil;
    if (msg.length) {
        userInfo = @{NSLocalizedDescriptionKey:msg};
    }
    return [NSError errorWithDomain:dbErrorDomain code:code userInfo:userInfo];
}

static const char * kAdditionalConfKey = "kAdditionalConfKey";
static NSString * const kDwIdKey = @"kDwIdKey";
static NSString * const kDbNameKey = @"kDbNameKey";
static NSString * const kTblNameKey = @"kTblNameKey";
///获取额外配置字典
NSMutableDictionary * additionalConfigFromModel(NSObject * model) {
    NSMutableDictionary * additionalConf = objc_getAssociatedObject(model, kAdditionalConfKey);
    if (!additionalConf) {
        additionalConf = [NSMutableDictionary dictionaryWithCapacity:0];
        objc_setAssociatedObject(model, kAdditionalConfKey, additionalConf, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return additionalConf;
}

///获取id
NSNumber * Dw_idFromModel(NSObject * model) {
    return [additionalConfigFromModel(model) valueForKey:kDwIdKey];
}

///设置id
void SetDw_idForModel(NSObject * model,NSNumber * dw_id) {
    [additionalConfigFromModel(model) setValue:dw_id forKey:kDwIdKey];
}

NSString * DbNameFromModel(NSObject * model) {
    return [additionalConfigFromModel(model) valueForKey:kDbNameKey];
}

void SetDbNameForModel(NSObject * model,NSString * dbName) {
    [additionalConfigFromModel(model) setValue:dbName forKey:kDbNameKey];
}

NSString * TblNameFromModel(NSObject * model) {
    return [additionalConfigFromModel(model) valueForKey:kTblNameKey];
}

void SetTblNameForModel(NSObject * model,NSString * tblName) {
    [additionalConfigFromModel(model) setValue:tblName forKey:kTblNameKey];
}

void excuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block) {
    if (!block) {
        return;
    }
    if (dispatch_get_specific(dbOpQKey)) {
        block();
    } else {
        dispatch_sync(db.dbOperationQueue, block);
    }
}

void asyncExcuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block) {
    if (!block) {
        return;
    }
    dispatch_async(db.dbOperationQueue, block);
}

NSArray * combineArrayWithExtraToSort(NSArray <NSString *>* array,NSArray <NSString *>* extra) {
    ///这里因为使用场景中，第一个数组为不关心排序的数组，故第一个数组直接添加，第二个数组排序后添加
    if (array.count + extra.count == 0) {
        return nil;
    }
    NSMutableArray * ctn = [NSMutableArray arrayWithCapacity:array.count + extra.count];
    if (array.count) {
        [ctn addObjectsFromArray:array];
    }
    
    if (extra.count) {
        extra = [extra sortedArrayUsingSelector:@selector(compare:)];
        [ctn addObjectsFromArray:extra];
    }
    
    return [ctn copy];
}
