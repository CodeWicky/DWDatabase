//
//  DWDatabase.m
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "DWDatabase.h"
#import <Foundation/NSZone.h>
#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabase+Private.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase+CreateTable.h"
#import "DWDatabase+Insert.h"
#import "DWDatabase+Delete.h"
#import "DWDatabase+Update.h"
#import "DWDatabase+Query.h"
#import "DWDatabase+Supply.h"
#import "DWDatabaseConditionMaker+Private.h"


#define kSqlSetDbName (@"sql_set")
#define kSqlSetTblName (@"sql_set")

@interface DWDatabase ()

///数据库路径缓存，缓存当前所有数据库路径
@property (nonatomic ,strong) NSMutableDictionary * allDBs_prv;

///私有FMDatabaseQueue，用于读取或更新本地表配置，于 -initializeDBWithError: 时被赋值
@property (nonatomic ,strong) FMDatabaseQueue * privateQueue;

@property (nonatomic ,strong) NSCache * saveKeysCache;

///是否成功配置过的标志位
@property (nonatomic ,assign) BOOL hasInitialize;

///数据库操作队列
@property (nonatomic ,strong) dispatch_queue_t dbOperationQueue;

@end

///数据库类
@implementation DWDatabase

#pragma mark --- interface method ---
-(DWDatabaseResult *)initializeDB {
    if (self.hasInitialize) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    ///首次启动时还没有沙盒地址，此时需要调用一下才能创建出来
    if (![[NSFileManager defaultManager] fileExistsAtPath:defaultSavePath()]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:defaultSavePath() withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    ///私有表地址（用于存储数据库信息）
    NSString * savePath = [defaultSavePath() stringByAppendingPathComponent:@".private/privateInfo.sqlite"];
    self.privateQueue = [self openDBQueueWithName:nil path:savePath private:YES];
    if (!self.privateQueue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid path which FMDatabaseQueue could not open.", 10003)];
    }
    
    DWDatabaseResult * result = [self dw_createTableWithClass:[DWDatabaseInfo class] tableName:kSqlSetTblName inQueue:self.privateQueue];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
        maker.loadClass([DWDatabaseInfo class]);
    };
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    NSArray <DWDatabaseInfo *>* res = [self dw_queryTableWithDbName:kSqlSetDbName tableName:kSqlSetTblName limit:0 offset:0 orderKey:nil ascending:YES inQueue:self.privateQueue queryChains:nil recursive:NO conditionMaker:maker reprocessing:nil].result;
    if (res.count) {
        ///取出以后配置数据库完整地址
        [res enumerateObjectsUsingBlock:^(DWDatabaseInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj configDBPath] && obj.dbPath.length && obj.dbName.length) {
                [self.allDBs_prv setValue:obj.dbPath forKey:obj.dbName];
            }
        }];
    }
    if (result.success) {
        self.hasInitialize = YES;
    }
    return result;
}

-(DWDatabaseResult *)fetchDBConfigurationAutomaticallyWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path {
    DWDatabaseResult * result = [self initializeDB];
    if (!result.success) {
        return result;
    }
    result = [self configDBIfNeededWithClass:cls name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationWithName:name tabelName:tblName].result;
    result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    return [DWDatabaseResult successResultWithResult:conf];
}

-(DWDatabaseResult *)configDBIfNeededWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path {
    if (cls == Nil) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    
    DWDatabaseResult * result = [self configDBIfNeededWithName:name path:path];
    if (!result.success) {
        return result;
    }

    DWDatabaseConfiguration * conf = [self fetchDBConfigurationWithName:name].result;
    result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    result = [self isTableExistWithTableName:tblName configuration:conf];
    if (result.success) {
        return result;
    }
    return [self createTableWithClass:cls tableName:tblName configuration:conf];
}

-(DWDatabaseResult *)insertTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }
    return [self dw_insertTableWithModel:model dbName:name tableName:tblName inQueue:conf.dbQueue insertChains:nil recursive:YES conditionMaker:maker];
}

-(DWDatabaseResult *)deleteTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path condition:(DWDatabaseConditionHandler)condition {
    
    if (!model && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model and condition which both are nil.", 10016)];
    }
    
    if (condition) {
        
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        condition(maker);
        Class cls = [maker fetchQueryClass];
        if (!cls) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid condition who hasn't load class.", 10017)];
        }
        
        DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:cls name:name tableName:tblName path:path];
        if (!result.success) {
            return result;
        }
        
        DWDatabaseConfiguration * conf = result.result;
        return [self dw_deleteTableWithModel:nil dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue deleteChains:nil recursive:NO conditionMaker:maker];
        
    } else {
        
        DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
        if (!result.success) {
            return result;
        }
        DWDatabaseConfiguration * conf = result.result;
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (!Dw_id) {
            return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
        }
        
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass([model class]);
            maker.conditionWith(kUniqueID).equalTo(Dw_id);
        };
        
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        condition(maker);
        
        return [self dw_deleteTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue deleteChains:nil recursive:YES conditionMaker:maker];
    }
}

-(DWDatabaseResult *)updateTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }
    return [self dw_updateTableWithModel:model dbName:name tableName:tblName inQueue:conf.dbQueue updateChains:nil recursive:YES updateObjectID:NO conditionMaker:maker];
}

-(DWDatabaseResult *)queryTableAutomaticallyWithClass:(Class)clazz name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path condition:(DWDatabaseConditionHandler)condition {
    
    if (!clazz && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid class and condition which both are nil.", 10017)];
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    clazz = [maker fetchQueryClass];
    if (!clazz) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:clazz name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:nil recursive:YES conditionMaker:maker reprocessing:nil];
}

///配置数据库
-(DWDatabaseResult *)configDBIfNeededWithName:(NSString *)name path:(NSString *)path {
    if (!name.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    if ([self.allDBs_prv.allKeys containsObject:name]) {
        NSError * error = errorWithMessage(@"Invalid name which there's already an database with it.If you are sure to use this name with a new database,delete the old one first.", 10001);
        DWDatabaseResult * result = [DWDatabaseResult successResultWithResult:nil];
        result.error = error;
        return result;
    }
    if (!path.length) {
        path = [[defaultSavePath() stringByAppendingPathComponent:generateUUID()] stringByAppendingPathExtension:@"sqlite3"];
    }
    
    FMDatabaseQueue * q = [self openDBQueueWithName:name path:path private:NO];
    BOOL success = (q != nil);
    ///创建数据库，若成功则保存
    if (!success) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid path which FMDatabaseQueue could not open.", 10003)];
    }
    
    DWDatabaseInfo * info = [DWDatabaseInfo new];
    info.dbName = name;
    info.dbPath = path;
    if ([info configRelativePath]) {
        [self dw_insertTableWithModel:info dbName:kSqlSetDbName tableName:kSqlSetTblName inQueue:self.privateQueue insertChains:nil recursive:NO conditionMaker:nil];
    } else {
        success = NO;
    }
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.success = success;
    return result;
}

-(DWDatabaseResult *)deleteDBWithName:(NSString *)name {
    if (!name.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    if (![self.allDBs.allKeys containsObject:name]) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name which there's no database named with it.", 10002)];
    }
    
    DWDatabaseResult * result = [DWDatabaseResult failResultWithError:nil];
    ///移除管理表、缓存及数据库
    NSString * path = [self.allDBs valueForKey:name];
    DWDatabaseInfo * info = [DWDatabaseInfo new];
    info.dbName = name;
    info.dbPath = path;
    if ([info configRelativePath]) {
        
        DWDatabaseConditionHandler condition = ^(DWDatabaseConditionMaker * maker) {
            maker.dw_loadClass(DWDatabaseInfo);
            maker.dw_conditionWith(dbName).equalTo(info.dbName);
            maker.dw_conditionWith(dbPath).equalTo(info.dbPath);
            maker.dw_conditionWith(relativePath).equalTo(info.relativePath);
            maker.dw_conditionWith(relativeType).equalTo(info.relativeType);
        };
        
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        condition(maker);
        
        result = [self dw_deleteTableWithModel:nil dbName:kSqlSetDbName tableName:kSqlSetTblName inQueue:self.privateQueue deleteChains:nil recursive:NO conditionMaker:maker];
        ///若表删除成功，应移除所有相关信息，包括缓存的DBQ，数据库地址缓存，本地数据库文件，以及若为当前库还要清空当前库信息
        if (result.success) {
            [self.allDBs_prv removeObjectForKey:name];
            [self.dbqContainer removeObjectForKey:name];
            NSError * error = nil;
            result.success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
            result.error = error;
        }
    }
    return result;
}

-(DWDatabaseResult *)fetchDBConfigurationWithName:(NSString *)name {
    if (!name.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    FMDatabaseQueue *dbqTmp = nil;
    ///内存总存在的DB直接切换
    if ([self.dbqContainer.allKeys containsObject:name]) {
        dbqTmp = [self.dbqContainer valueForKey:name];
    }
    ///内存中寻找DB路径，若存在则初始化DB
    if (!dbqTmp && [self.allDBs_prv.allKeys containsObject:name]) {
        NSString * path = [self.allDBs_prv valueForKey:name];
        if (path.length) {
            dbqTmp = [self openDBQueueWithName:name path:path private:NO];
        }
    }
    if (!dbqTmp) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Can't not fetch a FMDatabaseQueue", 10004)];
    }
    DWDatabaseConfiguration * conf = [[DWDatabaseConfiguration alloc] initWithName:name tblName:nil dbq:dbqTmp];
    return [DWDatabaseResult successResultWithResult:conf];
}

-(DWDatabaseResult *)isTableExistWithTableName:(NSString *)tblName configuration:(DWDatabaseConfiguration *)conf {
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    __block BOOL exist = NO;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            exist = [db tableExists:tblName];
        }];
    });
    if (!exist) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tabelName which currentDB doesn't contains a table named it.", 10006)];
    }
    return [DWDatabaseResult successResultWithResult:nil];
}

-(DWDatabaseResult *)queryAllTableNamesInDBWithConfiguration:(DWDatabaseConfiguration *)conf {
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    
    NSMutableArray * arr = [NSMutableArray arrayWithCapacity:0];
    [self queryTableWithSQL:@"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name" configuration:conf completion:^(FMResultSet * _Nullable set, NSError * _Nullable err) {
        result.error = err;
        if (set) {
            while ([set next]) {
                NSString * tblName = [set stringForColumn:@"name"];
                if (tblName.length) {
                    [arr addObject:tblName];
                }
            }
        }
    }];
    
    if ([arr containsObject:@"sqlite_sequence"]) {
        [arr removeObject:@"sqlite_sequence"];
    }
    
    result.success = YES;
    result.result = arr;
    return result;
}

-(DWDatabaseResult *)createTableWithClass:(Class)cls tableName:(NSString *)tblName configuration:(DWDatabaseConfiguration *)conf {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    return [self dw_createTableWithClass:cls tableName:tblName inQueue:conf.dbQueue];
}

-(DWDatabaseResult *)createTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf {
    
    if (!sql.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid sql whose length is 0.", 10007)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            ///建表
            result.success = [db executeUpdate:sql];
            result.error = db.lastError;
        }];
    });
    return result;
}

-(DWDatabaseResult *)fetchDBConfigurationWithName:(NSString *)name tabelName:(NSString *)tblName {
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    
    DWDatabaseResult * result = [self fetchDBConfigurationWithName:name];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * confTmp = result.result;
    result = [self isTableExistWithTableName:tblName configuration:confTmp];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = [[DWDatabaseConfiguration alloc] initWithName:name tblName:tblName dbq:confTmp.dbQueue];
    return [DWDatabaseResult successResultWithResult:conf];
}

-(DWDatabaseResult *)updateTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf {
    
    if (!sql.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid sql whose length is 0.", 10007)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            result.success = [db executeUpdate:sql];
            result.error = db.lastError;
        }];
    });
    return result;
}

-(DWDatabaseResult *)updateTableWithSQLs:(NSArray<NSString *> *)sqls rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf {
    
    if (!sqls.count) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid sqls whose count is 0.", 10007)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            [sqls enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.length) {
                    result.success = [db executeUpdate:obj];
                    if (!result.success && rollback) {
                        *stop = YES;
                        *rollback = YES;
                    }
                    result.error = db.lastError;
                }
            }];
        }];
    });
    return result;
}

-(void)queryTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf completion:(void (^)(FMResultSet * _Nullable, NSError * _Nullable))completion {
    
    if (!sql.length) {
        NSError * err = errorWithMessage(@"Invalid sql whose length is 0.", 10007);
        if (completion) {
            completion(nil,err);
        }
        return;
    }
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        if (completion) {
            completion(nil,result.error);
        }
        return;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            FMResultSet * ret = [db executeQuery:sql];
            if (completion) {
                completion(ret,db.lastError);
            }
            [ret close];
        }];
    });
}

-(DWDatabaseResult *)queryAllFieldInTable:(BOOL)translateToPropertyName class:(Class)cls configuration:(DWDatabaseConfiguration *)conf {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    NSMutableArray * fields = [NSMutableArray arrayWithCapacity:0];
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            FMResultSet * set = [db getTableSchema:conf.tableName];
            while ([set next]) {
                [fields addObject:[set stringForColumn:@"name"]];
            }
            [set close];
        }];
    });
    
    ///去除ID
    if ([fields containsObject:kUniqueID]) {
        [fields removeObject:kUniqueID];
    }
    if (!translateToPropertyName) {
        return [DWDatabaseResult successResultWithResult:fields];
    }
    if (translateToPropertyName && cls == Nil) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* propInfos = [self propertyInfosForSaveKeysWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSMutableArray * propNames = [NSMutableArray arrayWithCapacity:0];
    [propInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name.length) {
            NSString * field = propertyInfoTblName(obj, map);
            if (field.length && [fields containsObject:field]) {
                [propNames addObject:obj.name];
            }
        }
    }];
    
    result.result = propNames;
    ///如果个数不相等说明转换出现了问题
    if (propNames.count != fields.count) {
        result.error = errorWithMessage(@"Something wrong on translating fieldsName to propertyName.Checkout the result of propertyNames and find the reason.", 10020);
    }
    return result;
}

-(DWDatabaseResult *)clearTableWithConfiguration:(DWDatabaseConfiguration *)conf {
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            result.success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@",conf.tableName]];
            result.error = db.lastError;
        }];
    });
    
    return result;
}

-(DWDatabaseResult *)dropTableWithConfiguration:(DWDatabaseConfiguration *)conf {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            result.success = [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",conf.tableName]];
            result.error = db.lastError;
        }];
    });
    return result;
}

-(DWDatabaseResult *)insertTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition {
    return [self _entry_insertTableWithModel:model  configuration:conf insertChains:nil recursive:recursive condition:condition];
}

-(DWDatabaseResult *)insertTableWithModels:(NSArray<NSObject *> *)models recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseOperationChain * insertChains = [DWDatabaseOperationChain new];
    DWDatabaseConditionMaker * maker = nil;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
    }
    NSMutableArray * failures = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * factorys = [NSMutableArray arrayWithCapacity:0];
    [models enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DWDatabaseSQLFactory * fac = [self insertSQLFactoryWithModel:obj dbName:conf.dbName tableName:conf.tableName insertChains:insertChains recursive:recursive conditionMaker:maker].result;
        if (!fac) {
            [failures addObject:obj];
            ///如果失败就回滚的话，则此处无需再生成其他sql
            if (rollback) {
                *stop = YES;
            }
        } else {
            [factorys addObject:fac];
        }
    }];
    
    ///如果失败就回滚的话，此处无需再做插入操作，直接返回失败的模型
    if (rollback && failures.count > 0) {
        NSUInteger idx = [models indexOfObject:failures.lastObject];
        DWDatabaseResult * result = [DWDatabaseResult failResultWithError:nil];
        result.result = [models subarrayWithRange:NSMakeRange(idx, models.count - idx)];
        return result;
    }
    
    __block BOOL hasFailure = NO;
    __block NSError * error;
    __weak typeof(self) weakSelf = self;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollbackP) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [factorys enumerateObjectsUsingBlock:^(DWDatabaseSQLFactory * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                ///如果还没失败过则执行插入操作
                if (!hasFailure) {
                    ///如果插入失败则记录失败状态并将模型加入失败数组
                    DWDatabaseResult * result = [strongSelf excuteUpdate:db WithFactory:obj clear:NO];
                    if (!result.success) {
                        hasFailure = YES;
                        [failures addObject:obj.model];
                        error = result.error;
                    }
                } else {
                    ///如果失败过，直接将模型加入数组即可
                    [failures addObject:obj.model];
                }
            }];
            
            ///如果失败了，按需回滚
            if (hasFailure) {
                *rollbackP = rollback;
            }
        }];
    });
    
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.error = error;
    result.success = failures.count == 0;
    if (!result.success) {
        result.result = failures;
    }
    return result;
}

-(void)insertTableWithModels:(NSArray<NSObject *> *)models recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition completion:(void (^)(DWDatabaseResult * result))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        DWDatabaseResult * result = [self insertTableWithModels:models recursive:recursive rollbackOnFailure:rollback configuration:conf condition:condition];
        if (completion) {
            completion(result);
        }
    });
}

-(DWDatabaseResult *)deleteTableWithConfiguration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    return [self _entry_deleteTableWithModel:nil configuration:conf deleteChains:nil recursive:NO condition:condition];
}

-(DWDatabaseResult *)deleteTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    if (!model) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model who is nil.", 10016)];
    }
    
    NSNumber * Dw_id = Dw_idFromModel(model);
    if (!Dw_id) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
    }
    
    return [self _entry_deleteTableWithModel:model configuration:conf deleteChains:nil recursive:recursive condition:nil];
}

-(DWDatabaseResult *)updateTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
    return [self _entry_updateTableWithModel:model configuration:conf updateChains:nil recursive:recursive condition:condition];
}

-(DWDatabaseResult *)queryTableWithClass:(Class)clazz  limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf  condition:(DWDatabaseConditionHandler)condition reprocessing:(DWDatabaseReprocessingHandler)reprocessing {
    return [self _entry_queryTableWithClass:clazz limit:limit offset:offset orderKey:orderKey ascending:ascending configuration:conf queryChains:nil recursive:recursive condition:condition reprocessing:reprocessing];
}

-(void)queryTableWithClass:(Class)clazz limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition reprocessing:(DWDatabaseReprocessingHandler)reprocessing completion:(void (^)(DWDatabaseResult * result))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        DWDatabaseResult * result = [self queryTableWithClass:clazz limit:limit offset:offset orderKey:orderKey ascending:ascending recursive:recursive configuration:conf condition:condition reprocessing:reprocessing];
        if (completion) {
            completion(result);
        }
    });
}

-(DWDatabaseResult *)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    if (!sql.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid sql whose length is 0.", 10007)];
    }
    
    if (cls == Nil) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    __block DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* props = [self propertyInfosForSaveKeysWithClass:cls];
    NSDictionary * databaseMap = databaseMapFromClass(cls);
    NSMutableArray * resultArr = [NSMutableArray arrayWithCapacity:0];
    DWDatabaseOperationChain * queryChains = nil;
    NSDictionary * inlineTblNameMap = nil;
    if (recursive) {
        queryChains = [DWDatabaseOperationChain new];
        inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
    }
    __block BOOL stop = NO;
    __block BOOL returnNil = NO;
    [self queryTableWithSQL:sql configuration:conf completion:^(FMResultSet * _Nullable set, NSError * _Nullable err) {
        result.error = err;
        if (set) {
            while ([set next]) {
                
                result = [self handleQueryResultWithClass:cls dbName:conf.dbName tblName:conf.tableName resultSet:set validProInfos:props databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:&stop returnNil:&returnNil stopOnValidValue:NO reprocessing:nil];
                
                if (!result.success) {
                    if (stop) {
                        break;
                    }
                }
            }
        }
    }];
    
    if (returnNil) {
        result.success = NO;
        return result;
    }
    
    return [self handleQueryRecursiveResultWithDbName:conf.dbName tblName:conf.tableName resultArr:resultArr queryChains:queryChains recursive:recursive];
}

-(void)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf completion:(void (^)(NSArray<__kindof NSObject *> * _Nonnull, NSError * _Nonnull))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        DWDatabaseResult * result = [self queryTableWithSQL:sql class:cls recursive:recursive configuration:conf];
        if (completion) {
            completion(result.result,result.error);
        }
    });
}

-(DWDatabaseResult *)queryTableWithClass:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
    
    if (!cls && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(cls);
        };
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:nil recursive:recursive conditionMaker:maker reprocessing:nil];
}

-(DWDatabaseResult *)queryTableForCountWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf condition:(DWDatabaseConditionHandler)condition {
    
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
    
    return [self dw_queryTableForCountWithDbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue conditionMaker:maker];
}

-(DWDatabaseResult *)queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition {
    return [self _entry_queryTableWithClass:cls Dw_id:Dw_id queryChains:nil recursive:recursive configuration:conf condition:condition];
}

-(DWDatabaseResult *)fetchDBVersionWithConfiguration:(DWDatabaseConfiguration *)conf {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:NO];
    if (!result.success) {
        return result;
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            NSNumber * dbVersion = @([db userVersion]);
            result.error = db.lastError;
            ///获取带转换的属性
            result.result = dbVersion;
            result.success = dbVersion != nil;
        }];
    });
    
//    NSString * sql = @"PRAGMA user_version";
//    excuteOnDBOperationQueue(self, ^{
//        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//            [db userVersion];
//            FMResultSet * set = [db executeQuery:sql];
//            result.error = db.lastError;
//            ///获取带转换的属性
//            NSNumber * dbVersion = nil;
//            while ([set next] && !dbVersion) {
//                dbVersion = [set objectForColumn:@"user_version"];
//            }
//            result.result = dbVersion;
//            result.success = dbVersion != nil;
//            [set close];
//        }];
//    });
    return result;
}

-(DWDatabaseResult *)upgradeDBVersion:(NSInteger)targetVersion configuration:(DWDatabaseConfiguration *)conf handler:(DWDatabaseUpgradeDBVersionHandler)handler {
    if (!handler) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Upgrade DB fail for sending nil handler.", 10022)];
    }
    DWDatabaseResult * result = [self fetchDBVersionWithConfiguration:conf];
    if (!result.success) {
        return result;
    }
    
    NSInteger currentVersion = [result.result integerValue];
    if (currentVersion >= targetVersion) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Upgrade DB fail for sending the same targetVersion as currentVersion.", 10022)];
    }
    
    NSInteger newVersion = handler(self,currentVersion,targetVersion);
    if (newVersion < 0) {
        return [DWDatabaseResult failResultWithError:errorWithMessage([NSString stringWithFormat: @"Upgrade DB fail for handler return a invalid version:%ld",newVersion], 10023)];
    }
    
    if ([result.result integerValue] == newVersion) {
        return [DWDatabaseResult failResultWithError:errorWithMessage([NSString stringWithFormat: @"Upgrade DB fail for handler return a the same version as current version:%ld",newVersion], 10024)];
    }
    
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            [db setUserVersion:(uint32_t)newVersion];
            result.error = db.lastError;
            result.success =  (result.error.code == 0);
            result.result = @(newVersion);
        }];
    });
    
//    NSString * sql = [NSString stringWithFormat:@"PRAGMA user_version = %ld",newVersion];
//    excuteOnDBOperationQueue(self, ^{
//        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//            result.success = [db executeUpdate:sql];
//            result.error = db.lastError;
//            result.result = @(newVersion);
//        }];
//    });
    
    return result;
}

-(DWDatabaseResult *)supplyFieldIfNeededWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf {
    return [self _entry_supplyFieldIfNeededWithClass:clazz configuration:conf];
}

-(DWDatabaseResult *)addFieldsToTableWithClass:(Class)clazz keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf {
    return [self _entry_addFieldsToTableWithClass:clazz keys:keys configuration:conf];
}

+(NSNumber *)fetchDw_idForModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    return Dw_idFromModel(model);
}

+(NSString *)fetchDBNameForModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    return DbNameFromModel(model);
}

+(NSString *)fetchTblNameForModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    return TblNameFromModel(model);
}

///模型存数据库需要保存的键值
+(NSArray <DWPrefix_YYClassPropertyInfo *>*)propertysToSaveWithClass:(Class)cls {
    return [[self shareDB] propertysToSaveWithClass:cls];
}

///获取类指定键值的propertyInfo
+(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys {
    if (!cls) {
        return nil;
    }
    return [cls dw_propertyInfosForKeys:keys];
}

#pragma mark --- tool method ---
-(FMDatabaseQueue *)openDBQueueWithName:(NSString *)name path:(NSString *)path private:(BOOL)private {
    NSString * saveP = [path stringByDeletingLastPathComponent];
    ///路径不存在先创建路径
    if (![[NSFileManager defaultManager] fileExistsAtPath:saveP]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:saveP withIntermediateDirectories:NO attributes:nil error:nil];
    }
    FMDatabaseQueue * q = [FMDatabaseQueue databaseQueueWithPath:path];
    if (q && !private) {
        ///缓存当前数据库信息
        [self.allDBs_prv setValue:path forKey:name];
        [self.dbqContainer setValue:q forKey:name];
    }
    return q;
}

///模型存数据库需要保存的键值
-(NSArray *)propertysToSaveWithClass:(Class)cls {
    NSString * key = NSStringFromClass(cls);
    if (!key.length) {
        return nil;
    }
    
    ///有缓存取缓存
    NSArray * tmp = [self.saveKeysCache objectForKey:key];
    if (tmp) {
        return tmp;
    }
    
    ///没有则计算
    NSArray * allProps = [[cls dw_allPropertyInfos] allKeys];
    if ([cls respondsToSelector:@selector(dw_dataBaseWhiteList)]){
        NSArray * whiteProps = [cls dw_dataBaseWhiteList];
        ///如果白名单不为空，返回白名单交集，为空则代表没有属性要存返回空
        tmp = intersectionOfArray(allProps, whiteProps);
    } else if ([cls respondsToSelector:@selector(dw_dataBaseBlackList)]) {
        NSArray * blackProps = [cls dw_dataBaseBlackList];
        ///如果黑名单不为空，则返回排除黑名单的集合，为空则返回全部属性
        tmp = minusArray(allProps, blackProps);
    } else {
        tmp = allProps;
    }
    
    ///存储缓存
    tmp = tmp ? [tmp copy] :@[];
    [self.saveKeysCache setObject:tmp forKey:key];
    return tmp;
}

///获取类指定键值的propertyInfo
-(NSDictionary *)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys {
    if (!cls) {
        return nil;
    }
    return [cls dw_propertyInfosForKeys:keys];
}

#pragma mark --- tool func ---
///生成一个随机字符串
NS_INLINE NSString * generateUUID() {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge NSString*)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return uuidString;
}

///默认存储路径
NSString * defaultSavePath() {
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"DWDatabase"];
}

#pragma mark --- singleton ---
static DWDatabase * db = nil;
+(instancetype)shareDB {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        db = [[self alloc] init_prv];
    });
    return db;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        db = [super allocWithZone:zone];
    });
    return db;
}

#pragma mark --- override ---
-(instancetype)init_prv {
    if (self = [super init]) {
        _dbOperationQueue = dispatch_queue_create("com.DWDatabase.DBOperationQueue", NULL);
        dispatch_queue_set_specific(_dbOperationQueue, dbOpQKey, &dbOpQKey, NULL);
    }
    return self;
}

-(instancetype)init {
    NSAssert(NO, @"Don't call init.Use 'shareDB' instead.");
    return nil;
}

#pragma mark --- setter/getter ---
-(NSDictionary *)allDBs {
    return [self.allDBs_prv copy];
}

-(NSMutableDictionary *)allDBs_prv {
    if (!_allDBs_prv) {
        _allDBs_prv = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _allDBs_prv;
}

-(NSCache *)saveKeysCache {
    if (!_saveKeysCache) {
        _saveKeysCache = [NSCache new];
    }
    return _saveKeysCache;
}

@end
