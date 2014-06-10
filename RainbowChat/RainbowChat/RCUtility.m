//
//  RCUtility.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/13/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCUtility.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AWSS3.h>
#import "AmazonClientManager.h"

@implementation RCUtility

+ (void)putNewVideoWithData:(NSData*)recordedVideoData fileName:(NSString*)uploadFileName toBucket:(NSString*)bucket delegate:(id)delegate {
    DBGMSG(@"%s - %@", __func__, uploadFileName);
    S3PutObjectRequest *putObjectRequest = [[S3PutObjectRequest alloc] initWithKey:uploadFileName inBucket:bucket];
    putObjectRequest.data = recordedVideoData;
    putObjectRequest.delegate = delegate;
    
    S3PutObjectResponse *response = [[AmazonClientManager s3] putObject:putObjectRequest];
    if (response.error != nil) {
        DBGMSG(@"%s error = %@", __func__, response.error.description);
    }
}

+ (NSString*)usernameFromEmail:(NSString*)email {
    NSArray *emailComponents = [email componentsSeparatedByString:@"@"];
    return [NSString stringWithFormat:@"rbc_%@_at_%@", [emailComponents firstObject], [emailComponents lastObject]];
}

@end
