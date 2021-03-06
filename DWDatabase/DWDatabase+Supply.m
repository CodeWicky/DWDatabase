//
//  DWDatabase+Supply.m
//  DWDatabase
//
//  Created by Wicky on 2020/4/7.
//

#import "DWDatabase+Supply.h"
#import <DWKit/NSObject+DWObjectUtils.h>
#import <objc/runtime.h>
#import "DWDatabaseFunction.h"
#import "DWDatabase+Private.h"

@interface DWMetaClassInfo (Supply)

@property (nonatomic ,strong ,readonly) NSMutableSet * fieldsSuppliedSet;

@property (nonatomic ,assign) BOOL hasSuppliedTblFields;

@end

@implementation DWMetaClassInfo (Supply)

+(NSArray *)fieldsToSupplyForClass:(Class)cls withKeys:(NSArray <NSString *>*)keys {
    if (cls == NULL) {
        return nil;
    }
    if (keys.count == 0) {
        return nil;
    }
    DWMetaClassInfo * classInfo = [self classInfoFromClass:cls];
    NSMutableSet * keysToSupply = [NSMutableSet setWithArray:keys];
    [keysToSupply minusSet:classInfo.fieldsSuppliedSet];
    if (keysToSupply.count == 0) {
        return nil;
    }
    return keysToSupply.allObjects;
}

+(void)supplyFieldsForClass:(Class)cls withKeys:(NSArray <NSString *>*)keys {
    NSArray * keysToSupply = [self fieldsToSupplyForClass:cls withKeys:keys];
    if (!keysToSupply.count) {
        return;
    }
    DWMetaClassInfo * classInfo = [self classInfoFromClass:cls];
    [classInfo.fieldsSuppliedSet addObjectsFromArray:keysToSupply];
}

+(void)supplyTblFieldsForClass:(Class)cls withKeys:(NSArray <NSString *>*)keys {
    if (cls == NULL) {
        return;
    }
    if (keys.count == 0) {
        return;
    }
    DWMetaClassInfo * classInfo = [self classInfoFromClass:cls];
    if (classInfo.hasSuppliedTblFields) {
        return;
    }
    [self supplyFieldsForClass:cls withKeys:keys];
    classInfo.hasSuppliedTblFields = YES;
}

#pragma mark --- setter/getter ---
-(NSMutableSet *)fieldsSuppliedSet {
    NSMutableSet * set = objc_getAssociatedObject(self, _cmd);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(self, _cmd, set, OBJC_ASSOCIATION_RETAIN);
    }
    return set;
}

-(BOOL)hasSuppliedTblFields {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

-(void)setHasSuppliedTblFields:(BOOL)hasSuppliedTblFields {
    objc_setAssociatedObject(self, @selector(hasSuppliedTblFields), @(hasSuppliedTblFields), OBJC_ASSOCIATION_ASSIGN);
}

@end

@implementation DWDatabase (Supply)

-(DWDatabaseResult *)_entry_supplyFieldIfNeededWithClass:(Class)cls configuration:(DWDatabaseConfiguration *)conf {
    NSArray * propertyToSaveKey = [DWDatabase propertysToSaveWithClass:cls];
    return [self _entry_addFieldsToTableWithClass:cls keys:propertyToSaveKey configuration:conf];
}

-(DWDatabaseResult *)_entry_addFieldsToTableWithClass:(Class)cls keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf {
    
    __block DWDatabaseResult * result = [self validateConfiguration:conf considerTableName:YES];
    if (!result.success) {
        return result;
    }
    
    NSArray * allKeysInTbl = [self queryAllFieldInTable:YES class:cls configuration:conf].result;
    [DWMetaClassInfo supplyTblFieldsForClass:cls withKeys:allKeysInTbl];
    NSArray * saveProArray = [DWMetaClassInfo fieldsToSupplyForClass:cls withKeys:keys];
    if (saveProArray.count == 0) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * defaultValueMap = databaseFieldDefaultValueMapFromClass(cls);
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* propertys = [DWDatabase propertyInfosWithClass:cls keys:saveProArray];
    NSMutableArray * successKeys = [NSMutableArray arrayWithCapacity:propertys.count];
    [propertys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        ///转化完成的键名及数据类型
        result = [self dw_addFieldsToTableForClass:cls withKey:key propertyInfo:obj dbMap:map defaultValueMap:defaultValueMap configuration:conf];
        
        if (!result.success) {
            *stop = YES;
        } else {
            if (obj.name.length) {
                [successKeys addObject:obj.name];
            }
        }
    }];
    
    if (successKeys.count) {
        [DWMetaClassInfo supplyFieldsForClass:cls withKeys:successKeys];
    }
    
    return result;
}

-(DWDatabaseResult *)dw_addFieldsToTableForClass:(Class)cls withKey:(NSString *)key propertyInfo:(DWPrefix_YYClassPropertyInfo *)propertyInfo dbMap:(NSDictionary *)dbMap defaultValueMap:(NSDictionary *)defaultValueMap configuration:(DWDatabaseConfiguration *)conf {
    if (cls == NULL) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Fail adding fields because the supply class is NULL.", 10025)];
    }
    if (!key.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Fail adding fields because the supply key's length is 0.", 10025)];
    }
    
    NSString * field = tblFieldStringFromPropertyInfo(propertyInfo,dbMap,defaultValueMap);
    if (!field.length) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Fail adding fields by failing fetch tblField for key.", 10026)];
    }
    
    DWDatabaseResult * result = [DWDatabaseResult new];
    excuteOnDBOperationQueue(self, ^{
        [conf.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
            NSString * sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@",conf.tableName,field];
            result.success = [db executeUpdate:sql];
            result.error = db.lastError;
            if (result.success) {
                result.result = key;
            }
        }];
    });
    
    return result;
}

@end
