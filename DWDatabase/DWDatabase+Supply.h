//
//  DWDatabase+Supply.h
//  DWDatabase
//
//  Created by Wicky on 2020/4/7.
//

#import "DWDatabase.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWDatabase (Supply)

-(DWDatabaseResult *)_entry_supplyFieldIfNeededWithClass:(Class)cls configuration:(DWDatabaseConfiguration *)conf;

-(DWDatabaseResult *)_entry_addFieldsToTableWithClass:(Class)cls keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf;

@end

NS_ASSUME_NONNULL_END
