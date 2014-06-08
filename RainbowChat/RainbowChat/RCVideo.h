//
//  RCVideo.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/8/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class RCUser;

@interface RCVideo : NSManagedObject

@property (nonatomic) NSTimeInterval createdAt;
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * ffUrl;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * thumbnailURL;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) RCUser *fromUser;
@property (nonatomic, retain) RCUser *toUser;

@end
