//
//  CoreDataEngine.h
//  CycConnectPoc iOS
//
//  Created by florian BUREL on 05/07/2016.
//  Copyright © 2016 florian Burel. All rights reserved.
//

#import <Foundation/Foundation.h>

@import CoreData;

@interface NSManagedObject (EntityCreation)

+ (instancetype)    newInstanceInContext:(NSManagedObjectContext *)context;
+ (NSFetchRequest *)newFetchRequest;

@end

@import CoreData;


typedef void (^CoreDataBackgroundBlock) (NSManagedObjectContext * privateContext);

@interface FBCoreDataEngine : NSObject

@property (strong, readonly) NSManagedObjectContext *viewContext;

/// the single point access to the CoreDataEngine instance
- (id) initWithDataModel:(NSString *)dataModelName;

/// this methods should be call as early as possible, before any attempt to access the data is performed
- (void) preparePersistenceLayer:(dispatch_block_t)completion;

/*! In general, avoid doing data processing on the main queue that is not user-related. Data processing can be CPU-intensive, and if it is performed on the main queue, it can result in unresponsiveness in the user interface. If your application will be processing data, such as importing data into Core Data from JSON, encapsulate the process into a block and use this method to execute it. The block will be executed in an undisclosed dispatch queue and upon completion, the given privateContext will be saved which moves all of the changes into the main queue context without blocking the main queue. Once done, the completion block will be executed in the main queue.
 */
- (void) performBackgroundTask:(CoreDataBackgroundBlock)task completion:(dispatch_block_t)completion;

/// write the current changes to disk
- (void)save;

@end
