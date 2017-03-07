//
//  JPCFunctionTest.m
//  JSPatchDemo
//
//  Created by bang on 6/1/16.
//  Copyright © 2016 bang. All rights reserved.
//

#import "JPCFunctionTest.h"
#import <UIKit/UIKit.h>
#import "JPEngine.h"

static bool voidFuncRet = false;

id cfuncWithStructPadding(NSString *str, JPStructPadding strt){
    return [NSString stringWithFormat:@"%@, %c, %d", str, strt.ch, strt.num];
}

JPStructPadding cfuncReturnStructPadding(){
    JPStructPadding ret;
    ret.ch = 'X';
    ret.num = 233;
    return ret;
}

id cfuncWithStructPacking(NSString *str, JPStructPacking strt){
    NSLog(@"JPStructPacking: %c, %d", strt.ch, strt.num);
    return str;
}

id cfuncWithStruct(NSString *str, UIEdgeInsets insets){
    NSLog(@"UIEdgeInsets: %g, %g, %g, %g", insets.top, insets.bottom, insets.left, insets.right);
    return str;
}

id cfuncWithId(NSString *str){
    return str;
}

int cfuncWithInt(int num) {
    return num;
}

CGFloat cfuncWithCGFloat(CGFloat num) {
    return num;
}

void *cfuncReturnPointer() {
    char *a = "abc";
    return a;
}

bool cfuncWithPointerIsEqual(char *a) {
    return a[0] == 'a';
}
void cfuncVoid() {
    NSLog(@"dsssdfsdf");
}

@implementation JPCFunctionTest
+ (BOOL)testCfuncReturnStructPadding{
    return NO;
};
+ (BOOL)testCfuncWithStructPadding{
    return NO;
};
+ (BOOL)testCfuncWithId{
    return NO;
};
+ (BOOL)testCfuncWithInt{
    return NO;
};
+ (BOOL)testCfuncWithCGFloat{
    return NO;
};
+ (BOOL)testCfuncReturnPointer{
    return NO;
};
+ (BOOL)testCFunctionReturnClass{
    return NO;
};
+ (BOOL)testCFunctionVoid{
    return voidFuncRet;
};
+ (void)setupCFunctionVoidSucc{
    voidFuncRet = true;
}
@end
