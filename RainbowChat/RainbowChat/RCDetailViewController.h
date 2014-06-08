//
//  RCDetailViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "RCPreviewView.h"
#import "RCVideoProcessor.h"
#import "RCUser.h"
#import <Quickblox/Quickblox.h>
#import "RCFatFractal.h"
#import "KeychainItemWrapper.h"

@interface RCDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, RCVideoProcessorDelegate, QBActionStatusDelegate, QBChatDelegate> {
    
    // Video message
    RCVideoProcessor *videoProcessor;
    RCPreviewView *oglView;
    UIBackgroundTaskIdentifier backgroundRecordingID;
    dispatch_queue_t progressQueue;
    
    // Video call
    IBOutlet UIBarButtonItem *callButton;
    NSUInteger videoChatOpponentID;
    enum QBVideoChatConferenceType videoChatConferenceType;
    NSString *sessionID;
    BOOL isCalling;
}

// Fatfractal
//@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) RCFatFractal *ffInstance;
@property (strong, nonatomic) RCUser *currentUser;
@property (strong, nonatomic) RCUser *toUser;

// Quickblox
@property (retain) NSNumber *quickbloxID_currentuser;
@property (retain) NSNumber *quickbloxID_opponentID;
@property (retain) QBVideoChat *videoChat;
@property (retain) UIAlertView *callAlert;

@end
