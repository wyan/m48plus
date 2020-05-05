/*
 *  m48Filemanager.m
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

#import "m48Filemanager.h"
#import "m48Errors.h"
#import "ZipArchive.h"
#import "patchwince.h"
#import "xml.h"
#import "m48ModalAlertView.h"
#import "m48ModalActionSheet.h"
#import "m48MenuHTMLContent.h"
#import "m48FilemanagerTableViewCell.h"
#import "m48Emulator.h"


NSString * const kFilenameKey = @"kFilenameKey";
NSString * const kModificationDateKey = @"kModificationDateKey";
NSString * const kFileSizeKey = @"kFileSizeKey";
NSString * const kIconImageFilename = @"kIconImageFilename";

static NSString * const kTitleKey = @"kTitleKey";
static NSString * const kIsDirectoryKey = @"kIsDirectoryKey";

static NSString * const kImagesExtensions = @"kImagesExtensions";
static NSString * const kImagesExtensionsGeneralFile = @"kImagesExtensionsGeneralFile";
static NSString * const kImagesExtensionsDirectory = @"kImagesExtensionsDirectory";
static NSString * const kImagesExtensionsDirectoryUp = @"kImagesExtensionsDirectoryUp";
static NSString * const kImagesImageResourceName = @"kImagesImageResourceName";
static NSString * const kImagesImage = @"kImagesImage";
static NSString * const kImagesImageResourcePath = @".AppResources/";

static NSString * const kFilenameUpDir = @"..";
static NSString * const kFilenameNewFile = @"<New File>";
static NSString * const kFilenameNewDirectory = @"<New Directory>";
static NSString * const kFilenameCopyItem = @"--> Copy Item Here";
static NSString * const kFilenameMoveItem = @"--> Move Item Here";

static const NSInteger kTextfieldTag = 1;

@implementation m48Filemanager

@synthesize contentList = _contentList;
@synthesize currentDirectory = _currentDirectory;
@synthesize baseDirectory = _baseDirectory;
@synthesize filemanager = _filemanager;
@synthesize mode = _mode;
@synthesize extensionFilters = _extensionFilters;
@synthesize selectedExtensionFilter = _selectedExtensionFilter;
@synthesize displayableContents = _displayableContents;

@synthesize images = _images;
@synthesize toolbarLabel = _toolbarLabel;

@synthesize copyItem = _copyItem;
@synthesize isCutItem = _isCutItem;

@synthesize trackDirectory = _trackDirectory;

//@synthesize textFieldNewFile = _textFieldNewFile;
- (UITextField *) textFieldNewFile {
    return _textFieldNewFile;
}
- (void) setTextFieldNewFile:(UITextField *)textField {
    [_textFieldNewFile resignFirstResponder];
    [_textFieldNewFile release];
    [textField retain];
    _textFieldNewFile = textField;
}

//@synthesize textFieldNewDirectory = _textFieldNewDirectory;
- (UITextField *) textFieldNewDirectory {
    return _textFieldNewDirectory;
}
- (void) setTextFieldNewDirectory:(UITextField *)textField {
    [_textFieldNewDirectory resignFirstResponder];
    [_textFieldNewDirectory release];
    [textField retain];
    _textFieldNewDirectory = textField;
}

//@synthesize textFieldRename = _textFieldRename;
- (UITextField *) textFieldRename {
    return _textFieldRename;
}
- (void) setTextFieldRename:(UITextField *)textField {
    [_textFieldRename resignFirstResponder];
    [_textFieldRename release];
    [textField retain];
    _textFieldRename = textField;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_copyItem release];
	[_displayableContents release];
	self.textFieldNewFile = nil;
	self.textFieldNewDirectory = nil;
    self.textFieldRename = nil;
	[_toolbarLabel release];
	[_images release];
	[_contentList release];
	[_filemanager release];
	[_currentDirectory release];
	[_baseDirectory release];
	[_extensionFilters release];
	[_selectedExtensionFilter release];
    [super dealloc];
}

+ (BOOL)unpackApplicationDocumentsWithError:(NSError **)error {
	m48Filemanager * aFilemanager = [[m48Filemanager alloc] init];
	
	NSString * appDir = [[NSBundle mainBundle] resourcePath];
	NSString * baseDir = [aFilemanager absoluteBaseDirectory];
	if (error != NULL) {
		*error = nil;
	}

	// Try minizip
	ZipArchive * zipArchive = [[ZipArchive alloc] init];
	if (![zipArchive UnzipOpenFile:[appDir stringByAppendingPathComponent:@"Archiv.zip"]]) goto failure;
    if (![zipArchive UnzipFileTo:baseDir overWrite:YES addSkipBackupAttributeToItems:YES]) goto failure;
	if (![zipArchive UnzipCloseFile]) goto failure;
	
	[zipArchive release];
	[aFilemanager release];
	return YES;
	
failure:
	[zipArchive release];
	[aFilemanager release];
	if (error != NULL) {
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Not enough memory to extract default data structure.", NSLocalizedDescriptionKey, nil]];
	}
	return NO;
}

+ (BOOL)unzipFile:(NSString *)src to:(NSString *)dest isDirectory:(BOOL)isDirectory doOverwrite:(BOOL)doOverwrite doDeleteSource:(BOOL)doDeleteSource withError:(NSError **)error {
	BOOL isDir;
	m48Filemanager * aFilemanager = [[m48Filemanager alloc] init];
	
	if (error != NULL) {
		*error = nil;
	}
	NSString * dest2;	
	if (isDirectory) {
		dest2 = dest;
	}
	else {
		dest2 = [dest stringByDeletingLastPathComponent];
	}
	
	if (![aFilemanager.filemanager fileExistsAtPath:dest2 isDirectory:&isDir]) {
		if(![aFilemanager.filemanager createDirectoryAtPath:dest2 withIntermediateDirectories:YES attributes:nil error:error]) goto failure;
	}
	else if (!isDir) {
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:nil];
		goto failure;
	}
	
	// Minizip
	ZipArchive * zipArchive = [[ZipArchive alloc] init];
	if (![zipArchive UnzipOpenFile:src]) goto failure;
    NSString * tempString = [[UIDevice currentDevice] systemVersion];
    tempString = [tempString substringToIndex:1];
	if (![zipArchive UnzipFileTo:dest2 overWrite:doOverwrite addSkipBackupAttributeToItems:YES]) goto failure;
	if (![zipArchive UnzipCloseFile]) goto failure;
	
	if (!isDirectory) {
		// Rename
		dest2 = [dest2 stringByAppendingPathComponent:[src lastPathComponent]];
		dest2 = [dest2 stringByDeletingPathExtension];
		if ([aFilemanager.filemanager fileExistsAtPath:dest]) {
			if (doOverwrite) {
				if (![aFilemanager.filemanager removeItemAtPath:dest error:error]) goto failure;
			}
			else {
				*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:nil];
				goto failure;
			}
				
		}
		if (![aFilemanager.filemanager moveItemAtPath:dest2 toPath:dest error:error]) goto failure;
	}
	
	if (doDeleteSource)
		if(![aFilemanager.filemanager removeItemAtPath:src error:error]) goto failure;
	
	[zipArchive release];
	[aFilemanager release];
	return YES;
	
failure:
	[zipArchive release];
	[aFilemanager release];
	if (*error != nil) {
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Not enough memory to extract data structure.", NSLocalizedDescriptionKey, nil]];
	}
	return NO;
}

+ (BOOL)migrateFromVersion:(NSString *)oldVersion toVersion:(NSString *)newVersion {
	m48Filemanager * aFilemanager = [[m48Filemanager alloc] init];
	// Later we can check from where to where is upgraded, for now we leav it just like that
#ifndef VERSIONPLUS	
	
	if ([newVersion isEqual:@"1.1"]) {
		
		NSString * filenameOld = getFullDocumentsPathForFile(@"data");
		NSString * filenameNew = getFullDocumentsPathForFile(@".state.m48");
		if ([aFilemanager.filemanager fileExistsAtPath:filenameOld]) {
			NSMutableData * srcdata = [NSMutableData dataWithContentsOfFile:filenameOld];
			
			char * dxml = "Skins/HP48GX/m48_StarshipLight_48gx.xml";
			DWORD nLength = strlen(dxml);
			
			NSMutableData * trgdata = [NSMutableData dataWithCapacity:0];
			[trgdata appendBytes:"m48 Document 1\xFE" length:16];
			[trgdata appendBytes:&nLength length:sizeof(nLength)];
			[trgdata appendBytes:dxml length:nLength];
			
			nLength = [srcdata length];
			NSRange range;
			range.location = 31;
			range.length = nLength - range.location;
			
			[trgdata appendData:[srcdata subdataWithRange:range]];

			WORD x = 0;
			[trgdata appendBytes:&x length:2];
			[trgdata writeToFile:filenameNew atomically:YES];
		}
	}
	else if ([newVersion isEqual:@"1.2"]) {
		NSString * filenameOld;
		if ([oldVersion isEqual:@"1.0"]) {
			filenameOld = getFullDocumentsPathForFile(@"data");
		}
		else if ([oldVersion isEqual:@"1.1"]) {
			filenameOld = getFullDocumentsPathForFile(@".state.m48");
		}
		else {
			goto ende;
		}
		NSString * filenameNew = getFullDocumentsPathForFile((NSString *) kUnsavedFileFilename);
		if ([aFilemanager.filemanager fileExistsAtPath:filenameOld]) {
			
			NSMutableData * srcdata = [NSMutableData dataWithContentsOfFile:filenameOld];
			
			char * dxml = "Skins/HP48G/m48_DontPanicLE_48g.xml";
			DWORD nLength = strlen(dxml);
			
			NSMutableData * trgdata = [NSMutableData dataWithCapacity:0];
			[trgdata appendBytes:"m48 Document 1\xFE" length:16];
			[trgdata appendBytes:&nLength length:sizeof(nLength)];
			[trgdata appendBytes:dxml length:nLength];
			
			nLength = [srcdata length];
			const char * rawdata = [srcdata bytes];
			
			NSRange range;
			for (int i=0; i < (nLength-3); i++) {
				if ((rawdata[i] == 'x') && (rawdata[i+1] == 'm') && (rawdata[i+2] == 'l')) {
					range.location = i + 3;
					break;
				}
			}
			range.length = nLength - range.location;
			
			[trgdata appendData:[srcdata subdataWithRange:range]];
			
			WORD x = 0;
			[trgdata appendBytes:&x length:2];
			[trgdata writeToFile:filenameNew atomically:YES];
			
			[aFilemanager.filemanager removeItemAtPath:filenameOld error:NULL];
			[[NSUserDefaults standardUserDefaults] setObject:@"/" forKey:@"internalCurrentDocumentDirectory"];
			[[NSUserDefaults standardUserDefaults] setObject:kUnsavedFileFilename forKey:@"internalCurrentDocumentFilename"];
		}
		// Save ROM
		filenameOld = getFullDocumentsPathForFile(@"/ROMs/HP48GX/rom.48g");
		filenameNew = getFullDocumentsPathForFile(@"/ROMs/HP48G/rom.48g");
		if ([aFilemanager.filemanager fileExistsAtPath:filenameOld]) {
			[aFilemanager.filemanager moveItemAtPath:filenameOld toPath:filenameNew error:NULL];
		}
		// Cleanup
		[aFilemanager.filemanager removeItemAtPath:@"ROMs/HP48GX" error:NULL];
		[aFilemanager.filemanager removeItemAtPath:@"Skins/HP48GX" error:NULL];
	}
#endif
	
ende:
	[aFilemanager release];
	return YES;
}

+ (NSString *)absoluteHomeDirectory {
	return NSHomeDirectory();
}

+ (NSString *)absoluteDocumentsPathForFile:(NSString *)filename {
	NSMutableString * aString = [NSMutableString stringWithCapacity:0];
	[aString appendString:NSHomeDirectory()];
	[aString appendString:@"/Documents/"];
	[aString appendString:filename];
	return [aString stringByStandardizingPath];
}

+ (NSArray *)readDocumentsDirectory:(NSString *)directory {
	
	
	NSString * absoluteDirectory = [m48Filemanager absoluteDocumentsPathForFile:directory];
	
	
	
	NSFileManager * filemanager = [NSFileManager defaultManager];
	
	BOOL isDir = NO;
	if ([filemanager fileExistsAtPath:absoluteDirectory isDirectory:&isDir] == NO) {
		return NO;
	}
	
	if (isDir == NO) {
		return NO;
	}
	
	NSMutableArray * icons = [m48Filemanager iconImageList];
	NSArray * content = [filemanager contentsOfDirectoryAtPath:absoluteDirectory error:NULL];
	
	// Assemble all necessary information
	NSMutableArray * list = [NSMutableArray arrayWithCapacity:0];
	NSDictionary * tempDict = nil;
	
	NSString * tempString = nil;

	// If not baseDirectory, we want an dirUp
	if (([directory isEqual:@""] == NO) && ([directory isEqual:@"/"] == NO)) {
		tempDict = (NSDictionary *) [m48Filemanager searchIconImageList:icons forExtension:kImagesExtensionsDirectoryUp];
		tempString = [kImagesImageResourcePath stringByAppendingPathComponent:[tempDict objectForKey:kImagesImageResourceName]];
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:@"..",kFilenameKey,tempString,kIconImageFilename,nil];
		[list addObject:tempDict];
	}
	
	for (int i=0; i < [content count]; i++) {
		NSString * filename = [content objectAtIndex:i];		
		tempDict = [filemanager attributesOfItemAtPath:[absoluteDirectory stringByAppendingPathComponent:filename] error:NULL];
		
		//filename = [filename lastPathComponent];
		if (([filename hasPrefix:@"."] == YES) || ([filename isEqual:@"__MACOSX"] == YES)) {
			continue;
		}
		
		BOOL isDirectory = [tempDict objectForKey:NSFileType] == NSFileTypeDirectory;
		NSNumber * fileSize = nil;
		NSString * fileSizeString = nil;
		NSDate * modificationDate = nil;
		NSString * modificationDateString = nil;
		
		fileSize = [tempDict objectForKey:NSFileSize];
		modificationDate = [tempDict objectForKey:NSFileModificationDate];
		NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
		modificationDateString = [formatter stringFromDate:modificationDate];
		
		
		if (isDirectory == NO) {
			float f =  [fileSize floatValue];
			int i = 0;
			while (f/1024 > 1.0) {
				f = f / 1024;
				i++;
			}
			fileSizeString = [NSString stringWithFormat:@"%.1f", f];
			if (i==0) {
				fileSizeString = [fileSizeString stringByAppendingString:@" B"];
			}
			else if (i==1) {
				fileSizeString = [fileSizeString stringByAppendingString:@" kB"];
			}
			else if (i==2) {
				fileSizeString = [fileSizeString stringByAppendingString:@" MB"];
			}
			else if (i==3) {
				fileSizeString = [fileSizeString stringByAppendingString:@" GB"];
			}
			else if (i==4) {
				fileSizeString = [fileSizeString stringByAppendingString:@" TB"];
			}
			else {
				fileSizeString = [fileSizeString stringByAppendingString:@" Error"];
			}
			tempDict = (NSDictionary *) [m48Filemanager searchIconImageList:icons forExtension:[filename pathExtension]];
		}
		else {
			fileSizeString = @"";
			tempDict = (NSDictionary *) [m48Filemanager searchIconImageList:icons forExtension:kImagesExtensionsDirectory];
		}
		
		tempString = [kImagesImageResourcePath stringByAppendingPathComponent:[tempDict objectForKey:kImagesImageResourceName]];
        tempString = [tempString stringByReplacingOccurrencesOfString:@"@2x" withString:@""];
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:filename,kFilenameKey,tempString,kIconImageFilename,fileSizeString,kFileSizeKey,modificationDateString,kModificationDateKey,nil];
		[list addObject:tempDict];
	}
	
	return list;
}

+ (NSMutableArray *)iconImageList {
	NSMutableArray * images = [NSMutableArray arrayWithCapacity:0];
	
	NSMutableDictionary * tempDict;
	NSMutableArray * tempArray;
	
	// General File // MUST BE FIRST IN COLLECTION!!!
	tempArray = [NSArray arrayWithObjects:kImagesExtensionsGeneralFile, nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"File_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// Directory
	tempArray = [NSArray arrayWithObjects:kImagesExtensionsDirectory, nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"Folder_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// DirectoryUp
	tempArray = [NSArray arrayWithObjects:kImagesExtensionsDirectoryUp, nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"FolderUp_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// png-Files
	tempArray = [NSArray arrayWithObjects:@"PNG", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"png_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// xml
	tempArray = [NSArray arrayWithObjects:@"XML", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"xml_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// ROMs
	tempArray = [NSArray arrayWithObjects:@"38G", @"39G", @"40G", @"48S", @"48G", @"49G", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"rom_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// m48
	tempArray = [NSArray arrayWithObjects:@"M48", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"m48_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// lib
	tempArray = [NSArray arrayWithObjects:@"LIB", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"lib_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// obj
	tempArray = [NSArray arrayWithObjects:@"OBJ", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"obj_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// hp
	tempArray = [NSArray arrayWithObjects:@"HP", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"hp_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// html
	tempArray = [NSArray arrayWithObjects:@"HTML", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"html_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	// wav
	tempArray = [NSArray arrayWithObjects:@"WAV", nil];
	tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:tempArray, kImagesExtensions, @"wav_32x32_72dpi.png", kImagesImageResourceName, nil];
	[images addObject:tempDict];
	
	return images;
}

+ (NSMutableDictionary *)searchIconImageList:(NSArray *)list forExtension:(NSString *)extension {
	// Find the appropriate Image
	NSString * searchKey = nil;
	if (([extension isEqual:kImagesExtensionsDirectoryUp] == NO) && ([extension isEqual:kImagesExtensionsDirectory] == NO)) {
		searchKey = [extension uppercaseString];
	}
	else {
		searchKey = extension;
	}
	
	NSEnumerator * enumerator = [list objectEnumerator];
	NSMutableDictionary * anObject;
	BOOL found = NO;
	while (anObject = [enumerator nextObject]) {
		// We must go through each of its keys
		NSArray * keys = [anObject objectForKey:kImagesExtensions];
		NSEnumerator * enumerator2 = [keys objectEnumerator];
		NSString * anObject2;
		while (anObject2 = [enumerator2 nextObject]) {
			if ([anObject2 isEqual:searchKey]) {
				found = YES;
				break;
			}
		}
		if (found) {
			break;
		}
	}
	if (!found) {
		// Use first entry (thats why kImagesExtensionsGeneralFile must be first in the array)
		anObject = [list objectAtIndex:0];
	}
	return anObject;
}


- (id)init {
	if ((self=[super init])) {
		//[self setCurrentDirectory:NSHomeDirectory()];
		[self setBaseDirectory:@"Documents/"];
		[self setCurrentDirectory:_baseDirectory];
		self.filemanager = [NSFileManager defaultManager];
		_extensionFilters = nil;
		_selectedExtensionFilter = nil;
		_trackDirectory = NO;
        
		// Init imagelist;
		self.images = [m48Filemanager iconImageList];
		
		// UPPERCASE ONLY PATH EXTENSION
		self.displayableContents = [NSArray arrayWithObjects:@"TXT",@"HTML",@"H",@"C",@"M",@"XML",@"RTF",@"PNG",@"JPG",@"JPEG",@"BMP",@"PNG",@"GIF",@"WAV",nil];
		
		
		self.copyItem = nil;
	}
	return self;	
}	

- (void)setTarget:(id)target filterAction:(SEL)filterAction selectAction:(SEL)selectAction {
	_target = target;
	_selectAction = selectAction;
	_filterAction = filterAction;
}


- (void)readCurrentDirectory {
	NSDictionary *tempDict;
	NSNumber * numberNO = [NSNumber numberWithBool:NO];
	NSNumber * numberYES = [NSNumber numberWithBool:YES];
	BOOL isDirectory;
	
	NSArray * tempArray = [[NSFileManager defaultManager] directoryContentsAtPath:[self absoluteCurrentDirectory]];
    if (_trackDirectory) {
        [[NSUserDefaults standardUserDefaults] setObject:self.currentDirectory forKey:@"internalCurrentFilemanagerDirectory"];
    }
    
    self.contentList = [NSMutableArray arrayWithCapacity:[tempArray count]];
	
	if ([[_currentDirectory pathComponents] count] > 0) {
		// Need ".."
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:kFilenameUpDir,kFilenameKey,numberYES,kIsDirectoryKey,nil];
		[_contentList addObject:tempDict];
	}
	
	for (int i=0; i<[tempArray count]; i++) {		
		NSString * tempString = [tempArray objectAtIndex:i];
		NSString * tempString2;
		
		NSString * filename = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:tempString];
		
		// Get attributes
		// old: [_filemanager fileExistsAtPath:filename isDirectory:&isDirectory];
		NSDictionary * dict = [_filemanager attributesOfItemAtPath:filename error:NULL];
		NSNumber * fileSize = [dict objectForKey:@"NSFileSize"];
		NSDate * modificationDate = [dict objectForKey:@"NSFileModificationDate"];
		NSString * fileType = [dict objectForKey:@"NSFileType"];
		isDirectory = [fileType isEqual:NSFileTypeDirectory];
		
		if (isDirectory) {
			if (([tempString isEqual:@"__MACOSX"] == NO) && ([tempString isEqual:@".AppResources"] == NO)) { // QuickFix
				tempDict = [NSDictionary dictionaryWithObjectsAndKeys:tempString,kFilenameKey,numberYES,kIsDirectoryKey,modificationDate,kModificationDateKey,fileSize,kFileSizeKey,nil];
				[_contentList addObject:tempDict];
			}
		}
		else if (_extensionFilters != nil) {
			NSString * a = [tempString pathExtension];
			NSString * b = [_selectedExtensionFilter pathExtension];
			a = [a uppercaseString];
			b = [b uppercaseString];
			if ([b isEqual:@"*"] || [a isEqual:b]) {
				if (_filterAction != nil) {
					if([_target performSelector:_filterAction withObject:filename withObject:(id)&tempString2]) {
						tempDict = [NSDictionary dictionaryWithObjectsAndKeys:tempString,kFilenameKey,tempString2,kTitleKey,numberNO,kIsDirectoryKey,modificationDate,kModificationDateKey,fileSize,kFileSizeKey,nil];
						[_contentList addObject:tempDict];
					}
				}
				else {
					if ([[tempString substringToIndex:1] isEqual:@"."] == NO) {
						tempDict = [NSDictionary dictionaryWithObjectsAndKeys:tempString,kFilenameKey,numberNO,kIsDirectoryKey,modificationDate,kModificationDateKey,fileSize,kFileSizeKey,nil];
						[_contentList addObject:tempDict];
					}
				}
			}
		} 
		else {
			if ([[tempString substringToIndex:1] isEqual:@"."] == NO) {
				tempDict = [NSDictionary dictionaryWithObjectsAndKeys:tempString,kFilenameKey,numberNO,kIsDirectoryKey,modificationDate,kModificationDateKey,fileSize,kFileSizeKey,nil];
				[_contentList addObject:tempDict];
			}
		}	
	}
	
	if (_mode == m48FilemanagerModeSaveAsDialog) {
		// Need kFilenameNewFile
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:kFilenameNewFile,kFilenameKey,numberNO,kIsDirectoryKey,nil];
		[_contentList addObject:tempDict];
	}
	
	if ((_mode == m48FilemanagerModeFilemanagerDialog) || (_mode == m48FilemanagerModeSaveAsDialog)) {
		// Need kFilenameNewFile
		tempDict = [NSDictionary dictionaryWithObjectsAndKeys:kFilenameNewDirectory,kFilenameKey,numberYES,kIsDirectoryKey,nil];
		[_contentList addObject:tempDict];
	}
	
	if (_copyItem != nil) {
		if ([_filemanager fileExistsAtPath:_copyItem isDirectory:&isDirectory]) {			
			if (_isCutItem) {
				tempDict = [NSDictionary dictionaryWithObjectsAndKeys:kFilenameMoveItem,kFilenameKey,(isDirectory?numberYES:numberNO),kIsDirectoryKey,nil];
				[_contentList addObject:tempDict];
			}
			else {
				tempDict = [NSDictionary dictionaryWithObjectsAndKeys:kFilenameCopyItem,kFilenameKey,(isDirectory?numberYES:numberNO),kIsDirectoryKey,nil];
				[_contentList addObject:tempDict];
			}
		}
	}
}

- (void)updateAnimated:(BOOL)animated {
	[self readCurrentDirectory];
	if (animated) {
		[self.tableView beginUpdates];
		[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];
	}
	else {
		[self.tableView reloadData];
	}
}

- (void)loadView {
	UITableView * tempView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStylePlain];
	[tempView setDataSource:self];
	[tempView setDelegate:self];
	[tempView setDelegate:self];
	[tempView setDataSource:self];
	[self setTableView:tempView];
	[tempView release];
	tempView = nil;
	
	[self readCurrentDirectory];
	
	/*
	if (self.mode == m48FilemanagerModeFilemanagerDialog) {
		self.navigationItem.rightBarButtonItem = [self editButtonItem];
	}
	else {
	 */
		UIBarButtonItem * barButtonItem = [UIBarButtonItem alloc];
		[barButtonItem initWithTitle:_selectedExtensionFilter style:UIBarButtonItemStyleBordered target:self action:@selector(changeExtensionFilterTargetAction)];
		self.navigationItem.rightBarButtonItem = barButtonItem;
		[barButtonItem release];
	/*
	}
	 */
}

//- (void)viewWillAppear:(BOOL)animated {
//	[self.navigationController setToolbarHidden:NO animated:NO];
//	[super viewWillAppear:animated];
//}


- (void)setToolbarLabelText {
	NSMutableString * tempString = [NSMutableString stringWithCapacity:0];
	if ([_currentDirectory hasPrefix:@"/"] == NO) {
		[tempString appendString:@"/"];
	}
	[tempString appendString:_currentDirectory];
	CGSize size = [tempString sizeWithFont:_toolbarLabel.font];
	NSRange range = {0,5};
	while  ((size.width > _toolbarLabel.bounds.size.width) && ([tempString length] > 6)) {
		[tempString replaceCharactersInRange:range  withString:@"..."];		
		size = [tempString sizeWithFont:_toolbarLabel.font];
	}
	if ([[tempString substringFromIndex:([tempString length] - 1)] isEqual:@"/"] == NO) {
		[tempString appendString:@"/"];
	}
	[_toolbarLabel setText:tempString]; 
}

- (void)setupToolbar {
	// Set up the labels
	CGRect bounds = self.navigationController.toolbar.bounds;
	UILabel * aToolbarLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width - 100, 30)];
	[aToolbarLabel setTextAlignment:UITextAlignmentCenter];
	//[aToolbarLabel setTextColor:[UIColor whiteColor]]; // No longer required for >= iOS7
	// [aToolbarLabel setBackgroundColor:[UIColor clearColor]]; // No longer required for >= iOS7
	[aToolbarLabel setFont:[aToolbarLabel.font fontWithSize:16]];
	self.toolbarLabel = aToolbarLabel;
	
	[self setToolbarLabelText];
	
	UIBarButtonItem * tempItem = [[UIBarButtonItem alloc] initWithCustomView:aToolbarLabel];
	
	[aToolbarLabel release];
	
	UIBarButtonItem * tempSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	NSArray * tempArray = [NSArray arrayWithObjects:tempSpace,tempItem,tempSpace,nil];
	
	[tempItem release];
	[tempSpace release];
	
	[self.navigationController.toolbar setItems:tempArray animated:NO];	
}

- (void)viewDidAppear:(BOOL)animated {
	// Make toolbar visible
	[self.navigationController setToolbarHidden:NO animated:animated];
	[self setupToolbar];
	// Listen to changes of the server
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newFileArrived:) name:@"NewFileUploaded" object:nil];
	[super viewDidAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated {
	[_textFieldNewFile resignFirstResponder];
	[_textFieldNewDirectory resignFirstResponder];
	[_textFieldRename resignFirstResponder];
	//[self.navigationController setToolbarHidden:YES animated:YES];
	// Stop listening
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewWillDisappear:animated];
}
	
	
- (void)changeExtensionFilterTargetAction {
	// Find current
	NSString * tempString;
	int i;
	for (i=0; i < [_extensionFilters count]; i++) {
		tempString = [_extensionFilters objectAtIndex:i];
		if ([tempString isEqual:_selectedExtensionFilter]) {
			break;
		}
	}
	if (i >= ([_extensionFilters count]-1)) {
		i = 0;
	}
	else {
		i++;
	}
	_selectedExtensionFilter = [_extensionFilters objectAtIndex:i];
	
	self.navigationItem.rightBarButtonItem.title = _selectedExtensionFilter;
	
	//[self readCurrentDirectory];
	//[self.tableView reloadData];
	
	[_textFieldNewFile resignFirstResponder];
	[_textFieldNewDirectory resignFirstResponder];
	[_textFieldRename resignFirstResponder];
	[self updateAnimated:YES];
	
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
	// Release anything that can be recreated in viewDidLoad or on demand.
	// e.g. self.myOutlet = nil;
}



#pragma mark -
#pragma mark Actions
- (void)contextMenuActionForIndexPath:(NSIndexPath *)indexPath {
	static m48ModalActionSheet * myActionSheet = nil;
	
	if (myActionSheet == nil) {
		//init
		myActionSheet = [[m48ModalActionSheet alloc] initBlank];
		[myActionSheet.buttonTexts addObject:@"Rename"];
		[myActionSheet.buttonTexts addObject:@"Copy"];
		[myActionSheet.buttonTexts addObject:@"Cut"];
		[myActionSheet.buttonTexts addObject:@"Delete"];
		myActionSheet.destructiveButtonIndex = 3;
		[myActionSheet.buttonTexts addObject:@"Cancel"];
		myActionSheet.cancelButtonIndex = 4;
		myActionSheet.target = self;
		myActionSheet.selector = @selector(contextMenuActionForIndexPath:);
		myActionSheet.optionalObject = indexPath;
	}
	
	NSDictionary * dict = [_contentList objectAtIndex:[indexPath row]];
	NSString * filename = [dict objectForKey:kFilenameKey];
	
	switch (myActionSheet.evolutionStage) {
		case 0:
			[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
			[myActionSheet showInView:self.view];
			return;
		case 1:
			
			if (myActionSheet.didDismissWithButtonIndex == 0) {
				// Rename
				[self renameFileStartActionForIndexPath:indexPath];
				[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
				goto ende;
			}
			else if (myActionSheet.didDismissWithButtonIndex == 1) {
				// Copy
				[self copyFileAction:filename];
				[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
				goto ende;
			}
			else if (myActionSheet.didDismissWithButtonIndex == 2) {
				// Cut
				[self cutFileAction:filename];
				[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
				goto ende;
			}
			else if (myActionSheet.didDismissWithButtonIndex == 3) {
				// Delete
				[self deleteFileAction:filename];
				goto ende;
			}
			else if (myActionSheet.didDismissWithButtonIndex == 4) {
				// Cancel
				[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
				goto ende;
			}
			
		default:
			break;
	}
	return;
	
ende:
	[myActionSheet release];
	myActionSheet = nil;
	return;
}

- (BOOL)deleteFileAction:(NSString *)filename {
	static m48ModalAlertView * myAlertView = nil;
	
	if (myAlertView == nil) {
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.target = self;
		myAlertView.selector = @selector(deleteFileAction:);
		myAlertView.optionalObject = filename;
		myAlertView.title = @"Warning";
		myAlertView.message = @"This directory contains content. Do you really want to delete it?";
		[myAlertView.buttonTexts addObject:@"Cancel"];
		[myAlertView.buttonTexts addObject:@"Delete"];
	}
	
	NSString * absoluteFile = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
	BOOL isDir;
	
	switch (myAlertView.evolutionStage) {
		case 0:
			// Check if directory
			[_filemanager fileExistsAtPath:absoluteFile isDirectory:&isDir];
			if (isDir) {
				NSArray * content = [_filemanager contentsOfDirectoryAtPath:absoluteFile error:NULL];
				if ([content count] != 0) {
					[myAlertView show];
					return NO;
				}
			}
			myAlertView.didDismissWithButtonIndex = 1;
		case 1:
			if (myAlertView.didDismissWithButtonIndex == 1) {
				NSError * error = nil;
				[_filemanager removeItemAtPath:absoluteFile error:&error];
				[self updateAnimated:YES];
			}
			[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
			break;
		default:
			break;
	}
	// Clean up
	[myAlertView release];
	myAlertView = nil;
	return YES;
}

- (void)renameFileStartActionForIndexPath:(NSIndexPath *)indexPath {
	// We need to change the cell and make it active
	UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
	NSDictionary * dict = [_contentList objectAtIndex:[indexPath row]];
	
	/*
	static NSString * CellIdentifierTextField = @"cellIdentifierTextField";
	UIImage * image = cell.imageView.image;
	[cell initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierTextField];
	[[cell imageView] setImage:image];
	[image release];
	*/
	
	UITextField * textField = [self textFieldNormalForWidth:cell.bounds.size.width];
	textField.placeholder = [dict objectForKey:kFilenameKey];
	textField.text = textField.placeholder;
	
	[_textFieldRename resignFirstResponder];
	[_textFieldRename removeFromSuperview];
	self.textFieldRename = textField;
	
	[cell.contentView addSubview:textField];
	cell.detailTextLabel.text = nil;
	[textField becomeFirstResponder];
	
	return;
}

- (void)renameFileActionFrom:(NSString *)src to:(NSString *)dest {

	// Rename
	if ([dest length] == 0) {
		goto ende;
	}
	else {
		// We need to find out if a file or directory with that filename already exists at that path
		NSString * absoluteTarget = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:dest];
		if (([_filemanager fileExistsAtPath:absoluteTarget isDirectory:NULL] == YES) &&
			([[src uppercaseString] isEqual:[dest uppercaseString]] == NO)) {
			m48ModalAlertView * myAlertView = [[m48ModalAlertView alloc] initForError];
			myAlertView.message = @"An item with this name already exists.";
			[myAlertView show];
			[myAlertView release];
			myAlertView = nil;
			return;
		}
		// Everything seems to be fine
		NSString * absoluteSource = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:src];
		if ([_filemanager moveItemAtPath:absoluteSource toPath:absoluteTarget error:NULL] == NO) {
			m48ModalAlertView * myAlertView = [[m48ModalAlertView alloc] initForError];
			myAlertView.message = @"Error renaming item.";
			[myAlertView show];
			[myAlertView release];
			myAlertView = nil;		
		}
	}
ende:
	[_textFieldRename resignFirstResponder];
	[_textFieldRename removeFromSuperview];
	self.textFieldRename = nil;
	[self updateAnimated:YES];
}

- (void)newDirectoryAction:(NSString *)filename {
	// the user pressed the "Done" button, so dismiss the keyboard
	static m48ModalAlertView * myAlertView = nil;
	
	if (myAlertView == nil) {
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.target = self;
		myAlertView.selector = @selector(newDirectoryAction:);
		myAlertView.optionalObject = filename;
	}
	
	if ([filename length] == 0) {
		goto ende;
	}
	
	// New Directory
	NSString * absoluteDirectory = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
	if ([_filemanager fileExistsAtPath:absoluteDirectory] == NO) {
		[_filemanager createDirectoryAtPath:absoluteDirectory attributes:nil];
	}
	else {
		myAlertView.title = @"Error!";
		myAlertView.message = @"A directory with this name already exists.";
		[myAlertView.buttonTexts addObject:@"OK"];
		myAlertView.target = nil;
		myAlertView.selector = nil;
		[myAlertView show];
	}
	
	[self updateAnimated:YES];
ende:
	[_textFieldNewDirectory resignFirstResponder];
	[myAlertView release];
	myAlertView = nil;
	return;
}

- (void)newFileAction:(NSString *)filename {
	static m48ModalAlertView * myAlertView = nil;
	
	if (myAlertView == nil) {
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.target = self;
		myAlertView.selector = @selector(newFileAction:);
		myAlertView.optionalObject = filename;
	}
	
	NSString * a = [_selectedExtensionFilter pathExtension];
	NSString * b = [filename pathExtension];
	
	// New File
	switch (myAlertView.evolutionStage) {
		case 0:
			if ([filename length] == 0) {
				goto ende;
			}
			else {
				// Lets find out, if the extension is similar to the selectedFilter.
				// There are the folloewing possibilities
				if (([a isEqual:@"*"] == YES) && (b != nil) && ([b length] > 0)) {
					// Case I: A path extension was entered. Thats ok, and the user won't be bothered
					myAlertView.didDismissWithButtonIndex = 0;
				}
				else if ((b == nil) || ([b length] == 0)) {
					// Case II: Lets suggest him another extension:
					if ([a isEqual:@"*"] == YES) {
						a = [_extensionFilters objectAtIndex:0];
						a = [a pathExtension];
					}
					myAlertView.title = nil;
					myAlertView.message = @"The entered filename has no file extension.";
					[myAlertView.buttonTexts addObject:@"That's OK"];
					[myAlertView.buttonTexts addObject:[@"Use ." stringByAppendingString:a]];
					[myAlertView show];
					return;
				}
				else if ((b != nil) && ([b length] > 0) && ([b isEqual:a] == NO)) {
					// Case III: Suggest him the currently selected extension
					myAlertView.title = nil;
					myAlertView.message = @"Would you like to use an alternative file extension?";
					[myAlertView.buttonTexts addObject:[@"No. Use ." stringByAppendingString:b]];
					[myAlertView.buttonTexts addObject:[@"Yes. Use ." stringByAppendingString:a]];
					[myAlertView show];
					return;
				}
				else {
					// Case IV:Nothing to be done
					myAlertView.didDismissWithButtonIndex = 0;
				}
			}
		case 1:
			if (myAlertView.didDismissWithButtonIndex == 1) {
				if ([a isEqual:@"*"] == YES) {
					a = [_extensionFilters objectAtIndex:0];
					a = [a pathExtension];
				}
				filename = [filename stringByDeletingPathExtension];
				filename = [filename stringByAppendingPathExtension:a];
			}
			[self selectedFileAction:filename];
			goto ende;	
			break;
		default:
			goto ende;	
			break;
	}
ende:
	[_textFieldNewFile resignFirstResponder];
	[myAlertView release];
	myAlertView = nil;
	return;
}
	

- (void)copyFileAction:(NSString *)filename {
	NSString * absoluteFile = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
	self.copyItem = absoluteFile;
	self.isCutItem = NO;
	[self updateAnimated:YES];
}

- (void)cutFileAction:(NSString *)filename {
	NSString * absoluteFile = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
	self.copyItem = absoluteFile;
	self.isCutItem = YES;
	[self updateAnimated:YES];
}

- (void)pasteFileAction {
	// Three cases
	// 1: Filename has no collission in the current directory
	// 2: Filename is equal to the filenam within the directoy -> Copy of
	// 3: Filename collides
	NSString * filename = [_copyItem lastPathComponent];
	NSString * target = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
	BOOL isDirectory;
	NSError * error = nil;
	m48ModalAlertView * myAlertView = [[m48ModalAlertView alloc] initForError];
	
	if ([_filemanager fileExistsAtPath:target isDirectory:&isDirectory] == YES) {
		if ([_copyItem isEqual:target] == YES) {
			if (_isCutItem) { // NOT WORKING YET!!!!
				// Do nothing
				self.copyItem = nil;
				[self updateAnimated:YES];
				goto ende;
			}
			filename = [@"Copy of " stringByAppendingString:filename];
			target = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:filename];
			
			// Copy
			if ([_filemanager copyItemAtPath:_copyItem toPath:target error:&error] == NO) {
				myAlertView.message = @"Could not copy item";
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
			}
			
			
			[self updateAnimated:YES];
		}
		else {
			// Here we need to ask, if we should overwrite the destination
			// TO BE DONE ... nice dialog with "should I overwrite, merge, blabla"
			
			// However for now, we just display an Error
			myAlertView.message = @"A file or directory with this name already exists at the current directory. Please remove it first.";
			[myAlertView show];
			[myAlertView release];
			myAlertView = nil;
			goto ende;
		}
	}
	else {
		// Check if _copyFile is substring of target
		NSRange range = [target rangeOfString:_copyItem];
		if ((range.location != NSNotFound) && (range.location == 0) && (range.length < [target length])) {
			myAlertView.message = @"Recursive copy is not possible.";
			[myAlertView show];
			[myAlertView release];
			myAlertView = nil;
			goto ende;
		}
		
		if (!_isCutItem) {
			if ([_filemanager copyItemAtPath:_copyItem toPath:target error:&error] == NO) {
				myAlertView.message = @"Could not copy item.";
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				goto ende;
			}
		}
		else {
			if ([_filemanager moveItemAtPath:_copyItem toPath:target error:&error] == NO) {
				myAlertView.message = @"Could not copy item.";
				[myAlertView show];
				[myAlertView release];
				myAlertView = nil;
				goto ende;
			}
			self.copyItem = nil;
		}
		[self updateAnimated:YES];
	}
	
ende:	
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark -
#pragma mark Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_contentList count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString * CellIdentifierDefault = @"cellIdentifierDefault"; 
	static NSString * CellIdentifierSubtitle = @"cellIdentifierSubtitle";  
	static NSString * CellIdentifierTextField = @"cellIdentifierTextField";
	NSDictionary * dictElem = [_contentList objectAtIndex:[indexPath row]];
	NSString * filename = [dictElem objectForKey:kFilenameKey];
	NSNumber * isDirectoryNumber = [dictElem objectForKey:kIsDirectoryKey];
	NSString * title = nil;
	NSNumber * fileSize = nil;
	NSDate * modificationDate = nil;
	
	if (_mode != m48FilemanagerModeFilemanagerDialog) {
		title = [dictElem objectForKey:kTitleKey];
	}
	else {
		fileSize = [dictElem objectForKey:kFileSizeKey];
		modificationDate = [dictElem objectForKey:kModificationDateKey];
		NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
		title = [formatter stringFromDate:modificationDate];
		if ([isDirectoryNumber boolValue] == NO) {
			title = [title stringByAppendingString:@" | "];
			float f =  [fileSize floatValue];
			int i = 0;
			while (f/1024 > 1.0) {
				f = f / 1024;
				i++;
			}
			title = [title stringByAppendingFormat:@"%.1f", f];
			if (i==0) {
				title = [title stringByAppendingString:@" B"];
			}
			else if (i==1) {
				title = [title stringByAppendingString:@" kB"];
			}
			else if (i==2) {
				title = [title stringByAppendingString:@" MB"];
			}
			else if (i==3) {
				title = [title stringByAppendingString:@" GB"];
			}
			else if (i==4) {
				title = [title stringByAppendingString:@" TB"];
			}
			else {
				title = [title stringByAppendingString:@" Error"];
			}
		}
	}
	
	
	
	// Lets evaluate what kind of cell we need
	BOOL isTextFieldCell = NO;
	BOOL isSubtitleCell = NO;
	if ([filename isEqual:kFilenameNewFile] || [filename isEqual:kFilenameNewDirectory]) {
		isTextFieldCell = YES;
	}
	else {
		if (_mode == m48FilemanagerModeFilemanagerDialog) {
			if (([filename isEqual:kFilenameCopyItem] == NO) && ([filename isEqual:kFilenameMoveItem] == NO) && ([filename isEqual:kFilenameUpDir] == NO)) {
				isSubtitleCell = YES;
			}
		}
		else if (title != nil) {
			isSubtitleCell = YES;
		}		
	}
	
	
	m48FilemanagerTableViewCell * cell;
	if (isTextFieldCell) {
		// Cell with a text field
		cell = (m48FilemanagerTableViewCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifierTextField];
		if (cell == nil) {
			cell = [[[m48FilemanagerTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierTextField] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.holdActionEnabled = NO;
		}
		else {
			// a cell is being recycled, remove the old edit field (if it contains one of our tagged edit fields)
			UIView *viewToCheck = nil;
			viewToCheck = [cell.contentView viewWithTag:kTextfieldTag];
			if (viewToCheck != nil) {
				[viewToCheck removeFromSuperview];
			}
		}
		
		CGFloat width = cell.bounds.size.width;
		UITextField * textField = [self textFieldNormalForWidth:width];
		
		[cell.contentView addSubview:textField];
		if ([filename isEqual:kFilenameNewFile]) {
            [_textFieldNewFile resignFirstResponder];
			self.textFieldNewFile = textField;
		}
		else {
            [_textFieldNewDirectory resignFirstResponder];
			self.textFieldNewDirectory = textField;
		}
	}
	else if (isSubtitleCell) {	
		cell = (m48FilemanagerTableViewCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifierSubtitle];
		if (cell == nil) {
			cell = [[[m48FilemanagerTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifierSubtitle] autorelease];
		}
		else {
			// a cell is being recycled, remove the old edit field (if it contains one of our tagged edit fields)
			UIView *viewToCheck = nil;
			viewToCheck = [cell.contentView viewWithTag:kTextfieldTag];
			if (viewToCheck != nil) {
				[viewToCheck removeFromSuperview];
			}
		}
	}
	else {	
		cell = (m48FilemanagerTableViewCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifierDefault];
		if (cell == nil) {
			cell = [[[m48FilemanagerTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifierDefault] autorelease];
		}
		else {
			// a cell is being recycled, remove the old edit field (if it contains one of our tagged edit fields)
			UIView *viewToCheck = nil;
			viewToCheck = [cell.contentView viewWithTag:kTextfieldTag];
			if (viewToCheck != nil) {
				[viewToCheck removeFromSuperview];
			}
		}
	}
    
	// Configure the cell.
    cell.root = self;
    cell.indexPath = indexPath;
    cell.tableView2 = tableView;
	if (!isTextFieldCell) {
		if (isSubtitleCell) {
			if (_mode != m48FilemanagerModeFilemanagerDialog) {
				[cell.textLabel setText:title];
				[cell.detailTextLabel setText:filename];
			}
			else {
				[cell.textLabel setText:filename];
				[cell.detailTextLabel setText:title];
			}
		}
		else  {	
			[cell.textLabel setText:filename];
		}
	}
	else {
		if ([filename isEqual:kFilenameNewFile]) {
			self.textFieldNewFile.placeholder = kFilenameNewFile;
		}
		else {
			self.textFieldNewDirectory.placeholder = kFilenameNewDirectory;
		}
	}

	if ((_mode == m48FilemanagerModeOpenDialog) || ([filename isEqual:kFilenameUpDir] == YES) || ([filename isEqual:kFilenameCopyItem] == YES) ||  ([filename isEqual:kFilenameMoveItem] == YES) || isTextFieldCell) {
		cell.holdActionEnabled = NO;
	}
	else {
		cell.holdActionEnabled = YES;
	}
	
	if (([filename isEqual:kFilenameCopyItem] == YES) || ([filename isEqual:kFilenameMoveItem] == YES)) {
		cell.textLabel.textColor = [UIColor grayColor];
		//cell.textLabel.font = [UIFont systemFontOfSize:cell.textLabel.font.pointSize];
	}
	else {
		cell.textLabel.textColor = [UIColor blackColor];
		//cell.textLabel.font = [UIFont boldSystemFontOfSize:cell.textLabel.font.pointSize];
	}
	
	// Find the appropriate Image
	NSString * searchKey = nil;
	if ((isDirectoryNumber != nil) && ([isDirectoryNumber boolValue] == YES)) {
		// Is Directory
		if ([filename isEqual:kFilenameUpDir]) {
			// Find the DirectoryUp
			searchKey = kImagesExtensionsDirectoryUp;
		}
		else {
			searchKey = kImagesExtensionsDirectory;
		}
	}
	else {
		searchKey = [[filename pathExtension] uppercaseString];
	}
	
	NSEnumerator * enumerator = [_images objectEnumerator];
	NSMutableDictionary * anObject;
	BOOL found = NO;
	while (anObject = [enumerator nextObject]) {
		// We must go through each of its keys
		NSArray * keys = [anObject objectForKey:kImagesExtensions];
		NSEnumerator * enumerator2 = [keys objectEnumerator];
		NSString * anObject2;
		while (anObject2 = [enumerator2 nextObject]) {
			if ([anObject2 isEqual:searchKey]) {
				found = YES;
				break;
			}
		}
		if (found) {
			break;
		}
	}
	if (!found) {
		// Use first entry (thats why kImagesExtensionsGeneralFile must be first in the array)
		anObject = [_images objectAtIndex:0];
	}
	
	if ([anObject objectForKey:kImagesImage] == nil) {
		// Lazy load
		UIImage * anImage = [UIImage imageNamed:[anObject objectForKey:kImagesImageResourceName]];
		[anObject setObject:anImage forKey:kImagesImage];
	}
	
    
	[[cell imageView] setImage:[anObject objectForKey:kImagesImage]];
	
	// Accessory type in filemanager mode
	if (_mode == m48FilemanagerModeFilemanagerDialog) {
		NSString * tempString = [filename pathExtension];
		tempString = [tempString uppercaseString];
		if (([filename isEqual:kFilenameNewFile] == NO) && ([filename isEqual:kFilenameNewDirectory] == NO)) {
			if (([isDirectoryNumber boolValue] == NO) && ([_displayableContents containsObject:tempString] == YES)) {
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			}
			else {
				cell.accessoryType = UITableViewCellAccessoryNone;
			}
		}
		else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		// Selection Style in Filemanager mode
		if (([filename isEqual:kFilenameNewFile] == NO) && ([filename isEqual:kFilenameNewDirectory] == NO)) {
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		} 
		else {
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
	}
	
	
	
    return cell;
}

- (void)changeDirectoryAnimationStart:(NSIndexPath *)indexPath {
	if (_blinkCounter == 0) {
		[self.tableView reloadData];
		[self setToolbarLabelText];
	}
	else {
		if (_blinkCounter%2) {
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
		}
		else {
			[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
		}
		// reschedule myself
		[self performSelector:@selector(changeDirectoryAnimationStart:) withObject:indexPath afterDelay:0.15];
		_blinkCounter--;
	}
}

// Override to support row selection in the table view.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	NSDictionary * dictElem = [_contentList objectAtIndex:[indexPath row]];
	//NSString * title = [dictElem objectForKey:kTitleKey];
	NSString * filename = [dictElem objectForKey:kFilenameKey];
	NSNumber * isDirectoryNumber = [dictElem objectForKey:kIsDirectoryKey];

	// Hide the Keyboard if necessarry
	[_textFieldNewFile resignFirstResponder];
	[_textFieldNewDirectory resignFirstResponder];
	[_textFieldRename resignFirstResponder];
	
	if (([filename isEqual:kFilenameNewFile] == YES) || ([filename isEqual:kFilenameNewDirectory] == YES)) {
		return;
	}
	
	m48FilemanagerTableViewCell * cell = (m48FilemanagerTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
	
	if (cell.isHoldAction == YES) {
		// Present Action sheet
		[self contextMenuActionForIndexPath:(NSIndexPath *)indexPath];
		return;
	}
	
	if (([filename isEqual:kFilenameCopyItem] == YES) || ([filename isEqual:kFilenameMoveItem] == YES)) {
		[self pasteFileAction];
		return;
	}
	
	if ([isDirectoryNumber boolValue] == YES) {
		// Present new dictionary
		/* Part 1 of animation: set data for next directory */
		// Check if ".." was selected
		if ([filename isEqual:kFilenameUpDir]) {
			self.currentDirectory = [_currentDirectory stringByDeletingLastPathComponent];
		}
		else {
			self.currentDirectory = [_currentDirectory stringByAppendingPathComponent:filename];
		}
		//self.currentDirectory = [_currentDirectory stringByStandardizingPath];
		[self readCurrentDirectory];
		_blinkCounter = 3;
		[self changeDirectoryAnimationStart:indexPath];

		return;
	}
	
	// Use the target action
	[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	
	// Perform action
	[self selectedFileAction:filename];


}



/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
	 if (self.mode == m48FilemanagerModeFilemanagerDialog) {
		 // .. and kFilenameNewDirectory is not possible
		 NSDictionary * dictElem = [_contentList objectAtIndex:[indexPath row]];
		 NSString * filename = [dictElem objectForKey:kFilenameKey];
		 if (([filename isEqual:kFilenameUpDir] == NO) && ([filename isEqual:kFilenameNewDirectory] == NO)) {
			 return YES;
		 }
		 else {
			 return NO;
		 }
	 }
	 else {
		 return NO;
	 }
 }
 */

/*
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleDelete;
}
*/

/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	// Delete this
	NSDictionary * dict = [_contentList objectAtIndex:[indexPath row]];
	NSString * filename = [dict objectForKey:kFilenameKey];
	[self deleteFileAction:filename];
	return;
}
*/

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(m48FilemanagerTableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
	 if (editingStyle == m48FilemanagerTableViewCellEditingStyleDelete) {
	 // Delete the row from the data source.
	 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	 }   
	 else if (editingStyle == m48FilemanagerTableViewCellEditingStyleInsert) {
	 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
	 }   
 }
*/ 


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */



#pragma mark -
#pragma mark helper functions
- (NSString *)absoluteBaseDirectory {
	return [NSHomeDirectory() stringByAppendingPathComponent:_baseDirectory];
}

- (NSString *)absoluteCurrentDirectory {
	return [[self absoluteBaseDirectory] stringByAppendingPathComponent:_currentDirectory];
}

#pragma mark -
#pragma mark Load file	
- (void)selectedFileAction:(NSString *)selectedFile {
	static m48ModalAlertView * myAlertView = nil;
	NSString * absoluteFile = [[self absoluteCurrentDirectory] stringByAppendingPathComponent:selectedFile];
	
	// Open Dialog or change xml 
	if ((_mode == m48FilemanagerModeOpenDialog) || (_mode == m48FilemanagerModeChooseXmlScriptDialog)) {
		[_target performSelector:_selectAction withObject:absoluteFile];
		return;
	}
	
	// Filemanager Dialog
	if (_mode == m48FilemanagerModeFilemanagerDialog) {
		if ([_displayableContents containsObject:[[selectedFile pathExtension] uppercaseString]] == YES) {
			m48MenuHTMLContent * webViewViewController = [[m48MenuHTMLContent alloc] initWithTitle:selectedFile filename:absoluteFile URL:nil];
			[self.navigationController pushViewController:webViewViewController animated:YES];
			[webViewViewController release];
		}
		return;
	}
	
	// Save as Dialog
	if (myAlertView == nil) {
		myAlertView = [[m48ModalAlertView alloc] initBlank];
		myAlertView.title = @"Warning";
		myAlertView.message = @"Do you really want to overwrite this file?";
		myAlertView.target = self;
		myAlertView.selector = @selector(selectedFileAction:);
		myAlertView.optionalObject = selectedFile;
		[myAlertView.buttonTexts addObject:@"Cancel"];
		[myAlertView.buttonTexts addObject:@"Confirm"];
	}
	
	switch (myAlertView.evolutionStage) {
		case 0:
			if ([self.filemanager fileExistsAtPath:absoluteFile] == YES) {
				[myAlertView show];
				return;
			}
			else {
				myAlertView.didDismissWithButtonIndex = 1;
			}
		case 1:
			if (myAlertView.didDismissWithButtonIndex == 1) {
				[_target performSelector:_selectAction withObject:absoluteFile];
			}
		default:
			[myAlertView release];
			myAlertView = nil;
			break;
	}
	
	
	return;
}

- (void)finishedSelectedFileActionWithSuccess:(BOOL)success {
	[_textFieldNewFile resignFirstResponder];
	[_textFieldNewDirectory resignFirstResponder];
	[_textFieldRename resignFirstResponder];
	[self updateAnimated:YES];
}

#pragma mark -
#pragma mark Delegate for UIAlertView
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	;
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
	;
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == _textFieldNewDirectory) {
		[self newDirectoryAction:textField.text];
	}
	else if (textField == _textFieldNewFile) {
		[self newFileAction:textField.text];
		
	}
	else {
		// Rename action
		[self renameFileActionFrom:textField.placeholder to:textField.text];
	}
	
	return YES;
}

#pragma mark -
#pragma mark Text Fields

- (UITextField *)textFieldNormalForWidth:(CGFloat)width
{
	UITextField * textField;
	CGRect frame =  self.view.bounds;
	frame.origin.x = 68;
	frame.origin.y = 6;
	frame.size.width = width - frame.origin.x - 10;
	frame.size.height = 30;
	textField = [[UITextField alloc] initWithFrame:frame];
	textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	textField.borderStyle = UITextBorderStyleBezel;
	//textField.textColor = [UIColor grayColor];
	textField.font = [UIFont systemFontOfSize:17.0];
	textField.placeholder = @"<Enter>";
	textField.backgroundColor = [UIColor whiteColor];
	textField.autocorrectionType = UITextAutocorrectionTypeNo;	
	textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	textField.returnKeyType = UIReturnKeyDefault;
	textField.keyboardType = UIKeyboardTypeDefault;
	
	textField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
	
	textField.tag = kTextfieldTag;		// tag this control so we can remove it later for recycled cells
	
	textField.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
	
	[textField autorelease];
	
	return textField;
}

#pragma mark Notifications
- (void)newFileArrived:(NSNotification *) notification
{
	if (notification)
	{
		[self updateAnimated:YES];
	}
}

		
@end

