//
//  DWDatabase+Query.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Query.h"
#import "DWDatabaseFunction.h"

#define kQueryPrefix (@"q")

@implementation DWDatabase (Query)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_queryTableWithClass:(Class)clazz keys:(NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending configuration:(DWDatabaseConfiguration *)conf queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    if (!clazz && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    Class cls = [maker fetchQueryClass];
    if (!cls) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:conf.dbQueue queryChains:queryChains recursive:recursive conditionMaker:maker];
}

-(DWDatabaseResult *)_entry_queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id keys:(NSArray<NSString *> *)keys queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    if (!Dw_id) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Dw_id who is Nil.", 10018)];
    }
    
    if (!cls) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
        maker.loadClass(cls);
        maker.conditionWith(kUniqueID).equalTo(Dw_id);
    };
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    
    result = [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:queryChains recursive:recursive conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive,NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        DWDatabaseResult * result = [self handleQueryResultWithClass:cls dbName:conf.dbName tblName:conf.tableName resultSet:set validProInfos:validProInfos databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:stop returnNil:returnNil stopOnValidValue:YES];
        if (result.success) {
            return nil;
        } else {
            return result.error;
        }
    }];
    
    if (!result.success) {
        return result;
    }
    
    NSArray * ret = result.result;
    result.result = ret.lastObject;
    
    return result;
}

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker {

    return [self dw_queryTableWithDbName:dbName tableName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:queue queryChains:queryChains recursive:recursive conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive ,NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        DWDatabaseResult * result = [self handleQueryResultWithClass:cls dbName:dbName tblName:tblName resultSet:set validProInfos:validProInfos databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:stop returnNil:returnNil stopOnValidValue:NO];
        if (result.success) {
            return nil;
        } else {
            return result.error;
        }
    }];
}

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker resultSetHandler:(NSError *(^)(Class cls,FMResultSet * set,NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*validProInfos,NSDictionary * databaseMap,NSMutableArray * resultArr,DWDatabaseOperationChain * queryChains,BOOL recursive,NSDictionary * inlineTblNameMap,BOOL * stop,BOOL * returnNil))handler {
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    ///嵌套查询的思路：
    ///先将按指定条件查询符合条件的跟模型。在遍历模型属性给结果赋值时，检测赋值属性是否为对象类型。因为如果为对象类型，通过property将无法赋值成功。此时将这部分未赋值成功的属性值记录下来并标记为未完成状态。当根模型有效值赋值完成时，遍历结果集，如果有未完成状态的模型，则遍历模型未赋值成功的属性，尝试赋值。同插入一样，要考虑死循环的问题，所以查询前先校验查询链。此处将状态记录下来在所有根结果查询完成后在尝试赋值对象属性还有一个原因是，如果想要在为每个结果的属性赋值同时完成对象类型的查询，会由于队里造成死锁，原因是查询完成赋值在dbQueue中，但在赋值同时进行查询操作，会同步在dbQueue中再次派发至dbQueue，造成死锁。
    
    DWDatabaseResult * result = [self querySQLFactoryWithTblName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending conditionMaker:maker];
    if (!result.success) {
        return result;
    }
    
    if (!queryChains && recursive) {
        queryChains = [DWDatabaseOperationChain new];
    }
    
    ///组装数组
    DWDatabaseSQLFactory * fac = result.result;
    result.result = nil;
    result.success = YES;
    
    NSDictionary * validPropertyInfo = fac.validPropertyInfos;
    Class cls = fac.clazz;
    NSDictionary * dbTransformMap = fac.dbTransformMap;
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSMutableArray * resultArr = [NSMutableArray arrayWithCapacity:0];
    __block BOOL returnNil = NO;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            FMResultSet * set = [db executeQuery:fac.sql withArgumentsInArray:fac.args];
            result.error = db.lastError;
            ///获取带转换的属性
            BOOL stop = NO;
            while ([set next]) {
                if (handler) {
                     result.error = handler(cls,set,validPropertyInfo,dbTransformMap,resultArr,queryChains,recursive,inlineTblNameMap,&stop,&returnNil);
                }
                if (stop) {
                    break;
                }
            }
            [set close];
        }];
    });

    if (returnNil) {
        result.success = NO;
        return nil;
    }
    
    return [self handleQueryRecursiveResultWithDbName:dbName tblName:tblName resultArr:resultArr queryChains:queryChains recursive:recursive];
}

-(DWDatabaseResult *)dw_queryTableForCountWithDbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue conditionMaker:(DWDatabaseConditionMaker *)maker {
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    DWDatabaseResult * result = [self dw_queryTableWithDbName:dbName tableName:tblName keys:nil limit:0 offset:0 orderKey:nil ascending:YES inQueue:queue queryChains:nil recursive:NO conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive, NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        [resultArr addObject:@1];
        return nil;
    }];
    
    if (!result.success) {
        return result;
    }
    
    NSArray * ret = result.result;
    result.result = @(ret.count);
    return result;
}

-(DWDatabaseResult *)handleQueryResultWithClass:(Class)cls dbName:(NSString *)dbName tblName:(NSString *)tblName resultSet:(FMResultSet *)set validProInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)validProInfos databaseMap:(NSDictionary *)databaseMap resultArr:(NSMutableArray *)resultArr queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive inlineTblNameMap:(NSDictionary *)inlineTblNameMap stop:(BOOL *)stop returnNil:(BOOL *)returnNil stopOnValidValue:(BOOL)stopOnValidValue {
    id tmp = [cls new];
    if (!tmp) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        *stop = YES;
        *returnNil = YES;
        return [DWDatabaseResult failResultWithError:err];
    }
    
    NSNumber * Dw_id = [set objectForColumn:kUniqueID];
    if (Dw_id) {
        SetDw_idForModel(tmp, Dw_id);
        if (recursive) {
            DWDatabaseOperationRecord * record = [DWDatabaseOperationRecord new];
            record.model = tmp;
            record.operation = DWDatabaseOperationQuery;
            record.tblName = tblName;
            [queryChains addRecord:record];
        }
    }
    SetDbNameForModel(tmp, dbName);
    SetTblNameForModel(tmp, tblName);
    
    __block BOOL validValue = NO;
    NSMutableDictionary * unhandledPros = nil;
    DWDatabaseOperationRecord * record = nil;
    
    if (recursive) {
        unhandledPros = [NSMutableDictionary dictionaryWithCapacity:0];
        record = [DWDatabaseOperationRecord new];
        record.model = tmp;
        record.finishOperationInChain = YES;
        record.userInfo = unhandledPros;
    }
    
    [validProInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name.length) {
            NSString * name = propertyInfoTblName(obj, databaseMap);
            if (name.length) {
                id value = [set objectForColumn:name];
                ///这里考虑对象嵌套
                if (obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                    if (recursive && [value isKindOfClass:[NSNumber class]]) {
                        DWDatabaseResult * existRecordResult = [queryChains existRecordWithClass:obj.cls Dw_Id:value];
                        ///这个数据查过，直接赋值
                        if (existRecordResult.success) {
                            DWDatabaseOperationRecord * existRecord = existRecordResult.result;
                            [tmp setValue:existRecord.model forKey:obj.name];
                            validValue = YES;
                            ///借用这个标志位记录至少有一个可选值
                            record.operation = DWDatabaseOperationQuery;
                        } else {
                            ///此处取嵌套模型对应地表名
                            NSString * existTblName = [queryChains anyRecordInChainWithClass:obj.cls].tblName;
                            NSString * inlineTblName = inlineModelTblName(obj, inlineTblNameMap, tblName,existTblName);
                            if (inlineTblName.length) {
                                DWDatabaseOperationRecord * result = [DWDatabaseOperationRecord new];
                                result.model = obj;
                                result.userInfo = value;
                                [unhandledPros setValue:result forKey:inlineTblName];
                                if (record.finishOperationInChain) {
                                    record.finishOperationInChain = NO;
                                }
                            }
                        }
                    }
                } else {
                    [tmp dw_setValue:value forPropertyInfo:obj];
                    record.operation = DWDatabaseOperationQuery;
                    validValue = YES;
                }
            }
        }
    }];
    
    if (validValue) {
        if (recursive) {
            [resultArr addObject:record];
        } else {
            [resultArr addObject:tmp];
        }
        if (stopOnValidValue) {
            *stop = YES;
        }
    }
    return [DWDatabaseResult successResultWithResult:nil];
}

-(DWDatabaseResult *)handleQueryRecursiveResultWithDbName:(NSString *)dbName tblName:(NSString *)tblName resultArr:(NSMutableArray *)resultArr queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive {
    if (recursive) {
        NSMutableArray * tmp = [NSMutableArray arrayWithCapacity:resultArr.count];
        for (NSInteger i = 0; i < resultArr.count; i++) {
            DWDatabaseOperationRecord * obj = resultArr[i];
            NSObject * model = obj.model;
            if (obj.finishOperationInChain) {
                [tmp addObject:model];
            } else {
                NSDictionary <NSString *,DWDatabaseOperationRecord *>* pros = (NSDictionary *)obj.userInfo;
                DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
                if (!dbConf) {
                    ///没有dbConf，说明无法补充嵌套值，这时候看下有没有已经有的有效值，如果有，证明此模型合法，添加至结果数组
                    if (obj.operation == DWDatabaseOperationQuery) {
                        [tmp addObject:model];
                    }
                    continue;
                }
                __block BOOL hasValue = NO;
                [pros enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseOperationRecord * _Nonnull aObj, BOOL * _Nonnull stop) {
                    ///建表成功
                    DWPrefix_YYClassPropertyInfo * prop = aObj.model;
                    NSNumber * value = aObj.userInfo;
                    if (prop && value && [self createTableWithClass:prop.cls tableName:key configuration:dbConf].success) {
                        ///获取表名数据库句柄
                        DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:key].result;
                        if (tblConf) {
                            ///插入
                            DWDatabaseResult * result = [self _entry_queryTableWithClass:prop.cls Dw_id:value keys:nil queryChains:queryChains recursive:recursive configuration:tblConf];
                            if (result.success && result.result) {
                                [model setValue:result.result forKey:prop.name];
                                hasValue = YES;
                            }
                        }
                    }
                }];
                
                if (hasValue) {
                    [tmp addObject:model];
                }
            }
        }
        
        resultArr = tmp;
    }
    
    DWDatabaseResult * result = [DWDatabaseResult successResultWithResult:resultArr];
    if (!resultArr.count) {
        result.error = errorWithMessage(@"There's no result with this conditions", 10011);
    }
    return result;
}

#pragma mark --- tool method ---
-(DWDatabaseResult *)querySQLFactoryWithTblName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending conditionMaker:(DWDatabaseConditionMaker *)maker {
    
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    ///获取条件字段组并获取本次的class
    Class cls = [maker fetchQueryClass];
    if (!cls) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithTblName:tblName propertyInfos:propertyInfos databaseMap:map enableSubProperty:YES];
    [maker make];
    
    NSArray * args = [maker fetchArguments];
    NSArray * conditionStrings = [maker fetchConditions];
    NSArray * validConditionKeys = [maker fetchValidKeys];
    NSArray * joinTables = [maker fetchJoinTables];
    
    BOOL queryAll = NO;
    ///如果keys为空则试图查询cls与表对应的所有键值
    if (!keys.count) {
        keys = [DWDatabase propertysToSaveWithClass:cls];
        ///如果所有键值为空则返回空
        if (!keys.count) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008)];
        }
        queryAll = YES;
    } else {
        ///如果不为空，则将keys与对应键值做交集
        keys = intersectionOfArray(keys, saveKeys);
        if (!keys.count) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008)];
        }
    }
    
    NSMutableArray * validQueryKeys = [NSMutableArray arrayWithCapacity:0];
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*queryKeysProInfos = [DWDatabase propertyInfosWithClass:cls keys:keys];
    
    if (!queryKeysProInfos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid key to query.",NSStringFromClass(cls)];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    ///获取查询字符串数组
    if (queryAll) {
        [validQueryKeys addObject:@"*"];
    } else {
        if (![validQueryKeys containsObject:kUniqueID]) {
            [validQueryKeys addObject:kUniqueID];
        }
        [self handleQueryValidKeysWithPropertyInfos:queryKeysProInfos map:map validKeysContainer:validQueryKeys];
        if (validQueryKeys.count == 1) {
            NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid keys to query.",NSStringFromClass(cls)];
            return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
        }
    }
    
    ///如果无查询参数置为nil方便后面直接传参
    if (!args.count) {
        args = nil;
    }
    
    ///获取所有关键字段组
    NSMutableArray * validKeys = [NSMutableArray arrayWithArray:validQueryKeys];
    [validKeys addObjectsFromArray:validConditionKeys];
    
    NSString * sql = nil;
    ///先尝试取缓存的sql(这里要考虑数组顺序的影响，由于validQueryKeys是由字典遍历后过滤得来的，所以顺序可以保证。conditionStrings为查询条件字段，由于目前只能从maker中获取，故顺序收maker中编写顺序影响，故应对conditionStrings做排序后再行拼装)
    ///获取sql拼装数组
    NSArray * sqlCombineArray = combineArrayWithExtraToSort(validQueryKeys,conditionStrings);
    if (joinTables.count) {
        sqlCombineArray = combineArrayWithExtraToSort(sqlCombineArray, joinTables);
    }
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kQueryPrefix class:cls tblName:tblName keys:sqlCombineArray];
    
    ///有排序添加排序
    NSString * orderField = nil;
    if (orderKey.length && [saveKeys containsObject:orderKey]) {
        DWPrefix_YYClassPropertyInfo * prop = [[DWDatabase propertyInfosWithClass:cls keys:@[orderKey]] valueForKey:orderKey];
        if (prop) {
            NSString * field = propertyInfoTblName(prop, map);
            if (field.length) {
                orderField = field;
            }
        }
    }
    
    ///如果排序键不合法，则以Dw_id为排序键
    if (!orderField.length) {
        orderField = kUniqueID;
    }
    
    if (joinTables.count) {
        orderField = [NSString stringWithFormat:@"%@.%@",tblName,orderField];
    }
    
    cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-%@-%@",orderField,ascending?@"ASC":@"DESC"]];
    
    if (limit > 0) {
        cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-L%lu",(unsigned long)limit]];
    }
    if (offset > 0) {
        cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-O%lu",(unsigned long)offset]];
    }
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        
        ///条件查询模式，所有值均为查询值，故将条件值加至查询数组
        NSMutableArray * actualQueryKeys = [NSMutableArray arrayWithArray:validQueryKeys];
        if (!queryAll) {
            ///去重添加
            [validConditionKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (![actualQueryKeys containsObject:obj]) {
                    [actualQueryKeys addObject:obj];
                }
            }];
        }
        
        if (joinTables.count > 0) {
            NSMutableArray * tmp = [NSMutableArray arrayWithCapacity:actualQueryKeys.count];
            [actualQueryKeys enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [tmp addObject:[NSString stringWithFormat:@"%@.%@",tblName,obj]];
            }];
            actualQueryKeys = tmp;
        }
        
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"SELECT %@ FROM %@",[actualQueryKeys componentsJoinedByString:@","],tblName];
        
        if (joinTables.count > 0) {
            sql = [sql stringByAppendingFormat:@" %@",[joinTables componentsJoinedByString:@" "]];
        }
        
        ///如果有有效条件时拼装条件值，若无有效条件时且有有效条件字典时拼装有效条件字符串
        if (conditionStrings.count) {
            sql = [sql stringByAppendingString:[NSString stringWithFormat:@" WHERE %@",[conditionStrings componentsJoinedByString:@" AND "]]];
        }
        
        ///有排序添加排序
        if (orderField.length) {
            sql = [sql stringByAppendingString:[NSString stringWithFormat:@" ORDER BY %@ %@",orderField,ascending?@"ASC":@"DESC"]];
        }
        if (limit > 0) {
            sql = [sql stringByAppendingString:[NSString stringWithFormat:@" LIMIT %lu",(unsigned long)limit]];
        }
        if (offset > 0) {
            sql = [sql stringByAppendingString:[NSString stringWithFormat:@" OFFSET %lu",(unsigned long)offset]];
        }
        
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setObject:sql forKey:cacheSqlKey];
        }
    }
    
    ///获取带转换的属性
    NSDictionary * validPropertyInfo = nil;
    if (queryAll) {
        validPropertyInfo = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    } else {
        validPropertyInfo = [DWDatabase propertyInfosWithClass:cls keys:validKeys];
    }
    
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    fac.args = args;
    fac.clazz = cls;
    fac.validPropertyInfos = validPropertyInfo;
    fac.dbTransformMap = map;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(void)handleQueryValidKeysWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props map:(NSDictionary *)map validKeysContainer:(NSMutableArray *)validKeys {

    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name.length) {
            NSString * name = propertyInfoTblName(obj, map);
            if (name.length) {
                [validKeys addObject:name];
            }
        }
    }];
}

@end
