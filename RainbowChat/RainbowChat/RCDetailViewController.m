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
#import "RCConstant.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AWSS3.h>
#import "AmazonClientManager.h"
#import "MBProgressHUD.h"
#import "RCAppDelegate.h"

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
@property (nonatomic) IBOutlet UIView *opponentVideoView;
@property (nonatomic) IBOutlet UIView *myVideoView;
@end

@implementation RCCamPreviewFooter
@synthesize userNameLabel, userProfilePicture, previewView, opponentVideoView, myVideoView;
@end


@interface RCDetailViewController ()
@property (nonatomic) NSMutableArray *videos;
@property (nonatomic) NSMutableArray *videoURLs;
@property (nonatomic) NSNumber *lastRefreshTime;

@property (nonatomic, getter = getNewVideo) RCVideo *newVideo;
@property (nonatomic) AVPlayer *avPlayer;
@property (nonatomic) AVPlayerLayer *avPlayerLayer;
@property (strong, nonatomic) IBOutlet UISwitch *cameraSwitchButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordButton;

// Utilities.
#warning - Need to implement these properties
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;

@property (nonatomic, readwrite) UploadState uploadState;
@property (nonatomic, readwrite) UploadStateThumbnail uploadStateThumbnail;
@property (nonatomic, readwrite) UploadStateVideo uploadStateVideo;
@end

//static inline double radians (double degrees) { return degrees * (M_PI / 180); }

@implementation RCDetailViewController {
    IBOutlet UITableView *threadTableView;
    // Table view footer
    
    NSURL *outputFileURL;
    BOOL useBackCamera;
    NSInteger currentSelectedCell;
}

@synthesize lastRefreshTime = _lastRefreshTime;
@synthesize quickbloxID_currentuser;
@synthesize quickbloxID_opponentID;

#pragma mark - User login

- (NSNumber *)lastRefreshTime {
    if (_lastRefreshTime)
        return _lastRefreshTime;
    
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    _lastRefreshTime = [d valueForKey:@"lastRefreshTime"];
    if (! _lastRefreshTime) {
        [self setLastRefreshTime:[NSNumber numberWithLongLong:0]];
    }
    return _lastRefreshTime;
}

- (void)setLastRefreshTime:(NSNumber *)lastRefreshTime {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setValue:lastRefreshTime forKey:@"lastRefreshTime"];
    _lastRefreshTime = lastRefreshTime;
    [d synchronize];
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
		[videoProcessor setReferenceOrientation:(AVCaptureVideoOrientation)orientation];
}

- (void)setToUser:(RCUser *)toUser {
    if (_toUser != toUser) {
        _toUser = toUser;
        
        // Update the view.
        [self setVideoMessageView];
    }
}

#pragma mark - View life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    currentSelectedCell = -1;
    
    [self setVideoMessageView];
}

- (void)setVideoMessageView {
    DBGMSG(@"%s", __func__);
    if (_toUser)
        self.title = _toUser.firstName;

    // Set up AVPlayer
    _avPlayer = [[AVPlayer alloc] init];
    _avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];

    
    // Initialize the class responsible for managing AV capture session and asset writer
    videoProcessor = [[RCVideoProcessor alloc] init];
    videoProcessor.delegate = self;
    
    // Keep track of changes to the device orientation so we can update the video processor
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    // Setup and start the capture session
    [videoProcessor setupAndStartCaptureSession];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
    
    // Create an OpenGLView instance to display the captured video in the view
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.userNameLabel.text = _currentUser.firstName;
    
    
    oglView = [[RCPreviewView alloc] initWithFrame:footerView.previewView.bounds];
    // Force orientation to portrait
    oglView.transform = [videoProcessor transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)UIInterfaceOrientationPortrait];
    [((RCCamPreviewFooter*)threadTableView.tableFooterView).previewView addSubview:oglView];
    [footerView.previewView.layer setMasksToBounds:YES];
    
    
    // Quickblox setting
    footerView.opponentVideoView.hidden = YES;
    footerView.myVideoView.hidden = YES;
    callButton.title = @"Call";
    isCalling = NO;
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
    
    // Quickblox
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.myVideoView = nil;
    footerView.opponentVideoView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];

}

- (void)viewDidAppear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewDidAppear:animated];
    
    // Start sending chat presence
    [QBChat instance].delegate = self;
    [NSTimer scheduledTimerWithTimeInterval:30 target:[QBChat instance] selector:@selector(sendPresence) userInfo:nil repeats:YES];
    
    if ([[FatFractal main] loggedInUser]) {
        [[FatFractal main] registerClass:[RCUser class] forClazz:@"FFUser"];
        self.currentUser = (RCUser*)[[FatFractal main] loggedInUser];
    }
    
    [self fetchFromBackend];
    
    useBackCamera = NO;
    [self setQuickbloxID];
}

- (void)viewDidDisappear:(BOOL)animated {
    DBGMSG(@"%s", __func__);
    [super viewWillDisappear:animated];
}

- (IBAction)recordButtonPushed:(id)sender {
    DBGMSG(@"%s", __func__);
    [self sendVideoMessage];
}
- (IBAction)refreshButtonPushed:(id)sender {
    [self refresh];
}
- (IBAction)callButtonPushed:(id)sender {
    DBGMSG(@"%s", __func__);
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    
    // Call
    if(callButton.tag == 101){
        callButton.tag = 102;
        
        // Show call
        footerView.opponentVideoView.hidden = NO;
        footerView.myVideoView.hidden = NO;
        
        [self sendCallNotification];
        
        callButton.enabled = NO;
        callButton.title = @"Calling";
        
        isCalling = YES;
        // Finish
    }else{
        callButton.tag = 101;
        
        // Finish call
        [self.videoChat finishCall];
        footerView.myVideoView.hidden = YES;
        footerView.opponentVideoView.hidden = YES;
        [self setVideoMessageView];
        
        // release video chat
        [[QBChat instance] unregisterVideoChatInstance:self.videoChat];
        self.videoChat = nil;
        isCalling = NO;
    }
}

- (void)callOrStop {
    DBGMSG(@"%s", __func__);
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    // Call
    if(callButton.tag == 101){
        callButton.tag = 102;
        
        // Show call
        footerView.opponentVideoView.hidden = NO;
        footerView.myVideoView.hidden = NO;
        
        // Setup video chat
        if(self.videoChat == nil){
            self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
            self.videoChat.viewToRenderOpponentVideoStream = footerView.opponentVideoView;
            self.videoChat.viewToRenderOwnVideoStream = footerView.myVideoView;
        }
        
        // Set Audio & Video output
        self.videoChat.useHeadphone = NO;
        self.videoChat.useBackCamera = useBackCamera;
        
        // Call user by ID
        NSLog(@"quickbloxID_opponentID = %@", quickbloxID_opponentID);
        [self.videoChat callUser:[quickbloxID_opponentID integerValue] conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
        
        callButton.enabled = NO;
        callButton.title = @"Calling";
        
        isCalling = YES;
        // Finish
    }else{
        callButton.tag = 101;
        
        // Finish call
        [self.videoChat finishCall];
        footerView.myVideoView.hidden = YES;
        footerView.opponentVideoView.hidden = YES;
        [self setVideoMessageView];
        
        // release video chat
        [[QBChat instance] unregisterVideoChatInstance:self.videoChat];
        self.videoChat = nil;
        isCalling = NO;
    }
}

- (void)sendVideoMessage {
    DBGMSG(@"%s", __func__);
    if ( [videoProcessor isRecording] ) {
		// The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
		[videoProcessor stopRecording];
	}
	else {
		// The recordingWill/DidStart delegate methods will fire asynchronously in response to this call
        [videoProcessor startRecording];
	}
}

- (void)sendCallNotification {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = @"Calling...";
    hud.dimBackground = YES;
    hud.yOffset = -77;
    
    [[FatFractal main] getObjFromUrl:[NSString stringWithFormat:@"/ff/ext/call?guid=%@", _toUser.guid] onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theErr) {
            NSLog(@"StatsViewController getStats failed: %@", [theErr localizedDescription]);
            return;
        } else {
            NSString *message = (NSString*)theObj;
            NSLog(@"Sent message = %@", message);
        }
    }];
}

#pragma mark - RCVideoProcessorDelegate

- (void)recordingWillStart {
    DBGMSG(@"%s", __func__);
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
    DBGMSG(@"%s", __func__);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recordButton setEnabled:YES];
        [_recordButton setTintColor:[UIColor redColor]];
    });
}

- (void)recordingWillStop {
    DBGMSG(@"%s", __func__);
    dispatch_async(dispatch_get_main_queue(), ^{
		// Disable until saving to the camera roll is complete
		[_recordButton setEnabled:NO];
		
		// Pause the capture session so that saving will be as fast as possible.
		// We resume the sesssion in recordingDidStop:
		[videoProcessor pauseCaptureSession];
	});
}

- (void)recordingDidStopWithMovieURL:(NSURL *)movieURL {
    DBGMSG(@"%s", __func__);
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
        _newVideo.fromUser = _currentUser;
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
- (IBAction)switchCamera:(id)sender {
    DBGMSG(@"%s", __func__);
    
    if (_cameraSwitchButton.isOn)
        useBackCamera = NO;
    else
        useBackCamera = YES;
    
    if (isCalling) {
        if (self.videoChat != nil)
            self.videoChat.useBackCamera = useBackCamera;
    } else
        [videoProcessor toggleCameraIsFront:useBackCamera];
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
    DBGMSG(@"%s videos.count = %lu", __func__, (unsigned long)_videos.count);
    return _videos.count;
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBGMSG(@"%s", __func__);
    static NSString *cellIdentifier;
    RCVideo *videoForCell = _videos[indexPath.row];
    BOOL isCurrentUser = [videoForCell.fromUser.guid isEqualToString:_currentUser.guid];
    cellIdentifier = (isCurrentUser) ? @"currentUserCell" : @"toUserCell";
    
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

- (void)fetchFromCoreData {
    DBGMSG(@"%s", __func__);
    
    /*
     Fetch existing videos.
     Create a fetch request for the RCVideo entity; add a sort descriptor; then execute the fetch.
     */
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"RCVideo"];
    [request setFetchBatchSize:20];
    
    // Order the events by creation date, most recent first.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [request setSortDescriptors:sortDescriptors];
    
    // Execute the fetch.
    NSError *error;
    NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:request error:&error];
    if (fetchResults == nil) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    // Set self's events array to a mutable copy of the fetch results.
    [self setVideos:[fetchResults mutableCopy]];
}

- (void)fetchChangesFromBackEnd {
    __block BOOL blockComplete = NO;
    [[FatFractal main] getArrayFromExtension:[NSString stringWithFormat:@"/getVideos?guids=%@,%@",_currentUser.guid, _toUser.guid] onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theErr) {
            NSLog(@"Failed to retrieve from backend: %@", theErr.localizedDescription);
        } else {
            if (theObj) {
                NSArray *retrieved = theObj;
                
                if (self.videos) {
                    [self.videos removeAllObjects];
                    self.videos = nil;
                }
                self.lastRefreshTime = [FFUtils unixTimeStampFromDate:[NSDate date]];
                self.videos = (NSMutableArray*)retrieved;
                [threadTableView reloadData];
                
                [self scrollToLastCell];
            }
        }
    }];
    while (!blockComplete) {
        NSDate* cycle = [NSDate dateWithTimeIntervalSinceNow:0.001];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:cycle];
    }
}

- (void)fetchFromBackend {
    DBGMSG(@"%s", __func__);
    __block BOOL blockComplete = NO;
    [[FatFractal main] getArrayFromExtension:[NSString stringWithFormat:@"/getVideos?guids=%@,%@",_currentUser.guid, _toUser.guid] onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theObj) {
            _videos = (NSMutableArray*)theObj;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                _videoURLs = [[NSMutableArray alloc] init];
                for (RCVideo *video in _videos) {
                    [_videoURLs addObject:[self s3URLForVideo:video]];
                }
            });
            
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

- (void)setQuickbloxID {
    DBGMSG(@"%s currentUser = %@, toUser =%@", __func__, self.currentUser, self.toUser);
    NSString *password = [[RCAppDelegate keychainItem] objectForKey:(__bridge id)(kSecValueData)];
    
    QBASessionCreationRequest *extendedAuthRequest = [QBASessionCreationRequest request];
    extendedAuthRequest.userLogin = self.currentUser.userName;
    extendedAuthRequest.userPassword = password;
    [QBAuth createSessionWithExtendedRequest:extendedAuthRequest delegate:self];
    
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    [self setQuickbloxID_currentuser:[f numberFromString:self.currentUser.quickbloxID]];
    [self setQuickbloxID_opponentID:[f numberFromString:self.toUser.quickbloxID]];
}

#pragma mark - QBActionStatusDelegate
// QuickBlox API queries delegate
- (void)completedWithResult:(Result *)result{
    DBGMSG(@"%s - result = %@", __func__, result);
    // QuickBlox session creation  result
    if([result isKindOfClass:[QBAAuthSessionCreationResult class]]){
        
        // Success result
        if(result.success){
            
            // Set QuickBlox Chat delegate
            [QBChat instance].delegate = self;
            
            QBUUser *user = [QBUUser user];
            user.ID = ((QBAAuthSessionCreationResult *)result).session.userID;
            user.password = [[RCAppDelegate keychainItem] objectForKey:(__bridge id)(kSecValueData)];
            
            // Login to QuickBlox Chat
            //
            [[QBChat instance] loginWithUser:user];
        }else{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[[result errors] description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
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
                NSLog(@"Save newVideo to Fatfractal error: %@", theErr);
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
            if (backgroundRecordingID != UIBackgroundTaskInvalid)
                [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
            
            NSError *error = nil;
            [[FatFractal main] grabBagAdd:self.currentUser to:_newVideo  grabBagName:@"users" error:&error];
            [[FatFractal main] grabBagAdd:_toUser to:_newVideo grabBagName:@"users" error:&error];
            if (error)
                NSLog(@"Add grabbag error %@", error);
            
            [_videos addObject:_newVideo];
            
            [threadTableView reloadData];
        }];
    }
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
        [_dateFormatter setDateFormat:@"yyyy-MM-dd-HH:mm"];
    });
    return _dateFormatter;
}

#pragma mark - QBChatDelegate 

- (void)chatDidLogin {
    DBGMSG(@"%s", __func__);
    if (_isReceivedCallNotification) {
        if ([MBProgressHUD allHUDsForView:self.view] == 0) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.mode = MBProgressHUDModeIndeterminate;
            hud.labelText = @"Calling...";
            hud.dimBackground = YES;
            hud.yOffset = -77;
        }
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeIndeterminate;
        hud.labelText = @"Routing. Please wait!";
        hud.dimBackground = YES;
        hud.yOffset = -77;
        [self callOrStop];
    }
}

-(void) chatDidReceiveCallRequestFromUser:(NSUInteger)userID withSessionID:(NSString *)_sessionID conferenceType:(enum QBVideoChatConferenceType)conferenceType{
    DBGMSG(@"%s - userID = %lu, sessionID = %@", __func__, (unsigned long)userID, sessionID);
    
    // save  opponent data
    videoChatOpponentID = userID;
    videoChatConferenceType = conferenceType;
    sessionID = _sessionID;
    NSLog(@"receive sessionID = %@", sessionID);
    
    if (isCalling) {
        [self accept];
    } else {
        // show call alert
        if (self.callAlert == nil) {
            NSString *message = [NSString stringWithFormat:@"%@ is calling. Would you like to answer?", [self.currentUser.userName isEqualToString:@"test1@test.c"] ? @"Test Jiro" : @"Test Taro"];
            self.callAlert = [[UIAlertView alloc] initWithTitle:@"Call"
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:@"Decline"
                                              otherButtonTitles:@"Accept", nil];
            [self.callAlert show];
        }
    }
    
    // hide call alert if opponent has canceled call
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCallAlert) object:nil];
    [self performSelector:@selector(hideCallAlert) withObject:nil afterDelay:4];
    
}

-(void) chatCallUserDidNotAnswer:(NSUInteger)userID{
    DBGMSG(@"%s - userID = %lu", __func__, (unsigned long)userID);
    
    callButton.enabled = YES;
    callButton.tag = 101;
    
    // Hide call
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.opponentVideoView.hidden = YES;
    footerView.myVideoView.hidden = YES;
    [self setVideoMessageView];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"QuickBlox VideoChat" message:@"User isn't answering. Please try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}


-(void) chatCallDidRejectByUser:(NSUInteger)userID{
    DBGMSG(@"%s - userID = %lu", __func__, (unsigned long)userID);
    
    callButton.enabled = YES;
    callButton.tag = 101;
    
    // Hide call
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.opponentVideoView.hidden = YES;
    footerView.myVideoView.hidden = YES;
    [self setVideoMessageView];
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"QuickBlox VideoChat"
                          message:@"User has rejected your call."
                          delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil];
    [alert show];
}

-(void) chatCallDidAcceptByUser:(NSUInteger)userID{
    DBGMSG(@"%s - userID = %lu", __func__, (unsigned long)userID);
    
    callButton.enabled = YES;
    callButton.tag = 102;
    callButton.title = @"Stop";
    
    // Show call
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.opponentVideoView.hidden = NO;
    footerView.myVideoView.hidden = NO;
}

-(void) chatCallDidStopByUser:(NSUInteger)userID status:(NSString *)status{
    DBGMSG(@"%s - userID = %lu - status = %@", __func__, (unsigned long)userID, status);
    
    if([status isEqualToString:kStopVideoChatCallStatus_OpponentDidNotAnswer]){
        
        self.callAlert.delegate = nil;
        [self.callAlert dismissWithClickedButtonIndex:0 animated:YES];
        self.callAlert = nil;
        
    }else{
        callButton.tag = 101;
        callButton.title = @"Call";
    }
    
    // Hide call
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.opponentVideoView.hidden = YES;
    footerView.myVideoView.hidden = YES;
    [self setVideoMessageView];
    
    callButton.enabled = YES;
    
    // release video chat
    [[QBChat instance] unregisterVideoChatInstance:self.videoChat];
    self.videoChat = nil;
}

- (void)chatCallDidStartWithUser:(NSUInteger)userID sessionID:(NSString *)aSessionID{
    DBGMSG(@"%s - userID = %lu, sessionID = %@", __func__, (unsigned long)userID, aSessionID);
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}

- (void)didStartUseTURNForVideoChat{
    DBGMSG(@"%s", __func__);
}

- (void)reject {
    DBGMSG(@"%s", __func__);
    if(self.videoChat == nil){
        self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:sessionID];
    }
    [self.videoChat rejectCallWithOpponentID:videoChatOpponentID];

    [[QBChat instance] unregisterVideoChatInstance:self.videoChat];
    self.videoChat = nil;
    
    // update UI
    callButton.enabled = YES;
    
    [self setVideoMessageView];
}

- (void)accept {
    DBGMSG(@"%s", __func__);
    
    // Hide streaming
    RCCamPreviewFooter *footerView = (RCCamPreviewFooter*)threadTableView.tableFooterView;
    footerView.opponentVideoView.hidden = NO;
    footerView.myVideoView.hidden = NO;
    
    // Setup video chat
    if(self.videoChat == nil){
        self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:sessionID];
        self.videoChat.viewToRenderOpponentVideoStream = footerView.opponentVideoView;
        self.videoChat.viewToRenderOwnVideoStream = footerView.myVideoView;
    }
    
    // Set Audio & Video output
    self.videoChat.useHeadphone = NO;
    self.videoChat.useBackCamera = useBackCamera;
    
    // Accept call
    [self.videoChat acceptCallWithOpponentID:videoChatOpponentID conferenceType:videoChatConferenceType];

    callButton.enabled = YES;
    callButton.tag = 102;
    callButton.title = @"Stop";
    
    isCalling = YES;
}

#pragma mark UIAlertView

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    switch (buttonIndex) {
        case 0:
            [self reject];
            break;
        case 1:
            [self accept];
            break;
        default:
            break;
    }
    
    self.callAlert = nil;
}

- (void)hideCallAlert{
    DBGMSG(@"%s", __func__);
    [self.callAlert dismissWithClickedButtonIndex:-1 animated:YES];
    self.callAlert = nil;
    callButton.enabled = YES;
}

@end
