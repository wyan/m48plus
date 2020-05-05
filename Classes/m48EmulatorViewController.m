/*
 *  m48EmulatorViewController.m
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

#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

#import "m48EmulatorViewController.h"
#import "m48NavigationController.h"
#import "m48MenuMain.h"
#import "m48MenuFetch.h"
#import "m48AppDelegate.h"
#import "m48Filemanager.h"
#import "m48Errors.h"
#import "m48ModalAlertView.h"

#import "emu48.h"
#import "xml.h"
#import "io.h"

#pragma mark -
@implementation TouchDict

-(id)init {
	if (self = [super init]) {
		for (int i=0; i<MAXTOUCHES; i++) {
			[self clearPos:i];
		}
	}
	return self;
}

-(void)dealloc {
	for (int i=0; i<MAXTOUCHES; i++) {
		[self clearPos:i];
	}
	[super dealloc];
}	
	
-(void)clearPos:(int)pos {
	if ((pos < 0) || (pos >= MAXTOUCHES)) {
		return;
	}
	_touchDictData[pos].posIsValid = NO;
	_touchDictData[pos].lostFocus = YES;
	_touchDictData[pos].timerFired = NO;
	NSTimer * timer = _touchDictData[pos].timer;
    if (timer != nil) {
		if ([timer isValid]) {
			// Debug
			//DEBUG multouchinput NSLog(@"Invalidate timer now");
            //printf("Invalidated timer=%d\n", (unsigned int) timer);
			[timer invalidate];
        }
        [timer release];
	}
	_touchDictData[pos].timer = nil;
	_keys[pos] = nil;
}


-(void)clearKey:(id)key {
	int i = [self findKey:key];
    //printf("\nclearKey ==> key = %d, pos = %d\n", key, i);
	if ((i != -1) && (i < MAXTOUCHES)) {
		//Dabug
		//TouchDictData data = _touchDictData[i];
		////DEBUG multouchinput NSLog([NSString stringWithFormat:@"clearKey:\npos.x=%f\npos.y=%f\nposIsValid=%d\nlostFocus=%d\ntimerFired=%d\ntimer=%X\nkey=%X\n",data.pos.x,data.pos.y,data.posIsValid,data.lostFocus,data.timerFired,data.timer,key,nil]);
		
		[self clearPos:i];
	}
}


-(int)findKey:(id)key {
	int i;
	for (i=0; i < MAXTOUCHES; i++) {
		if (_keys[i] == key) {
			break;
		}
	}
	if (i == MAXTOUCHES) {
		return -1;
	}
	else {
		return i;
	}
}

-(TouchDictData *)touchDictDataForKey:(id)key {
	int i = [self findKey:key];
	if ((i != -1) && (i < MAXTOUCHES)) {
		//Dabug
		//TouchDictData data = _touchDictData[i];
		////DEBUG multouchinput NSLog([NSString stringWithFormat:@"touchDictDataForKey:\npos.x=%f\npos.y=%f\nposIsValid=%d\nlostFocus=%d\ntimerFired=%d\ntimer=%X\nkey=%X\n",data.pos.x,data.pos.y,data.posIsValid,data.lostFocus,data.timerFired,data.timer,key,nil]);
		
		return &(_touchDictData[i]);
	}
	else {
		return NULL;
	}
}

-(int)findfreePos {
	for (int i = 0; i < MAXTOUCHES; i++) {
		if (_keys[i] == nil) {
			return i;
		}
	}
	return -1;
}
		 
		 
-(BOOL)setTouchDictData:(TouchDictData)data forKey:(id)key {
	int i = [self findKey:key];
	if (i == -1)
	{
		i = [self findfreePos];
		if (i == -1) {
			return NO;
		}
	}
	NSTimer * timer = data.timer;
	[timer retain];
    //printf("\nkeep timer id = %d\n", timer);
	[_touchDictData[i].timer release];
	_touchDictData[i] = data;
	_keys[i] = key;
	
	// DEBUG
	////DEBUG multouchinput NSLog([NSString stringWithFormat:@"setTouchDictData:\npos.x=%f\npos.y=%f\nposIsValid=%d\nlostFocus=%d\ntimerFired=%d\ntimer=%X\nkey=%X\n",data.pos.x,data.pos.y,data.posIsValid,data.lostFocus,data.timerFired,data.timer,key,nil]);
	

	return YES;
}
		 
			 
@end

#pragma mark -
@interface m48EmulatorViewController ()
- (void)startupEmulator:(id)anObject;
@end

#pragma mark -

@implementation m48EmulatorViewController

@synthesize emulator = _emulator;
@synthesize emulatorAudio = _emulatorAudio;
@synthesize emulatorView = _emulatorView;
@synthesize startupPreview = _startupPreview;
@synthesize autoSetupCalcType = _autoSetupCalcType;
@synthesize autoSetupSkinType = _autoSetupSkinType;
//@synthesize screenshot = _screenshot;
@synthesize lcdRect = _lcdRect;
@synthesize actionQueue = _actionQueue;
@synthesize actionQueueTimer = _actionQueueTimer;
@synthesize touchDict = _touchDict;
@synthesize tapDict = _tapDict;

-(id)init {
	if (self = [super init]) {
		self.wantsFullScreenLayout = YES;
		
		// Load startupPreview with animazed activity indicator and try to open Document in Background
		_emulatorOk = NO;
		
		// Init touchesTrackingData
		[_touchDict release];
		_touchDict = [[TouchDict alloc] init];
		[_tapDict release];
		_tapDict = [[TouchDict alloc] init];
		
		// Handling action queue
		self.actionQueue = [NSMutableArray arrayWithCapacity:0];
		_autoSetupInProgress = NO;
		
		// Managing orientation lock
		_shouldLockToOrientation = NO;
		
		// iPhone 4 compatibility
		_screenScale = 0.0;
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			_screenScale = [[UIScreen mainScreen] scale];
		}
		if (_screenScale==0.0) _screenScale=1.0;
	}
	return self;
}

- (void)startupEmulator:(id)anObject {
	static int evolutionStage = 0;
	static m48ModalAlertView * myAlertView = nil;
	static BOOL needsStartupMaintenance = NO;
	static BOOL needsStartupScript = NO;
	static BOOL autoLoadOnStartup = NO;
	static BOOL factoryReset = NO;
	static NSError * error = nil;
	NSAutoreleasePool * pool;
	NSUserDefaults * userDefaults;
	// Fast startup performance means:
	// - Everything which we need for the other cases than regular startup have to be performed
	//   at the time they are needed and NOT before.
	/* Quickfix for someone whos App crashed straight at startup
	[self gotoMenu];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentXmlDirectory"];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentXmlFilename"];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentDocumentDirectory"];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentDocumentFilename"];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentVersionNumber"];
	return;
	*/
	switch (evolutionStage) {
		case 0:
			//DEBUG NSLog(@"Stage 0")
			evolutionStage = 1; // Set next step
			
			userDefaults = [NSUserDefaults standardUserDefaults];
			autoLoadOnStartup = [userDefaults boolForKey:@"filesAutoloadOnStartup"];
			factoryReset = [userDefaults boolForKey:@"resetShouldReset"];
			if (factoryReset == YES) {
				if (myAlertView == nil) {;
					myAlertView = [[m48ModalAlertView alloc] initBlank];
					myAlertView.target = self;
					myAlertView.selector = @selector(startupEmulator:);
					myAlertView.title = @"WARNING";
#ifdef VERSIONPLUS
					myAlertView.message = @"Do you really want to reset m48+ to factory default?\n\n ALL DATA WILL BE DELETED!";
#else
					myAlertView.message = @"Do you really want to reset m48 to factory default?\n\n ALL DATA WILL BE DELETED!";
#endif
					[myAlertView.buttonTexts addObject:@"Cancel"];
					[myAlertView.buttonTexts addObject:@"Reset"];
					[myAlertView show];
					evolutionStage = 0;
					return;
				}
				else {
					
					if (myAlertView.didDismissWithButtonIndex == 1) {
						// RESET
						int timesAppLaunched = [userDefaults integerForKey:@"internalTimesAppLaunched"];
#ifdef VERSIONPLUS		
						BOOL internalIsActivated = [userDefaults boolForKey:@"internalIsActivated"];
						BOOL internalIsDeactivated = [userDefaults boolForKey:@"internalIsDeactivated"];
#endif
						[userDefaults removePersistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]];
						[userDefaults setInteger:timesAppLaunched forKey:@"internalTimesAppLaunched"];
#ifdef VERSIONPLUS	
						[userDefaults setBool:internalIsActivated forKey:@"internalIsActivated"];
						[userDefaults setBool:internalIsDeactivated forKey:@"internalIsDeactivated"];
#endif
						[[NSFileManager defaultManager] removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"/Documents"] error:NULL];
						[_startupPreview loadDefaultImage];
						[_startupPreview setNeedsDisplay];
					}
					[userDefaults setBool:NO forKey:@"resetShouldReset"];
					[myAlertView release];
					myAlertView = nil;
				}	
			}
			else {
				// Check startupInProgress flag for heavy crash detection:
				if ([userDefaults boolForKey:@"internalStartupInProgress"] == YES) {
					[userDefaults setObject:@"" forKey:@"internalCurrentDocumentFilename"];
					[userDefaults setObject:@"" forKey:@"internalCurrentDocumentDirectory"];
					[userDefaults setObject:@"" forKey:@"internalCurrentXmlFilename"];
					[userDefaults setObject:@"" forKey:@"internalCurrentXmlDirectory"];
					// Last time the startup didnt finish properly. It must have been a crash.
					if (myAlertView == nil) {;
						myAlertView = [[m48ModalAlertView alloc] initBlank];
						myAlertView.target = self;
						myAlertView.selector = @selector(startupEmulator:);
						myAlertView.title = @"WARNING";
						myAlertView.message = @"A crash has been detected on last launch. The calculator opened last was closed therefore.";
						[myAlertView.buttonTexts addObject:@"OK"];
						[myAlertView show];
						evolutionStage = 0;
						return;
					}
					else {
						[myAlertView release];
						myAlertView = nil;
					}	
				}
			}
			[userDefaults setBool:YES forKey:@"internalStartupInProgress"];
			[userDefaults synchronize];
			
		case 1:
			//DEBUG NSLog(@"Stage 1")
			evolutionStage = 2; // Set next step
			// Running on Main thread:
			// Tasks: 
			//  1) Check if first start and display welcome message if so
			
			// 1) 
			NSString * currentVersionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
			NSString * defaultsVersionNumber = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentVersionNumber"];
			if (([currentVersionNumber isEqual:defaultsVersionNumber] == NO)) {
				// First time started
				needsStartupMaintenance = YES; // For later
				[myAlertView release];
				myAlertView = [[m48ModalAlertView alloc] initBlank];
				myAlertView.target = self;
				myAlertView.selector = @selector(startupEmulator:);
				myAlertView.title = @"Hello";
				//myAlertView.message = @"Welcome to m48+\n\nIMPORTANT:\nAt first start, additional installation steps are required:\n\n(1)\nDownload the ROMs with the menu command 'Fetch...'\n\n(2)\nCreate a new emulator document.";
#ifdef VERSIONPLUS
				myAlertView.message = @"Welcome to m48+\n\n\nPlease give me few seconds to finish installation.\n\nAfter that you will be guided through an auto setup procedure.\n\nAn INTERNET CONNECTION is REQUIRED for the download of the ROM!";
#else
				myAlertView.message = @"Welcome to m48\n\n\nPlease give me few seconds to finish installation.";
#endif
				[myAlertView.buttonTexts addObject:@"OK"];
				
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				return;
			}
		case 2:
			//DEBUG NSLog(@"Stage 2")
			evolutionStage = 3; // Set next step
			// Running on Main Thread
			// Tasks:
			//  1) Start animating again
			//  2) Call myself in background
			[_startupPreview startAnimating];
			NSString * tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentDocumentFilename"];
			if ((needsStartupMaintenance == NO) && (tmpString != nil) && ([tmpString length] > 0)) {
				evolutionStage = 6;
			}
			[self performSelectorInBackground:@selector(startupEmulator:) withObject:nil];
			return;
		case 3:
			//DEBUG NSLog(@"Stage 3")
			evolutionStage = 4; // Set next step
			// Running on Secondary Thread
			// Tasks:
			// 1) Check if first start and perform startup maintenance
			// 2) Check if emulator has to be set up and a document to be loaded
			// 3) Call myself on main thread again
			pool = [[NSAutoreleasePool alloc] init];
			
			// 1)
			if (needsStartupMaintenance) {
				if (![m48Filemanager unpackApplicationDocumentsWithError:&error]) {
					[error retain];
				}
				else {
					NSString * currentVersionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
					NSString * defaultsVersionNumber = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentVersionNumber"];

					// Convert saved data file from previous version to new format:
					[m48Filemanager migrateFromVersion:defaultsVersionNumber toVersion:currentVersionNumber];
					
					// Everything went successful, lets overwrite the defaults
					[[NSUserDefaults standardUserDefaults] setObject:currentVersionNumber forKey:@"internalCurrentVersionNumber"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    needsStartupMaintenance = NO;
				}
				DeleteXmlCacheFile();
			}	
			[pool release];
			pool = nil;
			[self performSelectorOnMainThread:@selector(startupEmulator:) withObject:nil waitUntilDone:NO];
			return;	
		case 4:
			//DEBUG NSLog(@"Stage 4")
			// Running on main thread
			evolutionStage = 5; // Set next step
			[_startupPreview stopAnimating];
#ifdef VERSIONPLUS
			[self autoSetup];
#else
            NSString * skinfilename;
            
            userDefaults = [NSUserDefaults standardUserDefaults];
            if ([userDefaults boolForKey:@"internalIsIPhone5"] == YES) {
                skinfilename = @"Skins/HP48G/Steel48G_LE-568h@2x.xml";
            }
            else if ([userDefaults boolForKey:@"internalIsIPad"] == YES) {
                if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                    skinfilename = @"Skins/HP48G/Steel48G_LE@2x~iPad.xml";
                }
                else {
                    skinfilename = @"Skins/HP48G/Steel48G_LE~iPad.xml";
                }
            }
            else {
                if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                    skinfilename = @"Skins/HP48G/Steel48G_LE@2x.xml";
                }
                else {
                    skinfilename = @"Skins/HP48G/Steel48G_LE.xml";
                }
            }
            
            [userDefaults setObject:[skinfilename lastPathComponent] forKey:@"internalCurrentXmlFilename"];
            
            NSArray *pathComponents = [skinfilename pathComponents];
            NSRange aRange;
            aRange.location = 0;
            aRange.length = 2;
            [userDefaults setObject:[NSString pathWithComponents:[pathComponents objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:aRange]]] forKey:@"internalCurrentXmlDirectory"];
#endif
            
		case 5:
			// Wait for autoSetup to finish by polling
			if (_autoSetupInProgress == YES) {
				[self performSelector:@selector(startupEmulator:) withObject:nil afterDelay:0.5];
				return;
			}
			needsStartupScript = YES; // For startup script of skin
			[_startupPreview startAnimating];
			evolutionStage = 6;
			[self performSelectorInBackground:@selector(startupEmulator:) withObject:nil];
			return;
		case 6:
			//DEBUG NSLog(@"Stage 6")
			evolutionStage = 7; // Set next step
			// Running on Secondary Thread
			// Tasks:
			// - Check if emulator has to be set up and a document to be loaded
			// - Call myself on main thread again
			pool = [[NSAutoreleasePool alloc] init];

			
			if (autoLoadOnStartup == YES) {
				// Set up the emulator:
				NSString * tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentDocumentDirectory"];
				NSString * filename = getFullDocumentsPathForFile(tmpString);
				tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentDocumentFilename"];
				

				// Allocate new emulator core
				[_emulator stop];
				[_emulator release];
				_emulator = [[m48Emulator alloc] init];
				
				// Allocate new EAGL View
				CGRect rect = [[UIScreen mainScreen] applicationFrame];	
				[_emulatorView release];
				_emulatorView = [[m48EmulatorEAGLView alloc] initWithFrame:rect];
				
				// Allocate new Audio
				[_emulatorAudio release];
				_emulatorAudio = [[m48EmulatorAudioEngine alloc] init];
					
				// Now we try to create the document
				filename = [filename stringByAppendingPathComponent:tmpString];
				
				BOOL ok = NO;
				if (tmpString && ([tmpString length] > 0)) {
					ok = [_emulator loadDocument:filename error:&error];
				}
				
				if (!ok) {
						// Maybe there was an auto setup and we can try load with a new xml file
					tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentXmlDirectory"];
					if ((tmpString != nil) && ([tmpString length] > 0)) {
						filename = getFullDocumentsPathForFile(tmpString);
						tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentXmlFilename"];
						filename = [filename stringByAppendingPathComponent:tmpString];
						ok = [_emulator newDocumentWithXml:filename error:&error];
					}
				}
				
				if (!ok) {
					// clean up
					[_emulator stop];
					[_emulator release];
					_emulator = nil;
					
					[_emulatorView release];
					_emulatorView = nil;
					
					[_emulatorAudio release];
					_emulatorAudio = nil;
					
					[error retain]; // Otherwise it is released by the autorelease pool
				}
				else  if (![_emulatorView loadTextureImage:xml->currentOrientation->textureFilename error:&error]) {
					// Try to load the image file
					
					// clean up
					[_emulator stop];
					[_emulator release];
					_emulator = nil;
					
					[_emulatorView release];
					_emulatorView = nil;
					
					[_emulatorAudio release];
					_emulatorAudio = nil;
					
					[error retain]; // Otherwise it is released by the autorelease pool
				}
				else if (![_emulatorAudio loadSoundsFromXml:xml error:&error]) {
					// Try to load audio
					// clean up
					[_emulator stop];
					[_emulator release];
					_emulator = nil;
					
					[_emulatorView release];
					_emulatorView = nil;
					
					[_emulatorAudio release];
					_emulatorAudio = nil;
					
					[error retain]; // Otherwise it is released by the autorelease pool
				}
			}
			
			[pool release];
			pool = nil;
			[self performSelectorOnMainThread:@selector(startupEmulator:) withObject:nil waitUntilDone:NO];
			return;
		case 7:
			//DEBUG NSLog(@"Stage 7")
			evolutionStage = 8; // Set next step
			// Running on Main Thread
			// Tasks:
			// 1) Check if filesAutoloadOnStartup is set and go to menu if not
			// 2) Else, check if an error occured and display it
			// 3) Else, go to case 3 with success
			
			// 1)
			[_startupPreview stopAnimating];
			if ((autoLoadOnStartup == NO) || ((error == nil) && (_emulator == nil))) {
				[error release];
				error = nil;
				[self gotoMenu];
				goto resetMeAndReturn;
			}
			
			if (error != nil) {
				[myAlertView release];
				myAlertView = [[m48ModalAlertView alloc] initForError];
				myAlertView.target = self;
				myAlertView.selector = @selector(startupEmulator:);
				myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				return;
			}
			
		case 8:
			//DEBUG NSLog(@"Stage 8")
			evolutionStage = 0; // static -> reset
			// Running on Main Thread
			// Tasks:
			// 1) Goto menu if error-message is dismissed
			// 2) Transition to emulation view if everything went alright.
			
			// 1)
			if (error != nil) {
				[error release];
				error = nil;				
				[self performSelectorOnMainThread:@selector(gotoMenu) withObject:nil waitUntilDone:NO];
				goto resetMeAndReturn;
			}
			
			// 2)
			_emulatorOk = YES;
			
#ifdef VERSIONSTARTUPANIMATION
			// Load View
			// Draw a single frame and add it to the superview
			//[_startupPreview stopAnimating];
			[_emulatorView.layer setHidden:YES];
            //[self setView:_emulatorView];
			//[self.view.superview addSubview:_emulatorView];
			self.view = _emulatorView;
			
			[_emulatorView updateContrast];
			
			
			[_emulatorView layoutSubviews];;
			[_emulatorView drawView];
			
			CATransition *transition = [CATransition animation];
			transition.duration = 0.20;
			transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
			transition.type = kCATransitionFade;
			transition.delegate = self;
			[self.view.superview.layer addAnimation:transition forKey:kCATransition];
			
			// Exchange views
			[_emulatorView.layer setHidden:NO];
			[_startupPreview.layer setHidden:YES];
			
			/*
			 UIApplication * application = [UIApplication sharedApplication];
			 if (xml->currentOrientation->hasStatusBar) {
			 [application setStatusBarStyle:xml->currentOrientation->statusBarStyle animated:YES];
			 [application setStatusBarHidden:NO animated:YES];
			 }
			 else {
			 [application setStatusBarHidden:YES animated:YES];
			 }
			 */
#else
            [_emulatorView.layer setHidden:YES];
            //[self setView:_emulatorView];
            //[self.view.superview addSubview:_emulatorView];
            self.view = _emulatorView;
			
			[_emulatorView updateContrast];
			
			SetOrientation(self.interfaceOrientation);
			[_emulatorView layoutSubviews];
			[_emulatorView drawView];
			
			[_emulatorView.layer setHidden:NO];
			[_startupPreview.layer setHidden:YES];

			[_startupPreview removeFromSuperview];
			self.startupPreview = nil;
			[self start];
#endif
			
			// 
			if (needsStartupScript) {
                needsStartupScript = NO;
				// Do we have a startup-script?
				for (int i=0; i < xml->currentOrientation->nButtons; i++) {
					if (xml->currentOrientation->buttons[i].type == XmlButtonTypeInit) {
						[self queueActionOfButton:&(xml->currentOrientation->buttons[i])];
					}
				}
			}
			
			break;
		default:
			goto resetMeAndReturn;
			break;
	}
	
	userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:NO forKey:@"internalStartupInProgress"]; // Crash detection => finished without crash;
	[userDefaults synchronize];
	return;
	
resetMeAndReturn:
	userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:NO forKey:@"internalStartupInProgress"]; // Crash detection => finished without crash;
	[userDefaults synchronize];
	evolutionStage = 0;
	[myAlertView release];
	myAlertView = nil;
	needsStartupMaintenance = NO;	
	autoLoadOnStartup = NO;
	[error release];
	error = nil;
	return;
}
#ifdef VERSIONSTARTUPANIMATION
-(void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
	[self.view.superview.layer removeAllAnimations];
	[_startupPreview removeFromSuperview];
	self.startupPreview = nil;
	[self start];
}
#endif

-(void)autoSetup {
	static int evolutionStage = 0;
	static m48ModalAlertView * myAlertView = nil;
	static m48MenuFetch * romMenu = nil;
    NSString * romfilename = nil;
    NSString * skinfilename = nil;
    NSUserDefaults * userDefaults = nil;
    
	switch (evolutionStage) {
		case 0:
			evolutionStage = 1;
			_autoSetupInProgress = YES;
			myAlertView = [[m48ModalAlertView alloc] initBlank];
			myAlertView.target = self;
			myAlertView.selector = @selector(autoSetup);
			myAlertView.title = @"Auto Setup";
			myAlertView.message = @"Would you like me to auto setup a new calculator for you?";
			[myAlertView.buttonTexts addObject:@"No"];
			[myAlertView.buttonTexts addObject:@"Yes"];
			[myAlertView show];
			return;
		case 1:
			evolutionStage = 2;
			if (myAlertView.didDismissWithButtonIndex == 0) {
				goto reset;
			}
#ifdef VERSIONPLUS            
            myAlertView = [[m48ModalAlertView alloc] initBlank];
			myAlertView.target = self;
			myAlertView.selector = @selector(autoSetup);
			myAlertView.title = @"Choose model!";
			myAlertView.message = nil;
			[myAlertView.buttonTexts addObject:@"HP48SX"];
			[myAlertView.buttonTexts addObject:@"HP48GX"];
			[myAlertView.buttonTexts addObject:@"HP49G"];
			[myAlertView.buttonTexts addObject:@"HP49G+"];
			[myAlertView.buttonTexts addObject:@"Cancel"];
			[myAlertView show];
			return;
#endif
        case 2:
			evolutionStage = 3;
#ifdef VERSIONPLUS
			if ([[myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex] isEqual:@"Cancel"]) {
				goto reset;
			}
            self.autoSetupCalcType = [myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex];
            
            if (([[myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex] isEqual:@"HP48GX"]) || ([[myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex] isEqual:@"HP49G+"])) {
                myAlertView = [[m48ModalAlertView alloc] initBlank];
                myAlertView.target = self;
                myAlertView.selector = @selector(autoSetup);
                myAlertView.title = @"Auto Setup";
                myAlertView.message = @"Good choice! Do you prefer an original looking calculator or the m48 \"Steel\" Multiskin?";
                [myAlertView.buttonTexts addObject:@"Real"];
                [myAlertView.buttonTexts addObject:@"\"Steel\"-Multiskin"];
                [myAlertView.buttonTexts addObject:@"Cancel"];
                [myAlertView show];
                return;
            }
#else
			if ([[myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex] isEqual:@"Cancel"]) {
				goto reset;
			}
            myAlertView = [[m48ModalAlertView alloc] initBlank];
            myAlertView.target = self;
            myAlertView.selector = @selector(autoSetup);
            myAlertView.title = @"Auto Setup";
            myAlertView.message = @"Do you prefer an original looking calculator or the m48 \"Steel\" Multiskin?";
            [myAlertView.buttonTexts addObject:@"Real"];
            [myAlertView.buttonTexts addObject:@"\"Steel\"-Multiskin"];
            [myAlertView.buttonTexts addObject:@"Cancel"];
            [myAlertView show];
            return;   
#endif
            
        case 3:
			evolutionStage = 4;
			if ([[myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex] isEqual:@"Cancel"]) {
				goto reset;
			}
            self.autoSetupSkinType = [myAlertView.buttonTexts objectAtIndex:myAlertView.didDismissWithButtonIndex];
            myAlertView.didDismissWithButtonIndex = 0;
            
			// QUICK'N'DIRTY
#ifndef VERSIONPLUS
			NSURL * tempUrl = [NSURL URLWithString:@""];
			NSString * tempFilename = @"Information/m48_fetch.plist";
#else
			NSURL * tempUrl = [NSURL URLWithString:@""];
			NSString * tempFilename = @"Information/m48plus_fetch.plist";
#endif
            
#ifdef VERSIONPLUS
			NSDictionary * dict  = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"ROMs",@"elementTitleKey",
                                    @"http://<url>",@"elementFileURLKey",
                                    @"/",@"elementFileDestinationKey",
                                    [NSNumber numberWithInt:2800000],@"elementFileSizeKey", nil];
#else
			NSDictionary * dict  = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"HP 48GX Revision R",@"elementTitleKey",
                                    @"http://www.hpcalc.org/hp48/pc/emulators/gxrom-r.zip",@"elementFileURLKey",
                                    @"/ROMs/HP48G/rom.48g",@"elementFileDestinationKey",
                                    [NSNumber numberWithInt:330144],@"elementFileSizeKey", nil];
#endif
            
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:getFullDocumentsPathForFile(@"/ROMs/HP48G/rom.48g")]) {
				evolutionStage = 5;
				[self performSelectorOnMainThread:@selector(autoSetup) withObject:nil waitUntilDone:NO];
				return;
			}
			else {
				romMenu = [[m48MenuFetch alloc] initWithFilename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
				[romMenu FetchStartAction:dict];
			}
		case 4:
			// Wait for fetch to finish by polling
			if (romMenu.selectedDataElement != nil) {
				[self performSelector:@selector(autoSetup) withObject:nil afterDelay:0.5];
				return;
			}
			[romMenu release];
			romMenu = nil;
			evolutionStage = 5;
		case 5:
            userDefaults = [NSUserDefaults standardUserDefaults];
#ifdef VERSIONPLUS
            // Choose appropriate skin
            if ([_autoSetupCalcType isEqual:@"HP38G"] == YES) {
                romfilename = @"/ROMs/HP38G/rom.38g";
                skinfilename = @"Skins/HP38G/Emu48_Real38G_BigLCD_38g.xml";
            }
            else if ([_autoSetupCalcType isEqual:@"HP39G"] == YES) {
                romfilename = @"/ROMs/HP39G/rom.39g";
                skinfilename = @"Skins/HP39G/Emu48_Real39G_BigLCD_39g.xml";
            }
            else if ([_autoSetupCalcType isEqual:@"HP48SX"] == YES) {
                romfilename = @"/ROMs/HP48S/rom.48s";
                skinfilename = @"Skins/HP48S/Emu48_Real48SX_BigLCD_48s.xml";
            }
            else if ([_autoSetupCalcType isEqual:@"HP48GX"] == YES) {
                romfilename = @"/ROMs/HP48G/rom.48g";
                
                if ([_autoSetupSkinType isEqual:@"Real"] == YES) {
                    if ([userDefaults boolForKey:@"internalIsIPhone5"] == YES) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([userDefaults boolForKey:@"internalIsIPad"] == YES) {
                        if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                            skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                        }
                        else {
                            skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                        }
                    }
                    else {
                        if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                            skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                        }
                        else {
                            skinfilename = @"Skins/HP48G/Real48GX.xml";
                        }
                    }
                }
                else {
                    
                    NSString * model = [userDefaults objectForKey:@"device_model"];
                    if ([model isEqualToString:@""]) {
                            skinfilename = @"Skins/HP48G/Steel48G.xml";
                    }
                    else if ([model isEqualToString:@"@2x"]) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([model isEqualToString:@"-568h@2x"]) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([model isEqualToString:@"-667h@2x"]) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([model isEqualToString:@"-736h@3x"]) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([model isEqualToString:@"2x~iPad"]) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else if ([model isEqualToString:@"~iPad"]) {
                        skinfilename = @"Skins/HP48G/Real48GX.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }

                    
                }
            }
            else if ([_autoSetupCalcType isEqual:@"HP49G"] == YES) {
                romfilename = @"/ROMs/HP49G/rom.49g";
                skinfilename = @"Skins/HP49G/Emu48_Real49G_BigLCD_49g.xml";
            }
            else if ([_autoSetupCalcType isEqual:@"HP49G+"] == YES) {
                romfilename = @"/ROMs/HP49G+/rom.49g+";
                
                if ([_autoSetupSkinType isEqual:@"Real"] == YES) {
                    
                    
                    NSString * model = [userDefaults objectForKey:@"device_model"];
                    if ([model isEqualToString:@""]) {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                    else if ([model isEqualToString:@"@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                    else if ([model isEqualToString:@"-568h@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"-667h@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"-736h@3x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"2x~iPad"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"~iPad"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                    
                }
                else {
                    
                    
                    NSString * model = [userDefaults objectForKey:@"device_model"];
                    if ([model isEqualToString:@""]) {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                    else if ([model isEqualToString:@"@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                    else if ([model isEqualToString:@"-568h@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"-667h@2x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"-736h@3x"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"2x~iPad"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else if ([model isEqualToString:@"~iPad"]) {
                        skinfilename = @"Skins/HP49G+/Real49G+-568h_HD.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP49G+/Real49G+_HD.xml";
                    }
                }
            }
#else
            romfilename = @"/ROMs/HP48G/rom.48g";       
            
                
            if ([_autoSetupSkinType isEqual:@"Real"] == YES) {
                if ([userDefaults boolForKey:@"internalIsIPhone5"] == YES) {
                    skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                }
                else if ([userDefaults boolForKey:@"internalIsIPad"] == YES) {
                    if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD-iPad.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP48G/Real48GX-iPad.xml";
                    }
                }
                else {
                    if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                        skinfilename = @"Skins/HP48G/Real48GX_HD.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP48G/Real48GX.xml";
                    }
                }
            }
            else {
                if ([userDefaults boolForKey:@"internalIsIPhone5"] == YES) {
                    skinfilename = @"Skins/HP48G/Steel48G_LE-568h@2x.xml";
                }
                else if ([userDefaults boolForKey:@"internalIsIPad"] == YES) {
                    if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                        skinfilename = @"Skins/HP48G/Steel48G_LE@2x~iPad.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP48G/Steel48G_LE~iPad.xml";
                    }
                }
                else {
                    if ([userDefaults boolForKey:@"internalIsRetina"] == YES) {
                        skinfilename = @"Skins/HP48G/Steel48G_LE@2x.xml";
                    }
                    else {
                        skinfilename = @"Skins/HP48G/Steel48G_LE.xml";
                    }
                }
            }
            
            
#endif
            
            
			if ([[NSFileManager defaultManager] fileExistsAtPath:getFullDocumentsPathForFile(romfilename)]) {
				// Everything went alright
                [userDefaults setObject:[skinfilename lastPathComponent] forKey:@"internalCurrentXmlFilename"];
                
                NSArray *pathComponents = [skinfilename pathComponents];
                NSRange aRange;
                aRange.location = 0;
                aRange.length = 2;
				[userDefaults setObject:[NSString pathWithComponents:[pathComponents objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:aRange]]] forKey:@"internalCurrentXmlDirectory"];
			}
			break;
		default:
			break;
	}
	
reset:
	evolutionStage = 0;
	[myAlertView release];
	myAlertView = nil;
	_autoSetupInProgress = NO;
	return;
}


- (void)loadView {
	[self.navigationController setNavigationBarHidden:YES animated:NO];
	
	if ([self emulatorIsValid] == NO) {
		CGRect rect = [[UIScreen mainScreen] applicationFrame];	
		_startupPreview = [[m48EmulatorStartupPreview alloc] initWithFrame:rect];
		self.view = self.startupPreview;
	}	
}

- (void)viewWillAppear:(BOOL)animated {
	m48NavigationController * myNavigationController = (m48NavigationController *) self.navigationController;
	[myNavigationController setFixedOrientationIsValid:NO];
	
	[self.navigationController setNavigationBarHidden:YES animated:animated];
	[self.navigationController setToolbarHidden:YES animated:animated];
	
	SetOrientation(self.interfaceOrientation);

    [self.view layoutIfNeeded];
    [self.view setNeedsLayout];
    
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	// WICHTIG wegen OpenGL!!!
	[self.navigationController.navigationBar removeFromSuperview];
	[self.navigationController.toolbar removeFromSuperview];
	
	[super viewDidAppear:animated];
	
	if (!_emulatorOk) {
		// Try get cached info
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"internalIsIPad"] == NO) {
			NSString * test = [defaults stringForKey:@"internalCurrentDocumentFilename"];
			BOOL isOn;
			int type;
			if ((test != nil) && ([test length] > 0)) {
				isOn = [defaults boolForKey:@"internalCurrentXmlHasUIStatusBar"];
				type = [defaults integerForKey:@"internalCurrentXmlUIStatusBarStyle"];
			}
			else {
				isOn = YES;
				type = UIStatusBarStyleLightContent;
			}
			UIApplication * application = [UIApplication sharedApplication];
			if (isOn) {
				[application setStatusBarStyle:type animated:NO];
			}
			else {
				[application setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
			}
            [application setStatusBarHidden:!isOn withAnimation:UIStatusBarAnimationNone];
		}
	}
	
	if ([self emulatorIsValid] == NO) {
		[self startupEmulator:nil];
	}
	else {
		self.startupPreview = nil;
		[self start];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[self pause];
	if (_emulatorOk && !xml->currentOrientation->hasStatusBar) {
		UIApplication * application = [UIApplication sharedApplication];
		[application setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
        if (animated) {
            [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        }
        else {
            [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
        }
	}
	[super viewWillDisappear:animated];
}


- (void)applicationWillTerminate:(UIApplication *)application {
	BOOL saveOnExit = [[NSUserDefaults standardUserDefaults] boolForKey:@"filesAutosaveOnExit"];
	if ((saveOnExit == YES) && ([self emulatorIsValid] == YES)) {
		
		[self saveCurrentDocumentAction];		
		
	}
	else {
		NSString * tmpString = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentDocumentFilename"];
		if ((saveOnExit == NO) && ([tmpString isEqual:kUnsavedFileFilename] == YES)) {
			// Discard this unsaved file
			[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentXmlDirectory"];
			[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentXmlFilename"];
			[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentDocumentDirectory"];
			[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentDocumentFilename"];
		}
	}
	// [_emulator stop]; if m48Emulator gets dealloc it will stop itself. 
	
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"internalStartupInProgress"]; // Crash detection => cancel due to exit;
	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)didReceiveMemoryWarning {
	//DEBUG NSLog(@"m48EmulatorViewController didReceiveMemoryWarning");
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
    
    /*
    [self gotoMenu];
    
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Memory Warning!" message:@"The application received a memory warning. Most common cause is, that you tried to load a skin which is too complex for your device. You might want to try another skin."
                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
	[alert show];
    [alert release];
     */
}

- (void)dealloc {
	[_tapDict release];
	[_touchDict release];
	[_actionQueue release];
	if ((_actionQueueTimer != nil) && [_actionQueueTimer isValid]) {
		[_actionQueueTimer invalidate];
	}
	[_actionQueueTimer release];
    [_autoSetupCalcType release];
    [_autoSetupSkinType release];
	//[_screenshot release];
	[_emulator release];
	[_emulatorView release];
	[_startupPreview release];
    [super dealloc];
}


#pragma mark interface orientation control
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
#ifndef VERSIONPLUS
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
#else
	return IsAllowedOrientation(interfaceOrientation);
#endif
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
#ifndef VERSIONPLUS
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
#else
	return IsAllowedOrientation(interfaceOrientation);
#endif
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if ([self emulatorIsValid]) {
		[self pause];
		
		// Change current orientation type in xml
		SetOrientation(toInterfaceOrientation);
		[[NSUserDefaults standardUserDefaults] setInteger:toInterfaceOrientation forKey:@"internalCurrentXmlUIInterfaceOrientation"];

		
		UIApplication * application = [UIApplication sharedApplication];
		if (xml->currentOrientation->hasStatusBar) {
			[application setStatusBarStyle:xml->currentOrientation->statusBarStyle animated:YES];
			[application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
		}
		else {
			[application setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
		}	
	}
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	if ([self emulatorIsValid]) {
		[self start];
	}
}

#pragma mark files
-(BOOL)changeXmlSelectAction:(NSString *)filename {
	NSAutoreleasePool *  pool = nil;
	static m48ModalAlertView * myAlertView = nil;
	static NSError * error = nil;
	
	if ([self emulatorIsValid] == NO) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator not running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
		
	// Now we try to load something in Background
	
	// Startup code for modal view
	if (myAlertView == nil) { // Initialize
		myAlertView = [[m48ModalAlertView alloc] initWait];
	}	
	

	
	switch (myAlertView.evolutionStage) {
		case 0:
			[myAlertView show];
			myAlertView.evolutionStage = 1;
			// Call myself in background
			[self performSelectorInBackground:@selector(changeXmlSelectAction:) withObject:filename];
			break;
		case 1:
			// Now I am running in Background
			pool = [[NSAutoreleasePool alloc] init];
			if ([_emulator loadXmlDocument:filename error:&error]) {
				[_emulatorAudio loadSoundsFromXml:xml error:&error];
				_emulatorView.textureImage = nil;
			}
			myAlertView.evolutionStage = 2;
			[error retain];
			[self performSelectorOnMainThread:@selector(changeXmlSelectAction:) withObject:nil waitUntilDone:NO];
			[pool release];
			pool = nil;
			return YES; // doesnt matter
			break;
		case 2:
			[myAlertView dismissWithClickedButtonIndex:0 animated:YES];
			// Now we can have an error or success from step 1
			if (error != nil) {
				[myAlertView release];
				myAlertView = nil;
				myAlertView = [[m48ModalAlertView alloc] initForError];
				myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
				[error release];
				error = nil;
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				return NO;
			}
			
			// Loading has gone right
			[myAlertView release];
			myAlertView = nil;
			myAlertView = [[m48ModalAlertView alloc] initBlank];
			myAlertView.title = @"Success!";
			
			// Compile result message
			NSMutableString * tempString = [NSMutableString stringWithCapacity:0];
			[tempString appendString:@"\""];
			if (xml && xml->global) {
				[tempString appendString:xml->global->title];
			}
			[tempString appendString:@"\""];
			if (xml && xml->global && (xml->global->author != nil)) {
				[tempString appendString:@"\nby\n "];
				[tempString appendString:xml->global->author];
			}		
			if (xml && xml->global && (xml->global->copyright != nil)) {
				[tempString appendString:@"\n\n"];
				[tempString appendString:xml->global->copyright];
			}
			if (xml && xml->global && (xml->global->message != nil)) {
				[tempString appendString:@"\n\n"];
				[tempString appendString:xml->global->message];
			}	
			
			[myAlertView.buttonTexts addObject:@"OK"];
			myAlertView.message = tempString;
			[myAlertView show];
			[myAlertView release];
			myAlertView = nil;
			return YES;
			break;
		default:
			break;
	}

	return NO;
}

-(BOOL)changeXmlFilterAction:(NSString *)filename title:(NSString **)title {
	if ([[filename pathExtension] isEqual:@"xml"] == NO) {
		*title = nil;
		return NO;
	}
	return PeekXML(filename, title);
}
#ifdef VERSIONPLUS
-(BOOL)loadObjectSelectAction:(NSString *)filename {
	NSError * error = nil;
	

	m48ModalAlertView * myAlertView = nil;

	if (([self emulatorIsValid] == NO) || ([_emulator isRunning] == NO)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator not running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}

	
	if (![_emulator loadObject:filename error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	return YES;
}

-(BOOL)saveObjectAsSelectAction:(NSString *)filename {
	NSError * error = nil;
	
	m48ModalAlertView * myAlertView = nil;
	
	if (([self emulatorIsValid] == NO) || ([_emulator isRunning] == NO)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator not running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}

	if (![_emulator saveObject:filename error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}

	m48Filemanager * myFilemanager = (m48Filemanager *) [self.navigationController topViewController];
	[myFilemanager finishedSelectedFileActionWithSuccess:YES];
	return YES;	
}
#endif
-(BOOL)newDocumentSelectAction:(NSString *)filename {
	NSAutoreleasePool *  pool = nil;
	static m48ModalAlertView * myAlertView = nil;
	static NSError * error = nil;
	
	if ((myAlertView == nil) && ([self emulatorIsValid] == YES)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator is currently running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	// Now we try to load something in Background
	
	// Startup code for modal view
	if (myAlertView == nil) { // Initialize
		myAlertView = [[m48ModalAlertView alloc] initWait];
	}	
	
	switch (myAlertView.evolutionStage) {
		case 0:
			[myAlertView show];
			myAlertView.evolutionStage = 1;
			// Call myself in background
			[self performSelectorInBackground:@selector(newDocumentSelectAction:) withObject:filename];
			break;
		case 1:
			// Now I am running in Background
			pool = [[NSAutoreleasePool alloc] init];
			myAlertView.evolutionStage = 2;
			
			// Allocate new emulator core
			[_emulator stop];
			[_emulator release];
			_emulator = [[m48Emulator alloc] init];
			
			// Allocate new EAGL View
			CGRect rect = [[UIScreen mainScreen] applicationFrame];	
			[_emulatorView release];
			_emulatorView = [[m48EmulatorEAGLView alloc] initWithFrame:rect];
			self.view = _emulatorView;
			
			// Allocate new Audio
			[_emulatorAudio release];
			_emulatorAudio = [[m48EmulatorAudioEngine alloc] init];
			
			// Now we try to create the new document
			if (![_emulator newDocumentWithXml:filename error:&error]) {
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				self.view = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
				
				[error retain];
				[self performSelectorOnMainThread:@selector(newDocumentSelectAction:) withObject:nil waitUntilDone:NO];
				[pool release];
				pool = nil;
				return YES; // doesnt matter, just go back
			}
			
			// Try to load texture
			if (![_emulatorView loadTextureImage:xml->currentOrientation->textureFilename error:&error]) {
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				self.view = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
				
				[error retain];
				[self performSelectorOnMainThread:@selector(newDocumentSelectAction:) withObject:nil waitUntilDone:NO];
				[pool release];
				pool = nil;
				return YES; // doesnt matter, just go back
			}	
			
			// Try to load audio
			if (![_emulatorAudio loadSoundsFromXml:xml error:&error]) {
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				self.view = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
			}	
			
			// Delete the .unsaved_file
			NSFileManager * filemanager = [NSFileManager defaultManager];
			NSString * unsavedFile = getFullDocumentsPathForFile(kUnsavedFileFilename);
			if ([filemanager fileExistsAtPath:unsavedFile] == YES) {
				[filemanager removeItemAtPath:unsavedFile error:&error];
			}
			[error retain];
			[self performSelectorOnMainThread:@selector(newDocumentSelectAction:) withObject:nil waitUntilDone:NO];
			[pool release];
			pool = nil;
			return YES; // doesnt matter
			break;
		case 2:
			[myAlertView dismissWithClickedButtonIndex:0 animated:YES];
			// Now we can have an error or success from step 1
			if (error != nil) {
				[myAlertView release];
				myAlertView = nil;
				myAlertView = [[m48ModalAlertView alloc] initForError];
				myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				[error release];
				error = nil;
				return NO;
			}
			
			_emulatorOk = YES;
			
			// Loading has gone right
			[myAlertView release];
			myAlertView = nil;
			myAlertView = [[m48ModalAlertView alloc] initBlank];
			myAlertView.title = @"Success!";
			myAlertView.target = self;
			myAlertView.selector = @selector(newDocumentSelectAction:);
			myAlertView.evolutionStage = 2;
			// Compile result message
			NSMutableString * tempString = [NSMutableString stringWithCapacity:0];
			if (xml && xml->global) {
				[tempString appendString:@"\""];
				[tempString appendString:xml->global->title];
				[tempString appendString:@"\""];
			}
			if (xml && xml->global && (xml->global->author != nil)) {
				[tempString appendString:@"\nby\n "];
				[tempString appendString:xml->global->author];
			}		
			if (xml && xml->global && (xml->global->copyright != nil)) {
				[tempString appendString:@"\n\n"];
				[tempString appendString:xml->global->copyright];
			}
			if (xml && xml->global && (xml->global->message != nil)) {
				[tempString appendString:@"\n\n"];
				[tempString appendString:xml->global->message];
			}	
			
			[myAlertView.buttonTexts addObject:@"OK"];
			myAlertView.message = tempString;
			[myAlertView show];
			break;
		case 3:
			[myAlertView release];
			myAlertView = nil;
			[self.navigationController popViewControllerAnimated:YES];
			return YES;
			break;
		default:
			[myAlertView release];
			myAlertView = nil;
			break;
	}
	
	return NO;
}

-(BOOL)newDocumentXmlFilterAction:(NSString *)filename title:(NSString **)title {
	*title = nil;
	if ([[filename pathExtension] isEqual:@"xml"] == NO) {
		return NO;
	}
	PeekXML(filename, title);
	if (*title != nil) {
		return YES;
	}
	else {
		return NO;
	}
}

-(BOOL)openDocumentSelectAction:(NSString *)filename {
	NSAutoreleasePool *  pool = nil;
	static m48ModalAlertView * myAlertView = nil;
	static NSError * error = nil;
	
	if ((myAlertView == nil) && ([self emulatorIsValid] == YES)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator is currently running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	// Now we try to load something in Background
	
	// Startup code for modal view
	if (myAlertView == nil) { // Initialize
		myAlertView = [[m48ModalAlertView alloc] initWait];
	}	
	
	switch (myAlertView.evolutionStage) {
		case 0:
			[myAlertView show];
			myAlertView.evolutionStage = 1;
			// Call myself in background
			[self performSelectorInBackground:@selector(openDocumentSelectAction:) withObject:filename];
			break;
		case 1:
			// Now I am running in Background
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
			myAlertView.evolutionStage = 2;
			
			// Allocate new emulator core
			[_emulator stop];
			[_emulator release];
			_emulator = [[m48Emulator alloc] init];
			
			// Allocate new EAGL View
			CGRect rect = [[UIScreen mainScreen] applicationFrame];	
			[_emulatorView release];
			_emulatorView = [[m48EmulatorEAGLView alloc] initWithFrame:rect];
			self.view = _emulatorView;
			
			// Allocate new Audio
			[_emulatorAudio release];
			_emulatorAudio = [[m48EmulatorAudioEngine alloc] init];
			
			// Now we try to create the new document
			if (![_emulator loadDocument:filename error:&error]) {
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				self.view = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
				
				[error retain]; // Otherwise it is released by the autorelease pool
			}
			else if (![_emulatorView loadTextureImage:xml->currentOrientation->textureFilename error:&error]) {
				// Try to load the image file
				
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
				
				[error retain]; // Otherwise it is released by the autorelease pool
			}
			else if (![_emulatorAudio loadSoundsFromXml:xml error:&error]) {
				// Try to load audio
				// clean up
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				[_emulatorView release];
				_emulatorView = nil;
				
				[_emulatorAudio release];
				_emulatorAudio = nil;
				
				[error retain]; // Otherwise it is released by the autorelease pool
			}
			else {			
				// Delete the .unsaved_file
				NSFileManager * filemanager = [NSFileManager defaultManager];
				NSString * unsavedFile = getFullDocumentsPathForFile(kUnsavedFileFilename);
				if ([filemanager fileExistsAtPath:unsavedFile] == YES) {
					[filemanager removeItemAtPath:unsavedFile error:&error];
				}
			}
			
			[self performSelectorOnMainThread:@selector(openDocumentSelectAction:) withObject:nil waitUntilDone:NO];
			[pool release];
			pool = nil;
			return YES; // doesnt matter
			break;
		case 2:
			[myAlertView dismissWithClickedButtonIndex:0 animated:YES];
			// Now we can have an error or success from step 1
			if (error != nil) {
				[myAlertView release];
				myAlertView = nil;
				myAlertView = [[m48ModalAlertView alloc] initForError];
				myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
				[error release];
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				return NO;
			}
			
			_emulatorOk = YES;
			[myAlertView release];
			myAlertView = nil;
			[self.navigationController popViewControllerAnimated:YES];
			return YES;
			break;
		default:
			[myAlertView release];
			myAlertView = nil;
			break;
	}
	
	return NO;
}

-(BOOL)saveCurrentDocumentAction {
	NSError * error = nil;
	m48ModalAlertView * myAlertView = nil;
	
	if (([self emulatorIsValid] == NO) || ([_emulator isRunning] == NO)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator not running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	NSString * tmpString1;
	NSString * tmpString2;
	
	tmpString1 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
	tmpString2 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentFilename"];
	tmpString1 = [tmpString1 stringByAppendingPathComponent:tmpString2];
	tmpString1 = getFullDocumentsPathForFile(tmpString1);	
	
	if (![_emulator saveDocument:tmpString1 error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	// Cache file for faster startup next time
	if ([self emulatorIsValid]) {
        /*
		if (self.screenshot == nil) {
			self.screenshot = [_emulatorView makeScreenshot];
		}
		NSData * data = UIImagePNGRepresentation(_screenshot);
		[data writeToFile:getFullDocumentsPathForFile(@".cached_screenshot.png") options:0 error:&error];
         */
		// cache current orientation
		[[NSUserDefaults standardUserDefaults] setBool:xml->currentOrientation->hasStatusBar forKey:@"internalCurrentXmlHasUIStatusBar"];
		[[NSUserDefaults standardUserDefaults] setInteger:xml->currentOrientation->statusBarStyle forKey:@"internalCurrentXmlUIStatusBarStyle"];
		// Cache for next start, remeber that the xml-structure contains also dynamic data.
		WriteXmlCacheFile();
	}
	
	return YES;
}

-(BOOL)saveDocumentAsSelectAction:(NSString *)filename {
	NSError * error = nil;
	
	m48ModalAlertView * myAlertView = nil;
	
	if (([self emulatorIsValid] == NO) || ([_emulator isRunning] == NO)) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"Emulator not running.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	if (![_emulator saveDocument:filename error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	[self.navigationController popViewControllerAnimated:YES];
	//m48Filemanager * myFilemanager = (m48Filemanager *) [self.navigationController topViewController];
	//[myFilemanager finishedSelectedFileActionWithSuccess:YES];
	return YES;
}

-(BOOL)closeDocument {
	static m48ModalAlertView * myAlertView = nil;
	NSString * tempString;
	// Is a document even opened
	if ([self emulatorIsValid] == NO) {
		// Nothing to be done
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"No calculator to be closed";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return NO;
	}
	
	if (myAlertView == nil) {
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.title = @"Warning";
#ifdef VERSIONPLUS
		myAlertView.message = @"Do you really want to close this unsaved calculator?";
#else
		myAlertView.message = @"Do you really want to close this calculator? All data within the calculator will be lost!";
#endif
		[myAlertView.buttonTexts addObject:@"Cancel"];
		[myAlertView.buttonTexts addObject:@"Yes"];
		myAlertView.target = self;
		myAlertView.selector = @selector(closeDocument);
	}
	
	// Has the document been altered or saved?
	
		// Nothing to be done

	
	switch (myAlertView.evolutionStage) {
		case 0:
			tempString = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentFilename"];
			BOOL unsavedDocument = (tempString == nil) || ([tempString length] == 0);
			if ([tempString isEqual:kUnsavedFileFilename]) {
				unsavedDocument = YES;
			}
			if (unsavedDocument || (_emulator.contentChanged == YES)) {
				[myAlertView show];
				break;
			}
			else {
				myAlertView.didDismissWithButtonIndex = 1;
			}
		case 1:
			if (myAlertView.didDismissWithButtonIndex == 1) {
				// Exchange view to default view
				//[_emulatorView removeFromSuperview];
				self.view = _startupPreview;
				//[self.view.superview addSubview:_startupPreview];
				//self.view = _startupPreview;
				
				// Close EAGL view
				[_emulatorView release];
				_emulatorView = nil;
			
				// Close sound
				[_emulatorAudio release];
				_emulatorAudio = nil;

				// Close emulator
				[_emulator closeDocument];
				[_emulator stop];
				[_emulator release];
				_emulator = nil;
				
				_emulatorOk = NO;
				
				m48MenuMain * myMenu =  (m48MenuMain *) self.navigationController.topViewController;
				[myMenu reevaluateMenuAnimated:YES];
				//[myMenu setToolbarLabelText];
				
				// Clear caches
				//[[NSFileManager defaultManager] removeItemAtPath:getFullDocumentsPathForFile(@".cached_screenshot.png") error:NULL];
				DeleteXmlCacheFile();
				[[NSUserDefaults standardUserDefaults] setInteger:UIInterfaceOrientationPortrait forKey:@"currentXmlUIInterfaceOrientation"];
				
				
			}
			[myAlertView release];
			myAlertView = nil;
			break;
		default:
			break;
	}
	return YES;
	
}


#pragma mark emulator control
-(void)loadSettings {
	[_emulator loadSettings];
	[_emulatorView loadSettings];
	[_emulatorAudio loadSettings];
	
	PrepareAvailableOrientations();
	
}

#pragma mark pasteboard
#ifdef VERSIONPLUS
-(BOOL)copyFromStackToPasteboard:(NSError **)error {
	if (!_emulatorOk) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Emulator not running.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}	
	return OnStackCopy(error);
}

-(BOOL)pasteFromPasteboardToStack:(NSError **)error {
	if (!_emulatorOk) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Emulator not running.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}	
	return OnStackPaste(error);
}
#endif

-(BOOL)resetEmulator:(NSError **)error {
	if (!_emulatorOk) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Emulator not running.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	[_emulator reset];
	return YES;
}

/*
- (void)copyScreenshotActionFull {
	// Paste to clipboard:
	[[UIPasteboard generalPasteboard] setImage:_screenshot];
	//NSData *screenshotPNG = UIImagePNGRepresentation(screenshot);
	//[[UIPasteboard generalPasteboard] setData:screenshotPNG forPasteboardType:kUTTypePNG];
}

- (void)copyScreenshotActionOnlyLcd {
	CGImageRef resizedImage = CGImageCreateWithImageInRect([_screenshot CGImage], _lcdRect);
	UIImage * image = [UIImage imageWithCGImage:resizedImage]; 
	CFRelease(resizedImage);
	[[UIPasteboard generalPasteboard] setImage:image];
}

- (void)saveScreenshotAsSelectActionFull:(NSString *)filename {
	NSError * error = nil;
	
	m48ModalAlertView * myAlertView = nil;
	
	if (self.screenshot == nil) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"No screenshot to be saved.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return;
	}
	
	NSData * data = UIImagePNGRepresentation(_screenshot);
	if(![data writeToFile:filename options:0 error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		if (error != nil) {
			myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		}
		else {
			myAlertView.message = @"File could not be written.";
		}
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return;
	}
	
	m48Filemanager * myFilemanager = (m48Filemanager *) [self.navigationController topViewController];
	[myFilemanager finishedSelectedFileActionWithSuccess:YES];
	return;		
}
- (void)saveScreenshotAsSelectActionOnlyLcd:(NSString *)filename {
	NSError * error = nil;
	
	m48ModalAlertView * myAlertView = nil;
	
	if (self.screenshot == nil) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		myAlertView.message = @"No screenshot to be saved.";
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return;
	}
	
	CGImageRef resizedImage = CGImageCreateWithImageInRect([_screenshot CGImage], _lcdRect);
	UIImage * image = [UIImage imageWithCGImage:resizedImage];
	CFRelease(resizedImage);
	NSData * data = UIImagePNGRepresentation(image);
	if(![data writeToFile:filename options:0 error:&error]) {
		myAlertView = [[m48ModalAlertView alloc] initForError];
		if (error != nil) {
			myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
		}
		else {
			myAlertView.message = @"File could not be written.";
		}
		[myAlertView show];
		[myAlertView release];
		myAlertView = nil;
		return;
	}
	
	m48Filemanager * myFilemanager = (m48Filemanager *) [self.navigationController topViewController];
	[myFilemanager finishedSelectedFileActionWithSuccess:YES];
	return;
}
*/
	
#pragma emulator control
-(void)start {
	if (_emulatorOk) {
		[self loadSettings];
		SetOrientation(self.interfaceOrientation);
		[_emulator run];
		[_emulatorView startAnimation];
		//self.screenshot = nil;
	}
}

-(void)pause {
	if (_emulatorOk) {
		[_emulatorAudio panic];
		[_emulatorView stopAnimation];
		[_emulator pause];
		
		[self cancelAllActions];
	}		
}

-(void)stop {
	if (_emulatorOk) {
		[_emulatorView stopAnimation];
		[_emulator stop];		
	}
}

-(BOOL)emulatorIsValid {
	return _emulatorOk;
}

#pragma mark touch input routines
// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_emulatorOk) {
		return;
	}
	
	TouchDictData touchDictData;
	CGPoint pos;
	
	if ([touches count] > 0) {
        for (UITouch *touch in touches) {
			
			// Get current position
			pos = [touch locationInView:self.view];
			pos.x *= _screenScale;
			pos.y *= _screenScale;
			pos = [_emulatorView reverseZoomPoint:pos];
			//Debug
			//DEBUG multouchinput NSLog([NSString stringWithFormat:@"touchesBegan:touch=%X x=%f y=%f\n",touch,pos.x,pos.y,nil]);
            //printf("%f/%f", pos.x, pos.y);
			// Register this touch in the touchDict
			//NSNumber * num = [NSNumber numberWithInt:(int)touch];
            //printf("\n===========================\nTouch began touch=%d", [num intValue]);
			touchDictData.timer = [NSTimer scheduledTimerWithTimeInterval:SENSORMINHOLDTIME target:self selector:@selector(handleHoldTimer:) userInfo:touch repeats:NO];
			touchDictData.pos = pos;
			touchDictData.posIsValid = YES;
			touchDictData.lostFocus = NO;
			touchDictData.timerFired = NO;
			[_touchDict setTouchDictData:touchDictData forKey:touch];
			
			
			// Resolve what we found
			XmlButton * myButton;
			myButton = xml->currentOrientation->buttons;
			for(int i=0; i < xml->currentOrientation->nButtons; i++) {
				XmlSensorType * mySensorType;
				mySensorType = myButton->sensorTypes;
				for (int j=0; j < myButton->nSensorTypes; j++) {
					// Handle touch down
					if (*mySensorType == XmlSensorTypeTouchInside) {
						if(CGRectContainsPoint(myButton->toucharea,pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch on for buttonid= %d\n",myButton->nId,nil]);
							[self buttonDownEventWithButton:myButton];					
						}
					}
					else if (*mySensorType == XmlSensorTypeTouch) {
						if(CGRectContainsPoint(myButton->toucharea,pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch on for buttonid= %d\n",myButton->nId,nil]);
							[self buttonDownEventWithButton:myButton];					
						}
					}
					else if (*mySensorType == XmlSensorTypeTouchDown) {
						if(CGRectContainsPoint(myButton->toucharea,pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch on for buttonid= %d\n",myButton->nId,nil]);
							[self buttonTriggerEventWithButton:myButton];					
						}
					}
					// Trigger event touchDown!
					else if (*mySensorType == XmlSensorTypeTouchInsideDown) {
						if(CGRectContainsPoint(myButton->toucharea,pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDown for buttonid= %d\n",myButton->nId,nil]);
							[self buttonTriggerEventWithButton:myButton];					
						}
					}
					mySensorType++;
				}
				myButton++;
			}
        }
    }
}


// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{  
	if (!_emulatorOk) {
		return;
	}
	

	TouchDictData * pTouchDictData;
	CGPoint pos, prevPos;
	if ([touches count] > 0) {
        for (UITouch *touch in touches) {
			// Get current position
			pos = [touch locationInView:self.view];
			pos.x *= _screenScale;
			pos.y *= _screenScale;
			pos = [_emulatorView reverseZoomPoint:pos];
			// Get previous position
			prevPos = [touch previousLocationInView:self.view];
			prevPos.x *= _screenScale;
			prevPos.y *= _screenScale;
			prevPos = [_emulatorView reverseZoomPoint:prevPos];
			// Get initial data
			pTouchDictData = [_touchDict touchDictDataForKey:touch];
			
			//Debug
			//DEBUG multouchinput NSLog([NSString stringWithFormat:@"touchesMoved:touch=%X x=%f y=%f\n",touch,pos.x,pos.y,nil]);
			
			if (pTouchDictData != NULL) {
				// DEBUG
				//DEBUG multouchinput NSLog(@"->found touch in dict\n");
				
				// Check swipes
				CGPoint startPos = pTouchDictData->pos;
				BOOL foundSwipe = NO;
				BOOL foundFastSwipe = NO;
				XmlSensorType type, type2;
				if (pTouchDictData != NULL) {
					if (pTouchDictData->posIsValid) {
						// Detect swipes
						if (fabsf(pos.x - startPos.x) > SENSORMINSWIPEDIST) {
							foundSwipe = YES;
							if (fabsf(pos.y - startPos.y) < SENSORMAXSWIPEDEV) {
								// horizontal swipe detected
								if (pos.x > startPos.x) {
									type = XmlSensorTypeSwipeInsideRight;
								}
								else {
									type = XmlSensorTypeSwipeInsideLeft;
								}
							}
							else if (pos.y < startPos.y) {
								// horizontal swipe detected
								if (pos.x > startPos.x) {
									type = XmlSensorTypeSwipeInsideUpperRight;
								}
								else {
									type = XmlSensorTypeSwipeInsideUpperLeft;
								}
							}
							else {
								// horizontal swipe detected
								if (pos.x > startPos.x) {
									type = XmlSensorTypeSwipeInsideLowerRight;
								}
								else {
									type = XmlSensorTypeSwipeInsideLowerLeft;
								}
							}	
						}
						else if ((fabsf(pos.y - startPos.y) > SENSORMINSWIPEDIST) && 
							(fabsf(pos.x - startPos.x) < SENSORMAXSWIPEDEV)) {
							foundSwipe = YES;
							// vertical swipe detected
							if (pos.y < startPos.y) {
								type = XmlSensorTypeSwipeInsideUp;
							}
							else {
								type = XmlSensorTypeSwipeInsideDown;
							}
							
						}
						
						// Register data for the touch
						if (foundSwipe) {
							pTouchDictData->posIsValid = NO;
						
						
							// Is it maybe even a fast swipe?
							if (pTouchDictData->timerFired == NO) {
								// Invalidate so no other delayed methods would be called!=> WRONG!
								//[pTouchDictData->timer invalidate];
								//[pTouchDictData->timer release];
								//pTouchDictData->timer = nil;
								
								foundFastSwipe = YES;
								if (type == XmlSensorTypeSwipeInsideUp) {
									type2 = XmlSensorTypeSwipeInsideUpFast;
								}
								else if (type == XmlSensorTypeSwipeInsideDown) {
									type2 = XmlSensorTypeSwipeInsideDownFast;
								}
								else if (type == XmlSensorTypeSwipeInsideLeft) {
									type2 = XmlSensorTypeSwipeInsideLeftFast;
								}
								else if (type == XmlSensorTypeSwipeInsideRight) {
									type2 = XmlSensorTypeSwipeInsideRightFast;
								}
								else if (type == XmlSensorTypeSwipeInsideUpperLeft) {
									type2 = XmlSensorTypeSwipeInsideUpperLeftFast;
								}
								else if (type == XmlSensorTypeSwipeInsideUpperRight) {
									type2 = XmlSensorTypeSwipeInsideUpperRightFast;
								}
								else if (type == XmlSensorTypeSwipeInsideLowerRight) {
									type2 = XmlSensorTypeSwipeInsideLowerRightFast;
								}
								else if (type == XmlSensorTypeSwipeInsideLowerLeft) {
									type2 = XmlSensorTypeSwipeInsideLowerLeftFast;
								}

							}
						}
					}
				}
							
							
				// Resolve what we have found onto the buttons
				XmlButton * myButton;	
				myButton = xml->currentOrientation->buttons;
				for(int i=0; i < xml->currentOrientation->nButtons; i++) {
					XmlSensorType * mySensorType;
					mySensorType = myButton->sensorTypes;
					for (int j=0; j < myButton->nSensorTypes; j++) {
						if (*mySensorType == XmlSensorTypeTouch) {
							if (!CGRectContainsPoint(myButton->toucharea,pos)
								&& CGRectContainsPoint(myButton->toucharea,prevPos)) {
								// Debug
								//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
								[self buttonUpEventWithButton:myButton];
							}
							else if (CGRectContainsPoint(myButton->toucharea,pos)
									 && !CGRectContainsPoint(myButton->toucharea,prevPos)) {
								// Debug
								//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
								[self buttonDownEventWithButton:myButton];
							}
						}
						else if (*mySensorType == XmlSensorTypeTouchDown) {
							if (CGRectContainsPoint(myButton->toucharea,pos)
								&& !CGRectContainsPoint(myButton->toucharea,prevPos)) {
								// Debug
								//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
								[self buttonTriggerEventWithButton:myButton];
							}
						}
						else if (CGRectContainsPoint(myButton->toucharea, startPos)) {
							if (*mySensorType == XmlSensorTypeTouchInside) {
								// In case we move off a button of sensortype touch
								if (!CGRectContainsPoint(myButton->toucharea,pos)
									&& CGRectContainsPoint(myButton->toucharea,prevPos)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
									[self buttonUpEventWithButton:myButton];
								}
							}
							else if ((*mySensorType == XmlSensorTypeTouchInsideDelayed) &&
									 (pTouchDictData->timerFired)) {
										 // In case we move off a button of sensortype touch
										 if (!CGRectContainsPoint(myButton->toucharea,pos)
											 && CGRectContainsPoint(myButton->toucharea,prevPos)) {
											 // Debug
											 //DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed (off) for buttonid= %d\n",myButton->nId,nil]);
											 [self buttonUpEventWithButton:myButton];
										 }
									 }
							else if ((*mySensorType == XmlSensorTypeTouchInsideDelayedFocused) &&
									 (pTouchDictData->timerFired)) {
								// In case we move off a button of sensortype touch
								if (!CGRectContainsPoint(myButton->toucharea,pos)
									&& CGRectContainsPoint(myButton->toucharea,prevPos)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed (off) for buttonid= %d\n",myButton->nId,nil]);
									[self buttonUpEventWithButton:myButton];
								}
							}
							else if (foundSwipe) {
								if (*mySensorType == type) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->swipe for buttonid= %d\n",myButton->nId,nil]);
									[self buttonTriggerEventWithButton:myButton];
								}
								else if (foundFastSwipe && (*mySensorType == type2)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->swipeFast for buttonid= %d\n",myButton->nId,nil]);
									[self buttonTriggerEventWithButton:myButton];
								}
							}
						}
						mySensorType++;
					}
					myButton++;
				}
					
							
				// Check if we moved outside focus area for the focused sensortypes
				if ((fabsf(pos.x - startPos.x) > SENSORMINSWIPEDIST) ||
					(fabsf(pos.y - startPos.y) > SENSORMINSWIPEDIST)) {
					// Moved outside the area, for which hold is allowed -> cancel
					pTouchDictData->lostFocus = YES;
					//DEBUG multouchinput NSLog(@"Lost focus");
				}	
			}
        }
    }	
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!_emulatorOk) {
		return;
	}

	
	TouchDictData * pTouchDictData;
	CGPoint pos, prevPos;
	if ([touches count] > 0) {
        for (UITouch *touch in touches) {
			// Get current position
			pos = [touch locationInView:self.view];
			pos.x *= _screenScale;
			pos.y *= _screenScale;
			pos = [_emulatorView reverseZoomPoint:pos];
			//Debug
			//DEBUG multouchinput NSLog([NSString stringWithFormat:@"touchesEnded:touch=%X x=%f y=%f\n",touch,pos.x,pos.y,nil]);
			
			// Get previous position
			prevPos = [touch previousLocationInView:self.view];
			prevPos.x *= _screenScale;
			prevPos.y *= _screenScale;
			prevPos = [_emulatorView reverseZoomPoint:prevPos];
			// Get initial data
			pTouchDictData = [_touchDict touchDictDataForKey:touch];
			
			if (pTouchDictData != NULL) {
				// DEBUG
				//DEBUG multouchinput NSLog(@"->found touch in dict\n");
				
				// Check swipes
				CGPoint startPos = pTouchDictData->pos;
			
				/*
				// Check if we moved outside focus area for the focused sensortypes
				if ((fabsf(pos.x - startPos.x) > SENSORMAXSWIPEDEV) ||
					(fabsf(pos.y - startPos.y) > SENSORMAXSWIPEDEV)) {
					// Moved outside the area, for which hold is allowed -> cancel
					pTouchDictData->lostFocus = YES;
					//DEBUG multouchinput NSLog(@"Lost focus");
				}
				 */
				
				// Resolve onto buttons
				XmlButton * myButton = xml->currentOrientation->buttons;
				for(int i=0; i < xml->currentOrientation->nButtons; i++) {
					XmlSensorType * mySensorType;
					mySensorType = myButton->sensorTypes;
					for (int j=0; j < myButton->nSensorTypes; j++) {
						if (*mySensorType == XmlSensorTypeTouch) {
							if (CGRectContainsPoint(myButton->toucharea,pos) || CGRectContainsPoint(myButton->toucharea,prevPos)) {
								// Debug
								//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
								[self buttonUpEventWithButton:myButton];
							}
						}
						if (*mySensorType == XmlSensorTypeTouchUp) {
							if (CGRectContainsPoint(myButton->toucharea,pos) || CGRectContainsPoint(myButton->toucharea,prevPos)) {
								// Debug
								//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off  for buttonid= %d\n",myButton->nId,nil]);
								[self buttonTriggerEventWithButton:myButton];
							}
						}
						else if (CGRectContainsPoint(myButton->toucharea, startPos)) {
							if (*mySensorType == XmlSensorTypeTouchInside) {
								if (CGRectContainsPoint(myButton->toucharea,pos) || CGRectContainsPoint(myButton->toucharea,prevPos)) {
										// Debug
										//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touch off for buttonid= %d\n",myButton->nId,nil]);
										[self buttonUpEventWithButton:myButton];
								}
									
							}
							else if ((*mySensorType == XmlSensorTypeTouchInsideDelayed) &&
									 (pTouchDictData->timerFired)){
								if (CGRectContainsPoint(myButton->toucharea,pos) || CGRectContainsPoint(myButton->toucharea,prevPos)) {
											 // Debug
											 //DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed off for buttonid= %d\n",myButton->nId,nil]);
											 [self buttonUpEventWithButton:myButton];
										 }
							}
							else if ((*mySensorType == XmlSensorTypeTouchInsideDelayedFocused) &&
									 (pTouchDictData->timerFired)){
								if (CGRectContainsPoint(myButton->toucharea,pos) || CGRectContainsPoint(myButton->toucharea,prevPos)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed off for buttonid= %d\n",myButton->nId,nil]);
									[self buttonUpEventWithButton:myButton];
								}
							}
									
							// Triggers
							else if (*mySensorType == XmlSensorTypeTouchInsideUp) {
								if(CGRectContainsPoint(myButton->toucharea,pos)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchUp for buttonid= %d\n",myButton->nId,nil]);
									[self buttonTriggerEventWithButton:myButton];					
								}
							}
							else if (*mySensorType == XmlSensorTypeTouchInsideUpFast) {
								if(CGRectContainsPoint(myButton->toucharea,pos) &&
								   (pTouchDictData->timerFired == NO)) {
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchUpFast for buttonid= %d\n",myButton->nId,nil]);
									[self buttonTriggerEventWithButton:myButton];
								}
							}
							else if (*mySensorType == XmlSensorTypeTouchInsideUpFocused) {
							   if(CGRectContainsPoint(myButton->toucharea,pos) &&
								  (pTouchDictData->lostFocus == NO)) {
										// Debug
										//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchUpFocused for buttonid= %d\n",myButton->nId,nil]);
									  [self buttonTriggerEventWithButton:myButton];
								  }
							}
							else if (*mySensorType == XmlSensorTypeTouchInsideUpFastFocused) {
								if(CGRectContainsPoint(myButton->toucharea,pos) &&
								   (pTouchDictData->lostFocus == NO) &&
								   (pTouchDictData->timerFired == NO)){
									// Debug
									//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchUpFastFocused for buttonid= %d\n",myButton->nId,nil]);
									[self buttonTriggerEventWithButton:myButton];
								}
							}
							else if (*mySensorType == XmlSensorTypeTap) {
                                if(CGRectContainsPoint(myButton->toucharea,pos)) {
                                    NSNumber * buttonID = [NSNumber numberWithInt:(int) myButton];
									if (touch.tapCount == 1) {
										// Potential tap candidate! -> Register tap timer and this button
										TouchDictData data;
										data.pos = pos;
										data.posIsValid = YES;
										data.timerFired = NO;
                                        data.lostFocus = NO;
                                        //printf("\n\n==>Set buttonID = %d\n", (id)myButton);
										data.timer = [NSTimer scheduledTimerWithTimeInterval:SENSORDOUBLETAPTIME target:self selector:@selector(handleSingleTap:) userInfo:buttonID repeats:NO];
										[_tapDict setTouchDictData:data forKey:(id)[buttonID intValue]];
										// Debug
										//DEBUG multouchinput NSLog(@"->sensorTap arm");
									}
									else {
										// Here the timer could be cancelled, was original done in touchesBegan...
                                        // but since some iOS change not the same touch is returned, and hence cannot be a key.
                                        // we better use the button as key
                                        //printf("\ntapCount = %d\n", touch.tapCount);
                                        //printf("touch %u\n", touch);
                                        
                                        //printf("Cancel buttonID = %d", (id)myButton);
                                        [_tapDict clearKey:(id)[buttonID intValue]];
                                        //printf("=========\n");
                                       
									}
								}
							}
							else if (*mySensorType == XmlSensorTypeDoubleTap) {
								if(CGRectContainsPoint(myButton->toucharea,pos)) {
									if (touch.tapCount == 2) {
										// Debug
										//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->doubleTap for buttonid= %d\n",myButton->nId,nil]);
										[self buttonTriggerEventWithButton:myButton];
									}
								}
							}
						}
						mySensorType++;
					}
					myButton++;
				}
				
				// Clear the touch from touch dict
				[_touchDict clearKey:touch];
			}
        }
    }
}

// Handles the end of a touch event.
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!_emulatorOk) {
		return;
	}

	TouchDictData * pTouchDictData;
	if ([touches count] > 0) {
        for (UITouch *touch in touches) {
			pTouchDictData = [_touchDict touchDictDataForKey:touch];
			if (pTouchDictData != NULL) {
				CGPoint startPos = pTouchDictData->pos;
			
				XmlButton * myButton;
				myButton = xml->currentOrientation->buttons;
				for(int i=0; i < xml->currentOrientation->nButtons; i++) {
					XmlSensorType * mySensorType;
					mySensorType = myButton->sensorTypes;
					for (int j=0; j < myButton->nSensorTypes; j++) {
						// For anything to happen the startPos must have been inside the button
						if (CGRectContainsPoint(myButton->toucharea, startPos)) {
							if (*mySensorType == XmlSensorTypeTouchInside) {
								[self buttonUpEventWithButton:myButton];
							}
							else if ((*mySensorType == XmlSensorTypeTouchInsideDelayed) &&
									 (pTouchDictData->timerFired)) {
										 [self buttonUpEventWithButton:myButton];
									 }
							mySensorType++;
						}
					}
					myButton++;
				}
			}
			[_touchDict clearKey:touch];
			[_tapDict clearKey:touch];
		}
	}
}


-(void)handleHoldTimer:(NSTimer*)timer {
	if (!_emulatorOk) {
		return;
	}
	
	TouchDictData * pTouchDictData;
	UITouch * touch = (UITouch *) [timer userInfo];
	
	// Get current position
	CGPoint pos = [touch locationInView:self.view];
	pos.x *= _screenScale;
	pos.y *= _screenScale;
	pos = [_emulatorView reverseZoomPoint:pos];
	
	// Get initial data
	pTouchDictData = [_touchDict touchDictDataForKey:touch];
	
	if (pTouchDictData != NULL) {
		// Remove timer (was already invalidated, since it fired
		[pTouchDictData->timer release];
		pTouchDictData->timer = nil;
		pTouchDictData->timerFired = YES;
		
		// Check swipes
		CGPoint startPos = pTouchDictData->pos;	

		XmlButton * myButton;
		myButton = xml->currentOrientation->buttons;
		for(int i=0; i < xml->currentOrientation->nButtons; i++) {
			XmlSensorType * mySensorType;
			mySensorType = myButton->sensorTypes;
			for (int j=0; j < myButton->nSensorTypes; j++) {
				if (CGRectContainsPoint(myButton->toucharea, startPos)) {
					if (*mySensorType == XmlSensorTypeTouchInsideDelayed) {
						if (CGRectContainsPoint(myButton->toucharea, pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed on for buttonid= %d\n",myButton->nId,nil]);
							[self buttonDownEventWithButton:myButton];
						}
					}
					else if (*mySensorType == XmlSensorTypeTouchInsideDelayedFocused) {
						if ((CGRectContainsPoint(myButton->toucharea, pos)) &&
							(pTouchDictData->lostFocus == NO)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDelayed on for buttonid= %d\n",myButton->nId,nil]);
							[self buttonDownEventWithButton:myButton];
						}
					}
					else if (*mySensorType == XmlSensorTypeTouchInsideDownDelayed) {
						if (CGRectContainsPoint(myButton->toucharea, pos)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDownDelayed for buttonid= %d\n",myButton->nId,nil]);
							[self buttonTriggerEventWithButton:myButton];
						}
					}
					else if (*mySensorType == XmlSensorTypeTouchInsideDownDelayedFocused) {
						if ((CGRectContainsPoint(myButton->toucharea, pos)) &&
							(pTouchDictData->lostFocus == NO)) {
							// Debug
							//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->touchDownDelayedFocus for buttonid= %d\n",myButton->nId,nil]);
							[self buttonTriggerEventWithButton:myButton];
						}
					}
				}
				mySensorType++;
			}
			myButton++;
		}
	}
}


-(void)handleSingleTap:(NSTimer*)timer {
	if (!_emulatorOk) {
		return;
	}
	NSNumber * buttonID = (NSNumber *) [timer userInfo];
	
	TouchDictData * pTouchDictData = [_tapDict touchDictDataForKey:(id)[buttonID intValue]];
	if (pTouchDictData == NULL) {
		return;
	}
	CGPoint pos = pTouchDictData->pos;
	[_tapDict clearKey:(id)[buttonID intValue]];
    //printf("Timer fired (%d) id=%d!\n", [buttonID intValue], (unsigned int) timer);
	
	// All we know is, that there was a touch once, which fitted one of the buttons of sensortype tap
	XmlButton * myButton;
	myButton = xml->currentOrientation->buttons;
	for(int i=0; i < xml->currentOrientation->nButtons; i++) {
		XmlSensorType * mySensorType;
		mySensorType = myButton->sensorTypes;
		for (int j=0; j < myButton->nSensorTypes; j++) {
			if (*mySensorType == XmlSensorTypeTap) {
				if (CGRectContainsPoint(myButton->toucharea, pos)) {
					// Debug
					//DEBUG multouchinput NSLog([NSString stringWithFormat:@"->tap for buttonid= %d\n",myButton->nId,nil]);
					[self buttonTriggerEventWithButton:myButton];
				}
			}
			mySensorType++;
		}
		myButton++;
	}
}


-(void)buttonDownEventWithButton:(XmlButton * )button {
	XmlLogic * myLogic;
	BOOL needToBeConsidered;
	//DEBUG multouchinput NSLog([NSString stringWithFormat:@"-->buttonDownEventWithButtonID=%d\n",button->nId,nil]);
	
	// Check LOGIC if button needs to be considered
	if (button->nLogics) {
		needToBeConsidered = NO;
		myLogic = button->logics;
		for (int j = 0; j < button->nLogics; j++) {
			if (  myLogic->logicVec == ((xml->logicStateVec) &  ~myLogic->dontCareVec) ) {
				needToBeConsidered = YES;
				break;
			}
			myLogic = myLogic + 1;
		}
	}
	else {
		needToBeConsidered = YES;
	}
	
	if (needToBeConsidered) {
		//Debug
		//DEBUG multouchinput NSLog(@"--->passed logictest\n");
		// Wake up m48GraphicsEngine
		contentChanged = YES;
		
		// Check if the mode is normal or toggle
		if (button->mode == XmlButtonModeNormal) {
			button->bDown = YES;
		}
		else {
			button->bDown = !(button->bDown);
		}
		
		// Process Animation and Audio
		if (button->bDown) {
			if ((button->onDrawable) && (button->onDrawable->animationControl)) {
				resetAnimation(button->onDrawable->animationControl, NO, YES);
			}
			if ((button->offDrawable) && (button->offDrawable->animationControl)) {
				resetAnimation(button->offDrawable->animationControl, YES, YES);
			}
			if (button->soundfx) {
				[_emulatorAudio playXmlSoundFX:button->soundfx buttonDown:button->bDown];
			}
		}
		else {
			if (button->soundfx) {
				[_emulatorAudio playXmlSoundFX:button->soundfx buttonDown:button->bDown];
			}	
		}
		
		// Process logic-linking!
		if (button->logicId != 0) {
			if (button->bDown) {
				xml->logicStateVec |= (0x1 << (button->logicId + 15));
			}
			else {
				xml->logicStateVec &= ~(0x1 << (button->logicId + 15));
			}
		}
									   
		
		// Perform necessary action
		if (button->type == XmlButtonTypeNormal) {
			//KeyboardEvent(button->bDown, button->nOut, button->nIn);	
			[_emulator queueKeyboardEventOut:button->nOut In:button->nIn Predicate:button->bDown];
		}
		else if (button->type == XmlButtonTypeMenu) {
			[self gotoMenu];
		}
#ifdef VERSIONPLUS
		else if (button->type == XmlButtonTypeCopy) {
			[self copyFromStackToPasteboardSkinMethod];
		}
		else if (button->type == XmlButtonTypePaste) {
			[self pasteFromPasteboardToStackSkinMethod];
		}
#endif
		
		if (button->nActions > 0) {
			// Some action has to be performed
			[self queueActionOfButton:button];
					
		}
		
	}
	return; 
}	

-(void)buttonUpEventWithButton:(XmlButton * )button {
	XmlLogic * myLogic;
	BOOL needToBeConsidered;
	//DEBUG multouchinput NSLog([NSString stringWithFormat:@"-->buttonUpEventWithButtonID=%d\n",button->nId,nil]);
	// Check LOGIC if button needs to be considered
	if (button->nLogics) {
		needToBeConsidered = NO;
		myLogic = button->logics;
		for (int j = 0; j < button->nLogics; j++) {
			if (  myLogic->logicVec == ((xml->logicStateVec) &  ~myLogic->dontCareVec) ) {
				needToBeConsidered = YES;
				break;
			}
			myLogic = myLogic + 1;
		}
	}
	else {
		needToBeConsidered = YES;
	}
	
	// Special case: !XmlButtonTypeVirtual shall be released even if logic determines no visibility
	needToBeConsidered |= ((button->type != XmlButtonTypeVirtual) && (button->bDown));
	
	
	if (needToBeConsidered) { 
		//Debug
		//DEBUG multouchinput NSLog(@"--->passed logictest\n");
		
		// WakeUp m48GraphicsEngine
		contentChanged = YES;
		
		// Check if the mode is normal or toggle
		if (button->mode == XmlButtonModeNormal) {
			button->bDown = NO;
		}
		else {
			return;
		}
		
		// Process Animation and Audio
		if (button->soundfx) {
			[_emulatorAudio playXmlSoundFX:button->soundfx buttonDown:button->bDown];
		}
		
		// Process logic-linking!
		if (button->logicId != 0) {
			if (button->bDown) {
				xml->logicStateVec |= (0x1 << (button->logicId + 15));
			}
			else {
				xml->logicStateVec &= ~(0x1 << (button->logicId + 15));
			}
		}
		
		// Perform necessary action
		if (button->type == XmlButtonTypeNormal) {
			//KeyboardEvent(button->bDown, button->nOut, button->nIn);
			[_emulator queueKeyboardEventOut:button->nOut In:button->nIn Predicate:button->bDown];
		}	
		
	}
	return;
}

-(void)buttonTriggerEventWithButton:(XmlButton *)button {
	[self buttonDownEventWithButton:button];
	//[NSThread sleepForTimeInterval:0.1]; bringt nix
	[self buttonUpEventWithButton:button];
}

-(void)buttonCancelEventWithButton:(XmlButton *)button {
	;
}

-(void)queueActionOfButton:(XmlButton *)button {
	if (xml == NULL) {
		return;
	}
	if (xml->currentOrientation == NULL) {
		return;
	}
	
	// Find the button position
	int i;
	XmlButton * myButton = xml->currentOrientation->buttons;
	for (i = 0; i < xml->currentOrientation->nButtons; i++) {
		if (myButton == button) {
			break;
		}
		myButton++;
	}
	if (i >= xml->currentOrientation->nButtons) {
		return;
	}
	[_actionQueue addObject:[NSNumber numberWithInt:i]];
	if ([_actionQueue count] == 1) {
		_currentSubStep = 0;
		[self execActionQueue:nil];
	}
}


-(void)execActionQueue:(NSTimer *)timer {
	// Invalidate timer
	if ((_actionQueueTimer != nil) && [_actionQueueTimer isValid]) {
		[_actionQueueTimer invalidate];
		self.actionQueueTimer = nil;
	}
	if ([_actionQueue count] == 0) {
		self.actionQueue = [NSMutableArray arrayWithCapacity:0];
		return;
	}
	if (xml == NULL) {
		return;
	}
	if (xml->currentOrientation == NULL) {
		return;
	}
	NSNumber * num = [_actionQueue objectAtIndex:0];
	int i = [num intValue];
	if (i >= xml->currentOrientation->nButtons) {
		//Something has gone wrong
		[self cancelAllActions];
		return;
	}
	
	XmlButton * myButton = xml->currentOrientation->buttons + i;
	
	if (_currentSubStep >= myButton->nActions) {
		//Something has gone wrong
		[self cancelAllActions];
		return;
	}
	XmlAction * myAction = myButton->actions + _currentSubStep;
	
	// Go to next step
	_currentSubStep++;
	if (_currentSubStep >= myButton->nActions) {
		_currentSubStep = 0;
		[_actionQueue removeObjectAtIndex:0];
	}
		
	
	// Now lets find the appropriate button id
	myButton = xml->currentOrientation->buttons;
	for (i = 0; i < xml->currentOrientation->nButtons; i++) {
		if (myButton->nId == myAction->buttonId) {
			break;
		}
		myButton++;
	}
	if ((myAction->buttonId > 0) && (i < xml->currentOrientation->nButtons)) {
		
	
		if (myAction->triggerMode == XmlActionTriggerModeTrigger) {
			[self buttonDownEventWithButton:myButton];
			[self buttonUpEventWithButton:myButton];
		}
		else if (myAction->triggerMode == XmlActionTriggerModeOn) {
			// Only if off
			if (myButton->bDown == FALSE) {
				XmlButtonMode mode = myButton->mode;
				myButton->mode = XmlButtonModeNormal; // Also toggle buttons shall be turned on
				[self buttonDownEventWithButton:myButton];
				myButton->mode = mode;
			}
		}
		else if (myAction->triggerMode == XmlActionTriggerModeOff) {
			// Only if on
			if (myButton->bDown == TRUE) {
				XmlButtonMode mode = myButton->mode;
				myButton->mode = XmlButtonModeNormal; // Also toggle buttons shall be turned off
				[self buttonUpEventWithButton:myButton];
				myButton->mode = mode;
			}
		}
		else if (myAction->triggerMode == XmlActionTriggerModeToggle) {
			if (myButton->mode == XmlButtonModeNormal) {
				if (myButton->bDown) {
					[self buttonUpEventWithButton:myButton];
				}
				else {
					[self buttonDownEventWithButton:myButton];
				}
			}
			else {
				[self buttonDownEventWithButton:myButton];
			}
		}
	}

	// Schedule timer
	if (myAction->delay > 0) {
		self.actionQueueTimer = [NSTimer scheduledTimerWithTimeInterval:myAction->delay  target:self selector:@selector(execActionQueue:) userInfo:nil repeats:NO];
	}
	else {
		[self performSelectorOnMainThread:@selector(execActionQueue:) withObject:nil waitUntilDone:NO];
	}
}

-(void)cancelAllActions {
	if ((_actionQueueTimer != nil) && [_actionQueueTimer isValid]) {
		[_actionQueueTimer invalidate];
	}
	self.actionQueueTimer = nil;
	self.actionQueue = [NSMutableArray arrayWithCapacity:0];
}

#pragma mark copy/paste for skin
#ifdef VERSIONPLUS
-(void)copyFromStackToPasteboardSkinMethod {
	static int stage = 0;
	NSError * error = nil;
	static BOOL ok = NO;
	if (stage == 0) {
		stage++;
		ok = OnStackCopy(&error);
		[_emulator run];
		if (ok) {
			xml->logicStateVec |= LACKNOK;
			xml->logicStateVec &= ~LACKNERR;
		}
		else {
			xml->logicStateVec |= LACKNERR;
			xml->logicStateVec &= ~LACKNOK;
		}
		[self performSelector:@selector(copyFromStackToPasteboardSkinMethod) withObject:nil afterDelay:0.5];
	}
	else if (stage == 1) {
		stage++;
		if (ok) {
			xml->logicStateVec &= ~LACKNOK;
		}
		else {
			xml->logicStateVec &= ~LACKNERR;
		}
	}
	if (stage == 2) {
		// Reset
		stage = 0;
	}
}

-(void)pasteFromPasteboardToStackSkinMethod {
	static int stage = 0;
	NSError * error = nil;
	static BOOL ok = NO;
	if (stage == 0) {
		stage++;
		ok = OnStackPaste(&error);
		[_emulator run];
		if (ok) {
			xml->logicStateVec |= LACKNOK;
			xml->logicStateVec &= ~LACKNERR;
		}
		else {
			xml->logicStateVec |= LACKNERR;
			xml->logicStateVec &= ~LACKNOK;
		}
		[self performSelector:@selector(pasteFromPasteboardToStackSkinMethod) withObject:nil afterDelay:0.5];
	}
	else if (stage == 1) {
		stage++;
		if (ok) {
			xml->logicStateVec &= ~LACKNOK;
		}
		else {
			xml->logicStateVec &= ~LACKNERR;
		}
	}
	if (stage == 2) {
		// Reset
		stage = 0;
	}
}
#endif


#pragma mark
#pragma mark Delegate for UIAlertView
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if ([alertView.title isEqualToString:@"Hello!"]) {
		[self viewDidAppear:NO];
	}
	else {
		[self gotoMenu];
	}
}

- (void)gotoMenu {
	m48MenuMain * mainMenu = [[m48MenuMain alloc] init];
	mainMenu.emulatorViewController = self; // Pass myself to the menu.
	/*
	if (_emulatorOk) {
		[_emulatorView stopAnimation];
		
		//[_emulator stop];
		WaitForSleepState();
		//SwitchToState(SM_SLEEP);
	}
	*/
	

	
	// set the orientation mode of the navigation controller
	m48NavigationController * myNavigationController = (m48NavigationController *) self.navigationController;
	[myNavigationController setFixedOrientation:self.interfaceOrientation];
	[myNavigationController setFixedOrientationIsValid:YES];
	[self.navigationController pushViewController:mainMenu animated:YES];
	[mainMenu release];
}

@end
