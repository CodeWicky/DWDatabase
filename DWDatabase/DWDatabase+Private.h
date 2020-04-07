//
//  DWDatabaseOperationRecord.h
//  DWDatabase
//
//  Created by Wicky on 2019/12/2.
//

#import <Foundation/Foundation.h>
#import "DWDatabaseResult.h"
#import "DWDatabase.h"

typedef NS_ENUM(NSUInteger, DWDatabaseOperation) {
    DWDatabaseOperationUndefined,
    DWDatabaseOperationInsert,
    DWDatabaseOperationDelete,
    DWDatabaseOperationUpdate,
    DWDatabaseOperationQuery,
};

@interface DWDatabaseInfo : NSObject<DWDatabaseSaveProtocol>

@property (nonatomic ,copy) NSString * dbName;

@property (nonatomic ,copy) NSString * dbPath;

@property (nonatomic ,copy) NSString * relativePath;

///-1初始值，0沙盒，1bundle，2其他
@property (nonatomic ,assign) int relativeType;

-(BOOL)configDBPath;

-(BOOL)configRelativePath;

@end

@interface DWDatabaseOperationRecord : NSObject

@property (nonatomic ,strong) __kindof NSObject * model;

@property (nonatomic ,assign) DWDatabaseOperation operation;

@property (nonatomic ,copy) NSString * tblName;

@property (nonatomic ,assign) BOOL finishOperationInChain;

@property (nonatomic ,strong) id userInfo;

@end

@interface DWDatabaseOperationChain : NSObject

-(void)addRecord:(DWDatabaseOperationRecord *)record;

-(DWDatabaseOperationRecord *)recordInChainWithModel:(NSObject *)model;

-(DWDatabaseOperationRecord *)recordInChainWithClass:(Class)cls Dw_Id:(NSNumber *)dw_id;

-(DWDatabaseOperationRecord *)anyRecordInChainWithClass:(Class)cls;

-(DWDatabaseResult *)existRecordWithModel:(NSObject *)model;

-(DWDatabaseResult *)existRecordWithClass:(Class)cls Dw_Id:(NSNumber *)dw_id;

@end

@interface DWDatabaseSQLFactory : NSObject

@property (nonatomic ,copy) NSString * dbName;

@property (nonatomic ,copy) NSString * tblName;

@property (nonatomic ,strong) NSArray * args;

@property (nonatomic ,copy) NSString * sql;

@property (nonatomic ,strong) NSObject * model;

@property (nonatomic ,strong) NSMutableDictionary * objMap;

@property (nonatomic ,assign) Class clazz;

@property (nonatomic ,strong) NSDictionary * validPropertyInfos;

@property (nonatomic ,strong) NSDictionary * dbTransformMap;

@end

static void* dbOpQKey = "dbOperationQueueKey";
@interface DWDatabase (Private)

///当前使用过的数据库的FMDatabaseQueue的容器
@property (nonatomic ,strong) NSMutableDictionary <NSString *,FMDatabaseQueue *>* dbqContainer;

@property (nonatomic ,strong ,readonly) dispatch_queue_t dbOperationQueue;

@property (nonatomic ,strong ,readonly) NSCache * saveInfosCache;

@property (nonatomic ,strong ,readonly) NSCache * sqlsCache;

-(DWDatabaseResult *)excuteUpdate:(FMDatabase *)db WithFactory:(DWDatabaseSQLFactory *)fac clear:(BOOL)clear;

-(NSArray <NSString *>*)validKeysIn:(NSArray <NSString *>*)keys forClass:(Class)clazz;

-(NSDictionary *)propertyInfosForSaveKeysWithClass:(Class)cls;

-(NSString *)sqlCacheKeyWithPrefix:(NSString *)prefix class:(Class)cls tblName:(NSString *)tblName keys:(NSArray <NSString *>*)keys;

-(DWDatabaseResult *)validateConfiguration:(DWDatabaseConfiguration *)conf considerTableName:(BOOL)consider;

@end

@interface DWDatabaseConfiguration (Private)

@property (nonatomic ,strong) FMDatabaseQueue * dbQueue;

@property (nonatomic ,copy) NSString * dbName;

@property (nonatomic ,copy) NSString * tableName;

-(instancetype)initWithName:(NSString *)name tblName:(NSString * )tblName dbq:(FMDatabaseQueue *)dbq;

@end
