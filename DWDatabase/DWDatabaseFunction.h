//
//  DWDatabaseFunction.h
//  DWDatabase
//
//  Created by Wicky on 2019/12/3.
//

#import <UIKit/UIKit.h>
#import "NSObject+PropertyInfo.h"

///获取键值转换表
NSDictionary * databaseMapFromClass(Class cls);

///获取property对应的表名
NSString * propertyInfoTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap);

///以propertyInfo生成对应字段信息
NSString * tblFieldStringFromPropertyInfo(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap);

///获取键值转换表
NSDictionary * inlineModelTblNameMapFromClass(Class cls);

///获取property对应的表名
NSString * inlineModelTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * tblNameMap,NSString * parentTblName,NSString * existTblName);

///支持存表的属性
BOOL supportSavingWithPropertyInfo(DWPrefix_YYClassPropertyInfo * property);
