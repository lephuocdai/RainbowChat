//
//  RCMasterViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
//#import "RCFatFractal.h"
#import "RCWelcomeViewController.h"
#import <Quickblox/Quickblox.h>

#warning - We do not need a fetchedResultsController since we have the managedObjectContext
@interface RCMasterViewController : UITableViewController <WelcomeViewControllerDelegate, UIAlertViewDelegate>

-(void)userIsAuthenticatedFromAppDelegateOnLaunch;
-(void)userAuthenticationFailedFromAppDelegateOnLaunch;
-(void)didReceiveNotificationFromAppDelegateOnLaunch:(NSDictionary*)userInfo;

@end
