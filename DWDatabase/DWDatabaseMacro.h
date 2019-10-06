//
//  DWDatabaseMacro.h
//  Pods
//
//  Created by Wicky on 2019/9/30.
//

#ifndef DWDatabaseMacro_h
#define DWDatabaseMacro_h

typedef struct {
    CGFloat start;
    CGFloat end;
} DWBetweenFloatValue;

typedef struct {
    NSInteger start;
    NSInteger end;
} DWBetweenIntegerValue;

static inline NSValue * DWBetweenMakeIntegerValue(NSInteger start,NSInteger end) {
    DWBetweenIntegerValue value = {start,end};
    NSValue * nsvalue = [NSValue value:&value withObjCType:@encode(DWBetweenIntegerValue)];
    return nsvalue;
}

static inline NSValue * DWBetweenMakeFloatValue(CGFloat start,CGFloat end) {
    DWBetweenFloatValue value = {start,end};
    NSValue * nsvalue = [NSValue value:&value withObjCType:@encode(DWBetweenFloatValue)];
    return nsvalue;
}

static inline NSValue * DWApproximateFloatValue(CGFloat value) {
    return DWBetweenMakeFloatValue(value - 0.000001f, value + 0.000001f);
}

///BoxValue 代码节选自Masonry
static inline id _DWDataBaseBoxValue(const char *type, ...) {
    va_list v;
    va_start(v, type);
    id obj = nil;
    if (strcmp(type, @encode(id)) == 0) {
        id actual = va_arg(v, id);
        obj = actual;
    } else if (strcmp(type, @encode(NSRange)) == 0) {
        NSRange actual = (NSRange)va_arg(v, NSRange);
        obj = [NSValue valueWithRange:actual];
    } else if (strcmp(type, @encode(double)) == 0) {
        double actual = (double)va_arg(v, double);
        obj = [NSNumber numberWithDouble:actual];
    } else if (strcmp(type, @encode(float)) == 0) {
        float actual = (float)va_arg(v, double);
        obj = [NSNumber numberWithFloat:actual];
    } else if (strcmp(type, @encode(int)) == 0) {
        int actual = (int)va_arg(v, int);
        obj = [NSNumber numberWithInt:actual];
    } else if (strcmp(type, @encode(long)) == 0) {
        long actual = (long)va_arg(v, long);
        obj = [NSNumber numberWithLong:actual];
    } else if (strcmp(type, @encode(long long)) == 0) {
        long long actual = (long long)va_arg(v, long long);
        obj = [NSNumber numberWithLongLong:actual];
    } else if (strcmp(type, @encode(short)) == 0) {
        short actual = (short)va_arg(v, int);
        obj = [NSNumber numberWithShort:actual];
    } else if (strcmp(type, @encode(char)) == 0) {
        char actual = (char)va_arg(v, int);
        obj = [NSNumber numberWithChar:actual];
    } else if (strcmp(type, @encode(bool)) == 0) {
        bool actual = (bool)va_arg(v, int);
        obj = [NSNumber numberWithBool:actual];
    } else if (strcmp(type, @encode(unsigned char)) == 0) {
        unsigned char actual = (unsigned char)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedChar:actual];
    } else if (strcmp(type, @encode(unsigned int)) == 0) {
        unsigned int actual = (unsigned int)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedInt:actual];
    } else if (strcmp(type, @encode(unsigned long)) == 0) {
        unsigned long actual = (unsigned long)va_arg(v, unsigned long);
        obj = [NSNumber numberWithUnsignedLong:actual];
    } else if (strcmp(type, @encode(unsigned long long)) == 0) {
        unsigned long long actual = (unsigned long long)va_arg(v, unsigned long long);
        obj = [NSNumber numberWithUnsignedLongLong:actual];
    } else if (strcmp(type, @encode(unsigned short)) == 0) {
        unsigned short actual = (unsigned short)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedShort:actual];
    } else if (strcmp(type, @encode(SEL)) == 0) {
        SEL actual = (SEL)va_arg(v, SEL);
        obj = NSStringFromSelector(actual);
    } else if (strcmp(type, @encode(Class)) == 0) {
        Class actual = (Class)va_arg(v, Class);
        obj = NSStringFromClass(actual);
    } else if (strcmp(type, @encode(char *)) == 0) {
        char * actual = (char *)va_arg(v, char *);
        obj = [NSString stringWithUTF8String:actual];
    }
    va_end(v);
    return obj;
}

///将所有值包装成对象
#define DWDataBaseBoxValue(value) _DWDataBaseBoxValue(@encode(__typeof__((value))), (value))

///快速取出一个对象的一个属性键名对应的字符串
#define keyPathString(objc, keyPath) @(((void)objc.keyPath, #keyPath))

///快速装载一个Class至接下来要创建的条件
#define loadClass(T) \
loadClass([T class]);\
T * loadClass = [T new];\
loadClass = nil

///快速为创建条件选择一个key（调用此宏之前务必调用loadClass）
#define conditionWith(key) conditionWith(keyPathString(loadClass,key))

///快速为创建的条件添加一个要相等的值（可以为任意类型数据，内部自动转换为对象）
#define equalTo(value) equalTo(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个要大于的值
#define greaterThan(value) greaterThan(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个要小于的值
#define lessThan(value) lessThan(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个要大于等于的值
#define greaterThanOrEqualTo(value) greaterThanOrEqualTo(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个要小于等于的值
#define lessThanOrEqualTo(value) lessThanOrEqualTo(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个匹配值的集合
#define inValues(value) inValues(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个匹配值的排除集合
#define notInValues(value) notInValues(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个模糊匹配的值
#define like(value) like(DWDataBaseBoxValue(value))

///快速为创建的条件添加一个范围
#define between(value) between(DWDataBaseBoxValue(value))

#endif /* DWDatabaseMacro_h */
