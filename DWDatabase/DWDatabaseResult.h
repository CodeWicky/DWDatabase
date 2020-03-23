//
//  DWDatabaseResult.h
//  DWDatabase
//
//  Created by Wicky on 2019/11/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 数据库操作结果模型
 */
@interface DWDatabaseResult : NSObject

///操作是否成功
@property (nonatomic ,assign) BOOL success;

///操作成功的数据
///插入成功返回Dw_id，否则返回空；
///更新若依Dw_id更新则返回Dw_id，否则返回空；
///查询若查询成功，返回结果数组，否则返回空；
///查询个数成功，返回个数，否则返回空。
///批量插入，如果插入失败了，则返回失败模型数组。
@property (nonatomic ,strong ,nullable) id result;

///error
@property (nonatomic ,strong ,nullable) NSError * error;

+(DWDatabaseResult *)failResultWithError:(nullable NSError *)error;

+(DWDatabaseResult *)successResultWithResult:(nullable id)result;

@end

NS_ASSUME_NONNULL_END
