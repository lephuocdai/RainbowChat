//
//  RCUtility.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/13/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RCUtility : NSObject

+ (void)putNewVideoWithData:(NSData*)recordedVideoData fileName:(NSString*)uploadFileName toBucket:(NSString*)bucket delegate:(id)delegate;


@end
