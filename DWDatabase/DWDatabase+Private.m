//
//  DWDatabaseOperationRecord.m
//  DWDatabase
//
//  Created by Wicky on 2019/12/2.
//

#import "DWDatabase+Private.h"
#import "DWDatabase.h"
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
