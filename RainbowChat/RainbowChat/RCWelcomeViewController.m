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
    
//    [self deleteAllObjects:@"RCUser"];
    
    NSLog(@"WelcomeViewController.ffInstance = %@", self.ffInstance);
    NSLog(@"[FatFractal main] = %@", [FatFractal main]);
    [QBAuth createSessionWithDelegate:self];
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
        signupVC.managedObjectContext = self.managedObjectContext;
        signupVC.ffInstance = self.ffInstance;
    } else if ([[segue identifier] isEqualToString:@"presentLoginView"]) {
        RCLoginViewController *loginVC = [segue destinationViewController];
        loginVC.delegate = self;
        loginVC.managedObjectContext = self.managedObjectContext;
        loginVC.ffInstance = self.ffInstance;
    }
}

#pragma mark - Core Data
- (void) deleteAllObjects: (NSString *) entityDescription  {
    DBGMSG(@"%s", __func__);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityDescription inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSError *error;
    NSArray *items = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    for (NSManagedObject *managedObject in items) {
    	[self.managedObjectContext deleteObject:managedObject];
    	NSLog(@"%@ object deleted",entityDescription);
    }
    if (![self.managedObjectContext save:&error]) {
    	NSLog(@"Error deleting %@ - error:%@",entityDescription,error);
    }
}


@end
