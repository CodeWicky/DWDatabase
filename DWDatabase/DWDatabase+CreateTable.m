//
//  DWDatabase+CreateTable.m
//  DWDatabase
//
//  Created by Wicky on 2020/3/31.
//

#import "DWDatabase+CreateTable.h"
#import "DWDatabaseFunction.h"

#define kCreatePrefix (@"c")

@implementation DWDatabase (CreateTable)

#pragma mark --- interface method ---
-(DWDatabaseResult *)dw_createTableWithClass:(nullable Class)cls tableName:(NSString *)tblName inQueue:(FMDatabaseQueue *)queue condtion:(nullable DWDatabaseConditionHandler)condition {
    
    DWDatabaseConditionMaker * maker = nil;
    Class clazz = NULL;
    if (condition) {
        maker = [DWDatabaseConditionMaker new];
        condition(maker);
        clazz = [maker fetchQueryClass];
        if (clazz != NULL) {
            if (cls) {
                maker.loadClass(cls);
                clazz = cls;
            }
        }
    } else {
        clazz = cls;
    }
    
    if (clazz == NULL) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid Class who is Nil.", 10017)];
    }
    if (!queue) {
        return [DWDatabaseResult failResultWithError:errorWithMessage(@"Invalid FMDatabaseQueue who is nil.", 10015)];
    }
    if (!tblName.length) {
        tblName = [NSStringFromClass(cls) stringByAppendingString:@"_tbl"];
    }
    
    DWDatabaseResult * result = [self createSQLFactoryWithClass:clazz tableName:tblName conditionMaker:maker];
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

#pragma mark --- tool method ---
-(DWDatabaseResult *)createSQLFactoryWithClass:(Class)cls tableName:(NSString *)tblName conditionMaker:(DWDatabaseConditionMaker *)maker {
    NSDictionary * props = [self propertyInfosForSaveKeysWithClass:cls];
    DWDatabaseBindKeyWrapperContainer bindedKeys = nil;
    if (maker) {
        bindedKeys = [maker fetchBindKeys];
    }
    if (!props.allKeys.count) {
        NSString * msg = [NSString stringWithFormat:@"Invalid Class(%@) who have no save key.",NSStringFromClass(cls)];
        return [DWDatabaseResult failResultWithError:errorWithMessage(msg, 10012)];
    }
    
    NSString * sql = nil;
    ///先尝试取缓存的sql
    NSString * cacheSqlKey = [self sqlCacheKeyWithPrefix:kCreatePrefix class:cls tblName:tblName keys:@[@"CREATE-SQL"]];
    if (cacheSqlKey.length) {
        sql = [self.sqlsCache objectForKey:cacheSqlKey];
    }
    ///如果没有缓存的sql则拼装sql
    if (!sql) {
        ///添加模型表键值转化
        NSDictionary * map = databaseMapFromClass(cls);
        NSDictionary * defaultValueMap = databaseFieldDefaultValueMapFromClass(cls);
        NSMutableArray * validKeys = [NSMutableArray arrayWithCapacity:0];
        [props enumerateKeysAndObjectsUsingBlock:^(NSString * key, DWPrefix_YYClassPropertyInfo * obj, BOOL * _Nonnull stop) {
            ///转化完成的键名及数据类型
            NSString * field = tblFieldStringFromPropertyInfo(obj,map,defaultValueMap);
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
            [self.sqlsCache setObject:sql forKey:cacheSqlKey];
        }
    }
    DWDatabaseSQLFactory * fac = [DWDatabaseSQLFactory new];
    fac.sql = sql;
    return [DWDatabaseResult successResultWithResult:fac];
}



@end
