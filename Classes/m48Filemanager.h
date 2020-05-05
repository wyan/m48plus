/*
 *  m48Filemanager.h
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

typedef enum _m48FilemanagerMode {
	m48FilemanagerModeOpenDialog,
	m48FilemanagerModeSaveAsDialog,
	m48FilemanagerModeChooseXmlScriptDialog,
	m48FilemanagerModeFilemanagerDialog
} m48FilemanagerMode;

extern NSString * const kFilenameKey;
extern NSString * const kModificationDateKey;
extern NSString * const kFileSizeKey;
extern NSString * const kIconImageFilename;

@interface m48Filemanager : UITableViewController <UIAlertViewDelegate,		// for UIAlertView
												   UIActionSheetDelegate,   // for UIActionSheet
												   UITableViewDataSource, UITableViewDelegate,
												   UITextFieldDelegate>	 
{
	NSFileManager * _filemanager;
	
	
	// Mode
	m48FilemanagerMode _mode;
	
    // TargetActionMechanism
    id _target;
	SEL _selectAction;
	SEL _filterAction;
	
	// Data:
	NSMutableArray *	_contentList;
	NSString *			_currentDirectory;
	NSString *			_baseDirectory;
	
	// Filter
	NSArray * _extensionFilters;
	NSString * _selectedExtensionFilter;
	
	// ContentViewer
	NSArray * _displayableContents;
	
	// Helper
	int				_blinkCounter;
	
	// Icons
	NSMutableArray * _images;
	
	// Toolbar label
	UILabel * _toolbarLabel;
	
	// TextFields
	UITextField * _textFieldNewFile;
	UITextField * _textFieldNewDirectory;
	UITextField * _textFieldRename;
	
	// For Copy/Paste Operation
	NSString * _copyItem;
	BOOL _isCutItem;
    
    // For currentDirectory
    BOOL _trackDirectory;
}

@property (nonatomic, retain) NSMutableArray * contentList;
@property (nonatomic, retain) NSString * currentDirectory;
@property (nonatomic, retain) NSString * baseDirectory;
@property (nonatomic, retain) NSFileManager * filemanager;
@property (nonatomic, retain) NSArray * extensionFilters;
@property (nonatomic, retain) NSString * selectedExtensionFilter;
@property (nonatomic, retain) NSMutableArray * images;
@property (nonatomic, retain) UILabel * toolbarLabel;
@property (nonatomic, retain) UITextField * textFieldNewFile;
@property (nonatomic, retain) UITextField * textFieldNewDirectory;
@property (nonatomic, retain) UITextField * textFieldRename;
@property (nonatomic, retain) NSArray * displayableContents;
@property (nonatomic, retain) NSString * copyItem;
@property (nonatomic, assign) BOOL isCutItem;
@property (nonatomic, assign) BOOL trackDirectory;

@property m48FilemanagerMode mode;

+ (BOOL)unpackApplicationDocumentsWithError:(NSError **)error;
+ (BOOL)unzipFile:(NSString *)src to:(NSString *)dest isDirectory:(BOOL)isDirectory doOverwrite:(BOOL)doOverwrite doDeleteSource:(BOOL)doDeleteSource withError:(NSError **)error;
+ (BOOL)migrateFromVersion:(NSString *)oldVersion toVersion:(NSString *)newVersion;
+ (NSString *)absoluteHomeDirectory;
+ (NSString *)absoluteDocumentsPathForFile:(NSString *)filename;
+ (NSArray *)readDocumentsDirectory:(NSString *)directory;
+ (NSMutableArray *)iconImageList;
+ (NSMutableDictionary *)searchIconImageList:(NSArray *)list forExtension:(NSString *)extension;


- (void)readCurrentDirectory;
- (void)updateAnimated:(BOOL)animated;


- (NSString *)absoluteBaseDirectory;
- (NSString *)absoluteCurrentDirectory;

- (void)selectedFileAction:(NSString *)selectedFile;
- (void)finishedSelectedFileActionWithSuccess:(BOOL)success;

- (void)changeExtensionFilterTargetAction;

- (void)setTarget:(id)target filterAction:(SEL)filterAction selectAction:(SEL)selectAction;

- (void)changeDirectoryAnimationStart:(NSIndexPath *)indexPath;

- (UITextField *)textFieldNormalForWidth:(CGFloat)width;


- (void)contextMenuActionForIndexPath:(NSIndexPath *)indexPath;
- (BOOL)deleteFileAction:(NSString *)filename;
- (void)renameFileStartActionForIndexPath:(NSIndexPath *)indexPath;
- (void)renameFileActionFrom:(NSString *)src to:(NSString *)dest;
- (void)newDirectoryAction:(NSString *)filename;
- (void)newFileAction:(NSString *)filename;

- (void)copyFileAction:(NSString *)filename;
- (void)cutFileAction:(NSString *)filename;
- (void)pasteFileAction;

- (void)newFileArrived:(NSNotification *) notification;

@end
