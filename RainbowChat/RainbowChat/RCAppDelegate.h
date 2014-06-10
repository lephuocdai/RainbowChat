//
//  RCAppDelegate.h
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KeychainItemWrapper.h"
//#import "RCFatFractal.h"
#import <Quickblox/Quickblox.h>

@interface RCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

// The static method for the KeychainItemWrapper class
+ (KeychainItemWrapper *)keychainItem;
//+ (RCFatFractal *)ffInstance;
+ (FatFractal*)ffInstance;
+ (BOOL)checkForAuthentication;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
