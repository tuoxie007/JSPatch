//
//  JPCFunctionTest.h
//  JSPatchDemo
//
//  Created by bang on 6/1/16.
//  Copyright © 2016 bang. All rights reserved.
//

#import <Foundation/Foundation.h>

struct JPStructPadding {
    char ch;
    int num;
};

typedef struct JPStructPadding JPStructPadding;

struct JPStructPacking {
    char ch;
    int num;
} __attribute__((packed));

typedef struct JPStructPacking JPStructPacking;

id cfuncWithStructPacking(NSString *str, JPStructPacking strt);

@interface JPCFunctionTest : NSObject
+ (BOOL)testCfuncWithId;
+ (BOOL)testCfuncWithInt;
+ (BOOL)testCfuncWithCGFloat;
+ (BOOL)testCfuncReturnPointer;
+ (BOOL)testCFunctionReturnClass;
+ (BOOL)testCFunctionVoid;
@end
