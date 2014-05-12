//
//  RCUser.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/12/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <FFEF/FatFractal.h>

@interface RCUser : FFUser

@property (strong, nonatomic) NSData *profilePicture;
@property (strong, nonatomic) FFGeoLocation *place;
@property (strong, nonatomic) NSString *nickname;

@end
