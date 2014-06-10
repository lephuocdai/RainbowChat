//
//  RCLoginViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCLoginViewController.h"
#import "RCAppDelegate.h"
#import "MBProgressHUD.h"
#import "RCUtility.h"

@interface RCLoginViewController ()
@property (strong, nonatomic) IBOutlet UITextField *emailTextField;
@property (strong, nonatomic) IBOutlet UITextField *passwordTextField;
@end


@implementation RCLoginViewController

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
    
    _emailTextField.delegate = self;
    _emailTextField.delegate = self;
    
    // Pop up the keyboard so users can typing immediately
    [_emailTextField becomeFirstResponder];
    
//    NSLog(@"LoginViewController.ffInstance = %@", self.ffInstance);
    NSLog(@"[FatFractal main] = %@", [FatFractal main]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextField delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _emailTextField) {
        [_passwordTextField becomeFirstResponder];
    } else if (textField == _passwordTextField) {
        [self loginUserWithEmail:_emailTextField.text andPassword:_passwordTextField.text];
    }
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - Navigation
- (IBAction)cancelButtonPressed:(id)sender {
    DBGMSG(@"%s", __func__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onLogin:(id)sender {
    DBGMSG(@"%s", __func__);
    [self loginUserWithEmail:_emailTextField.text andPassword:_passwordTextField.text];
}


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

#pragma Helper
- (void)loginUserWithEmail:(NSString*)email andPassword:(NSString*)password {
    DBGMSG(@"%s", __func__);
    
#warning - Need method to translate an email to a username
    
    if (([email length] > 0) && ([password length] >0) && ![email isEqualToString:@""] && ![password isEqualToString:@""]) {
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeIndeterminate;
        hud.labelText = @"Authorizing...";
        hud.dimBackground = YES;
        hud.yOffset = -77;
        
        // Login with FatFractal then save to keychain and handleSuccessfulLogin if successful
        [[FatFractal main] loginWithUserName:email andPassword:password onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
            if (theErr) {
                NSLog(@"Error logging in from LoginViewController: %@", [theErr localizedDescription]);
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [[[UIAlertView alloc] initWithTitle:@"Error"
                                                                message:@"Your username and password could not be authenticated. Double check that you entered them correctly and try again."
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles: nil]
                 show];
            } else {
                if (theObj) {
                    [self saveUserCredentialsInKeyChain];
                    QBASessionCreationRequest *extendedAuthRequest = [QBASessionCreationRequest request];
                    extendedAuthRequest.userLogin = [RCUtility usernameFromEmail:email];
                    extendedAuthRequest.userPassword = password;
                    [QBAuth createSessionWithExtendedRequest:extendedAuthRequest delegate:self];
                }
            }
        }];
    } else {
        // Textfields are empty, error handling.
        [[[UIAlertView alloc] initWithTitle:@"Text fields cannot be blank"
                                    message:@"One or more of the text fields are empty. Please fill them in."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil]
         show];
    }
}

-(void)saveUserCredentialsInKeyChain {
    DBGMSG(@"%s", __func__);
    NSString *username = _emailTextField.text;
    NSString *password = _passwordTextField.text;
    
    KeychainItemWrapper *keychainItem = [RCAppDelegate keychainItem];
    [keychainItem setObject:username forKey:(__bridge id)(kSecAttrAccount)];
    [keychainItem setObject:password forKey:(__bridge id)(kSecValueData)];
    NSLog(@"Successfully saved user %@ to keychain after authentication in LoginViewController.", [keychainItem objectForKey:(__bridge id)(kSecAttrAccount)]);
}

- (void)handleSuccessfulLogin {
    DBGMSG(@"%s", __func__);
//    self.delegate = self.parentViewController;
    if ([self.delegate respondsToSelector:@selector(loginViewControllerDidLoginUser)]) {
        [self.delegate loginViewControllerDidLoginUser];
    }
    [self.delegate loginViewControllerDidLoginUser];
}

#pragma mark - QBActionStatusDelegate
// QuickBlox API queries delegate
- (void)completedWithResult:(Result *)result {
    DBGMSG(@"%s", __func__);
    // QuickBlox session creation  result
    if ([result isKindOfClass:[QBAAuthSessionCreationResult class]]) {
        if (result.success) {
            // Set QuickBlox Chat delegate
            //
            [QBChat instance].delegate = self;
            QBUUser *user = [QBUUser user];
            user.ID = ((QBAAuthSessionCreationResult *)result).session.userID;
            user.password = @"12345678";
            
            // Login to QuickBlox Chat
            //
            [[QBChat instance] loginWithUser:user];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[[result errors] description]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

#pragma mark QBChatDelegate
- (void)chatDidLogin {
    DBGMSG(@"%s", __func__);
    // Show main controller
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        // Upon successful dismiss, handle login.
        [self handleSuccessfulLogin];
    }];
}
- (void)chatDidNotLogin{
    DBGMSG(@"%s", __func__);
}

@end
