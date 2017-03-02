//
//  JPCFunction.m
//  JSPatch
//
//  Created by bang on 5/30/16.
//  Copyright © 2016 bang. All rights reserved.
//

#import "JPCFunction.h"
#import "ffi.h"
#import <dlfcn.h>
#import "JPMethodSignature.h"
#import "JPEngine.h"

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

@implementation JPCFunction

static NSMutableDictionary *_funcDefines;

+ (void)main:(JSContext *)context
{
    if (!_funcDefines) {
        _funcDefines = [[NSMutableDictionary alloc] init];
    }
    
    [context evaluateScript:@"  \
     global.defineCFunction = function(funcName, paramsStr) {   \
         _OC_defineCFunction(funcName, paramsStr);   \
         global[funcName] = function() {    \
             var args = Array.prototype.slice.call(arguments);   \
             return _OC_callCFunc.apply(global, [funcName, args]);   \
         }  \
     }  \
     "];
    
    context[@"_OC_defineCFunction"] = ^void(NSString *funcName, NSString *types) {
        [self defineCFunction:funcName types:types];
    };
    
    context[@"_OC_callCFunc"] = ^id(NSString *funcName, JSValue *args) {
        id ret = [self callCFunction:funcName arguments:[self formatJSToOC:args]];
        return [self formatOCToJS:ret];
    };
}

+ (void)defineCFunction:(NSString *)funcName types:(NSString *)types
{
    NSMutableArray<NSString *> *funcArgTypes = [types componentsSeparatedByString:@","].mutableCopy;
    for (NSInteger i=0; i<funcArgTypes.count; i++) {
        funcArgTypes[i] = [funcArgTypes[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    [_funcDefines setObject:funcArgTypes forKey:funcName];
}

+ (id)callCFunction:(NSString *)funcName arguments:(NSArray *)arguments
{
    void* functionPtr = dlsym(RTLD_DEFAULT, [funcName UTF8String]);
    if (!functionPtr) {
        return nil;
    }
    
    NSMutableArray *argumentTypes = [_funcDefines objectForKey:funcName];
    NSString *returnType = argumentTypes.firstObject;
    [argumentTypes removeObjectAtIndex:0];
    const NSUInteger argCount = argumentTypes.count;
    if (argCount != [arguments count]) {
        return nil;
    }
    
    ffi_type *ffiArgTypes[argCount + 1];
    void *ffiArgs[argCount];
    for (int i = 0; i < argCount; i ++) {
        // convert type
        NSString *argType = argumentTypes[i];
        ffi_type *ffiType = malloc(sizeof(ffi_type *));
        ConvertObjCTypeToFFIType(argType, &ffiType);
        ffiArgTypes[i] = ffiType;
        
        size_t typeSize = ffiType->size;
        if (typeSize == 0 && ffiType->elements != NULL) {
            int idx = 0;
            while (ffiType->elements[idx] != NULL) {
                typeSize += ffiType->elements[idx]->size;
                idx ++;
            }
        }
        
        // convert value
        void *ffiArgPtr = alloca(typeSize);
        ConvertObjCValueToFFIValue(argType, arguments[i], &ffiArgPtr);
        ffiArgs[i] = ffiArgPtr;
    }
    ffiArgTypes[argCount] = NULL;
//    return nil;
    
    ffi_cif cif;
    ffi_type *returnFfiType;
    ConvertObjCTypeToFFIType(returnType, &returnFfiType);
    ffi_status ffiPrepStatus = ffi_prep_cif_var(&cif, FFI_DEFAULT_ABI, (unsigned int)0, (unsigned int)argCount, returnFfiType, ffiArgTypes);

    if (ffiPrepStatus == FFI_OK) {
        void *returnPtr = NULL;
        if (returnFfiType->size) {
            returnPtr = alloca(returnFfiType->size);
        }
        ffi_call(&cif, functionPtr, returnPtr, ffiArgs);
        
        // release memory in struct type
        for (int i = 0; i < argCount; i ++) {
            ffi_type *ffiType = ffiArgTypes[i];
            if (ffiType->elements != NULL) {
                free(ffiType->elements);
            }
        }
        
        id ret = ConvertFFIValueToObjCValue(returnPtr, returnType);
        
        // release memory in struct type
        if (returnFfiType->elements != NULL) {
            free(returnFfiType->elements);
            free(returnFfiType);
        }
        
        return ret;
    }
    
    return nil;
}

@end
