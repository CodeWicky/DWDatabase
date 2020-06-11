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
 模型嵌套支持完成
 增加数据库升级方法支持
 增加数据表字段补齐方法
 自加创建表默认值映射协议方法
 
 version 1.1.0
 完善嵌套模式的增删改查
 去除通过数组绑定操作Key的复杂接口，改为通过Maker绑定操作Key
 操作Key对二级属性的支持，同时添加单独属性指定递归性的接口
 修复条件查询模式传入空查询值导致后续条件错误的bug
 修复批量查询造成的死锁问题
 修复组合条件外部括号冗余的问题
 
 version 1.1.1.1
 添加bindKeys接口
 
 version 1.1.1.2
 修复inValues、notInValues遇到单值转化时的类型错误问题

 */

#import <Foundation/Foundation.h>
#import "DWDatabaseConfiguration.h"
#import "DWDatabaseConditionMaker.h"
#import "DWDatabaseMacro.h"
#import "DWDatabaseResult.h"
#import <DWKit/NSObject+DWObjectUtils.h>

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

///模型建表及自动补充字段时，字段的默认值。字典中key为模型属性名，value为属性建表默认值。
+(nullable NSDictionary *)dw_databaseFieldDefaultValueMap;

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

 @return 返回是否初始化成功结果
 
 @disc 数据库使用前，请确保调用过此方法，建议在AppDelegate中调用
 1.result中将携带成功结果，若不成功，error将携带错误信息
 */
-(DWDatabaseResult *)initializeDB;


#pragma mark --- 组合快捷方法 ---
/**
 快速获取表名数据库句柄
 
 @param cls 指定类
 @param name 映射的name
 @param tblName 指定的表名
 @param path 指定保存数据库的路径
 @return 返回包含表名数据库句柄的结果
 
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
 @return 返回创建是否成功的结果
 
 @disc 若本地已存在库或表则认为无需创建，返回成功。若创建失败，result中将携带错误信息
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
 
 @disc 方法各参数释义与其他方法相同，不做重复介绍。
 行为包括:
 1. -fetchDBConfigurationAutomaticallyWithClass:name:tableName:path:error:
 2. 增删改查对应相关方法
 3.result将携带操作结果，若成功，将携带各自的操作信息，若失败，将携带错误信息
 
 @eg. :
 V * model = [V new];
 model.intNum = -100;
 model.floatNum = 3.14;
 model.string = @"123";
 DWDatabaseResult * result = [[DWDatabase shareDB] insertTableAutomaticallyWithModel:model name:@"Auto" tableName:@"Auto_V_Tbl" path:dbPath condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
     maker.dw_loadClass(V);
     maker.dw_bindKey(intNum).dw_bindKey(floatNum);
 }];
 
 上述例子中，将自动初始化数据库并按需创建对应数据表，并在数据表中intNum和floatNum对应的字段名下插入数据。
 */
-(DWDatabaseResult *)insertTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path condition:(nullable DWDatabaseConditionHandler)condition;
-(DWDatabaseResult *)deleteTableAutomaticallyWithModel:(nullable NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path condition:(nullable DWDatabaseConditionHandler)condition;
-(DWDatabaseResult *)updateTableAutomaticallyWithModel:(NSObject *)model name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path condition:(nullable DWDatabaseConditionHandler)condition;
-(DWDatabaseResult *)queryTableAutomaticallyWithClass:(nullable Class)cls name:(NSString *)name tableName:(NSString *)tblName path:(nullable NSString *)path condition:(nullable DWDatabaseConditionHandler)condition;

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
 
 */
-(DWDatabaseResult *)configDBIfNeededWithName:(NSString *)name path:(nullable NSString *)path;


/**
 根据映射name删除本地数据库

 @param name 映射的name
 @return 返回是否删除成功
 
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
      3.若操作成功，result字段将携带包含所有字段名的数组
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
 1.下述方法均为对数据表的操作，顾此处应传入的均为表名数据库句柄。
 2.以下方法均为以模型或者类名操作的方法，其中模型可以为普通NSObject的子类作为模型。模型将作为操作数据库时数据的载体。
 3.在此基础上还可以遵循DWDatabaseSaveProtocol，来指定模型入库后的部分行为。
 4.框架内部为每个通过框架操作而来的模型维护了三个属性，分别是Dw_id，DbName和TblName。其中当插入和查询时，框架将维护Dw_id给所操作的模型，其对应的是数据在数据表中的Dw_id字段。插入、更新及查询操作时，框架内部会将模型所属的DbName及TblName维护至模型中，此外插入及查询操作，框架内部还会维护模型在数据表中的Dw_id至模型中。
 5.当需要为操作绑定操作的key时，传入的均应为model对应的属性名，框架内部将自动转换为数据表中对应的字段名。
 6.所有操作均支持递归操作。嵌套操作是指，模型实例model类为A，类A包含一个对象属性prop，其类为B。嵌套操作即是当执行对模型model的操作时，是否自动为模型prop执行相同操作。执行递归操作时，框架内部将自动为嵌套的模型定制表名。
 */


/**
 向当前库指定表中插入指定模型的指定属性的数据信息

 @param model 指定模型
 @param recursive 是否递归插入
 @param conf 表名数据库句柄
 @param condition 插入绑定key构造条件
 @return 返回是否插入成功
 
 @disc 1.model将作为插入数据的载体。框架内部将根据绑定的操作Key从model中取值后，插入至数据表中。 2.recursive将指定是否递归插入。例如存在嵌套结构A-B，若recursive为YES，则将自动为嵌套属性B创建数据表并插入，然后将B在数据表中的Dw_id插入至模型A对应的数据表中的prop对应的字段下。
      3.condition中可以通过bindKey语句进行操作Key的绑定，只有绑定的Key才会被插入至数据表中。如果condition中并为绑定Key，框架将插入默认的全部入库的key。
      4.当recursive为NO时，模型遇到嵌套模型时，将直接跳过此属性。
      5.当recursive为YES时，仍可通过bindKey语句后执行recursive语句来指定当前bindKey会话中所绑定的key的递归性。若不指定，将默认为YES。若recursive语句指定为NO时，会判断当前嵌套模型是否存在Dw_id，若存在，则将此嵌套模型的Dw_id插入至表中，并且不更新嵌套模型数据。若不存在Dw_id，则该嵌套模型对应的字段将不插入数据。
      6.插入操作中，condition中的conditionWith语句将被忽略。
      7.若插入成功，返回结果中result将携带当前模型的唯一id
 
 @eg. :
 C * cModel = [C new];
 cModel.dic = @{@"key":@"value"};
 cModel.classC = cModel;
 cModel.aNum = 12;
 cModel.array = @[@"1",@"2"];
 
 B * bModel = [B new];
 bModel.b = 100;
 cModel.classB = bModel;
 bModel.str = @"aaaa";
 
 A * aModel = [A new];
 aModel.a = @[@1,@2];
 aModel.classC = cModel;
 bModel.classA = aModel;
 aModel.num = 300;
 
 DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
 
 result = [self.db insertTableWithModel:cModel recursive:YES configuration:result.result condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
     maker.dw_loadClass(C);
     maker.dw_bindKey(dic).dw_bindKey(classB.b).dw_bindKey(classB.classA.a).dw_bindKey(classB.classA.classC.aNum).commit();
     maker.dw_bindKey(classC).recursively(NO);
 }];
 
 上述代码中，绑定的Key包含【dic,classB.b,classB.classA.a,classB.classA.classC.aNum】及【classC】两个绑定Key会话。其中第一个会话没有指定recursive语句，默认均为递归模式，第二个会话指定为非递归模式。
 
 插入cModel时，除了插入普通属性dic，还将插入嵌套属性classB，即插入bModel，bModel插入完成时，将在classB字段中插入bModel在数据表中对应的Dw_id。此外还有嵌套属性classC，本例中即为cModel本身，由于cModel在插入完成前并不存在Dw_id，且其此时指定为非递归模式，故此处将不插入classC字段。若本例中classC对应模型存在Dw_id，则此处将在classC字段中插入模型的Dw_id。
 插入bModel时，将插入b属性，及嵌套属性classA，本例中即aModel。同时aModel插入完成时，将在bModel对应的数据表中的classA字段中插入aModel的Dw_id。
 同理，插入aModel时，将插入a属性及classC属性。具体逻辑同插入bModel。不过本例中aModel的classC指向的即为cModel，故由classB.classA.classC.aNum带来的会将cModel的aNum同时入库。
 
 综上，
 cModel最终落库属性：【dic,classB,aNum】
 bModel最终落库属性：【b,classA】
 aModel最终落库属性：【a,classC】
 */
-(DWDatabaseResult *)insertTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


/**
 批量插入模型

 @param models 模型数组
 @param recursive 是否递归插入
 @param rollback 插入失败时是否回滚
 @param conf 表名数据库句柄
 @param condition 插入绑定key构造条件
 @return 插入失败的模型
 
 @disc 1.此处插入基本规则同单个模型插入规则相同，只是加入了批量插入及失败回滚接口。
      2.插入分为两个阶段，第一个阶段为校验所有待插入模型的合法性，第二个阶段为插入所有模型。两个阶段当产生错误，且rollback为YES时，均会立即停止，不再进行后续插入操作
      3.若第一阶段产生错误，且rollback为YES时，将停止批量插入操作，且result中将携带第一个产生错误的模型后的所有模型及错误信息。
      4.若第二阶段产生错误，且rollback为YES时，将停止当前所有操作，并回滚数据库，result中将携带第一个产生错误的模型后的所有模型及错误信息。
      5.当rollback不为YES时，即使操作失败也不影响当前操作，只是将手机当前报错的模型，result字段将携带插入失败的模型。批量插入只有到当全部插入成功时才会被认为插入成功。
 */
-(DWDatabaseResult *)insertTableWithModels:(NSArray <NSObject *>*)models recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;
-(void)insertTableWithModels:(NSArray <NSObject *>*)models recursive:(BOOL)recursive rollbackOnFailure:(BOOL)rollback configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition completion:(void(^)(DWDatabaseResult * result))completion;


/**
 根据模型或指定条件删除数据表中的数据
 
 @param model 将要删除的模型
 @param recursive 是否递归删除
 @param conf 表名数据库句柄
 @param condition 删除数据的条件
 @return 返回是否插入成功
 
 @disc 1.若传入非空model，且model中存在Dw_id，则将根据Dw_id进行数据表删除，否则将根据condition删除数据表中的数据，model的Dw_id及condition不可以同时为空，否则将删除失败。当且仅当按Dw_id删除时递归模式才有效。条件模式由于无法获取嵌套信息故无法使用递归模式。
 2.recursive将决定是否可以递归删除。当recursive为YES时，将自动删除嵌套模型对应Dw_id的数据。当recursive为NO时，嵌套属性将不做特殊处理。
 3.当且仅当传入非空模型且其Dw_id不为空时，才能确定嵌套模型相关信息，故只有此情形下递归模式生效，condition模式删除时，不支持递归模式。
 4.自动删除嵌套模型时，将根据嵌套模型是否存在Dw_id决定是否将其删除。若嵌套的模型不包含Dw_id，将跳过此嵌套模型的删除操作
 5.当recursive为YES时，仍可通过condition中的bindKey语句及recursive语句来指定个别属性为非递归模式。
 
 @eg. :
 DWDatabaseResult * result = [self.db deleteTableWithModel:cModel recursive:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
     maker.dw_loadClass(C);
     maker.dw_bindKey(classB.classA).recursively(NO);
 }];
 
 此处假设cModel是从数据库中查询出的数据，及cModel及其各个嵌套模型中，均存在Dw_id。
 删除cModel时，将删除cModel本身，同时遍历cModel所有属性，找寻其中的对象属性，本例中即【classB,classC】。由于bindKey会话中名优显示指定classB及classC为NO，故classB及classC均会递归删除。
 删除classB对应的模型(此处称其为bModel)时，先删除bModel在表中的数据，然后找寻其中的对象属性，本例中即【classA】，由于显示指定了classB.classA为NO，故不再递归删除classA对应的数据。
 删除classC对应的模型(此处称其为cModelRecursive)时，首先删除cModelRecursive在表中的数据，然后找寻其中的对象属性，并递归的删除下去。
 那么本例中，将会删除的数据包括【cModel，bModel，cModelRecursive及其递归模型数据】
 */
-(DWDatabaseResult *)deleteTableWithModel:(nullable NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


/**
 更新当前库指定表中对应的模型指定属性的数据信息

 @param model 指定模型
 @param recursive 是否递归更新
 @param conf 表名数据库句柄
 @param condition 更新模型的条件
 @return 返回是否更新成功
 
 @disc 1.传入的模型为数据载体，插入或更新的字段将从模型对应属性取值。传入的模型不可以为空。
      2.当传入的模型不存在Dw_id且condition中不包含conditionWith语句时，将降级为插入模型逻辑，否则将采用更新逻辑。
      3.当采用更新逻辑时，若condition中不包含conditionWith语句时，将采取以Dw_id进行更新，否则将采取条件更新模式
      4.条件模式更新下，由于无法获取嵌套信息，所以条件模式更新下，不支持递归更新操作。以Dw_id更新支持递归更新操作。
      5.当模型的属性中存在另一个模型时，可通过recursive指定是否递归更新。如果为真，将自动更新嵌套模型
      6.自动更新模型时，若嵌套模型存在Dw_id，则将直接更新对应表中数据，如果嵌套模型中不存在数据，则将自动插入至指定表中
      7.condition中可通过bindKey语句来绑定要更新的key，还可通过recursive语句来决定当前绑定会话是否支持递归更新操作。
 
 @eg. :
 DWDatabaseResult * result = [self.db updateTableWithModel:cModel recursive:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
     maker.dw_loadClass(C);
     maker.dw_bindKey(classC).recursively(NO).commit();
     maker.dw_bindKey(classB.classA.classC);
 }];
 
 此处假设cModel是从数据库中查询出的数据，及cModel及其各个嵌套模型中，均存在Dw_id。
 更新cModel时，根据bindKey语句确定，cModel需要更新字段为【classB,classC】
 更新classB(此处称其为bModel)时，由于指定了更新classA(此处称其为aModel)字段，故将更新bModel的classA属性。进而更新aModel时，又将更新classC(此处称其为cModelRecursive)属性。更新cModelRecursive时，由于没有指定操作的key，将更新cModelRecursive的全部落库属性。过程中由于是递归模式，若模型存在Dw_id将采用更新逻辑，若不存在，将降级为插入逻辑。
 更新classC(此处称其为cModelRecursive2)时，由于指定了非递归模式，故若cModelRecursive2不包含Dw_id，则将跳过此次更新操作，若包含，将更新classC字段为该Dw_id。
 */

-(DWDatabaseResult *)updateTableWithModel:(NSObject *)model recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


typedef void(^DWDatabaseReprocessingHandler)(__kindof NSObject * model,FMResultSet * set);
/**
 根据指定条件在当前库指定表中查询指定条数数据

 @param cls 作为数据承载的模型类
 @param limit 查询的最大条数
 @param offset 查询的起始点
 @param orderKey 指定的排序的key
 @param ascending 是否正序
 @param recursive 是否递归查询
 @param reprocessing 每当查询完结果组建成功一个模型后，对每个模型提供二次处理的操作回调
 @param conf 表名数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回查询结果
 
 @disc 1.cls将作为数据表中映射模型实例的类。框架内部将优先获取condition中loadClass语句装载的class，如果为空将获取cls，作为数据载体。condition中loadClass与cls不能同时为空。
      2.当limit为大于0的数是将作为查询条数上限，为0时查询条数无上限
      3.当offset为大于0的数是将作为查询的起始点，例如offset为10，当查询结果有20条符合条件的数据，将返回第10至第20条数据。
      4.当orderKey存在且合法时将会以orderKey作为排序条件，ascending作为是否升序或者降序，若不合法，则以默认id为排序条件。其中orderKey应为模型属性名
      5.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型，否则遇到嵌套模型将之赋值其边表中对应的Dw_id。
       6.当recursive为NO时，reprocessing回调有效。当执行完查询操作后，根据查询结果组装模型时，每当一个有效结果组装完成时，将回调reprocessing方法，并将组装完成的模型及fmdb查询结果set抛回，开发者可在此处对模型做二次处理。二次操作只影响查询结果，不影响数据库中数据。
       7.condition为构造查询条件的构造器，condition与clazz不能同时为空。condition中的conditionWith语句将为查询添加查询条件，查询条件支持副属性作为查询条件，具体见如下示例代码。
       8.condition中支持副属性作为条件查询，具体见如下示例代码
       9.condition中可以通过bindKey语句绑定查询字段，若不指定则默认查询所有入库字段。同时也可通过recursive语句指定当前绑定key会话是否支持递归查询。若不显示调用recursive语句，默认为支持嵌套查询
       10.返回的数组中将以传入的clazz的实例作为数据载体
       11.若操作成功，result字段中将携带结果数组
 
 @eg. :
 DWDatabaseResult *  result = [self.db queryTableWithClass:NULL recursive:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
     maker.dw_loadClass(C);
     maker.dw_conditionWith(aNum).equalTo(12).or.dw_conditionWith(classB.b).equalTo(100);
     maker.dw_bindKey(classB).commit();
     maker.dw_bindKey(classC.a);
 }];
 
 本例中，将查询所有符合如下条件的模型C，其中【该实例的aNum字段为12】或者【其嵌套的classB模型对应的b字段为100】。
 其绑定的查询键值包括【模型C的嵌套属性classB的全部属性及其递归属性,模型C的嵌套属性classC中的a属性】
 */
-(DWDatabaseResult *)queryTableWithClass:(nullable Class)cls limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition reprocessing:(nullable DWDatabaseReprocessingHandler)reprocessing;
-(void)queryTableWithClass:(nullable Class)cls limit:(NSUInteger)limit offset:(NSUInteger)offset orderKey:(nullable NSString *)orderKey ascending:(BOOL)ascending recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition reprocessing:(nullable DWDatabaseReprocessingHandler)reprocessing completion:(nullable void(^)(DWDatabaseResult * result))completion;

/**
 根据sql语句在指定表查询数据并将数据赋值到指定模型

 @param sql 指定sql
 @param cls 承载数据的模型的类
 @param recursive 是否递归查询
 @param conf 表名数据库句柄
 @return 返回查询结果
 
 @disc 1.当模型的属性中存在另一个模型时，可通过recursive指定是否递归查询。如果为真，将自动查询嵌套模型
      2.如果操作成功，result字段将携带结果数组
 */
-(DWDatabaseResult *)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf;
-(void)queryTableWithSQL:(NSString *)sql class:(Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf completion:(nullable void(^)(NSArray <__kindof NSObject *>* results,NSError * error))completion;


/**
 根据指定条件在当前库指定表中查询数据

 @param cls 作为数据承载的模型类
 @param recursive 是否递归查询
 @param conf 表名数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回查询结果
 
 @disc 1.此处具体查询基本规则同上，只是个别参数传入默认值。
      2.limit:0 offset:0 orderKey:nil ascending:YES 其中limit传入0(表示不设查询上限)，offset传入0(表示从第一条符合结果的数据开始返回)，orderKey传入nil(表示以Dw_id作为排序条件)，ascending传入YES(表示按升序返回数据)，reprocessing传入nil(表示不需要二次处理)。
 */
-(DWDatabaseResult *)queryTableWithClass:(nullable Class)cls recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


/**
 查询表中符合条件的数据条数，仅查询个数时请调用此API，会避免很多赋值计算

 @param cls 作为数据承载的模型类
 @param conf 表名数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回是否查询成功
 
 @disc 1.condition中的通过conditionWith指定查询条件，若不指定查询条件则默认查询表中的全部数据
      2.condition中的bindKey将失效，查询个数是将不查询任何字段的实际值
      3.查询个数不支持递归查询
      4.若查询成功，result字段将携带个数（NSNumber）
 */
-(DWDatabaseResult *)queryTableForCountWithClass:(nullable Class)cls configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


/**
 按指定Dw_id查询指定信息

 @param cls 承载数据的模型类
 @param Dw_id 指定ID
 @param recursive 是否递归查询
 @param conf 表名数据库句柄
 @param condition 指定查询条件的构造器
 @return 返回对应数据的模型
 
 @disc 1.此处具体查询基本规则同上。
      2.此处condition中的conditionWith语句将失效，以Dw_id作为唯一查询条件。Dw_id不能为空
      3.若操作成功，result字段将携带指定模型。
      4.此方法更适用于在确定某条数据的ID后要对此条数据进行追踪的情景，避免了每次查询并筛选的过程(如通过年龄查询出一批人后选中其中一个人，以后要针对这个人做操作，即可在本次记下ID后以后通过ID查询)。
 */
-(DWDatabaseResult *)queryTableWithClass:(nullable Class)cls Dw_id:(NSNumber *)Dw_id recursive:(BOOL)recursive configuration:(DWDatabaseConfiguration *)conf condition:(nullable DWDatabaseConditionHandler)condition;


#pragma mark ------ 其他 ------

/**
 获取指定数据库版本
 
 @param conf 数据库句柄
 @return 返回查询结果，若查询成功，result中将携带数据库当前版本
 
 @disc 1.此处应传库名数据库句柄
 */
-(DWDatabaseResult *)fetchDBVersionWithConfiguration:(DWDatabaseConfiguration *)conf;

/**
 升级回调
 
 @param db 待升级的数据库
 @param currentVersion 指定数据库当前版本
 @param targetVersion 指定升级到的数据库版本
 @return 升级后的数据库版本
 */
typedef NSInteger(^DWDatabaseUpgradeDBVersionHandler)(DWDatabase * db,NSInteger currentVersion,NSInteger targetVersion);
/**
 升级数据库至指定版本
 
 @param targetVersion 指定升级到的数据库版本
 @param conf 库名数据库句柄
 @param handler 升级回调
 @return 升级是否成功的结果
 
 @disc 1.DWDatabaseUpgradeDBVersionHandler回调中应返回升级后的版本号
 
 @eg. :
 DWDatabaseResult * result = [self.db upgradeDBVersion:1 configuration:conf handler:^NSInteger(DWDatabase * _Nonnull db, NSInteger currentVersion, NSInteger targetVersion) {
     switch (currentVersion) {
         case 0:
         {
             ///这里写0升级至1的代码
             result = [db addFieldsToTableWithClass:[C class] keys:@[@"a"] configuration:result.result];
             if (!result.success) {
                 NSLog(@"%@",result.error);
                 return 0;
             }
         }
         case 1:
         {
             NSLog(@"升级至2级");
         }
         case 2:
         {
             NSLog(@"升级至3级");
         }
         default:
         {
             return targetVersion;
         }
     }
 }];
 */
-(DWDatabaseResult *)upgradeDBVersion:(NSInteger)targetVersion configuration:(DWDatabaseConfiguration *)conf handler:(DWDatabaseUpgradeDBVersionHandler)handler;

/**
 为指定数据表补充其对应类上缺少的属性字段
 
 @param cls 数据表对应的类
 @param conf 表名数据库句柄
 @return 补充是否成功结果
 
 @disc 1.内部将遍历所有需入库属性，自动补充，任意一个补充失败时立即停止。
      2.框架内部自动维护指定表是否补充过，如果补充过，不会反复补充。
 */
-(DWDatabaseResult *)supplyFieldIfNeededWithClass:(Class)cls configuration:(DWDatabaseConfiguration *)conf;

/**
 为指定数据表补充其对应类上指定的属性字段
 
 @param cls 数据表对应的类
 @param keys 需补充的属性字段
 @param conf 表名数据库句柄
 @return 补充是否成功结果
 
 @disc 1.此处应传表名数据库句柄
      2.内部将遍历所有需入库属性，自动补充，任意一个补充失败时立即停止。
      3.keys中传入的应该是模型的属性名。框架内部自动维护指定表中指定Key是否补充过，如果补充过，不会反复补充。
 */
-(DWDatabaseResult *)addFieldsToTableWithClass:(Class)cls keys:(NSArray<NSString *> *)keys configuration:(DWDatabaseConfiguration *)conf;

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
+(NSString *)fetchDBNameForModel:(NSObject *)model;

/**
获取模型所在的数据表名称。

@param model 指定模型
@return 对应数据表名称

@disc 1.只有由框架查询得到的或者是插入到表中成功的model才会存在数据表名称
      2.具有数据表名称的模型从表中删除后会移除模型的数据表名称
*/
+(NSString *)fetchTblNameForModel:(NSObject *)model;

///模型存数据库需要保存的键值
+(NSArray <DWPrefix_YYClassPropertyInfo *>*)propertysToSaveWithClass:(Class)cls;

///获取类指定键值的propertyInfo
+(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)propertyInfosWithClass:(Class)cls keys:(NSArray *)keys;
@end
NS_ASSUME_NONNULL_END
