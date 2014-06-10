//
//  RCFatFractal.m
//  RainbowChat
//
//  Created by レー フックダイ on 5/7/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import "RCFatFractal.h"

@implementation RCFatFractal

//- (id) findExistingObjectWithClass:(Class) class andFFUrl:(NSString *)ffUrl {
//    NSEntityDescription *entityDescription = [NSEntityDescription
//                                              entityForName:NSStringFromClass(class) inManagedObjectContext:self.managedObjectContext];
//    NSFetchRequest *request = [[NSFetchRequest alloc] init];
//    [request setEntity:entityDescription];
//    
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:
//                              @"(ffUrl == %@)", ffUrl];
//    [request setPredicate:predicate];
//    
//    NSError *error;
//    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
//    return [array firstObject];
//}
//
//- (id) createInstanceOfClass:(Class) class forObjectWithMetaData:(FFMetaData *)objMetaData {
//    if ([class isSubclassOfClass:[NSManagedObject class]]) {
//        id obj = [self findExistingObjectWithClass:class andFFUrl:objMetaData.ffUrl];
//        if (obj) {
//            NSLog(@"Found existing %@ object with ffUrl %@ in managed context", NSStringFromClass(class), objMetaData.ffUrl);
//            return obj;
//        } else {
//            NSLog(@"Inserting new %@ object with ffUrl %@ into managed context", NSStringFromClass(class), objMetaData.ffUrl);
//            return [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(class)
//                                                 inManagedObjectContext:self.managedObjectContext];
//        }
//    } else {
//        return [[class alloc] init];
//    }
//}

@end
