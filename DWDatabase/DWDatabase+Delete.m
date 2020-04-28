//
//  DWDatabase+Delete.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Delete.h"
#import "DWDatabaseFunction.h"
#import "DWDatabaseConditionMaker+Private.h"

#define kDeletePrefix (@"d")

@implementation DWDatabase (Delete)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_deleteTableWithModel:(NSObject *)model configuration:(DWDatabaseConfiguration *)conf deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(DWDatabaseConditionHandler)condition {
    
    if (!condition && !model) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model and condition which both are nil.", 10016)];
    }
    
    NSNumber * Dw_id = nil;
    if (model) {
        Dw_id = Dw_idFromModel(model);
        if (Dw_id) {
            
            DWDatabaseBindKeyWrapperContainer bindKeyWrappers = nil;
            
            if (condition) {
                DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
                condition(maker);
                bindKeyWrappers = [maker fetchBindKeys];
                if (!bindKeyWrappers.allKeys.count) {
                    bindKeyWrappers = nil;
                }
            }
            
            condition = ^(DWDatabaseConditionMaker * maker) {
                maker.loadClass([model class]);
                maker.conditionWith(kUniqueID).equalTo(Dw_id);
                if (bindKeyWrappers) {
                    maker.bindKeyWithWrappers(bindKeyWrappers);
                }
            };
        }
    }
    
    if (!condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    
    return [self dw_deleteTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue deleteChains:deleteChains recursive:recursive conditionMaker:maker];
}

-(DWDatabaseResult *)dw_deleteTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
    NSError * error = nil;
    if (!queue) {
        error = errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015);
        return [DWDatabaseResult failResultWithError:error];
    }
    if (!tblName.length) {
        error = errorWithMessage(@"Invalid tblName whose length is 0.", 10005);
        return [DWDatabaseResult failResultWithError:error];
    }
    
    ///删除时的递归操作思路：
    ///当根据模型生成sql时，如果模型的某个属性是对象类型，那么先将这个属性的对象删除，再将自身删除。这里需要注意一点如果存在多级模型嵌套，为避免A-B-A这种引用关系造成的死循环，在访问过程中要记录删除链，如果删除前检查到删除链中包含当前要删除的模型，说明已经删除过，直接跳过即可。
    
    if (recursive) {
        
        if (!deleteChains) {
            deleteChains = [DWDatabaseOperationChain new];
        }
        
        ///记录本次操作
        DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
        record.model = model;
        record.operation = DWDatabaseOperationDelete;
        record.tblName = tblName;
        [deleteChains addRecord:record];
    }
    
    DWDatabaseResult * result = [self deleteSQLFactoryWithModel:model dbName:dbName tableName:tblName deleteChains:deleteChains recursive:recursive conditionMaker:maker];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseSQLFactory * fac = result.result;
    result.result = nil;
    __weak typeof(self) weakSelf = self;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf excuteUpdate:db WithFactory:fac clear:YES];
        }];
    });
    
    return result;
}

#pragma mark --- tool method ---
-(DWDatabaseResult *)deleteSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
    
    if (!model && !maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to delete.", 10009)];
    }
    
    if (!maker.conditions.count) {
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (!Dw_id) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
        }
        
        if (!maker) {
            maker = [DWDatabaseConditionMaker new];
        }
        
        maker.loadClass([model class]);
        maker.conditionWith(kUniqueID).equalTo(Dw_id);
    }
    
    Class cls = [maker fetchQueryClass];
    if (!cls && model) {
        cls = [model class];
        maker.loadClass(cls);
    }
    
    if (!cls) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who hasn't load class.", 10017)];
    }
    
    NSMutableArray * args = @[].mutableCopy;
    NSMutableArray * conditionStrings = @[].mutableCopy;
    
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    
    [maker configWithTblName:tblName propertyInfos:propertyInfos databaseMap:map enableSubProperty:NO];
    [maker make];
    [args addObjectsFromArray:[maker fetchArguments]];
    [conditionStrings addObjectsFromArray:[maker fetchConditions]];
    
    ///无有效插入值
    if (!conditionStrings.count) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who have no valid value to delete.", 10009)];
    }
    
    DWDatabaseBindKeyWrapperContainer bindKeyWrappers = [maker fetchBindKeys];
    NSArray <DWDatabaseBindKeyWrapperContainer> * seperateWrappers = [self seperateSubWrappers:bindKeyWrappers fixMainWrappers:NO];
    DWDatabaseBindKeyWrapperContainer mainKeyWrappers = seperateWrappers.firstObject;
    DWDatabaseBindKeyWrapperContainer subKeyWrappers = seperateWrappers.lastObject;
    
    ///处理递归删除
    [self handleDeleteRecursiveModelWithPropertyInfos:propertyInfos dbName:dbName tblName:tblName model:model deleteChains:deleteChains recursive:recursive mainKeyWrappers:mainKeyWrappers subKeyWrappers:subKeyWrappers];
    
    NSString * sql = nil;
    ///先尝试取缓存的sql
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kDeletePrefix class:cls tblName:tblName keys:conditionStrings];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",tblName,[conditionStrings componentsJoinedByString:@" AND "]];
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setObject:sql forKey:cacheSqlKey];
        }
    }
    
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.dbName = dbName;
    fac.tblName = tblName;
    fac.sql = sql;
    fac.args = args;
    fac.model = model;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(void)handleDeleteRecursiveModelWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive mainKeyWrappers:(DWDatabaseBindKeyWrapperContainer)mainKeyWrappers subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers {
    if (model && ![model isKindOfClass:[NSNumber class]] && recursive) {
        Class cls = [model class];
        NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
        NSDictionary * dbTransformMap = databaseMapFromClass(cls);
        [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.name && obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                DWDatabaseBindKeyWrapper * wrapper = mainKeyWrappers[obj.name];
                if (!wrapper || wrapper.recursively) {
                    id value = [model dw_valueForPropertyInfo:obj];
                    if (value) {
                        NSNumber * Dw_id = value;
                        if (![Dw_id isKindOfClass:[NSNumber class]]) {
                            Dw_id = Dw_idFromModel(value);
                        }
                        if (Dw_id) {
                            NSString * name = propertyInfoTblName(obj, dbTransformMap);
                            if (name.length) {
                                DWDatabaseResult * existResult =  [deleteChains existRecordWithModel:value];
                                if (existResult.success) {
                                    DWDatabaseOperationRecord * operation = (DWDatabaseOperationRecord *)existResult.result;
                                    ///如果还没有完成，说明作为子节点，直接以非递归模式删除即可。如果完成了，跳过即可。
                                    if (!operation.finishOperationInChain) {
                                        DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:operation.tblName].result;
                                        if (tblConf) {
                                            
                                            DWDatabaseBindKeyWrapperContainer subKeyToInsert = [self subKeyWrappersIn:subKeyWrappers withPrefix:obj.name];
                                            DWDatabaseConditionMaker * maker = nil;
                                            if (subKeyToInsert.allKeys.count) {
                                                maker = [DWDatabaseConditionMaker new];
                                                maker.loadClass(obj.cls);
                                                maker.conditionWith(kUniqueID).equalTo(Dw_id);
                                                maker.bindKeyWithWrappers(subKeyToInsert);
                                            }
                                            DWDatabaseResult * result = [self dw_deleteTableWithModel:value dbName:tblConf.dbName tableName:tblConf.tableName inQueue:tblConf.dbQueue deleteChains:deleteChains recursive:NO conditionMaker:maker];
                                            
                                            if (result.success) {
                                                operation.finishOperationInChain = YES;
                                            }
                                        }
                                    }
                                } else {
                                    ///如果不存在，直接走递归删除逻辑
                                    NSString * existTblName = [deleteChains anyRecordInChainWithClass:obj.cls].tblName;
                                    NSString * inlineTblName = inlineModelTblName(obj, inlineTblNameMap, tblName,existTblName);
                                    if (inlineTblName.length) {
                                        DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName].result;
                                        if (tblConf) {
                                            DWDatabaseBindKeyWrapperContainer subKeyToInsert = [self subKeyWrappersIn:subKeyWrappers withPrefix:obj.name];
                                            
                                            DWDatabaseConditionHandler condition = nil;
                                            if (subKeyToInsert.allKeys.count) {
                                                condition = ^(DWDatabaseConditionMaker * maker) {
                                                    maker.loadClass(obj.cls);
                                                    maker.conditionWith(kUniqueID).equalTo(Dw_id);
                                                    maker.bindKeyWithWrappers(subKeyToInsert);
                                                };
                                            }
                                            DWDatabaseResult * result = [self _entry_deleteTableWithModel:value configuration:tblConf deleteChains:deleteChains recursive:recursive condition:condition];
                                            if (result.success) {
                                                DWDatabaseOperationRecord * record = [deleteChains recordInChainWithModel:value];
                                                record.finishOperationInChain = YES;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }];
    }
}

@end
