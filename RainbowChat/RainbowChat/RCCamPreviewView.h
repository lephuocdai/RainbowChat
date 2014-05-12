//
//  RCCamPreviewView.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/12/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>

@class  AVCaptureSession;

@interface RCCamPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
