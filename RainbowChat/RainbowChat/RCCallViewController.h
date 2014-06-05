//
//  RCCallViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 6/4/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Quickblox/Quickblox.h>
#import "RCUser.h"

@interface RCCallViewController : UIViewController <QBActionStatusDelegate, QBChatDelegate, AVAudioPlayerDelegate, UIAlertViewDelegate> {
    
    IBOutlet UIBarButtonItem *stopButton;
    IBOutlet UIView *toUserVideoView;
    IBOutlet UIView *currentUserVideoView;
    IBOutlet UINavigationBar *navBar;
    
    NSUInteger videoChatOpponentID;
    enum QBVideoChatConferenceType videoChatConferenceType;
}

@property (strong, nonatomic) RCUser *currentUser;
@property (retain) NSNumber *quickbloxID_currentuser;
@property (retain) NSNumber *quickbloxID_opponentID;

@property (nonatomic) BOOL isReceivingSide;
@property (retain) NSString *sessionID;
@property (retain) NSNumber *opponentID;
@property (retain) QBVideoChat *videoChat;
@property (retain) UIAlertView *callAlert;

- (IBAction)stop:(id)sender;

@end
