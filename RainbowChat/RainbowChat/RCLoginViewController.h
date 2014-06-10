//
//  RCLoginViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Quickblox/Quickblox.h>
//#import "RCFatFractal.h"

@class RCLoginViewController;


@protocol RCLoginViewControllerDelegate <NSObject>

- (void)loginViewControllerDidLoginUser;

@end


@interface RCLoginViewController : UIViewController <UITextFieldDelegate, QBActionStatusDelegate, QBChatDelegate>

@property (nonatomic, assign) id <RCLoginViewControllerDelegate> delegate;
//@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
//@property (strong, nonatomic) FatFractal *ffInstance;

@end

