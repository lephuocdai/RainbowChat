//
//  RCLoginViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RCLoginViewController;


@protocol RCLoginViewControllerDelegate <NSObject>

- (void)loginViewControllerDidLoginUser;

@end


@interface RCLoginViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, assign) id <RCLoginViewControllerDelegate> delegate;

@end

