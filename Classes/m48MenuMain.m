/*
 *  m48MenuMain.m
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

#import "m48MenuMain.h"
#import "m48MenuFetch.h"
#import "m48MenuHTMLContent.h"
#import "m48Filemanager.h"
#import "m48MenuSettings.h"
#import "m48ModalAlertView.h"
#import "patchwince.h"
#import "m48AppDelegate.h"

#import "m48SupportRequest.h"


static NSString *kSectionTitleKey = @"SectionTitleKey";
static NSString *kSectionElementsKey = @"SectionElementsKey";
static NSString *kElementLabelKey = @"ElementLabelKey";
static NSString *kElementAccessoryKey = @"ElementAccessoryKey";
static NSString *kElementActionMethodKey = @"ElementActionMethodKeyKey";
static NSString *kElementTypeKey = @"ElementTypeKey";
static NSString *kElementTypeNormal = @"ElementTypeNormal";
static NSString *kElementTypeInfo = @"ElementTypeInfo";

@implementation m48MenuMain

@synthesize currentMenuItems = _currentMenuItems;
@synthesize previousMenuItems = _previousMenuItems;
@synthesize emulatorViewController = _emulatorViewController;
@synthesize toolbarLabel = _toolbarLabel;

-(id)init {

	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		self.title = @"Menu";
	}
	return self;

}

- (NSString *)compileCurrentDocumentsInfoText {
	NSMutableString * tempString = [NSMutableString stringWithCapacity:0];
	
	if ([_emulatorViewController emulatorIsValid] == NO) {
		return @"Emulator not running"; // Should never be displayed
	}
	
	// Current model
	[tempString appendString:@"Model:\t"];
	if (xml && xml->global) {
		switch (xml->global->model) {
			case '6':
				[tempString appendString:@"HP38G (64KB RAM)"];
				break;
			case 'A':
				[tempString appendString:@"HP38G"];
				break;
			case 'E':
				if (xml->global->class == 39) {
					[tempString appendString:@"HP39G"];
				}
				else {
					[tempString appendString:@"HP40G"];
				}
				break;
			case 'G':
				[tempString appendString:@"HP48GX"];
				break;
			case 'S':
				[tempString appendString:@"HP48SX"];
				break;
			case 'X':
				[tempString appendString:@"HP49G"];
				break;
			default:
				[tempString appendString:@"-"];
				break;
		}
	}
	// Line Break
	[tempString appendString:@"\n"];
	
	// Variables
	NSRange range = {0,5};
	NSString * tempString21;
	NSMutableString * tempString2;
	CGSize size;
	CGSize size2;
	UIFont * font = [UIFont systemFontOfSize:12];
	CGFloat maxWidth = (self.view.bounds.size.width-40);
	
	// Current ROM:
	
	if (xml && xml->global) {
		tempString21 = xml->global->romFilename;
		// Manually remove everything before 'Documents'
		NSArray * tempArray = [tempString21 pathComponents];
		NSRange range;
		range.location = [tempArray indexOfObject:@"Documents"];
		if (range.location == NSNotFound)
			range.location = 0;
		range.location = range.location + 1;
		range.length = [tempArray count] - range.location;
		tempString2 = [NSMutableString stringWithString:@"/"];
		tempString21 = [NSString pathWithComponents:[tempArray objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]]];
		[tempString2 appendString:tempString21];
	}
	else {
		tempString2 = [NSMutableString stringWithString:@""];
	}
	tempString21  = @"ROM:\t";
	size = [tempString21 sizeWithFont:font];
	size2 = [tempString2 sizeWithFont:font];
	while  (((size2.width+size.width) > maxWidth) && tempString2 && ([tempString2 length] > 6)) {
		[tempString2 replaceCharactersInRange:range  withString:@"..."];		
		size2 = [tempString2 sizeWithFont:font];
	}
	[tempString appendString:tempString21];
	[tempString appendString:tempString2];
	
	// Line Break
	[tempString appendString:@"\n"];
	
	// Current Skin:
	tempString2 = [NSMutableString stringWithCapacity:0];
	tempString21 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlDirectory"];
	if ([tempString21 hasPrefix:@"/"] == NO) {
		[tempString2 appendString:@"/"];
	}
	[tempString2 appendString:tempString21];
	if ([[tempString2 substringFromIndex:([tempString2 length] - 1)] isEqual:@"/"] == NO) {
		[tempString2 appendString:@"/"];
	}
	tempString21 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlFilename"];
	[tempString2 appendString:tempString21]; 
	
	tempString21  = @"Skin:\t";
	size = [tempString21 sizeWithFont:font];
	size2 = [tempString2 sizeWithFont:font];
	if ((tempString2 != nil) && ([tempString2 length] > 0)) {
		while  (((size2.width+size.width) > maxWidth) && ([tempString2 length] > 6)) {
			[tempString2 replaceCharactersInRange:range  withString:@"..."];		
			size2 = [tempString2 sizeWithFont:font];
		}
	}
	[tempString appendString:tempString21];
	[tempString appendString:tempString2];
	
	// Line Break
	[tempString appendString:@"\n"];

#ifdef VERSIONPLUS
	// Current Document:
	tempString2 = [NSMutableString stringWithString:@""];
	tempString21 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
	if ([tempString21 hasPrefix:@"/"] == NO) {
		[tempString2 appendString:@"/"];
	}
	[tempString2 appendString:tempString21];
	if ([tempString2 hasSuffix:@"/"] == NO) {
		[tempString2 appendString:@"/"];
	}
	tempString21 = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentFilename"];
	[tempString2 appendString:tempString21]; 
	BOOL currentDocument = (tempString21 != nil) && ([tempString21 length] > 0); 
	if ([tempString21 isEqual:kUnsavedFileFilename]) {
		currentDocument = NO;
	}
	tempString21  = @"Calculator:\t";
	size = [tempString21 sizeWithFont:font];
	size2 = [tempString2 sizeWithFont:font];
	if (currentDocument) {
		while  (((size2.width+size.width) > maxWidth) && ([tempString2 length] > 6)) {
			[tempString2 replaceCharactersInRange:range  withString:@"..."];		
			size2 = [tempString2 sizeWithFont:font];
		}
	}
	else {
		tempString2  = [[kUnsavedFileDisplayText copy] autorelease];
	}
	[tempString appendString:tempString21];
	[tempString appendString:tempString2];
#endif
	return tempString;
}


//#define SHOWUNFINISHED
- (void)evaluateCurrentMenuItems {
	NSDictionary * tempDict;
	NSString * tempString;
	NSMutableArray * tempMutArray;
	BOOL currentDocument;
	BOOL currentDocumentIsUnsavedFile;
	
	self.previousMenuItems = _currentMenuItems;
	self.currentMenuItems = [NSMutableArray arrayWithCapacity:0];
	
	// ****************************
	// Documents - Section
	// ****************************
	tempMutArray = [NSMutableArray arrayWithCapacity:0];
	
	tempString = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentFilename"];
	currentDocument = (tempString != nil) && ([tempString length] > 0);
	if (currentDocument) {
		currentDocumentIsUnsavedFile = [tempString isEqual:kUnsavedFileFilename];
	}
	if ([_emulatorViewController emulatorIsValid] == YES) {
		tempString = [self compileCurrentDocumentsInfoText];
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					tempString, kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					kElementTypeInfo, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}
	
	if ([_emulatorViewController emulatorIsValid] == NO) {
		// Nur wenn kein Dokument geöffnet ist, kann ein Neues erstellt werden.
		// New...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"New ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnNewAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
        // Auto Setup...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Auto Setup ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnAutoSetupAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}
#ifdef VERSIONPLUS	
	if ([_emulatorViewController emulatorIsValid] == NO) {
		// Nur wenn kein Dokument geöffnet ist, kann ein vorhandenes Dokument geöffnet werden.
		// Open...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Open ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnOpenAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
	}

	
	if (currentDocument && _emulatorViewController.emulator.contentChanged && !currentDocumentIsUnsavedFile) {
		// Save
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Save", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnSaveAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Save As ...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Save As ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnSaveAsAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}
#endif
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Change Skin ...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Change Skin ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnChangeXmlScriptAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}

	if ([_emulatorViewController emulatorIsValid] == YES) {
	//if (currentDocument) {
		// Close
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Close", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnCloseAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];		
	}
	
	if ([tempMutArray count] > 0) {
		[_currentMenuItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Calculator", kSectionTitleKey, tempMutArray, kSectionElementsKey, nil]];
	}
	
	// ****************************
	// Edit - Section
	// ****************************
	tempMutArray = [NSMutableArray arrayWithCapacity:0];
#ifdef VERSIONPLUS	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Load Object
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Load Object ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnLoadObjectAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];			
	}
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Save Object As ...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Save Object As ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnSaveObjectAsAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
	}

	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Copy Stack
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				 @"Copy Stack", kElementLabelKey,
				 [NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
				 NSStringFromSelector(@selector(OnCopyStackAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];
	}
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Paste Stack
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Paste Stack", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnPasteStackAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
		
	}
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Copy Screenshot
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Copy Screenshot", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnCopyScreenAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
	}
	/*
	if (([_emulatorViewController emulatorIsValid] == YES) && (_emulatorViewController.screenshot != nil)) {
		// Save Screenshot As ...
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Save Screenshot As ...", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnSaveScreenshotAsAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
	}
     */
#endif
	if ([_emulatorViewController emulatorIsValid] == YES) {
		// Reset Calculator
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
					@"Reset CPU", kElementLabelKey,
					[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
					NSStringFromSelector(@selector(OnResetCPUAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
		[tempMutArray addObject:tempDict];	
	}
	 
	if ([tempMutArray count] > 0) {
		[_currentMenuItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Edit", kSectionTitleKey, tempMutArray, kSectionElementsKey, nil]];
	}
	 

	// ****************************
	// Extras - Section
	// ****************************
	tempMutArray = [NSMutableArray arrayWithCapacity:0];

	// Settings
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"Settings ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnSettingsAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];	
	
	// Fetch
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"Fetch ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnFetchAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];	
	
#ifdef VERSIONPLUS
	// Filemanager
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"Filemanager ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnFilemanagerAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
#endif
	
	if ([tempMutArray count] > 0) {
		[_currentMenuItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Extras", kSectionTitleKey, tempMutArray, kSectionElementsKey, nil]];
	}
	
	// ****************************
	// Information - Section
	// ****************************
	tempMutArray = [NSMutableArray arrayWithCapacity:0];

#ifndef VERSIONPLUS
	// Donate
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"m48+ ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnM48plusAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
#endif
	/*
	// News
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"News ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnNewsAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];	
     */
	// FAQ
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"FAQ ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnFAQAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
	
	// Help
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"Help ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnHelpAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
	
	// About
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"About ...", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryDisclosureIndicator], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnAboutAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
#ifdef FALSEFALSEFALSE
#ifdef VERSIONPLUS
	// Support Request
	tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
				@"Send Support Request", kElementLabelKey,
				[NSNumber numberWithInt:UITableViewCellAccessoryNone], kElementAccessoryKey,
				NSStringFromSelector(@selector(OnSupportAction)), kElementActionMethodKey, kElementTypeNormal, kElementTypeKey, nil];
	[tempMutArray addObject:tempDict];
#endif
#endif
	
	if ([tempMutArray count] > 0) {
		[_currentMenuItems addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Information", kSectionTitleKey, tempMutArray, kSectionElementsKey, nil]];
	}
}


- (void)reevaluateMenuAnimated:(BOOL)animated {
	
	[self evaluateCurrentMenuItems];
	
	// Update
	if ((_previousMenuItems == nil) || (animated == NO)) {
		[self.tableView reloadData];
	}
	else {
		NSMutableIndexSet * sectionsToRemove = [NSMutableIndexSet indexSet];
		NSMutableIndexSet * sectionsToAdd = [NSMutableIndexSet indexSet];
		NSMutableIndexSet * sectionsToKeep = [NSMutableIndexSet indexSet];
		
		NSMutableArray * prevSectionTitles = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray * curSectionTitles = [NSMutableArray arrayWithCapacity:0];
		NSDictionary * prevSection;
		NSDictionary * curSection;
		NSString * prevSectionTitle;
		NSString * curSectionTitle;
		
		for (int i=0; i < [_previousMenuItems count]; i++) {
			prevSection = [_previousMenuItems objectAtIndex:i];
			[prevSectionTitles addObject:[prevSection objectForKey:kSectionTitleKey]];
		}
		for (int i=0; i < [_currentMenuItems count]; i++) {
			curSection = [_currentMenuItems objectAtIndex:i];
			[curSectionTitles addObject:[curSection objectForKey:kSectionTitleKey]];
		}
		
		int prevSectionTitlesStartVal = 0;
		
		for (int i=0; i < [curSectionTitles count]; i++) {
			curSectionTitle = [curSectionTitles objectAtIndex:i];
			for (int j=prevSectionTitlesStartVal; j < [prevSectionTitles count]; j++) {
				prevSectionTitle = [prevSectionTitles objectAtIndex:j];
				if ([prevSectionTitle isEqual:curSectionTitle]) {
					[sectionsToKeep addIndex:j];
					prevSectionTitlesStartVal = j+1;
					break;
				}
				else {
					// Lets see if the section title might come in the current section titles
					BOOL found = NO;
					for (int k=i; k < [curSectionTitles count]; k++) {
						NSString * tempString = [curSectionTitles objectAtIndex:k];
						if ([tempString isEqual:prevSectionTitle]) {
							found = YES;
							break;
						}
					}
					if (!found) {
						[sectionsToRemove addIndex:j];
						prevSectionTitlesStartVal = j+1;
					}
					else {
						[sectionsToAdd addIndex:j];
					}
				}
			}
		}
			
				
		[self.tableView beginUpdates];
		[self.tableView insertSections:sectionsToAdd withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView deleteSections:sectionsToRemove withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView reloadSections:sectionsToKeep withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];
		
		if ([_emulatorViewController emulatorIsValid] == YES) {
			[self.navigationController.navigationBar.topItem setHidesBackButton:NO animated:animated];
		}
		else {
			[self.navigationController.navigationBar.topItem setHidesBackButton:YES animated:animated];
		}		
	}
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_toolbarLabel release];
	[_currentMenuItems release];
	[_previousMenuItems release];
	[super dealloc];
}

#pragma mark -
#pragma mark Implementation of Actions;

- (void)OnNewAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
#ifdef VERSIONPLUS
    NSString * currentPath = @"Skins/";
	//NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlDirectory"];
#else
	NSString * currentPath = @"/Skins/HP48G/";
#endif
#ifdef VERSIONPLUS
	[myFilemanager setCurrentDirectory:currentPath];
#else
	[myFilemanager setCurrentDirectory:@""];
	myFilemanager.baseDirectory = [myFilemanager.baseDirectory stringByAppendingPathComponent:currentPath];
#endif
	[myFilemanager setMode:m48FilemanagerModeChooseXmlScriptDialog];
    [myFilemanager setTrackDirectory:NO];
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.xml",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTarget:_emulatorViewController filterAction:(@selector(newDocumentXmlFilterAction:title:)) selectAction:(@selector(newDocumentSelectAction:))];
	[myFilemanager setTitle:@"Choose Skin"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}

- (void)OnAutoSetupAction {
	[self.navigationController popToRootViewControllerAnimated:YES];
}

#ifdef VERSIONPLUS
- (void)OnOpenAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	//NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
    NSString * currentPath = @"Documents/";
	[myFilemanager setCurrentDirectory:currentPath];
	[myFilemanager setMode:m48FilemanagerModeOpenDialog];
    [myFilemanager setTrackDirectory:YES];
	
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.m48",@"*.*",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(openDocumentSelectAction:))];
	[myFilemanager setTitle:@"Open"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}

- (void)OnSaveAction {
	[_emulatorViewController saveCurrentDocumentAction];
	[self reevaluateMenuAnimated:YES];
}

- (void)OnSaveAsAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
	[myFilemanager setCurrentDirectory:currentPath];
	[myFilemanager setMode:m48FilemanagerModeSaveAsDialog];
	
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.m48",@"*.*",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(saveDocumentAsSelectAction:))];
	[myFilemanager setTitle:@"Save As"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}
#endif

- (void)OnChangeXmlScriptAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlDirectory"];
#ifdef VERSIONPLUS
	[myFilemanager setCurrentDirectory:currentPath];
#else
	myFilemanager.baseDirectory = [myFilemanager.baseDirectory stringByAppendingPathComponent:currentPath];
	[myFilemanager setCurrentDirectory:@""];
#endif
	[myFilemanager setMode:m48FilemanagerModeChooseXmlScriptDialog];
    [myFilemanager setTrackDirectory:NO];
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.xml",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTarget:_emulatorViewController filterAction:(@selector(changeXmlFilterAction:title:)) selectAction:(@selector(changeXmlSelectAction:))];
	[myFilemanager setTitle:@"Change Skin"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}

- (void)OnCloseAction {
	[_emulatorViewController closeDocument];
}

#ifdef VERSIONPLUS
- (void)OnLoadObjectAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	//NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
    NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentFilemanagerDirectory"];
	[myFilemanager setCurrentDirectory:currentPath];
	[myFilemanager setMode:m48FilemanagerModeOpenDialog];
    [myFilemanager setTrackDirectory:YES];
	
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.obj",@"*.*",@"*.lib",@"*.hp",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:1]];
	[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(loadObjectSelectAction:))];
	[myFilemanager setTitle:@"Load Object"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}


- (void)OnSaveObjectAsAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	//NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentDocumentDirectory"];
    NSString * currentPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentFilemanagerDirectory"];
	[myFilemanager setCurrentDirectory:currentPath];
	[myFilemanager setMode:m48FilemanagerModeSaveAsDialog];
    [myFilemanager setTrackDirectory:YES];
	
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.obj",@"*.*",@"*.lib",@"*.hp",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(saveObjectAsSelectAction:))];
	[myFilemanager setTitle:@"Save Object As"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}

- (void)OnMacroRecordAction {
	
}

- (void)OnMacroPlayAction {
	
}

- (void)OnMacroStopAction {
	
}

- (void)OnCopyStackAction {
	NSError * error = nil;
	if (![self.emulatorViewController copyFromStackToPasteboard:&error]) {
		if (error != nil) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error!" message:[error.userInfo valueForKey:NSLocalizedDescriptionKey] 
														   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];	
			[alert release];
		}
	}
}

- (void)OnPasteStackAction {
	NSError * error = nil;
	if (![self.emulatorViewController pasteFromPasteboardToStack:&error]) {
		if (error != nil) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error!" message:[error.userInfo valueForKey:NSLocalizedDescriptionKey] 
														   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];	
			[alert release];
		}
	}
}

- (void)OnCopyScreenAction {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Screenshot" message:@"To make screenshots go back to the calculator and press the Power- and Home-Button of your iDevice simultanously. The screen should flash white. You will find the screenshot in your photos."
													   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
	[alert show];
    [alert release];
}

/*
- (void)OnCopyScreenAction {
	
	if (_emulatorViewController.screenshot == nil) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error!" message:@"Emulator not running." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];	
		[alert release];
		
		return;
	}
		
	// open a dialog with two custom buttons
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Copy Screenshot"
														delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
														otherButtonTitles:@"Full screen", @"Only LCD", nil];
	actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
	[actionSheet showInView:self.view]; // show from our table view (pops up in the middle of the table)
	[actionSheet release];
}
	

- (void)OnSaveScreenshotAsAction {
	if (_emulatorViewController.screenshot == nil) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error!" message:@"Emulator not running." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];	
		[alert release];
		
		return;
	}
	
	// open a dialog with two custom buttons
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Save Screenshot"
															 delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
													otherButtonTitles:@"Full screen", @"Only LCD", nil];
	actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
	[actionSheet showInView:self.view]; // show from our table view (pops up in the middle of the table)
	[actionSheet release];
}
*/
#endif

- (void)OnResetCPUAction {
	// Startup code for modal view
	static m48ModalAlertView * myAlertView = nil;
	if (myAlertView == nil) { // Initialize
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.target = self;
		myAlertView.selector = @selector(OnResetCPUAction);
		myAlertView.title = @"Reset CPU";
		[myAlertView.buttonTexts addObject:@"Cancel"];
		[myAlertView.buttonTexts addObject:@"Reset"];
		myAlertView.message = @"Do you really want to reset the CPU? Some data within the current calculator may get lost!";
	}
	
	switch (myAlertView.evolutionStage) {
		case 0:
			[myAlertView show];
			break;
		case 1:
			if (myAlertView.didDismissWithButtonIndex == 1) {
				NSError * error = nil;
				[_emulatorViewController resetEmulator:&error];
				if (error != nil) {
					[myAlertView initForError];
					myAlertView.message = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
					[myAlertView show];
					break;
				}
			}
			goto cleanup;
			break;
		default:
			goto cleanup;
			break;
	}
	return;
cleanup:
	[myAlertView release];
	myAlertView = nil;
	return;
}

- (void)OnSettingsAction {
	m48MenuSettings * menuSettings;
    menuSettings = [[m48MenuSettings alloc] initWithPropertyList:@"settings"];
	[self.navigationController pushViewController:menuSettings animated:YES];
	[menuSettings release];
}

- (void)OnFetchAction {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
#ifndef VERSIONPLUS
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48_fetch.plist", version]];
	NSString * tempFilename = @"Information/m48_fetch.plist";
#else
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48plus/%@/m48plus_Documents/Information/m48plus_fetch.plist", version]];
	NSString * tempFilename = @"Information/m48plus_fetch.plist";
#endif	
	m48MenuFetch * romMenu = [[m48MenuFetch alloc] initWithFilename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:romMenu animated:YES];
	[romMenu release];
}
#ifdef VERSIONPLUS
- (void)OnFilemanagerAction {
	m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
	[myFilemanager setCurrentDirectory:[[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentFilemanagerDirectory"]];
	[myFilemanager setMode:m48FilemanagerModeFilemanagerDialog];
    [myFilemanager setTrackDirectory:YES];
	NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.*",@"*.m48",@"*.obj",@"*.lib",@"*.hp",@"*.html",@"*.txt",@"*.xml",@"*.png",@"*.jpg",@"*.bmp",@"*.wav",@"*.caf",nil];
	[myFilemanager setExtensionFilters:extensionFilter];
	[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
	[myFilemanager setTitle:@"Filemanager"];
	[self.navigationController pushViewController:myFilemanager animated:YES];
	[myFilemanager release];
}
#endif

#ifndef VERSIONPLUS
- (void)OnM48plusAction {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48plus_info.html", version]];
	NSString * tempFilename = @"Information/m48plus_info.html";
	m48MenuHTMLContent * childMenu = [[m48MenuHTMLContent alloc] initWithTitle:@"m48+" filename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:childMenu animated:YES];
	[childMenu release];
}
#endif

- (void)OnNewsAction {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
#ifndef VERSIONPLUS
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48_news.html", version]];
	NSString * tempFilename = @"Information/m48_news.html";
#else
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48plus/%@/m48plus_Documents/Information/m48plus_news.html", version]];
	NSString * tempFilename = @"Information/m48plus_news.html";
#endif

	m48MenuHTMLContent * childMenu = [[m48MenuHTMLContent alloc] initWithTitle:@"News" filename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:childMenu animated:YES];
	[childMenu release];
}

- (void)OnFAQAction {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
#ifndef VERSIONPLUS
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48_faq.html", version]];
	NSString * tempFilename = @"Information/m48_faq.html";
#else
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48plus/%@/m48plus_Documents/Information/m48plus_faq.html", version]];
	NSString * tempFilename = @"Information/m48plus_faq.html";
#endif
	m48MenuHTMLContent * childMenu = [[m48MenuHTMLContent alloc] initWithTitle:@"FAQ" filename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:childMenu animated:YES];
	[childMenu release];
}


- (void)OnHelpAction {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
#ifndef VERSIONPLUS
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48_help.html", version]];
	NSString * tempFilename = @"Information/m48_help.html";
#else
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48plus/%@/m48plus_Documents/Information/m48plus_help.html", version]];
	NSString * tempFilename = @"Information/m48plus_help.html";
#endif
	m48MenuHTMLContent * childMenu = [[m48MenuHTMLContent alloc] initWithTitle:@"Help" filename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:childMenu animated:YES];
	[childMenu release];
}

- (void)OnAboutAction  {
	NSString * version = [[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentVersionNumber"];
#ifndef VERSIONPLUS
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48/%@/m48_Documents/Information/m48_about.html", version]];
	NSString * tempFilename = @"Information/m48_about.html";
#else
	NSURL * tempUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://<url>/m48plus/%@/m48plus_Documents/Information/m48plus_about.html", version]];
	NSString * tempFilename = @"Information/m48plus_about.html";
#endif
	m48MenuHTMLContent * childMenu = [[m48MenuHTMLContent alloc] initWithTitle:@"About" filename:getFullDocumentsPathForFile(tempFilename) URL:tempUrl];
	[self.navigationController pushViewController:childMenu animated:YES];
	[childMenu release];
}

#ifdef VERSIONPLUS
-(void)OnSupportAction {
	MFMailComposeViewController * controller = [[MFMailComposeViewController alloc] init];
	controller.mailComposeDelegate = self;
	[controller setToRecipients:[NSArray arrayWithObject:@"m48@mksg.de"]];
	[controller setSubject:@"Support Request"];
	[controller setMessageBody:[m48SupportRequest generateText] isHTML:NO]; 
	[self presentModalViewController:controller animated:YES];
	[controller release];
}


- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error;
{
	if (result == MFMailComposeResultSent) {
		//DEBUG NSLog(@"It's away!");
	}
	[self dismissModalViewControllerAnimated:YES];
}
#endif

#pragma mark -
#pragma mark UIActionSheetDelegate
/*
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if ([actionSheet.title isEqualToString:@"Copy Screenshot"]) {
		if (buttonIndex == 0) {
			[_emulatorViewController copyScreenshotActionFull];
		}
		else if (buttonIndex == 1) {
			[_emulatorViewController copyScreenshotActionOnlyLcd];
		}
	}
	else if ([actionSheet.title isEqualToString:@"Save Screenshot"]) {
		m48Filemanager * myFilemanager = [[m48Filemanager alloc] init];
		[myFilemanager setCurrentDirectory:[[NSUserDefaults standardUserDefaults] objectForKey:@"internalCurrentFilemanagerDirectory"]];
		[myFilemanager setMode:m48FilemanagerModeSaveAsDialog];
        [myFilemanager setTrackDirectory:YES];
		NSArray * extensionFilter = [NSArray arrayWithObjects:@"*.png",@"*.*",nil];
		[myFilemanager setExtensionFilters:extensionFilter];
		[myFilemanager setSelectedExtensionFilter:(NSString *)[extensionFilter objectAtIndex:0]];
		
		[myFilemanager setTitle:@"Save Screenshot"];
		
		if (buttonIndex == 0) {
			[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(saveScreenshotAsSelectActionFull:))];
		}
		else if (buttonIndex == 1) {
			[myFilemanager setTarget:_emulatorViewController filterAction:nil selectAction:(@selector(saveScreenshotAsSelectActionOnlyLcd:))];
		}
		if (buttonIndex != 2) {
			[self.navigationController pushViewController:myFilemanager animated:YES];
		}
		[myFilemanager release];
	}
}
*/

#pragma mark -
#pragma mark Implementation of viewController;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (void)viewWillAppear:(BOOL)animated {
	//[self evaluateCurrentMenuItems];
	//[self.tableView reloadData];
	[self reevaluateMenuAnimated:NO];
	
	UIApplication * application = [UIApplication sharedApplication];
	[application setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	[application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
	[self.navigationController setNavigationBarHidden:NO animated:YES];
	
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	
	if ([_emulatorViewController emulatorIsValid] == YES) {
		[self.navigationController.navigationBar.topItem setHidesBackButton:NO animated:animated];
	}
	else {
		[self.navigationController.navigationBar.topItem setHidesBackButton:YES animated:animated];
	}

#ifdef VERSIONPLUS
	// Check if the fileserver is running:
	BOOL serverShouldRun = [[NSUserDefaults standardUserDefaults] boolForKey:@"serverEnabled"];
	m48AppDelegate * appDelegate = (m48AppDelegate *) [[UIApplication sharedApplication] delegate];		

	if (serverShouldRun == YES) {
		
		if (appDelegate.serverIsRunning == NO) {
			// Start the server
			[appDelegate setupAndStartServer];
		}
		
		[self.navigationController setToolbarHidden:NO animated:animated];
		[self setupToolbar];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
	}
	else {
		if (appDelegate.serverIsRunning == YES) {
			[appDelegate startStopServer:NO];
		}
		[self.navigationController setToolbarHidden:NO animated:animated];
		[self setupToolbar];
        _toolbarLabel.text = @"Enable WiFi-Server in Settings.";
	}

	
#else
	[self.navigationController setToolbarHidden:YES animated:animated];
#endif
    UIApplication * application = [UIApplication sharedApplication];
    [application setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	[application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];

#ifdef VERSIONPLUS
	// Check activation
	[self checkLicense];
#endif
	
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewWillDisappear:animated];
}

#ifdef VERSIONPLUS
- (void)setupToolbar {
	// Set up the labels
	CGRect bounds = self.navigationController.toolbar.bounds;
	UILabel * aToolbarLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width - 40, 30)];
    [aToolbarLabel setTextAlignment:NSTextAlignmentCenter];
	//[aToolbarLabel setTextColor:[UIColor blackColor]]; // No longer required for >= iOS7
	//[aToolbarLabel setBackgroundColor:[UIColor clearColor]]; // No longer required for >= iOS7
	[aToolbarLabel setFont:[aToolbarLabel.font fontWithSize:14]];
	self.toolbarLabel = aToolbarLabel;
	
	[self displayInfoUpdate:nil];
	
	UIBarButtonItem * tempItem = [[UIBarButtonItem alloc] initWithCustomView:aToolbarLabel];
	
	[aToolbarLabel release];
	
	UIBarButtonItem * tempSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	NSArray * tempArray = [NSArray arrayWithObjects:tempSpace,tempItem,tempSpace,nil];
	
	[tempItem release];
	[tempSpace release];
	
	[self.navigationController.toolbar setItems:tempArray animated:NO];	
}

#pragma mark Internal Server
- (void)displayInfoUpdate:(NSNotification *) notification {
	
	m48AppDelegate * appDelegate = (m48AppDelegate *) [[UIApplication sharedApplication] delegate];
	if (appDelegate.addresses != nil) {
		
#if TARGET_IPHONE_SIMULATOR
		NSString *curAddress = [appDelegate.addresses objectForKey:@"en1"];
#else
		NSString *curAddress = [appDelegate.addresses objectForKey:@"en0"];
#endif
		NSInteger port = (NSInteger)[appDelegate.httpServer port];
		NSString *portString;
		
		if (port==80)
		{
			portString = @"";  // standard, no need to specify
		}
		else
		{
			portString = [NSString stringWithFormat:@":%d", port]; // non-standard
		}
		
		if (curAddress != nil) {
			_toolbarLabel.text = [NSString stringWithFormat:@"Server: http://%@%@", curAddress, portString];
			return;
		}
	}
	_toolbarLabel.text = @"WLAN not available";
}
#endif


#ifdef VERSIONPLUS
- (void)checkLicense {
	static int evolutionStage = 0;
	static m48ModalAlertView * myAlertView = nil;
	
	switch (evolutionStage) {
		case 0:
			break;
		case 1:
			if ((myAlertView != nil) && (myAlertView.didDismissWithButtonIndex == 1)) {
				NSString *iTunesLink = @"http://phobos.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=341541461&mt=8";
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
			}
			[myAlertView release];
			myAlertView = nil;
			evolutionStage = 0;
			break;
		default:
			evolutionStage = 0;
			break;
	}
}
#endif	

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	////DEBUG NSLog(@"numberOfSectionsInTableView");
	return [self.currentMenuItems count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	////DEBUG NSLog(@"tableView:titleForHeaderInSection");
	return [[self.currentMenuItems objectAtIndex: section] valueForKey:kSectionTitleKey];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	////DEBUG NSLog(@"tableView:numberOfRowsInSection");
	NSDictionary * aDictionary = [self.currentMenuItems objectAtIndex:section];
	NSArray * anArray = [aDictionary objectForKey:kSectionElementsKey];
	return [anArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	// Retrieve the element
	NSDictionary * aDictionary = [self.currentMenuItems objectAtIndex: indexPath.section];
	NSArray * anArray = [aDictionary valueForKey:kSectionElementsKey];
	aDictionary = [anArray objectAtIndex: indexPath.row];
	NSString * tempString = [aDictionary objectForKey:kElementTypeKey];
	if ((tempString != nil) && ([tempString isEqual:kElementTypeInfo] == YES)) {
		return 70.0;
	}
	else {
		return 44.0;
	}
}

// to determine which UITableViewCell to be used on a given row.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Retrieve the element
	NSDictionary * aDictionary = [self.currentMenuItems objectAtIndex: indexPath.section];
	NSArray * anArray = [aDictionary valueForKey:kSectionElementsKey];
	aDictionary = [anArray objectAtIndex: indexPath.row];
	
	////DEBUG NSLog(@"tableView:cellForRowAtIndexPath");
	UITableViewCell *cell = nil;
	
	// Cell identifier keys
	static NSString *kNormalCellID = @"DisplayCellID";
	static NSString *kInfoCellID = @"InfoCellID";
	
	NSString * tempString = [aDictionary objectForKey:kElementTypeKey];
	if ((tempString != nil) && ([tempString isEqual:kElementTypeInfo] == YES)) {
		cell = [self.tableView dequeueReusableCellWithIdentifier:kInfoCellID];
		if (cell == nil)
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kInfoCellID] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			//CGRect bounds = cell.frame;
			//bounds.size.height = 100.0;
			//cell.frame	= bounds;
			//cell.textLabel.bounds = bounds;
			cell.textLabel.backgroundColor = [UIColor clearColor];
			cell.textLabel.font =  [UIFont systemFontOfSize:12]; // [cell.textLabel.font fontWithSize:11];
			cell.textLabel.numberOfLines = 0;
			
		}
	}
	else {
		cell = [self.tableView dequeueReusableCellWithIdentifier:kNormalCellID];
		if (cell == nil)
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kNormalCellID] autorelease];
			//cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
	}	
	
	
	
	cell.textLabel.text = [aDictionary valueForKey:kElementLabelKey];
	NSNumber * accessoryTypeNumber = [aDictionary valueForKey:kElementAccessoryKey];
	cell.accessoryType = [accessoryTypeNumber intValue];
	
	return cell;
}


// the table's selection has changed, show the alert or action sheet
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// deselect the current row (don't keep the table selection persistent)
	[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	
	NSDictionary * aDictionary = [self.currentMenuItems objectAtIndex: indexPath.section];
	NSArray * anArray = [aDictionary valueForKey:kSectionElementsKey];
	aDictionary = [anArray objectAtIndex: indexPath.row];
	  
	if ([kElementTypeInfo isEqual:[aDictionary objectForKey:kElementTypeKey]] == NO) {
		[self performSelector:NSSelectorFromString([aDictionary objectForKey:kElementActionMethodKey])];
	}
}



@end
