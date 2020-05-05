/*
 *  m48MenuHTMLContent.m
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

#import "m48MenuHTMLContent.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface m48MenuHTMLContent ()

- (void)tryUpdateFromWeb;

@end


@implementation m48MenuHTMLContent

@synthesize webView = _webView;
@synthesize url = _url;
@synthesize localSource = _localSource;

- (id) initWithTitle:(NSString *)title filename:(NSString *)filename URL:(NSURL *)url {
	if ((self = [super init])) {
		[self setUrl:url];
		[self setTitle:title];
		[self setLocalSource:filename];
	}
	return self;
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0,0,320,480)];
	[_webView setScalesPageToFit:YES];
	[_webView setDelegate:self];
	// load local file
	[_webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:_localSource]]];
	[self setView:_webView];
	
	[self tryUpdateFromWeb];
}

//- (void)webViewDidStartLoad:(UIWebView *)webView {
//	NSString * temp = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
//	temp = [NSString stringWithFormat:@"var version = \"%@\";", temp];
//	[_webView stringByEvaluatingJavaScriptFromString:temp];
//}

// Alternate version
- (void)webViewDidFinishLoad:(UIWebView *)webView {
	NSString * temp = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	//[_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"tryParsingAppVersion(%@);",version]];
	temp = [NSString stringWithFormat:@"document.getElementById(\"version\").innerHTML = \"%@\";", temp];
	[_webView stringByEvaluatingJavaScriptFromString:temp];
}

- (void)viewDidAppear:(BOOL)animated {
	[self.navigationController setToolbarHidden:YES animated:animated];
	[super viewDidAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)tryUpdateFromWeb {
	static int evolutionStage = 0;
	NSAutoreleasePool * pool = nil;
	
	switch (evolutionStage) {
		case 0:
			evolutionStage = 1;
			
			// Check if sth has to be done at all
			if (_url == nil) {
				goto cleanupAndLeave;
			}
			
			// Only if enabled
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"informationAutoUpdate"] == NO) {
				goto cleanupAndLeave;
			}
			
			// Two cases one has to update: last time too long ago or file not present
			BOOL needsUpdate = NO;
			if ([[NSFileManager defaultManager] fileExistsAtPath:_localSource] == NO) {
				needsUpdate = YES;
			}
			
			NSString * oldDateString = [[NSUserDefaults standardUserDefaults] objectForKey:[@"informationLastUpdate" stringByAppendingString:self.title]];
			if (oldDateString == nil) {
				needsUpdate = YES;
			}
			else {
				NSDateFormatter * formatter = [[[NSDateFormatter alloc] init] autorelease];
				[formatter setFormatterBehavior:NSDateFormatterBehaviorDefault];
				[formatter setDateFormat:@"yyyy.MM.dd 'at' HH:mm"];
				//[formatter setDateStyle:NSDateFormatterShortStyle];
				NSDate * oldDate = [formatter dateFromString:oldDateString];
				// Retrieve update frequency
				int diffInSec;
				NSString * updateFrequency = [[NSUserDefaults standardUserDefaults] objectForKey:@"informationAutoUpdateFrequency"];
				if ([updateFrequency isEqual:@"daily"]) {
					diffInSec = 24*3600;
				}
				else if ([updateFrequency isEqual:@"weekly"]) {
					diffInSec = 7*24*3600;
				}
				else if ([updateFrequency isEqual:@"monthly"]) {
					diffInSec = 30*7*24*3600;
				}
				else  {
					diffInSec = 0;
				}
					
				if ((oldDate == nil) || (abs([oldDate timeIntervalSinceNow]) > diffInSec)) {
					needsUpdate = YES;
				}
			}
				
			if (needsUpdate == NO) {
				goto cleanupAndLeave;
			}
				
			
			
			[self performSelectorInBackground:@selector(tryUpdateFromWeb) withObject:nil];
			return;
		case 1:
			evolutionStage = 2;
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
			
			// See when we have updated last time
			// TO BE DONE
			
			
			// See if we are online
			
			// First check if the address is reachable
			NSString * tempString = [_url host];
			SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [tempString UTF8String]);
			if (reachability == NULL)
			{
				goto cleanupAndLeave;
			}
			SCNetworkReachabilityFlags flags;
			if (SCNetworkReachabilityGetFlags(reachability, &flags))
			{
				if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
					goto cleanupAndLeave;
				}
			}
			
			
			// We are online. Lets get the data
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
			
			
			NSError * error = nil;
			NSData * file = [[NSData alloc] initWithContentsOfURL:_url options:NSMappedRead error:&error];
			if (error != nil) {
				[file release];
				goto cleanupAndLeave;
			}
			
			// Elaborate if the directory needs to be created
			NSString * baseDir = [_localSource stringByDeletingLastPathComponent];
			if ([[NSFileManager defaultManager] fileExistsAtPath:baseDir] == NO) {
				[[NSFileManager defaultManager] createDirectoryAtPath:baseDir withIntermediateDirectories:YES attributes:nil error:&error];
				if (error != nil) {
					[file release];
					goto cleanupAndLeave;
				}
			}
			
			
			// Save it to disk
			[file writeToFile:_localSource atomically:YES];
			[file release];
			file = nil;
			
			// Now we have to determine if there are image-references within the document
			// No directories are supported, neither anything else but images
			// These MUST be <img src="IMAGENAME.png"....!
			NSString * contentOfFile = [NSString stringWithContentsOfFile:_localSource];
			
			NSRange searchRange;
			
			searchRange.location = 0;
			searchRange.length = [contentOfFile length];
			
			NSRange findRange;
			NSMutableArray * files = [NSMutableArray arrayWithCapacity:0];
			
			unichar mark = [@"\"" characterAtIndex:0];
			BOOL finished = NO;
			
			while (!finished) {
				findRange = [contentOfFile rangeOfString:@"<img src=\"" options:NSCaseInsensitiveSearch range:searchRange];
				if ((findRange.location == NSNotFound) && (findRange.length == 0)) {
					// Not found
					finished = YES;
				}
				
				if (!finished) {
					findRange.location = findRange.location + findRange.length;
					findRange.length = 0;
					// Search the trailing "
					while (([contentOfFile characterAtIndex:(findRange.location+findRange.length)] != mark) &&
						   (findRange.location + findRange.length) <= (searchRange.location + searchRange.length)) {
						if ((findRange.location + findRange.length) > (searchRange.location + searchRange.length)) {
							finished = YES;
						}
						else {
							findRange.length = findRange.length + 1;
						}
					}
					if (!finished) {
						// Ok, we seem to have found a valid entry
						[files addObject:[contentOfFile substringWithRange:findRange]];
						searchRange.location = findRange.location + findRange.length;
						searchRange.length = searchRange.length - searchRange.location;
					}
				}
			}
			
			// Now everything we have to do is download the files to disk, if they not yet exist!
			NSString * urlBase = [_url absoluteString];
			urlBase = [urlBase stringByDeletingLastPathComponent];
			
			NSString * localBase = [_localSource stringByDeletingLastPathComponent];
			
			for (int i=0; i < [files count]; i++) {
				NSString * tmpFilename = [files objectAtIndex:i];
				if ([[NSFileManager defaultManager] fileExistsAtPath:[localBase stringByAppendingPathComponent:tmpFilename]] == NO) {
					// Download
					error = nil;
					NSURL * tmpURL = [NSURL URLWithString:[urlBase stringByAppendingPathComponent:tmpFilename]];
					file = [[NSData alloc] initWithContentsOfURL:tmpURL options:NSMappedRead error:&error];
					if (error != nil) {
						[file release];
						goto cleanupAndLeave;
					}
					// Save it to disk
					[file writeToFile:[localBase stringByAppendingPathComponent:tmpFilename] atomically:YES];
					[file release];
					file = nil;
				}
			}
			
			// Store the update date
			NSDateFormatter * formatter = [[[NSDateFormatter alloc] init] autorelease];
			[formatter setFormatterBehavior:NSDateFormatterBehaviorDefault];
			[formatter setDateFormat:@"yyyy.MM.dd 'at' HH:mm"];
			//[formatter setDateStyle:NSDateFormatterShortStyle];
			NSDate * now = [NSDate date];
			NSString * nowString = [formatter stringFromDate:now];
			[[NSUserDefaults standardUserDefaults] setObject:nowString forKey:[@"informationLastUpdate" stringByAppendingString:self.title]];
			
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
			[pool release];
			pool = nil;
			[self performSelectorOnMainThread:@selector(tryUpdateFromWeb) withObject:nil waitUntilDone:NO];
			return;
		case 2:
			// Actually everything went successful, lets load if we are still on top
			if (self.navigationController.topViewController == self) {
				[_webView reload]; 
			}
			goto cleanupAndLeave;
		default:
			break;
	}
	return;
	
	
cleanupAndLeave:
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	evolutionStage = 0;
	[pool release];
	pool = nil;
	return; // Leave and do nothing
}
/*
- (void)webViewDidStartLoad:(UIWebView *)webView{
	if ([_url isFileURL] == NO) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	}
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}
*/
- (void)dealloc {
	[_localSource release];
	self.webView = nil;
    [super dealloc];
}

@end