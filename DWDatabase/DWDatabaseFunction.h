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

///时间转换格式化
NSDateFormatter *dateFormatter(void);

///根据对应的属性类型转换值
id transformValueWithPropertyInfo(id value,DWPrefix_YYClassPropertyInfo * property);

///根据对应的对象类型转化值
id transformValueWithType(id value,DWPrefix_YYEncodingType encodingType,DWPrefix_YYEncodingNSType nsType);

///获取两个数组的交集
NSArray * intersectionOfArray(NSArray * arr1,NSArray * arr2);

///从数组1中减去数组2
NSArray * minusArray(NSArray * arr1,NSArray * arr2);
