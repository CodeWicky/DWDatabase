//
//  DWDatabase.m
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "DWDatabase.h"
#import <Foundation/NSZone.h>
#import "NSObject+PropertyInfo.h"
#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabase+Private.h"
#import "DWDatabaseFunction.h"
#import "DWDatabase+Insert.h"
#import "DWDatabase+Update.h"

#pragma mark --------- 数据库管理模型部分开始 ---------
@interface DWDatabaseInfo : NSObject<DWDatabaseSaveProtocol>

@property (nonatomic ,copy) NSString * dbName;

@property (nonatomic ,copy) NSString * dbPath;

@property (nonatomic ,copy) NSString * relativePath;

///-1初始值，0沙盒，1bundle，2其他
@property (nonatomic ,assign) int relativeType;

@end

@implementation DWDatabaseInfo

+(NSArray *)dw_dataBaseWhiteList {
    static NSArray * wl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wl = @[@"dbName",@"relativePath",@"relativeType"];
    });
    return wl;
}

///用于存表过程
-(BOOL)configRelativePath {
    if (!self.dbPath.length) {
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.dbPath]) {
        return NO;
    }
    if ([self.dbPath hasPrefix:NSHomeDirectory()]) {
        self.relativeType = 0;
        self.relativePath = [self.dbPath stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@""];
    } else if ([self.dbPath hasPrefix:[NSBundle mainBundle].bundlePath]) {
        self.relativeType = 1;
        self.relativePath = [self.dbPath stringByReplacingOccurrencesOfString:[NSBundle mainBundle].bundlePath withString:@""];
    } else {
        self.relativeType = 2;
        self.relativePath = self.dbPath;
    }
    return YES;
}

///用于取表过程
-(BOOL)configDBPath {
    if (!self.relativePath.length) {
        return NO;
    }
    if (self.relativeType == 0) {
        self.dbPath = [NSHomeDirectory() stringByAppendingString:self.relativePath];
    } else if (self.relativeType == 1) {
        self.dbPath = [[NSBundle mainBundle].bundlePath stringByAppendingString:self.relativePath];
    } else if (self.relativeType == 2) {
        self.dbPath = self.relativePath;
    } else {
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.dbPath]) {
        return NO;
    }
    return YES;
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _relativeType = -1;
    }
    return self;
}

@end
#pragma mark --------- 数据库管理模型部分结束 ---------

#pragma mark --------- DWDatabaseConfiguration开始 ---------
@interface DWDatabaseConfiguration (Private)

///当前使用的数据库队列
@property (nonatomic ,strong) FMDatabaseQueue * dbQueue;

///数据库在本地映射的name
@property (nonatomic ,copy) NSString * dbName;

///当前使用的表名
@property (nonatomic ,copy) NSString * tableName;

@end

@implementation DWDatabaseConfiguration (Private)
@dynamic dbName,tableName,dbQueue;
-(instancetype)initWithName:(NSString *)name tblName:(NSString * )tblName dbq:(FMDatabaseQueue *)dbq {
    if (self = [super init]) {
        self.dbName = name;
        self.tableName = tblName;
        self.dbQueue = dbq;
    }
    return self;
}

@end
#pragma mark --------- DWDatabaseConfiguration结束 ---------

#pragma mark --------- DWDatabase开始 ---------

#define kSqlSetDbName (@"sql_set")
#define kSqlSetTblName (@"sql_set")
#define kCreatePrefix (@"c")
#define kDeletePrefix (@"d")
#define kQueryPrefix (@"q")

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

    NSArray <DWDatabaseInfo *>* res = [self dw_queryTableWithDbName:kSqlSetDbName tableName:kSqlSetTblName keys:nil limit:0 offset:0 orderKey:nil ascending:YES inQueue:self.privateQueue queryChains:nil recursive:NO condition:^(DWDatabaseConditionMaker *maker) {
        maker.loadClass([DWDatabaseInfo class]);
    }].result;
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

-(DWDatabaseResult *)insertTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray<NSString *> *)keys {
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    return [self dw_insertTableWithModel:model dbName:name tableName:tblName keys:keys inQueue:conf.dbQueue insertChains:nil recursive:YES];
}

-(DWDatabaseResult *)deleteTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path condition:(nullable void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    
    if (!model && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model and condition which both are nil.", 10016)];
    }
    
    NSNumber * Dw_id = Dw_idFromModel(model);
    if (!condition && !Dw_id) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
    }
    
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseConfiguration * conf = result.result;
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass([model class]);
            maker.conditionWith(kUniqueID).equalTo(Dw_id);
        };
    }
    
    return [self dw_deleteTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue deleteChains:nil recursive:YES condition:condition];
}

-(DWDatabaseResult *)updateTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray<NSString *> *)keys {
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    return [self dw_updateTableWithModel:model dbName:name tableName:tblName keys:keys inQueue:conf.dbQueue updateChains:nil recursive:YES condition:nil];
}

-(DWDatabaseResult *)queryTableAutomaticallyWithClass:(Class)clazz name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray *)keys condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    
    if (!clazz) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    
    DWDatabaseResult * result = [self fetchDBConfigurationAutomaticallyWithClass:clazz name:name tableName:tblName path:path];
    if (!result.success) {
        return result;
    }
    DWDatabaseConfiguration * conf = result.result;
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:nil recursive:YES condition:condition];
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
        [self dw_insertTableWithModel:info dbName:kSqlSetDbName tableName:kSqlSetTblName keys:nil inQueue:self.privateQueue insertChains:nil recursive:NO];
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
        result = [self dw_deleteTableWithModel:nil dbName:kSqlSetDbName tableName:kSqlSetTblName inQueue:self.privateQueue deleteChains:nil recursive:NO condition:^(DWDatabaseConditionMaker *maker) {
            maker.dw_loadClass(DWDatabaseInfo);
            maker.dw_conditionWith(dbName).equalTo(info.dbName);
            maker.dw_conditionWith(dbPath).equalTo(info.dbPath);
            maker.dw_conditionWith(relativePath).equalTo(info.relativePath);
            maker.dw_conditionWith(relativeType).equalTo(info.relativeType);
        }];
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

-(DWDatabaseResult *)insertTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    return [self _entry_insertTableWithModel:model keys:keys configuration:conf insertChains:nil recursive:recursive];
}

-(DWDatabaseResult *)insertTableWithModels:(NSArray<NSObject *> *)models keys:(NSArray<NSString *> *)keys recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf {
    DWDatabaseOperationChain * insertChains = [DWDatabaseOperationChain new];
    NSMutableArray * failures = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * factorys = [NSMutableArray arrayWithCapacity:0];
    [models enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DWDatabaseSQLFactory * fac = [self insertSQLFactoryWithModel:obj dbName:conf.dbName tableName:conf.tableName keys:keys insertChains:insertChains recursive:recursive].result;
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
                    [strongSelf supplyFieldIfNeededWithClass:[obj.model class] configuration:conf];
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

-(void)insertTableWithModels:(NSArray<NSObject *> *)models keys:(NSArray<NSString *> *)keys recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf completion:(void (^)(NSArray<NSObject *> * _Nonnull, NSError * _Nonnull))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        DWDatabaseResult * result = [self insertTableWithModels:models keys:keys recursive:recursive rollbackOnFailure:rollback configuration:conf];
        if (completion) {
            completion(result.result,result.error);
        }
    });
}

-(DWDatabaseResult *)deleteTableWithConfiguration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker *))condition {
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

-(DWDatabaseResult *)updateTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    return [self _entry_updateTableWithModel:model keys:keys configuration:conf updateChains:nil recursive:recursive condition:condition];
}

-(DWDatabaseResult *)queryTableWithClass:(Class)clazz keys:(NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    return [self _entry_queryTableWithClass:clazz keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending configuration:conf queryChains:nil recursive:recursive condition:condition];
}

-(void)queryTableWithClass:(Class)clazz keys:(NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(void(^)(DWDatabaseConditionMaker * maker))condition completion:(void (^)(NSArray<__kindof NSObject *> *, NSError *))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        DWDatabaseResult * result = [self queryTableWithClass:clazz keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending recursive:recursive configuration:conf condition:condition];
        if (completion) {
            completion(result.result,result.error);
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
                
                result = [self handleQueryResultWithClass:cls dbName:conf.dbName tblName:conf.tableName resultSet:set validProInfos:props databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:&stop returnNil:&returnNil stopOnValidValue:NO];
                
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

-(DWDatabaseResult *)queryTableWithClass:(Class)cls keys:(NSArray *)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker * ))condition {
    
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
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:nil recursive:recursive condition:condition];
}

-(DWDatabaseResult *)queryTableForCountWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    
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
    
    return [self dw_queryTableForCountWithDbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue condition:condition];
}

-(DWDatabaseResult *)queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id keys:(NSArray<NSString *> *)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    return [self _entry_queryTableWithClass:cls Dw_id:Dw_id keys:keys queryChains:nil recursive:recursive configuration:conf];
}

+(NSNumber *)fetchDw_idForModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    return Dw_idFromModel(model);
}

+(NSString *)fetchDbNameForModel:(NSObject *)model {
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

#pragma mark --- tool method ---
#pragma mark --- 内部入口 ---

-(DWDatabaseResult *)_entry_deleteTableWithModel:(NSObject *)model configuration:(DWDatabaseConfiguration *)conf deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    if (!condition && model) {
        NSNumber * Dw_id = Dw_idFromModel(model);
        if (Dw_id) {
            condition = ^(DWDatabaseConditionMaker * maker) {
                maker.loadClass([model class]);
                maker.conditionWith(kUniqueID).equalTo(Dw_id);
            };
        }
    }
    
    return [self dw_deleteTableWithModel:model dbName:conf.dbName tableName:conf.tableName inQueue:conf.dbQueue deleteChains:deleteChains recursive:recursive condition:condition];
}

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
    
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:conf.dbQueue queryChains:queryChains recursive:recursive condition:condition];
}

-(DWDatabaseResult *)_entry_queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id keys:(NSArray<NSString *> *)keys queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf {
    if (!Dw_id) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Dw_id who is Nil.", 10018)];
    }
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    result = [self dw_queryTableWithClass:cls dbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue queryChains:nil recursive:recursive condition:^(DWDatabaseConditionMaker *maker) {
        maker.loadClass(cls);
        maker.conditionWith(kUniqueID).equalTo(Dw_id);
    } resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive,NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
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

#pragma mark ------ 建表 ------
-(DWDatabaseResult *)dw_createTableWithClass:(Class)cls tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue {
    if (cls == Nil) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!tblName.length) {
        tblName = [NSStringFromClass(cls) stringByAppendingString:@"_tbl"];
    }
    
    DWDatabaseResult * result = [self createSQLFactoryWithClass:cls tableName:tblName];
    if (!result.success) {
        return result;
    }
    DWDatabaseSQLFactory * fac = result.result;
    result.result = nil;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            ///建表
            result.success = [db executeUpdate:fac.sql];
            result.error = db.lastError;
        }];
    });
    
    return result;
}

#pragma mark ------ 插入表 ------

#pragma mark ------ 表删除 ------
-(DWDatabaseResult *)dw_deleteTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
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
    
    DWDatabaseResult * result = [self deleteSQLFactoryWithModel:model dbName:dbName tableName:tblName deleteChains:deleteChains recursive:recursive condition:condition];
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

#pragma mark ------ 更新表 ------


#pragma mark ------ 查询表 ------

-(DWDatabaseResult *)dw_queryTableWithClass:(Class)clazz dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition resultSetHandler:(NSError *(^)(Class cls,FMResultSet * set,NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*validProInfos,NSDictionary * databaseMap,NSMutableArray * resultArr,DWDatabaseOperationChain * queryChains,BOOL recursive,NSDictionary * inlineTblNameMap,BOOL * stop,BOOL * returnNil))handler {
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!tblName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    if (!clazz && !condition) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid query without any condition.", 10010)];
    }
    
    ///嵌套查询的思路：
    ///先将按指定条件查询符合条件的跟模型。在遍历模型属性给结果赋值时，检测赋值属性是否为对象类型。因为如果为对象类型，通过property将无法赋值成功。此时将这部分未赋值成功的属性值记录下来并标记为未完成状态。当根模型有效值赋值完成时，遍历结果集，如果有未完成状态的模型，则遍历模型未赋值成功的属性，尝试赋值。同插入一样，要考虑死循环的问题，所以查询前先校验查询链。此处将状态记录下来在所有根结果查询完成后在尝试赋值对象属性还有一个原因是，如果想要在为每个结果的属性赋值同时完成对象类型的查询，会由于队里造成死锁，原因是查询完成赋值在dbQueue中，但在赋值同时进行查询操作，会同步在dbQueue中再次派发至dbQueue，造成死锁。
    
    DWDatabaseResult * result = [self querySQLFactoryWithClazz:clazz tblName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending condition:condition];
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

#pragma mark ------ SQL factory ------
-(DWDatabaseResult *)createSQLFactoryWithClass:(Class)cls tableName:(NSString *)tblName {
    NSDictionary * props = [self propertyInfosForSaveKeysWithClass:cls];
    if (!props.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no save key.",NSStringFromClass(cls)];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10012)];
    }
    
    NSString * sql = nil;
    ///先尝试取缓存的sql
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kCreatePrefix class:cls tblName:tblName keys:@[@"CREATE-SQL"]];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache valueForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///添加模型表键值转化
        NSDictionary * map = databaseMapFromClass(cls);
        NSMutableArray * validKeys = [NSMutableArray arrayWithCapacity:0];
        [props enumerateKeysAndObjectsUsingBlock:^(NSString * key, DWPrefix_YYClassPropertyInfo * obj, BOOL * _Nonnull stop) {
            ///转化完成的键名及数据类型
            NSString * field = tblFieldStringFromPropertyInfo(obj,map);
            if (field.length) {
                [validKeys addObject:field];
            }
        }];
        
        if (!validKeys.count) {
            NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid keys to create table.",NSStringFromClass(cls)];
            return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
        }
        
        ///对表中字段名进行排序
        [validKeys sortUsingSelector:@selector(compare:)];
        
        ///拼装sql语句
        sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT,%@)",tblName,kUniqueID,[validKeys componentsJoinedByString:@","]];
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setValue:sql forKey:cacheSqlKey];
        }
    }
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(DWDatabaseResult *)deleteSQLFactoryWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
    
    if (!condition) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who have no valid value to delete.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    Class cls = [maker fetchQueryClass];
    
    if (!cls) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who hasn't load class.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10017)];
    }
    
    NSMutableArray * args = @[].mutableCopy;
    NSMutableArray * conditionStrings = @[].mutableCopy;
    NSMutableArray * validConditionKeys = @[].mutableCopy;
    
    
    NSArray * saveKeys = [self propertysToSaveWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [self propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithPropertyInfos:propertyInfos databaseMap:map];
    [maker make];
    [args addObjectsFromArray:[maker fetchArguments]];
    [conditionStrings addObjectsFromArray:[maker fetchConditions]];
    [validConditionKeys addObjectsFromArray:[maker fetchValidKeys]];
    
    ///无有效插入值
    if (!conditionStrings.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who have no valid value to delete.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    
    ///处理递归删除
    [self handleDeleteRecursiveModelWithPropertyInfos:propertyInfos dbName:dbName tblName:tblName model:model deleteChains:deleteChains recursive:recursive];
    
    NSString * sql = nil;
    ///先尝试取缓存的sql
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kDeletePrefix class:cls tblName:tblName keys:conditionStrings];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache valueForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",tblName,[conditionStrings componentsJoinedByString:@" AND "]];
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setValue:sql forKey:cacheSqlKey];
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

-(DWDatabaseResult *)querySQLFactoryWithClazz:(Class)clazz tblName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    
    ///获取条件字段组并获取本次的class
    NSMutableArray * args = @[].mutableCopy;
    NSMutableArray * conditionStrings = @[].mutableCopy;
    NSMutableArray * validConditionKeys = @[].mutableCopy;
    Class cls;
    NSArray * saveKeys = nil;
    NSDictionary * map = nil;
    if (condition) {
        DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
        condition(maker);
        cls = [maker fetchQueryClass];
        if (!cls) {
            cls = clazz;
        }
        saveKeys = [self propertysToSaveWithClass:cls];
        map = databaseMapFromClass(cls);
        NSDictionary * propertyInfos = [self propertyInfosWithClass:cls keys:saveKeys];
        [maker configWithPropertyInfos:propertyInfos databaseMap:map];
        [maker make];
        [args addObjectsFromArray:[maker fetchArguments]];
        [conditionStrings addObjectsFromArray:[maker fetchConditions]];
        [validConditionKeys addObjectsFromArray:[maker fetchValidKeys]];
    } else {
        cls = clazz;
        saveKeys = [self propertysToSaveWithClass:cls];
        map = databaseMapFromClass(cls);
    }
    
    BOOL queryAll = NO;
    ///如果keys为空则试图查询cls与表对应的所有键值
    if (!keys.count) {
        keys = [self propertysToSaveWithClass:cls];
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
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*queryKeysProInfos = [self propertyInfosWithClass:cls keys:keys];
    
    if (!queryKeysProInfos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid key to query.",NSStringFromClass(cls)];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    ///获取查询字符串数组
    if (queryAll) {
        [validQueryKeys addObject:@"*"];
    } else {
        [validQueryKeys addObject:kUniqueID];
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
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kQueryPrefix class:cls tblName:tblName keys:sqlCombineArray];
    
    ///有排序添加排序
    NSString * orderField = nil;
    if (orderKey.length && [saveKeys containsObject:orderKey]) {
        DWPrefix_YYClassPropertyInfo * prop = [[self propertyInfosWithClass:cls keys:@[orderKey]] valueForKey:orderKey];
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
    cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-%@-%@",orderField,ascending?@"ASC":@"DESC"]];
    
    if (limit > 0) {
        cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-L%lu",(unsigned long)limit]];
    }
    if (offset > 0) {
        cacheSqlKey = [cacheSqlKey stringByAppendingString:[NSString stringWithFormat:@"-O%lu",(unsigned long)offset]];
    }
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache valueForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        
        ///条件查询模式，所有值均为查询值，故将条件值加至查询数组
        NSMutableArray * actualQueryKeys = [NSMutableArray arrayWithArray:validQueryKeys];
        if (!queryAll) {
            [actualQueryKeys addObjectsFromArray:validConditionKeys];
        }
        
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"SELECT %@ FROM %@",[actualQueryKeys componentsJoinedByString:@","],tblName];
        
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
            [self.sqlsCache setValue:sql forKey:cacheSqlKey];
        }
    }
    
    ///获取带转换的属性
    NSDictionary * validPropertyInfo = nil;
    if (queryAll) {
        validPropertyInfo = [self propertyInfosWithClass:cls keys:saveKeys];
    } else {
        validPropertyInfo = [self propertyInfosWithClass:cls keys:validKeys];
    }
    
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    fac.args = args;
    fac.clazz = cls;
    fac.validPropertyInfos = validPropertyInfo;
    fac.dbTransformMap = map;
    return [DWDatabaseResult successResultWithResult:fac];
}

#pragma mark ------ 其他 ------
-(DWDatabaseResult *)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue queryChains:(DWDatabaseOperationChain *)queryChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition {

    return [self dw_queryTableWithClass:nil dbName:dbName tableName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:queue queryChains:queryChains recursive:recursive condition:condition resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive ,NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
        DWDatabaseResult * result = [self handleQueryResultWithClass:cls dbName:dbName tblName:tblName resultSet:set validProInfos:validProInfos databaseMap:databaseMap resultArr:resultArr queryChains:queryChains recursive:recursive inlineTblNameMap:inlineTblNameMap stop:stop returnNil:returnNil stopOnValidValue:NO];
        if (result.success) {
            return nil;
        } else {
            return result.error;
        }
    }];
}

-(DWDatabaseResult *)dw_queryTableForCountWithDbName:(NSString *)dbName tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    if (!condition) {
        return [DWDatabaseResult failResultWithError:nil];
    }
    
    DWDatabaseResult * result = [self dw_queryTableWithClass:nil dbName:dbName tableName:tblName keys:nil limit:0 offset:0 orderKey:nil ascending:YES inQueue:queue queryChains:nil recursive:NO condition:condition resultSetHandler:^NSError *(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, DWDatabaseOperationChain *queryChains, BOOL recursive, NSDictionary * inlineTblNameMap, BOOL *stop, BOOL *returnNil) {
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

///获取类指定键值的propertyInfo
-(NSDictionary *)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys {
    if (!cls) {
        return nil;
    }
    return [cls dw_propertyInfosForKeys:keys];
}

-(void)handleDeleteRecursiveModelWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName model:(NSObject *)model deleteChains:(DWDatabaseOperationChain *)deleteChains recursive:(BOOL)recursive {
    if (model && recursive) {
        Class cls = [model class];
        NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass(cls);
        NSDictionary * dbTransformMap = databaseMapFromClass(cls);
        [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.name && obj.type == DWPrefix_YYEncodingTypeObject && obj.nsType == DWPrefix_YYEncodingTypeNSUnknown) {
                id value = [model dw_valueForPropertyInfo:obj];
                NSNumber * Dw_id = Dw_idFromModel(value);
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
                                    DWDatabaseResult * result = [self dw_deleteTableWithModel:value dbName:tblConf.dbName tableName:tblConf.tableName inQueue:tblConf.dbQueue deleteChains:deleteChains recursive:NO condition:nil];
                                    
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
                                    DWDatabaseResult * result = [self _entry_deleteTableWithModel:value configuration:tblConf deleteChains:deleteChains recursive:recursive condition:nil];
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
        }];
    }
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
                        DWDatabaseResult * existRecord = [queryChains existRecordWithClass:obj.cls Dw_Id:value];
                        ///这个数据查过，直接赋值
                        if (existRecord.success) {
                            [tmp setValue:existRecord.result forKey:obj.name];
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
        for (NSInteger i = resultArr.count - 1; i >= 0; i--) {
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
#pragma mark --------- DWDatabase结束 ---------
