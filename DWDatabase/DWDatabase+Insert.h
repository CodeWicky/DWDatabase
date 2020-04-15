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

-(DWDatabaseResult *)insertSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive conditionMaker:(nullable DWDatabaseConditionMaker *)maker;

-(DWDatabaseResult *)_entry_insertTableWithModel:(NSObject *)model configuration:(nullable DWDatabaseConfiguration *)conf insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive condition:(nullable DWDatabaseConditionHandler)condition;

-(DWDatabaseResult *)dw_insertTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue insertChains:(nullable DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive conditionMaker:(nullable DWDatabaseConditionMaker *)maker;

@end

NS_ASSUME_NONNULL_END
