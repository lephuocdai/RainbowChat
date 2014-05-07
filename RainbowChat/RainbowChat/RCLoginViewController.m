//
//  RCLoginViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCLoginViewController.h"

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
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextField delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
#warning Need to implement
    return NO;
}

#pragma Helper
- (void)loginUserWithEmail:(NSString*)email andPassword:(NSString*)password {
    
}

-(void)saveUserCredentialsInKeyChain {
    
}

- (void)handleSuccessfulLogin {
    
}


#pragma mark - Navigation
- (IBAction)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onLogin:(id)sender {
}


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}


@end
