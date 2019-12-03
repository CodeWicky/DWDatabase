//
//  DWDatabaseFunction.m
//  DWDatabase
//
//  Created by Wicky on 2019/12/3.
//

#import "DWDatabaseFunction.h"
#import "DWDatabase.h"

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

///以propertyInfo生成对应字段信息
NSString * tblFieldStringFromPropertyInfo(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap) {
    ///如果属性类型不在支持类型中，则返回nil
    if (!supportSavingWithPropertyInfo(property)) {
        return nil;
    }
    ///取出表字段名
    NSString * name = propertyInfoTblName(property, databaseMap);
    if (!name.length) {
        return nil;
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
            return [NSString stringWithFormat:@"%@ INTEGER",name];
        }
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            return [NSString stringWithFormat:@"%@ REAL",name];
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                case DWPrefix_YYEncodingTypeNSDate:
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    return [NSString stringWithFormat:@"%@ TEXT",name];
                }
                ///由于建表过程中NSNumber具体值尚未确定，无法推断出整形或浮点型，故此处统一转换为浮点型（因此不推荐使用NSNumber类型数据，建议直接使用基本类型数据）
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    return [NSString stringWithFormat:@"%@ REAL",name];
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
                    return [NSString stringWithFormat:@"%@ BLOB",name];
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
            return [NSString stringWithFormat:@"%@ TEXT",name];
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

