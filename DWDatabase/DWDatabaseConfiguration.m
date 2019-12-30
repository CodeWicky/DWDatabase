//
//  DWDatabaseConfiguration.m
//  DWDatabase
//
//  Created by Wicky on 2019/11/25.
//

#import "DWDatabaseConfiguration.h"

@interface DWDatabaseConfiguration ()

///当前使用的数据库队列
@property (nonatomic ,strong) FMDatabaseQueue * dbQueue;

///数据库在本地映射的name
@property (nonatomic ,copy ,readwrite) NSString * dbName;

///当前使用的表名
@property (nonatomic ,copy) NSString * tableName;

@end

@implementation DWDatabaseConfiguration

-(NSString *)dbPath {
    return self.dbQueue.path;
}

@end
