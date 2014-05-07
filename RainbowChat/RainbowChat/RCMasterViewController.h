//
//  RCMasterViewController.h
//  RainbowChat
//
//  Created by レー フックダイ on 4/27/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CoreData/CoreData.h>

#import "RCFatFractal.h"

#warning - We do not need a fetchedResultsController since we have the managedObjectContext
@interface RCMasterViewController : UITableViewController //<NSFetchedResultsControllerDelegate>

//@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) RCFatFractal *ffInstance;

@end
