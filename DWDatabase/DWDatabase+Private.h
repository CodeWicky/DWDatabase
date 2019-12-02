//
//  DWDatabaseOperationRecord.h
//  DWDatabase
//
//  Created by Wicky on 2019/12/2.
//

#import <Foundation/Foundation.h>
#import "DWDatabaseResult.h"

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

@interface DWDatabaseOperationChain : NSObject

-(void)addRecord:(DWDatabaseOperationRecord *)record;

-(DWDatabaseOperationRecord *)recordInChainWithModel:(NSObject *)model;

-(DWDatabaseOperationRecord *)anyRecordInChainWithClass:(Class)cls;

-(DWDatabaseResult *)existRecordWithModel:(NSObject *)model;

@end
