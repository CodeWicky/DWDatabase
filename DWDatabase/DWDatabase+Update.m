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
#import "DWDatabase+Supply.h"
#import "DWDatabaseConditionMaker+Private.h"

#define kUpdatePrefix (@"u")

@implementation DWDatabase (Update)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_updateTableWithModel:(NSObject *)model configuration:(DWDatabaseConfiguration *)conf updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }
    
    return [self dw_updateTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue updateChains:updateChains recursive:recursive conditionMaker:maker];
}

-(DWDatabaseResult *)dw_updateTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
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
    
    NSNumber * Dw_id = Dw_idFromModel(model);
    ///如果模型本身存在Dw_id或者条件中设置过Dw_id，则认为是更新模式，否则是插入模式
    if (Dw_id || maker.conditions.count) {
        ///更新时的递归操作思路：
        if (!maker.conditions.count) {
            maker.conditionWith(kUniqueID).equalTo(Dw_id);
        }
        ///思路与插入时大致相同，当根据模型生成sql是，如果模型的某个属性是对象类型，应该根据该属性对应的对象是否包含Dw_id，如果不包含，则需要插入操作，完成后，更新至模型中。如果存在Dw_id，则直接更新指定模型，并在sql中可以更新为此Dw_id。同样，为了避免循环插入，要记录在更新链中。
        
        if (recursive) {
            
            if (!updateChains) {
                updateChains = [DWDatabaseOperationChain new];
            }
            
            if (![updateChains existRecordWithModel:model].success) {
                ///记录本次操作
                DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
                record.model = model;
                record.operation = DWDatabaseOperationUpdate;
                record.tblName = tblName;
                record.operatedKeys = [NSMutableSet set];
                [updateChains addRecord:record];
            }
        }
        
        __block DWDatabaseResult * result = [self updateSQLFactoryWithModel:model dbName:dbName tableName:tblName updateChains:updateChains recursive:recursive conditionMaker:maker];
        if (!result.success) {
            return result;
        }
        DWDatabaseSQLFactory * fac = result.result;
        
        ///如果更新链中已经包含model，说明嵌套链中存在自身model，且已经成功插入，此时直接更新表（如A-B-A这种结构中，updateChains结果中将不包含B，故此需要更新）
        
        if (recursive) {
            DWDatabaseOperationRecord * record = [updateChains recordInChainWithModel:model];
            if (record.finishOperationInChain) {
                DWDatabaseBindKeyWrapperContainer updateWrappers = [self subKeyWrappersIn:fac.mainKeyWrappers inKeys:fac.objMap.allKeys];
                if (fac.objMap.allKeys.count && updateWrappers.allKeys.count) {
                    
                    [fac.objMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                        [model setValue:obj forKey:key];
                    }];
                    
                    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
                    maker.bindKeyWithWrappers(updateWrappers);
                    result = [self dw_updateTableWithModel:model dbName:dbName tableName:tblName inQueue:queue updateChains:nil recursive:NO conditionMaker:maker];
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
        return [self dw_insertTableWithModel:model dbName:dbName tableName:tblName inQueue:queue insertChains:nil recursive:recursive conditionMaker:nil];
    }
}

#pragma mark --- tool method ---
-(DWDatabaseResult *)updateSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
    NSDictionary * infos = nil;
    
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to update.",10009)];
    }
    
    Class cls = [maker fetchQueryClass];
    if (!cls && model) {
        cls = [model class];
        
        if (!cls) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who hasn't load class.", 10017)];
        }
        
        maker.loadClass(cls);
    }
    
    DWDatabaseBindKeyWrapperContainer bindKeyWrapper = [maker fetchBindKeys];
    NSArray<DWDatabaseBindKeyWrapperContainer> * seperateWrappers = [self seperateSubWrappers:bindKeyWrapper];
    NSArray * keys = [seperateWrappers.firstObject allKeys];
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
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    NSDictionary * databaseMap = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithTblName:tblName propertyInfos:propertyInfos databaseMap:databaseMap enableSubProperty:NO];
    [maker make];
    NSArray * conditionArgs = [maker fetchArguments];
    NSArray * conditionStrings = [maker fetchConditions];
    
    ///无有效插入值
    if (!conditionStrings.count) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to update.", 10009)];
    }
    
    ///存在ID可以做更新操作
    NSMutableArray * updateArgs = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * validKeys = [NSMutableArray arrayWithCapacity:0];
    
    NSMutableDictionary * objMap = nil;
    if (recursive) {
        objMap = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    
    ///获取更新sql相关参数
    [self handleUpdateArgumentsWithPropertyInfos:infos dbName:dbName tblName:tblName model:model updateChains:updateChains recursive:recursive validKeysContainer:validKeys argumentsContaienr:updateArgs objMap:objMap mainKeyWrappers:seperateWrappers.firstObject subKeyWrappers:seperateWrappers.lastObject];
    
    ///无有效插入值
    if (!updateArgs.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid value to update.",model];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    NSString * sql = nil;
    
    ///先尝试取缓存的sql
    NSArray * sqlCombineArray = combineArrayWithExtraToSort(validKeys ,conditionStrings);
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kUpdatePrefix class:cls tblName:tblName keys:sqlCombineArray];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",tblName,[validKeys componentsJoinedByString:@","],[conditionStrings componentsJoinedByString:@" AND "]];
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
    fac.validKeys = validKeys;
    fac.mainKeyWrappers = seperateWrappers.firstObject;
    fac.subKeyWrappers = seperateWrappers.lastObject;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(void)handleUpdateArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap mainKeyWrappers:(DWDatabaseBindKeyWrapperContainer)mainKeyWrappers subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers {
    Class cls = [model class];
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSDictionary * dbTransformMap = databaseMapFromClass(cls);
    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name) {
            id value = [model dw_valueForPropertyInfo:obj];
            NSString * propertyTblName = propertyInfoTblName(obj, dbTransformMap);
            if (propertyTblName.length) {
                if (value) {
                    if (obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                        DWDatabaseBindKeyWrapper * wrapper = mainKeyWrappers[obj.name];
                        if (!wrapper || wrapper.recursively) {
                            if (recursive) {
                                DWDatabaseResult * existResult =  [updateChains existRecordWithModel:value];
                                if (existResult.success) {
                                    NSNumber * Dw_id = Dw_idFromModel(value);
                                    DWDatabaseOperationRecord * record = (DWDatabaseOperationRecord *)existResult.result;
                                    
                                    ///如果未完成，有存在，证明此次作为子节点递归存在，故不需要再次递归更新，仅更新本层即可
                                    DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:record.tblName].result;
                                    
                                    NSArray * subkeyToUpdate = nil;
                                    if (tblConf) {
                                        subkeyToUpdate = [self actualSubKeysIn:subKeyWrappers.allKeys withPrefix:obj.name];
                                        ///没有指定二级属性，则按需要插入全部属性计算
                                        if (!subkeyToUpdate.count) {
                                            subkeyToUpdate = [DWDatabase propertysToSaveWithClass:obj.cls];
                                        }
                                    }
                                    
                                    if (!record.finishOperationInChain) {
                                        if (!subkeyToUpdate.count) {
                                            return ;
                                        }
                                        [self updateModelSubKeys:value Dw_id:Dw_id propertyInfo:obj propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers subkeyToUpdate:subkeyToUpdate record:record conf:tblConf updateChains:updateChains validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                                    } else {
                                        ///如果已经在更新链中完成更新 ，那么直接更新id即可
                                        [self supplyModelSubKeys:value Dw_id:Dw_id propertyInfo:obj propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers subkeyToUpdate:subkeyToUpdate record:record conf:tblConf updateChains:updateChains validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                                    }
                                } else {
                                    [self updateNotExistModel:value propertyInfo:obj dbName:dbName tblName:tblName propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers updateChains:updateChains inlineTblNameMap:inlineTblNameMap validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                                }
                            } else {
                                [self updateModelID:value propertyTblName:propertyTblName validKeysContainer:validKeys argumentsContaienr:args];
                            }
                        } else {
                            [self updateModelID:value propertyTblName:propertyTblName validKeysContainer:validKeys argumentsContaienr:args];
                        }
                    } else {
                        propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
                        [validKeys addObject:propertyTblName];
                        [args addObject:value];
                    }
                } else {
                    ///代表更新为空
                    propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
                    [validKeys addObject:propertyTblName];
                    [args addObject:[NSNull null]];
                }
            }
        }
    }];
}

-(void)updateModelSubKeys:(NSObject *)model Dw_id:(NSNumber *)Dw_id propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subkeyToUpdate:(NSArray <NSString *>*)subkeyToUpdate record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf  updateChains:(DWDatabaseOperationChain *)updateChains validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    NSMutableSet * subKeyToUpdateSet = [NSMutableSet setWithArray:subkeyToUpdate];
    DWDatabaseResult * result = [self updateModelSubKeysResult:model propertyInfo:prop subKeyWrappers:subKeyWrappers subKeyToUpdateSet:subKeyToUpdateSet record:record conf:conf updateChains:updateChains];
    if (result) {
        if (!result.success) {
            propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
            [validKeys addObject:propertyTblName];
            ///之前就存在，则_entry_update中走的也是更新逻辑
            if (Dw_id) {
                [args addObject:Dw_id];
            } else {
                [args addObject:result.result];
                objMap[prop.name] = model;
            }
            record.finishOperationInChain = YES;
        } else {
            ///如果插入失败了，再将刚才因此添加的key移除
            [record.operatedKeys minusSet:subKeyToUpdateSet];
        }
    }
}

-(DWDatabaseResult *)updateModelSubKeysResult:(NSObject *)model propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subKeyToUpdateSet:(NSMutableSet *)subKeyToUpdateSet record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf updateChains:(DWDatabaseOperationChain *)updateChains {
    ///先计算是否有需要更新的字段，如果没有的话，此模型也就没有其他操作了
    [subKeyToUpdateSet minusSet:record.operatedKeys];
    if (subKeyToUpdateSet.count) {
        ///同样要先记录属性，避免递归
        NSArray * subKeyToUpdate = [subKeyToUpdateSet allObjects];
        [record.operatedKeys addObjectsFromArray:subKeyToUpdate];
        ///转化成为带subKey的属性字段
        DWDatabaseBindKeyWrapperContainer subKeyRecursiveToUpdate = [NSMutableDictionary dictionaryWithCapacity:0];
        [subKeyToUpdate enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [subKeyRecursiveToUpdate addEntriesFromDictionary:[self subKeyWrappersIn:subKeyWrappers withPrefix:prop.name actualSubKey:obj]];
        }];
        ///开始更新
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        maker.bindKeyWithWrappers(subKeyRecursiveToUpdate);
        return [self dw_updateTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue updateChains:updateChains recursive:YES conditionMaker:maker];
    }
    return nil;
}

-(void)supplyModelSubKeys:(NSObject *)model Dw_id:(NSNumber *)Dw_id propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subkeyToUpdate:(NSArray <NSString *>*)subkeyToUpdate record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf  updateChains:(DWDatabaseOperationChain *)updateChains validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    if (Dw_id) {
        propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
        [validKeys addObject:propertyTblName];
        [args addObject:Dw_id];
        NSMutableSet * subKeyToUpdateSet = [NSMutableSet setWithArray:subkeyToUpdate];
        [self updateModelSubKeysResult:model propertyInfo:prop subKeyWrappers:subKeyWrappers subKeyToUpdateSet:subKeyToUpdateSet record:record conf:conf updateChains:updateChains];
    }
}

-(void)updateNotExistModel:(NSObject *)model propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop dbName:(NSString *)dbName tblName:(NSString *)tblName propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers updateChains:(DWDatabaseOperationChain *)updateChains inlineTblNameMap:(NSDictionary *)inlineTblNameMap validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    ///此处取嵌套模型对应地表名
    NSString * existTblName = [updateChains anyRecordInChainWithClass:prop.cls].tblName;
    NSString * inlineTblName = inlineModelTblName(prop, inlineTblNameMap, tblName,existTblName);
    if (inlineTblName.length) {
        DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
        if (dbConf && [self createTableWithClass:prop.cls tableName:inlineTblName configuration:dbConf].success) {
            DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName].result;
            
            DWDatabaseBindKeyWrapperContainer subKeyToUpdate = nil;
            if (tblConf) {
                subKeyToUpdate = [self subKeyWrappersIn:subKeyWrappers withPrefix:prop.name];
                ///没有指定二级属性，则按需要插入全部属性计算
                if (!subKeyToUpdate.count) {
                    subKeyToUpdate = [self saveKeysWrappersWithCls:prop.cls];
                }
            }
            
            if (!subKeyToUpdate.count) {
                return;
            }
            
            DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
                maker.bindKeyWithWrappers(subKeyToUpdate);
            };
            
            ///这里区分下是否有dw_id，如果Dw_id存在，证明本身就是表中的数据，仅更新数据即可，如果没有走插入逻辑
            NSNumber * Dw_id = Dw_idFromModel(model);
            DWDatabaseResult * result = [self _entry_updateTableWithModel:model configuration:tblConf updateChains:updateChains recursive:YES condition:condition];
            if (result.success) {
                propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
                [validKeys addObject:propertyTblName];
                ///之前就存在，则_entry_update中走的也是更新逻辑
                if (Dw_id) {
                    [args addObject:Dw_id];
                } else {
                    ///走的是插入逻辑，要标记状态
                    [args addObject:result.result];
                    objMap[prop.name] = model;
                }
                DWDatabaseOperationRecord * record = [updateChains recordInChainWithModel:model];
                record.finishOperationInChain = YES;
            }
        }
    }
}

-(void)updateModelID:(NSObject *)model propertyTblName:(NSString *)propertyTblName validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args {
    if ([model isKindOfClass:[NSNumber class]]) {
        propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
        [validKeys addObject:propertyTblName];
        [args addObject:model];
    } else {
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (Dw_id) {
            propertyTblName = [propertyTblName stringByAppendingString:@" = ?"];
            [validKeys addObject:propertyTblName];
            [args addObject:Dw_id];
        }
    }
}

@end
