//
//  DWDatabasePropertyInfo.m
//  DWDatabase
//
//  Created by Wicky on 2019/10/4.
//

#import "NSObject+PropertyInfo.h"

NS_INLINE DWPrefix_YYEncodingType DWPrefix_YYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return DWPrefix_YYEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return DWPrefix_YYEncodingTypeUnknown;
    
    DWPrefix_YYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            ///prefix
            case 'r':
            case 'n':
            case 'N':
            case 'o':
            case 'O':
            case 'R':
            case 'V': {
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return DWPrefix_YYEncodingTypeUnknown | qualifier;
    
    switch (*type) {
        case 'v': return DWPrefix_YYEncodingTypeVoid | qualifier;
        case 'B': return DWPrefix_YYEncodingTypeBool | qualifier;
        case 'c': return DWPrefix_YYEncodingTypeInt8 | qualifier;
        case 'C': return DWPrefix_YYEncodingTypeUInt8 | qualifier;
        case 's': return DWPrefix_YYEncodingTypeInt16 | qualifier;
        case 'S': return DWPrefix_YYEncodingTypeUInt16 | qualifier;
        case 'i': return DWPrefix_YYEncodingTypeInt32 | qualifier;
        case 'I': return DWPrefix_YYEncodingTypeUInt32 | qualifier;
        case 'l': return DWPrefix_YYEncodingTypeInt32 | qualifier;
        case 'L': return DWPrefix_YYEncodingTypeUInt32 | qualifier;
        case 'q': return DWPrefix_YYEncodingTypeInt64 | qualifier;
        case 'Q': return DWPrefix_YYEncodingTypeUInt64 | qualifier;
        case 'f': return DWPrefix_YYEncodingTypeFloat | qualifier;
        case 'd': return DWPrefix_YYEncodingTypeDouble | qualifier;
        case 'D': return DWPrefix_YYEncodingTypeLongDouble | qualifier;
        case '#': return DWPrefix_YYEncodingTypeClass | qualifier;
        case ':': return DWPrefix_YYEncodingTypeSEL | qualifier;
        case '*': return DWPrefix_YYEncodingTypeCString | qualifier;
        case '^': return DWPrefix_YYEncodingTypePointer | qualifier;
        case '[': return DWPrefix_YYEncodingTypeCArray | qualifier;
        case '(': return DWPrefix_YYEncodingTypeUnion | qualifier;
        case '{': return DWPrefix_YYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return DWPrefix_YYEncodingTypeBlock | qualifier;
            else
                return DWPrefix_YYEncodingTypeObject | qualifier;
        }
        default: return DWPrefix_YYEncodingTypeUnknown | qualifier;
    }
}

/// Get the Foundation class type from property info.
NS_INLINE DWPrefix_YYEncodingNSType YYClassGetNSType(Class cls) {
    if (!cls) return DWPrefix_YYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return DWPrefix_YYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return DWPrefix_YYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return DWPrefix_YYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return DWPrefix_YYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return DWPrefix_YYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return DWPrefix_YYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return DWPrefix_YYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return DWPrefix_YYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return DWPrefix_YYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return DWPrefix_YYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return DWPrefix_YYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return DWPrefix_YYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return DWPrefix_YYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return DWPrefix_YYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return DWPrefix_YYEncodingTypeNSSet;
    return DWPrefix_YYEncodingTypeNSUnknown;
}

@implementation DWPrefix_YYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    DWPrefix_YYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    NSString * typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = DWPrefix_YYEncodingGetType(attrs[i].value);
                    
                    if ((type & DWPrefix_YYEncodingTypeMask) == DWPrefix_YYEncodingTypeObject && typeEncoding.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:typeEncoding];
                        if (![scanner scanString:@"@\"" intoString:NULL]) continue;
                        
                        NSString *clsName = nil;
                        if ([scanner scanUpToCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&clsName]) {
                            if (clsName.length) {
                                _cls = objc_getClass(clsName.UTF8String);
                            }
                        }
                    }
                }
            }
            break;
            case 'G':
            {
                type |= DWPrefix_YYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            }
            break;
            case 'S':
            {
                type |= DWPrefix_YYEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            }
            break;
            default: break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    if (_name.length) {
        if (!_getter) {
            _getter = NSSelectorFromString(_name);
        }
        if (!_setter) {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    _type = type;
    if ((type & DWPrefix_YYEncodingTypeMask) == DWPrefix_YYEncodingTypeObject && _cls) {
        _nsType = YYClassGetNSType(_cls);
    } else {
        _nsType = DWPrefix_YYEncodingTypeNSUnknown;
    }
    return self;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"<PropertyName:%@ Type:%02lx>",self.name,(unsigned long)self.type & DWPrefix_YYEncodingTypeMask];
}

@end

@implementation DWMetaClassInfo

+(instancetype)classInfoFromClass:(Class)cls {
    if (!cls || !NSStringFromClass(cls)) {
        return nil;
    }
    static NSMutableDictionary * infoCollection;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        infoCollection = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    DWMetaClassInfo * info = [infoCollection valueForKey:NSStringFromClass(cls)];
    if (!info) {
        info = [DWMetaClassInfo new];
        [info setupInfoWithClass:cls];
        [infoCollection setValue:info forKey:NSStringFromClass(cls)];
    }
    return info;
}

+(BOOL)hasValidFieldSupplyForClass:(Class)cls withValidKey:(NSString *)validKey {
    if (validKey.length == 0) {
        return NO;
    }
    DWMetaClassInfo * classInfo = [self classInfoFromClass:cls];
    return [classInfo.fieldSupplyValidedSet containsObject:validKey];
}

+(void)validedFieldSupplyForClass:(Class)cls withValidKey:(NSString *)validKey {
    if (validKey.length == 0) {
        return ;
    }
    DWMetaClassInfo * classInfo = [self classInfoFromClass:cls];
    [classInfo.fieldSupplyValidedSet addObject:validKey];
}

-(void)setupInfoWithClass:(Class)cls {
    if (!cls || !NSStringFromClass(cls)) {
        return;
    }
    _cls = cls;
    Class superCls = class_getSuperclass(cls);
    _name = NSStringFromClass(cls);
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            DWPrefix_YYClassPropertyInfo *info = [[DWPrefix_YYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    if (superCls && ![superCls isEqual:[NSObject class]]) {
        _superClassInfo = [[self class] classInfoFromClass:superCls];
    }
}

-(NSDictionary<NSString *, DWPrefix_YYClassPropertyInfo *> *)allPropertyInfos {
    static NSMutableDictionary * allPropertyInfosContainer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allPropertyInfosContainer = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    NSMutableDictionary * allPropertysInfo = allPropertyInfosContainer[self.name];
    if (!allPropertysInfo) {
        allPropertysInfo = [NSMutableDictionary dictionaryWithDictionary:self.propertyInfos];
        allPropertyInfosContainer[self.name] = allPropertysInfo;
        NSArray * tmp = allPropertysInfo.allKeys;
        
        if ([self.superClassInfo allPropertyInfos].allKeys.count) {
            [[self.superClassInfo allPropertyInfos] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
                if (![tmp containsObject:key]) {
                    [allPropertysInfo setValue:obj forKey:key];
                }
            }];
        }
    }
    return allPropertysInfo;
}

#pragma mark --- setter/getter ---
-(NSMutableSet *)fieldSupplyValidedSet {
    if (!_fieldSupplyValidedSet) {
        _fieldSupplyValidedSet = [NSMutableSet set];
    }
    return _fieldSupplyValidedSet;
}

@end

@implementation NSObject (DWDatabaseTransform)

-(NSDictionary *)dw_transformToDictionary {
    NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> * allPropertyInfos = [[self class] dw_allPropertyInfos];
    if (!allPropertyInfos.allKeys.count) {
        return nil;
    }
    NSMutableDictionary * ret = [NSMutableDictionary dictionaryWithCapacity:0];
    [allPropertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name) {
            id value = [self dw_valueForPropertyInfo:obj];
            if (value) {
                NSString * name = obj.name;
                if (name.length) {
                    ret[name] = value;
                }
            }
        }
    }];
    return [ret copy];
}

-(NSDictionary *)dw_transformToDictionaryForKeys:(NSArray<NSString *> *)keys {
    if (!keys.count) {
        return nil;
    }
    
    NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> * allPropertyInfos = [[self class] dw_allPropertyInfos];
    if (!allPropertyInfos.allKeys.count) {
        return nil;
    }
    NSMutableDictionary * ret = [NSMutableDictionary dictionaryWithCapacity:0];
    [allPropertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DWPrefix_YYClassPropertyInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.name && [keys containsObject:obj.name]) {
            id value = [self dw_valueForPropertyInfo:obj];
            if (value) {
                NSString * name = obj.name;
                if (name.length) {
                    ret[name] = value;
                }
            }
        }
    }];
    
    if (!ret.allKeys.count) {
        return nil;
    }
    return [ret copy];
}

+(instancetype)dw_modelFromDictionary:(NSDictionary *)dictionary {
    NSObject * ret = [self new];
    if (!dictionary.allKeys.count) {
        return ret;
    }
    
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* allPropertyInfos = [self dw_allPropertyInfos];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length && obj) {
            DWPrefix_YYClassPropertyInfo * info = allPropertyInfos[key];
            [ret dw_setValue:obj forPropertyInfo:info];
        }
    }];
    return ret;
}

+(instancetype)dw_modelFromDictionary:(NSDictionary *)dictionary withKeys:(NSArray<NSString *> *)keys {
    NSObject * ret = [self new];
    if (!dictionary.allKeys.count || !keys.count) {
        return ret;
    }
    
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* allPropertyInfos = [self dw_allPropertyInfos];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (key.length && obj && [keys containsObject:key]) {
            DWPrefix_YYClassPropertyInfo * info = allPropertyInfos[key];
            [ret dw_setValue:obj forPropertyInfo:info];
        }
    }];
    return ret;
}

@end

@implementation NSObject (DWDatabasePropertyInfos)

+(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)dw_allPropertyInfos {
    return [[DWMetaClassInfo classInfoFromClass:self] allPropertyInfos];
}

+(NSDictionary<NSString *,DWPrefix_YYClassPropertyInfo *> *)dw_propertyInfosForKeys:(NSArray<NSString *> *)keys {
    if (!keys.count) {
        return nil;
    }
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithCapacity:0];
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *>* all = [self dw_allPropertyInfos];
    [keys enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([all.allKeys containsObject:obj] && obj.length) {
            [dic setValue:[all valueForKey:obj] forKey:obj];
        }
    }];
    return [dic copy];
}

-(id)dw_valueForPropertyInfo:(DWPrefix_YYClassPropertyInfo *)info {
    if (!info) {
        return nil;
    }
    return modelValueWithPropertyInfo(self, info);
}

-(void)dw_setValue:(id)value forPropertyInfo:(DWPrefix_YYClassPropertyInfo *)info {
    modelSetValueWithPropertyInfo(self, info, value);
}

#pragma mark --- tool method ---
///模型根据propertyInfo取值（用于给FMDB让其落库，故均为FMDB支持的对象类型）
static id modelValueWithPropertyInfo(id model,DWPrefix_YYClassPropertyInfo * property) {
    switch (property.type & DWPrefix_YYEncodingTypeMask) {
        case DWPrefix_YYEncodingTypeBool:
        case DWPrefix_YYEncodingTypeInt8:
        case DWPrefix_YYEncodingTypeUInt8:
        case DWPrefix_YYEncodingTypeInt16:
        case DWPrefix_YYEncodingTypeUInt16:
        case DWPrefix_YYEncodingTypeInt32:
        case DWPrefix_YYEncodingTypeUInt32:
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        {
            id value = [model valueForKey:property.name];
            if ([value isEqual:[NSNull null]]) {
                return @(NAN);
            } else if ([value isKindOfClass:[NSNumber class]]) {
                return value;
            } else if ([value isKindOfClass:[NSString class]]) {
                if ([value containsString:@"."]) {
                    return @([value floatValue]);
                } else {
                    return @([value integerValue]);
                }
            } else {
                return nil;
            }
        }
            ///不支持NAN
        case DWPrefix_YYEncodingTypeInt64:
        case DWPrefix_YYEncodingTypeUInt64:
        {
            id value = [model valueForKey:property.name];
            if ([value isEqual:[NSNull null]]) {
                return @(0);
            } else if ([value isKindOfClass:[NSNumber class]]) {
                return value;
            } else if ([value isKindOfClass:[NSString class]]) {
                if ([value containsString:@"."]) {
                    return @([value floatValue]);
                } else {
                    return @([value integerValue]);
                }
            } else {
                return nil;
            }
        }
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, property.getter);
            return [NSNumber numberWithDouble:num];
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            id value = [model valueForKey:property.name];
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                {
                    if ([value isKindOfClass:[NSString class]]) {
                        return [value copy];
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        return [NSString stringWithFormat:@"%f",[value floatValue]];
                    } else if ([value isKindOfClass:[NSData class]]) {
                        return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                    } else if ([value isKindOfClass:[NSDate class]]) {
                        return [dateFormatter() stringFromDate:value];
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        return [value absoluteString];
                    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                        NSData * dV = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
                        if (!dV) {
                            return nil;
                        }
                        return [[NSString alloc] initWithData:dV encoding:NSUTF8StringEncoding];
                    } else if ([value isKindOfClass:[NSSet class]]) {
                        NSData * dV = [NSJSONSerialization dataWithJSONObject:[value allObjects] options:0 error:nil];
                        if (!dV) {
                            return nil;
                        }
                        return [[NSString alloc] initWithData:dV encoding:NSUTF8StringEncoding];
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    if ([value isEqual:[NSNull null]]) {
                        return @(NAN);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        return value;
                    } else if ([value isKindOfClass:[NSString class]]) {
                        if ([value containsString:@"."]) {
                            return @([value floatValue]);
                        } else {
                            return @([value integerValue]);
                        }
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSData:
                case DWPrefix_YYEncodingTypeNSMutableData:
                {
                    if ([value isKindOfClass:[NSData class]]) {
                        return [value copy];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        return [value dataUsingEncoding:NSUTF8StringEncoding];
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSDate:
                {
                    if ([value isKindOfClass:[NSDate class]]) {
                        return [dateFormatter() stringFromDate:value];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        if ([dateFormatter() dateFromString:value]) {
                            return value;
                        } else {
                            return nil;
                        }
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    if ([value isKindOfClass:[NSURL class]]) {
                        return [value absoluteString];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        return value;
                    } else {
                        return nil;
                    }
                }
                case DWPrefix_YYEncodingTypeNSArray:
                case DWPrefix_YYEncodingTypeNSMutableArray:
                case DWPrefix_YYEncodingTypeNSDictionary:
                case DWPrefix_YYEncodingTypeNSMutableDictionary:
                case DWPrefix_YYEncodingTypeNSSet:
                case DWPrefix_YYEncodingTypeNSMutableSet:
                {
                    if ([value isEqual:[NSNull null]]) {
                        return nil;
                    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSSet class]]) {
                        if ([value isKindOfClass:[NSSet class]]) {
                            value = [value allObjects];
                        }
                        return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
                    } else if ([value isKindOfClass:[NSData class]] || [value isKindOfClass:[NSString class]]) {
                        id tmp = value;
                        if ([tmp isKindOfClass:[NSString class]]) {
                            tmp = [tmp dataUsingEncoding:NSUTF8StringEncoding];
                        }
                        id obj = [NSJSONSerialization JSONObjectWithData:tmp options:0 error:nil];
                        if (obj) {
                            return tmp;
                        } else {
                            return nil;
                        }
                    } else {
                        return nil;
                    }
                }
                default:
                    return nil;
            }
        }
        case DWPrefix_YYEncodingTypeClass:
        {
            id value = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, property.getter);
            if ([value isEqual:[NSNull null]]) {
                return nil;
            } else if ([value isKindOfClass:[NSString class]]) {
                return value;
            } else {
                if (value != Nil) {
                    return NSStringFromClass(value);
                } else {
                    return nil;
                }
            }
        }
        case DWPrefix_YYEncodingTypeSEL:
            return NSStringFromSelector(((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, property.getter));
        case DWPrefix_YYEncodingTypeCString:
            return [NSString stringWithUTF8String:((char * (*)(id, SEL))(void *) objc_msgSend)((id)model, property.getter)];
        default:
            return nil;
    }
}

///根据propertyInfo给模型赋值（用于通过FMDB取出数据库中的值后赋值给模型，故需要将数据转化为模型对应属性的数据类型）
static void modelSetValueWithPropertyInfo(id model,DWPrefix_YYClassPropertyInfo * property,id value) {
    if (!value || !property) {
        return;
    }
    switch (property.type & DWPrefix_YYEncodingTypeMask) {
        case DWPrefix_YYEncodingTypeBool:
        case DWPrefix_YYEncodingTypeInt8:
        case DWPrefix_YYEncodingTypeUInt8:
        case DWPrefix_YYEncodingTypeInt16:
        case DWPrefix_YYEncodingTypeUInt16:
        case DWPrefix_YYEncodingTypeInt32:
        case DWPrefix_YYEncodingTypeUInt32:
        {
            if ([value isEqual:[NSNull null]]) {
                ///如果是NULL则赋NAN
                [model setValue:@(NAN) forKey:property.name];
            } else if ([value isKindOfClass:[NSNumber class]]) {
                [model setValue:value forKey:property.name];
            } else if ([value isKindOfClass:[NSString class]]) {
                NSNumber * numV = @([value integerValue]);
                if (numV) {
                    [model setValue:numV forKey:property.name];
                }
            }
            break;
        }
        case DWPrefix_YYEncodingTypeFloat:
        case DWPrefix_YYEncodingTypeDouble:
        {
            if ([value isEqual:[NSNull null]]) {
                ///如果是NULL则赋NAN
                [model setValue:@(NAN) forKey:property.name];
            } else if ([value isKindOfClass:[NSNumber class]]) {
                [model setValue:value forKey:property.name];
            } else if ([value isKindOfClass:[NSString class]]) {
                NSNumber * numV = @(atof([value UTF8String]));
                if (numV) {
                    [model setValue:numV forKey:property.name];
                }
            }
            break;
        }
            ///不支持NAN
        case DWPrefix_YYEncodingTypeInt64:
        case DWPrefix_YYEncodingTypeUInt64:
        {
            if ([value isEqual:[NSNull null]]) {
                ///如果是NULL则赋NAN
                [model setValue:@(0) forKey:property.name];
            } else if ([value isKindOfClass:[NSNumber class]]) {
                [model setValue:value forKey:property.name];
            } else if ([value isKindOfClass:[NSString class]]) {
                NSNumber * numV = @(atoll([value UTF8String]));
                if (numV) {
                    [model setValue:numV forKey:property.name];
                }
            }
            break;
        }
            ///这个类型不支持KVC
        case DWPrefix_YYEncodingTypeLongDouble:
        {
            long double numV = 0;
            BOOL valid = YES;
            if ([value isEqual:[NSNull null]]) {
                numV = NAN;
            } else if ([value isKindOfClass:[NSNumber class]]) {
                numV = [value longLongValue];
            } else if ([value isKindOfClass:[NSString class]]) {
                numV = atof(([value UTF8String]));
            } else {
                valid = NO;
            }
            if (valid) {
                ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, property.setter, numV);
            }
            break;
        }
        case DWPrefix_YYEncodingTypeObject:
        {
            ///FMDB中仅可能取出NSString/NSData/NSNumber/NSNull
            switch (property.nsType) {
                case DWPrefix_YYEncodingTypeNSString:
                case DWPrefix_YYEncodingTypeNSMutableString:
                {
                    if ([value isKindOfClass:[NSString class]]) {
                        if (property.nsType == DWPrefix_YYEncodingTypeNSString) {
                            [model setValue:value forKey:property.name];
                        } else {
                            [model setValue:[value mutableCopy] forKey:property.name];
                        }
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        NSString * strV = [((NSNumber *)value) stringValue];
                        if (property.nsType == DWPrefix_YYEncodingTypeNSString) {
                            [model setValue:strV forKey:property.name];
                        } else {
                            [model setValue:[strV mutableCopy] forKey:property.name];
                        }
                    } else if ([value isKindOfClass:[NSData class]]) {
                        NSString * strV = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        if (strV) {
                            if (property.nsType == DWPrefix_YYEncodingTypeNSString) {
                                [model setValue:strV forKey:property.name];
                            } else {
                                [model setValue:[strV mutableCopy] forKey:property.name];
                            }
                        }
                    }
                    break;
                }
                case DWPrefix_YYEncodingTypeNSNumber:
                {
                    if ([value isEqual:[NSNull null]]) {
                        [model setValue:@(NAN) forKey:property.name];
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        [model setValue:value forKey:property.name];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSNumber * numV = @(atof([value UTF8String]));
                        if (numV) {
                            [model setValue:numV forKey:property.name];
                        }
                    }
                    break;
                }
                case DWPrefix_YYEncodingTypeNSData:
                case DWPrefix_YYEncodingTypeNSMutableData:
                {
                    if ([value isKindOfClass:[NSData class]]) {
                        if (property.nsType == DWPrefix_YYEncodingTypeNSData) {
                            [model setValue:value forKey:property.name];
                        } else {
                            [model setValue:[value mutableCopy] forKey:property.name];
                        }
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSData *dataV = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (dataV) {
                            if (property.nsType == DWPrefix_YYEncodingTypeNSData) {
                                [model setValue:dataV forKey:property.name];
                            } else {
                                [model setValue:[dataV mutableCopy] forKey:property.name];
                            }
                        }
                    }
                    break;
                }
                case DWPrefix_YYEncodingTypeNSDate:
                {
                    if ([value isKindOfClass:[NSDate class]]) {
                        [model setValue:value forKey:property.name];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSDate * dataStr = [dateFormatter() dateFromString:value];
                        if (dataStr) {
                            [model setValue:dataStr forKey:property.name];
                        }
                    }
                    break;
                }
                case DWPrefix_YYEncodingTypeNSURL:
                {
                    if ([value isKindOfClass:[NSURL class]]) {
                        [model setValue:value forKey:property.name];
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSURL * url = [NSURL URLWithString:value];
                        if (url) {
                            [model setValue:url forKey:property.name];
                        }
                    }
                    break;
                }
                case DWPrefix_YYEncodingTypeNSArray:
                case DWPrefix_YYEncodingTypeNSMutableArray:
                case DWPrefix_YYEncodingTypeNSDictionary:
                case DWPrefix_YYEncodingTypeNSMutableDictionary:
                case DWPrefix_YYEncodingTypeNSSet:
                case DWPrefix_YYEncodingTypeNSMutableSet:
                {
                    if ([value isEqual:[NSNull null]]) {
                        break;
                    }
                    id aV = value;
                    if ([aV isKindOfClass:[NSData class]]) {
                        aV = [NSJSONSerialization JSONObjectWithData:aV options:(NSJSONReadingAllowFragments) error:nil];
                    }
                    if (!aV) {
                        break;
                    }
                    if (property.nsType == DWPrefix_YYEncodingTypeNSArray || property.nsType == DWPrefix_YYEncodingTypeNSMutableArray) {
                        if ([aV isKindOfClass:[NSArray class]]) {
                            if (property.nsType == DWPrefix_YYEncodingTypeNSArray) {
                                [model setValue:aV forKey:property.name];
                            } else {
                                [model setValue:[aV mutableCopy] forKey:property.name];
                            }
                        }
                    } else if (property.nsType == DWPrefix_YYEncodingTypeNSDictionary || property.nsType == DWPrefix_YYEncodingTypeNSMutableDictionary) {
                        if ([aV isKindOfClass:[NSDictionary class]]) {
                            if (property.nsType == DWPrefix_YYEncodingTypeNSDictionary) {
                                [model setValue:aV forKey:property.name];
                            } else {
                                [model setValue:[aV mutableCopy] forKey:property.name];
                            }
                        }
                    } else {
                        if ([aV isKindOfClass:[NSArray class]]) {
                            aV = [NSSet setWithArray:aV];
                            if ([aV isKindOfClass:[NSSet class]]) {
                                if (property.nsType == DWPrefix_YYEncodingTypeNSSet) {
                                    [model setValue:aV forKey:property.name];
                                } else {
                                    [model setValue:[aV mutableCopy] forKey:property.name];
                                }
                            }
                        }
                    }
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case DWPrefix_YYEncodingTypeClass:
        {
            if ([value isKindOfClass:[NSString class]]) {
                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, property.setter, (Class)NSClassFromString(value));
            }
            break;
        }
        case DWPrefix_YYEncodingTypeSEL:
        {
            if ([value isKindOfClass:[NSString class]]) {
                ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, property.setter, (SEL)NSSelectorFromString(value));
            }
            break;
        }
        case DWPrefix_YYEncodingTypeCString:
        {
            if ([value isKindOfClass:[NSString class]]) {
                ((void (*)(id, SEL,const char *))(void *) objc_msgSend)((id)model, property.setter, [value UTF8String]);
            }
            break;
        }
        default:
            break;
    }
}

///时间转换格式化
NS_INLINE NSDateFormatter *dateFormatter(){
    static NSDateFormatter * formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return formatter;
}

@end
