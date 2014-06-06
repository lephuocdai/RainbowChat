//
//  RCUser.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/6/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface RCUser : NSManagedObject

@property (nonatomic, retain) NSData * profilePicture;
@property (nonatomic, retain) id place;
@property (nonatomic, retain) NSString * nickname;
@property (nonatomic, retain) NSString * guid;
@property (nonatomic, retain) NSString * userName;
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * ffUrl;

@end
