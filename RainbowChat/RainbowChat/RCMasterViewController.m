//
//  RCMasterViewController.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCMasterViewController.h"
#import "RCAppDelegate.h"
#import "RCDetailViewController.h"
#import "RCWelcomeViewController.h"
#import "KeychainItemWrapper.h"
#import "RCUser.h"

@interface RCMasterViewController ()

//@property (nonatomic) CoreDataStack *coreDataStack;
@property (strong, nonatomic) RCUser *calledUser;
@property (strong, nonatomic) RCUser *currentUser;
@property (nonatomic) NSMutableArray *friends;
@property (nonatomic) NSNumber *lastRefreshTime;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end


@implementation RCMasterViewController
@synthesize lastRefreshTime = _lastRefreshTime;

- (void)awakeFromNib {
    [super awakeFromNib];
}

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

#pragma mark - View lifecycle
- (void)viewDidLoad {
    DBGMSG(@"%s", __func__);
    [super viewDidLoad];
    
    NSLog(@"[FatFractal main] = %@", [FatFractal main]);
    
    [[FatFractal main] registerClass:[RCUser class] forClazz:@"FFUser"];
    self.currentUser = (RCUser*)[[FatFractal main] loggedInUser];
    
    NSLog(@"Current User = %@  loggedInUser = %@", self.currentUser, [[FatFractal main] loggedInUser]);
    
    [self fetchChangesFromBackEnd];
    
    /*
     Reload the table view if the locale changes -- look at APLEventTableViewCell.m to see how the table view cells are redisplayed.
     
    __weak UITableViewController *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        [weakSelf.tableView reloadData];
    }];
     */
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkForAuthentication];
}

- (void)checkForAuthentication {
    if (![RCAppDelegate checkForAuthentication]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        RCWelcomeViewController *welcomeViewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
        welcomeViewController.delegate = self;
        [self presentViewController:welcomeViewController animated:YES completion:nil];
    } else {
        [self userIsAuthenticatedFromAppDelegateOnLaunch];
        [self.tableView reloadData];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table View data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _friends.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // We do not allow user to edit the table.
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // The table view should not be re-orderable.
    return NO;
}

#pragma mark - Table View delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        RCUser *toFriend = [_friends objectAtIndex:indexPath.row];
        [[segue destinationViewController] setToUser:toFriend];
        [[segue destinationViewController] setIsReceivedCallNotification:NO];
    } else if ([[segue identifier] isEqualToString:@"showDetailFromNotification"]) {
        [[segue destinationViewController] setToUser:_calledUser];
        [[segue destinationViewController] setIsReceivedCallNotification:YES];
    }
}

#pragma mark - Data fetch
- (void)fetchFromCoreData {
    DBGMSG(@"%s", __func__);
}

- (void)fetchChangesFromBackEnd {
    DBGMSG(@"%s", __func__);
#warning Need to implement
    // Fetch any friends that have been updated on the backend
    // Guide to query language is here: http://fatfractal.com/prod/docs/queries/
    // and full syntax reference here: http://fatfractal.com/prod/docs/reference/#query-language
    // Note use of the "depthGb" parameter - see here: http://fatfractal.com/prod/docs/queries/#retrieving-related-objects-inline
    self.currentUser = (RCUser*)[[FatFractal main] loggedInUser];
    NSLog(@"self.currentUser = %@ guid = %@", self.currentUser, self.currentUser.guid);
    NSString *queryString = [NSString stringWithFormat:@"/FFUser/(userName ne 'anonymous' and userName ne 'system' and guid ne '%@' and isTeacher eq true)", self.currentUser.guid];
//    NSString *queryString = [NSString stringWithFormat:@"/FFUser/(userName ne 'anonymous' and userName ne 'system' and guid ne '%@')", self.currentUser.guid];
    
    [[[[FatFractal main] newReadRequest] prepareGetFromCollection:queryString] executeAsyncWithBlock:^(FFReadResponse *response) {
        NSArray *retrieved = response.objs;
        if (response.error) {
            NSLog(@"Failed to retrieve from backend: %@", response.error.localizedDescription);
        } else {
            // Clean friends array
            if (self.friends) {
                [self.friends removeAllObjects];
                self.friends = nil;
            }
            self.lastRefreshTime = [FFUtils unixTimeStampFromDate:[NSDate date]];
            self.friends = (NSMutableArray*)retrieved;
            self.title = self.currentUser.nickname;
            [self.tableView reloadData];
        }
    }];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    RCUser *friend = (RCUser*)[_friends objectAtIndex:indexPath.row];
    cell.textLabel.text = friend.nickname;
}

#pragma mark - WelcomeViewControllerDelegate Methods
-(void)userDidAuthenticate {
    NSLog(@"Main View Controller refreshTableAndLoadData");
}

#pragma mark - Public Methods

- (void)didReceiveNotificationFromAppDelegateOnLaunch:(NSDictionary*)userInfo{
    DBGMSG(@"%s, userInfo = %@", __func__, userInfo);
    
    NSString *fromUserGUID = [userInfo valueForKey:@"fromUser"];
    _calledUser = (RCUser*)[[FatFractal main] getObjFromUri:[NSString stringWithFormat:@"/FFUser/%@",fromUserGUID]];
    
    NSLog(@"fromUser = %@",_calledUser);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Incoming call"
                                                        message:[NSString stringWithFormat:@"Called by %@", _calledUser.firstName]
                                                       delegate:self
                                              cancelButtonTitle:@"Decline"
                                              otherButtonTitles:@"Accept", nil];
    alertView.tag = 101;
    [alertView show];
}


- (void)userAuthenticationFailedFromAppDelegateOnLaunch {
    DBGMSG(@"%s", __func__);
    [[RCAppDelegate keychainItem] resetKeychainItem];
    // Navigate to WelcomeViewController
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RCWelcomeViewController *welcomeViewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
    welcomeViewController.delegate = self;
    
    [self presentViewController:welcomeViewController animated:YES completion:nil];
}

- (void)userIsAuthenticatedFromAppDelegateOnLaunch {
    DBGMSG(@"%s", __func__);
    if ([[FatFractal main] loggedInUser]) {
        self.currentUser = (RCUser*)[[FatFractal main] loggedInUser];
        [self fetchChangesFromBackEnd];
    }
}


- (IBAction)refreshButtonPressed:(id)sender {
    DBGMSG(@"%s", __func__);
    [RCUtility askForPushNotification];
    [self fetchChangesFromBackEnd];
}

- (IBAction)logoutButtonPressed:(id)sender {
    DBGMSG(@"%s - loggedin user guid = %@", __func__, [[FatFractal main] loggedInUserGuid]);
    [[FatFractal main] logout];
    
    // Clear keychain
    [[RCAppDelegate keychainItem] resetKeychainItem];
    
    // Navigate to Welcome View Controller
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RCWelcomeViewController *welcomeViewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
    welcomeViewController.delegate = self;
    
    [self presentViewController:welcomeViewController animated:YES completion:nil];
}

#pragma UIAletViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 101) {
        if (buttonIndex == 1) {
            // Navigate to DetailViewController
            [self performSegueWithIdentifier:@"showDetailFromNotification" sender:self];
        }
    }
}


@end
