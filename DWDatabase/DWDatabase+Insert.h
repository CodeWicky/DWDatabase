//
//  DWDatabase+Insert.h
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//
#import "DWDatabase.h"
#import "DWDatabase+Private.h"
NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (Insert)

-(DWDatabaseResult *)insertSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(nullable NSArray<NSString *> *)keys insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive;

-(DWDatabaseResult *)_entry_insertTableWithModel:(NSObject *)model keys:(nullable NSArray<NSString *> *)keys configuration:(nullable DWDatabaseConfiguration *)conf insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive;

-(DWDatabaseResult *)dw_insertTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(nullable NSArray <NSString *>*)keys inQueue:(FMDatabaseQueue *)queue insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive;

@end

NS_ASSUME_NONNULL_END
