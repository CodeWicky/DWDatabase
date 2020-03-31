//
//  DWDatabase+CreateTable.h
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//
#import "DWDatabase.h"
#import "DWDatabase+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (CreateTable)

-(DWDatabaseResult *)dw_createTableWithClass:(Class)cls tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue;

@end

NS_ASSUME_NONNULL_END
