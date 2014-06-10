//
//  RCUser.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/10/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface RCUser : FFUser

@property (strong, nonatomic) NSData *profilePicture;
@property (strong, nonatomic) FFGeoLocation *place;
@property (strong, nonatomic) NSString *nickname;
@property (strong, nonatomic) NSString * quickbloxID;
//@property (nonatomic, retain) NSString * email;
//@property (nonatomic, retain) NSString * ffUrl;
//@property (nonatomic, retain) NSString * firstName;
//@property (nonatomic, retain) NSString * guid;
//@property (nonatomic, retain) NSString * lastName;
//@property (nonatomic, retain) NSString * nickname;
//@property (nonatomic, retain) id place;
//@property (nonatomic, retain) NSData * profilePicture;
//@property (nonatomic, retain) NSString * quickbloxID;
//@property (nonatomic, retain) NSString * userName;

@end
