/*
 *  m48SupportRequest.m
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

#import "m48SupportRequest.h"
#import "DDData.h"

#include <sys/types.h>  
#include <sys/sysctl.h>  

@implementation m48SupportRequest

+ (NSString *)generateText {
	NSMutableString * text = [NSMutableString stringWithCapacity:0];
	NSString * tempString;
	[text appendString:@"\n\n"];
	[text appendString:@"Please make sure, that you have checked the Help, FAQ & Tips'n'tricks section with concern to your problem! Also due to the huge amount of the HP calculators functionality, I cannot possibly give support for problems regarding the usage of the emulated calculators."];
	[text appendString:@"\n"];
	[text appendString:@"============================================================\n"];
	[text appendString:@"The following information is needed to determine, if you are\n"];
	[text appendString:@"eligible for support, i.e. bought the App from me. It contains\n"];
	[text appendString:@"the unique identifier (UDID) of your device and information\n"]; 
	[text appendString:@"about the App. This information will be solely used for the\n"];
	[text appendString:@"purpose stated. By sending this information, you declare,\n"];
	[text appendString:@"that you agree with this process. If not, please remove this\n"];
	[text appendString:@"information.\n"];
	[text appendString:@"============================================================\n"];
	// Applicaion
	[text appendString:@"Application: "];
	tempString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	// Version:
	[text appendString:@"Version: "];
	tempString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	// UDID:
	[text appendString:@"UDID: "];
	NSString * UDID = @"";
	[text appendString:UDID];
	[text appendString:@"\n"];
	
	// Model:
	[text appendString:@"Model: "];
	tempString = [[UIDevice currentDevice] model];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	// Platform:
	size_t size;  
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);  
	char *machine = malloc(size);  
	sysctlbyname("hw.machine", machine, &size, NULL, 0);  
	
	[text appendString:@"Platform: "];
	tempString = [NSString stringWithCString:machine];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	free(machine); 
	
	// System Name:
	[text appendString:@"System Name: "];
	tempString = [[UIDevice currentDevice] systemName];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	// System Version:
	[text appendString:@"System Version: "];
	tempString = [[UIDevice currentDevice] systemVersion];
	[text appendString:tempString];
	[text appendString:@"\n"];
	
	/* ************************************************
	 * SECRETCODES
	 * ************************************************ */
	// SHA1 of UDID:
	NSData * data = [UDID dataUsingEncoding:NSUTF8StringEncoding];
	NSData * dataSHA1 = [data sha1Digest];
	NSString * UDIDSHA1 = [dataSHA1 hexStringValue];
	
	// SHA1 Hash of Bundle name
	/*
	NSString * bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
	data = [bundleName dataUsingEncoding:NSUTF8StringEncoding];
	dataSHA1 = [data sha1Digest];
	NSString * bundleNameSHA1 = [dataSHA1 hexStringValue];
	//[text appendString:@"Checksum1:"];
	//[text appendString:bundleNameSHA1];
	 */
	
	// SHA1 of the Bundle identifier
	NSString * bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]; //[[NSBundle mainBundle] bundleIdentifier];
	data = [bundleIdentifier dataUsingEncoding:NSUTF8StringEncoding];
	dataSHA1 = [data sha1Digest];
	NSString * bundleIdentifierSHA1 = [dataSHA1 hexStringValue];
	//[text appendString:@"\nChecksum2:"];
	//[text appendString:bundleIdentifierSHA1];
	
	
	// SHA1 Hash of App Binary
	NSString * execFilename = [[NSBundle mainBundle] executablePath];
	data = [NSData dataWithContentsOfFile:execFilename];
	dataSHA1 = [data sha1Digest];
	NSString * execSHA1 = [dataSHA1 hexStringValue];
	[text appendString:@"\nChecksum1:"];
	[text appendString:[execSHA1 uppercaseString]];
	

	NSString * keys[15];
	keys[0] = @"A2B7831AAE68C118A0616A9ED81A6BEB41B59BF5";
	keys[1] = @"4FBBA19D47B744527DE1E885F741E1864E87E1BC";
	keys[2] = @"C20AD9BBFD35589D6D46874329C087EB8D9D23B2";
	keys[3] = @"14060BE435DA2A66729D9E82F628477E23592A9C";
	keys[4] = @"47630E62E62D121542C757CEA3AE4D789CB7E97C";
	keys[5] = @"ABFED488269D7BDBCBB0D871B7AA3EDD827F3758";
	keys[6] = @"D77C53F29900CB56AA3DBC11B93316EE64A4CC64";
	keys[7] = @"303F4C2693C2F4423AACABAA1935A2B8895B227D";
	keys[8] = @"C8B52859864667764164AA8BBE7E578A69F2A588";
	keys[9] = @"C04A8E4F4DA7C02BB79BFA4B30712ECB70981863";
	keys[10] = @"69AB84C6A5028C3112B41778724DA9A51F80D067";
	keys[11] = @"9BA812F359928E5DF446CD4BA74A232803961A6D";
	keys[12] = @"2F017CE45C7BAAB1338A9634A2B21A2E79E09B71";
	keys[13] = @"78C17F757B336EE4128282D665B9DBDA6E958764";
	keys[14] = @"167423C8AD4B46173C704A63E2CE391548CDB5C9";
	keys[15] = @"112C18E331AB74B63377DF7180B9C53866FFDD52";
	
	
	int i;
	
	// Seed the random sequence
	srand( time(NULL) );
	
	// Print combination bundle identifier, udid, key
	NSString * temp = [m48SupportRequest xorHash:bundleIdentifierSHA1 withHash:UDIDSHA1];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	[text appendString:@"\nChecksum2:"];
	[text appendString:temp];
	
	// Print combination bundle identifier, binary, key
	temp = [m48SupportRequest xorHash:bundleIdentifierSHA1 withHash:execSHA1];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	[text appendString:@"\nChecksum3:"];
	[text appendString:temp];
	
	
	// Print combination bundle identifier, binary, udid, key
	temp = [m48SupportRequest xorHash:bundleIdentifierSHA1 withHash:execSHA1];
	temp = [m48SupportRequest xorHash:temp withHash:UDIDSHA1];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	i = floor(16.0/RAND_MAX*(rand()-1));
	temp = [m48SupportRequest xorHash:temp withHash:keys[i]];
	[text appendString:@"\nChecksum4:"];
	[text appendString:temp];
	
	
	[text appendString:@"\n============================================================\n"];
	
	return text;
}

+ (NSString *)xorHash:(NSString *)x1 withHash:(NSString *)x2 {
	if ([x1 length] != 40) {
		return nil;
	}
	if ([x2 length] != 40) {
		return nil;
	}
	NSMutableString * y = [NSMutableString stringWithCapacity:0];
	UTF8Char * a = [[x1 uppercaseString] UTF8String];
	UTF8Char * b = [[x2 uppercaseString] UTF8String];
	char b1, b2;
	for (int i=0; i < 40; i++) {
		b1 = a[i];
		b2 = b[i];
		// Convert to a number
		b1 -= '0';
		if (b1 > 9) b1-= 7;
		if (b1 > 15) return nil;
		b2 -= '0';
		if (b2 > 9) b2-= 7;
		if (b2 > 15) return nil;
		
		b1 = b1^b2;
		
		[y appendFormat:@"%X", b1];
		
		
	}
	return (NSString *)y;
}

@end
