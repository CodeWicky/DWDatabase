//
//  DWDatabase+Update.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Update.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase+Insert.h"
#import "DWDatabase.h"

#define kUpdatePrefix (@"u")

@implementation DWDatabase (Update)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_updateTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    
    if (!condition) {
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (Dw_id) {
            condition = ^(DWDatabaseConditionMaker * maker) {
                maker.loadClass([model class]);
                maker.conditionWith(kUniqueID).equalTo(Dw_id);
            };
        }
    }
    
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }
    
    return [self dw_updateTableWithModel:model dbName:conf.dbName tableName:conf.tableName keys:keys inQueue:conf.dbQueue updateChains:updateChains recursive:recursive updateObjectID:NO conditionMaker:maker];
}

-(DWDatabaseResult *)dw_updateTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray <NSString *>*)keys inQueue:(FMDatabaseQueue *)queue updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive updateObjectID:(BOOL)updateObjectID conditionMaker:(DWDatabaseConditionMaker *)maker {
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!dbName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    if (!model) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model who is nil.", 10016)];
    }
    
    ///存在Dw_id的会被更新为条件模式，故只判断condition即可
    if (maker) {
        ///更新时的递归操作思路：
        ///思路与插入时大致相同，当根据模型生成sql是，如果模型的某个属性是对象类型，应该根据该属性对应的对象是否包含Dw_id，如果不包含，则需要插入操作，完成后，更新至模型中。如果存在Dw_id，则直接更新指定模型，并在sql中可以更新为此Dw_id。同样，为了避免循环插入，要记录在更新链中。
        
        if (recursive) {
            
            if (!updateChains) {
                updateChains = [DWDatabaseOperationChain new];
            }
            
            ///记录本次操作
            DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
            record.model = model;
            record.operation = DWDatabaseOperationUpdate;
            record.tblName = tblName;
            [updateChains addRecord:record];
        }
        
        __block DWDatabaseResult * result = [self updateSQLFactoryWithModel:model dbName:dbName tableName:tblName keys:keys updateChains:updateChains recursive:recursive updateObjectID:updateObjectID conditionMaker:maker];
        if (!result.success) {
            return result;
        }
        DWDatabaseSQLFactory * fac = result.result;
        
        ///如果更新链中已经包含model，说明嵌套链中存在自身model，且已经成功插入，此时直接更新表（如A-B-A这种结构中，updateChains结果中将不包含B，故此需要更新）
        
        if (recursive) {
            DWDatabaseOperationRecord * record = [updateChains recordInChainWithModel:model];
            if (record.finishOperationInChain) {
                if (fac.objMap.allKeys.count) {
                    
                    [fac.objMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                        [model setValue:obj forKey:key];
                    }];
                    
                    result = [self dw_updateTableWithModel:model dbName:dbName tableName:tblName keys:fac.objMap.allKeys inQueue:queue updateChains:nil recursive:NO updateObjectID:YES conditionMaker:nil];
                } else {
                    NSNumber * Dw_id = nil;
                    if (model) {
                        Dw_id = Dw_idFromModel(model);
                    }
                    return [DWDatabaseResult successResultWithResult:Dw_id];
                }
                return result;
            }
        }
        
        result.result = nil;
        __weak typeof(self) weakSelf = self;
        excuteOnDBOperationQueue(self, ^{
            [queue inDatabase:^(FMDatabase * _Nonnull db) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                result = [strongSelf excuteUpdate:db WithFactory:fac clear:NO];
            }];
        });
        return result;
    } else {
        ///不存在ID则不做更新操作，做插入操作
        ///插入操作后最好把Dw_id赋值
        return [self dw_insertTableWithModel:model dbName:dbName tableName:tblName keys:keys inQueue:queue insertChains:nil recursive:recursive];
    }
}

#pragma mark --- tool method ---
-(DWDatabaseResult *)updateSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray<NSString *> *)keys updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive updateObjectID:(BOOL)updateObjectID conditionMaker:(DWDatabaseConditionMaker *)maker {
    NSDictionary * infos = nil;
    
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to update.",10009)];
    }
    
    Class cls = [maker fetchQueryClass];
    if (!cls && model) {
        cls = [model class];
    }
    
    if (!cls) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who hasn't load class.", 10017)];
    }
    
    ///如果指定更新key则取更新key的infos信息
    if (keys.count) {
        keys = [self validKeysIn:keys forClass:cls];
        if (keys.count) {
            infos = [DWDatabase propertyInfosWithClass:cls keys:keys];
        }
    } else {
        infos = [self propertyInfosForSaveKeysWithClass:cls];
    }
    if (!infos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid key.",model];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10013)];
    }
    
    ///配置查询条件
    NSMutableArray * conditionArgs = @[].mutableCopy;
    NSMutableArray * conditionStrings = @[].mutableCopy;
    NSMutableArray * validConditionKeys = @[].mutableCopy;
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    NSDictionary * databaseMap = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithPropertyInfos:propertyInfos databaseMap:databaseMap];
    [maker make];
    [conditionArgs addObjectsFromArray:[maker fetchArguments]];
    [conditionStrings addObjectsFromArray:[maker fetchConditions]];
    [validConditionKeys addObjectsFromArray:[maker fetchValidKeys]];
    
    ///无有效插入值
    if (!conditionStrings.count) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to update.", 10009)];
    }
    
    ///存在ID可以做更新操作
    NSMutableArray * updateArgs = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * validUpdateKeys = [NSMutableArray arrayWithCapacity:0];
    
    NSMutableDictionary * objMap = nil;
    if (recursive) {
        objMap = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    
    ///获取更新sql相关参数
    [self handleUpdateArgumentsWithPropertyInfos:infos dbName:dbName tblName:tblName model:model updateChains:updateChains recursive:recursive updateObjectID:updateObjectID validKeysContainer:validUpdateKeys argumentsContaienr:updateArgs objMap:objMap];
    
    ///无有效插入值
    if (!updateArgs.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid value to update.",model];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    NSString * sql = nil;
    
    ///先尝试取缓存的sql
    NSArray * sqlCombineArray = combineArrayWithExtraToSort(validUpdateKeys ,conditionStrings);
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kUpdatePrefix class:cls tblName:tblName keys:sqlCombineArray];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",tblName,[validUpdateKeys componentsJoinedByString:@","],[conditionStrings componentsJoinedByString:@" AND "]];
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setObject:sql forKey:cacheSqlKey];
        }
    }
    
    NSMutableArray * args = [NSMutableArray arrayWithCapacity:updateArgs.count + conditionArgs.count];
    [args addObjectsFromArray:updateArgs];
    [args addObjectsFromArray:conditionArgs];
    
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.dbName = dbName;
    fac.tblName = tblName;
    fac.sql = sql;
    fac.args = args;
    fac.model = model;
    fac.objMap = objMap;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(void)handleUpdateArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive updateObjectID:(BOOL)updateObjectID validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    Class cls = [model class];
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSDictionary * dbTransformMap = databaseMapFromClass(cls);
    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name) {
            id value = [model dw_valueForPropertyInfo:obj];
            NSString * name = propertyInfoTblName(obj, dbTransformMap);
            if (name.length) {
                if (value) {
                    if (obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                        ///考虑模型嵌套
                        if (recursive) {
                            DWDatabaseResult * existResult =  [updateChains existRecordWithModel:value];
                            if (existResult.success) {
                                NSNumber * Dw_id = Dw_idFromModel(value);
                                DWDatabaseOperationRecord * operation = (DWDatabaseOperationRecord *)existResult.result;
                                if (!operation.finishOperationInChain) {
                                    ///如果未完成，有存在，证明此次作为子节点递归存在，故不需要再次递归更新，仅更新本层即可
                                    DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:operation.tblName].result;
                                    if (tblConf) {
                                        DWDatabaseConditionMaker * maker = nil;
                                        if (Dw_id) {
                                            DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
                                                maker.conditionWith(kUniqueID).equalTo(Dw_id);
                                            };
                                            maker = [DWDatabaseConditionMaker new];
                                            condition(maker);
                                        }
                                        
                                        DWDatabaseResult * result = [self dw_updateTableWithModel:value dbName:tblConf.dbName tableName:tblConf.tableName keys:nil inQueue:tblConf.dbQueue updateChains:updateChains recursive:NO updateObjectID:YES conditionMaker:maker];
                                        if (result.success) {
                                            name = [name stringByAppendingString:@" = ?"];
                                            [validKeys addObject:name];
                                            ///之前就存在，则_entry_update中走的也是更新逻辑
                                            if (Dw_id) {
                                                [args addObject:Dw_id];
                                            } else {
                                                [args addObject:result.result];
                                                objMap[obj.name] = result.result;
                                            }
                                            operation.finishOperationInChain = YES;
                                        }
                                    }
                                } else {
                                    ///如果已经在更新链中完成更新 ，那么直接更新id即可
                                    if (Dw_id) {
                                        name = [name stringByAppendingString:@" = ?"];
                                        [validKeys addObject:name];
                                        [args addObject:Dw_id];
                                    }
                                }
                            } else {
                                ///此处取嵌套模型对应地表名
                                NSString * existTblName = [updateChains anyRecordInChainWithClass:obj.cls].tblName;
                                NSString * inlineTblName = inlineModelTblName(obj, inlineTblNameMap, tblName,existTblName);
                                if (inlineTblName.length) {
                                    DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
                                    if (dbConf && [self createTableWithClass:obj.cls tableName:inlineTblName configuration:dbConf].success) {
                                        DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName].result;
                                        if (tblConf) {
                                            ///这里区分下是否有dw_id，如果Dw_id存在，证明本身就是表中的数据，仅更新数据即可，如果没有走插入逻辑
                                            NSNumber * Dw_id = Dw_idFromModel(value);
                                            DWDatabaseResult * result = [self _entry_updateTableWithModel:value keys:nil configuration:tblConf updateChains:updateChains recursive:recursive condition:nil];
                                            if (result.success) {
                                                name = [name stringByAppendingString:@" = ?"];
                                                [validKeys addObject:name];
                                                ///之前就存在，则_entry_update中走的也是更新逻辑
                                                if (Dw_id) {
                                                    [args addObject:Dw_id];
                                                } else {
                                                    ///走的是插入逻辑，要标记状态
                                                    [args addObject:result.result];
                                                    objMap[obj.name] = result.result;
                                                }
                                                DWDatabaseOperationRecord * record = [updateChains recordInChainWithModel:value];
                                                record.finishOperationInChain = YES;
                                            }
                                        }
                                    }
                                }
                            }
                        } else if (updateObjectID) {
                            ///updateObjectID这个标志位是用来标识是否是嵌套插入或者更新后用来更新ID的标志位。因为这种情况下为非嵌套模式，且对应属性是对象类型
                            if ([value isKindOfClass:[NSNumber class]]) {
                                name = [name stringByAppendingString:@" = ?"];
                                [validKeys addObject:name];
                                [args addObject:value];
                            } else {
                                NSNumber * Dw_id = Dw_idFromModel(value);
                                if (Dw_id) {
                                    name = [name stringByAppendingString:@" = ?"];
                                    [validKeys addObject:name];
                                    [args addObject:Dw_id];
                                }
                            }
                        }
                    } else {
                        name = [name stringByAppendingString:@" = ?"];
                        [validKeys addObject:name];
                        [args addObject:value];
                    }
                } else {
                    ///代表更新为空
                    name = [name stringByAppendingString:@" = ?"];
                    [validKeys addObject:name];
                    [args addObject:[NSNull null]];
                }
            }
        }
    }];
}

@end
