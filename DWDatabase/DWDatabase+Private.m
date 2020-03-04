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
        } else {
            NSNumber * modelID = [DWDatabase fetchDw_idForModel:model];
            if (modelID) {
                NSNumber * objID = [DWDatabase fetchDw_idForModel:obj.model];
                if (objID && [objID isEqualToNumber:modelID]) {
                    result = obj;
                }
            }
        }
        if (result) {
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
