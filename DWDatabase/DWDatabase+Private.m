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

-(NSArray<DWDatabaseBindKeyWrapperContainer> *)seperateSubWrappers:(DWDatabaseBindKeyWrapperContainer)wrapper {
    NSMutableDictionary * mainWrappers = [NSMutableDictionary dictionaryWithCapacity:wrapper.count];
    NSMutableDictionary * subWrappers = [NSMutableDictionary dictionaryWithCapacity:wrapper.count];
    NSMutableArray * result = [NSMutableArray arrayWithCapacity:2];
    [result addObject:mainWrappers];
    [result addObject:subWrappers];
    [wrapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseBindKeyWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key containsString:@"."]) {
            [subWrappers setValue:obj forKey:key];
            if (![key hasPrefix:@"."]) {
                key = [key componentsSeparatedByString:@"."].firstObject;
                DWDatabaseBindKeyWrapper * tmp = [DWDatabaseBindKeyWrapper new];
                tmp.key = key;
                tmp.recursively = YES;
                [mainWrappers setValue:tmp forKey:key];
            }
        } else if (key.length > 0) {
            [mainWrappers setValue:obj forKey:key];
        }
    }];
    return result;
}

-(DWDatabaseBindKeyWrapperContainer)subKeyWrappersIn:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers withPrefix:(NSString *)prefix {
    if (!subKeyWrappers.allKeys.count || !prefix.length) {
        return nil;
    }
    
    NSInteger prefixLen = prefix.length + 1;
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:subKeyWrappers.allKeys.count];
    [subKeyWrappers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseBindKeyWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length > prefixLen && [key hasPrefix:prefix]) {
            key = [key substringFromIndex:prefixLen];
            obj.key = key;
            [result setObject:obj forKey:key];
        }
    }];
    return result;
}

-(DWDatabaseBindKeyWrapperContainer)subKeyWrappersIn:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers inKeys:(NSArray<NSString *> *)keys {
    if (!subKeyWrappers.allKeys.count || !keys.count) {
        return nil;
    }
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:keys.count];
    [keys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.length) {
            result[obj] = subKeyWrappers[obj];
        }
    }];
    return result;
}

-(DWDatabaseBindKeyWrapperContainer)saveKeysWrappersWithCls:(Class)cls {
    if (!cls) {
        return nil;
    }
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    if (!saveKeys.count) {
        return nil;
    }
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:saveKeys.count];
    [saveKeys enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.length) {
            DWDatabaseBindKeyWrapper * tmp = [DWDatabaseBindKeyWrapper new];
            tmp.key = obj;
            [result setObject:tmp forKey:obj];
        }
    }];
    return result;
}

-(DWDatabaseBindKeyWrapperContainer)actualSubKeyWrappersIn:(DWDatabaseBindKeyWrapperContainer)subWrappers withPrefix:(NSString *)prefix {
    if (!subWrappers.allKeys.count || !prefix.length) {
        return nil;
    }
    prefix = [prefix stringByAppendingString:@"."];
    NSInteger prefixLen = prefix.length;
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:subWrappers.count];
    [subWrappers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseBindKeyWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length > prefixLen && [key hasPrefix:prefix]) {
            key = [key substringFromIndex:prefixLen];
            if (![key hasPrefix:@"."]) {
                key = [key componentsSeparatedByString:@"."].firstObject;
                obj.key = key;
                [result setObject:obj forKey:key];
            }
        }
    }];
    return result;
}

-(DWDatabaseBindKeyWrapperContainer)subKeyWrappersIn:(DWDatabaseBindKeyWrapperContainer)subKeyWrappers withPrefix:(NSString *)prefix actualSubKey:(NSString *)actualSubKey {
    if (!subKeyWrappers.allKeys.count || !prefix.length || !actualSubKey.length) {
        return nil;
    }
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:subKeyWrappers.allKeys.count];
    NSString * findKey = [NSString stringWithFormat:@"%@.%@",prefix,actualSubKey];
    
    NSInteger subLenFrom = prefix.length + 1;
    [subKeyWrappers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWDatabaseBindKeyWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length >= findKey.length && [key hasPrefix:findKey]) {
            key = [key substringFromIndex:subLenFrom];
            if ([key isEqualToString:actualSubKey]) {
                obj.key = key;
                [result setObject:obj forKey:key];
            } else {
                if ([key hasPrefix:@"."] && key.length > 1) {
                    key = [key substringFromIndex:1];
                    obj.key = key;
                    [result setObject:obj forKey:key];
                }
            }
        }
    }];
    return result;
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

@implementation DWPrefix_YYClassPropertyInfo (Private)

-(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)subPropertyInfos {
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setSubPropertyInfos:(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)subPropertyInfos {
    objc_setAssociatedObject(self, @selector(subPropertyInfos), subPropertyInfos, OBJC_ASSOCIATION_ASSIGN);
}

-(NSString *)tblName {
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setTblName:(NSString *)tblName {
    objc_setAssociatedObject(self, @selector(tblName), tblName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(NSString *)inlineModelTblName {
    return objc_getAssociatedObject(self, _cmd);
}

-(void)setInlineModelTblName:(NSString *)inlineModelTblName {
    objc_setAssociatedObject(self, @selector(inlineModelTblName), inlineModelTblName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
