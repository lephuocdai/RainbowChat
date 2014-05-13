//
//  AmazonClientManager.m
//  Presentice
//
//  Created by レー フックダイ on 2/19/14.
//  Copyright (c) 2014 Presentice. All rights reserved.
//

#import "AmazonClientManager.h"

static AmazonS3Client *s3  = nil;
static AmazonTVMClient      *tvm = nil;

@implementation AmazonClientManager

+(AmazonS3Client *)s3 {
    [AmazonClientManager validateCredentials];
    return s3;
}

+(AmazonTVMClient *)tvm {
    if (tvm == nil)
        tvm = [[AmazonTVMClient alloc] initWithEndpoint:[RCConstant TVM_URL] useSSL:[RCConstant USE_SSL]];
    return tvm;
}

+(bool)hasCredentials {
    return ![[RCConstant TVM_URL] isEqualToString:@"CHANGE ME"];
}

+(Response *)validateCredentials {
    Response *ableToGetToken = [[Response alloc] initWithCode:200 andMessage:@"OK"];
    
    if ([AmazonKeyChainWrapper areCredentialsExpired]) {
        @synchronized(self) {
            if ([AmazonKeyChainWrapper areCredentialsExpired]) {
                
                ableToGetToken = [[AmazonClientManager tvm] anonymousRegister];
                
                if ( [ableToGetToken wasSuccessful]) {
                    ableToGetToken = [[AmazonClientManager tvm] getToken];
                    
                    if ( [ableToGetToken wasSuccessful]) {
                        [AmazonClientManager initClients];
                    }
                }
            }
        }
    } else if (s3 == nil) {
        @synchronized(self) {
            if (s3 == nil) {
                [AmazonClientManager initClients];
            }
        }
    }
    return ableToGetToken;
}

+(void)initClients {
    AmazonCredentials *credentials = [AmazonKeyChainWrapper getCredentialsFromKeyChain];
    s3  = [[AmazonS3Client alloc] initWithCredentials:credentials];
    s3.endpoint = [AmazonEndpoints s3Endpoint:AP_NORTHEAST_1];
}

+(void)wipeAllCredentials {
    @synchronized(self) {
        [AmazonKeyChainWrapper wipeCredentialsFromKeyChain];
        s3  = nil;
    }
}

+ (BOOL)wipeCredentialsOnAuthError:(NSError *)error {
    id exception = [error.userInfo objectForKey:@"exception"];
    
    if([exception isKindOfClass:[AmazonServiceException class]]) {
        AmazonServiceException *e = (AmazonServiceException *)exception;
        
        if(
           // STS http://docs.amazonwebservices.com/STS/latest/APIReference/CommonErrors.html
           [e.errorCode isEqualToString:@"IncompleteSignature"]
           || [e.errorCode isEqualToString:@"InternalFailure"]
           || [e.errorCode isEqualToString:@"InvalidClientTokenId"]
           || [e.errorCode isEqualToString:@"OptInRequired"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           || [e.errorCode isEqualToString:@"ServiceUnavailable"]
           
           // For S3 http://docs.amazonwebservices.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList
           || [e.errorCode isEqualToString:@"AccessDenied"]
           || [e.errorCode isEqualToString:@"BadDigest"]
           || [e.errorCode isEqualToString:@"CredentialsNotSupported"]
           || [e.errorCode isEqualToString:@"ExpiredToken"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"InvalidAccessKeyId"]
           || [e.errorCode isEqualToString:@"InvalidPolicyDocument"]
           || [e.errorCode isEqualToString:@"InvalidToken"]
           || [e.errorCode isEqualToString:@"NotSignedUp"]
           || [e.errorCode isEqualToString:@"RequestTimeTooSkewed"]
           || [e.errorCode isEqualToString:@"SignatureDoesNotMatch"]
           || [e.errorCode isEqualToString:@"TokenRefreshRequired"]
           
           // SimpleDB http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/APIError.html
           || [e.errorCode isEqualToString:@"AccessFailure"]
           || [e.errorCode isEqualToString:@"AuthFailure"]
           || [e.errorCode isEqualToString:@"AuthMissingFailure"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           
           // SNS http://docs.amazonwebservices.com/sns/latest/api/CommonErrors.html
           || [e.errorCode isEqualToString:@"IncompleteSignature"]
           || [e.errorCode isEqualToString:@"InternalFailure"]
           || [e.errorCode isEqualToString:@"InvalidClientTokenId"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           
           // SQS http://docs.amazonwebservices.com/AWSSimpleQueueService/2011-10-01/APIReference/Query_QueryErrors.html#list-of-errors
           || [e.errorCode isEqualToString:@"AccessDenied"]
           || [e.errorCode isEqualToString:@"AuthFailure"]
           || [e.errorCode isEqualToString:@"AWS.SimpleQueueService.InternalError"]
           || [e.errorCode isEqualToString:@"InternalError"]
           || [e.errorCode isEqualToString:@"InvalidAccessKeyId"]
           || [e.errorCode isEqualToString:@"InvalidSecurity"]
           || [e.errorCode isEqualToString:@"InvalidSecurityToken"]
           || [e.errorCode isEqualToString:@"MissingClientTokenId"]
           || [e.errorCode isEqualToString:@"MissingCredentials"]
           || [e.errorCode isEqualToString:@"NotAuthorizedToUseVersion"]
           || [e.errorCode isEqualToString:@"RequestExpired"]
           || [e.errorCode isEqualToString:@"X509ParseError"]
           )
        {
            [AmazonClientManager wipeAllCredentials];
            
            return YES;
        }
    }
    
    return NO;
}

@end
