//
//  RCAppDelegate.m
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCAppDelegate.h"
#import "RCWelcomeViewController.h"
#import "RCMasterViewController.h"
#import "RCUser.h"

static NSString *baseURL = @"http://presentice.fatfractal.com/rainbowchat";
static NSString *sslURL = @"https://presentice.fatfractal.com/rainbowchat";
static RCFatFractal *_ffInstance;

// Instantiating KeychainItemWrapper class as a singleton through AppDelegate
static KeychainItemWrapper *_keychainItem;

// Keychain Identifier
static NSString *keychainIdentifier = @"RainBowChatKeychain";

@interface RCAppDelegate () <QBActionStatusDelegate>
@property RCWelcomeViewController *welcomeViewController;
@property RCMasterViewController *masterViewController;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) RCFatFractal *ffInstance;
@end


@implementation RCAppDelegate
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize ffInstance = _ffInstance;

#pragma mark - FatFractal
/*
+ (RCFatFractal *) ffInstance {
    return _ffInstance;
}
*/
+ (BOOL)checkForAuthentication {
    DBGMSG(@"%s - [_ffInstance loggedIn] = %hhd [_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] = %@, [_keychainItem objectForKey:(__bridge id)(kSecValueData)] = %@", __func__, [_ffInstance loggedIn], [_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)], [_keychainItem objectForKey:(__bridge id)(kSecValueData)]);
    if ([_ffInstance loggedIn] || ([_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] != nil && ![[_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] isEqual:@""])){
//    if ([_ffInstance loggedIn]) {
        NSLog(@"checkForAuthentication: FFUser logged in.");
        return YES;
    } else {
        NSLog(@"checkForAuthentication: No user logged in.");
        return NO;
    }
}


- (RCFatFractal *) ffInstance {
    if (_ffInstance != nil) {
        return _ffInstance;
    }
    
    _ffInstance = [[RCFatFractal alloc] initWithBaseUrl:baseURL sslUrl:sslURL];
    [_ffInstance registerClass:[RCUser class] forClazz:@"FFUser"];
#warning - Need to revise the usage of localstorage
    //    _ffInstance.localStorage = [[FFLocalStorageSQLite alloc] initWithDatabaseKey:@"RainbowChatFFStorage"];
#ifdef DEBUG
    _ffInstance.debug = YES;
#endif
    _ffInstance.managedObjectContext = self.managedObjectContext;
    _ffInstance.managedObjectModel = self.managedObjectModel;
    
    return _ffInstance;
}


+ (KeychainItemWrapper*)keychainItem {
    return _keychainItem;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Set QuickBlox credentials. Register at admin.quickblox.com, create a new app
    // and copy credentials here to have your own backend instance enabled.
    [QBSettings setApplicationID:10793];
    [QBSettings setAuthorizationKey:@"uxk8UDP3e5bU86V"];
    [QBSettings setAuthorizationSecret:@"DZg6fZKCOWg-6kP"];
    [QBSettings setAccountKey:@"niLsXRnpG2bhBtqzGsxF"];
    
    NSMutableDictionary *videoChatConfiguration = [[QBSettings videoChatConfiguration] mutableCopy];
    [videoChatConfiguration setObject:@20 forKey:kQBVideoChatCallTimeout];
    [videoChatConfiguration setObject:AVCaptureSessionPresetLow forKey:kQBVideoChatFrameQualityPreset];
    [videoChatConfiguration setObject:@10 forKey:kQBVideoChatVideoFramesPerSecond];
    [videoChatConfiguration setObject:@3 forKey:kQBVideoChatP2PTimeout];
    [QBSettings setVideoChatConfiguration:videoChatConfiguration];
    
    
    // Create the KeychainItem singleton
    _keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:keychainIdentifier accessGroup:nil];
    
    
    // If Keychain item exists, attempt login
    if ([_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] != nil && ![[_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)] isEqual:@""]) {
        NSLog(@"_keychainItem username exists, attempting login in background.");
        
        NSString *username = [_keychainItem objectForKey:(__bridge id)(kSecAttrAccount)];
        NSString *password = [_keychainItem objectForKey:(__bridge id)(kSecValueData)];
        
        // Login with FatFractal by initiating connection with server
        [self.ffInstance loginWithUserName:username andPassword:password onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
            if (theErr) {
                NSLog(@"Error trying to log in from AppDelegate: %@", [theErr localizedDescription]);
                // Probably keychain item is corrupted, reset the keychain and force user to sign up/ login again.
                // Better error handling can be done in a production application
                [_keychainItem resetKeychainItem];
                return;
            }
            if (theObj) {
                NSLog(@"Login from AppDelegate using keychain successful!");
                
                QBASessionCreationRequest *extendedAuthRequest = [QBASessionCreationRequest request];
                extendedAuthRequest.userEmail = username;
                extendedAuthRequest.userPassword = password;
                [QBAuth createSessionWithExtendedRequest:extendedAuthRequest delegate:self];
            }
        }];
    }
    
    // Override point for customization after application launch.
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    self.masterViewController = (RCMasterViewController *)navigationController.topViewController;
    self.masterViewController.managedObjectContext = self.managedObjectContext;
    self.masterViewController.ffInstance = self.ffInstance;
    NSLog(@"self.masterViewController.ffInstance =%@", self.masterViewController.ffInstance);
    
    return YES;
}

#pragma mark - Helper Methods
- (void)userSuccessfullyAuthenticated {
    DBGMSG(@"%s", __func__);
    [self.masterViewController setFfInstance:self.ffInstance];
    [self.masterViewController setManagedObjectContext:self.managedObjectContext];
    [self.masterViewController userIsAuthenticatedFromAppDelegateOnLaunch];
}
							
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext {
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"RainbowChat" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Presentice.RainbowChat"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    // Allow inferred migration from the original version of the application.
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES, NSInferMappingModelAutomaticallyOption : @YES };
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - QBActionStatusDelegate
// QuickBlox API queries delegate
- (void)completedWithResult:(Result *)result{
    DBGMSG(@"%s - result = %@", __func__, result);
    // QuickBlox session creation  result
    if([result isKindOfClass:[QBAAuthSessionCreationResult class]]){
        
        // Success result
        if(result.success){
            
            [self userSuccessfullyAuthenticated];
            
        }else{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[[result errors] description] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
    }
}


@end
