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
    
    NSLog(@"MasterViewController.ffInstance = %@", self.ffInstance);
    NSLog(@"[FatFractal main] = %@", [FatFractal main]);
    
    [self.ffInstance registerClass:[RCUser class] forClazz:@"FFUser"];
    self.currentUser = (RCUser*)[self.ffInstance loggedInUser];
    
    NSLog(@"Current User = %@  loggedInUser = %@", self.currentUser, [self.ffInstance loggedInUser]);
    
	[self fetchFromCoreData];
//    [self fetchChangesFromBackEnd];
    
    /*
     Reload the table view if the locale changes -- look at APLEventTableViewCell.m to see how the table view cells are redisplayed.
     */
    __weak UITableViewController *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        [weakSelf.tableView reloadData];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    [self checkForAuthentication];
}

- (void)checkForAuthentication {
    if (![RCAppDelegate checkForAuthentication]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        RCWelcomeViewController *welcomeViewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
        welcomeViewController.delegate = self;
        welcomeViewController.ffInstance = self.ffInstance;
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
//    return [[self.fetchedResultsController sections] count];
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
# warning - Need to send a specific class of toFriend ( maybe RCUser?)
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
//        NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        RCUser *toFriend = [_friends objectAtIndex:indexPath.row];
        [[segue destinationViewController] setToUser:toFriend];
        [[segue destinationViewController] setFfInstance:self.ffInstance];
        [[segue destinationViewController] setManagedObjectContext:self
         .managedObjectContext];
    }
}

#pragma mark - Data fetch
- (void)fetchFromCoreData {
    DBGMSG(@"%s", __func__);
    /*
     Fetch existing friends.
     Create a fetch request for the RCUser entity; add a sort descriptor; then execute the fetch.
     */
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"RCUser"];
    [request setFetchBatchSize:20];
    
    // Order the events by creation date, most recent first.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"userName" ascending:NO];
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
    [self setFriends:[fetchResults mutableCopy]];
    [self.tableView reloadData];
}

- (void)fetchChangesFromBackEnd {
    DBGMSG(@"%s", __func__);
#warning Need to implement
    // Fetch any friends that have been updated on the backend
    // Guide to query language is here: http://fatfractal.com/prod/docs/queries/
    // and full syntax reference here: http://fatfractal.com/prod/docs/reference/#query-language
    // Note use of the "depthGb" parameter - see here: http://fatfractal.com/prod/docs/queries/#retrieving-related-objects-inline
    
    NSString *queryString = [NSString stringWithFormat:@"/FFUser/(userName ne 'anonymous' and userName ne 'system' and guid ne '%@')", self.currentUser.guid];
    [[[self.ffInstance newReadRequest] prepareGetFromCollection:queryString] executeAsyncWithBlock:^(FFReadResponse *response) {
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
        NSError *cdError;
        [self.managedObjectContext save:&cdError];
        if (cdError) {
            NSLog(@"Saved managedObjectContext - error was %@", [cdError localizedDescription]);
        }
    }];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    //    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    RCUser *friend = (RCUser*)[_friends objectAtIndex:indexPath.row];
    cell.textLabel.text = friend.nickname;
}

#pragma mark - WelcomeViewControllerDelegate Methods
-(void)userDidAuthenticate {
    NSLog(@"Main View Controller refreshTableAndLoadData");
}

#pragma mark - Public Methods
- (void)refresh {
    DBGMSG(@"%s", __func__);
}

- (void)userIsAuthenticatedFromAppDelegateOnLaunch {
    DBGMSG(@"%s", __func__);
    if ([self.ffInstance loggedInUser]) {
        self.currentUser = (RCUser*)[self.ffInstance loggedInUser];
        [self fetchFromCoreData];
    }
}

- (void)refreshTableAndLoadData {
    DBGMSG(@"%s", __func__);
    // Clean friends array
    if (_friends) {
        [_friends removeAllObjects];
        _friends = nil;
    }
    
    // Load from backend
    NSString *uri = [NSString stringWithFormat:@"/FFUser/(userName ne 'anonymous' and userName ne 'system' and guid ne '%@')", self.currentUser.guid];
    _friends = [NSMutableArray array];
    [self.ffInstance registerClass:[RCUser class] forClazz:@"FFUser"];
    [self.ffInstance getArrayFromUri:uri onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
        if (theObj) {
            _friends = (NSMutableArray*)theObj;
            NSLog(@"first friend = %@", (RCUser*)[_friends firstObject]);
            self.title = self.currentUser.nickname;
            [self.tableView reloadData];
        }
    }];
}
- (IBAction)refreshButtonPressed:(id)sender {
    [self fetchChangesFromBackEnd];
}

- (IBAction)logoutButtonPressed:(id)sender {
    DBGMSG(@"%s", __func__);
    [self.ffInstance logout];
    // Clear keychain
    KeychainItemWrapper *keychainItem = [RCAppDelegate keychainItem];
    if ([keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] != nil) {
        [keychainItem setObject:nil forKey:(__bridge id)(kSecAttrAccount)];
        [keychainItem setObject:nil forKey:(__bridge id)(kSecValueData)];
    }
    // Navigate to Welcome View Controller
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    RCWelcomeViewController *welcomeViewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
    welcomeViewController.delegate = self;
    welcomeViewController.ffInstance = self.ffInstance;
    welcomeViewController.managedObjectContext = self.managedObjectContext;
    
    [self presentViewController:welcomeViewController animated:YES completion:nil];
}


/* We do not need a fetchedResultsController since we have the managedObjectContext
- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}
 */
/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */



@end
