//
//  RCVideo.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/6/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class RCUser;

@interface RCVideo : NSManagedObject

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * thumbnailURL;
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * ffUrl;
@property (nonatomic, retain) RCUser *fromUser;
@property (nonatomic, retain) RCUser *toUser;
@property (nonatomic, retain) NSSet *users;
@end

@interface RCVideo (CoreDataGeneratedAccessors)

- (void)addUsersObject:(RCUser *)value;
- (void)removeUsersObject:(RCUser *)value;
- (void)addUsers:(NSSet *)values;
- (void)removeUsers:(NSSet *)values;

@end
