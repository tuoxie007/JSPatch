//
//  JPMethodSignature.h
//  JSPatch
//
//  Created by bang on 1/19/17.
//  Copyright © 2017 bang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ffi.h"

@interface JPMethodSignature : NSObject

@property (nonatomic, readonly) NSString *typeNames;
@property (nonatomic, readonly) NSString *types;
@property (nonatomic, readonly) NSArray *argumentTypes;
@property (nonatomic, readonly) NSString *returnType;

- (instancetype)initWithObjCTypes:(NSString *)objCTypes;
- (instancetype)initWithBlockTypeNames:(NSString *)typeNames;

+ (void)ffiTypeWithObjcType:(NSString *)objcType ffiType:(ffi_type **)ffiType;
+ (ffi_type *)ffiTypeWithEncodingChar:(const char *)c;
+ (NSString *)typeEncodeWithTypeName:(NSString *)typeName;

@end

extern void ConvertObjCTypeToFFIType(NSString *objcType, ffi_type **ffiType);
extern void ConvertObjCValueToFFIValue(NSString *objcType, id objcVal, void **ffiVal);
extern id ConvertFFIValueToObjCValue(void *ffiVal, NSString *objcType);

