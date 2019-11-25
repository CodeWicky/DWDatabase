//
//  DWDatabaseConfiguration.h
//  DWDatabase
//
//  Created by Wicky on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>
/**
 数据库配置项，数据库操作的基本对象信息，不可通过自行创建，只可通过DWDatabase获取
 */
@interface DWDatabaseConfiguration : NSObject

///当前使用的数据库队列
@property (nonatomic ,strong ,readonly) FMDatabaseQueue * dbQueue;

///数据库在本地映射的name
@property (nonatomic ,copy ,readonly) NSString * dbName;

///当前使用的表名
@property (nonatomic ,copy ,readonly) NSString * tableName;

///当前数据库文件路径
@property (nonatomic ,copy ,readonly) NSString * dbPath;

-(instancetype)init NS_UNAVAILABLE;

@end
