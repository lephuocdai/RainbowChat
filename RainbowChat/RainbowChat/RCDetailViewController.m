//
//  RCDetailViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCDetailViewController.h"
#import "RCCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>
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
@property (nonatomic) IBOutlet RCCamPreviewView *videoPreview;
@end

@implementation RCCamPreviewFooter
@synthesize userNameLabel, userProfilePicture, videoPreview;
@end

@interface RCDetailViewController () <AVCaptureFileOutputRecordingDelegate>

@property (strong, nonatomic) RCUser *currentUser;
@property (nonatomic) NSMutableArray *videos;
@property (nonatomic) NSMutableArray *videoURLs;
@property (nonatomic, getter = getNewVideo) RCVideo *newVideo;
@property (nonatomic) AVPlayer *avPlayer;
@property (nonatomic) AVPlayerLayer *avPlayerLayer;
//@property (nonatomic) NSNumber *lastRefreshTime;

@property (strong, nonatomic) IBOutlet UISwitch *cameraSwitch;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordButton;

- (void)configureView;

// Session Management
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *avCapturesession;
@property (nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

#warning - Need to implement these properties
// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@property (nonatomic, readwrite) UploadState uploadState;
@property (nonatomic, readwrite) UploadStateThumbnail uploadStateThumbnail;
@property (nonatomic, readwrite) UploadStateVideo uploadStateVideo;

@end

@implementation RCDetailViewController {
    IBOutlet UITableView *threadTableView;
    // Table view footer
    
    
    NSURL *outputFileURL;
    BOOL isFrontCamera;
    NSInteger currentSelectedCell;
}

#pragma mark - View life cycle

- (void)setToUser:(RCUser *)toUser {
    if (_toUser != toUser) {
        _toUser = toUser;
        
        // Update the view.
        [self configureView];
    }
}


- (void)configureView {
    if (_toUser)
        self.title = _toUser.firstName;
    
    // Set up AVPlayer
    _avPlayer = [[AVPlayer alloc] init];
    _avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];
    
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setAvCapturesession:session];
    // Set up session queue
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
}


- (void)viewDidLoad {
    [super viewDidLoad];
	
    currentSelectedCell = -1;
    
    [self configureView];
    
    [self refresh];
    
    isFrontCamera = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];
    
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
}

- (void)viewDidDisappear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];
	dispatch_async(_sessionQueue, ^{
		[_avCapturesession stopRunning];
        
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
	});
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordButtonPushed:(id)sender {
    
    [_recordButton setEnabled:NO];
    
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
    if (_cameraSwitch.isOn) {
        isFrontCamera = YES;
        [threadTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_videos.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
//        [self initializeCameraFor:(CurrentUserCell *)[threadTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_videos.count inSection:0]]];
    }
    else {
        isFrontCamera = NO;
        [threadTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_videos.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
//        [self initializeCameraFor:(CurrentUserCell *)[threadTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_videos.count inSection:0]]];
    }
}

#warning Need to implement
- (void)startRecord {
    
}
#warning Need to implement
- (void)stopRecord {
    
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

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)tableView.tableFooterView;
    
    footerView.userNameLabel.text = _currentUser.firstName;
    
    [_avCapturesession beginConfiguration];
    _avCapturesession.sessionPreset = AVCaptureSessionPresetLow;
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_avCapturesession];
    [_captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    _captureVideoPreviewLayer.frame = footerView.videoPreview.bounds;
    [footerView.videoPreview.layer addSublayer:_captureVideoPreviewLayer];
    
    [footerView.videoPreview.layer setMasksToBounds:YES];
    
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
            //        [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
            //            if (error)
            //                NSLog(@"%@", error);
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
            if (_backgroundRecordingID != UIBackgroundTaskInvalid)
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];
            //        }];
            
            NSError *error = nil;
            [[FatFractal main] grabBagAdd:(RCUser*)[[FatFractal main] loggedInUser] to:theObj  grabBagName:@"users" error:&error];
            [[FatFractal main] grabBagAdd:_toUser to:theObj grabBagName:@"users" error:&error];
            if (error)
                NSLog(@"Add grabbag error %@", error);
        }];
    }
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error {
    DBGMSG(@"%s - %@", __func__, error);
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)exception {
    DBGMSG(@"%s - %@", __func__, exception);
}

#pragma mark - Movie Player

- (void)moviePlayBackDidFinish:(NSNotification *)notification {
    DBGMSG(@"%s - %@", __func__, notification);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
}

- (void)willEnterFullScreen:(NSNotification *)notification {
    DBGMSG(@"%s - %@", __func__, notification);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidEnterFullscreenNotification object:nil];
}

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
