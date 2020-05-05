/*
 *  m48MenuFetch.m
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

#import "m48MenuFetch.h"
#import "patchwince.h"
#import "m48Errors.h"
#import "m48Filemanager.h"
#import "m48ModalAlertView.h"


static NSString *kSectionTitleKey = @"sectionTitleKey";
static NSString *kSectionElementsKey = @"sectionElementsKey";
static NSString *kElementTitleKey = @"elementTitleKey";
static NSString *kElementFileURLKey = @"elementFileURLKey";
static NSString *kElementFileSizeKey = @"elementFileSizeKey";
static NSString *kElementFileDestinationKey = @"elementFileDestinationKey";


static NSString *tAlertViewFetch = @"Fetch";
static NSString *tAlertViewWait = @"Downloading";
static NSString *tAlertViewSuccess = @"Success!";
static NSString *tAlertViewError = @"Error!";

@interface m48MenuFetch ()
-(void)reloadData;
- (void)tryUpdateFromWeb;

@end


@implementation m48MenuFetch

@synthesize dataSourceArray = _dataSourceArray;
@synthesize selectedDataElement = _selectedDataElement;
@synthesize waitAlertView = _waitAlertView;
@synthesize url = _url;
@synthesize localSource = _localSource;
@synthesize startDate = _startDate;
@synthesize inData = _inData;
@synthesize connection = _connection;

-(void)dealloc {
	[_url release];
	[_localSource release];
	[_waitAlertView release];
	[_selectedDataElement release];
	[_dataSourceArray release];
	[_inData release];
	[_connection release];
	
	[super dealloc];
}

- (id) initWithFilename:(NSString *)filename URL:(NSURL *)url {
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		self.title = @"Fetch";
		self.localSource = filename;
		self.url = url;
		[self reloadData];
	}
	return self;
}

-(void)reloadData {
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:_localSource];
	NSArray * temp;
	temp = (NSArray *)[NSPropertyListSerialization
					   propertyListFromData:plistXML
					   mutabilityOption:NSPropertyListMutableContainersAndLeaves
					   format:&format errorDescription:&errorDesc];
	if (!temp) {
		//DEBUG NSLog(errorDesc);
		[errorDesc release];
	}

	self.dataSourceArray = 	temp;
}

#pragma mark -
#pragma mark Implementation of Actions;

- (void)FetchStartAction:(NSDictionary *)dataSourceElement {
	static int evolutionStage = 0;
	static m48ModalAlertView * myAlertView = nil;
	
	
	switch (evolutionStage) {
		case 0:
			self.selectedDataElement = dataSourceElement;
			
			// Ask for permission
			NSMutableString * myMessage = [NSMutableString stringWithCapacity:0];
			[myMessage appendString:@"Please confirm the download of the following file from the internet:\n"];
			[myMessage appendString:[_selectedDataElement objectForKey:kElementFileURLKey]];
			
			NSNumber * fileSize = [_selectedDataElement objectForKey:kElementFileSizeKey];
			float f =  [fileSize floatValue];
			int i = 0;
			while (f/1024 > 1.0) {
				f = f / 1024;
				i++;
			}
			NSString * fileSizeString = [NSString stringWithFormat:@"\n(%.1f", f];
			if (i==0) {
				fileSizeString = [fileSizeString stringByAppendingString:@" B)"];
			}
			else if (i==1) {
				fileSizeString = [fileSizeString stringByAppendingString:@" kB)"];
			}
			else if (i==2) {
				fileSizeString = [fileSizeString stringByAppendingString:@" MB)"];
			}
			else if (i==3) {
				fileSizeString = [fileSizeString stringByAppendingString:@" GB)"];
			}
			else if (i==4) {
				fileSizeString = [fileSizeString stringByAppendingString:@" TB)"];
			}
			else {
				fileSizeString = [fileSizeString stringByAppendingString:@" Error)"];
			}
			if (fileSize > 0) {
				[myMessage appendString:fileSizeString];
			}
			
			[myAlertView release];
			myAlertView = [[m48ModalAlertView alloc] initWithTitle:tAlertViewFetch message:myMessage 
														   delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
			
			
			myAlertView = [[m48ModalAlertView alloc] initBlank];
			myAlertView.target = self;
			myAlertView.selector = @selector(FetchStartAction:);
			myAlertView.title = tAlertViewFetch;
			myAlertView.message = myMessage;
			[myAlertView.buttonTexts addObject:@"Cancel"];
			[myAlertView.buttonTexts addObject:@"Confirm"];
			[myAlertView show];
			evolutionStage = 1;
			return;
			break;
			
		case 1:
			// We have some result
			if (myAlertView.didDismissWithButtonIndex == 0) {
				goto leave;
			}
			
			// Initializing long running task
			UIDevice * device = [UIDevice currentDevice];
			if (([device respondsToSelector:@selector(isMultitaskingSupported)]) &&
				 ([device isMultitaskingSupported] == YES)) {
				_bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// Synchronize the cleanup call on the main thread in case
					// the task actually finishes at around the same time.
					dispatch_async(dispatch_get_main_queue(), ^{
						if (_bgTask != UIBackgroundTaskInvalid)
						{
							[[UIApplication sharedApplication] endBackgroundTask:_bgTask];
							_bgTask = UIBackgroundTaskInvalid;
						}
					});
				}];	
			}
			else {
				_bgTask = 0;
			}
			
			// Ok we can download: set everthing up and leave
			// Set up the wait view
			self.waitAlertView = [UIAlertView alloc];
			[_waitAlertView initWithTitle:tAlertViewWait message:@"Please wait...\n\n\n\n" delegate:self cancelButtonTitle:nil otherButtonTitles: nil];
			[_waitAlertView show];
			
			NSNumber * num = [_selectedDataElement objectForKey:kElementFileSizeKey];
			if (num != nil) {
				_fileSize = [num intValue];
			}
			else {
				_fileSize = 0;
			}
			self.startDate = [NSDate date];
			
			
			self.inData = [NSMutableData dataWithLength:0];
			
			
			NSString * src = [_selectedDataElement objectForKey:kElementFileURLKey];
			NSURL * myURL = [NSURL URLWithString:src];
			NSURLRequest * myRequest = [NSURLRequest requestWithURL:myURL];
			
			self.connection = [[NSURLConnection alloc] initWithRequest:myRequest delegate:self];
			
			goto leave;
			
			
			
			
		default:
			evolutionStage = 0;
			break;
	}
	
leave:
	[myAlertView release];
	myAlertView = nil;
	evolutionStage = 0;
	return;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSError * error1 = [NSError errorWithDomain:ERROR_DOMAIN code:EWWW userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not download file.", NSLocalizedDescriptionKey, nil]];
	[self FetchFinishedAction:error1];
	self.connection = nil;
	return;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_inData appendData:data];
	
	// Update progress
	float currentSize;
	NSTimeInterval elapsedTime;
	
	if (_waitAlertView != nil) {
		if (_fileSize == 0) {
			_waitAlertView.message = [NSString stringWithFormat:@"(unknown filesize)\n\n\n\n"];
			return;
		}
		if (_inData != nil) {
			currentSize = [_inData length];
		}
		else {
			currentSize = 0;
		}
		elapsedTime = -[_startDate timeIntervalSinceNow];
		float finished = 100.0*currentSize/_fileSize;
		elapsedTime = ((_fileSize/currentSize) - 1)*elapsedTime;
		int hours = 0;
		int minutes = 0;
		int seconds = 0;
		if (elapsedTime > 3600) {
			hours = floorf(elapsedTime/3600);
			elapsedTime -= 3600*hours;
		}
		if (elapsedTime > 60) {
			minutes = floorf(elapsedTime/60);
			elapsedTime -= 60*minutes;
		}
		seconds = elapsedTime;
		
		_waitAlertView.message = [NSString stringWithFormat:@"%.0f %%\n%02d:%02d:%02d\n\n\n", finished, hours, minutes, seconds];
	}
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSError * error = nil;
	self.connection = nil;

	
	
	// Fetch file from the internet
	NSString * tempString;
	NSString * src = [_selectedDataElement objectForKey:kElementFileURLKey];
	NSString * dest = [_selectedDataElement objectForKey:kElementFileDestinationKey];
	BOOL destIsDirectory = NO;
	if ([dest characterAtIndex:[dest length]-1] == '/')
		destIsDirectory = YES;
	
	
	// Write file to disk
	tempString = getFullDocumentsPathForFile([dest stringByDeletingLastPathComponent]);
	
	NSFileManager * filemanager = [NSFileManager defaultManager];
	BOOL isDir;
	if (![filemanager fileExistsAtPath:tempString isDirectory:&isDir]) {
		if(![filemanager createDirectoryAtPath:tempString withIntermediateDirectories:YES attributes:nil error:&error]) {
			self.inData = nil;
			goto leave;
		}
	}
	else if (!isDir) {
		self.inData = nil;
		error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:nil];
		goto leave;
	}
	
	tempString = [tempString stringByAppendingPathComponent:[src lastPathComponent]];
	[_inData writeToFile:tempString options:NSAtomicWrite error:&error];
	if (error != nil) {
		tempString = @"Could not write file to disk";
		error = [NSError errorWithDomain:ERROR_DOMAIN code:EWWW userInfo:[NSDictionary dictionaryWithObjectsAndKeys:tempString, NSLocalizedDescriptionKey, nil]];
		goto leave;	
	}
	
	
	// Unzip file
	dest = getFullDocumentsPathForFile(dest);
	if(![m48Filemanager unzipFile:tempString to:dest isDirectory:destIsDirectory doOverwrite:YES doDeleteSource:YES withError:&error]) {
		tempString = @"Could not extract file";
		error = [NSError errorWithDomain:ERROR_DOMAIN code:EWWW userInfo:[NSDictionary dictionaryWithObjectsAndKeys:tempString, NSLocalizedDescriptionKey, nil]];
		goto leave;	
	}
	
	UIDevice * device = [UIDevice currentDevice];
	if (([device respondsToSelector:@selector(isMultitaskingSupported)]) &&
		([device isMultitaskingSupported] == YES)) {
		// This marks the end of the long running task
		// Synchronize the cleanup call on the main thread in case
		// the expiration handler is fired at the same time.
		dispatch_async(dispatch_get_main_queue(), ^{
			if (_bgTask != 0)
			{
				[[UIApplication sharedApplication] endBackgroundTask:_bgTask];
				_bgTask = UIBackgroundTaskInvalid;
			}
		});
	}
	
leave:
	self.inData = nil;
	[self FetchFinishedAction:error];
	return;
}
	
- (void)FetchFinishedAction:(NSError *)error {
	
	if (error != nil) {
		[_waitAlertView dismissWithClickedButtonIndex:0 animated:YES];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:tAlertViewError message:[error.userInfo valueForKey:NSLocalizedDescriptionKey] 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];	
		[alert release];
	} 
	else {	
		[_waitAlertView dismissWithClickedButtonIndex:0 animated:YES];
		NSString * message = [@"File sucessfully downloaded to " stringByAppendingString:[_selectedDataElement objectForKey:kElementFileDestinationKey]];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:tAlertViewSuccess message:message 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];	
		[alert release];
	}

}

#pragma mark
#pragma mark Delegate for UIAlertView

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if ([alertView.title compare:tAlertViewFetch] == 0) {
		/*
		if (buttonIndex != 1) {
			self.selectedDataElement = nil;
			return;
		}
		[self performSelectorInBackground:@selector(FetchAndProcessInBackgroundAction) withObject:nil];
		
		// Put itself to wait
		_waitAlertView = [UIAlertView alloc];
		[_waitAlertView initWithTitle:tAlertViewWait message:@"Please wait...\n\n\n\n" delegate:self cancelButtonTitle:nil otherButtonTitles: nil];
		[_waitAlertView show];
		 */
		/*
		NSNumber * num = [_selectedDataElement objectForKey:kElementFileSizeKey];
		if (num != nil) {
			_fileSize = [num intValue];
		}
		else {
			_fileSize = 0;
		}
		self.startDate = [NSDate date];
		if ([_progressTimer isValid] == YES) {
			[_progressTimer invalidate];
		}
		self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];
		*/
		
		
	}
	else if ([alertView.title compare:tAlertViewSuccess] == 0) {
		; //[self.navigationController popViewControllerAnimated:YES];
		self.selectedDataElement = nil;
	}
	else  if ([alertView.title compare:tAlertViewWait] == 0) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
	else  if ([alertView.title compare:tAlertViewError] == 0) {
		self.selectedDataElement = nil;
	}
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
	if ([alertView.title compare:tAlertViewWait] == 0) {
		UIActivityIndicatorView * activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		//[activityIndicator setHidesWhenStopped:NO];
		CGRect r = [alertView bounds];
		[activityIndicator setCenter:CGPointMake(0.5*r.size.width,0.65*r.size.height)];	
		[_waitAlertView addSubview:activityIndicator];
		[activityIndicator startAnimating];
		[activityIndicator release];
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	}
}
	
#pragma mark -
#pragma mark Implementation of viewController;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (void)viewDidAppear:(BOOL)animated {
	[self.navigationController setToolbarHidden:YES animated:animated];
	[self tryUpdateFromWeb];
	[super viewDidAppear:animated];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	////DEBUG NSLog(@"numberOfSectionsInTableView");
	return [self.dataSourceArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	////DEBUG NSLog(@"tableView:titleForHeaderInSection");
	return [[self.dataSourceArray objectAtIndex: section] valueForKey:kSectionTitleKey];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	////DEBUG NSLog(@"tableView:numberOfRowsInSection");
	NSDictionary * aDictionary = [self.dataSourceArray objectAtIndex:section];
	NSArray * anArray = [aDictionary objectForKey:kSectionElementsKey];
	return [anArray count];
}

// to determine which UITableViewCell to be used on a given row.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	////DEBUG NSLog(@"tableView:cellForRowAtIndexPath");
	UITableViewCell *cell = nil;
	
	
	static NSString *kDisplayCell_ID = @"DisplayCellID";
	cell = [self.tableView dequeueReusableCellWithIdentifier:kDisplayCell_ID];
	if (cell == nil)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDisplayCell_ID] autorelease];
		//cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	NSDictionary * aDictionary = [self.dataSourceArray objectAtIndex: indexPath.section];
	NSArray * anArray = [aDictionary valueForKey:kSectionElementsKey];
	aDictionary = [anArray objectAtIndex: indexPath.row];
	cell.textLabel.text = [aDictionary valueForKey:kElementTitleKey];
	
	return cell;
}


// the table's selection has changed, show the alert or action sheet
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	
	// deselect the current row (don't keep the table selection persistent)
	[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	
	NSDictionary * aDictionary = [self.dataSourceArray objectAtIndex: indexPath.section];
	NSArray * anArray = [aDictionary valueForKey:kSectionElementsKey];
	aDictionary = [anArray objectAtIndex: indexPath.row];
	
	[self FetchStartAction:aDictionary];
}


#pragma mark -
#pragma mark Auto update of list;
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
				if ((oldDate == nil) || (abs([oldDate timeIntervalSinceNow]) > 7*24*3600)) { // Once every three week
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
			// Actually everything went successful
			[self reloadData];
			[self.tableView reloadData];
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

@end
