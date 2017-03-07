//
//  JPMethodSignature.m
//  JSPatch
//
//  Created by bang on 1/19/17.
//  Copyright © 2017 bang. All rights reserved.
//

#import "JPMethodSignature.h"
#import <UIKit/UIKit.h>
#import "JPEngine.h"

@implementation JPMethodSignature {
    NSString *_typeNames;
    NSMutableArray *_argumentTypes;
    NSString *_returnType;
    NSString *_types;
    BOOL _isBlock;
}


- (instancetype)initWithBlockTypeNames:(NSString *)typeNames
{
    self = [super init];
    if (self) {
        _typeNames = typeNames;
        _isBlock = YES;
        [self _parseTypeNames];
        [self _parse];
    }
    return self;
}

- (instancetype)initWithObjCTypes:(NSString *)objCTypes
{
    self = [super init];
    if (self) {
        _types = objCTypes;
        [self _parse];
    }
    return self;
}

- (void)_parse
{
    _argumentTypes = [[NSMutableArray alloc] init];
    for (int i = 0; i < _types.length; i ++) {
        unichar c = [_types characterAtIndex:i];
        NSString *arg;
        
        if (isdigit(c)) continue;
        
        BOOL skipNext = NO;
        if (c == '^') {
            skipNext = YES;
            arg = [_types substringWithRange:NSMakeRange(i, 2)];
            
        } else if (c == '?') {
            // @? is block
            arg = [_types substringWithRange:NSMakeRange(i - 1, 2)];
            [_argumentTypes removeLastObject];
            
        } else {
            
            arg = [_types substringWithRange:NSMakeRange(i, 1)];
        }
        
        if (i == 0) {
            _returnType = arg;
        } else {
            [_argumentTypes addObject:arg];
        }
        if (skipNext) i++;
    }
}

- (void)_parseTypeNames
{
    NSMutableString *encodeStr = [[NSMutableString alloc] init];
    NSArray *typeArr = [_typeNames componentsSeparatedByString:@","];
    for (NSInteger i = 0; i < typeArr.count; i++) {
        NSString *typeStr = trim([typeArr objectAtIndex:i]);
        NSString *encode = [JPMethodSignature typeEncodeWithTypeName:typeStr];
        if (!encode) {
            NSString *argClassName = trim([typeStr stringByReplacingOccurrencesOfString:@"*" withString:@""]);
            if (NSClassFromString(argClassName) != NULL) {
                encode = @"@";
            } else {
//                NSCAssert(NO, @"unreconized type %@", typeStr);
//                return;
                encode = @"@?";
            }
        }
        [encodeStr appendString:encode];
        int length = [JPMethodSignature typeLengthWithTypeName:typeStr];
        [encodeStr appendString:[NSString stringWithFormat:@"%d", length]];
        
        if (_isBlock && i == 0) {
            // Blocks are passed one implicit argument - the block, of type "@?".
            [encodeStr appendString:@"@?0"];
        }
    }
    _types = encodeStr;
}

- (NSString *)typeNames
{
    return _typeNames;
}

- (NSArray *)argumentTypes
{
    return _argumentTypes;
}

- (NSString *)types
{
    return _types;
}

- (NSString *)returnType
{
    return _returnType;
}

#pragma mark - class methods

+ (void)ffiTypeWithObjcType:(NSString *)objcType ffiType:(ffi_type **)ffiType
{
    // basic types
    if ([objcType isEqualToString:@"int"]) {
        *ffiType = &ffi_type_sint;
    } else if ([objcType isEqualToString:@"uint"]) {
        *ffiType = &ffi_type_uint;
    } else if ([objcType isEqualToString:@"long"]) {
        *ffiType = &ffi_type_slong;
    } else if ([objcType isEqualToString:@"ulong"]) {
        *ffiType = &ffi_type_ulong;
    } else if ([objcType isEqualToString:@"size_t"]) {
        *ffiType = &ffi_type_ulong;
    } else if ([objcType isEqualToString:@"float"]) {
        *ffiType = &ffi_type_float;
    } else if ([objcType isEqualToString:@"double"]) {
        *ffiType = &ffi_type_double;
    } else if ([objcType isEqualToString:@"char"]) {
        *ffiType = &ffi_type_schar;
    } else if ([objcType isEqualToString:@"uchar"]) {
        *ffiType = &ffi_type_uchar;
    } else if ([objcType isEqualToString:@"short"]) {
        *ffiType = &ffi_type_sshort;
    } else if ([objcType isEqualToString:@"ushort"]) {
        *ffiType = &ffi_type_ushort;
    } else if ([objcType isEqualToString:@"void"]) {
        *ffiType = &ffi_type_void;
    }

    // cocoa types
    else if ([objcType isEqualToString:@"CGFloat"]) {
        if (CGFLOAT_IS_DOUBLE) {
            *ffiType = &ffi_type_double;
        } else {
            *ffiType = &ffi_type_float;
        }
    } else if ([objcType isEqualToString:@"NSInteger"]) {
        *ffiType = &ffi_type_sint64;
    } else if ([objcType isEqualToString:@"NSUInteger"]) {
        *ffiType = &ffi_type_uint64;
    }

    // pointer
    else if ([objcType isEqualToString:@"id"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"Class"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"@"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType hasSuffix:@"*"]) {
        *ffiType = &ffi_type_pointer;
    }

    // struct
    else if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        ffi_type *structType = malloc(sizeof(ffi_type *));
        NSDictionary *registedStruct = [JPExtension registeredStruct];
        NSString *structName = [objcType substringWithRange:NSMakeRange(1, objcType.length - 2)];
        NSDictionary *structDefine = registedStruct[structName];
        NSString *structTypes = structDefine[@"types"];
        const char *types = [structTypes cStringUsingEncoding:NSUTF8StringEncoding];
        int index = 0;
        ffi_type **subTypes = malloc(sizeof(ffi_type *) * (strlen(types) + 1));
        while (types[index]) {
            switch (types[index]) {
                #define AddSubType(_typeChar, type) \
                case _typeChar: \
                    subTypes[index] = &type; \
                    break;
                AddSubType('c', ffi_type_schar);
                AddSubType('C', ffi_type_uchar);
                AddSubType('s', ffi_type_sshort);
                AddSubType('S', ffi_type_ushort);
                AddSubType('i', ffi_type_sint);
                AddSubType('I', ffi_type_uint);
                AddSubType('l', ffi_type_slong);
                AddSubType('L', ffi_type_ulong);
                AddSubType('d', ffi_type_double);
                AddSubType('f', ffi_type_float);
                //AddSubType('q', ffi_type_slong); // `long long` not supported
                //AddSubType('Q', ffi_type_ulong); // `unsigned long long` not supported
                case 'F': // CGFloat
                    if (CGFLOAT_IS_DOUBLE) {
                        subTypes[index] = &ffi_type_double;
                    } else {
                        subTypes[index] = &ffi_type_float;
                    }
                    break;
                AddSubType('N', ffi_type_sint64); // NSInteger
                AddSubType('U', ffi_type_uint64); // NSUInteger
                AddSubType('B', ffi_type_schar); // BOOL
                AddSubType('*', ffi_type_pointer);
                AddSubType('^', ffi_type_pointer);

                default:
                    break;
            }
            index ++;
        }
        subTypes[index] = NULL;
        structType->size = 0;
        structType->alignment = 0;
        structType->type = FFI_TYPE_STRUCT;
        structType->elements = subTypes;
        *ffiType = structType;
    }
}

+ (ffi_type *)ffiTypeWithEncodingChar:(const char *)c
{
    switch (c[0]) {
        case 'v':
        return &ffi_type_void;
        case 'c':
        return &ffi_type_schar;
        case 'C':
        return &ffi_type_uchar;
        case 's':
        return &ffi_type_sshort;
        case 'S':
        return &ffi_type_ushort;
        case 'i':
        return &ffi_type_sint;
        case 'I':
        return &ffi_type_uint;
        case 'l':
        return &ffi_type_slong;
        case 'L':
        return &ffi_type_ulong;
        case 'q':
        return &ffi_type_sint64;
        case 'Q':
        return &ffi_type_uint64;
        case 'f':
        return &ffi_type_float;
        case 'd':
        return &ffi_type_double;
        case 'B':
        return &ffi_type_uint8;
        case '^':
        return &ffi_type_pointer;
        case '@':
        return &ffi_type_pointer;
        case '#':
        return &ffi_type_pointer;
    }
    return NULL;
}

static NSMutableDictionary *_typeEncodeDict;
static NSMutableDictionary *_typeLengthDict;

+ (int)typeLengthWithTypeName:(NSString *)typeName
{
    if (!typeName) return 0;
    if (!_typeLengthDict) {
        _typeLengthDict = [[NSMutableDictionary alloc] init];
        
        #define JP_DEFINE_TYPE_LENGTH(_type) \
        [_typeLengthDict setObject:@(sizeof(_type)) forKey:@#_type];\

        JP_DEFINE_TYPE_LENGTH(id);
        JP_DEFINE_TYPE_LENGTH(BOOL);
        JP_DEFINE_TYPE_LENGTH(int);
        JP_DEFINE_TYPE_LENGTH(void);
        JP_DEFINE_TYPE_LENGTH(char);
        JP_DEFINE_TYPE_LENGTH(short);
        JP_DEFINE_TYPE_LENGTH(unsigned short);
        JP_DEFINE_TYPE_LENGTH(unsigned int);
        JP_DEFINE_TYPE_LENGTH(long);
        JP_DEFINE_TYPE_LENGTH(unsigned long);
        JP_DEFINE_TYPE_LENGTH(long long);
        JP_DEFINE_TYPE_LENGTH(unsigned long long);
        JP_DEFINE_TYPE_LENGTH(float);
        JP_DEFINE_TYPE_LENGTH(double);
        JP_DEFINE_TYPE_LENGTH(bool);
        JP_DEFINE_TYPE_LENGTH(size_t);
        JP_DEFINE_TYPE_LENGTH(CGFloat);
        JP_DEFINE_TYPE_LENGTH(CGSize);
        JP_DEFINE_TYPE_LENGTH(CGRect);
        JP_DEFINE_TYPE_LENGTH(CGPoint);
        JP_DEFINE_TYPE_LENGTH(CGVector);
        JP_DEFINE_TYPE_LENGTH(NSRange);
        JP_DEFINE_TYPE_LENGTH(NSInteger);
        JP_DEFINE_TYPE_LENGTH(Class);
        JP_DEFINE_TYPE_LENGTH(SEL);
        JP_DEFINE_TYPE_LENGTH(void*);
        JP_DEFINE_TYPE_LENGTH(void *);
        JP_DEFINE_TYPE_LENGTH(id *);
    }
    return [_typeLengthDict[typeName] intValue];
}

+ (NSString *)typeEncodeWithTypeName:(NSString *)typeName
{
    if (!typeName) return nil;
    if (!_typeEncodeDict) {
        _typeEncodeDict = [[NSMutableDictionary alloc] init];
        #define JP_DEFINE_TYPE_ENCODE_CASE(_type) \
        [_typeEncodeDict setObject:[NSString stringWithUTF8String:@encode(_type)] forKey:@#_type];\

        JP_DEFINE_TYPE_ENCODE_CASE(id);
        JP_DEFINE_TYPE_ENCODE_CASE(BOOL);
        JP_DEFINE_TYPE_ENCODE_CASE(int);
        JP_DEFINE_TYPE_ENCODE_CASE(void);
        JP_DEFINE_TYPE_ENCODE_CASE(char);
        JP_DEFINE_TYPE_ENCODE_CASE(short);
        JP_DEFINE_TYPE_ENCODE_CASE(unsigned short);
        JP_DEFINE_TYPE_ENCODE_CASE(unsigned int);
        JP_DEFINE_TYPE_ENCODE_CASE(long);
        JP_DEFINE_TYPE_ENCODE_CASE(unsigned long);
        JP_DEFINE_TYPE_ENCODE_CASE(long long);
        JP_DEFINE_TYPE_ENCODE_CASE(unsigned long long);
        JP_DEFINE_TYPE_ENCODE_CASE(float);
        JP_DEFINE_TYPE_ENCODE_CASE(double);
        JP_DEFINE_TYPE_ENCODE_CASE(bool);
        JP_DEFINE_TYPE_ENCODE_CASE(size_t);
        JP_DEFINE_TYPE_ENCODE_CASE(CGFloat);
        JP_DEFINE_TYPE_ENCODE_CASE(CGSize);
        JP_DEFINE_TYPE_ENCODE_CASE(CGRect);
        JP_DEFINE_TYPE_ENCODE_CASE(CGPoint);
        JP_DEFINE_TYPE_ENCODE_CASE(CGVector);
        JP_DEFINE_TYPE_ENCODE_CASE(NSRange);
        JP_DEFINE_TYPE_ENCODE_CASE(NSInteger);
        JP_DEFINE_TYPE_ENCODE_CASE(Class);
        JP_DEFINE_TYPE_ENCODE_CASE(SEL);
        JP_DEFINE_TYPE_ENCODE_CASE(void*);
        JP_DEFINE_TYPE_ENCODE_CASE(void *);
        [_typeEncodeDict setObject:@"@?" forKey:@"block"];
        [_typeEncodeDict setObject:@"^@" forKey:@"id*"];
    }
    return _typeEncodeDict[typeName];
}

static NSString *trim(NSString *string)
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end


void ConvertObjCTypeToFFIType(NSString *objcType, ffi_type **ffiType)
{
    // basic types
    if ([objcType isEqualToString:@"int"]) {
        *ffiType = &ffi_type_sint;
    } else if ([objcType isEqualToString:@"uint"]) {
        *ffiType = &ffi_type_uint;
    } else if ([objcType isEqualToString:@"long"]) {
        *ffiType = &ffi_type_slong;
    } else if ([objcType isEqualToString:@"ulong"]) {
        *ffiType = &ffi_type_ulong;
    } else if ([objcType isEqualToString:@"size_t"]) {
        *ffiType = &ffi_type_ulong;
    } else if ([objcType isEqualToString:@"float"]) {
        *ffiType = &ffi_type_float;
    } else if ([objcType isEqualToString:@"double"]) {
        *ffiType = &ffi_type_double;
    } else if ([objcType isEqualToString:@"char"]) {
        *ffiType = &ffi_type_schar;
    } else if ([objcType isEqualToString:@"uchar"]) {
        *ffiType = &ffi_type_uchar;
    } else if ([objcType isEqualToString:@"short"]) {
        *ffiType = &ffi_type_sshort;
    } else if ([objcType isEqualToString:@"ushort"]) {
        *ffiType = &ffi_type_ushort;
    } else if ([objcType isEqualToString:@"void"]) {
        *ffiType = &ffi_type_void;
    }

    // cocoa types
    else if ([objcType isEqualToString:@"CGFloat"]) {
        if (CGFLOAT_IS_DOUBLE) {
            *ffiType = &ffi_type_double;
        } else {
            *ffiType = &ffi_type_float;
        }
    } else if ([objcType isEqualToString:@"NSInteger"]) {
        *ffiType = &ffi_type_sint64;
    } else if ([objcType isEqualToString:@"NSUInteger"]) {
        *ffiType = &ffi_type_uint64;
    } else if ([objcType isEqualToString:@"BOOL"]) {
        *ffiType = &ffi_type_schar;
    } else if ([objcType isEqualToString:@"bool"]) {
        *ffiType = &ffi_type_schar;
    }

    // pointer
    else if ([objcType isEqualToString:@"id"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"@"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"Class"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"SEL"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"void *"] || [objcType isEqualToString:@"void*"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"block"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType isEqualToString:@"id*"]) {
        *ffiType = &ffi_type_pointer;
    } else if ([objcType hasSuffix:@"*"]) {
        *ffiType = &ffi_type_pointer;
    }

    // struct
    else if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        ffi_type *structType = malloc(sizeof(ffi_type *));
        NSDictionary *registedStruct = [JPExtension registeredStruct];
        NSString *structName = [objcType substringWithRange:NSMakeRange(1, objcType.length - 2)];
        NSDictionary *structDefine = registedStruct[structName];
        NSString *structTypes = structDefine[@"types"];
        const char *types = [structTypes cStringUsingEncoding:NSUTF8StringEncoding];
        int index = 0;
        ffi_type **subTypes = malloc(sizeof(ffi_type *) * (strlen(types) + 1));
        while (types[index]) {
            switch (types[index]) {
#define AddSubType(_typeChar, type) \
case _typeChar: \
subTypes[index] = &type; \
break;
                AddSubType('c', ffi_type_schar);
                AddSubType('C', ffi_type_uchar);
                AddSubType('s', ffi_type_sshort);
                AddSubType('S', ffi_type_ushort);
                AddSubType('i', ffi_type_sint);
                AddSubType('I', ffi_type_uint);
                AddSubType('l', ffi_type_slong);
                AddSubType('L', ffi_type_ulong);
                AddSubType('d', ffi_type_double);
                AddSubType('f', ffi_type_float);
                //AddSubType('q', ffi_type_slong); // `long long` not supported
                //AddSubType('Q', ffi_type_ulong); // `unsigned long long` not supported
                case 'F': // CGFloat
                if (CGFLOAT_IS_DOUBLE) {
                    subTypes[index] = &ffi_type_double;
                } else {
                    subTypes[index] = &ffi_type_float;
                }
                break;
                AddSubType('N', ffi_type_sint64); // NSInteger
                AddSubType('U', ffi_type_uint64); // NSUInteger
                AddSubType('B', ffi_type_schar); // BOOL
                AddSubType('*', ffi_type_pointer);
                AddSubType('^', ffi_type_pointer);

                default:
                break;
            }
            index ++;
        }
        subTypes[index] = NULL;
        structType->size = 0;
        structType->alignment = 0;
        structType->type = FFI_TYPE_STRUCT;
        structType->elements = subTypes;
        *ffiType = structType;
    }
}

void ConvertObjCValueToFFIValue(NSString *objcType, id objcVal, void *ffiVal)
{
    if ([objcVal isKindOfClass:[JSValue class]]) {
        if ([objcType isEqualToString:@"id"] || [objcType hasSuffix:@"*"]) {
            if ([objcVal isKindOfClass:[JSValue class]]) {
                id retObj = [JPExtension formatJSToOC:objcVal];
                void **ptr = ffiVal;
                *ptr = (__bridge void *)retObj;
            } else {
                void **ptr = ffiVal;
                *ptr = (__bridge void *)(objcVal);
            }
            return;
        }
        objcVal = [objcVal toObject];
    }
#define JP_CONVERT_VALUE_IF(_type, _selector) \
    if ([objcType isEqualToString:@#_type]) { \
        _type val = [((NSNumber *)objcVal) _selector]; \
        _type *ffiValPtr = (_type *)ffiVal; \
        *ffiValPtr = val; \
        return;\
    }
    
#define JP_CONVERT_VALUE_IF2(_typeAlias, _type, _selector) \
    if ([objcType isEqualToString:@#_typeAlias]) { \
        _type val = [((NSNumber *)objcVal) _selector]; \
        _type *ffiValPtr = (_type *)ffiVal; \
        *ffiValPtr = val; \
        return;\
    }
    JP_CONVERT_VALUE_IF(int, intValue);
    JP_CONVERT_VALUE_IF(uint, unsignedIntValue);
    JP_CONVERT_VALUE_IF(long, longValue);
    JP_CONVERT_VALUE_IF2(ulong, unsigned long, unsignedLongValue);
    JP_CONVERT_VALUE_IF(size_t, unsignedLongValue);
    JP_CONVERT_VALUE_IF(float, floatValue);
    JP_CONVERT_VALUE_IF(double, doubleValue);
    JP_CONVERT_VALUE_IF(char, charValue);
    JP_CONVERT_VALUE_IF2(uchar, unsigned char, unsignedCharValue);
    JP_CONVERT_VALUE_IF(short, shortValue);
    JP_CONVERT_VALUE_IF2(ushort, unsigned short, unsignedShortValue);
    JP_CONVERT_VALUE_IF(long long, longLongValue);
    JP_CONVERT_VALUE_IF(unsigned long long, unsignedLongLongValue);
    JP_CONVERT_VALUE_IF(NSInteger, integerValue);
    JP_CONVERT_VALUE_IF(NSUInteger, unsignedIntegerValue);
    JP_CONVERT_VALUE_IF(BOOL, boolValue);
    JP_CONVERT_VALUE_IF(double, doubleValue);
    if (CGFLOAT_IS_DOUBLE) {
        JP_CONVERT_VALUE_IF(CGFloat, doubleValue);
    } else {
        JP_CONVERT_VALUE_IF(CGFloat, floatValue);
    }
    if ([objcType isEqualToString:@"void *"] || [objcType isEqualToString:@"void*"]) {
        void **ptr = ffiVal;
        *ptr = [((JPBoxing *)objcVal) unboxPointer];
        return;
    }
    if ([objcType isEqualToString:@"id"] || [objcType hasSuffix:@"*"] || [objcType isEqualToString:@"Class"]) {
        void **ptr = ffiVal;
        *ptr = (__bridge void *)(objcVal);
        return;
    }
    if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        NSDictionary *registedStruct = [JPExtension registeredStruct];
        NSString *structName = [objcType substringWithRange:NSMakeRange(1, objcType.length - 2)];
        NSDictionary *structDefine = registedStruct[structName];
        void **ptr = ffiVal;
        [JPExtension getStructDataWidthDict:ptr dict:objcVal structDefine:structDefine];
        return;
    }
}

id ConvertFFIValueToObjCValue(void *ffiVal, NSString *objcType)
{
    if ([objcType isEqualToString:@"int"]) {
        int val = *(int *)ffiVal;
        return [NSNumber numberWithInt:val];
    } else if ([objcType isEqualToString:@"uint"]) {
        unsigned int val = *(unsigned int *)ffiVal;
        return [NSNumber numberWithUnsignedInt:val];
    } else if ([objcType isEqualToString:@"long"]) {
        long val = *(long *)ffiVal;
        return [NSNumber numberWithLong:val];
    } else if ([objcType isEqualToString:@"ulong"]) {
        unsigned long val = *(unsigned long *)ffiVal;
        return [NSNumber numberWithUnsignedLong:val];
    } else if ([objcType isEqualToString:@"size_t"]) {
        unsigned long val = *(unsigned long *)ffiVal;
        return [NSNumber numberWithUnsignedLong:val];
    } else if ([objcType isEqualToString:@"float"]) {
        float val = *(float *)ffiVal;
        return [NSNumber numberWithFloat:val];
    } else if ([objcType isEqualToString:@"double"]) {
        double val = *(double *)ffiVal;
        return [NSNumber numberWithDouble:val];
    } else if ([objcType isEqualToString:@"char"]) {
        char val = *(char *)ffiVal;
        return [NSNumber numberWithChar:val];
    } else if ([objcType isEqualToString:@"uchar"]) {
        unsigned char val = *(unsigned char *)ffiVal;
        return [NSNumber numberWithUnsignedChar:val];
    } else if ([objcType isEqualToString:@"short"]) {
        short val = *(short *)ffiVal;
        return [NSNumber numberWithShort:val];
    } else if ([objcType isEqualToString:@"ushort"]) {
        unsigned char val = *(unsigned char *)ffiVal;
        return [NSNumber numberWithUnsignedChar:val];
    } else if ([objcType isEqualToString:@"long long"]) {
        long long val = *(long long *)ffiVal;
        return [NSNumber numberWithLongLong:val];
    } else if ([objcType isEqualToString:@"unsigned long long"]) {
        unsigned long long val = *(unsigned long long *)ffiVal;
        return [NSNumber numberWithUnsignedLongLong:val];
    } else if ([objcType isEqualToString:@"CGFloat"]) {
        CGFloat val = *(CGFloat *)ffiVal;
        return [NSNumber numberWithDouble:val];
    } else if ([objcType isEqualToString:@"NSInteger"]) {
        NSInteger val = *(NSInteger *)ffiVal;
        return [NSNumber numberWithInteger:val];
    } else if ([objcType isEqualToString:@"NSUInteger"]) {
        NSUInteger val = *(NSUInteger *)ffiVal;
        return [NSNumber numberWithUnsignedInteger:val];
    } else if ([objcType isEqualToString:@"BOOL"]) {
        BOOL val = *(BOOL *)ffiVal;
        return [NSNumber numberWithBool:val];
    } else if ([objcType isEqualToString:@"bool"]) {
        BOOL val = *(BOOL *)ffiVal;
        return [NSNumber numberWithBool:val];
    } else if ([objcType isEqualToString:@"void*"] || [objcType isEqualToString:@"void *"]) {
        JPBoxing *box = [[JPBoxing alloc] init];
        box.pointer = (*(void**)ffiVal);
        return box;
    } else if ([objcType isEqualToString:@"id"]) {
        return (__bridge id)(*(void **)ffiVal);
    } else if ([objcType isEqualToString:@"Class"]) {
        return (__bridge id)(*(void **)ffiVal);
    } else if ([objcType hasSuffix:@"*"]) {
        return (__bridge id)(*(void **)ffiVal);
    } else if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        // struct
        NSString *structName = [objcType substringWithRange:NSMakeRange(1, objcType.length-2)];
        NSDictionary *structDefine = [JPExtension registeredStruct][structName];
        if (structDefine) {
            NSMutableDictionary *structDict = @{}.mutableCopy;
            NSString *structTypesStr = structDefine[@"types"];
            NSArray *structTypeKeys = structDefine[@"keys"];
            const char *typeCodes = [structTypesStr cStringUsingEncoding:NSASCIIStringEncoding];
            NSUInteger index = 0;
            NSUInteger position = 0;
            NSUInteger alignment = [structDefine[@"alignment"] unsignedIntegerValue];
            while (typeCodes[index]) {
                switch (typeCodes[index]) {
                    #define JP_PARSE_STRUCT_DATA_CASE(_encode, _type, _selector) \
                        case _encode: { \
                        size_t size = sizeof(_type); \
                        _type *val = malloc(size); \
                        memcpy(val, ffiVal+position, size); \
                        position += alignment ?: size; \
                        structDict[structTypeKeys[index]] = [NSNumber _selector:*val]; \
                        break; \
                        }
                        JP_PARSE_STRUCT_DATA_CASE('c', char, numberWithChar)
                        JP_PARSE_STRUCT_DATA_CASE('C', unsigned char, numberWithUnsignedChar)
                        JP_PARSE_STRUCT_DATA_CASE('s', short, numberWithShort)
                        JP_PARSE_STRUCT_DATA_CASE('S', unsigned short, numberWithUnsignedShort)
                        JP_PARSE_STRUCT_DATA_CASE('i', int, numberWithInt)
                        JP_PARSE_STRUCT_DATA_CASE('I', unsigned int, numberWithUnsignedInt)
                        JP_PARSE_STRUCT_DATA_CASE('l', long, numberWithLong)
                        JP_PARSE_STRUCT_DATA_CASE('L', unsigned long, numberWithUnsignedLong)
                        JP_PARSE_STRUCT_DATA_CASE('q', long long, numberWithLongLong)
                        JP_PARSE_STRUCT_DATA_CASE('Q', unsigned long long, numberWithUnsignedLongLong)
                        JP_PARSE_STRUCT_DATA_CASE('f', float, numberWithFloat)
                        JP_PARSE_STRUCT_DATA_CASE('d', double, numberWithDouble)
                        JP_PARSE_STRUCT_DATA_CASE('B', BOOL, numberWithBool)
                        JP_PARSE_STRUCT_DATA_CASE('N', NSInteger, numberWithInteger)
                        JP_PARSE_STRUCT_DATA_CASE('U', NSUInteger, numberWithUnsignedInteger)
                        
                    default:
                        break;
                }
                index ++;
            }
            return structDict;
        }
    }
    return nil;
}
