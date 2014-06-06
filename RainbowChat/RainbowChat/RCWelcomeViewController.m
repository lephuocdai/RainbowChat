//
//  RCWelcomeViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCWelcomeViewController.h"

@interface RCWelcomeViewController ()

@end

@implementation RCWelcomeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"LoginViewController.ffInstance = %@", self.ffInstance);
    NSLog(@"[FatFractal main] = %@", [FatFractal main]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SignupViewController delegate
- (void)signupViewControllerDidSignupUser {
    DBGMSG(@"%s", __func__);
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [self userSuccessfullyAuthenticated];
}


#pragma mark - LoginViewController delegate
- (void)loginViewControllerDidLoginUser {
    DBGMSG(@"%s", __func__);
    // Dismiss WelcomeViewController
    [self dismissViewControllerAnimated:NO completion:nil];
    
    // Announce user has successfully authenticated
    [self userSuccessfullyAuthenticated];
}


#pragma mark - Helper
- (void)userSuccessfullyAuthenticated {
    DBGMSG(@"%s", __func__);
    if ([self.delegate respondsToSelector:@selector(userDidAuthenticate)]) {
        [self.delegate userDidAuthenticate];
    }
}


#pragma mark - Navigation
- (IBAction)signupButtonPressed:(id)sender {
    DBGMSG(@"%s", __func__);
}

- (IBAction)loginButtonPressed:(id)sender {
    DBGMSG(@"%s", __func__);
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DBGMSG(@"%s", __func__);
    if ([[segue identifier] isEqualToString:@"presentSignupView"]) {
        RCSignupViewController *signupVC = [segue destinationViewController];
        signupVC.delegate = self;
        signupVC.ffInstance = self.ffInstance;
    } else if ([[segue identifier] isEqualToString:@"presentLoginView"]) {
        RCLoginViewController *loginVC = [segue destinationViewController];
        loginVC.delegate = self;
        loginVC.ffInstance = self.ffInstance;
    }
}


@end
