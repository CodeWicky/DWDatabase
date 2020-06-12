//
//  DWDatabase+Insert.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Insert.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase+Update.h"
#import "DWDatabase+Supply.h"
#import "DWDatabaseConditionMaker+Private.h"

#define kInsertPrefix (@"i")

@implementation DWDatabase (Insert)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_insertTableWithModel:(NSObject *)model configuration:(DWDatabaseConfiguration *)conf insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }

    return [self dw_insertTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue insertChains:insertChains recursive:recursive conditionMaker:maker];
}

-(DWDatabaseResult *)dw_insertTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
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
        
        ///递归模式下，即使插入链中存在，也可能走递归模式，补充字段。所以这里记录一下，不存在的才更新插入链
        if (![insertChains existRecordWithModel:model].success) {
            ///记录本次操作
            DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
            record.model = model;
            record.operation = DWDatabaseOperationInsert;
            record.tblName = tblName;
            record.operatedKeys = [NSMutableSet set];
            [insertChains addRecord:record];
        }
    }
    
    ///生成sqlFac
    __block DWDatabaseResult * result = [self insertSQLFactoryWithModel:model dbName:dbName tableName:tblName insertChains:insertChains recursive:recursive conditionMaker:maker];
    if (!result.success) {
        return result;
    }
   
    DWDatabaseSQLFactory * fac = result.result;
    ///如果插入链中已经包含model，说明嵌套链中存在自身model，且已经成功插入，此时直接更新表（如A-B-A这种结构中，inertChains结果中将不包含B，故此需要更新）
    
    if (recursive) {
        ///看看是不是已经在插入链中完成了，嵌套结构的话会存在这种情况。如果完成了，则更新所有对象字段。
        DWDatabaseOperationRecord * record = [insertChains recordInChainWithModel:model];
        if (record.finishOperationInChain) {
            NSNumber * Dw_id = Dw_idFromModel(model);
            ///这里用validKeys是因为要做全量更新，当finishOperationInChain以后，非对象属性可能由于还没有插入导致漏掉
            DWDatabaseBindKeyWrapperContainer updateWrappers = [self subKeyWrappersIn:fac.mainKeyWrappers inKeys:fac.validKeys];
            if (fac.objMap.allKeys.count && updateWrappers.count) {
                [fac.objMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [model setValue:obj forKey:key];
                }];
                
                DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
                maker.loadClass([model class]);
                maker.conditionWith(kUniqueID).equalTo(Dw_id);
                maker.bindKeyWithWrappers(updateWrappers);
                ///只更新对象说行，不需要嵌套结构了
                result = [self dw_updateTableWithModel:model dbName:dbName tableName:tblName inQueue:queue updateChains:nil recursive:NO conditionMaker:maker];
            }
            result.result = Dw_id;
            return result;
        }
    }
    
    ///至此已取到合法sql
    __weak typeof(self) weakSelf = self;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            result = [strongSelf excuteUpdate:db WithFactory:fac operation:(DWDatabaseOperationInsert)];
        }];
    });
    
    return result;
}

-(DWDatabaseResult *)insertSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {
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
    DWDatabaseBindKeyWrapperContainer bindKeyWrapper = [maker fetchBindKeys];
    NSArray<DWDatabaseBindKeyWrapperContainer> * seperateWrappers = [self seperateSubWrappers:bindKeyWrapper fixMainWrappers:YES];
    NSArray * keys = [seperateWrappers.firstObject allKeys];
    if (keys.count) {
        ///此处要按支持的key做sql
        keys = [self validKeysIn:keys forClass:cls];
        if (keys.count) {
            infos = [DWDatabase propertyInfosWithClass:cls keys:keys];
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
    [self handleInsertArgumentsWithPropertyInfos:infos dbName:dbName tblName:tblName model:model insertChains:insertChains recursive:recursive validKeysContainer:validKeys argumentsContaienr:args objMap:objMap mainKeyWrappers:seperateWrappers.firstObject subKeyWrappers:seperateWrappers.lastObject];
    
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
    fac.validKeys = validKeys;
    fac.mainKeyWrappers = seperateWrappers.firstObject;
    fac.subKeyWrappers = seperateWrappers.lastObject;
    return [DWDatabaseResult successResultWithResult:fac];
}

#pragma mark --- tool method ---
-(void)handleInsertArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap mainKeyWrappers:(DWDatabaseBindKeyWrapperContainer)mainKeyWrappers subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers {
    Class cls = [model class];
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSDictionary * dbTransformMap = databaseMapFromClass(cls);
    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        
        if (obj.name) {
            id value = [model dw_valueForPropertyInfo:obj];
            NSString * propertyTblName = propertyInfoTblName(obj, dbTransformMap);
            if (value && propertyTblName.length) {
                ///此处考虑模型嵌套
                if (obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                    
                    DWDatabaseBindKeyWrapper * propWrapper = mainKeyWrappers[obj.name];
                    if (!propWrapper || propWrapper.recursively) {
                        if (recursive) {
                            ///首先应该考虑当前要插入的模型，是否存在于插入链中，如果存在，还要考虑是否完成插入了，如果未完成（代表作为头部节点进入插入链，此时需要执行插入操作），如果完成了，说明同级模型中，存在相同实例，直接插入ID即可。如果不存在，直接执行插入操作
                            DWDatabaseResult * existResult =  [insertChains existRecordWithModel:value];
                            if (existResult.success) {
                                DWDatabaseOperationRecord * record = (DWDatabaseOperationRecord *)existResult.result;
                                ///获取一下表名数据库句柄，一会插入表或者更新表需要使用
                                DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:record.tblName].result;
                                
                                DWDatabaseBindKeyWrapperContainer subKeyToInsert = nil;
                                if (tblConf) {
                                    subKeyToInsert = [self actualSubKeyWrappersIn:subKeyWrappers withPrefix:obj.name];
                                    ///没有指定二级属性，则按需要插入全部属性计算
                                    if (!subKeyToInsert.count) {
                                        subKeyToInsert = [self saveKeysWrappersWithCls:obj.cls];
                                    }
                                }
                                
                                ///存在记录的话，看看这个模型是否已经被插入到表中，如果已经插入，按需走更新，如果没有则插入。
                                if (!record.finishOperationInChain) {
                                    ///这里为空，有两种情况，一种是tblConf获取失败，也就是表名数据库句柄获取失败，那么此嵌套模型将无法入库，故此模型放弃操作。另一种可能是没有指定二级属性，且获取的兜底策略插入所有入库属性，但是入库属性也没有获取到，所以也导致模型无法入库，故此模型也放弃操作。
                                    if (!subKeyToInsert.count) {
                                        return ;
                                    }
                                    
                                    ///到这里，已经确定好本属性作为模型，要插入的属性了，接下来看下本属性作为模型，已经插入的属性是哪些，排除掉这些属性，插入其他待补充的属性
                                    [self supplyModelSubKeys:value withPropertyInfo:obj propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers subkeyToInsert:subKeyToInsert.allKeys record:record conf:tblConf insertChains:insertChains validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                                } else {
                                    ///走到这，说明这个模型其实已经如果库了，那么则将其ID作为插入值更新，同时还要看这个模型本身是否字段已经插入完整，如果不完整，这里需要补一下
                                    NSNumber * Dw_id = Dw_idFromModel(value);
                                    if (Dw_id) {
                                        [validKeys addObject:propertyTblName];
                                        [args addObject:Dw_id];
                                    }
                                    ///就算完成了，这里也要走更新逻辑，看看有没有要补充的key
                                    if (!subKeyToInsert.count) {
                                        ///这里为空的原因同上，如果为空的话，也没有办法更新其他字段，故直接返回
                                        return ;
                                    }
                                    
                                    ///开始更新二级字段
                                    [self updateModelSubKeys:value propertyInfo:obj subKeyWrappers:subKeyWrappers subkeyToInsert:subKeyToInsert.allKeys record:record conf:tblConf insertChains:insertChains validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                                }
                            } else {
                                ///开始插入二级模型
                                [self insertNotExistModel:value propertyInfo:obj dbName:dbName tblName:tblName propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers insertChains:insertChains inlineTblNameMap:inlineTblNameMap validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
                            }
                        }
                    } else {
                        ///非递归模式下，看当前要插入的值是否包含Dw_id，如果包含则用这个ID做更新
                        if ([model isKindOfClass:[NSNumber class]]) {
                            [validKeys addObject:propertyTblName];
                            [args addObject:model];
                        } else {
                            NSNumber * Dw_id = Dw_idFromModel(model);
                            if (Dw_id) {
                                [validKeys addObject:propertyTblName];
                                [args addObject:Dw_id];
                            }
                        }
                    }
                } else {
                    [validKeys addObject:propertyTblName];
                    [args addObject:value];
                }
            }
        }
    }];
}

-(void)supplyModelSubKeys:(NSObject *)model withPropertyInfo:(DWPrefix_YYClassPropertyInfo *)prop propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subkeyToInsert:(NSArray <NSString *>*)subKeyToInsert record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf insertChains:(DWDatabaseOperationChain *)insertChains validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    ///看一下有没有剩下的key需要补
    NSMutableSet * subKeyToInsertSet = [NSMutableSet setWithArray:subKeyToInsert];
    [subKeyToInsertSet minusSet:record.operatedKeys];
    ///有需要补的key
    if (subKeyToInsertSet.count) {
        ///开始补key
        [self supplySubKeysWithModel:model propertyInfo:prop propertyTblName:propertyTblName subKeyWrappers:subKeyWrappers subKeyToInsertSet:subKeyToInsertSet record:record conf:conf insertChains:insertChains validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
    } else {
        ///走到这，说明作为二级模型，虽然指定了插入的key，但是之前已经将这些key都插入过了，说明已经完整了，不需要再插了
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (Dw_id) {
            [validKeys addObject:propertyTblName];
            [args addObject:Dw_id];
        }
    }
}

-(void)supplySubKeysWithModel:(NSObject *)model propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subKeyToInsertSet:(NSSet *)subKeyToInsertSet record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf insertChains:(DWDatabaseOperationChain *)insertChains validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    NSArray * subKeyToInsert = [subKeyToInsertSet allObjects];
    ///插入之前，前在record中标记这些key已经在补的途中了，这样在递归下，相同的属性不会重复补充
    [record.operatedKeys addObjectsFromArray:subKeyToInsert];
    ///这里要绑定的不应该是真实的二级key，应该将subKey传递下去。如model.c.b.a，当插入C时，遍历C需要补充的字段是b，subKeyToInsert中的也是b，而事实上此时我们应该传递下去的是b.a，让为c补充b字段的时候，知道b应该插入的字段。
    NSMutableDictionary * subKeyRecursiveToInsert = [NSMutableDictionary dictionaryWithCapacity:0];
    [subKeyToInsert enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [subKeyRecursiveToInsert addEntriesFromDictionary:[self subKeyWrappersIn:subKeyWrappers withPrefix:prop.name actualSubKey:obj]];
    }];
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    maker.bindKeyWithWrappers(subKeyRecursiveToInsert);
    ///在表中插入此次要补的key。此处因为是finishOperationInChain为NO才会进入的分支，标志着本地中，一定没有这个模型的记录，所以此处一定是插入。
    DWDatabaseResult * result = [self dw_insertTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue insertChains:insertChains recursive:YES conditionMaker:maker];
    if (result.success) {
        [validKeys addObject:propertyTblName];
        [args addObject:result.result];
        ///标记一下，表中已经有这条记录了，之后针对这条记录的所有插入操作，均应降级成为更新操作
        record.finishOperationInChain = YES;
        objMap[prop.name] = model;
    } else {
        record.finishOperationInChain = NO;
        ///如果插入失败了，再将刚才因此添加的key移除
        [record.operatedKeys minusSet:subKeyToInsertSet];
    }
}

-(void)updateModelSubKeys:(NSObject *)model propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers subkeyToInsert:(NSArray <NSString *>*)subKeyToInsert record:(DWDatabaseOperationRecord *)record conf:(DWDatabaseConfiguration *)conf  insertChains:(DWDatabaseOperationChain *)insertChains validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    ///先计算是否有需要更新的字段，如果没有的话，此模型也就没有其他操作了
    NSMutableSet * subKeyToInsertSet = [NSMutableSet setWithArray:subKeyToInsert];
    [subKeyToInsertSet minusSet:record.operatedKeys];
    if (subKeyToInsertSet.count) {
        ///同样要先记录属性，避免递归
        subKeyToInsert = [subKeyToInsertSet allObjects];
        [record.operatedKeys addObjectsFromArray:subKeyToInsert];
        ///转化成为带subKey的属性字段
        NSMutableDictionary * subKeyRecursiveToInsert = [NSMutableDictionary dictionaryWithCapacity:0];
        [subKeyToInsert enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [subKeyRecursiveToInsert addEntriesFromDictionary:[self subKeyWrappersIn:subKeyWrappers withPrefix:prop.name actualSubKey:obj]];
        }];
        ///开始更新
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        maker.bindKeyWithWrappers(subKeyRecursiveToInsert);
        DWDatabaseResult * result = [self dw_updateTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue updateChains:insertChains recursive:YES conditionMaker:maker];
        if (!result.success) {
            ///如果插入失败了，再将刚才因此添加的key移除
            [record.operatedKeys minusSet:subKeyToInsertSet];
        }
    }
}

-(void)insertNotExistModel:(NSObject *)model propertyInfo:(DWPrefix_YYClassPropertyInfo *)prop dbName:(NSString *)dbName tblName:(NSString *)tblName propertyTblName:(NSString *)propertyTblName subKeyWrappers:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers insertChains:(DWDatabaseOperationChain *)insertChains inlineTblNameMap:(NSDictionary *)inlineTblNameMap validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    ///此处取嵌套模型对应地表名
    NSString * existTblName = [insertChains anyRecordInChainWithClass:prop.cls].tblName;
    NSString * inlineTblName = inlineModelTblName(prop, inlineTblNameMap, tblName,existTblName);
    if (inlineTblName.length) {
        ///开始准备插入模型，先获取库名数据库句柄
        DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
        ///建表
        if (dbConf && [self createTableWithClass:prop.cls tableName:inlineTblName configuration:dbConf].success) {
            ///获取表名数据库句柄
            DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName].result;
            
            DWDatabaseBindKeyWrapperContainer subKeyToInsert = nil;
            if (tblConf) {
                subKeyToInsert = [self subKeyWrappersIn:subKeyWrappers withPrefix:prop.name];
                ///没有指定二级属性，则按需要插入全部属性计算
                if (!subKeyToInsert.count) {
                    subKeyToInsert = [self saveKeysWrappersWithCls:prop.cls];
                }
            }
            
            if (!subKeyToInsert.count) {
                return;
            }
            
            DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
                maker.bindKeyWithWrappers(subKeyToInsert);
            };
            
            DWDatabaseResult * result = [self _entry_insertTableWithModel:model configuration:tblConf insertChains:insertChains recursive:YES condition:condition];
            ///如果成功，添加id
            if (result.success) {
                [validKeys addObject:propertyTblName];
                [args addObject:result.result];
                
                DWDatabaseOperationRecord * record = [insertChains recordInChainWithModel:model];
                record.finishOperationInChain = YES;
                objMap[prop.name] = model;
            }
        }
    }
}

@end
