//
//  DWDatabaseConditionMaker.h
//  DWDatabase
//
//  Created by Wicky on 2019/9/30.
//

#import <Foundation/Foundation.h>
#import <DWKit/NSObject+DWObjectUtils.h>
NS_ASSUME_NONNULL_BEGIN

@class DWDatabaseCondition,DWDatabaseConditionMaker;
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseConditionKey)(NSString * key);
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseConditionClass)(Class clazz);
typedef DWDatabaseCondition *_Nonnull(^DWDatabaseConditionValue)(id value);
typedef DWDatabaseCondition *_Nonnull(^DWDatabaseConditionVoidValue)(void);
typedef DWDatabaseCondition *_Nonnull(^DWDatabaseConditionCombine)(void);
typedef void (^DWDatabaseConditionHandler)(DWDatabaseConditionMaker * maker);
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseBindKey)(NSString * key);
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseBindKeyRecursively)(BOOL recursively);
typedef DWDatabaseConditionMaker *_Nonnull(^DWDatabaseBindKeyCommit)(void);

/**
 maker创建的条件支持与逻辑与或逻辑，通过combine()语句以就近原则组合两个条件为一个逻辑条件。
 
 @eg. : maker.conditionWith(@"a").equalTo(1).and.conditionWith(@"b").equalTo(2).or.conditionWith(@"b").equalTo(3).combine().combine();
 
 本例中，指定了三个条件【a = 1,b = 2,b = 3】
 其中执行到第一个combine语句时，就近寻找两个条件，则组合后两个条件【b = 2,b = 3】，按照逻辑符指定，则逻辑条件为【b = 2 OR b = 3】
 执行第二个combine语句时，逻辑同上，组合后两个条件【a = 1,(b = 2 OR b = 3)】，按照逻辑符指定，则逻辑条件为【a = 1 AND (b = 2 OR b = 3)】
 
 综上，本例中，最后的条件为【a = 1 AND (b = 2 OR b = 3)】
 */
@interface DWDatabaseCondition : NSObject

///以就近原则按照先前指定的逻辑关系组合调用此函数处之前的两个条件
@property (nonatomic ,copy) DWDatabaseConditionCombine combine;

///添加一个且条件（下一个添加的条件与当前条件为且关系）
-(DWDatabaseConditionMaker *)and;

///添加一个或条件（下一个添加的条件与当前条件为或 关系）
-(DWDatabaseConditionMaker *)or;

@end

/**
 maker装载一个当前条件构造器操作的类，后续操作将针对该操作类进行相关数据表操作。
 
 @eg. :
 maker.loadClass([A class]);
 
 本例中，为当前构造器，装载了一个操作类，即类A。
 */
@interface DWDatabaseConditionMaker : NSObject

//1.指定条件装载的类
///为当前条件工厂指定索引模型类（必须在其他属性前调用）
@property (nonatomic ,copy) DWDatabaseConditionClass loadClass;

@end

/**
 为条件构造器添加相关的查询、更新、删除条件。框架内部将根据这些条件构造相关sql语句。
 
 maker.conditionWith(@"a").conditionWith(@"b").greaterThan(1);
 NSArray * values = @[@2,@3];
 maker.conditionWith(@"c").inValues(values);
 maker.conditionWith(@"d").like(@"zhangsan");
 maker.conditionWith(@"e").between(DWBetweenMakeIntegerValue(0, 100));
 maker.conditionWith(@"f").between(DWBetweenMakeFloatValue(-3.14, 3.14));
 maker.conditionWith(@"g").between(DWApproximateFloatValue(3.14));
 maker.conditionWith(@"h").notNull();
 
 本例中，示例了条件构造器基本使用方法：
 1.conditionWith语句可以连续使用，代表为多个数据表字段添加相同条件值。
 maker.conditionWith(@"a").conditionWith(@"b").greaterThan(1);
 上式中添加条件【a > 1 AND b > 1】
 
 2.conditionWith语句支持添加副属性的条件，内部将转换为LEFT JOIN关系。
 maker.conditionWith(@"classB.b").equalTo(10);
 上式中添加条件【LEFT JOIN TblBName ON TblAName.classB = TblBName.Dw_id WHERE TblBName.b = 10】其中原始表为TblAName，嵌套表为TblBName
 
 3.条件值可以除了可以添加比较运算关系外，还可以添加其他多种：集合运算关系，模糊匹配关系，范围运算关系，非空性判断关系。
 
 集合运算关系：
 NSArray * values = @[@2,@3];
 maker.conditionWith(@"c").inValues(values);
 上式中添加条件【IN (2,3)】，表示c等于2或者3。
 
 模糊匹配关系：
 maker.conditionWith(@"d").like(@"zhangsan");
 上式中添加条件【LIKE zhangsan】
 
 范围运算关系：
 maker.conditionWith(@"e").between(DWBetweenMakeIntegerValue(0, 100));
 maker.conditionWith(@"f").between(DWBetweenMakeFloatValue(-3.14, 3.14));
 上式中添加条件【e BETWEEN 0 AND 100】及【f BETWEEN -3.14 AND 3.14】
 
 特殊的，有与浮点数的精度问题，浮点数入库后可能存在精度丢失。建议添加查询条件时，通过between语句添加近似条件值
 maker.conditionWith(@"g").between(DWApproximateFloatValue(3.14));
 上式中添加条件【g BETWEEN 3.139999 AND 3.140001】，及与近似值误差在0.000001之间。
 
 非空性判断关系：
 maker.conditionWith(@"h").notNull();
 上式中添加条件【h IS NOT NULL】
 
 4.不同条件之间，默认以【AND】进行相连，即默认为且关系。若想添加【OR】或关系，请使用or语句。
 */
@interface DWDatabaseConditionMaker (Condition)
//2.指定条件对应的键值
///指定当前条件对应的键值（此处会根据先前装载的模型类自动推断出该模型类的相关属性，方便快速指定键值。），一个条件可以对应多个键值（即属性a及属性bu均等于某个值时conditionWith 可以连续调用）
@property (nonatomic ,copy) DWDatabaseConditionKey conditionWith;

//3.指定条件对应的值（一个条件只能有一个值关系及指定值）
///指定当前条件为等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue equalTo;

///指定当前条件为不等于指定值得条件
@property (nonatomic ,copy) DWDatabaseConditionValue notEqualTo;

///指定当前条件为大于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue greaterThan;

///指定当前条件为小于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue lessThan;

///指定当前条件为大于等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue greaterThanOrEqualTo;

///指定当前条件为小于等于指定值的条件
@property (nonatomic ,copy) DWDatabaseConditionValue lessThanOrEqualTo;

///【集合运算关系】指定当前条件为在指定值集合中的条件（例如传入@[@"zhangsan",@"lisi"] 则会匹配值为zhangsan或者lisi）
///集合运算关系应传入数组，若传入非数组对象，将会降级为【equalTo】
///若传入数组对象，且数组元素个数为0，将会降级为【恒假的条件】
///若传入数组对象，且数组元素个数为1，将会降级为【equalTo】
@property (nonatomic ,copy) DWDatabaseConditionValue inValues;

///【集合运算关系】指定当前条件为不在指定值集合中的条件（例如传入@[@"zhangsan",@"lisi"] 则会匹配值为非zhangsan且非lisi）
///集合运算关系应传入数组，若传入非数组对象，将会降级为【notEqualTo】
///若传入数组对象，且数组元素个数为0，将会降级为【恒真的条件】
///若传入数组对象，且数组元素个数为1，将会降级为【notEqualTo】
@property (nonatomic ,copy) DWDatabaseConditionValue notInValues;

///指定当前条件为模糊匹配的条件（例如传入@"zhangsan" 则会匹配值为zhangsan或者azhangsanbbb）
@property (nonatomic ,copy) DWDatabaseConditionValue like;

///指定当前条件为在指定值范围中的条件（接收值为DWBetweenFloatValue及DWBetweenIntegerValue）
///若要指定一个整型区间，请传入【DWBetweenIntegerValue】构造的value值。
///若要指定一个浮点型区间，请传入【DWBetweenFloatValue】构造的value值。
///特殊的，当入库时，由于浮点数的精度丢失问题，可导致数据表中数据精度丢失，此时可通过between语句传入【DWApproximateFloatValue】构造的value值，即可指定条件值近似为value，误差在0.000001之内。
///若对精度有严格要求，建议模型字段属性定义为字符串属性
@property (nonatomic ,copy) DWDatabaseConditionValue between;

///指定当前条件为Null值字段
@property (nonatomic ,copy) DWDatabaseConditionVoidValue isNull;

///指定当前条件为非Null值字段
@property (nonatomic ,copy) DWDatabaseConditionVoidValue notNull;

@end

/**
 为条件构造器绑定操作的键值，及是否递归操作。
 
 maker.dw_bindKey(dic).dw_bindKey(classB.b).dw_bindKey(classB.classA.a).commit();
 maker.dw_bindKey(classC).recursively(NO);
 maker.dw_bindKey(classD);
 
 本例中，为数据表操作绑定的操作key共有【dic,classB.b,classB.classA.a,classC,classD】
 其中，支持递归的操作key键值包括【dic,classB.b,classB.classA.a】，不支持递归操作的key有【classC,classD】
 第一句语句中，由于没有显示指定recursive语句，所以绑定的键值均为recursive为YES。通过commit语句标识当前绑定Key会话完成。
 第二句语句，由于上一个绑定Key会话已经完成，进入一个新的绑定Key会话。同时指定recursive为NO。
 第三局语句，由于第二句未调用commit语句，所以仍处于第二个绑定Key的会话中，当前recursive为NO，故绑定的classD也不支持递归操作。
 同一个绑定Key会话中，若多次调用recursive语句，以最后一次调用的指定值为准。
 */
@interface DWDatabaseConditionMaker (BindKey)

///4.绑定操作键值
///为后续操作绑定相关键值。例如：
///(1).插入方法中，指定需要插入表的属性名
///(2).更新方法中，指定需要更新表的属性名
///(3).查询方法中，指定需要查询表的属性名
///若不绑定键值，将默认操作表中所有的字段
@property (nonatomic ,copy) DWDatabaseBindKey bindKey;

///设置绑定的键值是否支持递归，若不调用，默认为YES
@property (nonatomic ,copy) DWDatabaseBindKeyRecursively recursively;

///完成一个绑定Key会话。
@property (nonatomic ,copy) DWDatabaseBindKeyCommit commit;

@end

/**
 没有实际意义，只为了提供自动提示
 
 可以通过dw_loadClass与dw_conditionWith及dw_bindKey配合使用，在转载class的同时，后续为条件构造器添加条件Key或者绑定操作Key的时候，会带出自动提示。
 
 @eg. :
 maker.dw_loadClass(C);
 maker.dw_conditionWith(aNum).equalTo(12).or.dw_conditionWith(classB.b).equalTo(100);
 maker.dw_bindKey(classB).dw_bindKey(classC.a);
 */
@interface DWDatabaseConditionMaker (AutoTip)

@property (nonatomic ,copy) DWDatabaseConditionClass dw_loadClass;

@property (nonatomic ,copy) DWDatabaseConditionKey dw_conditionWith;

@property (nonatomic ,copy) DWDatabaseBindKey dw_bindKey;

@end

NS_ASSUME_NONNULL_END
