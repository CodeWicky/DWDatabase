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
    return [NSString stringWithFormat:@"<PropertyName:%@ Type:%02lx>",self.name,self.type & DWPrefix_YYEncodingTypeMask];
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
