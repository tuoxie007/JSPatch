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
