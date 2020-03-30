//
//  DWDatabase.h
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

/**
 DWDatabase
 
 基于MFDB的二次封装，自动将模型写入数据库
 支持数据类型，基础类型数据及部分Foundation对象，其中包括（NSString,NSMutableString,NSNumber,NSData,NSMutableData,NSDate,NSURL,NSArray,NSMutableArray,NSDictionary,NSMutableDictionary,NSSet,NSMutableSet）。
 其中NSNumber写入库中时由于无法在建表期确定其数值类型，故统一转换成浮点型
 
 version 1.0.0
 增删改查完成，回归测试完成
 添加类型容错，可实现部分类型间的容错转换（NSDate与NSString间的容错仅适用于格式为 yyyy-MM-dd HH:mm:ss.SSS 的数据）
 添加查询个数API及按ID查询API
 
 version 1.0.1
 添加默认排序条件为Dw_id
 数据库句柄中添加数据库文件路径
 
 version 1.0.2
 规范方法命名
 提供批量插入接口
 
 version 1.0.2.1
 修复批量插入时由于error已经释放引起的野指针问题
 
 version 1.0.2.2
 添加异步插入、查询接口
 规范方法命名
 对外暴露默认存储主路径
 添加操作队列，防止多线程下同时访问崩溃情况

 version 1.0.3
 添加当模型增加字段时，自动为表添加字段功能
 
 version 1.0.4
 修改query系列方法为conditionMaker模式，即通过Maker链式生成查询条件，扩展条件类型包括等于、大于、小于、大于等于、小于等于、取值集合、取值补集、模糊查询、取值范围等几种查询方式。
 修复sql缓存时未考虑表名的bug
 
 version 1.0.4.1
 修改部分警告
 修改condition宏使用方式（提供便捷宏及普通用法）
 
 version 1.0.4.2
 增加如果没有LoadClass使用Model class做备选的辅助功能
 
 version 1.0.4.3
 增加搜索条件时对Dw_id为搜索条件的支持
 
 version 1.0.4.4
 修复cacheBug
 
 version 1.0.4.5
 去除FMResultSet接口，改用Block接口，解除警告

 version 1.0.4.6
 增加不等于条件
 去除黑白名单需要遵守协议的限制
 增加模型转换方法，容器属性支持泛型，支持数组、字典、集合间互转容错
 当前模型转换支持基本属性转换，模型嵌套，容器属性容错转换，容器属性泛型转换（暂时不考虑CFArray的遍历方式，待日后实际测量效率后再做定度）
 
 version 1.0.4.7
 优化InValue及NotInValue逻辑，兼容数组0元素、1元素的条件转换
 
 version 1.0.4.8
 修复sel与char *为空时引起的崩溃
 修复update时无法将值更新为nil的bug
 
 version 1.0.4.9
 增加查询条件中的isNull及notNull
 
 模型嵌套入库几个点：通过为Oject类型且NSType为Unknown识别模型嵌套，通过一个钩子方法提供表明定制，钩子方法提供数据库路径（考虑是否需要维护多个数据库文件），db获取的数据库信息中应该维护内联表名(当前初步考虑不应该维护在库中，要考虑钩子方法中对应的表明改变的问题，应该从钩子方法中获取并维护在内存当中)，应从最内层的嵌套开始存储，直到失败或者最外层为止，失败后不回滚，只取消上级的存储，改造插入方法返回值，带出Dw_id（思考是否要将Dw_id暴露给外界），update方法考虑是否能直接以条件模式做更新
 此处修改组合条件外部括号冗余的问题，待验证
 条件模式已经更改完成，目前考虑模型嵌套问题。还要考虑是否要统一所有结果为result，还要考虑代码模块拆分，还要review一下所有代码，看改动是否完整
 目前插入时采取若嵌套model存在Dw_id直接插入模式，要考虑两个（1.model是否真正存在于表中。2.测试一下）
 模型嵌套时，即使嵌套模型存在Dw_id也应重新插入，而不是使用当前Dw_id，这样嵌套的记录就只属于当前模型。当前模型更新、删除都同时操作嵌套模型的记录。能保证数据统一

 */

#import <Foundation/Foundation.h>
#import "DWDatabaseConfiguration.h"
#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabaseResult.h"

/**
 模型数据表转换协议
 
 无论模型是否遵循协议均可实现自动落库，若遵循协议可通过协议方法自定义模型与数据表的对应关系。若实现白名单方法则仅将model中在白名单中的属性进行落库。若实现黑名单方法则仅将model中不在黑名单中的属性进行落库。若实现白名单方法将忽略黑名单方法。若实现‘键-字段’转化方法将会将模型的对应属性名与数据表中指定的字段名建立对应关系
 */

///获取默认存储主路径
OBJC_EXTERN  NSString * _Nonnull defaultSavePath(void);

NS_ASSUME_NONNULL_BEGIN
@protocol DWDatabaseSaveProtocol

@optional
///模型属性白名单
+(nullable NSArray *)dw_dataBaseWhiteList;

///模型属性黑名单
+(nullable NSArray *)dw_dataBaseBlackList;

///模型属性名与数据表字段名转化对应关系，字典中key为模型属性名，value为数据表中字段名
+(nullable NSDictionary *)dw_modelKeyToDataBaseMap;

///模型嵌套对应的表名
+(nullable NSDictionary *)dw_inlineModelTableNameMap;

@end

@interface DWDatabase : NSObject

///当前所有可用数据库信息
@property (nonatomic ,strong ,readonly) NSDictionary * allDBs;

#pragma mark --- 实例化方法 ---
+(instancetype)shareDB;
-(instancetype)init NS_UNAVAILABLE;

#pragma mark --- 初始化配置方法 ---

/**
 初始化数据库

 @return 返回是否初始化成功
 
 @disc 数据库使用前，请确保调用过此方法，建议在AppDelegate中调用
 */
-(DWDatabaseResult *)initializeDB;


#pragma mark --- 组合快捷方法 ---
/**
 快速获取表名数据库句柄
 
 @param cls 指定类
 @param name 映射的name
 @param tblName 指定的表名
 @param path 指定保存数据库的路径
 @return 返回表名数据库句柄
 
 @disc 行为包括:
 1. -initializeDBWithError:
 2. -configDBIfNeededWithName:path:error:
 3. -createTableWithClass:tableName:configuration:error:
 4. -fetchDBConfigurationWithName:tableName:error:
 
 本方法做了表操作之前的所有准备操作，表操作之前直接调用即可获取表名数据库句柄
 如果操作成功，返回结果中result字段将携带表名数据库句柄
 */
-(DWDatabaseResult *)fetchDBConfigurationAutomaticallyWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path;


/**
 自动按需为指定类在指定路径创建数据库并建表
 
 @param cls 指定类
 @param name 映射的name
 @param tblName 指定的表名
 @param path 指定保存数据库的路径
 @return 返回创建是否成功
 
 @disc 若本地已存在库或表则认为无需创建，返回成功
 行为包括：
 1. -configDBIfNeededWithName:path:error:
 2. -createTableWithClass:tableName:configuration:error:
 */
-(DWDatabaseResult *)configDBIfNeededWithClass:(Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path;

#pragma mark --- 组合表操作方法 ---
/**
 本方法在做了表操作之前所有操作之后，进行了增删改查操作。
 虽然本系列方法可以无需考虑任何操作直接做数据表操作，但是会进行很多判断。
 适用于开发者不确定当前数据库状态的情况下调用，若开发者确定数据库状态应直接调用相关方法，避免做过多无用的判断。
 
 方法各参数释义与其他方法相同，不做重复介绍。
 行为包括:
 1. -fetchDBConfigurationAutomaticallyWithClass:name:tableName:path:error:
 2. 增删改查对应相关方法
 */
-(nonnull DWDatabaseResult *)insertTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path keys:(nullable NSArray <NSString *>*)keys;
-(nonnull DWDatabaseResult *)deleteTableAutomaticallyWithModel:(nullable NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition;
-(DWDatabaseResult *)updateTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path keys:(nullable NSArray <NSString *>*)keys;
-(DWDatabaseResult *)queryTableAutomaticallyWithClass:(Class)clazz name:(NSString *)name tableName:(nullable NSString *)tblName path:(NSString *)path keys:(nullable NSArray *)keys condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition;

#pragma mark --- 数据库操作方法 ---
/**
 通过本地与数据库实例一一映射的name来管理数据库，当前库为空时所有操作将无效，此处均为对数据库的操作，故均应传入库名数据库句柄
 */


/**
 创建一个数据库并与本地name进行映射

 @param name 映射的name
 @param path 指定保存数据库的路径
 @return 返回是否创建成功
 
 @disc 1.用于创建数据库，若本地已存在对应的数据库映射将创建失败。
       2.当所传path为空时将 /Library/DWDatabase 下创建随机文件名的数据库文件
       3.调用后会自动将数据库配置为当前使用库
 */
-(DWDatabaseResult *)configDBIfNeededWithName:(NSString *)name path:(nullable NSString *)path;


/**
 根据映射name删除本地数据库

 @param name 映射的name
 @return 返回是否删除成功
 
 @disc 若删除的库为当前使用的库，当前库将被置空
 */
-(DWDatabaseResult *)deleteDBWithName:(NSString *)name;


/**
 库名数据库句柄操作方法
 
 @param name 映射的name
 @return 返回库名数据库句柄
 
 @disc 库名数据库句柄相较表名数据库句柄缺少表名信息，故使用库名数据库句柄的地方均可用表明数据库句柄代替（表名不做校验，无影响）
      若操作成功，result字段将携带库名数据库句柄。
 */
-(DWDatabaseResult *)fetchDBConfigurationWithName:(NSString *)name;


/**
 查询当前库中是否包含指定表
 
 @param tblName 指定表名
 @param conf 数据库句柄
 @return 返回是否存在
 
 @disc 此处应传库名数据库句柄
 */

-(DWDatabaseResult *)isTableExistWithTableName:(NSString *)tblName configuration:(DWDatabaseConfiguration *)conf;


/**
 获取当前库中包含的所有表名
 
 @param conf 数据库句柄
 @return 返回当前库中所有表名
 
 @disc 此处应传库名数据库句柄，若操作成功，result字段将携带所有包含所有表名的数组
 */
-(DWDatabaseResult *)queryAllTableNamesInDBWithConfiguration:(DWDatabaseConfiguration *)conf;


/**
 根据类和指定表名在当前库中创建表
 
 @param cls 指定类
 @param tblName 指定表名
 @param conf 数据库句柄
 @return 返回是否创建成功
 
 @disc 此处应传入库名数据库句柄
 */
-(DWDatabaseResult *)createTableWithClass:(Class)cls tableName:(NSString *)tblName configuration:(DWDatabaseConfiguration *)conf;
-(DWDatabaseResult *)createTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf;

#pragma mark --- 表操作方法 ---
/**
 此处均为对数据表的操作，故均应传入表名数据库句柄
 */


/**
 表名数据库句柄获取方法
 
 @param name 映射的name
 @param tblName 指定表名
 @return 返回表名数据库句柄
 
 @disc 库名数据库句柄相较表名数据库句柄缺少表名信息，故使用表名数据库句柄的地方均不可用表明数据库句柄代替（表名做校验，存在影响）
      若操作成功，result字段将携带表名数据库句柄。
 */
-(DWDatabaseResult *)fetchDBConfigurationWithName:(NSString *)name tabelName:(NSString *)tblName;


/**
 根据sql语句操作数据表
 
 @disc 此处应传表名数据库句柄
 */
-(DWDatabaseResult *)updateTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf;
-(DWDatabaseResult *)updateTableWithSQLs:(NSArray <NSString *>*)sqls rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf;
-(void)queryTableWithSQL:(NSString *)sql configuration:(DWDatabaseConfiguration *)conf completion:(nullable void(^)(FMResultSet * _Nullable set, NSError * _Nullable error))completion;

/**
 获取指定表所有字段

 @param translateToPropertyName 是否转换成对应类的属性名
 @param cls 转换模型的类
 @param conf 数据库句柄
 @return 所有字段名
 
 @disc 1.此处应传表名数据库句柄
      2.若数据表名不能一一映射到模型中将给出错误信息
      3.若操作成功，result字段将携带z包含所有字段名的数组
 */
-(DWDatabaseResult *)queryAllFieldInTable:(BOOL)translateToPropertyName class:(nullable Class)cls configuration:(DWDatabaseConfiguration *)conf;


/**
 清空当前库指定表

 @param conf 数据库句柄
 @return 返回是否清空成功
 
 @disc 此处应传表名数据库句柄
 */
-(DWDatabaseResult *)clearTableWithConfiguration:(DWDatabaseConfiguration *)conf;


/**
 删除当前库指定表
 
 @param conf 数据库句柄
 @return 返回是否删除成功
 
 @disc 此处应传表名数据库句柄
 */
-(DWDatabaseResult *)dropTableWithConfiguration:(DWDatabaseConfiguration *)conf;


#pragma mark ------ 根据模型操作表 ------
/**
 以下方法均为以模型或者类名操作的方法，其中模型可以为普通NSObject的子类作为模型，在此基础上还可以遵循DWDatabaseSaveProtocol，当遵循协议后将可以自定义模型与数据表的对应关系。同时部分操作强依赖于Dw_id，Dw_id是一个开发者不可见的属性，由框架进行赋值，当model执行insert后或者通过query查询出的结果中的模型会默认存在Dw_id字段。所有使用到的键值均应为model对应的属性名，框架内部会自动转换为对应的表中字段名。
 */


/**
 向当前库指定表中插入指定模型的指定属性的数据信息

 @param model 指定模型
 @param keys 指定属性数组
 @param recursive 是否递归插入
 @param conf 数据库句柄
 @return 返回是否插入成功
 
 @disc 1.此处传入表名数据库句柄
      2.若传入keys为空或者nil时则以全部对应落库属性作为插入数据
      3.当模型的属性中存在另一个模型时，可通过recursive指定是否递归插入。如果为真，将自动插入嵌套模型
      4.若插入成功，返回结果中result将携带当前模型的唯一id
 */
-(DWDatabaseResult *)insertTableWithModel:(NSObject *)model keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf;


/**
 批量插入模型

 @param models 模型数组
 @param keys 指定属性数组
 @param recursive 是否递归插入
 @param rollback 插入失败时是否回滚
 @param conf 数据库句柄
 @return 插入失败的模型
 
 @disc 1.此处传入表名数据库句柄
       2.若传入keys为空或者nil时则以全部对应落库属性作为插入数据
       3.当模型的属性中存在另一个模型时，可通过recursive指定是否递归插入。如果为真，将自动插入嵌套模型
       4.一旦出现错误立即停止操作，不再进行后续插入操作
       5.若操作失败，result字段将携带插入失败的模型
 */
-(DWDatabaseResult *)insertTableWithModels:(NSArray <NSObject *>*)models keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf;
-(void)insertTableWithModels:(NSArray <NSObject *>*)models keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf completion:(void(^)(NSArray <NSObject *>*failureModels,NSError * error))completion;

/**
 删除当前库指定表中对应的模型信息

 @param conf 数据库句柄
 @param condition 删除模型的条件
 @return 返回是否删除成功
 
 @disc 1.此处传入表明数据库句柄
 */
-(DWDatabaseResult *)deleteTableWithConfiguration:(DWDatabaseConfiguration *)conf condition:(void(^)(DWDatabaseConditionMaker * maker))condition;

/**
 删除当前库指定表中对应的模型信息

 @param model 待删除的模型
 @param recursive 是否递归删除
 @param conf 数据库句柄
 @return 返回是否删除成功

@disc 1.此处传入表明数据库句柄
     2.此处根据model自身的唯一ID删除。若其不存在ID将删除失败。即model为通过框架查询得来的才可以进行删除
     3.当模型的属性中存在另一个模型时，可通过recursive指定是否递归删除。如果为真，将自动删除嵌套模型
     4.自动删除嵌套模型时，将根据嵌套模型是否存在Dw_id决定是否将其删除。若嵌套的模型不包含Dw_id，将跳过此嵌套模型的删除操作
*/
-(DWDatabaseResult *)deleteTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf;


/**
 更新当前库指定表中对应的模型指定属性的数据信息

 @param model 指定模型
 @param keys 指定属性数组
 @param recursive 是否递归更新
 @param conf 数据库句柄
 @param condition 更新模型的条件
 @return 返回是否更新成功
 
 @disc 1.此处传入表名数据库句柄
       2.仅更新keys中指定的字段
       3.当模型的属性中存在另一个模型时，可通过recursive指定是否递归更新。如果为真，将自动更新嵌套模型
       4.自动更新模型时，若嵌套模型存在Dw_id，则将直接更新对应表中数据，如果嵌套模型中不存在数据，则将自动插入至指定表中
       5.如果condition存在，将按照条件进行更新
       6.若果condition不存在，将按照模型的唯一ID进行更新
       7.当model中不存在Dw_id时，将向当前表中插入model的数据信息
       8.若传入keys为空或者nil时则以全部对应落库属性作为更新数据
 */

-(DWDatabaseResult *)updateTableWithModel:(NSObject *)model keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition;


/**
 根据指定条件在当前库指定表中查询指定条数数据

 @param clazz 作为数据承载的模型类
 @param keys 想要查询的键值
 @param limit 查询的最大条数
 @param offset 查询的起始点
 @param orderKey 指定的排序的key
 @param ascending 是否正序
 @param recursive 是否递归查询
 @param conf 数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回查询结果
 
 @disc 1.此处传入表名数据库句柄
       2.keys中均应该是model的属性的字段名，框架内部将根据 +dw_modelKeyToDataBaseMap  自动将其转化为对应表中相应的字段名，若model未实现 +dw_modelKeyToDataBaseMap 协议方法则字段名不做转化
       3.将从数据表中查询keys中指定的字段的数据信息，当其为nil时将把根据 +dw_dataBaseWhiteList 和 +dw_dataBaseBlackList 计算出的所有落库字段的数据信息均查询出来
       4.当limit为大于0的数是将作为查询条数上限，为0时查询条数无上限
       5.当offset为大于0的数是将作为查询的起始点，即从第几条开始查询数据
       6.当orderKey存在且合法时将会以orderKey作为排序条件，ascending作为是否升序或者降序，若不合法，则以默认id为排序条件
       7.orderKey应为模型属性名，框架将自动转换为数据表对应的字段名
       8.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型
       9.condition为构造查询条件的构造器，condition与clazz不能同时为空
       10.返回的数组中将以传入的clazz的实例作为数据载体
       11.若操作成功，result字段中将携带结果数组
 */

-(DWDatabaseResult *)queryTableWithClass:(nullable Class)clazz keys:(nullable NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition;
-(void)queryTableWithClass:(nullable Class)clazz keys:(nullable NSArray <NSString *>*)keys limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition completion:(nullable void(^)(NSArray <__kindof NSObject *>* results,NSError * error))completion;

/**
 根据sql语句在指定表查询数据并将数据赋值到指定模型

 @param sql 指定sql
 @param cls 承载数据的模型的类
 @param recursive 是否递归查询
 @param conf 数据库句柄
 @return 返回查询结果
 
 @disc 1.此处传入表名数据库句柄，如果操作成功，result字段将携带结果数组
      2.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型
 */
-(DWDatabaseResult *)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf;
-(void)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf completion:(nullable void(^)(NSArray <__kindof NSObject *>* results,NSError * error))completion;


/**
 根据指定条件在当前库指定表中查询数据

 @param cls 作为数据承载的模型类
 @param keys 想要查询的键值
 @param recursive 是否递归查询
 @param conf 数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回查询结果
 
 @disc 1.此处传入表名数据库句柄
       2.keys中均应该是model的属性的字段名，框架内部将根据 +dw_modelKeyToDataBaseMap  自动将其转化为对应表中相应的字段名，若model未实现 +dw_modelKeyToDataBaseMap 协议方法则字段名不做转化
       3.将从数据表中查询keys中指定的字段的数据信息，当其为nil时将把根据 +dw_dataBaseWhiteList 和 +dw_dataBaseBlackList 计算出的所有落库字段的数据信息均查询出来
       4.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型
       5.返回的数组中将以传入的cls的实例作为数据载体
       6.若操作成功，result字段将携带结果数组
 */
-(DWDatabaseResult *)queryTableWithClass:(nullable Class)cls keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable void (^)(DWDatabaseConditionMaker * maker))condition;


/**
 查询表中符合条件的数据条数，仅查询个数时请调用此API，会避免很多赋值计算

 @param cls 作为数据承载的模型类
 @param conf 数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回是否查询成功
 
 @disc 1.此处传入表名数据库句柄
       2.model将作为数据承载的载体
       3.conditionKeys应该是model的属性的字段名，框架内部将根据 +dw_modelKeyToDataBaseMap  自动将其转化为对应表中相应的字段名，若model未实现 +dw_modelKeyToDataBaseMap 协议方法则字段名不做转化
       4.将根据conditionKeys从model中取出对应数值作为查询条件，当其为nil时将返回整个数据表中指定字段的信息
       5.若查询成功，result字段将携带个数（NSNumber）
 */
-(DWDatabaseResult *)queryTableForCountWithClass:(nullable Class)cls configuration:(DWDatabaseConfiguration *)conf condition:(nullable void(^)(DWDatabaseConditionMaker * maker))condition;


/**
 按指定Dw_id查询指定信息

 @param cls 承载数据的模型类
 @param Dw_id 指定ID
 @param keys 查询的键值
 @param recursive 是否递归查询
 @param conf 数据库句柄
 @return 返回对应数据的模型
 
 @disc 1.此处应传入表名数据库，此方法更适用于在确定某条数据的ID后要对此条数据进行追踪的情景，避免了每次查询并筛选的过程（如通过年龄查询出一批人后选中其中一个人，以后要针对这个人做操作，即可在本次记下ID后以后通过ID查询）,若操作成功，result字段将携带指定模型
     2.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型
 */
-(DWDatabaseResult *)queryTableWithClass:(Class)cls Dw_id:(NSNumber *)Dw_id keys:(nullable NSArray <NSString *>*)keys recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf;


#pragma mark ------ 其他 ------
/**
 获取模型的Dw_id，与表中id一一对应。

 @param model 指定模型
 @return 对应ID
 
 @disc 1.只有由框架查询得到的或者是插入到表中成功的model才会存在Dw_id
       2.具有Dw_id的模型从表中删除后会移除模型的Dw_id
 */
+(NSNumber *)fetchDw_idForModel:(NSObject *)model;

/**
获取模型所在的数据库名称。

@param model 指定模型
@return 对应数据库名称

@disc 1.只有由框架查询得到的或者是插入到表中成功的model才会存在数据库名称
      2.具有数据库名称的模型从表中删除后会移除模型的数据库名称
*/
+(NSString *)fetchDbNameForModel:(NSObject *)model;

/**
获取模型所在的数据表名称。

@param model 指定模型
@return 对应数据表名称

@disc 1.只有由框架查询得到的或者是插入到表中成功的model才会存在数据表名称
      2.具有数据表名称的模型从表中删除后会移除模型的数据表名称
*/
+(NSString *)fetchTblNameForModel:(NSObject *)model;




///模型存数据库需要保存的键值
-(NSArray *)propertysToSaveWithClass:(Class)cls;

///获取类指定键值的propertyInfo
-(NSDictionary *)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys;
@end
NS_ASSUME_NONNULL_END
