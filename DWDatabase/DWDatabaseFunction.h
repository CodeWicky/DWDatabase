//
//  DWDatabaseFunction.h
//  DWDatabase
//
//  Created by Wicky on 2019/12/3.
//

#import <UIKit/UIKit.h>
#import "DWDatabase.h"

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

///快速生成NSError
NSError * errorWithMessage(NSString * msg,NSInteger code);

///获取额外配置字典
NSMutableDictionary * additionalConfigFromModel(NSObject * model);

///获取id
NSNumber * Dw_idFromModel(NSObject * model);

///设置id
void SetDw_idForModel(NSObject * model,NSNumber * dw_id);

///获取库名
NSString * DbNameFromModel(NSObject * model);

///设置库名
void SetDbNameForModel(NSObject * model,NSString * dbName);

///获取表名
NSString * TblNameFromModel(NSObject * model);

///设置表名
void SetTblNameForModel(NSObject * model,NSString * tblName);

///同步在数据库队列执行任务
void excuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block);

///异步在数据库队列执行任务
void asyncExcuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block);

///拼装数组
NSArray * combineArrayWithExtraToSort(NSArray <NSString *>* array,NSArray <NSString *>* extra);
