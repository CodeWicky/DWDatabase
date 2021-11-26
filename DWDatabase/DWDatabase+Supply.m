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
    NSMutableSet * keysToSupply = [NSMutableSet setWithArray:keys];
    [keysToSupply minusSet:[NSSet setWithArray:allKeysInTbl]];
    if (keysToSupply.count == 0) {
        return [DWDatabaseResult successResultWithResult:nil];
    }
    
    NSArray * saveProArray = keysToSupply.allObjects;
    NSDictionary * map = databaseMapFromClass(cls);
    NSDictionary * defaultValueMap = databaseFieldDefaultValueMapFromClass(cls);
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* propertys = [DWDatabase propertyInfosWithClass:cls keys:saveProArray];
    [propertys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        ///转化完成的键名及数据类型
        result = [self dw_addFieldsToTableForClass:cls withKey:key propertyInfo:obj dbMap:map defaultValueMap:defaultValueMap configuration:conf];
        
        if (!result.success) {
            *stop = YES;
        }
    }];
    
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
