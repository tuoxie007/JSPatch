//
//  JPBlockWrapper.m
//  JSPatch
//
//  Created by bang on 1/19/17.
//  Copyright © 2017 bang. All rights reserved.
//

#import "JPBlockWrapper.h"
#import "ffi.h"
#import "JPEngine.h"
#import "JPMethodSignature.h"
#import "JPCFunctionTest.h"

enum {
    BLOCK_DEALLOCATING =      (0x0001),
    BLOCK_REFCOUNT_MASK =     (0xfffe),
    BLOCK_NEEDS_FREE =        (1 << 24),
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26),
    BLOCK_IS_GC =             (1 << 27),
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_USE_STRET =         (1 << 29),
    BLOCK_HAS_SIGNATURE  =    (1 << 30)
};

struct JPSimulateBlock {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct JPSimulateBlockDescriptor *descriptor;
};

struct JPSimulateBlockDescriptor {
    //Block_descriptor_1
    struct {
        unsigned long int reserved;
        unsigned long int size;
    };
    
    /*
    //Block_descriptor_2
    //no need
    struct {
        // requires BLOCK_HAS_COPY_DISPOSE
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
    };
    */
    
    //Block_descriptor_3
    struct {
        // requires BLOCK_HAS_SIGNATURE
        const char *signature;
        const char *layout;
    };
};



@interface JPBlockWrapper ()
{
    ffi_cif *_cifPtr;
    ffi_type **_args;
    ffi_closure *_closure;
    BOOL _generatedPtr;
    void *_blockPtr;
    struct JPSimulateBlockDescriptor *_descriptor;
}

@property (nonatomic,strong) JPMethodSignature *signature;
@property (nonatomic,strong) JSValue *jsFunction;

@end

void JPBlockInterpreter(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    JPBlockWrapper *blockObj = (__bridge JPBlockWrapper*)userdata;
    
    NSMutableArray *params = [[NSMutableArray alloc] init];
    NSString *types = blockObj.signature.typeNames;
    NSMutableArray<NSString *> *funcArgTypes = [types componentsSeparatedByString:@","].mutableCopy;
    for (NSInteger i=0; i<funcArgTypes.count; i++) {
        funcArgTypes[i] = [funcArgTypes[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    for (int i = 1; i < funcArgTypes.count; i ++) {
        void *argumentPtr = args[i];
        NSString *type = funcArgTypes[i];
        id param = ConvertFFIValueToObjCValue(argumentPtr, type);
        [params addObject:[JPExtension formatOCToJS:param]];
    }
    
    JSValue *jsResult = [blockObj.jsFunction callWithArguments:params];
    NSString *retType = funcArgTypes[0];
    ConvertObjCValueToFFIValue(retType, jsResult, ret);
}

@implementation JPBlockWrapper

- (id)initWithTypeString:(NSString *)typeString callbackFunction:(JSValue *)jsFunction
{
    self = [super init];
    if(self) {
        _generatedPtr = NO;
        self.jsFunction = jsFunction;
        self.signature = [[JPMethodSignature alloc] initWithBlockTypeNames:typeString];
    }
    return self;
}

- (void *)blockPtr
{
    if (_generatedPtr) {
        return _blockPtr;
    }

    _generatedPtr = YES;

    NSString *types = self.signature.typeNames;
    NSMutableArray<NSString *> *funcArgTypes = [types componentsSeparatedByString:@","].mutableCopy;
    for (NSInteger i=0; i<funcArgTypes.count; i++) {
        funcArgTypes[i] = [funcArgTypes[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    NSString *returnType = funcArgTypes[0];

    ffi_type *returnFfiType = malloc(sizeof(ffi_type *));
    ConvertObjCTypeToFFIType(returnType, &returnFfiType);

    funcArgTypes[0] = @"block";

    NSUInteger argumentCount = funcArgTypes.count;

    _cifPtr = malloc(sizeof(ffi_cif));

    void *blockImp = NULL;

    _args = malloc(sizeof(ffi_type *) *argumentCount) ;

    for (int i = 0; i < argumentCount; i++){
        ffi_type* current_ffi_type = malloc(sizeof(ffi_type *));
        ConvertObjCTypeToFFIType(funcArgTypes[i], &current_ffi_type);
        _args[i] = current_ffi_type;
    }

    _closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&blockImp);

    if(ffi_prep_cif(_cifPtr, FFI_DEFAULT_ABI, (unsigned int)argumentCount, returnFfiType, _args) == FFI_OK) {
        if (ffi_prep_closure_loc(_closure, _cifPtr, JPBlockInterpreter, (__bridge void *)self, blockImp) != FFI_OK) {
            NSAssert(NO, @"generate block error");
        }
    }
    
    struct JPSimulateBlockDescriptor descriptor = {
        0,
        sizeof(struct JPSimulateBlock),
        [self.signature.types cStringUsingEncoding:NSUTF8StringEncoding],
        NULL
    };
    
    _descriptor = malloc(sizeof(struct JPSimulateBlockDescriptor));
    memcpy(_descriptor, &descriptor, sizeof(struct JPSimulateBlockDescriptor));
    
    struct JPSimulateBlock simulateBlock = {
        &_NSConcreteStackBlock,
        (BLOCK_HAS_SIGNATURE), 0,
        blockImp,
        _descriptor
    };
    
    _blockPtr = malloc(sizeof(struct JPSimulateBlock));
    memcpy(_blockPtr, &simulateBlock, sizeof(struct JPSimulateBlock));
    
    return _blockPtr;
}

- (void)dealloc
{
    ffi_closure_free(_closure);
    free(_args);
    free(_cifPtr);
    free(_blockPtr);
    free(_descriptor);
    return;
}

@end
