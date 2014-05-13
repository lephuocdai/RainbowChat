//
//  RCVideo.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/13/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FFEF/FatFractal.h>
#import "RCUser.h"

@interface RCVideo : NSObject

@property (strong, nonatomic) NSString *url;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) RCUser *fromUser;
@property (strong, nonatomic) RCUser *toUser;
@property (strong, nonatomic) NSArray *users;

@end
