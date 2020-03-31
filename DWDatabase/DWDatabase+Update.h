//
//  DWDatabase+Update.h
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase.h"
#import "DWDatabase+Private.h"
NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (Update)

-(DWDatabaseResult *)_entry_updateTableWithModel:(NSObject *)model keys:(nullable NSArray<NSString *> *)keys configuration:(nullable DWDatabaseConfiguration *)conf updateChains:(nullable DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive condition:(nullable DWDatabaseConditionHandler)condition;

-(DWDatabaseResult *)dw_updateTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(nullable NSArray <NSString *>*)keys inQueue:(FMDatabaseQueue *)queue updateChains:(nullable DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive conditionMaker:(nullable DWDatabaseConditionMaker *)maker;

@end

NS_ASSUME_NONNULL_END
