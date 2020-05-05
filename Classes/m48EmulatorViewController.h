/*
 *  m48EmulatorViewController.h
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

#import <UIKit/UIKit.h>
//#import <AudioToolbox/AudioToolbox.h>
#import "m48Emulator.h"			// Model
#import "m48EmulatorEAGLView.h" // View
#import "m48EmulatorStartupPreview.h"
#import "m48EmulatorAudioEngine.h" // Audio
#import "xml.h"

#define MAXTOUCHES 10
typedef struct __touchDictData {
	BOOL		posIsValid;
	CGPoint		pos;
	NSTimer *	timer;
	BOOL		timerFired;
	BOOL		lostFocus;
} TouchDictData;

@interface TouchDict : NSObject
{
	id				_keys[MAXTOUCHES];
	TouchDictData	_touchDictData[MAXTOUCHES];
}
-(void)clearPos:(int)pos;
-(int)findfreePos;
-(int)findKey:(id)key;
-(void)clearKey:(id)key;
-(TouchDictData *)touchDictDataForKey:(id)key;
@end


@interface m48EmulatorViewController : UIViewController {
	m48Emulator *			_emulator;
	m48EmulatorEAGLView *	_emulatorView;
	BOOL					_emulatorOk;
	
	m48EmulatorAudioEngine * _emulatorAudio;
	
	m48EmulatorStartupPreview * _startupPreview;
	BOOL					_autoSetupInProgress;
	NSString *              _autoSetupCalcType;
	NSString *				_autoSetupSkinType;
	
	
	//UIImage *				_screenshot;
	CGRect					_lcdRect;
	
	// Managing touches
	TouchDict *				_touchDict;
	TouchDict *				_tapDict;
	float					_screenScale;

	// Managing execution of actions
	NSMutableArray *		_actionQueue;
	int						_currentSubStep;
	NSTimer *				_actionQueueTimer;
	
	// Managing orientation lock
	BOOL					_shouldLockToOrientation;
	UIInterfaceOrientation	_preferredOrientation1;
	UIInterfaceOrientation	_preferredOrientation2;
	BOOL					_preferredOrientation2IsAlt;
}

@property (readonly, nonatomic) m48Emulator * emulator;
@property (retain, nonatomic) m48EmulatorAudioEngine * emulatorAudio;
@property (retain, nonatomic) m48EmulatorEAGLView * emulatorView;
@property (retain, nonatomic) m48EmulatorStartupPreview * startupPreview;
@property (retain, nonatomic) NSString * autoSetupCalcType;
@property (retain, nonatomic) NSString * autoSetupSkinType;
//@property (nonatomic, retain) UIImage * screenshot;
@property (nonatomic, assign) CGRect lcdRect;
@property (nonatomic, retain) NSMutableArray * actionQueue;
@property (nonatomic, retain) NSTimer * actionQueueTimer;
@property (nonatomic, retain) TouchDict * touchDict;
@property (nonatomic, retain) TouchDict * tapDict;

-(id)init;
- (void)startupEmulator:(id)anObject;
- (void)autoSetup;

-(void)gotoMenu;

// Functions which are required by the menu
-(BOOL)changeXmlSelectAction:(NSString *)filename;
-(BOOL)changeXmlFilterAction:(NSString *)filename title:(NSString **)title;
-(BOOL)newDocumentSelectAction:(NSString *)filename;
-(BOOL)newDocumentXmlFilterAction:(NSString *)filename title:(NSString **)title;
-(BOOL)openDocumentSelectAction:(NSString *)filename;
-(BOOL)saveCurrentDocumentAction;
-(BOOL)saveDocumentAsSelectAction:(NSString *)filename;

-(BOOL)closeDocument;



#ifdef VERSIONPLUS
-(BOOL)loadObjectSelectAction:(NSString *)filename;
-(BOOL)saveObjectAsSelectAction:(NSString *)filename;
-(BOOL)copyFromStackToPasteboard:(NSError **)error;
-(BOOL)pasteFromPasteboardToStack:(NSError **)error;
#endif
-(BOOL)resetEmulator:(NSError **)error;

/*
- (void)copyScreenshotActionFull;
- (void)copyScreenshotActionOnlyLcd;
- (void)saveScreenshotAsSelectActionFull:(NSString *)filename;
- (void)saveScreenshotAsSelectActionOnlyLcd:(NSString *)filename;
*/

-(void)loadSettings;
-(void)start;
-(void)pause;
-(void)stop;

-(BOOL)emulatorIsValid;


// Touches tracking
-(void)handleHoldTimer:(NSTimer *)timer;
-(void)handleSingleTap:(NSTimer *)timer;

-(void)buttonDownEventWithButton:(XmlButton *)button;
-(void)buttonUpEventWithButton:(XmlButton *)button;
-(void)buttonTriggerEventWithButton:(XmlButton *)button;
-(void)buttonCancelEventWithButton:(XmlButton *)button;

-(void)queueActionOfButton:(XmlButton *)button;
-(void)execActionQueue:(NSTimer *)timer;
-(void)cancelAllActions;

#ifdef VERSIONPLUS
-(void)copyFromStackToPasteboardSkinMethod;
-(void)pasteFromPasteboardToStackSkinMethod;
#endif

- (void)applicationWillTerminate:(UIApplication *)application;

@end
