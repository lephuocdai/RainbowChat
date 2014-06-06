//
//  RCVideoProcessor.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/20/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "RCVideoProcessor.h"

#define BYTES_PER_PIXEL 4

@interface RCVideoProcessor()

// Redeclared as readwrite so that we can write to the property and still be atomic with external readers.
@property (readwrite) Float64 videoFrameRate;
@property (readwrite) CMVideoDimensions videoDimensions;
@property (readwrite) CMVideoCodecType videoType;

@property (readwrite, getter=isRecording) BOOL recording;

@property (readwrite) AVCaptureVideoOrientation videoOrientation;
@property (readwrite) AVCaptureDevicePosition captureDevicePosition;

@end


@implementation RCVideoProcessor

@synthesize delegate;
@synthesize videoFrameRate, videoDimensions, videoType;
@synthesize referenceOrientation;
@synthesize videoOrientation;
@synthesize recording;

#pragma mark -
- (id) init {
    if (self = [super init]) {
        previousSecondTimestamps = [[NSMutableArray alloc] init];
        referenceOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationPortrait;
        
        // The temporary path for the video before saving it to the photo album
        movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"Movie.MOV"]];
        self.captureDevicePosition = AVCaptureDevicePositionFront;
    }
    return self;
}

#pragma mark - Utilities
- (void) calculateFramerateAtTimestamp:(CMTime) timestamp {
	[previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
    
	CMTime oneSecond = CMTimeMake( 1, 1 );
	CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
    
	while( CMTIME_COMPARE_INLINE( [[previousSecondTimestamps objectAtIndex:0] CMTimeValue], <, oneSecondAgo ) )
		[previousSecondTimestamps removeObjectAtIndex:0];
    
	Float64 newRate = (Float64) [previousSecondTimestamps count];
	self.videoFrameRate = (self.videoFrameRate + newRate) / 2;
}

- (void)removeFile:(NSURL *)fileURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
		if (!success)
			[self showError:error];
    }
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation {
	CGFloat angle = 0.0;
    
#warning Need to optimize this
	switch (orientation) {
		case AVCaptureVideoOrientationPortrait:
//			angle = (self.captureDevicePosition == AVCaptureDevicePositionFront) ? M_PI : 0.0;
            angle = 0.0;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
//			angle = (self.captureDevicePosition == AVCaptureDevicePositionFront) ? 0.0 : M_PI;
            angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
    
	return angle;
}

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation {
    DBGMSG(@"%s", __func__);
	CGAffineTransform transform = CGAffineTransformIdentity;
    
	// Calculate offsets from an arbitrary reference orientation (portrait)
	CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
	CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
	
	// Find the difference in angle between the passed in orientation and the current video orientation
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    if (self.captureDevicePosition == AVCaptureDevicePositionFront) {
        transform = CGAffineTransformConcat(CGAffineTransformMakeRotation(angleOffset), CGAffineTransformMakeScale(1.0, -1.0));
    } else {
        transform = CGAffineTransformConcat(CGAffineTransformMakeRotation(angleOffset), CGAffineTransformMakeScale(-1.0, -1.0));
    }
    
    
//	transform = CGAffineTransformMakeRotation(angleOffset);
	
	return transform;
}

#pragma mark - Recording

- (void)saveToCloud {
    DBGMSG(@"%s", __func__);
}


- (void)saveMovieToCameraRoll {
    DBGMSG(@"%s", __func__);
    
#warning - These lines of code is only for testing

    // added example to save a local copy of the file
    NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSURL *movieURLD = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", documentsDirectory, @"ManageriPadMovie.mp4"]];
    NSString *strDest = [NSString stringWithFormat:@"%@/%@", documentsDirectory, @"ManageriPadMovie.mp4"];
    NSString *strSrc = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"ManageriPadMovie.mp4"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    // delete any previous copy of the file
    if ([fileManager fileExistsAtPath:strDest] && [fileManager isWritableFileAtPath:strDest]) {
		if (![fileManager removeItemAtPath:strDest error:&error]) {
			return;
		}
	}
    
    if ([fileManager fileExistsAtPath:strSrc]) {
        if ([fileManager copyItemAtURL:movieURL toURL:movieURLD error:&error]) {
            NSLog(@"copied to %@", documentsDirectory);
        }
    }

    // make sure you have the AssetsLibrary framework added
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	[library writeVideoAtPathToSavedPhotosAlbum:movieURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error)
            [self showError:error];
        else
            [self removeFile:movieURL];
									
        dispatch_async(movieWritingQueue, ^{
            recordingWillBeStopped = NO;
            self.recording = NO;
										
            [self.delegate recordingDidStopWithMovieURL:movieURL];
        });
    }];
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType {
	if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
		
        if ([assetWriter startWriting]) {
			[assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
			[self showError:[assetWriter error]];
		}
	}
	
	if ( assetWriter.status == AVAssetWriterStatusWriting ) {
		
		if (mediaType == AVMediaTypeVideo) {
			if (assetWriterVideoIn.readyForMoreMediaData) {
				if (![assetWriterVideoIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
		else if (mediaType == AVMediaTypeAudio) {
			if (assetWriterAudioIn.readyForMoreMediaData) {
				if (![assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
	}
}

- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription {
	const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
	size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
	NSData *currentChannelLayoutData = nil;
	
	// AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 )
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
	else
		currentChannelLayoutData = [NSData data];
	
	NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
											  [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
											  [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
											  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
											  currentChannelLayoutData, AVChannelLayoutKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
		assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
		assetWriterAudioIn.expectsMediaDataInRealTime = YES;
		if ([assetWriter canAddInput:assetWriterAudioIn])
			[assetWriter addInput:assetWriterAudioIn];
		else {
			NSLog(@"Couldn't add asset writer audio input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply audio output settings.");
        return NO;
	}
    
    return YES;
}

- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription {
	float bitsPerPixel;
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
	int numPixels = dimensions.width * dimensions.height;
	int bitsPerSecond;
	
	// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
	if ( numPixels < (640 * 480) )
		bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
	else
		bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	bitsPerSecond = numPixels * bitsPerPixel;
	
#warning Need to change the dimensions here: 200.0
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoScalingModeResizeAspectFill,AVVideoScalingModeKey,
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:200.0], AVVideoWidthKey,
											  [NSNumber numberWithInteger:200.0], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
        
		assetWriterVideoIn.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
		if ([assetWriter canAddInput:assetWriterVideoIn])
			[assetWriter addInput:assetWriterVideoIn];
		else {
			NSLog(@"Couldn't add asset writer video input.");
            return NO;
		}
	}
	else {
		NSLog(@"Couldn't apply video output settings.");
        return NO;
	}
    
    return YES;
}

- (void) startRecording {
	dispatch_async(movieWritingQueue, ^{
        
		if ( recordingWillBeStarted || self.recording )
			return;
        
		recordingWillBeStarted = YES;
        
		// recordingDidStart is called from captureOutput:didOutputSampleBuffer:fromConnection: once the asset writer is setup
		[self.delegate recordingWillStart];
        
		// Remove the file if one with the same name already exists
		[self removeFile:movieURL];
        
		// Create an asset writer
		NSError *error;
		assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:(NSString *)kUTTypeQuickTimeMovie error:&error];
		if (error)
			[self showError:error];
	});
}

- (void) stopRecording {
	dispatch_async(movieWritingQueue, ^{
		
		if ( recordingWillBeStopped || (self.recording == NO) )
			return;
		
		recordingWillBeStopped = YES;
		
		// recordingDidStop is called from saveMovieToCameraRoll
		[self.delegate recordingWillStop];
        
        // Added by Le: http://stackoverflow.com/questions/14765875/avassetwriter-finishwritingwithcompletionhandler-error-with-unknown-error
        [assetWriterAudioIn markAsFinished];
        [assetWriterVideoIn markAsFinished];
        
        [assetWriter finishWritingWithCompletionHandler:^{
            if (assetWriter.status == AVAssetWriterStatusCompleted) {
                assetWriterAudioIn = nil;
                assetWriterVideoIn = nil;
                assetWriter = nil;
                readyToRecordVideo = NO;
                readyToRecordAudio = NO;
#warning Need to check this
//                [self saveMovieToCameraRoll];
//                [self saveToCloud];
                [self.delegate recordingDidStopWithMovieURL:movieURL];
                
            } else {
                [self showError:[assetWriter error]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self resumeCaptureSession];
                });
            }
            
        }];
	});
}

- (void)toggleCameraIsFront:(BOOL)isBack {
    
#warning - Need to change transform orientation
    AVCaptureDevicePosition desiredPosition = (isBack) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:desiredPosition] error:nil];
    [captureSession beginConfiguration];
    [captureSession removeInput:videoDeviceInput];
    if ([captureSession canAddInput:videoIn]) {
        [captureSession addInput:videoIn];
        videoDeviceInput = videoIn;
    } else
        [captureSession addInput:videoDeviceInput];
    
    [captureSession removeOutput:videoDataOutput];
    AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
    if ([captureSession canAddOutput:videoOut]) {
        [captureSession addOutput:videoOut];
        videoDataOutput = videoOut;
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
        [videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        // How to manage previously created videoCaptureQ in setupSessionWithPreview method ???
        // or do we need create instance variable as dispatch_queue_t videoCaptureQ ???
        dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
        videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        self.videoOrientation = [videoConnection videoOrientation];
    } else
        [captureSession addOutput:videoDataOutput];
    
    [captureSession commitConfiguration];
}

#pragma mark - Capture

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
	if ( connection == videoConnection ) {
		
		// Get framerate
		CMTime timestamp = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
		[self calculateFramerateAtTimestamp:timestamp];
        
		// Get frame dimensions (for onscreen display)
		if (self.videoDimensions.width == 0 && self.videoDimensions.height == 0)
			self.videoDimensions = CMVideoFormatDescriptionGetDimensions( formatDescription );
		
		// Get buffer type
		if ( self.videoType == 0 )
			self.videoType = CMFormatDescriptionGetMediaSubType( formatDescription );
		
		// Enqueue it for preview.  This is a shallow queue, so if image processing is taking too long,
		// we'll drop this frame for preview (this keeps preview latency low).
		OSStatus err = CMBufferQueueEnqueue(previewBufferQueue, sampleBuffer);
		if ( !err ) {
			dispatch_async(dispatch_get_main_queue(), ^{
				CMSampleBufferRef sbuf = (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(previewBufferQueue);
				if (sbuf) {
					CVImageBufferRef pixBuf = CMSampleBufferGetImageBuffer(sbuf);
					[self.delegate pixelBufferReadyForDisplay:pixBuf];
					CFRelease(sbuf);
				}
			});
		}
	}
    
	CFRetain(sampleBuffer);
	CFRetain(formatDescription);
	dispatch_async(movieWritingQueue, ^{
        
		if ( assetWriter ) {
            
			BOOL wasReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
			
			if (connection == videoConnection) {
				
				// Initialize the video input if this is not done yet
				if (!readyToRecordVideo)
					readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
				
				// Write video data to file
				if (readyToRecordVideo && readyToRecordAudio)
					[self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
			}
			else if (connection == audioConnection) {
				
				// Initialize the audio input if this is not done yet
				if (!readyToRecordAudio)
					readyToRecordAudio = [self setupAssetWriterAudioInput:formatDescription];
				
				// Write audio data to file
				if (readyToRecordAudio && readyToRecordVideo)
					[self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
			}
			
			BOOL isReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
			if ( !wasReadyToRecord && isReadyToRecord ) {
				recordingWillBeStarted = NO;
				self.recording = YES;
				[self.delegate recordingDidStart];
			}
		}
		CFRelease(sampleBuffer);
		CFRelease(formatDescription);
	});
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return nil;
}

- (AVCaptureDevice *)audioDevice {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

- (BOOL) setupCaptureSession {
	/*
     Overview: Uses separate GCD queues for audio and video capture.  If a single GCD queue
     is used to deliver both audio and video buffers, and our video processing consistently takes
     too long, the delivery queue can back up, resulting in audio being dropped.
     
     When recording, it creates a third GCD queue for calls to AVAssetWriter.  This ensures
     that AVAssetWriter is not called to start or finish writing from multiple threads simultaneously.
     
     Uses AVCaptureSession's default preset, AVCaptureSessionPresetHigh.
	 */
    
    // Create capture session
    captureSession = [[AVCaptureSession alloc] init];
    
    // Create audio connection
    audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if ([captureSession canAddInput:audioDeviceInput])
        [captureSession addInput:audioDeviceInput];
	
	audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
	dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
	[audioDataOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
#warning Need to check: ARC compliance
//	dispatch_release(audioCaptureQueue);
	if ([captureSession canAddOutput:audioDataOutput])
		[captureSession addOutput:audioDataOutput];
	audioConnection = [audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    
	// Create video connection with default position is back
    videoDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:self.captureDevicePosition] error:nil];
    if ([captureSession canAddInput:videoDeviceInput])
        [captureSession addInput:videoDeviceInput];
    
	videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
	[videoDataOutput setAlwaysDiscardsLateVideoFrames:NO]; // set this to NO when using AVAssetWriter
	[videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
	[videoDataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
#warning Need to check: ARC compliance
//	dispatch_release(videoCaptureQueue);
	if ([captureSession canAddOutput:videoDataOutput])
		[captureSession addOutput:videoDataOutput];
	videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
	self.videoOrientation = [videoConnection videoOrientation];
    
	return YES;
}

- (void) setupAndStartCaptureSession {
	// Create a shallow queue for buffers going to the display for preview.
	OSStatus err = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &previewBufferQueue);
	if (err)
		[self showError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
	
	// Create serial queue for movie writing
	movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
	
    if ( !captureSession )
		[self setupCaptureSession];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionStoppedRunningNotification:) name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	
	if ( !captureSession.isRunning)
		[captureSession startRunning];
}

- (void) pauseCaptureSession {
	if ( captureSession.isRunning )
		[captureSession stopRunning];
}

- (void) resumeCaptureSession {
	if ( !captureSession.isRunning )
		[captureSession startRunning];
}

- (void) stopAndTearDownCaptureSession {
    [captureSession stopRunning];
	if (captureSession)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	captureSession = nil;
	if (previewBufferQueue) {
		CFRelease(previewBufferQueue);
		previewBufferQueue = NULL;
	}
	if (movieWritingQueue) {
#warning Need to check: ARC compliance
//		dispatch_release(movieWritingQueue);
		movieWritingQueue = NULL;
	}
}

#pragma mark - Notifications
- (void)captureSessionStoppedRunningNotification:(NSNotification *)notification {
	dispatch_async(movieWritingQueue, ^{
		if ( [self isRecording] ) {
			[self stopRecording];
		}
	});
}

#pragma mark - Error Handling

- (void)showError:(NSError *)error {
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}


@end
