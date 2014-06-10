//
//  RCVideo.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/10/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class RCUser;

@interface RCVideo : NSObject

@property (strong, nonatomic) NSString *url;
@property (strong, nonatomic) NSString *thumbnailURL;
@property (strong, nonatomic) NSData *data;
@property (strong, nonatomic) RCUser *fromUser;
@property (strong, nonatomic) RCUser *toUser;
@property (strong, nonatomic) NSArray *users;

//@property (nonatomic) NSDate *createdAt;
//@property (nonatomic, retain) NSData * data;
//@property (nonatomic, retain) NSString * ffUrl;
//@property (nonatomic, retain) NSString * name;
//@property (nonatomic, retain) NSString * thumbnailURL;
//@property (nonatomic, retain) NSString * url;
//@property (nonatomic, retain) RCUser *fromUser;
//@property (nonatomic, retain) RCUser *toUser;

@end
