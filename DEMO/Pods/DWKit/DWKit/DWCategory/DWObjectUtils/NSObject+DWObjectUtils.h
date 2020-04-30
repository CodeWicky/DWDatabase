//
//  DWDatabasePropertyInfo.h
//  DWDatabase
//
//  Created by Wicky on 2019/10/4.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
NS_ASSUME_NONNULL_BEGIN
/**
 以下关于类的元信息相关代码摘取自YYModel，此处摘取代码为了获取属性类型，顾剔除一些无关代码，未避免可能的冲突此处添加前缀
 */
typedef NS_OPTIONS(NSUInteger, DWPrefix_YYEncodingType) {
    DWPrefix_YYEncodingTypeMask       = 0xFF, ///< mask of type value
    DWPrefix_YYEncodingTypeUnknown    = 0, ///< unknown
    DWPrefix_YYEncodingTypeVoid       = 1, ///< void
    DWPrefix_YYEncodingTypeBool       = 2, ///< bool
    DWPrefix_YYEncodingTypeInt8       = 3, ///< char / BOOL
    DWPrefix_YYEncodingTypeUInt8      = 4, ///< unsigned char
    DWPrefix_YYEncodingTypeInt16      = 5, ///< short
    DWPrefix_YYEncodingTypeUInt16     = 6, ///< unsigned short
    DWPrefix_YYEncodingTypeInt32      = 7, ///< int
    DWPrefix_YYEncodingTypeUInt32     = 8, ///< unsigned int
    DWPrefix_YYEncodingTypeInt64      = 9, ///< long long
    DWPrefix_YYEncodingTypeUInt64     = 10, ///< unsigned long long
    DWPrefix_YYEncodingTypeFloat      = 11, ///< float
    DWPrefix_YYEncodingTypeDouble     = 12, ///< double
    DWPrefix_YYEncodingTypeLongDouble = 13, ///< long double
    DWPrefix_YYEncodingTypeObject     = 14, ///< id
    DWPrefix_YYEncodingTypeClass      = 15, ///< Class
    DWPrefix_YYEncodingTypeSEL        = 16, ///< SEL
    DWPrefix_YYEncodingTypeBlock      = 17, ///< block
    DWPrefix_YYEncodingTypePointer    = 18, ///< void*
    DWPrefix_YYEncodingTypeStruct     = 19, ///< struct
    DWPrefix_YYEncodingTypeUnion      = 20, ///< union
    DWPrefix_YYEncodingTypeCString    = 21, ///< char*
    DWPrefix_YYEncodingTypeCArray     = 22, ///< char[10] (for example)
    
    DWPrefix_YYEncodingTypePropertyCustomGetter = 1 << 21, ///< getter=
    DWPrefix_YYEncodingTypePropertyCustomSetter = 1 << 22, ///< setter=
};

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, DWPrefix_YYEncodingNSType) {
    DWPrefix_YYEncodingTypeNSUnknown = 0,
    DWPrefix_YYEncodingTypeNSString,
    DWPrefix_YYEncodingTypeNSMutableString,
    DWPrefix_YYEncodingTypeNSValue,
    DWPrefix_YYEncodingTypeNSNumber,
    DWPrefix_YYEncodingTypeNSDecimalNumber,
    DWPrefix_YYEncodingTypeNSData,
    DWPrefix_YYEncodingTypeNSMutableData,
    DWPrefix_YYEncodingTypeNSDate,
    DWPrefix_YYEncodingTypeNSURL,
    DWPrefix_YYEncodingTypeNSArray,
    DWPrefix_YYEncodingTypeNSMutableArray,
    DWPrefix_YYEncodingTypeNSDictionary,
    DWPrefix_YYEncodingTypeNSMutableDictionary,
    DWPrefix_YYEncodingTypeNSSet,
    DWPrefix_YYEncodingTypeNSMutableSet,
};

///属性信息
@interface DWPrefix_YYClassPropertyInfo : NSObject

@property (nonatomic, assign, readonly) objc_property_t property; ///< property's opaque struct
@property (nonatomic, strong, readonly) NSString *name;           ///< property's name
@property (nonatomic, assign, readonly) DWPrefix_YYEncodingType type;      ///< property's type

@property (nonatomic ,assign, readonly) DWPrefix_YYEncodingNSType nsType; ///< property's foundation type

@property (nonatomic ,assign, readonly) BOOL isCNumber;///< whether property is c number

@property (nonatomic ,assign, readonly) BOOL isContainerProperty;///< wheter property is container property like NSArray/NSMutableArray/NSSet/NSMutableSet

@property (nullable, nonatomic, assign, readonly) Class cls;      ///< may be nil
@property (nonatomic, assign, readonly) SEL getter;               ///< getter (nonnull)
@property (nonatomic, assign, readonly) SEL setter;               ///< setter (nonnull)

@property (nullable, nonatomic ,assign ,readonly) Class genericClass;///< indicates the container property's generic Class if you have set.

- (instancetype)initWithProperty:(objc_property_t)property;

@end

///类的元信息
@interface DWMetaClassInfo : NSObject

@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, DWPrefix_YYClassPropertyInfo *> *propertyInfos; ///< properties
@property (nullable, nonatomic, assign, readonly) Class cls;      ///< class object
@property (nonatomic, strong, readonly) NSString *name; ///< class name
@property (nullable, nonatomic, strong, readonly) DWMetaClassInfo *superClassInfo; ///< super class's class info

+(instancetype)classInfoFromClass:(Class)cls;

-(NSDictionary<NSString *, DWPrefix_YYClassPropertyInfo *> *)allPropertyInfos;

@end

@protocol DWDatabaseTransformProtocol <NSObject>

/**
 模型嵌套时，指定属性对应的类，以便完成自动转换
 
 +(NSDictionary *)dw_containerPropertyGenericClassMap {
     return @{
         @"array":[A class],
         @"modelDic":[A class],
         @"dicFromArray":@"A",
     };
 }
 
 */
+(NSDictionary *)dw_containerPropertyGenericClassMap;

@end

@interface NSObject (DWDatabaseTransform)

-(id)dw_jsonObject;

-(NSDictionary *)dw_transformToDictionary;

-(NSDictionary *)dw_transformToDictionaryForKeys:(NSArray <NSString *>*)keys;

+(instancetype)dw_modelFromDictionary:(NSDictionary *)dictionary;

+(instancetype)dw_modelFromDictionary:(NSDictionary *)dictionary withKeys:(NSArray <NSString *>*)keys;

@end

@interface NSObject (DWDatabasePropertyInfos)

-(id)dw_valueForPropertyInfo:(DWPrefix_YYClassPropertyInfo *)info;

-(void)dw_setValue:(id)value forPropertyInfo:(DWPrefix_YYClassPropertyInfo *)info;

+(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)dw_allPropertyInfos;

+(NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>*)dw_propertyInfosForKeys:(NSArray <NSString *>*)keys;

@end
NS_ASSUME_NONNULL_END
