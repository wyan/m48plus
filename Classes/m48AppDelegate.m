/*
 *  m48AppDelegate.m
 *
 *  This file is part of m48
 *
 *  Copyright (C) 2009 Markus Gonser, m48@mksg.de
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 * 
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 */

#import "m48AppDelegate.h"
#import "m48NavigationController.h"
#import "UIDevice+Resolutions.h"

// for the HTTP server
#ifdef VERSIONPLUS
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import "localhostAdresses.h"
#endif

@implementation m48AppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;
@synthesize emulatorViewController = _emulatorViewController;
#ifdef VERSIONPLUS
@synthesize httpServer = _httpServer;
@synthesize addresses = _addresses;
@synthesize serverIsRunning = _serverIsRunning;
#endif
@synthesize isIPad = _isIPad;

- (void) applicationDidFinishLaunching:(UIApplication*)application
{

	
	// Load Application standard defaults
	NSString * filename;
    filename = @"defaults.plist";
    
	filename = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
	NSDictionary * defaults = [NSDictionary dictionaryWithContentsOfFile:filename];
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:defaults];
	NSInteger timesAppLaunched = [userDefaults integerForKey:@"internalTimesAppLaunched"];
	[userDefaults setInteger:(timesAppLaunched+1) forKey:@"internalTimesAppLaunched"];		
	
	//Create a full-screen window
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setBackgroundColor:[UIColor blackColor]];
	

    // Check on which device this is run on
    UIDeviceResolution test = UIDeviceResolution_Unknown;
    
    test = [[UIDevice currentDevice] resolution];
    if (test == UIDeviceResolution_iPadStandard) {
        [userDefaults setBool:YES forKey:@"internalIsIPad"];
    }
    else if (test == UIDeviceResolution_iPadRetina) {
        [userDefaults setBool:YES forKey:@"internalIsRetina"];
        [userDefaults setBool:YES forKey:@"internalIsIPad"];
    } else if (test == UIDeviceResolution_iPhoneRetina4) {
        [userDefaults setBool:YES forKey:@"internalIsRetina"];
        [userDefaults setBool:YES forKey:@"internalIsIPhone5"];
    } else if (test == UIDeviceResolution_iPhoneRetina35) {
        [userDefaults setBool:YES forKey:@"internalIsRetina"];
    }
    
    
    // New code for device detection
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat scale = 1.0;
    
    if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
    {
        scale = [[UIScreen mainScreen] scale];
    }
    
    NSString * model = nil;
    if (screenSize.height == 480) {
        if (scale > 1.9) {
            model = @"@2x";
        }
        else {
            model = @"";
        }
    }
    else if (screenSize.height == 568) {
        if (scale > 1.9) {
            model = @"-568h@2x";
        }
    }
    else if (screenSize.height == 667) {
        if (scale > 1.9) {
            model = @"-667h@2x";
        }
    }
    else if (screenSize.height == 736) {
        if (scale > 2.9) {
            model = @"-736h@3x";
        }
    }
    else if (screenSize.height == 1024) {
        if (scale > 1.9) {
            model = @"2x~iPad";
        }
        else {
            model = @"~iPad";
        }
    }
    if (model == nil) {
        model = @"";
    }
    [userDefaults setObject:model forKey:@"device_model"];
    
    NSLog(@"model = %@", model);
    
    
	// Initialisieren der viewControllers
	_emulatorViewController = [[m48EmulatorViewController alloc] init];

	// Die view des view-Controllers hinzufügen.
	//[_window addSubview:_emulatorViewController.view];
	
	_navigationController = [[m48NavigationController alloc] initWithRootViewController:_emulatorViewController];
	[_window setRootViewController:_navigationController];
    
	//Show the window
	[_window makeKeyAndVisible];	
	
#ifdef VERSIONPLUS	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"serverEnabled"] == YES) {
		//[self performSelectorInBackground:@selector(setupAndStartServer) withObject:nil]; // ACHTUNG: started dann nicht richtig.
		[self setupAndStartServer];
	}
#endif
	//DEBUG NSLog(@"applicationDidFinishLaunching:");
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[_emulatorViewController applicationWillTerminate:(UIApplication *)application];
	// Set the statusbar back to the settings in the Info-plist.
	//[application setStatusBarHidden:NO animated:NO];
	//[application setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
	//DEBUG NSLog(@"applicationWillTerminate:");
}

- (void)applicationWillResignActive:(UIApplication *)application {
	[_emulatorViewController pause];
	//DEBUG NSLog(@"applicationWillResignActive:");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	if (_navigationController.topViewController == _emulatorViewController) {
		[_emulatorViewController start];
	}
	//DEBUG NSLog(@"applicationDidBecomeActive:");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
#ifdef VERSIONPLUS
    // Check if the WiFi Server is still running
#endif    
	//DEBUG NSLog(@"applicationWillEnterForeground:");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	[_emulatorViewController applicationWillTerminate:(UIApplication *)application];
	//DEBUG NSLog(@"applicationDidEnterBackground:");
}

// Release resources when they are no longer needed,
- (void) dealloc {
#ifdef VERSIONPLUS
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_httpServer release];
	[_addresses release];
#endif
	[_navigationController release];
	[_emulatorViewController release];
	[_window release];	
	[super dealloc];
}

#pragma mark HTTP Server related
#ifdef VERSIONPLUS
// HTTP Server

- (void)setupAndStartServer {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	// HTTP Server
	// configure the http server
	if (_httpServer == nil) {
	
		NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
		
		self.httpServer = [HTTPServer new];
		[_httpServer setType:@"_http._tcp."];
		[_httpServer setConnectionClass:[MyHTTPConnection class]];
		[_httpServer setDocumentRoot:[NSURL fileURLWithPath:root]];
		
		/*
		 #if TARGET_IPHONE_SIMULATOR
		 [httpServer setPort:8080];
		 #else
		 [httpServer setPort:80];
		 #endif
		 */	
		
		[_httpServer setPort:8080];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
		[localhostAdresses performSelectorInBackground:@selector(list) withObject:nil];
		
		/*
		 NSError *error;
		 if(![httpServer start:&error])
		 {
		 //DEBUG NSLog(@"Error starting HTTP Server: %@", error);
		 } */
		
		_serverIsRunning = NO;
	}
	
	[self startStopServer:YES];
	
	[pool release];
}

- (void)startStopServer:(BOOL)isOn
{
	if (isOn)
	{
		NSError *error;
		if(![_httpServer start:&error])
		{
			_serverIsRunning = NO;
		}
		else
		{
			//[self displayInfoUpdate:nil];
			_serverIsRunning = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"ServerStatusChanged" object:nil userInfo:(id)[NSNumber numberWithBool:YES]];
			
		}
	}
	else
	{
		[_httpServer stop];
		_serverIsRunning = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ServerStatusChanged" object:nil userInfo:(id)[NSNumber numberWithBool:NO]];
		
	}
}

- (void) toggleServer:(BOOL)status
{
	if (_serverIsRunning == status)
	{
		return;
	}
	
	if (status)
	{
		NSError *error;
		if(![_httpServer start:&error])
		{
			_serverIsRunning = NO;
		}
		else
		{
			//[self displayInfoUpdate:nil];
			_serverIsRunning = YES;
		}
	}
	else
	{
		[_httpServer stop];
		_serverIsRunning = NO;
	}
}

#pragma mark Internal Server
- (void)displayInfoUpdate:(NSNotification *) notification
{
	if(notification)
	{
		self.addresses = [[notification object] copy];
	}
	if(_addresses == nil)
	{
		return;
	}
}
#endif

@end
