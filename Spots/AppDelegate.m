//
//  AppDelegate.m
//  Spots
//
//  Created by Nicholas Spitale on 7/10/14.
//  Copyright (c) 2014 NickSpitale. All rights reserved.
//

#import "AppDelegate.h"
#import "Reachability.h"
#import "MBProgressHUD.h"
#import "SPWelcomeViewController.h"
#import "SPActivityViewController.h"
#import "SPLogInViewController.h"
#import "SPDiscoverViewController.h"
#import "SPEventsViewController.h"
#import "SPMoreNavigationController.h"

@interface AppDelegate () {
    NSMutableData *_data;
    BOOL firstLaunch;
}

@property (nonatomic, strong) SPWelcomeViewController *welcomeViewController;
@property (nonatomic, strong) SPActivityViewController *homeViewController;
@property (nonatomic, strong) SPDiscoverViewController *discoverViewController;
@property (nonatomic, strong) SPEventsViewController *eventsViewController;
@property (nonatomic, strong) SPMoreNavigationController *moreNavigationController;
@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, strong) NSTimer *autoFollowTimer;


@property (nonatomic, strong) Reachability *internetReach;
@property (nonatomic, strong) Reachability *wifiReach;


- (void)setupAppearance;
@end



@implementation AppDelegate

@synthesize window;
@synthesize navController;
@synthesize tabBarController;
@synthesize homeViewController;
@synthesize welcomeViewController;
@synthesize moreNavigationController;
@synthesize hud;
@synthesize autoFollowTimer;
@synthesize internetReach;
@synthesize wifiReach;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    

    // ****************************************************************************
    // Parse initialization
    [Parse setApplicationId:@"GitsOrpE6s6v4RB30Xrkfjr9LazUrORIZrHcqDGb"
                  clientKey:@"KWZI2125IsHodVq7WlNHukaguohs5uk8QiBrJ6U8"];
    
    [PFFacebookUtils initializeFacebook];
    // ****************************************************************************
    
    PFACL *defaultACL = [PFACL ACL];
    
    // Enable public read access by default, with any newly created PFObjects belonging to the current user
    [defaultACL setPublicReadAccess:YES];
    [PFACL setDefaultACL:defaultACL withAccessForCurrentUser:YES];
    
    [self setupAppearance];
    
    [self monitorReachability];
    
    self.welcomeViewController = [[SPWelcomeViewController alloc] init];
    self.navController = [[UINavigationController alloc] initWithRootViewController:self.welcomeViewController];
    self.navController.navigationBarHidden = YES;
    
    self.window.rootViewController = self.navController;
    
    [self.window makeKeyAndVisible];
    return YES;
}




- (void)monitorReachability {
    Reachability *hostReach = [Reachability reachabilityWithHostname:@"api.parse.com"];
    
    hostReach.reachableBlock = ^(Reachability*reach) {
        _networkStatus = [reach currentReachabilityStatus];
        
        if ([self isParseReachable] && [PFUser currentUser] && self.homeViewController.objects.count == 0) {
            // Refresh home timeline on network restoration. Takes care of a freshly installed app that failed to load the main timeline under bad network conditions.
            // In this case, they'd see the empty timeline placeholder and have no way of refreshing the timeline unless they followed someone.
            [self.homeViewController loadObjects];
        }
    };
    
    hostReach.unreachableBlock = ^(Reachability*reach) {
        _networkStatus = [reach currentReachabilityStatus];
    };
    
    [hostReach startNotifier];
}


- (void)presentLoginViewControllerAnimated:(BOOL)animated {
    
    SPLogInViewController *loginViewController = [[SPLogInViewController alloc] init];
    
    [loginViewController setDelegate:self];
    loginViewController.fields = PFLogInFieldsFacebook;
    loginViewController.facebookPermissions = @[ @"user_about_me" ];
    
    [self.welcomeViewController presentViewController:loginViewController animated:NO completion:nil];
    
}


#pragma mark - ()

- (void)setupAppearance {
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

    //The appearance class customizes the appearance of all instances of a class!!
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UIBarButtonItem appearance] setTintColor:kSPColorBlue];
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          kSPColorBlue,NSForegroundColorAttributeName,
                                                          nil]];
    [[UITabBar appearance] setTintColor:[UIColor beigeColor]];
}


- (void)logOut {
    // clear cache
    [[SPCache sharedCache] clear];
    
     //clear NSUserDefaults
   [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSPUserDefaultsCacheFacebookFriendsKey];
   // [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSPUserDefaultsActivityFeedViewControllerLastRefreshKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Unsubscribe from push notifications by removing the user association from the current installation.
 //   [[PFInstallation currentInstallation] removeObjectForKey:kPAPInstallationUserKey];
//    [[PFInstallation currentInstallation] saveInBackground];
    
    // Clear all caches
    [PFQuery clearAllCachedResults];
    
    // Log out
    [PFUser logOut];
    
    // clear out cached data, view controllers, etc
    [self.navController popToRootViewControllerAnimated:NO];
    
    [self presentLoginViewController];
    
    self.homeViewController = nil;
    self.discoverViewController = nil;
}



#pragma mark - PFLoginViewController

- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user {
   
    
    // user has logged in - we need to fetch all of their Facebook data before we let them in
    if (![self shouldProceedToMainInterface:user]) {
        
        
        self.hud = [MBProgressHUD showHUDAddedTo:self.navController.presentedViewController.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Loading", nil);
        self.hud.dimBackground = YES;
        
    }
    
    [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        
        
        if (!error) {
            [self facebookRequestDidLoad:result];
        } else {
            [self facebookRequestDidFailWithError:error];
        }
    }];
    
    
}

- (void)presentLoginViewController {
    [self presentLoginViewControllerAnimated:YES];
}


- (BOOL)shouldProceedToMainInterface:(PFUser *)user {
    
    if ([SPUtility userHasValidFacebookData:[PFUser currentUser]]) {
        [MBProgressHUD hideHUDForView:self.navController.presentedViewController.view animated:YES];
        
        [self presentTabBarController];
        
        [self.navController dismissViewControllerAnimated:YES completion:nil];
        return YES;
    }
    return NO;
}



- (void)presentTabBarController {
    
    self.tabBarController = [[SPTabBarController alloc] init];
    
    self.homeViewController = [[SPActivityViewController alloc] initWithStyle:UITableViewStylePlain];
    self.discoverViewController = [[SPDiscoverViewController alloc] init];
    self.eventsViewController = [[SPEventsViewController alloc] init];
    moreNavigationController = [[SPMoreNavigationController alloc] init];
    
    UINavigationController *homeNavigationController = [[UINavigationController alloc] initWithRootViewController:self.homeViewController];
    
      UINavigationController *emptyNavigationController = [[UINavigationController alloc] init];

    
     UINavigationController *discoverNavigationController = [[UINavigationController alloc] initWithRootViewController:self.discoverViewController];
    
    UINavigationController *eventsNavigationController = [[UINavigationController alloc] initWithRootViewController:self.eventsViewController];
    
    
  
    
    UITabBarItem *homeTabBarItem = [[UITabBarItem alloc] initWithTitle:nil image:[UIImage imageNamed:@"ActivityTabBarIcon2.png"] selectedImage:[UIImage imageNamed:@"ActivityTabBarIcon2.png"]];
    /*
    [homeTabBarItem setTitleTextAttributes: @{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateNormal];
    [homeTabBarItem setTitleTextAttributes: @{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateSelected];
    */


    
    [homeNavigationController setTabBarItem:homeTabBarItem];
    
    UITabBarItem *discoverTabBarItem = [[UITabBarItem alloc] initWithTitle:nil image:[UIImage imageNamed:@"SpotsTabBarIcon2"] selectedImage:[UIImage imageNamed:@"SpotsTabBarIcon2"]];
    
    [discoverTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateNormal];
    [discoverTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateSelected];
    
    [discoverNavigationController setTabBarItem:discoverTabBarItem];
    
    
    
    UITabBarItem *eventsTabBarItem = [[UITabBarItem alloc] initWithTitle:nil image:[UIImage imageNamed:@"EventsTabBarIcon"] selectedImage:[UIImage imageNamed:@"EventsTabBarIcon"]];
    [eventsTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateNormal];
    [eventsTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateSelected];
    
    [eventsNavigationController setTabBarItem:eventsTabBarItem];
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"bunduru: %@",bundleIdentifier);
    
    UITabBarItem *moreTabBarItem = [[UITabBarItem alloc] initWithTitle:nil image:[UIImage imageNamed:@"MoreTabBarIcon"] selectedImage:[UIImage imageNamed:@"MoreTabBarIcon"]];
    [moreTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateNormal];
    [moreTabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f] } forState:UIControlStateSelected];
    
    [moreNavigationController setTabBarItem:moreTabBarItem];

    tabBarController.tabBar.tintColor = kSPColorBlue;
   
    self.tabBarController.delegate = self;
    self.tabBarController.viewControllers = @[ homeNavigationController, discoverNavigationController, emptyNavigationController, eventsNavigationController,moreNavigationController];
  
    [self.navController setViewControllers:@[ self.welcomeViewController, self.tabBarController ] animated:NO];
    

     
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|
     UIRemoteNotificationTypeAlert|
     UIRemoteNotificationTypeSound];
  
    
    NSLog(@"Downloading user's profile picture");
    // Download user's profile picture
    NSURL *profilePictureURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large", [[PFUser currentUser] objectForKey:kSPUserFacebookIDKey]]];
    NSURLRequest *profilePictureURLRequest = [NSURLRequest requestWithURL:profilePictureURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f]; // Facebook profile picture cache policy: Expires in 2 weeks
    [NSURLConnection connectionWithRequest:profilePictureURLRequest delegate:self];

    
    
}

- (void)autoFollowTimerFired:(NSTimer *)aTimer {
    [MBProgressHUD hideHUDForView:self.navController.presentedViewController.view animated:YES];
    [MBProgressHUD hideHUDForView:self.homeViewController.view animated:YES];
    [self.homeViewController loadObjects];
}



#pragma mark -- Facebook Methods
- (void)facebookRequestDidLoad:(id)result {
    
    
    // This method is called twice - once for the user's /me profile, and a second time when obtaining their friends. We will try and handle both scenarios in a single method.
    PFUser *user = [PFUser currentUser];
    
    NSArray *data = [result objectForKey:@"data"];

    if (data) {
        // we have friends data
        NSMutableArray *facebookIds = [[NSMutableArray alloc] initWithCapacity:[data count]];
        for (NSDictionary *friendData in data) {
            if (friendData[@"id"]) {
                [facebookIds addObject:friendData[@"id"]];
            }
        }
        
        // cache friend data
        [[SPCache sharedCache] setFacebookFriends:facebookIds];
        
        if (user) {
            if ([user objectForKey:kSPUserFacebookFriendsKey]) {
                [user removeObjectForKey:kSPUserFacebookFriendsKey];
            }
            
            if (![user objectForKey:kSPUserAlreadyAutoFollowedFacebookFriendsKey]) {
                self.hud.labelText = NSLocalizedString(@"Following Friends", nil);
                firstLaunch = YES;
                
                [user setObject:@YES forKey:kSPUserAlreadyAutoFollowedFacebookFriendsKey];
                NSError *error = nil;
                
                // find common Facebook friends already using Anypic
                PFQuery *facebookFriendsQuery = [PFUser query];
                [facebookFriendsQuery whereKey:kSPUserFacebookIDKey containedIn:facebookIds];
                
                // auto-follow Parse employees
            //    PFQuery *parseEmployeesQuery = [PFUser query];
            //    [parseEmployeesQuery whereKey:kSPUserFacebookIDKey containedIn:kPAPParseEmployeeAccounts];
                
                // combined query
                PFQuery *query = [PFQuery orQueryWithSubqueries:[NSArray arrayWithObjects:facebookFriendsQuery, nil]];
                
                NSArray *anypicFriends = [query findObjects:&error];
                
                if (!error) {
                    [anypicFriends enumerateObjectsUsingBlock:^(PFUser *newFriend, NSUInteger idx, BOOL *stop) {
                        PFObject *joinActivity = [PFObject objectWithClassName:kSPActivityClassKey];
                        [joinActivity setObject:user forKey:kSPActivityFromUserKey];
                        [joinActivity setObject:newFriend forKey:kSPActivityToUserKey];
                        [joinActivity setObject:kSPActivityTypeJoined forKey:kSPActivityTypeKey];
                        
                        PFACL *joinACL = [PFACL ACL];
                        [joinACL setPublicReadAccess:YES];
                        joinActivity.ACL = joinACL;
                        
                        // make sure our join activity is always earlier than a follow
                        [joinActivity saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                            [SPUtility followUserInBackground:newFriend block:^(BOOL succeeded, NSError *error) {
                                // This block will be executed once for each friend that is followed.
                                // We need to refresh the timeline when we are following at least a few friends
                                // Use a timer to avoid refreshing innecessarily
                                if (self.autoFollowTimer) {
                                    [self.autoFollowTimer invalidate];
                                }
                                
                                self.autoFollowTimer = [NSTimer scheduledTimerWithTimeInterval:3.0f target:self selector:@selector(autoFollowTimerFired:) userInfo:nil repeats:NO];
                                
                            }];
                        }];
                    }];
                }
                
                if (![self shouldProceedToMainInterface:user]) {
                    [self logOut];
                    return;
                }
                
                if (!error) {
                    [MBProgressHUD hideHUDForView:self.navController.presentedViewController.view animated:NO];
                    if (anypicFriends.count > 0) {
                        self.hud = [MBProgressHUD showHUDAddedTo:self.homeViewController.view animated:NO];
                        self.hud.dimBackground = YES;
                        self.hud.labelText = NSLocalizedString(@"Following Friends", nil);
                    } else {
                        [self.homeViewController loadObjects];
                    }
                }
            }
            
            [user saveEventually];
        } else {
            NSLog(@"No user session found. Forcing logOut.");
            [self logOut];
        }
    } else {
        self.hud.labelText = NSLocalizedString(@"Creating Profile", nil);
        
        if (user) {
            NSString *facebookName = result[@"name"];
            if (facebookName && [facebookName length] != 0) {
                [user setObject:facebookName forKey:kSPUserDisplayNameKey];
            } else {
                [user setObject:@"Someone" forKey:kSPUserDisplayNameKey];
            }
            
            NSString *facebookId = result[@"id"];
            if (facebookId && [facebookId length] != 0) {
                [user setObject:facebookId forKey:kSPUserFacebookIDKey];
            }
            
            [user saveEventually];
        }
        
        [FBRequestConnection startForMyFriendsWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (!error) {
                [self facebookRequestDidLoad:result];
            } else {
                [self facebookRequestDidFailWithError:error];
            }
        }];
    }

    
    
}

- (void)facebookRequestDidFailWithError:(NSError *)error {
    
    
    NSLog(@"Facebook error: %@", error);
    
    if ([PFUser currentUser]) {
        if ([[error userInfo][@"error"][@"type"] isEqualToString:@"OAuthException"]) {
            NSLog(@"The Facebook token was invalidated. Logging out.");
          //  [self logOut];
        }
    }
}

- (BOOL)isParseReachable {
    return self.networkStatus != NotReachable;
}
#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _data = [[NSMutableData alloc] init];
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    [SPUtility processFacebookProfilePictureData:_data];
}


//Called by Reachability whenever status changes.
- (void)reachabilityChanged:(NSNotification* )note {
    Reachability *curReach = (Reachability *)[note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    NSLog(@"Reachability changed: %@", curReach);
    _networkStatus = [curReach currentReachabilityStatus];
    
    if ([self isParseReachable] && [PFUser currentUser] && self.homeViewController.objects.count == 0) {
        // Refresh home timeline on network restoration. Takes care of a freshly installed app that failed to load the main timeline under bad network conditions.
        // In this case, they'd see the empty timeline placeholder and have no way of refreshing the timeline unless they followed someone.
        [self.homeViewController loadObjects];
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [FBAppCall handleOpenURL:url
                  sourceApplication:sourceApplication
                        withSession:[PFFacebookUtils session]];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    [FBAppCall handleDidBecomeActiveWithSession:[PFFacebookUtils session]];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    [[PFFacebookUtils session] close];
}

@end
