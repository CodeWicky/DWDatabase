//
//  DWDatabase+Query.h
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//
#import "DWDatabase.h"
#import "DWDatabase+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (Query)

-(DWDatabaseResult *)_entry_queryTableWithClass:(nullable Class)clazz limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending configuration:(nullable DWDatabaseConfiguration *)conf queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive condition:(nullable DWDatabaseConditionHandler)condition;

-(DWDatabaseResult *)_entry_queryTableWithClass:(nullable Class)cls Dw_id:(NSNumber *)Dw_id queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive configuration:(nullable DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker;

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker resultSetHandler:(NSError *(^)(Class cls,FMResultSet * set,NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*validProInfos,NSDictionary * databaseMap,NSMutableArray * resultArr,DWDatabaseOperationChain * queryChains,BOOL recursive,NSDictionary * inlineTblNameMap,BOOL * stop,BOOL * returnNil))handler;

-(DWDatabaseResult *)dw_queryTableForCountWithDbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue conditionMaker:(DWDatabaseConditionMaker *)maker;

-(DWDatabaseResult *)handleQueryResultWithClass:(nullable Class)cls dbName:(NSString *)dbName tblName:(NSString *)tblName resultSet:(FMResultSet *)set validProInfos:(nullable NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)validProInfos databaseMap:(nullable NSDictionary *)databaseMap resultArr:(NSMutableArray *)resultArr queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive inlineTblNameMap:(nullable NSDictionary *)inlineTblNameMap stop:(BOOL *)stop returnNil:(BOOL *)returnNil stopOnValidValue:(BOOL)stopOnValidValue;

-(DWDatabaseResult *)handleQueryRecursiveResultWithDbName:(NSString *)dbName tblName:(NSString *)tblName resultArr:(nullable NSMutableArray *)resultArr queryChains:(nullable DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive;

@end

NS_ASSUME_NONNULL_END
