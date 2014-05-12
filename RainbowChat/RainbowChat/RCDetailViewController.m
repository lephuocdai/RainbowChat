//
//  RCDetailViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCDetailViewController.h"

@class ToUserCell;
@class CurrentUserCell;

@interface ToUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@end

@implementation ToUserCell
@synthesize userProfilePicture, videoView;
@end


@interface CurrentUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UIView *videoPreview;
@end

@implementation CurrentUserCell
@synthesize userProfilePicture, videoView, videoPreview;
@end


@interface RCDetailViewController ()
- (void)configureView;
@end

@implementation RCDetailViewController {
    IBOutlet UITableView *threadTableView;
    NSMutableArray *chats; // every chat contains one movie controller
    BOOL isRecording;
}

#pragma mark - Managing the detail item

- (void)setToUser:(RCUser *)toUser {
    if (_toUser != toUser) {
        _toUser = toUser;
        
        // Update the view.
        [self configureView];
    }
}


- (void)configureView {
    // Update the user interface for the detail item.
    
    threadTableView = [[UITableView alloc] init];
    
    if (_toUser) {
        self.title = _toUser.firstName;
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
	
    [self fetchFromBackend];

    [self configureView];
    
    isRecording = false;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordButtonPushed:(id)sender {
    if (isRecording) {
        [self stopRecord];
    } else {
        [self startRecord];
    }
}

#pragma mark - AVFoundation

- (void)initializeCameraFor:(CurrentUserCell*)cell {
    cell.videoView.hidden = YES;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetLow;
    
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    captureVideoPreviewLayer.frame = cell.videoPreview.bounds;
    [cell.videoPreview.layer addSublayer:captureVideoPreviewLayer];
    
    UIView *view = [cell videoPreview];
    CALayer *viewLayer = [view layer];
    [viewLayer setMasksToBounds:YES];
    
    CGRect bounds = [view bounds];
    [captureVideoPreviewLayer setFrame:bounds];
    
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
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
    if (!input) {
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    [session addInput:input];
    
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    
    [session addOutput:stillImageOutput];
    
    [session startRunning];
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
    DBGMSG(@"%s chats.count = %d", __func__, chats.count);
    return chats.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBGMSG(@"%s", __func__);
    
    // Configure last cell
    if (indexPath.row == chats.count - 1) {
        NSLog(@"Last cell");
        
        static NSString *cellIdentifier = @"currentUserCell";
        CurrentUserCell *cell = (CurrentUserCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        [self initializeCameraFor:cell];
        
        return cell;
        
    } else {
        NSLog(@"Not last cell");
        static NSString *cellIdentifier = @"Cell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
        
        return cell;
    }
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    #warning Need to implement
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Data fetch

- (void)fetchFromBackend {
    chats = [NSMutableArray arrayWithObject:@{@"name": @"test name"}];
}


@end
