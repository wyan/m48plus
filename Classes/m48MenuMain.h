/*
 *  m48MenuMain.h
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
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "m48EmulatorViewController.h"

//static NSString * kOnChangeXmlScriptAction = @"OnChangeXmlScriptAction";

@interface m48MenuMain : UITableViewController <UIAlertViewDelegate,		// for UIAlertView
												UIActionSheetDelegate,	// for UIActionSheet
												MFMailComposeViewControllerDelegate>
{
	NSMutableArray * _currentMenuItems;
	NSMutableArray * _previousMenuItems;
	
	m48EmulatorViewController * _emulatorViewController;
	
	// Toolbar label
	UILabel * _toolbarLabel;
}


@property (nonatomic, retain) NSMutableArray * currentMenuItems;
@property (nonatomic, retain) NSMutableArray * previousMenuItems;
@property (nonatomic, retain) m48EmulatorViewController * emulatorViewController;
@property (nonatomic, retain) UILabel * toolbarLabel;

- (NSString *)compileCurrentDocumentsInfoText;
- (void)evaluateCurrentMenuItems;
- (void)reevaluateMenuAnimated:(BOOL)animated;

#ifdef VERSIONPLUS
- (void)setupToolbar;
- (void)displayInfoUpdate:(NSNotification *) notification;
#endif

- (void)OnNewAction;
- (void)OnAutoSetupAction;
#ifdef VERSIONPLUS
- (void)OnOpenAction;
- (void)OnSaveAction;
- (void)OnSaveAsAction;
#endif
- (void)OnChangeXmlScriptAction;
- (void)OnCloseAction;

#ifdef VERSIONPLUS
- (void)OnLoadObjectAction;
- (void)OnSaveObjectAsAction;

- (void)OnMacroRecordAction;
- (void)OnMacroPlayAction;
- (void)OnMacroStopAction;


- (void)OnCopyStackAction;
- (void)OnPasteStackAction;
- (void)OnCopyScreenAction;
//- (void)OnSaveScreenshotAsAction;
#endif
- (void)OnResetCPUAction;

- (void)OnSettingsAction;
- (void)OnFetchAction;
#ifdef VERSIONPLUS
- (void)OnFilemanagerAction;
#endif
#ifndef VERSIONPLUS
- (void)OnM48plusAction;
#endif
- (void)OnNewsAction;
- (void)OnFAQAction;
- (void)OnHelpAction;
- (void)OnAboutAction;
#ifdef VERSIONPLUS
- (void)OnSupportAction;
#endif
#ifdef VERSIONPLUS
- (void)checkLicense;
#endif

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;

@end
