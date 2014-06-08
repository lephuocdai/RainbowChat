//
//  RCSignupViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RCFatFractal.h"

@class RCSignupViewController;


@protocol RCSignupViewControllerDelegate <NSObject>

- (void)signupViewControllerDidSignupUser;

@end


@interface RCSignupViewController : UIViewController

@property (nonatomic, assign) id <RCSignupViewControllerDelegate> delegate;
//@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) RCFatFractal *ffInstance;

@end
