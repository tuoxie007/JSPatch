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

void ConvertObjCValueToFFIValue(NSString *objcType, id objcVal, void **ffiVal)
{
    if ([objcType isEqualToString:@"int"]) {
        int val = [((NSNumber *)objcVal) intValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"uint"]) {
        unsigned int val = [((NSNumber *)objcVal) unsignedIntValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"long"]) {
        long val = [((NSNumber *)objcVal) longValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"ulong"]) {
        unsigned long val = [((NSNumber *)objcVal) unsignedLongValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"float"]) {
        float val = [((NSNumber *)objcVal) floatValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"double"]) {
        double val = [((NSNumber *)objcVal) doubleValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"char"]) {
        char val = [((NSNumber *)objcVal) charValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"uchar"]) {
        unsigned char val = [((NSNumber *)objcVal) unsignedCharValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"short"]) {
        short val = [((NSNumber *)objcVal) shortValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"ushort"]) {
        unsigned short val = [((NSNumber *)objcVal) unsignedShortValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"long long"]) {
        long long val = [((NSNumber *)objcVal) longLongValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"unsigned long long"]) {
        unsigned long long val = [((NSNumber *)objcVal) unsignedLongLongValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"CGFloat"]) {
        if (CGFLOAT_IS_DOUBLE) {
            CGFloat val = [((NSNumber *)objcVal) doubleValue];
            *ffiVal = &val;
        } else {
            CGFloat val = [((NSNumber *)objcVal) floatValue];
            *ffiVal = &val;
        }
    } else if ([objcType isEqualToString:@"NSInteger"]) {
        NSInteger val = [((NSNumber *)objcVal) integerValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"NSUInteger"]) {
        NSUInteger val = [((NSNumber *)objcVal) unsignedIntegerValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"BOOL"]) {
        BOOL val = [((NSNumber *)objcVal) boolValue];
        *ffiVal = &val;
    } else if ([objcType isEqualToString:@"id"]) {
        void **ptr = *ffiVal;
        *ptr = (__bridge void *)(objcVal);
    } else if ([objcType hasSuffix:@"*"]) {
        void **ptr = *ffiVal;
        *ptr = (__bridge void *)(objcVal);
    } else if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        NSDictionary *registedStruct = [JPExtension registeredStruct];
        NSString *structName = [objcType substringWithRange:NSMakeRange(1, objcType.length - 2)];
        NSDictionary *structDefine = registedStruct[structName];
        size_t size = [JPExtension sizeOfStructDefine:structDefine];
        *ffiVal = malloc(size);
        [JPExtension getStructDataWidthDict:*ffiVal dict:objcVal structDefine:structDefine];
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
    } else if ([objcType isEqualToString:@"id"]) {
        return (__bridge id)(*(void **)ffiVal);
    } else if ([objcType hasSuffix:@"*"]) {
        return (__bridge id)(*(void **)ffiVal);
    } else if ([objcType hasPrefix:@"{"] && [objcType hasSuffix:@"}"]) {
        JPBoxing *box = [[JPBoxing alloc] init];
        box.pointer = (*(void **)ffiVal);
        return box;
    }
    return nil;
}
