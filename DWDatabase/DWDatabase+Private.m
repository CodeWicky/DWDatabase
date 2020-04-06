//
//  DWDatabaseOperationRecord.m
//  DWDatabase
//
//  Created by Wicky on 2019/12/2.
//

#import "DWDatabase+Private.h"
#import "DWDatabase.h"
#import "DWDatabaseFunction.h"

@implementation DWDatabaseInfo
#pragma mark --- interface method ---
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

#pragma mark --- DWDatabaseSaveProtocol ---
+(NSArray *)dw_dataBaseWhiteList {
    static NSArray * wl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wl = @[@"dbName",@"relativePath",@"relativeType"];
    });
    return wl;
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _relativeType = -1;
    }
    return self;
}

@end

@implementation DWDatabaseOperationRecord

@end

@interface DWDatabaseOperationChain ()

@property (nonatomic ,strong) NSMutableDictionary * records;

@end

@implementation DWDatabaseOperationChain

-(void)addRecord:(DWDatabaseOperationRecord *)record {
    if (!record.model) {
        return;
    }
    
    NSString * key = keyStringFromClass([record.model class]);
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
    NSString *key = keyStringFromClass([model class]);
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
            *stop = YES;
        }
    }];
    return result;
}

-(DWDatabaseOperationRecord *)recordInChainWithClass:(Class)cls Dw_Id:(NSNumber *)dw_id {
    if (!dw_id) {
        return nil;
    }
    NSString *key = keyStringFromClass(cls);
    if (!key.length) {
        return nil;
    }
    NSArray * records = self.records[key];
    if (!records) {
        return nil;
    }
    __block DWDatabaseOperationRecord * result = nil;
    [records enumerateObjectsUsingBlock:^(DWDatabaseOperationRecord * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber * objId = [DWDatabase fetchDw_idForModel:obj.model];
        if ([objId isEqualToNumber:dw_id]) {
            result = obj;
            *stop = YES;
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

-(DWDatabaseResult *)existRecordWithClass:(Class)cls Dw_Id:(NSNumber *)dw_id {
    DWDatabaseOperationRecord * record = [self recordInChainWithClass:cls Dw_Id:dw_id];
    if (!record) {
        return [DWDatabaseResult failResultWithError:nil];
    }
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.success = YES;
    result.result = record;
    return result;
}

#pragma mark --- tool func ---
NS_INLINE NSString * keyStringFromClass(Class cls) {
    if (cls == NULL) {
        return nil;
    }
    return NSStringFromClass(cls);
}

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)records {
    if (!_records) {
        _records = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _records;
}

@end

@implementation DWDatabaseSQLFactory

@end

@implementation DWDatabase (Private)
@dynamic dbqContainer,dbOperationQueue;
#pragma mark --- interface method ---
-(DWDatabaseResult *)excuteUpdate:(FMDatabase *)db WithFactory:(DWDatabaseSQLFactory *)fac clear:(BOOL)clear {
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.success = [db executeUpdate:fac.sql withArgumentsInArray:fac.args];
    if (result.success) {
        NSObject * model = fac.model;
        if (model) {
            if (clear) {
                SetDw_idForModel(model, nil);
                SetDbNameForModel(model, nil);
                SetTblNameForModel(model, nil);
            } else {
                SetDw_idForModel(model, @(db.lastInsertRowId));
                SetDbNameForModel(model, fac.dbName);
                SetTblNameForModel(model, fac.tblName);
            }
        }
        result.result = @(db.lastInsertRowId);
    }
    result.error = db.lastError;
    return result;
}

-(NSArray <NSString *>*)validKeysIn:(NSArray <NSString *>*)keys forClass:(Class)clazz {
    if (!keys.count) {
        return nil;
    }
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:clazz];
    return intersectionOfArray(keys,saveKeys);
}


-(NSDictionary *)propertyInfosForSaveKeysWithClass:(Class)cls {
    NSString * key = NSStringFromClass(cls);
    if (!key) {
        return nil;
    }
    NSDictionary * infos = [self.saveInfosCache objectForKey:key];
    if (!infos) {
        NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
        infos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
        [self.saveInfosCache setObject:infos forKey:key];
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

-(DWDatabaseResult *)supplyFieldIfNeededWithClass:(Class)clazz configuration:(DWDatabaseConfiguration *)conf {
    NSString * validKey = [NSString stringWithFormat:@"%@%@",conf.dbName,conf.tableName];
    if ([DWMetaClassInfo hasValidFieldSupplyForClass:clazz withValidKey:validKey]) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    
    NSArray * allKeysInTbl = [self queryAllFieldInTable:YES class:clazz configuration:conf].result;
    NSArray * propertyToSaveKey = [DWDatabase propertysToSaveWithClass:clazz];
    NSArray * saveProArray = minusArray(propertyToSaveKey, allKeysInTbl);
    if (saveProArray.count == 0) {
        [DWMetaClassInfo validedFieldSupplyForClass:clazz withValidKey:validKey];
        return [DWDatabaseResult successResultWithResult:nil];
    } else {
        DWDatabaseResult * result = [DWDatabaseResult successResultWithResult:nil];
        NSDictionary * map = databaseMapFromClass(clazz);
        NSDictionary * defaultValueMap = databaseFieldDefaultValueMapFromClass(clazz);
        NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* propertys = [DWDatabase propertyInfosWithClass:clazz keys:saveProArray];
        [propertys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            ///转化完成的键名及数据类型
            NSString * field = tblFieldStringFromPropertyInfo(obj,map,defaultValueMap);
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

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)dbqContainer {
    NSMutableDictionary * ctn = objc_getAssociatedObject(self, _cmd);
    if (!ctn) {
        ctn = [NSMutableDictionary dictionaryWithCapacity:0];
        objc_setAssociatedObject(self, _cmd, ctn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return ctn;
}

-(NSCache *)saveInfosCache {
    NSCache * cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [NSCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

-(NSCache *)sqlsCache {
    NSCache * cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [NSCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

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
