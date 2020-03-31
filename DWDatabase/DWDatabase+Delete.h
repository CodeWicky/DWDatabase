//
//  DWDatabase+Delete.h
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//
#import "DWDatabase.h"
#import "DWDatabase+Private.h"
NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (Delete)

-(DWDatabaseResult *)_entry_deleteTableWithModel:(nullable NSObject *)model configuration:(nullable DWDatabaseConfiguration *)conf deleteChains:(nullable DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(nullable DWDatabaseConditionHandler)condition;

-(DWDatabaseResult *)dw_deleteTableWithModel:(nullable NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue deleteChains:(nullable DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(nullable DWDatabaseConditionHandler)condition;

@end

NS_ASSUME_NONNULL_END
