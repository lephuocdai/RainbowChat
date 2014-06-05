//
//  RCCallViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 6/4/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCCallViewController.h"

@interface RCCallViewController ()

@end

@implementation RCCallViewController

- (void)viewDidLoad {
    DBGMSG(@"%s", __func__);
    
    [super viewDidLoad];
    
    [QBChat instance].delegate = self;
    [NSTimer scheduledTimerWithTimeInterval:30 target:[QBChat instance] selector:@selector(sendPresence) userInfo:nil repeats:YES];

}

- (void)viewDidAppear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewDidAppear:animated];
    
    videoChatConferenceType = QBVideoChatConferenceTypeAudioAndVideo;
    videoChatOpponentID = (NSUInteger)self.opponentID;
    
    if (self.isReceivingSide) {
//        if(self.videoChat == nil){
//            NSLog(@"Receiving");
//            self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:self.sessionID];
//            NSLog(@"accept sessionID = %@", self.sessionID);
//            
//        }
        
        self.videoChat.viewToRenderOpponentVideoStream = toUserVideoView;
        self.videoChat.viewToRenderOwnVideoStream = currentUserVideoView;
        
        // Set Audio & Video output
        //
        self.videoChat.useHeadphone = NO;
        self.videoChat.useBackCamera = NO;
        
        // Accept call
        [self.videoChat acceptCallWithOpponentID:videoChatOpponentID conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
        NSLog(@"%@", self.videoChat.sessionID);
    } else {
        if(self.videoChat == nil){
            NSLog(@"Sending");
            self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
            self.videoChat.viewToRenderOpponentVideoStream = toUserVideoView;
            self.videoChat.viewToRenderOwnVideoStream = currentUserVideoView;
        }
        
        // Set Audio & Video output
        //
        self.videoChat.useHeadphone = NO;
        self.videoChat.useBackCamera = NO;
        
        // Call user by ID
        [self.videoChat callUser:[self.opponentID integerValue] conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
    }
}

- (IBAction)stop:(id)sender {

    [self.videoChat finishCall];
    
    [[QBChat instance] unregisterVideoChatInstance:self.videoChat];
    self.videoChat = nil;
}

#pragma mark - QBChatDelegate 
-(void) chatCallUserDidNotAnswer:(NSUInteger)userID{
    NSLog(@"chatCallUserDidNotAnswer %lu", (unsigned long)userID);
    
    //    [self sendVideoMessage];
}

-(void) chatCallDidRejectByUser:(NSUInteger)userID{
    NSLog(@"chatCallDidRejectByUser %lu", (unsigned long)userID);
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"QuickBlox VideoChat"
                          message:@"User has rejected your call."
                          delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil];
    [alert show];
}

-(void) chatCallDidAcceptByUser:(NSUInteger)userID{
    NSLog(@"chatCallDidAcceptByUser %lu", (unsigned long)userID);
}

- (void)chatCallDidStartWithUser:(NSUInteger)userID sessionID:(NSString *)sessionID{
    NSLog(@"chatCallDidAcceptByUser %lu", (unsigned long)userID);
}


- (void)setQuickbloxID {
    
    _currentUser = (RCUser*)[[FatFractal main] loggedInUser];
    
    QBASessionCreationRequest *extendedAuthRequest = [QBASessionCreationRequest request];
    extendedAuthRequest.userLogin = ([_currentUser.userName isEqualToString:@"test1@test.c"]) ? @"test1" : @"test2";
    extendedAuthRequest.userPassword = @"12345678";
    [QBAuth createSessionWithExtendedRequest:extendedAuthRequest delegate:self];
    
    
    if ([_currentUser.userName isEqualToString:@"test1@test.c"]) {
        [self setQuickbloxID_currentuser:@1180746];
        [self setQuickbloxID_opponentID:@1180748];
    } else {
        [self setQuickbloxID_currentuser:@1180748];
        [self setQuickbloxID_opponentID:@1180746];
    }
}

#pragma mark - QBActionStatusDelegate
// QuickBlox API queries delegate
- (void)completedWithResult:(Result *)result{
    DBGMSG(@"%s - result = %@", __func__, result);
    // QuickBlox session creation  result
    if([result isKindOfClass:[QBAAuthSessionCreationResult class]]){
        
        // Success result
        if(result.success){
            
            // Set QuickBlox Chat delegate
            //
            [QBChat instance].delegate = self;
            
            QBUUser *user = [QBUUser user];
            user.ID = ((QBAAuthSessionCreationResult *)result).session.userID;
            user.password = @"12345678";
            
            // Login to QuickBlox Chat
            //
            [[QBChat instance] loginWithUser:user];
        }else{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[[result errors] description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
    }
}

#pragma mark QBChatDelegate
- (void)chatDidLogin {
    videoChatConferenceType = QBVideoChatConferenceTypeAudioAndVideo;
    videoChatOpponentID = (NSUInteger)self.opponentID;
    
    if (self.isReceivingSide) {
        if(self.videoChat == nil){
            NSLog(@"Receiving");
            self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:self.sessionID];
            NSLog(@"accept sessionID = %@", self.sessionID);
            self.videoChat.viewToRenderOpponentVideoStream = toUserVideoView;
            self.videoChat.viewToRenderOwnVideoStream = currentUserVideoView;
        }
        
        // Set Audio & Video output
        //
        self.videoChat.useHeadphone = NO;
        self.videoChat.useBackCamera = NO;
        
        // Accept call
        [self.videoChat acceptCallWithOpponentID:videoChatOpponentID conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
        NSLog(@"%@", self.videoChat.sessionID);
    } else {
        if(self.videoChat == nil){
            NSLog(@"Sending");
            self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
            self.videoChat.viewToRenderOpponentVideoStream = toUserVideoView;
            self.videoChat.viewToRenderOwnVideoStream = currentUserVideoView;
        }
        
        // Set Audio & Video output
        //
        self.videoChat.useHeadphone = NO;
        self.videoChat.useBackCamera = NO;
        
        // Call user by ID
        [self.videoChat callUser:[self.opponentID integerValue] conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
    }
}

@end
