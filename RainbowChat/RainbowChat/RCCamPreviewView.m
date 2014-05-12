//
//  RCCamPreviewView.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/12/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation RCCamPreviewView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (Class)layerClass {
	return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session {
	return [(AVCaptureVideoPreviewLayer *)[self layer] session];
}

- (void)setSession:(AVCaptureSession *)session {
	[(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];
}

@end
