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
#import "RCVideo.h"
#import "RCUtility.h"
#import "RCConstant.h"
#import <AWSRuntime/AWSRuntime.h>
#import "MBProgressHUD.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;

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
@property (weak, nonatomic) IBOutlet RCCamPreviewView *videoPreview;
@end

@implementation CurrentUserCell
@synthesize userProfilePicture, videoView, videoPreview;
@end


@interface RCDetailViewController () <AVCaptureFileOutputRecordingDelegate>

@property (strong, nonatomic) RCUser *currentUser;
@property (nonatomic) NSMutableArray *videos;
@property (nonatomic, getter = getNewVideo) RCVideo *newVideo;
//@property (nonatomic) NSNumber *lastRefreshTime;

@property (strong, nonatomic) IBOutlet UISwitch *cameraSwitch;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordButton;

- (void)configureView;

// Session Management
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

#warning - Need to implement these properties
// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@end

@implementation RCDetailViewController {
    IBOutlet UITableView *threadTableView;
    NSURL *outputFileURL;
    BOOL isFrontCamera;
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
    if (_toUser) {
        self.title = _toUser.firstName;
    }
    
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    self.session.sessionPreset = AVCaptureSessionPresetLow;
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    // Set up session queue
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
}


- (void)viewDidLoad {
    [super viewDidLoad];
	
    [self fetchFromBackend];
    
    [self configureView];
    
    [self refresh];
    
    isFrontCamera = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    dispatch_async(self.sessionQueue, ^{
        
        [self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        [self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
        
        __weak RCDetailViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
			RCDetailViewController *strongSelf = weakSelf;
			dispatch_async(strongSelf.sessionQueue, ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[strongSelf.session startRunning];
			});
		}]];
		[[self session] startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[self.session stopRunning];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
	});
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordButtonPushed:(id)sender {
    
    [self.recordButton setEnabled:NO];
    
    dispatch_async(self.sessionQueue, ^{
        if (![self.movieFileOutput isRecording]) {
            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
            }
            
            // Turning OFF flash for video recording
#warning - Need to implement
            
            // Start recording to a temporary file
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"moview" stringByAppendingPathExtension:@"mov"]];
            [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
            
            
        } else {
            [self.movieFileOutput stopRecording];
        }
    });
}

#pragma mark - Public methods
- (void)refresh {
    DBGMSG(@"%s", __func__);
    if ([[FatFractal main] loggedInUser]) {
        self.currentUser = (RCUser*)[[FatFractal main] loggedInUser];
        [self refreshTableAndLoadData];
    }
}

- (void)refreshTableAndLoadData {
    DBGMSG(@"%s", __func__);
    // Clean videos array
    if (_videos) {
        [_videos removeAllObjects];
        _videos = nil;
    }
    [self fetchFromBackend];
}


#pragma mark - AVFoundation

- (void)initializeCameraFor:(CurrentUserCell*)cell {
    DBGMSG(@"%s", __func__);
    cell.videoView.hidden = YES;
    cell.userNameLabel.text = self.currentUser.firstName;
    
    self.captureVideoPreviewLayer.frame = cell.videoPreview.bounds;
    [cell.videoPreview.layer addSublayer:self.captureVideoPreviewLayer];
    
    [cell.videoPreview.layer setMasksToBounds:YES];

    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
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
        }
    }
    
    // Set device input
    if (self.videoDeviceInput) {
        [self.session removeInput:self.videoDeviceInput];
        self.videoDeviceInput = nil;
    }
    NSError *error = nil;
    if (!isFrontCamera) {
        self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!self.videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [self.session addInput:self.videoDeviceInput];
    } else {
        self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!self.videoDeviceInput) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [self.session addInput:self.videoDeviceInput];
    }
    
    // Init deviceOutput
    if (!self.stillImageOutput) {
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [self.stillImageOutput setOutputSettings:outputSettings];
        
        [self.session addOutput:self.stillImageOutput];
    }
    
    if (!self.movieFileOutput) {
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported])
            [connection setEnablesVideoStabilizationWhenAvailable:YES];
        [self.session addOutput:self.movieFileOutput];
    }
}

- (IBAction)switchCamera:(id)sender {
    DBGMSG(@"%s", __func__);
    if (_cameraSwitch.isOn) {
        isFrontCamera = YES;
        [threadTableView reloadData];
    }
    else {
        isFrontCamera = NO;
        [threadTableView reloadData];
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
    return _videos.count + 1;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBGMSG(@"%s", __func__);
    static NSString *cellIdentifier;
    // Configure last cell
    if (indexPath.row == _videos.count) {
        NSLog(@"Last cell");
        
        cellIdentifier = @"currentUserCell";
        CurrentUserCell *cell = (CurrentUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        [self initializeCameraFor:cell];
        
        return cell;
        
    } else {
        NSLog(@"Not last cell");
        
        RCVideo *videoForCell = _videos[indexPath.row];
        BOOL isCurrentUser = [videoForCell.fromUser.guid isEqualToString:self.currentUser.guid];
        cellIdentifier = (isCurrentUser) ? @"currentUserCell" : @"toUserCell";
        
        if (isCurrentUser) {
            CurrentUserCell *cell = (CurrentUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            cell.videoPreview.hidden = YES;
            cell.userNameLabel.text = videoForCell.fromUser.firstName;
            return cell;
        } else {
            ToUserCell *cell = (ToUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            cell.userNameLabel.text = videoForCell.fromUser.firstName;
            return cell;
        }
    }
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    #warning Need to implement
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Data fetch

- (void)fetchFromBackend {
    //    __block BOOL blockComplete = NO;
    [[FatFractal main] getArrayFromExtension:[NSString stringWithFormat:@"/getVideos?guids=%@,%@",self.currentUser.guid, self.toUser.guid] onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        //        STAssertNil(theErr, @"Got error from extension: %@", [theErr localizedDescription]);
        if (theObj) {
            _videos = (NSMutableArray*)theObj;
            NSLog(@"Videos = %@", _videos);
            [threadTableView reloadData];
        }
        /*
        STAssertTrue([conversations count] == 1, @"Expected 1 conversation, got %d", [conversations count]);
        NSLog(@"Conversations: \n%@", conversations);
        blockComplete = YES;
        */
    }];
    /*
    while (!blockComplete) {
        NSDate* cycle = [NSDate dateWithTimeIntervalSinceNow:0.001];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:cycle];
    }
     */
}

#pragma mark - AVCaptureFileOutput delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)anOutputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    if (error)
		NSLog(@"%@", error);
    
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
	UIBackgroundTaskIdentifier backgroundRecordingID = self.backgroundRecordingID;
	[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    
    _newVideo = [[RCVideo alloc] init];
    _newVideo.fromUser = (RCUser*)[[FatFractal main] loggedInUser];
    _newVideo.toUser = self.toUser;
    _newVideo.url = [NSString stringWithFormat:@"%@_%@_%@.mov", self.currentUser.firstName, self.toUser.firstName, [[self dateFormatter] stringFromDate:[NSDate date]]];
#warning - Need to send to AWS first
    outputFileURL = anOutputFileURL;
    [RCUtility putNewVideoWithData:[NSData dataWithContentsOfURL:outputFileURL] fileName:_newVideo.url toBucket:[RCConstant transferManagerBucket] delegate:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == RecordingContext) {
		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRecording) {
				[self.recordButton setEnabled:YES];
                [self.recordButton setTintColor:[UIColor redColor]];
			}
			else {
				[self.recordButton setEnabled:YES];
                [self.recordButton setTintColor:[UIColor blueColor]];
			}
		});
	}
}

#pragma mark - AmazonServiceRequest delegate

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
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    
    [[FatFractal main] createObj:_newVideo atUri:@"/RCVideo" onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theErr)
			NSLog(@"%@", theErr);
		
		[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
		
		if (_backgroundRecordingID != UIBackgroundTaskInvalid)
			[[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];
        NSError *error = nil;
        [[FatFractal main] grabBagAdd:(RCUser*)[[FatFractal main] loggedInUser] to:theObj  grabBagName:@"users" error:&error];
        [[FatFractal main] grabBagAdd:self.toUser to:theObj grabBagName:@"users" error:&error];
        if (error)
            NSLog(@"Add grabbag error %@", error);
    }];
	/*
    [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
    	if (error)
    		NSLog(@"%@", error);
    
    	[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
    
    	if (backgroundRecordingID != UIBackgroundTaskInvalid)
    		[[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
    }];
     */
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error {
    DBGMSG(@"%s - %@", __func__, error);
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)exception {
    DBGMSG(@"%s - %@", __func__, exception);
}

# pragma mark - Helper
- (NSDateFormatter*)dateFormatter {
    static NSDateFormatter *_dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"HH:mm"];
    });
    return _dateFormatter;
}

@end
