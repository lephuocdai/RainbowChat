//
//  RCDetailViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCDetailViewController.h"
#import <QuartzCore/QuartzCore.h>

#import <AssetsLibrary/AssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>
#import "RCVideo.h"
#import "RCUtility.h"
#import "RCConstant.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AWSS3.h>
#import "AmazonClientManager.h"
#import "MBProgressHUD.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;

typedef enum {
    UploadStateNotUpload,
    UploadStateUploading,
    UploadStateFinished
} UploadState;

typedef enum {
    UploadStateThumbnailNotUpload,
    UploadStateThumbnailStarted,
    UploadStateThumbnailFinished
} UploadStateThumbnail;

typedef enum {
    UploadStateVideoNotUpload,
    UploadStateVideoStarted,
    UploadStateVideoFinished
} UploadStateVideo;

@class ToUserCell;
@class CurrentUserCell;

@interface ToUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (strong, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@end

@implementation ToUserCell
@synthesize userProfilePicture, videoView;
@end


@interface CurrentUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (strong, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@end

@implementation CurrentUserCell
@synthesize userProfilePicture, videoView;
@end

@interface RCCamPreviewFooter : UITableViewHeaderFooterView
@property (nonatomic) IBOutlet UILabel *userNameLabel;
@property (nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (nonatomic) IBOutlet UIView *previewView;
@end

@implementation RCCamPreviewFooter
@synthesize userNameLabel, userProfilePicture, previewView;
@end



@interface RCDetailViewController () <AVCaptureFileOutputRecordingDelegate>

@property (strong, nonatomic) RCUser *currentUser;
@property (nonatomic) NSMutableArray *videos;
@property (nonatomic) NSMutableArray *videoURLs;
@property (nonatomic, getter = getNewVideo) RCVideo *newVideo;
@property (nonatomic) AVPlayer *avPlayer;
@property (nonatomic) AVPlayerLayer *avPlayerLayer;
//@property (nonatomic) NSNumber *lastRefreshTime;

@property (strong, nonatomic) IBOutlet UISwitch *cameraSwitchButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordButton;

- (void)configureView;

/*
// Session Management
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *avCapturesession;
@property (nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
*/


// Utilities.
#warning - Need to implement these properties
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;


@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, readwrite) UploadState uploadState;
@property (nonatomic, readwrite) UploadStateThumbnail uploadStateThumbnail;
@property (nonatomic, readwrite) UploadStateVideo uploadStateVideo;

@end

static inline double radians (double degrees) { return degrees * (M_PI / 180); }

@implementation RCDetailViewController {
    IBOutlet UITableView *threadTableView;
    // Table view footer
    
    NSURL *outputFileURL;
    BOOL isFrontCamera;
    NSInteger currentSelectedCell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)applicationDidBecomeActive:(NSNotification*)notifcation {
	// For performance reasons, we manually pause/resume the session when saving a recording.
	// If we try to resume the session in the background it will fail. Resume the session here as well to ensure we will succeed.
	[videoProcessor resumeCaptureSession];
}

// UIDeviceOrientationDidChangeNotification selector
- (void)deviceOrientationDidChange {
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	// Don't update the reference orientation when the device orientation is face up/down or unknown.
	if ( UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation) )
		[videoProcessor setReferenceOrientation:orientation];
}

- (void)setToUser:(RCUser *)toUser {
    if (_toUser != toUser) {
        _toUser = toUser;
        
        // Update the view.
        [self configureView];
    }
}

#pragma mark - View life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
    currentSelectedCell = -1;
    
    [self configureView];
    
    [self refresh];
    
    isFrontCamera = YES;
}

- (void)configureView {
    DBGMSG(@"%s", __func__);
    if (_toUser)
        self.title = _toUser.firstName;

    // Set up AVPlayer
    _avPlayer = [[AVPlayer alloc] init];
    _avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];

/*
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setAvCapturesession:session];
    // Set up session queue
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
 */
    
    // Initialize the class responsible for managing AV capture session and asset writer
    videoProcessor = [[RCVideoProcessor alloc] init];
    videoProcessor.delegate = self;
    
    // Keep track of changes to the device orientation so we can update the video processor
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
//    [notificationCenter addObserver:self selector:@selector(didReturnUploadFileConnectionSuccess:)
//                               name:@"didHaveUploadFileConnectionSuccess" object:nil];
    
    // Setup and start the capture session
    [videoProcessor setupAndStartCaptureSession];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
    
    // Create an OpenGLView instance to display the captured video in the view
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.userNameLabel.text = _currentUser.firstName;
    
    
    oglView = [[RCPreviewView alloc] initWithFrame:footerView.previewView.bounds];
    // Force orientation to portrait
    oglView.transform = [videoProcessor transformFromCurrentVideoOrientationToOrientation:UIInterfaceOrientationPortrait];
    [((RCCamPreviewFooter*)threadTableView.tableFooterView).previewView addSubview:oglView];
    [footerView.previewView.layer setMasksToBounds:YES];
}

- (void)setPreviewView:(UIView*)aView{
    DBGMSG(@"%s", __func__);
    ((RCCamPreviewFooter*)threadTableView.tableFooterView).previewView = aView;
}

- (void)cleanup {
    DBGMSG(@"%s", __func__);
    oglView = nil;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
	[notificationCenter removeObserver:self name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
    
    // Stop and tear down the capture session
	[videoProcessor stopAndTearDownCaptureSession];
	videoProcessor.delegate = nil;
}
- (void)viewDidUnload {
    DBGMSG(@"%s", __func__);
    [self setPreviewView:nil];
    [self setRecordButton:nil];
    [super viewDidUnload];
    [self cleanup];
}

- (void)viewWillAppear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];
/**
    _uploadState = UploadStateNotUpload;
    _uploadStateThumbnail = UploadStateThumbnailNotUpload;
    _uploadStateVideo = UploadStateVideoNotUpload;
    
    dispatch_async(_sessionQueue, ^{
        
        [self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        [self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
        
        __weak RCDetailViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:_avCapturesession queue:nil usingBlock:^(NSNotification *note) {
			RCDetailViewController *strongSelf = weakSelf;
			dispatch_async(strongSelf.sessionQueue, ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[strongSelf.avCapturesession startRunning];
			});
		}]];
		[_avCapturesession startRunning];
    });
 **/
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];
/**
	dispatch_async(_sessionQueue, ^{
		[_avCapturesession stopRunning];
        
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
	});
**/
}

- (IBAction)recordButtonPushed:(id)sender {
    
    // Wait for the recording to start/stop before re-enabling the record button.
    [_recordButton setEnabled:NO];
    
    if ( [videoProcessor isRecording] ) {
		// The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
		[videoProcessor stopRecording];
	}
	else {
		// The recordingWill/DidStart delegate methods will fire asynchronously in response to this call
        [videoProcessor startRecording];
	}
    
    /*
    dispatch_async(_sessionQueue, ^{
        if (![_movieFileOutput isRecording]) {
            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
            }
            
            // Turning OFF flash for video recording
#warning - Need to implement
            
            // Start recording to a temporary file
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"moview" stringByAppendingPathExtension:@"mov"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
                NSError *error;
                if ([[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:&error] == NO) {
                    NSLog(@"removeItemAtPath %@ error:%@", outputFilePath, error);
                }
            }
            [_movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
            
            
        } else {
            [_movieFileOutput stopRecording];
        }
    });
     */
}

#pragma mark - RCVideoProcessorDelegate

- (void)recordingWillStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recordButton setEnabled:NO];
        
		// Disable the idle timer while we are recording
		[UIApplication sharedApplication].idleTimerDisabled = YES;
        
		// Make sure we have time to finish saving the movie if the app is backgrounded during recording
		if ([[UIDevice currentDevice] isMultitaskingSupported])
			backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
    });
}

- (void)recordingDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recordButton setEnabled:YES];
        [_recordButton setTintColor:[UIColor redColor]];
    });
}

- (void)recordingWillStop {
    dispatch_async(dispatch_get_main_queue(), ^{
		// Disable until saving to the camera roll is complete
		[_recordButton setEnabled:NO];
		
		// Pause the capture session so that saving will be as fast as possible.
		// We resume the sesssion in recordingDidStop:
		[videoProcessor pauseCaptureSession];
	});
}

- (void)recordingDidStopWithMovieURL:(NSURL *)movieURL {
	dispatch_async(dispatch_get_main_queue(), ^{
		[_recordButton setEnabled:YES];
		[_recordButton setTintColor:[UIColor blueColor]];
        
		[UIApplication sharedApplication].idleTimerDisabled = NO;
        
		[videoProcessor resumeCaptureSession];
        
		if ([[UIDevice currentDevice] isMultitaskingSupported]) {
			[[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
			backgroundRecordingID = UIBackgroundTaskInvalid;
		}
        
        // Get the movie url from video processor
        outputFileURL = movieURL;
        // Generate thumbnail picture
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:outputFileURL options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        NSError *err = NULL;
        CMTime time = CMTimeMake(1, 60);
        CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&err];
        UIImage *img = [[UIImage alloc] initWithCGImage:imgRef];
        NSData *thumbnailData = UIImagePNGRepresentation(img);
        
        // Initiate new video
        _newVideo = [[RCVideo alloc] init];
        _newVideo.fromUser = (RCUser*)[[FatFractal main] loggedInUser];
        _newVideo.toUser = _toUser;
        _newVideo.url = [NSString stringWithFormat:@"%@_%@_%@.mov", _currentUser.firstName, _toUser.firstName, [[self dateFormatter] stringFromDate:[NSDate date]]];
        _newVideo.thumbnailURL = [NSString stringWithFormat:@"%@_%@_%@.png", _currentUser.firstName, _toUser.firstName, [[self dateFormatter] stringFromDate:[NSDate date]]];
        
#warning - Need to send to AWS first
        dispatch_async(dispatch_get_main_queue(), ^{
            _uploadStateThumbnail = UploadStateThumbnailStarted;
            _uploadStateVideo = UploadStateVideoStarted;
            _uploadState = UploadStateUploading;
            
            [self putNewThumbNailWithData:thumbnailData fileName:_newVideo.thumbnailURL toBucket:[RCConstant transferManagerBucket] delegate:self];
            [self putNewVideoWithData:[NSData dataWithContentsOfURL:outputFileURL] fileName:_newVideo.url toBucket:[RCConstant transferManagerBucket] delegate:self];
        });
	});
}

- (void)pixelBufferReadyForDisplay:(CVPixelBufferRef)pixelBuffer {
	// Don't make OpenGLES calls while in the background.
	if ( [UIApplication sharedApplication].applicationState != UIApplicationStateBackground )
		[oglView displayPixelBuffer:pixelBuffer];
}

#pragma mark - Public methods
- (void)refresh {
    DBGMSG(@"%s", __func__);
    if ([[FatFractal main] loggedInUser]) {
        _currentUser = (RCUser*)[[FatFractal main] loggedInUser];
        [self refreshTableAndLoadData];
    }
}

- (void)refreshTableAndLoadData {
    DBGMSG(@"%s", __func__);
    // Clean videos array
    if (_videos || _videoURLs) {
        [_videos removeAllObjects];
        _videos = nil;
        [_videoURLs removeAllObjects];
        _videoURLs = nil;
    }
    [self fetchFromBackend];
}


#pragma mark - AVFoundation
/*
- (void)initializeCameraFor:(CurrentUserCell*)cell {
    DBGMSG(@"%s", __func__);
    [_avCapturesession beginConfiguration];
    _avCapturesession.sessionPreset = AVCaptureSessionPresetLow;
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_avCapturesession];
    [_captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    cell.videoView.hidden = YES;
    cell.userNameLabel.text = _currentUser.firstName;
    
    _captureVideoPreviewLayer.frame = cell.videoPreview.bounds;
    [cell.videoPreview.layer addSublayer:_captureVideoPreviewLayer];
    
    [cell.videoPreview.layer setMasksToBounds:YES];

    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    AVCaptureDevice *audioDevice;
    
    for (AVCaptureDevice *device in devices) {
        NSLog(@"Device name: %@", [device localizedName]);
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                NSLog(@"Device position : back");
                backCamera = device;
            }
            else {
                NSLog(@"Device position : front");
                frontCamera = device;
            }
        } else if ([device hasMediaType:AVMediaTypeAudio]) {
            audioDevice = device;
        }
    }
    
    // Set device input
    if (_videoDeviceInput) {
        [_avCapturesession removeInput:_videoDeviceInput];
        _videoDeviceInput = nil;
    }
    NSError *error = nil;
    if (!isFrontCamera) {
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!_videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [_avCapturesession addInput:_videoDeviceInput];
    } else {
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!_videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [_avCapturesession addInput:_videoDeviceInput];
    }
    
    if (_audioDeviceInput) {
        [_avCapturesession removeInput:_audioDeviceInput];
        _audioDeviceInput = nil;
    }
    _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    [_avCapturesession addInput:_audioDeviceInput];
    
    // Init deviceOutput
    if (!_stillImageOutput) {
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [stillImageOutput setOutputSettings:outputSettings];
        [self setStillImageOutput:stillImageOutput];
        [_avCapturesession addOutput:_stillImageOutput];
    }
    
    if (!_movieFileOutput) {
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        [self setMovieFileOutput:movieFileOutput];
        AVCaptureConnection *connection = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported])
            [connection setEnablesVideoStabilizationWhenAvailable:YES];
        [_avCapturesession addOutput:_movieFileOutput];
    }
    [_avCapturesession commitConfiguration];
}
*/
- (IBAction)switchCamera:(id)sender {
    DBGMSG(@"%s", __func__);
    
    if (_cameraSwitchButton.isOn) {
        isFrontCamera = YES;
    }
    else {
        isFrontCamera = NO;
    }
    [videoProcessor toggleCameraIsFront:isFrontCamera];
}

#warning Need to implement
- (void)playVideoAtIndex:(NSInteger)indexPath {
    
}


#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    DBGMSG(@"%s", __func__);
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    DBGMSG(@"%s videos.count = %d", __func__, _videos.count);
    return _videos.count;
}

/*
- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)tableView.tableFooterView;
    
    footerView.userNameLabel.text = _currentUser.firstName;
    
    [_avCapturesession beginConfiguration];
    _avCapturesession.sessionPreset = AVCaptureSessionPresetLow;
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_avCapturesession];
    [_captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    _captureVideoPreviewLayer.frame = footerView.previewView.bounds;
    [footerView.previewView.layer addSublayer:_captureVideoPreviewLayer];
    
    [footerView.previewView.layer setMasksToBounds:YES];
    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    AVCaptureDevice *audioDevice;
    
    for (AVCaptureDevice *device in devices) {
        NSLog(@"Device name: %@", [device localizedName]);
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                NSLog(@"Device position : back");
                backCamera = device;
            }
            else {
                NSLog(@"Device position : front");
                frontCamera = device;
            }
        } else if ([device hasMediaType:AVMediaTypeAudio]) {
            audioDevice = device;
        }
    }
    
    // Set device input
    if (_videoDeviceInput) {
        [_avCapturesession removeInput:_videoDeviceInput];
        _videoDeviceInput = nil;
    }
    NSError *error = nil;
    if (!isFrontCamera) {
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!_videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [_avCapturesession addInput:_videoDeviceInput];
    } else {
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!_videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [_avCapturesession addInput:_videoDeviceInput];
    }
    
    if (_audioDeviceInput) {
        [_avCapturesession removeInput:_audioDeviceInput];
        _audioDeviceInput = nil;
    }
    _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    [_avCapturesession addInput:_audioDeviceInput];
    
    // Init deviceOutput
    if (!_stillImageOutput) {
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [stillImageOutput setOutputSettings:outputSettings];
        [self setStillImageOutput:stillImageOutput];
        [_avCapturesession addOutput:_stillImageOutput];
    }
    
    if (!_movieFileOutput) {
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        [self setMovieFileOutput:movieFileOutput];
        AVCaptureConnection *connection = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported])
            [connection setEnablesVideoStabilizationWhenAvailable:YES];
        [_avCapturesession addOutput:_movieFileOutput];
    }
    [_avCapturesession commitConfiguration];
    
    return footerView;
}
*/

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBGMSG(@"%s", __func__);
    static NSString *cellIdentifier;
    RCVideo *videoForCell = _videos[indexPath.row];
    BOOL isCurrentUser = [videoForCell.fromUser.guid isEqualToString:_currentUser.guid];
    cellIdentifier = (isCurrentUser) ? @"currentUserCell" : @"toUserCell";
    
    UITableViewCell *cell;
    
    if (isCurrentUser) {
        CurrentUserCell *cell = (CurrentUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        cell.videoView.hidden = NO;
        cell.userNameLabel.text = videoForCell.fromUser.firstName;
        
        UIImage *thumbnailImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[self s3URLForThumbnailOfVideo:videoForCell]]];
        UIImageView *thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cell.videoView.frame.size.width, cell.videoView.frame.size.height)];
        thumbnailImageView.image = thumbnailImage;
        [cell.videoView addSubview:thumbnailImageView];
        
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone]; // Disable animation of cell selection
        
        return cell;
    } else {
        ToUserCell *cell = (ToUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        cell.videoView.hidden = NO;
        cell.userNameLabel.text = videoForCell.fromUser.firstName;
        
        UIImage *thumbnailImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[self s3URLForThumbnailOfVideo:videoForCell]]];
        UIImageView *thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cell.videoView.frame.size.width, cell.videoView.frame.size.height)];
        thumbnailImageView.image = thumbnailImage;
        [cell.videoView addSubview:thumbnailImageView];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone]; // Disable animation of cell selection
        
        return cell;
    }
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
#warning Need to implement
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    RCVideo *videoForCell = _videos[indexPath.row];
    BOOL isCurrentUser = [videoForCell.fromUser.guid isEqualToString:_currentUser.guid];
    
    if (currentSelectedCell >= 0) {
        [_avPlayer pause];
        [_avPlayerLayer removeFromSuperlayer];
    }
    currentSelectedCell = indexPath.row;
    
    AVAsset *newAsset = [AVURLAsset URLAssetWithURL:[self s3URLForVideo:videoForCell] options:nil];
    AVPlayerItem *newPlayerItem = [AVPlayerItem playerItemWithAsset:newAsset];
    if ([_avPlayer currentItem]) {
        [_avPlayer replaceCurrentItemWithPlayerItem:newPlayerItem];
    } else {
        _avPlayer = [AVPlayer playerWithPlayerItem:newPlayerItem];
    }
    _avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];
    
    if (isCurrentUser) {
        CurrentUserCell *cell = (CurrentUserCell*)[tableView cellForRowAtIndexPath:indexPath];
        cell.videoView.hidden = NO;
        _avPlayerLayer.frame = cell.videoView.bounds;
        [cell.videoView.layer addSublayer:_avPlayerLayer];
    } else {
        ToUserCell *cell = (ToUserCell*)[tableView cellForRowAtIndexPath:indexPath];
        cell.videoView.hidden = NO;
        _avPlayerLayer.frame = cell.videoView.bounds;
        [cell.videoView.layer addSublayer:_avPlayerLayer];
    }
    [_avPlayer play];
}

- (void)scrollToLastCell {
    if (_videos.count > 0) {
        NSInteger lastRowNumber = [threadTableView numberOfRowsInSection:0] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:lastRowNumber inSection:0];
        [threadTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

#pragma mark - Data fetch

- (void)fetchFromBackend {
    DBGMSG(@"%s", __func__);
    __block BOOL blockComplete = NO;
    [[FatFractal main] getArrayFromExtension:[NSString stringWithFormat:@"/getVideos?guids=%@,%@",_currentUser.guid, _toUser.guid] onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theObj) {
            _videos = (NSMutableArray*)theObj;
            _videoURLs = [[NSMutableArray alloc] init];
            
            for (RCVideo *video in _videos) {
                [_videoURLs addObject:[self s3URLForVideo:video]];
            }
            NSLog(@"Videos = %@ \n videoURLs = %@", _videos, _videoURLs);
#warning - Need to add notification here, then execute the following 2 lines of code outside
            [threadTableView reloadData];
            [self scrollToLastCell];
        }
        blockComplete = YES;
    }];
    
    while (!blockComplete) {
        NSDate* cycle = [NSDate dateWithTimeIntervalSinceNow:0.001];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:cycle];
    }
}

/*
#pragma mark - AVCaptureFileOutput delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)anOutputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    DBGMSG(@"%s - %@", __func__, anOutputFileURL);
    if (error)
		NSLog(@"%@", error);
    
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
//	UIBackgroundTaskIdentifier backgroundRecordingID = self.backgroundRecordingID;
//	[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    

    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"moview2" stringByAppendingPathExtension:@"mov"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    
    // input file
    AVAsset* asset = [AVAsset assetWithURL:anOutputFileURL];
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    [composition  addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    // input clip
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    // make it square
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.height, clipVideoTrack.naturalSize.height);
    videoComposition.frameDuration = CMTimeMake(1, 30);
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30) );
    
    // rotate to portrait
    AVMutableVideoCompositionLayerInstruction* transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(clipVideoTrack.naturalSize.height, -(clipVideoTrack.naturalSize.width - clipVideoTrack.naturalSize.height) /2 );
    CGAffineTransform t2 = CGAffineTransformRotate(t1, M_PI_2);
    
    CGAffineTransform finalTransform = t2;
    [transformer setTransform:finalTransform atTime:kCMTimeZero];
    instruction.layerInstructions = [NSArray arrayWithObject:transformer];
    videoComposition.instructions = [NSArray arrayWithObject: instruction];
    
    // export
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality] ;
    exporter.videoComposition = videoComposition;
    exporter.outputURL=[NSURL fileURLWithPath:outputPath];
    exporter.outputFileType=AVFileTypeQuickTimeMovie;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^(void){
        NSLog(@"Exporting done!");
        outputFileURL = exporter.outputURL;
        
        // Generate thumbnail picture
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:outputFileURL options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        NSError *err = NULL;
        CMTime time = CMTimeMake(1, 60);
        CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&err];
        UIImage *img = [[UIImage alloc] initWithCGImage:imgRef];
        NSData *thumbnailData = UIImagePNGRepresentation(img);
        
        
        _newVideo = [[RCVideo alloc] init];
        _newVideo.fromUser = (RCUser*)[[FatFractal main] loggedInUser];
        _newVideo.toUser = _toUser;
        _newVideo.url = [NSString stringWithFormat:@"%@_%@_%@.mov", _currentUser.firstName, _toUser.firstName, [[self dateFormatter] stringFromDate:[NSDate date]]];
        _newVideo.thumbnailURL = [NSString stringWithFormat:@"%@_%@_%@.png", _currentUser.firstName, _toUser.firstName, [[self dateFormatter] stringFromDate:[NSDate date]]];
        
#warning - Need to send to AWS first
        dispatch_async(dispatch_get_main_queue(), ^{
            _uploadStateThumbnail = UploadStateThumbnailStarted;
            _uploadStateVideo = UploadStateVideoStarted;
            _uploadState = UploadStateUploading;
            
            [self putNewThumbNailWithData:thumbnailData fileName:_newVideo.thumbnailURL toBucket:[RCConstant transferManagerBucket] delegate:self];
            [self putNewVideoWithData:[NSData dataWithContentsOfURL:outputFileURL] fileName:_newVideo.url toBucket:[RCConstant transferManagerBucket] delegate:self];
            
        });
    }];
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == RecordingContext) {
		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRecording) {
				[_recordButton setEnabled:YES];
                [_recordButton setTintColor:[UIColor redColor]];
			}
			else {
				[_recordButton setEnabled:YES];
                [_recordButton setTintColor:[UIColor blueColor]];
			}
		});
	}
}
*/

#pragma mark - AmazonServiceRequest delegate

- (void)putNewThumbNailWithData:(NSData*)thumbnailData fileName:(NSString*)uploadFileName toBucket:(NSString*)bucket delegate:(id)delegate {
    DBGMSG(@"%s - %@", __func__, uploadFileName);
    S3PutObjectRequest *putObjectRequest = [[S3PutObjectRequest alloc] initWithKey:uploadFileName inBucket:bucket];
    putObjectRequest.data = thumbnailData;
    putObjectRequest.delegate = delegate;
    putObjectRequest.requestTag = @"thumbnail";
    
    S3PutObjectResponse *response = [[AmazonClientManager s3] putObject:putObjectRequest];
    if (response.error != nil) {
        DBGMSG(@"%s error = %@", __func__, response.error.description);
    }
}

- (void)putNewVideoWithData:(NSData*)recordedVideoData fileName:(NSString*)uploadFileName toBucket:(NSString*)bucket delegate:(id)delegate {
    DBGMSG(@"%s - %@", __func__, uploadFileName);
    S3PutObjectRequest *putObjectRequest = [[S3PutObjectRequest alloc] initWithKey:uploadFileName inBucket:bucket];
    putObjectRequest.data = recordedVideoData;
    putObjectRequest.delegate = delegate;
    putObjectRequest.requestTag = @"video";
    
    S3PutObjectResponse *response = [[AmazonClientManager s3] putObject:putObjectRequest];
    if (response.error != nil) {
        DBGMSG(@"%s error = %@", __func__, response.error.description);
    }
}

- (NSURL*)s3URLForVideo:(RCVideo*)video {
    DBGMSG(@"%s", __func__);
    // Init connection with S3Client
    AmazonS3Client *s3Client = [AmazonClientManager s3];
    @try {
        // Set the content type so that the browser will treat the URL as an image.
        S3ResponseHeaderOverrides *override = [[S3ResponseHeaderOverrides alloc] init];
        override.contentType = @" ";
        // Request a pre-signed URL to picture that has been uploaded.
        S3GetPreSignedURLRequest *gpsur = [[S3GetPreSignedURLRequest alloc] init];
        // Video name
        gpsur.key = [NSString stringWithFormat:@"%@", video.url];
        //bucket name
        gpsur.bucket  = [RCConstant transferManagerBucket];
        // Added an hour's worth of seconds to the current time.
        gpsur.expires = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval) 3600];
        
        gpsur.responseHeaderOverrides = override;
        
        // Get the URL
        NSError *error;
        NSURL *url = [s3Client getPreSignedURL:gpsur error:&error];
        return url;
    }
    @catch (NSException *exception) {
        NSLog(@"Cannot list S3 %@",exception);
    }
}

- (NSURL*)s3URLForThumbnailOfVideo:(RCVideo*)video {
    DBGMSG(@"%s", __func__);
    // Init connection with S3Client
    AmazonS3Client *s3Client = [AmazonClientManager s3];
    @try {
        // Set the content type so that the browser will treat the URL as an image.
        S3ResponseHeaderOverrides *override = [[S3ResponseHeaderOverrides alloc] init];
        override.contentType = @" ";
        // Request a pre-signed URL to picture that has been uploaded.
        S3GetPreSignedURLRequest *gpsur = [[S3GetPreSignedURLRequest alloc] init];
        // Video name
        gpsur.key = [NSString stringWithFormat:@"%@", video.thumbnailURL];
        //bucket name
        gpsur.bucket  = [RCConstant transferManagerBucket];
        // Added an hour's worth of seconds to the current time.
        gpsur.expires = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval) 3600];
        
        gpsur.responseHeaderOverrides = override;
        
        // Get the URL
        NSError *error;
        NSURL *url = [s3Client getPreSignedURL:gpsur error:&error];
        return url;
    }
    @catch (NSException *exception) {
        NSLog(@"Cannot list S3 %@",exception);
    }
}


-(void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)response {
    DBGMSG(@"%s - %@", __func__, response);
}

-(void)request:(AmazonServiceRequest *)request didSendData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten totalBytesExpectedToWrite:(long long)totalBytesExpectedToWrite {
    if ([MBProgressHUD allHUDsForView:self.view].count == 0)
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    double percent = ((double)totalBytesWritten/(double)totalBytesExpectedToWrite)*100;
    NSLog(@"totalBytesWritten = %.2f%%", percent);
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response {
    DBGMSG(@"%s - %@", __func__, response);
    
    
    if ([request.requestTag isEqualToString:@"video"]) {
        _uploadStateVideo = UploadStateVideoFinished;
        NSLog(@"change upload state video");
    }
    
    if ([request.requestTag isEqualToString:@"thumbnail"]) {
        _uploadStateThumbnail = UploadStateThumbnailFinished;
        NSLog(@"change upload state thumbnail");
    }
    
    
    if (_uploadStateVideo == UploadStateVideoFinished && _uploadStateThumbnail == UploadStateThumbnailFinished) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        [[FatFractal main] createObj:_newVideo atUri:@"/RCVideo" onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
            if (theErr)
                NSLog(@"%@", theErr);
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
            if (_backgroundRecordingID != UIBackgroundTaskInvalid)
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];
            
            NSError *error = nil;
            [[FatFractal main] grabBagAdd:(RCUser*)[[FatFractal main] loggedInUser] to:theObj  grabBagName:@"users" error:&error];
            [[FatFractal main] grabBagAdd:_toUser to:theObj grabBagName:@"users" error:&error];
            if (error)
                NSLog(@"Add grabbag error %@", error);
            [self fetchFromBackend];
        }];
    }
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error {
    DBGMSG(@"%s - %@", __func__, error);
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)exception {
    DBGMSG(@"%s - %@", __func__, exception);
}

/*
#pragma mark - Movie Player

- (void)moviePlayBackDidFinish:(NSNotification *)notification {
    DBGMSG(@"%s - %@", __func__, notification);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
}

- (void)willEnterFullScreen:(NSNotification *)notification {
    DBGMSG(@"%s - %@", __func__, notification);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidEnterFullscreenNotification object:nil];
}
*/

# pragma mark - Helper
- (NSDateFormatter*)dateFormatter {
    static NSDateFormatter *_dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd-HH:mm"];
    });
    return _dateFormatter;
}

@end
