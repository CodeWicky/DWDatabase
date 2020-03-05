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
