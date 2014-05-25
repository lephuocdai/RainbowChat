//
//  RCVideoProcessor.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/20/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBufferQueue.h>

@protocol RCVideoProcessorDelegate;

@interface RCVideoProcessor : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
    id <RCVideoProcessorDelegate> __unsafe_unretained delegate;
    
    NSMutableArray *previousSecondTimestamps;
	Float64 videoFrameRate;
	CMVideoDimensions videoDimensions;
	CMVideoCodecType videoType;
    
	AVCaptureSession *captureSession;
	AVCaptureConnection *audioConnection;
	AVCaptureConnection *videoConnection;
    AVCaptureDeviceInput *videoDeviceInput;
    AVCaptureDeviceInput *audioDeviceInput;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureAudioDataOutput *audioDataOutput;
	CMBufferQueueRef previewBufferQueue;
	
	NSURL *movieURL;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioIn;
	AVAssetWriterInput *assetWriterVideoIn;
	dispatch_queue_t movieWritingQueue;
    
	AVCaptureVideoOrientation referenceOrientation;
	AVCaptureVideoOrientation videoOrientation;
    
	// Only accessed on movie writing queue
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
	BOOL recordingWillBeStarted;
	BOOL recordingWillBeStopped;
    
	BOOL recording;
}

@property (readwrite, assign) id <RCVideoProcessorDelegate> delegate;

@property (readonly) Float64 videoFramRate;
@property (readonly) CMVideoDimensions videoDimensions;
@property (readonly) CMVideoCodecType videoType;

@property (readwrite) AVCaptureVideoOrientation referenceOrientation;

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation;

- (void) showError:(NSError*)error;

- (void) setupAndStartCaptureSession;
- (void) stopAndTearDownCaptureSession;

- (void) startRecording;
- (void) stopRecording;
- (void) toggleCameraIsFront:(BOOL)isFront;

- (void) pauseCaptureSession; // Pausing while a recording is in progress will cause the recording to be stopped and saved.
- (void) resumeCaptureSession;

@property(readonly, getter=isRecording) BOOL recording;

@end

@protocol RCVideoProcessorDelegate <NSObject>
@required
- (void)pixelBufferReadyForDisplay:(CVPixelBufferRef)pixelBuffer;	// This method is always called on the main thread.
- (void)recordingWillStart;
- (void)recordingDidStart;
- (void)recordingWillStop;
- (void)recordingDidStopWithMovieURL:(NSURL*)movieURL;
@end
