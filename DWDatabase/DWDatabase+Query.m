//
//  DWDatabase+Query.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+Query.h"
#import "DWDatabaseFunction.h"
#import "DWDatabaseConditionMaker+Private.h"
#define kQueryPrefix (@"q")

typedef NSError *(^DWDatabaseResultSetHandler)(Class cls,FMResultSet * set,NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*validProInfos,NSArray <NSString *>* subKeyArr,NSDictionary * databaseMap,NSMutableArray * resultArr,DWDatabaseOperationChain * queryChains,BOOL recursive,NSDictionary * inlineTblNameMap,BOOL * stop,BOOL * returnNil);
@implementation DWDatabase (Query)

#pragma mark --- interface method ---
-(DWDatabaseResult *)_entry_queryTableWithClass:(Class)clazz limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending configuration:(DWDatabaseConfiguration *)conf queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition reprocessing:(DWDatabaseReprocessingHandler)reprocessing {
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
    
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:conf.dbQueue queryChains:queryChains recursive:recursive conditionMaker:maker reprocessing:reprocessing];
}

-(DWDatabaseResult *)_entry_queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
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
    
    ///如果外部传入，则获取外部传入需要获取的key，其他细节抛弃即可
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    if (condition) {
        condition(maker);
    }
    NSMutableArray * bindKeys = maker.bindKeys;
    [maker reset];
    maker.loadClass(cls);
    maker.conditionWith(kUniqueID).equalTo(Dw_id);
    maker.bindKeysWithArray(bindKeys);
    
    result = [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:queryChains recursive:recursive conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSArray<NSString *> *subKeyArr, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive, NSDictionary *inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        DWDatabaseResult * result = [self handleQueryResultWithClass:cls dbName:conf.dbName tblName:conf.tableName resultSet:set validProInfos:validProInfos subKeyArr:subKeyArr databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:stop returnNil:returnNil stopOnValidValue:YES reprocessing:nil];
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

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker reprocessing:(DWDatabaseReprocessingHandler)reprocessing {

    return [self dw_queryTableWithDbName:dbName tableName:tblName limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:queue queryChains:queryChains recursive:recursive conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSArray<NSString *> *subKeyArr, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive, NSDictionary *inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        DWDatabaseResult * result = [self handleQueryResultWithClass:cls dbName:dbName tblName:tblName resultSet:set validProInfos:validProInfos subKeyArr:subKeyArr databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:stop returnNil:returnNil stopOnValidValue:NO reprocessing:reprocessing];
        if (result.success) {
            return nil;
        } else {
            return result.error;
        }
    }];
}

-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive conditionMaker:(DWDatabaseConditionMaker *)maker resultSetHandler:(DWDatabaseResultSetHandler)handler {
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
    
    DWDatabaseResult * result = [self querySQLFactoryWithTblName:tblName limit:limit offset:offset orderKey:orderKey ascending:ascending conditionMaker:maker];
    if (!result.success) {
        return result;
    }
    
    if (!queryChains && recursive) {
        queryChains = [DWDatabaseOperationChain new];
    }
    
    ///组装数组
    DWDatabaseSQLFactory * fac = result.result;
    NSDictionary * validPropertyInfo = fac.validPropertyInfos;
    Class cls = fac.clazz;
    NSDictionary * dbTransformMap = fac.dbTransformMap;
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    NSArray * subKeyArr = fac.subKeyArr;
    result.result = nil;
    result.success = YES;
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
                     result.error = handler(cls,set,validPropertyInfo,subKeyArr,dbTransformMap,resultArr,queryChains,recursive,inlineTblNameMap,&stop,&returnNil);
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
    
    return [self handleQueryRecursiveResultWithDbName:dbName tblName:tblName resultArr:resultArr queryChains:queryChains recursive:recursive subKeyArr:subKeyArr];
}

-(DWDatabaseResult *)dw_queryTableForCountWithDbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue conditionMaker:(DWDatabaseConditionMaker *)maker {
    if (!maker) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    ///查询个数的话，只查询ID即可
    [maker.bindKeys removeAllObjects];
    [maker.bindKeys addObject:kUniqueID];
    DWDatabaseResult * result = [self dw_queryTableWithDbName:dbName tableName:tblName limit:0 offset:0 orderKey:nil ascending:YES inQueue:queue queryChains:nil recursive:NO conditionMaker:maker resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSArray<NSString *> *subKeyArr, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive, NSDictionary *inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
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

-(DWDatabaseResult *)handleQueryResultWithClass:(Class)cls dbName:(NSString *)dbName tblName:(NSString *)tblName resultSet:(FMResultSet *)set validProInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)validProInfos subKeyArr:(NSArray <NSString *>*)subKeyArr databaseMap:(NSDictionary *)databaseMap resultArr:(NSMutableArray *)resultArr queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive inlineTblNameMap:(NSDictionary *)inlineTblNameMap stop:(BOOL *)stop returnNil:(BOOL *)returnNil stopOnValidValue:(BOOL)stopOnValidValue reprocessing:(DWDatabaseReprocessingHandler)reprocessing {
    if (cls == NULL) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        *stop = YES;
        *returnNil = YES;
        return [DWDatabaseResult failResultWithError:err];
    }
    
    id tmp = nil;
    NSNumber * Dw_id = [set objectForColumn:kUniqueID];
    if (!Dw_id) {
        NSError * err = errorWithMessage(@"Invalid Query Operation which Dw_id is Nil.", 10027);
        *stop = YES;
        *returnNil = YES;
        return [DWDatabaseResult failResultWithError:err];;
    }
    
    ///这里从查询链中取出当前查询ID对应的模型，因为最后应保证对应唯一查询ID只有一个唯一模型，因为不同属性同种类名和同种ID应该为模型嵌套的结果，故应该保证实例只有一个。
    DWDatabaseResult * existRecordResult = [queryChains existRecordWithClass:cls Dw_Id:Dw_id];
    DWDatabaseOperationRecord * record = nil;
    if (existRecordResult.success) {
        record = existRecordResult.result;
        tmp = record.model;
    } else {
        tmp = [cls new];
        SetDw_idForModel(tmp, Dw_id);
    }
    
    __block BOOL validValue = NO;
        
    if (recursive) {
        ///这里记录查询结果
        if (!existRecordResult.success) {
            record = [DWDatabaseOperationRecord new];
            record.model = tmp;
            record.operation = DWDatabaseOperationQuery;
            record.tblName = tblName;
            record.operatedKeys = [NSMutableSet setWithArray:validProInfos.allKeys];
            [queryChains addRecord:record];
        } else {
            record = existRecordResult.result;
            NSMutableSet * keyToQuerySet = [NSMutableSet setWithArray:validProInfos.allKeys];
            [keyToQuerySet minusSet:record.operatedKeys];
            ///如果已经查询的结果覆盖了将要查询的结果，则认为此次查询已经完成
            if (keyToQuerySet.count == 0) {
                validValue = YES;
            }
        }
        
        ///这里新生成一个record实例，此处的实例为记录未完成的属性的实例，并不存入queryChains
        record = [DWDatabaseOperationRecord new];
        record.model = tmp;
        record.finishOperationInChain = YES;
    }
    
    if (!validValue) {
        SetDbNameForModel(tmp, dbName);
        SetTblNameForModel(tmp, tblName);
        
        NSMutableDictionary * unhandledPros = nil;
        if (recursive) {
            unhandledPros = [NSMutableDictionary dictionaryWithCapacity:0];
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
                            ///这个数据查过，可以赋值，但是要考虑查过的值是否够，不够的话，要继续查
                            if (existRecordResult.success) {
                                DWDatabaseOperationRecord * existRecord = existRecordResult.result;
                                [tmp setValue:existRecord.model forKey:obj.name];
                                ///借用这个标志位记录至少有一个可选值
                                validValue = YES;
                                record.operation = DWDatabaseOperationQuery;
                                
                                ///看看查询的键值够不够，不够还得补
                                NSArray * subKeyToQuery = [self actualSubKeysIn:subKeyArr withPrefix:obj.name];
                                if (subKeyToQuery.count) {
                                    NSMutableSet * subKeyToQuerySet = [NSMutableSet setWithArray:subKeyToQuery];
                                    [subKeyToQuerySet minusSet:existRecord.operatedKeys];
                                    ///键值不够，开始补
                                    if (subKeyToQuerySet.count > 0) {
                                        NSString * tblName = TblNameFromModel(existRecord.model);
                                        if (tblName.length) {
                                            DWDatabaseOperationRecord * result = [DWDatabaseOperationRecord new];
                                            result.model = obj;
                                            result.userInfo = value;
                                            ///这里unhandledPros用tblName记录，这样后续补的时候直接可以取出内料表名
                                            [unhandledPros setValue:result forKey:tblName];
                                            record.keysToQuery = [subKeyToQuerySet allObjects];
                                            ///不足，计算完需要补充的key后，告诉外界这里还没结束，需要补充
                                            if (record.finishOperationInChain) {
                                                record.finishOperationInChain = NO;
                                            }
                                        }
                                    }
                                }
                            } else {
                                ///不存在就很明显，就应该去查
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
    }
    
    if (validValue) {
        if (recursive) {
            [resultArr addObject:record];
        } else {
            if (reprocessing) {
                reprocessing(tmp,set);
            }
            [resultArr addObject:tmp];
        }
        if (stopOnValidValue) {
            *stop = YES;
        }
    }
    return [DWDatabaseResult successResultWithResult:nil];
}

-(DWDatabaseResult *)handleQueryRecursiveResultWithDbName:(NSString *)dbName tblName:(NSString *)tblName resultArr:(NSMutableArray *)resultArr queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive subKeyArr:(NSArray<NSString *> *)subKeyArr {
    ///如果是递归模式的话，这里resultArr记录的是record，表名当前模型是否查询完毕
    if (recursive) {
        NSMutableArray * tmp = [NSMutableArray arrayWithCapacity:resultArr.count];
        [resultArr enumerateObjectsUsingBlock:^(DWDatabaseOperationRecord * obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSObject * model = obj.model;
            ///如果结果被标记已经查询完成了，代表接过已经合法了，直接放在数组里就行
            if (obj.finishOperationInChain) {
                [tmp addObject:model];
            } else {
                ///没有完成的话，就要看到底是那些属性没有完成，一般情况下，这些属性应该都是嵌套的模型
                NSDictionary <NSString *,DWDatabaseOperationRecord *>* pros = (NSDictionary *)obj.userInfo;
                DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName].result;
                if (!dbConf) {
                    ///没有dbConf，说明无法补充嵌套值，这时候看下有没有已经有的有效值，如果有，证明此模型合法，添加至结果数组
                    if (obj.operation == DWDatabaseOperationQuery) {
                        [tmp addObject:model];
                    }
                    return ;
                }
                __block BOOL hasValue = NO;
                
                ///开始补属性
                [pros enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseOperationRecord * _Nonnull aObj, BOOL * _Nonnull stop) {
                    ///建表成功
                    DWPrefix_YYClassPropertyInfo * prop = aObj.model;
                    NSNumber * value = aObj.userInfo;
                    ///拿待补属性信息及Dw_id，并按需建表
                    if (prop && value && [self createTableWithClass:prop.cls tableName:key configuration:dbConf].success) {
                        ///获取表名数据库句柄
                        DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:key].result;
                        if (tblConf) {
                            ///取出需要查询的key。由于查询是先查询完自身的逻辑，故当前仅当对象A持有对象A自身的时候会遇到嵌套结构，这时候有可能取到二重属性较自身额外的查询属性，所以直接查找以录得属性即可。其他情况下，keysToQuery为空。
                            NSArray * subKeys = aObj.keysToQuery;
                            if (!subKeys) {
                                subKeys = [self subKeysIn:subKeyArr withPrefix:prop.name];
                            } else {
                                aObj.keysToQuery = nil;
                            }
                            
                            DWDatabaseConditionHandler condition = nil;
                            if (subKeys.count) {
                                condition = ^(DWDatabaseConditionMaker * maker) {
                                    maker.bindKeysWithArray(subKeys);
                                };
                            }
                            
                            DWDatabaseResult * result = [self _entry_queryTableWithClass:prop.cls Dw_id:value queryChains:queryChains recursive:recursive configuration:tblConf condition:condition];
                            if (result.success && result.result) {
                                [model setValue:result.result forKey:prop.name];
                                hasValue = YES;
                            }
                        }
                    }
                }];
                
                ///这里补属性成功，或者原本就有查询成功的值，都认为他是有效值
                if (hasValue || obj.operation == DWDatabaseOperationQuery) {
                    [tmp addObject:model];
                }
            }
        }];
        resultArr = tmp;
    }
    
    DWDatabaseResult * result = [DWDatabaseResult successResultWithResult:resultArr];
    if (!resultArr.count) {
        result.error = errorWithMessage(@"There's no result with this conditions", 10011);
    }
    return result;
}

#pragma mark --- tool method ---
-(DWDatabaseResult *)querySQLFactoryWithTblName:(NSString *)tblName limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending conditionMaker:(DWDatabaseConditionMaker *)maker {
    
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
    NSArray * keys = [maker fetchBindKeys];
    NSArray * seperateKeys = [self seperateSubKeys:keys];
    keys = seperateKeys.firstObject;
    BOOL queryAll = NO;
    ///如果keys为空则试图查询cls与表对应的所有键值
    BOOL hasDw_id = NO;
    if (!keys.count) {
        keys = [DWDatabase propertysToSaveWithClass:cls];
        ///如果所有键值为空则返回空
        if (!keys.count) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008)];
        }
        queryAll = YES;
    } else {
        ///如果不为空，则将keys与对应键值做交集
        hasDw_id = [keys containsObject:kUniqueID];
        keys = intersectionOfArray(keys, saveKeys);
        ///如果没有有效查询键值则抛出异常，这里要对kUniqueID做处理，因为saveKeys中可能不包含kUniqueID，所以交集后kUniqueID可能会屏蔽，要补充
        if (!keys.count && !hasDw_id) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008)];
        }
    }
    
    NSMutableArray * validQueryKeys = [NSMutableArray arrayWithCapacity:0];
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*queryKeysProInfos = [DWDatabase propertyInfosWithClass:cls keys:keys];
    
    if (!queryKeysProInfos.allKeys.count && !hasDw_id) {
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
        if (validQueryKeys.count == 1 && !hasDw_id) {
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
    fac.subKeyArr = seperateKeys.lastObject;
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
