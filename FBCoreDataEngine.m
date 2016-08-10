//
//  CoreDataEngine.m
//  CycConnectPoc iOS
//
//  Created by florian BUREL on 05/07/2016.
//  Copyright © 2016 florian Burel. All rights reserved.
//

#import "FBCoreDataEngine.h"

@interface FBCoreDataEngine ()

@property (copy, nonatomic) NSString * dataModelName;

@property (strong, readwrite) NSManagedObjectContext *viewContext;

@end


@implementation NSManagedObject (EntityCreation)

+ (NSString *) entityName
{
    return [self description];
}

+ (instancetype) newInstanceInContext:(NSManagedObjectContext *)context
{
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                         inManagedObjectContext:context];
}

+ (NSFetchRequest *)newFetchRequest
{
    return [[NSFetchRequest alloc] initWithEntityName:[self entityName]];
}

@end

@implementation FBCoreDataEngine

- (id)initWithDataModel:(NSString *)dataModelName;
{
    self = [super init];
    if (self) {
        self.dataModelName = dataModelName;
    }
    return self;
}
- (void) preparePersistenceLayer:(dispatch_block_t)completion
{
    dispatch_block_t safeCallToCompletion = ^{
        if(completion)
        {
            dispatch_sync(dispatch_get_main_queue(), completion);
        }
    };
    
    if(self.viewContext)
    {
        // the layer has allready been initialized
        safeCallToCompletion();
        return;
    }
    
    // Creating the viewContext
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:self.dataModelName withExtension:@"momd"];
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(mom != nil, @"Error initializing Managed Object Model");
    
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:psc];
    self.viewContext = moc;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsURL URLByAppendingPathComponent:@"DataModel.sqlite"];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSDictionary *options = @{
                                  NSMigratePersistentStoresAutomaticallyOption : @YES,
                                  NSInferMappingModelAutomaticallyOption : @YES,
                                  NSSQLitePragmasOption : @{ @"journal_mode":@"DELETE" }
                                  };
        
        NSError *error = nil;
        NSPersistentStore *store = [[self.viewContext persistentStoreCoordinator] addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
        NSAssert(store != nil, @"Error initializing PSC: %@\n%@", [error localizedDescription], [error userInfo]);
        
        
        safeCallToCompletion();
        
    });

}

- (void) performBackgroundTask:(CoreDataBackgroundBlock)task completion:(dispatch_block_t)completion
{
    NSManagedObjectContext *private = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [private setParentContext:self.viewContext];
    
    [private performBlock:^
    {
        
        // execute the given task
        task(private);
        
        // Save
        NSError *error = nil;
        if (![private save:&error]) {
            NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            abort();
        }
        else if(completion)
        {
            dispatch_sync(dispatch_get_main_queue(), completion);
        }
    }];
}

- (void)save
{
    static dispatch_source_t source;
    
    // Cancel previous call
    if (source != nil) {
        dispatch_source_cancel(source);
    }
    
    dispatch_block_t executionBlockThrottled = ^{
       
        // Since we cannot guarantee that caller is the main thread, we use --performBlockAndWait: against the main context
        [[self viewContext] performBlockAndWait:^{
            
            NSError *error = nil;
            
            if ([self.viewContext hasChanges] && [self.viewContext save:&error] == NO) {
                NSAssert(NO, @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            }
        }];

        
    };
    
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
    
    dispatch_source_set_event_handler(source, ^{
        executionBlockThrottled();
        dispatch_source_cancel(source);
    });
    dispatch_resume(source);
    
}


@end
