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

#pragma mark --------- 数据库操作记录模型部分开始 ---------

typedef NS_ENUM(NSUInteger, DWDatabaseOperation) {
    DWDatabaseOperationUndefined,
    DWDatabaseOperationInsert,
    DWDatabaseOperationDelete,
    DWDatabaseOperationUpdate,
    DWDatabaseOperationQuery,
};

@interface DWDatabaseOperationRecord : NSObject

@property (nonatomic ,weak) __kindof NSObject * model;

@property (nonatomic ,assign) DWDatabaseOperation operation;

@property (nonatomic ,copy) NSString * tblName;

@property (nonatomic ,assign) BOOL finishOperationInChain;

@end

@implementation DWDatabaseOperationRecord

@end
#pragma mark --------- 数据库操作记录模型部分结束 ---------

#pragma mark --------- 数据库操作记录链部分开始 ---------

@interface DWDatabaseOperationChain : NSObject

@property (nonatomic ,strong) NSMutableDictionary * records;

-(void)addRecord:(DWDatabaseOperationRecord *)record;

-(DWDatabaseOperationRecord *)recordInChainWithModel:(NSObject *)model;

-(DWDatabaseOperationRecord *)anyRecordInChainWithClass:(Class)cls;

-(DWDatabaseResult *)existRecordWithModel:(NSObject *)model;

@end

@implementation DWDatabaseOperationChain

-(void)addRecord:(DWDatabaseOperationRecord *)record {
    if (!record.model) {
        return;
    }
    
    NSString * key = keyStringFromModel(record.model);
    if (!key.length) {
        return;
    }
    
    DWDatabaseResult * result = [self existRecordWithModel:record.model];
    ///存在
    if (result.success) {
        return;
    }
    
    NSMutableArray * records = self.records[key];
    if (!records) {
        records = [NSMutableArray arrayWithCapacity:0];
        self.records[key] = records;
    }
    
    [records addObject:record];
}

-(DWDatabaseOperationRecord *)recordInChainWithModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    NSString *key = keyStringFromModel(model);
    if (!key.length) {
        return nil;
    }
    NSArray * records = self.records[key];
    if (!records) {
        return nil;
    }
    __block DWDatabaseOperationRecord * result = nil;
    [records enumerateObjectsUsingBlock:^(DWDatabaseOperationRecord * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.model isEqual:model]) {
            result = obj;
        }
    }];
    return result;
}

-(DWDatabaseOperationRecord *)anyRecordInChainWithClass:(Class)cls {
    if (!cls) {
        return nil;
    }
    NSString * key = NSStringFromClass(cls);
    if (!key.length) {
        return nil;
    }
    NSArray * records = self.records[key];
    if (!records.count) {
        return nil;
    }
    return records.firstObject;
}

-(DWDatabaseResult *)existRecordWithModel:(NSObject *)model {
    DWDatabaseOperationRecord * record = [self recordInChainWithModel:model];
    if (!record) {
        return [DWDatabaseResult failResultWithError:nil];
    }
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.success = YES;
    result.result = record;
    return result;
}

#pragma mark --- tool func ---
NS_INLINE NSString * keyStringFromModel(NSObject * model) {
    if (!model) {
        return nil;
    }
    return NSStringFromClass([model class]);
}

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)records {
    if (!_records) {
        _records = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _records;
}

@end

#pragma mark --------- 数据库操作记录链部分结束 ---------

#pragma mark --------- DWDatabaseConfiguration开始 ---------
@interface DWDatabaseConfiguration ()

///当前使用的数据库队列
@property (nonatomic ,strong) FMDatabaseQueue * dbQueue;

///数据库在本地映射的name
@property (nonatomic ,copy) NSString * dbName;

///当前使用的表名
@property (nonatomic ,copy) NSString * tableName;

@end

@implementation DWDatabaseConfiguration (Private)

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

#pragma mark --------- DWDatabaseSQLFactory开始 ---------
@interface DWDatabaseSQLFactory : NSObject

@property (nonatomic ,strong) NSArray * args;

@property (nonatomic ,copy) NSString * sql;

@property (nonatomic ,strong) NSObject * model;

@property (nonatomic ,strong) NSMutableDictionary * objMap;

@property (nonatomic ,assign) Class clazz;

@property (nonatomic ,strong) NSDictionary * validPropertyInfos;

@property (nonatomic ,strong) NSDictionary * dbTransformMap;

@end

@implementation DWDatabaseSQLFactory

@end
#pragma mark --------- DWDatabaseSQLFactory结束 ---------

#pragma mark --------- DWDatabase开始 ---------

#define kSqlSetDbName (@"sql_set")
#define kSqlSetTblName (@"sql_set")
#define kCreatePrefix (@"c")
#define kInsertPrefix (@"i")
#define kDeletePrefix (@"d")
#define kUpdatePrefix (@"u")
#define kQueryPrefix (@"q")
static const char * kAdditionalConfKey = "kAdditionalConfKey";
static NSString * const kDwIdKey = @"kDwIdKey";
static void* dbOpQKey = "dbOperationQueueKey";

@interface DWDatabase ()

///数据库路径缓存，缓存当前所有数据库路径
@property (nonatomic ,strong) NSMutableDictionary * allDBs_prv;

///当前使用过的数据库的FMDatabaseQueue的容器
@property (nonatomic ,strong) NSMutableDictionary <NSString *,FMDatabaseQueue *>* dbqContainer;

///私有FMDatabaseQueue，用于读取或更新本地表配置，于 -initializeDBWithError: 时被赋值
@property (nonatomic ,strong) FMDatabaseQueue * privateQueue;

///每个类对应的存表的键值缓存
@property (nonatomic ,strong) NSMutableDictionary * saveKeysCache;

///每个类对应的存表的属性信息缓存
@property (nonatomic ,strong) NSMutableDictionary * saveInfosCache;

///插入语句缓存
@property (nonatomic ,strong) NSMutableDictionary * sqlsCache;

///是否成功配置过的标志位
@property (nonatomic ,assign) BOOL hasInitialize;

@property (nonatomic ,strong) dispatch_queue_t dbOperationQueue;

@end

///数据库类
@implementation DWDatabase

#pragma mark --- interface method ---
-(BOOL)initializeDBWithError:(NSError *__autoreleasing *)error {
    if (self.hasInitialize) {
        return YES;
    }
    ///首次启动时还没有沙盒地址，此时需要调用一下才能创建出来
    if (![[NSFileManager defaultManager] fileExistsAtPath:defaultSavePath()]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:defaultSavePath() withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    ///私有表地址（用于存储数据库信息）
    NSString * savePath = [defaultSavePath() stringByAppendingPathComponent:@".private/privateInfo.sqlite"];
    self.privateQueue = [self openDBQueueWithName:nil path:savePath private:YES];
    if (!self.privateQueue) {
        NSError * err = errorWithMessage(@"Invalid path which FMDatabaseQueue could not open.", 10003);
        safeLinkError(error, err);
        return NO;
    }
    BOOL success = [self dw_createTableWithClass:[DWDatabaseInfo class] tableName:kSqlSetTblName inQueue:self.privateQueue error:error];
    NSArray <DWDatabaseInfo *>* res = [self dw_queryTableWithDbName:kSqlSetDbName tableName:kSqlSetTblName keys:nil limit:0 offset:0 orderKey:nil ascending:YES inQueue:self.privateQueue error:error condition:^(DWDatabaseConditionMaker *maker) {
        maker.loadClass([DWDatabaseInfo class]);
    }];
    
    if (res.count) {
        ///取出以后配置数据库完整地址
        [res enumerateObjectsUsingBlock:^(DWDatabaseInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj configDBPath] && obj.dbPath.length && obj.dbName.length) {
                [self.allDBs_prv setValue:obj.dbPath forKey:obj.dbName];
            }
        }];
    }
    if (success) {
        self.hasInitialize = YES;
    }
    return success;
}

-(DWDatabaseConfiguration *)fetchDBConfigurationAutomaticallyWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path error:(NSError *__autoreleasing *)error {
    if (![self initializeDBWithError:error]) {
        return nil;
    }
    if (![self configDBIfNeededWithClass:cls name:name tableName:tblName path:path error:error]) {
        return nil;
    }
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationWithName:name tabelName:tblName error:error];
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
    }
    return conf;
}

-(BOOL)configDBIfNeededWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path error:(NSError *__autoreleasing *)error {
    if (cls == Nil || !tblName.length) {
        return NO;
    }
    BOOL success = [self configDBIfNeededWithName:name path:path error:error];
    if (!success) {
        return NO;
    }
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationWithName:name error:error];
    success = [self validateConfiguration:conf considerTableName:NO].success;
    if (!success) {
        return NO;
    }
    BOOL exist = [self isTableExistWithTableName:tblName configuration:conf].success;
    if (exist) {
        return YES;
    }
    return [self createTableWithClass:cls tableName:tblName configuration:conf error:error];
}

-(DWDatabaseResult *)insertTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray<NSString *> *)keys error:(NSError *__autoreleasing *)error {
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path error:error];
    if (!conf) {
        return [DWDatabaseResult failResultWithError:*error];
    }
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
    
    NSError * error;
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path error:&error];
    if (!conf) {
        return [DWDatabaseResult failResultWithError:error];
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass([model class]);
            maker.conditionWith(kUniqueID).equalTo(Dw_id);
        };
    }
    
    return [self dw_deleteTableWithTableName:tblName inQueue:conf.dbQueue condition:condition];
}

-(DWDatabaseResult *)updateTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray<NSString *> *)keys {
    NSError * error;
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationAutomaticallyWithClass:[model class] name:name tableName:tblName path:path error:&error];
    if (!conf) {
        return [DWDatabaseResult failResultWithError:error];
    }
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    return [self dw_updateTableWithModel:model dbName:name tableName:tblName keys:keys inQueue:conf.dbQueue updateChains:nil recursive:YES condition:nil];
}

-(NSArray<NSObject *> *)queryTableAutomaticallyWithClass:(Class)clazz name:(NSString *)name tableName:(NSString *)tblName path:(NSString *)path keys:(NSArray *)keys error:(NSError * _Nullable __autoreleasing *)error condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    
    if (!clazz) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        safeLinkError(error, err);
        return nil;
    }
    
    DWDatabaseConfiguration * conf = [self fetchDBConfigurationAutomaticallyWithClass:clazz name:name tableName:tblName path:path error:error];
    if (!conf) {
        return nil;
    }
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue error:error condition:condition];
}

///配置数据库
-(BOOL)configDBIfNeededWithName:(NSString *)name path:(NSString *)path error:(NSError * __autoreleasing *)error {
    if (!name.length) {
        NSError * err = errorWithMessage(@"Invalid name whose length is 0.", 10000);
        safeLinkError(error, err);
        return NO;
    }
    if ([self.allDBs_prv.allKeys containsObject:name]) {
        NSError * err = errorWithMessage(@"Invalid name which there's already an database with it.If you are sure to use this name with a new database,delete the old one first.", 10001);
        safeLinkError(error,err);
        return YES;
    }
    if (!path.length) {
        path = [[defaultSavePath() stringByAppendingPathComponent:generateUUID()] stringByAppendingPathExtension:@"sqlite3"];
    }
    
    FMDatabaseQueue * q = [self openDBQueueWithName:name path:path private:NO];
    BOOL success = (q != nil);
    ///创建数据库，若成功则保存
    if (!success) {
        NSError * err = errorWithMessage(@"Invalid path which FMDatabaseQueue could not open.", 10003);
        safeLinkError(error, err);
        return NO;
    }
    
    DWDatabaseInfo * info = [DWDatabaseInfo new];
    info.dbName = name;
    info.dbPath = path;
    if ([info configRelativePath]) {
        [self dw_insertTableWithModel:info dbName:kSqlSetDbName tableName:kSqlSetTblName keys:nil inQueue:self.privateQueue insertChains:nil recursive:NO];
    } else {
        success = NO;
    }
    return success;
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
        result = [self dw_deleteTableWithTableName:kSqlSetTblName inQueue:self.privateQueue condition:^(DWDatabaseConditionMaker * maker) {
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

-(DWDatabaseConfiguration *)fetchDBConfigurationWithName:(NSString *)name error:(NSError *__autoreleasing *)error {
    if (!name.length) {
        NSError * err = errorWithMessage(@"Invalid name whose length is 0.", 10000);
        safeLinkError(error, err);
        return nil;
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
        NSError * err = errorWithMessage(@"Can't not fetch a FMDatabaseQueue", 10004);
        safeLinkError(error, err);
        return nil;
    }
    return [[DWDatabaseConfiguration alloc] initWithName:name tblName:nil dbq:dbqTmp];
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

-(NSArray<NSString *> *)queryAllTableNamesInDBWithConfiguration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing *)error {
    
    BOOL valid = [self validateConfiguration:conf considerTableName:NO].success;
    if (!valid) {
        return nil;
    }
    
    NSMutableArray * arr = [NSMutableArray arrayWithCapacity:0];
    [self queryTableWithSQL:@"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name" configuration:conf completion:^(FMResultSet * _Nullable set, NSError * _Nullable err) {
        safeLinkError(error, err);
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
    return arr;
}

-(BOOL)createTableWithClass:(Class)cls tableName:(NSString *)tblName configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing *)error {
    BOOL valid = [self validateConfiguration:conf considerTableName:NO].success;
    if (!valid) {
        return NO;
    }
    return [self dw_createTableWithClass:cls tableName:tblName inQueue:conf.dbQueue error:error];
}

-(BOOL)createTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf error:(NSError * __autoreleasing *)error {
    
    BOOL valid = [self validateConfiguration:conf considerTableName:NO].success;
    if (!valid) {
        return NO;
    }
    
    if (!sql.length) {
        NSError * err = errorWithMessage(@"Invalid sql whose length is 0.", 10007);
        safeLinkError(error, err);
        return NO;
    }
    
    __block BOOL success = NO;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            ///建表
            success = [db executeUpdate:sql];
            safeLinkError(error, db.lastError);
        }];
    });
    return success;
}

-(DWDatabaseConfiguration *)fetchDBConfigurationWithName:(NSString *)name tabelName:(NSString *)tblName error:(NSError *__autoreleasing *)error {
    if (!tblName.length) {
        NSError * err = errorWithMessage(@"Invalid tblName whose length is 0.", 10005);
        safeLinkError(error, err);
        return nil;
    }
    
    DWDatabaseConfiguration * confTmp = [self fetchDBConfigurationWithName:name error:error];
    if (!confTmp) {
        return nil;
    }
    
    if (![self isTableExistWithTableName:tblName configuration:confTmp].success) {
        return nil;
    }
    return [[DWDatabaseConfiguration alloc] initWithName:name tblName:tblName dbq:confTmp.dbQueue];
}

-(BOOL)updateTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing *)error {
    
    BOOL valid = [self validateConfiguration:conf considerTableName:NO].success;
    if (!valid) {
        return NO;
    }
    
    if (!sql.length) {
        NSError * err = errorWithMessage(@"Invalid sql whose length is 0.", 10007);
        safeLinkError(error, err);
        return NO;
    }
    
    __block BOOL success = NO;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            success = [db executeUpdate:sql];
            safeLinkError(error, db.lastError);
        }];
    });
    return success;
}

-(BOOL)updateTableWithSQLs:(NSArray<NSString *> *)sqls rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing *)error {
    
    BOOL valid = [self validateConfiguration:conf considerTableName:NO].success;
    if (!valid) {
        return NO;
    }
    
    if (!sqls.count) {
        NSError * err = errorWithMessage(@"Invalid sqls whose count is 0.", 10007);
        safeLinkError(error, err);
        return NO;
    }
    
    __block BOOL success = NO;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            [sqls enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.length) {
                    success = [db executeUpdate:obj];
                    if (!success && rollback) {
                        *stop = YES;
                        *rollback = YES;
                    }
                    safeLinkError(error, db.lastError);
                }
            }];
        }];
    });
    return success;
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

-(NSArray<NSString *> *)queryAllFieldInTable:(BOOL)translateToPropertyName class:(Class)cls configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing  _Nullable *)error {
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
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
        return fields;
    }
    if (translateToPropertyName && cls == Nil) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        safeLinkError(error, err);
        return nil;
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
    
    ///如果个数不相等说明转换出现了问题
    if (propNames.count != fields.count) {
        NSError * err = errorWithMessage(@"Something wrong on translating fieldsName to propertyName.Checkout the result of propertyNames and find the reason.", 10020);
        safeLinkError(error, err);
    }
    return propNames;
}

-(DWDatabaseResult *)clearTableWithConfiguration:(DWDatabaseConfiguration *)conf {
    
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    result.result = nil;
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
    
    result.result = nil;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            result.success = [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@",conf.tableName]];
            result.error = db.lastError;
        }];
    });
    return result;
}

-(DWDatabaseResult *)insertTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf {
    return [self _entry_insertTableWithModel:model keys:keys configuration:conf insertChains:nil];
}

-(NSArray<NSObject *> *)insertTableWithModels:(NSArray<NSObject *> *)models keys:(NSArray<NSString *> *)keys  rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing  _Nullable *)error {
    DWDatabaseOperationChain * insertChains = [DWDatabaseOperationChain new];
    NSMutableArray * failures = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * factorys = [NSMutableArray arrayWithCapacity:0];
    [models enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DWDatabaseSQLFactory * fac = [self insertSQLFactoryWithModel:obj dbName:conf.dbName tableName:conf.tableName keys:keys insertChains:insertChains recursive:YES].result;
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
        return [models subarrayWithRange:NSMakeRange(idx, models.count - idx)];
    }
    
    __block BOOL hasFailure = NO;
    ///使用一个临时的Error，防止由于原生error已经被释放后野指针调用崩溃问题
    __block NSError * errorRetain;
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollbackP) {
            [factorys enumerateObjectsUsingBlock:^(DWDatabaseSQLFactory * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                ///如果还没失败过则执行插入操作
                if (!hasFailure) {
                    ///如果插入失败则记录失败状态并将模型加入失败数组
                    [self supplyFieldIfNeededWithClass:[obj.model class] configuration:conf];
                    if (![self insertIntoDBWithDatabase:db factory:obj].success) {
                        hasFailure = YES;
                        [failures addObject:obj.model];
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
    
    safeLinkError(error, errorRetain);
    return failures.count?failures:nil;
}

-(void)insertTableWithModels:(NSArray<NSObject *> *)models keys:(NSArray<NSString *> *)keys rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf completion:(void (^)(NSArray<NSObject *> * _Nonnull, NSError * _Nonnull))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        NSError * error;
        NSMutableArray * ret = (NSMutableArray *)[self insertTableWithModels:models keys:keys rollbackOnFailure:rollback configuration:conf error:&error];
        if (completion) {
            completion(ret,error);
        }
    });
}

-(DWDatabaseResult *)deleteTableWithConfiguration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker *))condition {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    return [self dw_deleteTableWithTableName:conf.tableName inQueue:conf.dbQueue condition:condition];
}

-(DWDatabaseResult *)deleteTableWithModel:(NSObject *)model configuration:(DWDatabaseConfiguration *)conf {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    if (!model) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model who is nil.", 10016)];
    }
    
    NSNumber * Dw_id = Dw_idFromModel(model);
    if (!Dw_id) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid model whose Dw_id is nil.", 10016)];
    }
    
    result = [self deleteTableWithConfiguration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.loadClass([model class]);
        maker.conditionWith(kUniqueID).equalTo(Dw_id);
    }];
    
    if (result.success) {
        SetDw_idForModel(model, nil);
    }
    
    return result;
}

-(DWDatabaseResult *)updateTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    return [self _entry_updateTableWithModel:model keys:keys configuration:conf updateChains:nil recursive:YES condition:condition];
}

-(NSArray <NSObject *>*)queryTableWithClass:(Class)clazz keys:(NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending configuration:(DWDatabaseConfiguration *)conf error:(NSError * _Nullable __autoreleasing *)error condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    
    if (!clazz && !condition) {
        NSError * err = errorWithMessage(@"Invalid query without any condition.", 10010);
        safeLinkError(error, err);
        return nil;
    }
    
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:conf.dbQueue  error:error condition:condition];
}

-(void)queryTableWithClass:(Class)clazz keys:(NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending configuration:(DWDatabaseConfiguration *)conf condition:(void(^)(DWDatabaseConditionMaker * maker))condition completion:(void (^)(NSArray<__kindof NSObject *> *, NSError *))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        NSError * error;
        NSMutableArray * ret = (NSMutableArray *)[self queryTableWithClass:clazz keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending configuration:conf error:&error condition:condition];
        if (completion) {
            completion(ret,error);
        }
    });
}

-(NSArray<NSObject *> *)queryTableWithSQL:(NSString *)sql class:(Class)cls configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing  _Nullable *)error {
    if (!sql.length) {
        NSError * err = errorWithMessage(@"Invalid sql whose length is 0.", 10007);
        safeLinkError(error, err);
        return nil;
    }
    
    if (cls == Nil) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        safeLinkError(error, err);
        return nil;
    }
    
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
    }
    
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* props = [self propertyInfosForSaveKeysWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSMutableArray * ret = [NSMutableArray arrayWithCapacity:0];
    __block BOOL returnNil = NO;
    [self queryTableWithSQL:sql configuration:conf completion:^(FMResultSet * _Nullable set, NSError * _Nullable err) {
        safeLinkError(error, err);
        if (set) {
            while ([set next]) {
                id tmp = [cls new];
                if (!tmp) {
                    NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
                    safeLinkError(error, err);
                    returnNil = YES;
                    break;
                }
                __block BOOL validValue = NO;
                [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
                    if (obj.name.length) {
                        NSString * name = propertyInfoTblName(obj, map);
                        if (name.length) {
                            id value = [set objectForColumn:name];
                            [tmp dw_setValue:value forPropertyInfo:obj];
                            validValue = YES;
                        }
                    }
                }];
                if (validValue) {
                    NSNumber * Dw_id = [set objectForColumn:kUniqueID];
                    if (Dw_id) {
                        SetDw_idForModel(tmp, Dw_id);
                    }
                    [ret addObject:tmp];
                }
            }
        }
    }];
    
    if (returnNil) {
        return nil;
    }

    return ret;
}

-(void)queryTableWithSQL:(NSString *)sql class:(Class)cls configuration:(DWDatabaseConfiguration *)conf completion:(void (^)(NSArray<__kindof NSObject *> * _Nonnull, NSError * _Nonnull))completion {
    asyncExcuteOnDBOperationQueue(self, ^{
        NSError * error;
        NSMutableArray * ret = (NSMutableArray *)[self queryTableWithSQL:sql class:cls configuration:conf error:&error];
        if (completion) {
            completion(ret,error);
        }
    });
}

-(NSArray<NSObject *> *)queryTableWithClass:(Class)clazz keys:(NSArray *)keys configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing *)error condition:(void (^)(DWDatabaseConditionMaker * ))condition {
    
    if (!clazz && !condition) {
        NSError * err = errorWithMessage(@"Invalid query without any condition.", 10010);
        safeLinkError(error, err);
        return nil;
    }
    
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    return [self dw_queryTableWithDbName:conf.dbName tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue error:error condition:condition];
}

-(NSInteger)queryTableForCountWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf error:(NSError * _Nullable __autoreleasing *)error condition:(void (^)(DWDatabaseConditionMaker * _Nonnull))condition {
    
    if (!clazz && !condition) {
        NSError * err = errorWithMessage(@"Invalid query without any condition.", 10010);
        safeLinkError(error, err);
        return -1;
    }
    
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return -1;
    }
    
    if (!condition) {
        condition = ^(DWDatabaseConditionMaker * maker) {
            maker.loadClass(clazz);
        };
    }
    
    return [self dw_queryTableForCountWithTableName:conf.tableName inQueue:conf.dbQueue error:error condition:condition];
}

-(NSObject *)queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf error:(NSError *__autoreleasing  _Nullable *)error {
    if (!Dw_id) {
        NSError * err = errorWithMessage(@"Invalid Dw_id who is Nil.", 10018);
        safeLinkError(error, err);
        return nil;
    }
    BOOL valid = [self validateConfiguration:conf considerTableName:YES].success;
    if (!valid) {
        return nil;
    }
    
    return [self dw_queryTableWithClass:cls tableName:conf.tableName keys:keys limit:0 offset:0 orderKey:nil ascending:YES inQueue:conf.dbQueue error:error condition:^(DWDatabaseConditionMaker *maker) {
        maker.loadClass(cls);
        maker.conditionWith(kUniqueID).equalTo(Dw_id);
    } resultSetHandler:^(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, BOOL *stop, BOOL *returnNil, NSError *__autoreleasing *error) {
        id tmp = [cls new];
        if (!tmp) {
            NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
            safeLinkError(error, err);
            *stop = YES;
            *returnNil = YES;
            return;
        }
        __block BOOL validValue = NO;
        [validProInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.name.length) {
                NSString * name = propertyInfoTblName(obj, databaseMap);
                if (name.length) {
                    id value = [set objectForColumn:name];
                    [tmp dw_setValue:value forPropertyInfo:obj];
                    validValue = YES;
                }
            }
        }];
        if (validValue) {
            NSNumber * Dw_id = [set objectForColumn:kUniqueID];
            if (Dw_id) {
                SetDw_idForModel(tmp, Dw_id);
            }
            [resultArr addObject:tmp];
            *stop = YES;
        }
    }].lastObject;
}

-(NSNumber *)fetchDw_idForModel:(NSObject *)model {
    if (!model) {
        return nil;
    }
    return Dw_idFromModel(model);
}

#pragma mark --- tool method ---
#pragma mark --- 内部入口 ---
-(DWDatabaseResult *)_entry_insertTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf insertChains:(DWDatabaseOperationChain *)insertChains {
    DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    [self supplyFieldIfNeededWithClass:[model class] configuration:conf];
    return [self dw_insertTableWithModel:model dbName:conf.dbName tableName:conf.tableName keys:keys inQueue:conf.dbQueue insertChains:insertChains recursive:YES];
}

-(DWDatabaseResult *)_entry_updateTableWithModel:(NSObject *)model keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
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
    
    return [self dw_updateTableWithModel:model dbName:conf.dbName tableName:conf.tableName keys:keys inQueue:conf.dbQueue updateChains:updateChains recursive:recursive condition:condition];
}

#pragma mark ------ 建表 ------
-(BOOL)dw_createTableWithClass:(Class)cls tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue error:(NSError * __autoreleasing *)error {
    if (cls == Nil) {
        NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
        safeLinkError(error, err);
        return NO;
    }
    if (!queue) {
        NSError * err = errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015);
        safeLinkError(error, err);
        return NO;
    }
    if (!tblName.length) {
        tblName = [NSStringFromClass(cls) stringByAppendingString:@"_tbl"];
    }
    
    DWDatabaseSQLFactory * fac = [self createSQLFactoryWithClass:cls tableName:tblName error:error];
    if (!fac) {
        return NO;
    }
    
    __block BOOL success = NO;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            ///建表
            success = [db executeUpdate:fac.sql];
            safeLinkError(error, db.lastError);
        }];
    });
    
    return success;
}

#pragma mark ------ 插入表 ------
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
    
    if (!insertChains && recursive) {
        insertChains = [DWDatabaseOperationChain new];
    }
    
    if (recursive) {
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
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            result = [self insertIntoDBWithDatabase:db factory:fac];
        }];
    });
    
    return result;
}

#pragma mark ------ 表删除 ------
-(DWDatabaseResult *)dw_deleteTableWithTableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
    NSError * error = nil;
    if (!queue) {
        error = errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015);
        return [DWDatabaseResult failResultWithError:error];
    }
    if (!tblName.length) {
        error = errorWithMessage(@"Invalid tblName whose length is 0.", 10005);
        return [DWDatabaseResult failResultWithError:error];
    }
    
    ///ID存在删除对应ID，不存在删除所有值相等的条目
    DWDatabaseResult * result = [self deleteSQLFactoryWithTableName:tblName condition:condition];
    if (!result.success) {
        return result;
    }
    
    DWDatabaseSQLFactory * fac = result.result;
    result.result = nil;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            result.success = [db executeUpdate:fac.sql withArgumentsInArray:fac.args];
            result.error = db.lastError;
        }];
    });
    
    return result;
}

#pragma mark ------ 更新表 ------
-(DWDatabaseResult *)dw_updateTableWithModel:(NSObject *)model dbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray <NSString *>*)keys inQueue:(FMDatabaseQueue *)queue updateChains:(DWDatabaseOperationChain *)updateChains recursive:(BOOL)recursive condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
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
    if (condition) {
        DWDatabaseResult * result = [self updateSQLFactoryWithModel:model tableName:tblName keys:keys condition:condition];
        if (!result.success) {
            return result;
        }
        DWDatabaseSQLFactory * fac = result.result;
        result = [DWDatabaseResult new];
        excuteOnDBOperationQueue(self, ^{
            [queue inDatabase:^(FMDatabase * _Nonnull db) {
                result.success = [db executeUpdate:fac.sql withArgumentsInArray:fac.args];
                result.error = db.lastError;
            }];
        });
        return result;
    } else {
        ///不存在ID则不做更新操作，做插入操作
        ///插入操作后最好把Dw_id赋值
        return [self dw_insertTableWithModel:model dbName:dbName tableName:tblName keys:keys inQueue:queue insertChains:nil recursive:YES];
    }
}

#pragma mark ------ 查询表 ------

-(NSArray <__kindof NSObject *>*)dw_queryTableWithClass:(Class)clazz tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue error:(NSError *__autoreleasing *)error condition:(void(^)(DWDatabaseConditionMaker * maker))condition resultSetHandler:(void(^)(Class cls,FMResultSet * set,NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*validProInfos,NSDictionary * databaseMap,NSMutableArray * resultArr,BOOL * stop,BOOL * returnNil,NSError * __autoreleasing * error))handler {
    if (!queue) {
        NSError * err = errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015);
        safeLinkError(error, err);
        return nil;
    }
    if (!tblName.length) {
        NSError * err = errorWithMessage(@"Invalid tblName whose length is 0.", 10005);
        safeLinkError(error, err);
        return nil;
    }
    if (!clazz && !condition) {
        NSError * err = errorWithMessage(@"Invalid query without any condition.", 10010);
        safeLinkError(error, err);
        return nil;
    }
    
    DWDatabaseSQLFactory * fac = [self querySQLFactoryWithClazz:clazz tblName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending error:error condition:condition];
    
    if (!fac) {
        return nil;
    }
    
    ///组装数组
    NSMutableArray * ret = [NSMutableArray arrayWithCapacity:0];
    __block BOOL returnNil = NO;
    excuteOnDBOperationQueue(self, ^{
        [queue inDatabase:^(FMDatabase * _Nonnull db) {
            FMResultSet * set = [db executeQuery:fac.sql withArgumentsInArray:fac.args];
            safeLinkError(error, db.lastError);
            ///获取带转换的属性
            NSDictionary * validPropertyInfo = fac.validPropertyInfos;
            Class cls = fac.clazz;
            NSDictionary * dbTransformMap = fac.dbTransformMap;
            BOOL stop = NO;
            
            while ([set next]) {
                if (handler) {
                    handler(cls,set,validPropertyInfo,dbTransformMap,ret,&stop,&returnNil,error);
                }
                if (stop) {
                    break;
                }
            }
            [set close];
        }];
    });

    if (returnNil) {
        return nil;
    }

    if (!ret.count) {
        NSError * err = errorWithMessage(@"There's no result with this conditions", 10011);
        safeLinkError(error, err);
    }
    return ret;
}

#pragma mark ------ SQL factory ------
-(DWDatabaseSQLFactory *)createSQLFactoryWithClass:(Class)cls tableName:(NSString *)tblName  error:(NSError *__autoreleasing *)error {
    NSDictionary * props = [self propertyInfosForSaveKeysWithClass:cls];
    if (!props.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no save key.",NSStringFromClass(cls)];
        NSError * err = errorWithMessage(msg, 10012);
        safeLinkError(error, err);
        return nil;
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
            NSError * err = errorWithMessage(msg, 10009);
            safeLinkError(error, err);
            return nil;
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
    return fac;
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
    
    NSDictionary * dbTransformMap = databaseMapFromClass(cls);
    
    
    [self handleInsertArgumentsWithPropertyInfos:infos dbName:dbName tblName:tblName dbTransformMap:dbTransformMap model:model insertChains:insertChains recursive:recursive validKeysContainer:validKeys argumentsContaienr:args objMap:objMap];
    
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
        sql = [self.sqlsCache valueForKey:cacheSqlKey];
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
            [self.sqlsCache setValue:sql forKey:cacheSqlKey];
        }
    }
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    fac.args = args;
    fac.model = model;
    fac.objMap = objMap;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(DWDatabaseResult *)deleteSQLFactoryWithTableName:(NSString *)tblName condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
    
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
    fac.sql = sql;
    fac.args = args;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(DWDatabaseResult *)updateSQLFactoryWithModel:(NSObject *)model tableName:(NSString *)tblName keys:(NSArray<NSString *> *)keys condition:(void (^)(DWDatabaseConditionMaker * maker))condition {
    NSDictionary * infos = nil;
    
    if (!condition) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who have no valid value to delete.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    condition(maker);
    Class cls = [maker fetchQueryClass];
    if (!cls && model) {
        cls = [model class];
    }
    
    if (!cls) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who hasn't load class.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10017)];
    }
    
    ///如果指定更新key则取更新key的infos信息
    if (keys.count) {
        keys = [self validKeysIn:keys forClass:cls];
        if (keys.count) {
            infos = [self propertyInfosWithClass:cls keys:keys];
        }
    } else {
        infos = [self propertyInfosForSaveKeysWithClass:cls];
    }
    if (!infos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid key.",model];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10013)];
    }
    
    NSMutableArray * conditionArgs = @[].mutableCopy;
    NSMutableArray * conditionStrings = @[].mutableCopy;
    NSMutableArray * validConditionKeys = @[].mutableCopy;
    NSArray * saveKeys = [self propertysToSaveWithClass:cls];
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * propertyInfos = [self propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithPropertyInfos:propertyInfos databaseMap:map];
    [maker make];
    [conditionArgs addObjectsFromArray:[maker fetchArguments]];
    [conditionStrings addObjectsFromArray:[maker fetchConditions]];
    [validConditionKeys addObjectsFromArray:[maker fetchValidKeys]];
    
    ///无有效插入值
    if (!conditionStrings.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid condition(%@) who have no valid value to update.",condition];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    ///存在ID可以做更新操作
    NSMutableArray * updateArgs = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray * validUpdateKeys = [NSMutableArray arrayWithCapacity:0];
    [self handleUpdateArgumentsWithPropertyInfos:infos map:map model:model validKeysContainer:validUpdateKeys argumentsContaienr:updateArgs];
    
    ///无有效插入值
    if (!updateArgs.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid model(%@) who have no valid value to update.",model];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10009)];
    }
    
    NSString * sql = nil;
    
    ///先尝试取缓存的sql
    NSArray * sqlCombineArray = [self combineArrayWith:validUpdateKeys extraToSort:conditionStrings];
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kUpdatePrefix class:cls tblName:tblName keys:sqlCombineArray];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache valueForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///先配置更新值得sql
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",tblName,[validUpdateKeys componentsJoinedByString:@","],[conditionStrings componentsJoinedByString:@" AND "]];
        ///计算完缓存sql
        if (cacheSqlKey.length) {
            [self.sqlsCache setValue:sql forKey:cacheSqlKey];
        }
    }
    
    NSMutableArray * args = [NSMutableArray arrayWithCapacity:updateArgs.count + conditionArgs.count];
    [args addObjectsFromArray:updateArgs];
    [args addObjectsFromArray:conditionArgs];
    
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    fac.args = args;
    fac.model = model;
    return [DWDatabaseResult successResultWithResult:fac];
}

-(DWDatabaseSQLFactory *)querySQLFactoryWithClazz:(Class)clazz tblName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending error:(NSError *__autoreleasing *)error condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    
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
            NSError * err = errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008);
            safeLinkError(error, err);
            return nil;
        }
        queryAll = YES;
    } else {
        ///如果不为空，则将keys与对应键值做交集
        keys = intersectionOfArray(keys, saveKeys);
        if (!keys.count) {
            NSError * err = errorWithMessage(@"Invalid query keys which has no key in save keys.", 10008);
            safeLinkError(error, err);
            return nil;
        }
    }
    
    NSMutableArray * validQueryKeys = [NSMutableArray arrayWithCapacity:0];
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*queryKeysProInfos = [self propertyInfosWithClass:cls keys:keys];
    
    if (!queryKeysProInfos.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid key to query.",NSStringFromClass(cls)];
        NSError * err = errorWithMessage(msg, 10009);
        safeLinkError(error, err);
        return nil;
    }
    
    ///获取查询字符串数组
    if (queryAll) {
        [validQueryKeys addObject:@"*"];
    } else {
        [validQueryKeys addObject:kUniqueID];
        [self handleQueryValidKeysWithPropertyInfos:queryKeysProInfos map:map validKeysContainer:validQueryKeys];
        if (validQueryKeys.count == 1) {
            NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no valid keys to query.",NSStringFromClass(cls)];
            NSError * err = errorWithMessage(msg, 10009);
            safeLinkError(error, err);
            return nil;
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
    NSArray * sqlCombineArray = [self combineArrayWith:validQueryKeys extraToSort:conditionStrings];
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
        if (args.count) {
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
    return fac;
}

#pragma mark ------ 其他 ------
-(DWDatabaseResult *)insertIntoDBWithDatabase:(FMDatabase *)db factory:(DWDatabaseSQLFactory *)fac {
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.success = [db executeUpdate:fac.sql withArgumentsInArray:fac.args];
    if (result.success) {
        SetDw_idForModel(fac.model, @(db.lastInsertRowId));
        result.result = @(db.lastInsertRowId);
    }
    result.error = db.lastError;
    return result;
}


-(NSArray <__kindof NSObject *>*)dw_queryTableWithDbName:(NSString *)dbName tableName:(NSString *)tblName keys:(NSArray *)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(NSString *)orderKey ascending:(BOOL)ascending inQueue:(FMDatabaseQueue *)queue error:(NSError *__autoreleasing *)error condition:(void(^)(DWDatabaseConditionMaker * maker))condition {

    return [self dw_queryTableWithClass:nil tableName:tblName keys:keys limit:limit offset:offset orderKey:orderKey ascending:ascending inQueue:queue error:error condition:condition resultSetHandler:^(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, BOOL *stop, BOOL *returnNil, NSError *__autoreleasing *error) {
        id tmp = [cls new];
        if (!tmp) {
            NSError * err = errorWithMessage(@"Invalid Class who is Nil.", 10017);
            safeLinkError(error, err);
            *stop = YES;
            *returnNil = YES;
            return;
        }
        __block BOOL validValue = NO;
        [validProInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.name.length) {
                NSString * name = propertyInfoTblName(obj, databaseMap);
                if (name.length) {
                    id value = [set objectForColumn:name];
                    [tmp dw_setValue:value forPropertyInfo:obj];
                    validValue = YES;
                }
            }
        }];
        if (validValue) {
            NSNumber * Dw_id = [set objectForColumn:kUniqueID];
            if (Dw_id) {
                SetDw_idForModel(tmp, Dw_id);
            }
            [resultArr addObject:tmp];
        }
    }];
}


-(NSInteger)dw_queryTableForCountWithTableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue error:(NSError *__autoreleasing *)error condition:(void(^)(DWDatabaseConditionMaker * maker))condition {
    if (!condition) {
        return -1;
    }
    NSArray * ret = [self dw_queryTableWithClass:nil tableName:tblName keys:nil limit:0 offset:0 orderKey:nil ascending:YES inQueue:queue error:error condition:condition resultSetHandler:^(__unsafe_unretained Class cls, FMResultSet *set, NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *validProInfos, NSDictionary *databaseMap, NSMutableArray *resultArr, BOOL *stop, BOOL *returnNil, NSError *__autoreleasing *error) {
        [resultArr addObject:@1];
    }];
    
    if (!ret) {
        return -1;
    }
    return ret.count;
}

-(DWDatabaseResult *)validateConfiguration:(DWDatabaseConfiguration *)conf considerTableName:(BOOL)consider {
    if (!conf) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid conf who is nil.", 10014)];
    }
    if (!conf.dbName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name whose length is 0.", 10000)];
    }
    if (![self.allDBs.allKeys containsObject:conf.dbName]) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid name who has been not managed by DWDatabase.", 10019)];
    }
    NSString * path = [self.allDBs valueForKey:conf.dbName];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString * msg = [NSString stringWithFormat:@"There's no local database at %@",path];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10021)];
    }
    if (!conf.dbQueue || ![self.dbqContainer.allKeys containsObject:conf.dbName]) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Can't not fetch a FMDatabaseQueue", 10004)];
    }
    if (!consider) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    if (!conf.tableName.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid tblName whose length is 0.", 10005)];
    }
    return [self isTableExistWithTableName:conf.tableName configuration:conf];
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

///模型存数据库需要保存的键值
-(NSArray *)propertysToSaveWithClass:(Class)cls {
    NSString * key = NSStringFromClass(cls);
    if (!key.length) {
        return nil;
    }
    
    ///有缓存取缓存
    NSArray * tmp = self.saveKeysCache[key];
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
    self.saveKeysCache[key] = tmp;
    return tmp;
}

///获取类指定键值的propertyInfo
-(NSDictionary *)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys {
    if (!cls) {
        return nil;
    }
    return [cls dw_propertyInfosForKeys:keys];
}

///类存表的所有属性信息
-(NSDictionary *)propertyInfosForSaveKeysWithClass:(Class)cls {
    NSString * key = NSStringFromClass(cls);
    if (!key) {
        return nil;
    }
    NSDictionary * infos = [self.saveInfosCache valueForKey:key];
    if (!infos) {
        NSArray * saveKeys = [self propertysToSaveWithClass:cls];
        infos = [self propertyInfosWithClass:cls keys:saveKeys];
        [self.saveInfosCache setValue:infos forKey:key];
    }
    return infos;
}

-(NSString *)sqlCacheKeyWithPrefix:(NSString *)prefix class:(Class)cls tblName:(NSString *)tblName keys:(NSArray <NSString *>*)keys {
    if (!keys.count) {
        return nil;
    }
    NSString * keyString = [keys componentsJoinedByString:@"-"];
    keyString = [NSString stringWithFormat:@"%@-%@-%@-%@",prefix,NSStringFromClass(cls),tblName,keyString];
    return keyString;
}

-(NSArray *)combineArrayWith:(NSArray <NSString *>*)array extraToSort:(NSArray <NSString *>*)extra {
    ///这里因为使用场景中，第一个数组为不关心排序的数组，故第一个数组直接添加，第二个数组排序后添加
    if (array.count + extra.count == 0) {
        return nil;
    }
    NSMutableArray * ctn = [NSMutableArray arrayWithCapacity:array.count + extra.count];
    if (array.count) {
        [ctn addObjectsFromArray:array];
    }
    
    if (extra.count) {
        extra = [extra sortedArrayUsingSelector:@selector(compare:)];
        [ctn addObjectsFromArray:extra];
    }
    
    return [ctn copy];
}

-(void)handleInsertArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props dbName:(NSString *)dbName tblName:(NSString *)tblName dbTransformMap:(NSDictionary *)dbTransformMap model:(NSObject *)model insertChains:(DWDatabaseOperationChain *)insertChains recursive:(BOOL)recursive validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args objMap:(NSMutableDictionary *)objMap {
    NSDictionary * inlineTblNameMap = inlineModelTblNameMapFromClass([model class]);
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
                                DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:operation.tblName error:nil];
                                DWDatabaseResult * result = [self dw_insertTableWithModel:value dbName:dbName tableName:tblConf.tableName keys:nil inQueue:tblConf.dbQueue insertChains:insertChains recursive:NO];
                                if (result.success) {
                                    [validKeys addObject:name];
                                    [args addObject:result.result];
                                    operation.finishOperationInChain = YES;
                                    objMap[obj.name] = result.result;
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
                                DWDatabaseConfiguration * dbConf = [self fetchDBConfigurationWithName:dbName error:nil];
                                ///建表
                                if (dbConf && [self createTableWithClass:obj.cls tableName:inlineTblName configuration:dbConf error:nil]) {
                                    ///获取表名数据库句柄
                                    DWDatabaseConfiguration * tblConf = [self fetchDBConfigurationWithName:dbName tabelName:inlineTblName error:nil];
                                    if (tblConf) {
                                        ///插入
                                        DWDatabaseResult * result = [self _entry_insertTableWithModel:value keys:nil configuration:tblConf insertChains:insertChains];
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

-(void)handleUpdateArgumentsWithPropertyInfos:(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)props map:(NSDictionary *)map model:(NSObject *)model validKeysContainer:(NSMutableArray *)validKeys argumentsContaienr:(NSMutableArray *)args {
    [props enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name) {
            id value = [model dw_valueForPropertyInfo:obj];
            NSString * name = propertyInfoTblName(obj, map);
            if (name.length) {
                name = [name stringByAppendingString:@" = ?"];
                [validKeys addObject:name];
                if (value) {
                    [args addObject:value];
                } else {
                    [args addObject:[NSNull null]];
                }
            }
        }
    }];
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

-(DWDatabaseResult *)supplyFieldIfNeededWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf {
    NSString * validKey = [NSString stringWithFormat:@"%@%@",conf.dbName,conf.tableName];
    if ([DWMetaClassInfo hasValidFieldSupplyForClass:clazz withValidKey:validKey]) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    NSError * error;
    NSArray * allKeysInTbl = [self queryAllFieldInTable:YES class:clazz configuration:conf error:&error];
    NSArray * propertyToSaveKey = [self propertysToSaveWithClass:clazz];
    NSArray * saveProArray = minusArray(propertyToSaveKey, allKeysInTbl);
    if (saveProArray.count == 0) {
        [DWMetaClassInfo validedFieldSupplyForClass:clazz withValidKey:validKey];
        return [DWDatabaseResult successResultWithResult:nil];
    } else {
        DWDatabaseResult * result = [DWDatabaseResult successResultWithResult:nil];
        NSDictionary * map = databaseMapFromClass(clazz);
        NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* propertys = [self propertyInfosWithClass:clazz keys:saveProArray];
        [propertys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            ///转化完成的键名及数据类型
            NSString * field = tblFieldStringFromPropertyInfo(obj,map);
            if (field.length) {
                NSString * sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@",conf.tableName,field];
                [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
                    result.success = [db executeUpdate:sql] && result.success;
                    result.error = db.lastError;
                }];
            } else {
                result.success = NO;
                *stop = YES;
            }
        }];
        
        if (result.success) {
            [DWMetaClassInfo validedFieldSupplyForClass:clazz withValidKey:validKey];
        }
        
        return result;
    }
}

-(NSArray <NSString *>*)validKeysIn:(NSArray <NSString *>*)keys forClass:(Class)clazz {
    if (!keys.count) {
        return nil;
    }
    NSArray * saveKeys = [self propertysToSaveWithClass:clazz];
    return intersectionOfArray(keys,saveKeys);
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

NS_INLINE void excuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block) {
    if (!block) {
        return;
    }
    if (dispatch_get_specific(dbOpQKey)) {
        block();
    } else {
        dispatch_sync(db.dbOperationQueue, block);
    }
}

NS_INLINE void asyncExcuteOnDBOperationQueue(DWDatabase * db,dispatch_block_t block) {
    if (!block) {
        return;
    }
    dispatch_async(db.dbOperationQueue, block);
}

NSString * const dbErrorDomain = @"com.DWDatabase.error";
///快速生成NSError
NS_INLINE NSError * errorWithMessage(NSString * msg,NSInteger code) {
    NSDictionary * userInfo = nil;
    if (msg.length) {
        userInfo = @{NSLocalizedDescriptionKey:msg};
    }
    return [NSError errorWithDomain:dbErrorDomain code:code userInfo:userInfo];
}

///安全赋error
NS_INLINE void safeLinkError(NSError * __autoreleasing * error ,NSError * error2Link) {
    if (error != NULL) {
        *error = error2Link;
    }
}

///获取键值转换表
NS_INLINE NSDictionary * databaseMapFromClass(Class cls) {
    NSDictionary * map = nil;
    if ([cls respondsToSelector:@selector(dw_modelKeyToDataBaseMap)]) {
        map = [cls dw_modelKeyToDataBaseMap];
    }
    return map;
}

///获取property对应的表名
static NSString * propertyInfoTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap) {
    NSString * name = property.tblName;
    if (!name.length) {
        ///取出原字段名，若转换表中存在转换关系，则替换为转换名
        if ([databaseMap.allKeys containsObject:property.name]) {
            id mapped = [databaseMap valueForKey:property.name];
            if ([mapped isKindOfClass:[NSString class]]) {
                name = mapped;
            } else {
                name = property.name;
            }
        } else {
            name = property.name;
        }
        property.tblName = name;
    }
    return name;
}

///以propertyInfo生成对应字段信息
static NSString * tblFieldStringFromPropertyInfo(DWPrefix_YYClassPropertyInfo * property,NSDictionary * databaseMap) {
    ///如果属性类型不在支持类型中，则返回nil
    if (!supportSavingWithPropertyInfo(property)) {
        return nil;
    }
    ///取出表字段名
    NSString * name = propertyInfoTblName(property, databaseMap);
    if (!name.length) {
        return nil;
    }

    ///根据不同类型分配不同的数据类型
    switch (property.type & DWPrefix_YYEncodingTypeMask) {
        case DWPrefix_YYEncodingTypeBool:
        case DWPrefix_YYEncodingTypeInt8:
        case DWPrefix_YYEncodingTypeUInt8:
        case DWPrefix_YYEncodingTypeInt16:
        case DWPrefix_YYEncodingTypeUInt16:
        case DWPrefix_YYEncodingTypeInt32:
        case DWPrefix_YYEncodingTypeUInt32:
        case DWPrefix_YYEncodingTypeInt64:
        case DWPrefix_YYEncodingTypeUInt64:
        {
            return [NSString stringWithFormat:@"%@ INTEGER",name];
        }
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            return [NSString stringWithFormat:@"%@ REAL",name];
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                case DWPrefix_YYEncodingTypeNSDate:
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    return [NSString stringWithFormat:@"%@ TEXT",name];
                }
                ///由于建表过程中NSNumber具体值尚未确定，无法推断出整形或浮点型，故此处统一转换为浮点型（因此不推荐使用NSNumber类型数据，建议直接使用基本类型数据）
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    return [NSString stringWithFormat:@"%@ REAL",name];
                }
                case DWPrefix_YYEncodingTypeNSData:
                case DWPrefix_YYEncodingTypeNSMutableData:
                case DWPrefix_YYEncodingTypeNSArray:
                case DWPrefix_YYEncodingTypeNSMutableArray:
                case DWPrefix_YYEncodingTypeNSDictionary:
                case DWPrefix_YYEncodingTypeNSMutableDictionary:
                case DWPrefix_YYEncodingTypeNSSet:
                case DWPrefix_YYEncodingTypeNSMutableSet:
                {
                    return [NSString stringWithFormat:@"%@ BLOB",name];
                }
                default:
                    ///此时考虑模型嵌套，直接以index保存另一张表中
                {
                    return [NSString stringWithFormat:@"%@ INTEGER",name];
                }
            }
        }
        case DWPrefix_YYEncodingTypeClass:
        case DWPrefix_YYEncodingTypeSEL:
        case DWPrefix_YYEncodingTypeCString:
        {
            return [NSString stringWithFormat:@"%@ TEXT",name];
        }
        default:
            break;
    }
    return nil;
}

///获取键值转换表
NS_INLINE NSDictionary * inlineModelTblNameMapFromClass(Class cls) {
    NSDictionary * map = nil;
    if ([cls respondsToSelector:@selector(dw_inlineModelTableNameMap)]) {
        map = [cls dw_inlineModelTableNameMap];
    }
    return map;
}

///获取property对应的表名
static NSString * inlineModelTblName(DWPrefix_YYClassPropertyInfo * property,NSDictionary * tblNameMap,NSString * parentTblName,NSString * existTblName) {
    NSString * name = property.inlineModelTblName;
    if (!name.length) {
        ///取出原字段名，若转换表中存在转换关系，则替换为转换名
        if ([tblNameMap.allKeys containsObject:property.name]) {
            id mapped = [tblNameMap valueForKey:property.name];
            if ([mapped isKindOfClass:[NSString class]]) {
                name = mapped;
            } else {
                ///如果未指定inline表名，应该考虑当前是否存在同样模型对应表，如果存在，则返回该表名
                if (existTblName.length) {
                    name = existTblName;
                } else {
                    name = [parentTblName stringByAppendingFormat:@"_inline_%@_tbl",property.name];
                }
            }
        } else {
            if (existTblName.length) {
                name = existTblName;
            } else {
                name = [parentTblName stringByAppendingFormat:@"_inline_%@_tbl",property.name];
            }
        }
        property.inlineModelTblName = name;
    }
    return name;
}

///支持存表的属性
static BOOL supportSavingWithPropertyInfo(DWPrefix_YYClassPropertyInfo * property) {
    static NSSet * supportSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportSet = [NSSet setWithObjects:
                      @(DWPrefix_YYEncodingTypeBool),
                      @(DWPrefix_YYEncodingTypeInt8),
                      @(DWPrefix_YYEncodingTypeUInt8),
                      @(DWPrefix_YYEncodingTypeInt16),
                      @(DWPrefix_YYEncodingTypeUInt16),
                      @(DWPrefix_YYEncodingTypeInt32),
                      @(DWPrefix_YYEncodingTypeUInt32),
                      @(DWPrefix_YYEncodingTypeInt64),
                      @(DWPrefix_YYEncodingTypeUInt64),
                      @(DWPrefix_YYEncodingTypeFloat),
                      @(DWPrefix_YYEncodingTypeDouble),
                      @(DWPrefix_YYEncodingTypeLongDouble),
                      @(DWPrefix_YYEncodingTypeObject),
                      @(DWPrefix_YYEncodingTypeClass),
                      @(DWPrefix_YYEncodingTypeSEL),
                      @(DWPrefix_YYEncodingTypeCString),nil];
    });
    return [supportSet containsObject:@(property.type)];
}

///获取额外配置字典
NS_INLINE NSMutableDictionary * additionalConfigFromModel(NSObject * model) {
    NSMutableDictionary * additionalConf = objc_getAssociatedObject(model, kAdditionalConfKey);
    if (!additionalConf) {
        additionalConf = [NSMutableDictionary dictionaryWithCapacity:0];
        objc_setAssociatedObject(model, kAdditionalConfKey, additionalConf, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return additionalConf;
}

///获取id
NS_INLINE NSNumber * Dw_idFromModel(NSObject * model) {
    return [additionalConfigFromModel(model) valueForKey:kDwIdKey];
}

///设置id
NS_INLINE void SetDw_idForModel(NSObject * model,NSNumber * dw_id) {
    [additionalConfigFromModel(model) setValue:dw_id forKey:kDwIdKey];
}

///获取两个数组的交集
NS_INLINE NSArray * intersectionOfArray(NSArray * arr1,NSArray * arr2) {
    if (!arr1.count || !arr2.count) {
        return nil;
    } else {
        NSMutableSet * set1 = [NSMutableSet setWithArray:arr1];
        NSSet * set2 = [NSSet setWithArray:arr2];
        [set1 intersectSet:set2];
        if (!set1.count) {
            return nil;
        }
        return [set1 allObjects];
    }
}

NS_INLINE NSArray * minusArray(NSArray * arr1,NSArray * arr2) {
    if (!arr1.count) {
        return nil;
    } else if (!arr2.count) {
        return arr1;
    } else {
        NSMutableSet * all = [NSMutableSet setWithArray:arr1];
        NSSet * black = [NSSet setWithArray:arr2];
        [all minusSet:black];
        if (!all.count) {
            return nil;
        }
        return [all allObjects];
    }
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

-(NSMutableDictionary *)dbqContainer {
    if (!_dbqContainer) {
        _dbqContainer = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _dbqContainer;
}

-(NSMutableDictionary *)saveKeysCache {
    if (!_saveKeysCache) {
        _saveKeysCache = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _saveKeysCache;
}

-(NSMutableDictionary *)saveInfosCache {
    if (!_saveInfosCache) {
        _saveInfosCache = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _saveInfosCache;
}

-(NSMutableDictionary *)sqlsCache {
    if (!_sqlsCache) {
        _sqlsCache = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _sqlsCache;
}
@end
#pragma mark --------- DWDatabase结束 ---------
