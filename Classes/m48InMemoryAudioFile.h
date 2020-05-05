/*
 *  m48InMemoryAudioFile.h
 *
 *  This file is part of m48
 *
 *  Thankfully provided by Aran Mulholland 
 *
 *  Copyright (C) 2009 Aran Mulholland
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


#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioFile.h>
#include <sys/time.h>


@interface m48InMemoryAudioFile : NSObject {
	AudioStreamBasicDescription		mDataFormat;                    
    AudioFileID						mAudioFile;                     
    UInt32							bufferByteSize;                 
    SInt64							mCurrentPacket;                 
    UInt32							mNumPacketsToRead;              
    AudioStreamPacketDescription	*mPacketDescs;                  
	SInt64							packetCount;
	UInt32							*audioData;
	SInt64							packetIndex;
	SInt64							leftPacketIndex;
	SInt64							rightPacketIndex;
	
	SInt16							*leftAudioData;
	SInt16							*rightAudioData;
	
	float							*monoFloatDataLeft;
	float							*monoFloatDataRight;

	Boolean		isPlaying;
	
	float volume;
}
@property SInt64 packetCount;
@property UInt32 * audioData;
@property float volume;

//opens a wav file
-(OSStatus)open:(NSString *)filePath;
//gets the infor about a wav file, stores it locally
-(OSStatus)getFileInfo;

//gets the next packet from the buffer, returns -1 if we have reached the end of the buffer
-(UInt32)getNextPacket;
//gets the current index (where we are up to in the buffer)
-(SInt64)getIndex;

//reset the index to the start of the file
-(void)reset;

-(void)play;

@end
