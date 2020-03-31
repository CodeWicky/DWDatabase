//
//  DWDatabase+Insert.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Insert.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase+Update.h"

#define kInsertPrefix (@"i")

@implementation DWDatabase (Insert)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_insertTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    return [self dw_insertTableWithModel:model dbName:conf.dbName tableName:conf.tableName keys:keys inQueue:conf.dbQueue insertChains:insertChains recursive:recursive];
}

-(DWDatabaseResult *)dw_insertTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray <NSString *>*)keys inQueue:(FMDatabaseQueue *)queue insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive {
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!dbName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    if (!model) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model who is nil.", 10016)];
    }
    
    
    ///插入时的递归操作思路：
    ///当根据模型生成sql时，如果模型的某个属性是对象类型，那么先将这个属性的对象插入表中，插入完成后，再将dw_id拼接至sql中。这里需要注意一点如果存在多级模型嵌套，为避免A-B-A这种引用关系造成的死循环，在访问过程中要记录插入链，如果插入前检查到插入链中包含当前要插入的模型，说明已经插入过，直接赋值即可。
    
    if (recursive) {
        
        if (!insertChains) {
            insertChains = [DWDatabaseOperationChain new];
        }
        
        ///记录本次操作
        DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
        record.model = model;
        record.operation = DWDatabaseOperationInsert;
        record.tblName = tblName;
        [insertChains addRecord:record];
    }
    
    __block DWDatabaseResult * result = [self insertSQLFactoryWithModel:model dbName:dbName tableName:tblName keys:keys insertChains:insertChains recursive:recursive];
    if (!result.success) {
        return result;
    }
   
    DWDatabaseSQLFactory * fac = result.result;
    ///如果插入链中已经包含model，说明嵌套链中存在自身model，且已经成功插入，此时直接更新表（如A-B-A这种结构中，inertChains结果中将不包含B，故此需要更新）
    
    if (recursive) {
        DWDatabaseOperationRecord * record = [insertChains recordInChainWithModel:model];
        if (record.finishOperationInChain) {
            if (fac.objMap.allKeys.count) {
                
                [fac.objMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [model setValue:obj forKey:key];
                }];
                
                result = [self dw_updateTableWithModel:model dbName:dbName tableName:tblName keys:fac.objMap.allKeys inQueue:queue updateChains:nil recursive:NO condition:nil];
            }
            result.result = Dw_idFromModel(model);
            return result;
        }
    }
    
    ///至此已取到合法sql
    __weak typeof(self) weakSelf = self;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            result = [strongSelf excuteUpdate:db WithFactory:fac clear:NO];
        }];
    });
    
    return result;
}

-(DWDatabaseResult *)insertSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray<NSString *> *)keys insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive {
    Class cls = [model class];
    NSError * error = nil;
    if (!tblName.length) {
        error = errorWithMessage(@"Invalid tblName whose length is 0.", 10005);
        return [DWDatabaseResult failResultWithError:error];
    }
    if (!model) {
        error = errorWithMessage(@"Invalid model who is nil.", 10016);
        return [DWDatabaseResult failResultWithError:error];
    }
    NSDictionary * infos = nil;
    if (keys.count) {
        ///此处要按支持的key做sql
        keys = [self validKeysIn:keys forClass:cls];
        if (keys.count) {
            infos = [self propertyInfosWithClass:cls keys:keys];
        }
    } else {
        infos = [self propertyInfosForSaveKeysWithClass:cls];
    }
    if (!infos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid key.",model];
        error = errorWithMessage(msg, 10013);
        return [DWDatabaseResult failResultWithError:error];
    }
    
    ///先看有效插入值，根据有效插入值确定sql
    NSMutableArray * args = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * validKeys = [NSMutableArray arrayWithCapacity:0];
    NSMutableDictionary * objMap = nil;
    if (recursive) {
        objMap = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    
    ///获取配置sql的相关参数
    [self handleInsertArgumentsWithPropertyInfos:infos dbName:dbName tblName:tblName model:model insertChains:insertChains recursive:recursive validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
    
    ///无有效插入值
    if (!args.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid value to insert.",model];
        error = errorWithMessage(msg, 10009);
        return [DWDatabaseResult failResultWithError:error];
    }
    
    NSString * sql = nil;
    ///先尝试取缓存的sql
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kInsertPrefix class:cls tblName:tblName keys:validKeys];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (",tblName,[validKeys componentsJoinedByString:@","]];
        ///再配置值
        NSString * doubt = @"";
        for (int i = 0,max = (int)args.count; i < max; i++) {
            doubt = [doubt stringByAppendingString:@"?,"];
        }
        doubt = [doubt substringToIndex:doubt.length - 1];
        sql = [sql stringByAppendingString:[NSString stringWithFormat:@"%@)",doubt]];
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
    fac.objMap = objMap;
    return [DWDatabaseResult successResultWithResult:fac];
}

#pragma mark --- tool method ---
-(void)handleInsertArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    Class cls = [model class];
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSDictionary * dbTransformMap = databaseMapFromClass(cls);
    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        
        if (obj.name) {
            id value = [model dw_valueForPropertyInfo:obj];
            NSString * name = propertyInfoTblName(obj, dbTransformMap);
            if (value && name.length) {
                ///此处考虑模型嵌套
                if (obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                    if (recursive) {
                        ///首先应该考虑当前要插入的模型，是否存在于插入链中，如果存在，还要考虑是否完成插入了，如果未完成（代表作为头部节点进入插入链，此时需要执行插入操作），如果完成了，说明同级模型中，存在相同实例，直接插入ID即可。如果不存在，直接执行插入操作
                        DWDatabaseResult * existResult =  [insertChains existRecordWithModel:value];
                        if (existResult.success) {
                            DWDatabaseOperationRecord * operation = (DWDatabaseOperationRecord *)existResult.result;
                            if (!operation.finishOperationInChain) {
                                DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:operation.tblName].result;
                                if (tblConf) {
                                    DWDatabaseResult * result = [self dw_insertTableWithModel:value dbName:dbName tableName:tblConf.tableName keys:nil inQueue:tblConf.dbQueue insertChains:insertChains recursive:NO];
                                    if (result.success) {
                                        [validKeys addObject:name];
                                        [args addObject:result.result];
                                        operation.finishOperationInChain = YES;
                                        objMap[obj.name] = result.result;
                                    }
                                }
                            } else {
                                NSNumber * Dw_id = Dw_idFromModel(value);
                                if (Dw_id) {
                                    [validKeys addObject:name];
                                    [args addObject:Dw_id];
                                }
                            }
                        } else {
                            
                            ///此处取嵌套模型对应地表名
                            NSString * existTblName = [insertChains anyRecordInChainWithClass:obj.cls].tblName;
                            NSString * inlineTblName = inlineModelTblName(obj, inlineTblNameMap, tblName,existTblName);
                            ///先看嵌套的模型是否存在Dw_id，如果存在代表为已存在记录，直接更新
                            if (inlineTblName.length) {
                                ///开始准备插入模型，先获取库名数据库句柄
                                DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
                                ///建表
                                if (dbConf && [self createTableWithClass:obj.cls tableName:inlineTblName configuration:dbConf].success) {
                                    ///获取表名数据库句柄
                                    DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName].result;
                                    if (tblConf) {
                                        ///插入
                                        DWDatabaseResult * result = [self _entry_insertTableWithModel:value keys:nil configuration:tblConf insertChains:insertChains recursive:recursive];
                                        ///如果成功，添加id
                                        if (result.success) {
                                            [validKeys addObject:name];
                                            [args addObject:result.result];
                                            
                                            DWDatabaseOperationRecord * record = [insertChains recordInChainWithModel:value];
                                            record.finishOperationInChain = YES;
                                            objMap[obj.name] = result.result;
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    [validKeys addObject:name];
                    [args addObject:value];
                }
            }
        }
    }];
}

@end
