//
//  RCDetailViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCDetailViewController.h"

@interface ToUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@end


@interface CurrentUserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *userProfilePicture;
@property (weak, nonatomic) IBOutlet UIView *videoView;
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

- (void)setToUser:(FFUser *)toUser {
    if (_toUser != toUser) {
        _toUser = toUser;
        
        // Update the view.
        [self configureView];
    }
}


- (void)configureView {
    // Update the user interface for the detail item.

    if (_toUser) {
        self.title = _toUser.firstName;
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return chats.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    #warning Need to implement
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}






@end
