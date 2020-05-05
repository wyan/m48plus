//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "MyHTTPConnection.h"
#import "HTTPServer.h"
#import "HTTPResponse.h"
#import "DDRange.h"

// To fetch the files
#import "m48Filemanager.h"

@implementation MyHTTPConnection

/**
 * Returns whether or not the requested resource is browseable.
**/
- (BOOL)isBrowseable:(NSString *)path
{
	// Override me to provide custom configuration...
	// You can configure it for the entire server, or based on the current request
	
	return YES;
}

/**
 * This method creates a html browseable page.
 * Customize to fit your needs
**/
- (NSString *)createBrowseableIndex:(NSString *)path {
    NSMutableString * outdata = [NSMutableString stringWithCapacity:0];
	NSStringEncoding enc;
	NSString * sourceFile = [m48Filemanager absoluteDocumentsPathForFile:@".AppResources/m48plus_fileserver.html"];
	[outdata appendString:[NSString stringWithContentsOfFile:sourceFile usedEncoding:&enc error:NULL]];
	
	NSArray * filelist = [m48Filemanager readDocumentsDirectory:path];
	
	NSMutableString * tableString = [NSMutableString stringWithCapacity:0];
	
	NSString * dispPath = path;
	if ([dispPath hasSuffix:@"/"] == NO) {
		dispPath = [dispPath stringByAppendingString:@"/"];
	}
	
	[tableString appendString:@"<tr><th colspan=\"2\">"];
	[tableString appendString:dispPath];
	[tableString appendString:@"</th></tr>\n"];
	
	for (int i=0; i < [filelist count]; i++) {
		NSDictionary * tempDict = [filelist objectAtIndex:i];
		NSString * link = [path stringByAppendingPathComponent:[tempDict objectForKey:kFilenameKey]];
		[tableString appendString:@"<tr><td class=\"fileTableRowLeftCol\">"];
		[tableString appendFormat:@"<a href=\"%@\">", link];
		[tableString appendFormat:@"<img src=\"/%@\" />", [tempDict objectForKey:kIconImageFilename]];
		[tableString appendString:@"</a></td><td class=\"fileTableRowRightCol\">"];
		[tableString appendFormat:@"<a href=\"%@\"><font class=\"mainLabel\">", link];
		[tableString appendString:[tempDict objectForKey:kFilenameKey]];
		[tableString appendFormat:@"</font></a>"];
		NSString * modDate = [tempDict objectForKey:kModificationDateKey];
		if (modDate != nil) { // For directories we havent set that
			[tableString appendString:@"<br /><font class=\"detailLabel\">"];
			[tableString appendString:modDate];
			NSString * fileSize = [tempDict objectForKey:kFileSizeKey];
			if ((fileSize != nil) && ([fileSize length] > 0)) {
				[tableString appendFormat:@" | %@", fileSize];
			}
			[tableString appendString:@"</font>"];
		}

		
		[tableString appendString:@"</td></tr>\n"];
	}

	
	if ([self supportsPOST:path withSize:0])
	{
		[tableString appendString:@"<tr><td class=\"fileTableRowBotom\" colspan=\"2\">"];
		
		[tableString appendString:@"<form action=\"\" method=\"post\" enctype=\"multipart/form-data\" name=\"form1\" id=\"form1\">"];
		[tableString appendString:@"<label>Upload File: "];
		[tableString appendString:@"<input type=\"file\" name=\"file\" id=\"file\" />"];
		[tableString appendString:@"</label>"];
		[tableString appendString:@"<label>"];
		[tableString appendString:@"<input type=\"submit\" name=\"button\" id=\"button\" value=\"Submit\" />"];
		[tableString appendString:@"</label></form>"];
		//[tableString appendString:@"<br /><font class=\"warningLabel\">WARNING: Existing files will be overwritten.</font>"];
		
		[tableString appendString:@"</th></tr>\n"];
	}
	
	
	[outdata replaceOccurrencesOfString:@"kInsertFileTableHere" withString:tableString options:0 range:NSMakeRange(0, [outdata length])];
    
	////DEBUG NSLog(@"outData: %@", outdata);
    return outdata;
}

- (NSString *) htmlEncodeUmlaute:(NSString *)string
{
	NSString *ret = [string stringByReplacingOccurrencesOfString:@"ä" withString:@"&auml;"];
	
	return ret;
}

/**
 * Returns whether or not the server will accept POSTs.
 * That is, whether the server will accept uploaded data for the given URI.
**/
- (BOOL)supportsPOST:(NSString *)path withSize:(UInt64)contentLength
{
//	//DEBUG NSLog(@"POST:%@", path);
	
	dataStartIndex = 0;
	multipartData = [[NSMutableArray alloc] init];
	postHeaderOK = FALSE;
	
	return YES;
}

- (NSDictionary *)dictFromUrlParams:(NSString *)path
{
	NSMutableDictionary *retMut = [[NSMutableDictionary alloc] init];
	
	NSURL *url = [NSURL URLWithString:path];
	
	NSArray *queryParts = [[url query] componentsSeparatedByString:@"&"];
	NSEnumerator *enu = [queryParts objectEnumerator];
	NSString *oneVar;
	
	while (oneVar = [enu nextObject])
	{
		NSArray *varParts = [oneVar componentsSeparatedByString:@"="];
		
		if ([varParts count]==2)
		{
			NSString *paramName = [varParts objectAtIndex:0];
			NSString *paramValue = [varParts objectAtIndex:1];
			
			[retMut setObject:paramValue forKey:paramName];
		}
	}
	
	NSDictionary *ret = [NSDictionary dictionaryWithDictionary:retMut];
	[retMut release];
	
	return ret;
}


/**
 * This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResopnse is a wrapper for an NSData object, and may be used to send a custom response.
**/
- (NSObject<HTTPResponse> *)httpResponseForURI:(NSString *)path
{
//	//DEBUG NSLog(@"httpResponseForURI: %@", path);
	
	if (postContentLength > 0)		//process POST data
	{
		////DEBUG NSLog(@"processing post data: %i", postContentLength);
		
		NSString* postInfo = [[NSString alloc] initWithBytes:[[multipartData objectAtIndex:1] bytes] length:[[multipartData objectAtIndex:1] length] encoding:NSUTF8StringEncoding];
		NSArray* postInfoComponents = [postInfo componentsSeparatedByString:@"; filename="];
		postInfoComponents = [[postInfoComponents lastObject] componentsSeparatedByString:@"\""];
		postInfoComponents = [[postInfoComponents objectAtIndex:1] componentsSeparatedByString:@"\\"];
		NSString* filename = [postInfoComponents lastObject];
		
		if ((filename != nil) && ![filename isEqualToString:@""]) //this makes sure we did not submitted upload form without selecting file
		{
			UInt16 separatorBytes = 0x0A0D;
			NSMutableData* separatorData = [NSMutableData dataWithBytes:&separatorBytes length:2];
			[separatorData appendData:[multipartData objectAtIndex:0]];
			int l = [separatorData length];
			int count = 2;	//number of times the separator shows up at the end of file data
			
			NSFileHandle* dataToTrim = [multipartData lastObject];
			
			for (unsigned long long i = [dataToTrim offsetInFile] - l; i > 0; i--)
			{
				[dataToTrim seekToFileOffset:i];
				if ([[dataToTrim readDataOfLength:l] isEqualToData:separatorData])
				{
					[dataToTrim truncateFileAtOffset:i];
					i -= l;
					if (--count == 0) break;
				}
			}
			
			////DEBUG NSLog(@"NewFileUploaded");
			NSDictionary *tmpDict = [NSDictionary dictionaryWithObject:filename forKey:@"FileName"];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"NewFileUploaded" object:nil userInfo:tmpDict];
		}
		
		[postInfo release];
		[multipartData release];
		postContentLength = 0;
		
	}
	
	NSString *filePath = [self filePathForURI:path];
	
	BOOL isDirectory = NO;
	BOOL fileExists = NO;
	fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
	
	if(fileExists && !isDirectory)
	{
		return [[[HTTPFileResponse alloc] initWithFilePath:filePath] autorelease];
	}
	else
	{	
		NSString *folder = [path isEqualToString:@"/"] ? [[server documentRoot] path] : [NSString stringWithFormat: @"%@%@", [[server documentRoot] path], path];
		if ([self isBrowseable:folder])
		{
			////DEBUG NSLog(@"folder: %@", folder);
			NSData *browseData = [[self createBrowseableIndex:path] dataUsingEncoding:NSUTF8StringEncoding];
			return [[[HTTPDataResponse alloc] initWithData:browseData] autorelease];
		} 
	}
	
	return nil;
}

/**
 * This method is called to handle data read from a POST.
 * The given data is part of the POST body.
**/
- (void)processPostDataChunk:(NSData *)postDataChunk
{
	// Override me to do something useful with a POST.
	// If the post is small, such as a simple form, you may want to simply append the data to the request.
	// If the post is big, such as a file upload, you may want to store the file to disk.
	// 
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	////DEBUG NSLog(@"processPostDataChunk");
	
	if (!postHeaderOK)
	{
		UInt16 separatorBytes = 0x0A0D;
		NSData* separatorData = [NSData dataWithBytes:&separatorBytes length:2];
		
		int l = [separatorData length];
		for (int i = 0; i < [postDataChunk length] - l; i++)
		{
			NSRange searchRange = {i, l};
			if ([[postDataChunk subdataWithRange:searchRange] isEqualToData:separatorData])
			{
				NSRange newDataRange = {dataStartIndex, i - dataStartIndex};
				dataStartIndex = i + l;
				i += l - 1;
				NSData *newData = [postDataChunk subdataWithRange:newDataRange];
				if ([newData length])
				{
					[multipartData addObject:newData];
					
				}
				else
				{
					postHeaderOK = TRUE;
					
					NSString* postInfo = [[NSString alloc] initWithBytes:[[multipartData objectAtIndex:1] bytes] length:[[multipartData objectAtIndex:1] length] encoding:NSUTF8StringEncoding];
					NSArray* postInfoComponents = [postInfo componentsSeparatedByString:@"; filename="];
					postInfoComponents = [[postInfoComponents lastObject] componentsSeparatedByString:@"\""];
					postInfoComponents = [[postInfoComponents objectAtIndex:1] componentsSeparatedByString:@"\\"];
					
					NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
					//httpResponse = [[self httpResponseForURI:[uri relativeString]] retain];
					NSString* filename = [[[server documentRoot] path] stringByAppendingPathComponent:[uri relativeString]];
					filename = [filename stringByAppendingPathComponent:[postInfoComponents lastObject]];
		
					NSString * extension = [filename pathExtension];
					NSString * newFilename = filename;
					NSFileManager * filemanager = [NSFileManager defaultManager];
					i = 1;
					while (([filemanager fileExistsAtPath:newFilename] == YES) && (i < 100)) {
						newFilename = [filename stringByDeletingPathExtension];
						newFilename = [newFilename stringByAppendingString:[NSString stringWithFormat:@" %d", i++]];
						if ([extension length] > 0) {
							newFilename = [newFilename stringByAppendingPathExtension:extension];
						}
					}
					filename = newFilename;
					
					NSRange fileDataRange = {dataStartIndex, [postDataChunk length] - dataStartIndex};
					
					[filemanager createFileAtPath:filename contents:[postDataChunk subdataWithRange:fileDataRange] attributes:nil];
					NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:filename];
					if (file)
					{
						[file seekToEndOfFile];
						[multipartData addObject:file];
					}
					
					[postInfo release];
					
					break;
				}
			}
		}
	}
	else
	{
		[(NSFileHandle*)[multipartData lastObject] writeData:postDataChunk];
	}
}


@end
