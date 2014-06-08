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


#define loginContext @"loginContext"
#define registrationContext @"registrationContext"


@interface RCSignupViewController ()  <UITextFieldDelegate, QBActionStatusDelegate>

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
    DBGMSG(@"%s", __func__);
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
    
    // Create new RCUser and registerUser then save to keychain if successful
    RCUser *newUser = (RCUser*)[NSEntityDescription insertNewObjectForEntityForName:@"RCUser" inManagedObjectContext:self.managedObjectContext];
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
                
                QBUUser *qbuser = [QBUUser user];
                qbuser.login = [NSString stringWithFormat:@"rbc_%@", [[newUser.userName componentsSeparatedByString:@"@"] firstObject]];
                qbuser.password = password;
                qbuser.fullName = fullname;
                qbuser.email = email;
                [QBUsers signUp:qbuser delegate:self context:registrationContext];
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

#pragma mark - QBActionStatusDelegate

// QuickBlox API queries delegate
-(void)completedWithResult:(Result*)result context:(void *)contextInfo{
     DBGMSG(@"%s - result = %@", __func__, result);
    // QuickBlox User creation result
    if([result isKindOfClass:[QBUUserResult class]]){
        
        // Success result
		if(result.success){
            
            [self saveUserCredentialsInKeyChain];
            
            NSError *cdError;
            [self.managedObjectContext save:&cdError];
            if (cdError) {
                NSLog(@"Saved managedObjectContext - error was %@", [cdError localizedDescription]);
            }
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
            [self dismissViewControllerAnimated:YES completion:^{
                [self handleSuccessfulSignup];
            }];
            
        /*
            if([((__bridge NSString *)contextInfo) isEqualToString:loginContext]){
                
                // Save current user
                //
                QBUUserLogInResult *res = (QBUUserLogInResult *)result;
                res.user.password = self.passwordTextField.text;
                [[LocalStorageService shared] setCurrentUser: res.user];
                
                
                // Login to Chat
                //
                [[ChatService instance] loginWithUser:[LocalStorageService shared].currentUser completionBlock:^{
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You have successfully logged in"
                                                                    message:nil
                                                                   delegate:nil
                                                          cancelButtonTitle:@"Ok"
                                                          otherButtonTitles: nil];
                    [alert show];
                    //
                    // hide alert after delay
                    double delayInSeconds = 2.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        [alert dismissWithClickedButtonIndex:0 animated:YES];
                    });
                    
                    [self dismissViewControllerAnimated:YES completion:nil];
                }];
                
            }else{
                // Login to QuickBlox
                //
                [QBUsers logInWithUserLogin:self.loginTextField.text
                                   password:self.passwordTextField.text
                                   delegate:self context:loginContext];
            }
        */
        // Errors
        }else {
            NSString *errorMessage = [[result.errors description] stringByReplacingOccurrencesOfString:@"(" withString:@""];
            errorMessage = [errorMessage stringByReplacingOccurrencesOfString:@")" withString:@""];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Errors"
                                                            message:errorMessage
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil, nil];
            [alert show];
		}
	}
}


@end
