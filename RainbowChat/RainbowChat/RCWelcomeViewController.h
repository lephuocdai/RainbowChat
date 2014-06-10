//
//  RCWelcomeViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RCSignupViewController.h"
#import "RCLoginViewController.h"

@class RCWelComeViewController;

@protocol WelcomeViewControllerDelegate <NSObject>

- (void)userDidAuthenticate;

@end


@interface RCWelcomeViewController : UIViewController <RCSignupViewControllerDelegate, RCLoginViewControllerDelegate>

@property (nonatomic, assign) id <WelcomeViewControllerDelegate> delegate;

//@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;



@end
