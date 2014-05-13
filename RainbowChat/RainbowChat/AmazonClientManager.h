//
//  AmazonClientManager.h
//  Presentice
//
//  Created by レー フックダイ on 2/19/14.
//  Copyright (c) 2014 Presentice. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AWSS3/AWSS3.h>
#import <AWSRuntime/AWSRuntime.h>

#import "AmazonKeyChainWrapper.h"
#import "AmazonTVMClient.h"
#import "RCConstant.h"
#import "Response.h"

@interface AmazonClientManager : NSObject {
    
}

+(AmazonS3Client *)s3;
+(bool)hasCredentials;
+(Response *)validateCredentials;
+(void)wipeAllCredentials;
+ (BOOL)wipeCredentialsOnAuthError:(NSError *)error;

@end
