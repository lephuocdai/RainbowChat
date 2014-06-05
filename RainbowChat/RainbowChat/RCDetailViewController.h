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
#import "RCCallViewController.h"
#import "RCUser.h"
#import <Quickblox/Quickblox.h>



@interface RCDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, RCVideoProcessorDelegate> {
    RCVideoProcessor *videoProcessor;
    RCPreviewView *oglView;
    UIBackgroundTaskIdentifier backgroundRecordingID;
    dispatch_queue_t progressQueue;
    
}

#warning Need to change the type of this class
@property (strong, nonatomic) RCUser *toUser;

@end
