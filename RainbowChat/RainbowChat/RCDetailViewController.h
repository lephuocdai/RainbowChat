//
//  RCDetailViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RCUser.h"
#import <AVFoundation/AVFoundation.h>

@interface RCDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

#warning Need to change the type of this class
@property (strong, nonatomic) RCUser *toUser;

@end
