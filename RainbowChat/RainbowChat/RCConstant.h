//
//  RCConstant.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/13/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CREDENTIALS_ERROR_TITLE    @"Missing Credentials"
#define CREDENTIALS_ERROR_MESSAGE  @"AWS Credentials not configured correctly.  Please review the README file."


@interface RCConstant : NSObject

/*
 * Creating bucket
 */
+ (NSString *)transferManagerBucket;
+ (NSString *)TVM_URL;
+ (BOOL) USE_SSL;

+ (NSString *)getConstantbyClass:(NSString *)className forType:(NSString *)typeName withName:(NSString *)name;

@end
