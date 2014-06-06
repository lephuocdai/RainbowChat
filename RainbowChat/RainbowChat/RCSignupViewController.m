//
//  RCSignupViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCSignupViewController.h"
#import "MBProgressHUD.h"
#import "KeychainItemWrapper.h"
#import "RCAppDelegate.h"
#import "RCUser.h"

@interface RCSignupViewController ()

@property (strong, nonatomic) IBOutlet UITextField *fullnameTextField;
@property (strong, nonatomic) IBOutlet UITextField *emailTextField;
@property (strong, nonatomic) IBOutlet UITextField *passwordTextField;
@property (strong, nonatomic) IBOutlet UITextField *passwordAgainTextField;

@end


@implementation RCSignupViewController

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
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextField delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - NavigationX
- (IBAction)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onSignup:(id)sender {
    
    // Get text string from input text field
    NSString *fullname = _fullnameTextField.text;
    NSString *email = _emailTextField.text;
    NSString *password = _passwordTextField.text;
    NSString *passwordAgain = _passwordAgainTextField.text;
    
    // Check input email and password
    if (![self isPassword:password validWithPasswordAgain:passwordAgain]) {
        [self callAlertPasswordInvalid];
        return;
    }
    if (![self isEmailValid:email]) {
        [self callAlertEmailInvalid];
        return;
    }
    
    
    FFGeoLocation *place = [[FFGeoLocation alloc] initWithLatitude:33.5 longitude:-112];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = @"Signing up...";
    hud.dimBackground = YES;
    hud.yOffset = -77;
    
    [self.ffInstance registerClass:[RCUser class] forClazz:@"FFUser"];
    
    // Create new FFUser and registerUser then save to keychain if successful
    RCUser *newUser = [[RCUser alloc] init];
    newUser.firstName = fullname;
    newUser.userName = [self usernameFromEmail:email];
    newUser.email = email;
    newUser.place = place;
    newUser.nickname = fullname;
    
    [self.ffInstance registerUser:newUser password:password onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theErr) {
            [self callAlertError:theErr];
            return;
        } else {
            if (theObj) {
                [self saveUserCredentialsInKeyChain];
                
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                
                [self dismissViewControllerAnimated:YES completion:^{
                    [self handleSuccessfulSignup];
                }];
            }
        }
    }];
}


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

#pragma mark - Helper
-(void)saveUserCredentialsInKeyChain {
    NSString *username = [self usernameFromEmail:_emailTextField.text];;
    NSString *password = _passwordAgainTextField.text;
    
    KeychainItemWrapper *keychainItem = [RCAppDelegate keychainItem];
    [keychainItem setObject:username forKey:(__bridge id)(kSecAttrAccount)];
    [keychainItem setObject:password forKey:(__bridge id)(kSecValueData)];
    
    NSLog(@"Successfully saved user %@ to keychain after signup in SignupViewController.", [keychainItem objectForKey:(__bridge id)(kSecAttrAccount)]);
}

- (void)checkEmail:(NSString*)email {
    
}

- (void)callAlertEmailInvalid {
    
}

- (void)callAlertPasswordInvalid {
    
}

- (void)callAlertError:(NSError*)error {
    
}

- (NSString*)usernameFromEmail:(NSString*)email {
#warning Need to implement
    return email;
}

- (BOOL)isEmailValid:(NSString*)email {
#warning Need to implement
    return YES;
}

- (BOOL)isPassword:(NSString*)password validWithPasswordAgain:(NSString*)passwordAgain {
#warning Need to implement
    return YES;
}

- (void)handleSuccessfulSignup {
    if ([self.delegate respondsToSelector:@selector(signupViewControllerDidSignupUser)]) {
        [self.delegate signupViewControllerDidSignupUser];
    }
}

@end
