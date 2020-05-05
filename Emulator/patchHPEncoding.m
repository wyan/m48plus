/*
 *  patchHPEncoding.c
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
#import "patchHPEncoding.h"

// http://www.kostis.net/charsets/hp48.htm
static UInt16 mapHPToUTF16[] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,8735,129,8711,8730,8747,8721,9654,960,8706,8804,8805,8800,945,8594,8592,8595,8593,947,948,949,951,952,955,961,963,964,969,916,928,937,9644,8734,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255};

unichar * codepageHPToUTF16(const char * src) {
	unichar * dst;
	unsigned int len = strlen(src);
	
	dst = malloc(2*(len+1));
	if (dst == NULL) {
		return NULL;
	}
	
	UInt16 * dst16 = (UInt16 *) dst;
	const UInt8 * src8 = (const UInt8 *) src;
	for (int i=0; i < len; i++) {
		*(dst16++) = mapHPToUTF16[*(src8++)];
	}
	dst16 = 0; // EOS
	return dst;
}


char * codepageUTF16ToHP(const unichar * src, unsigned int len) {
	// This is more difficult, since we can't be sure, that everything can be represented
	char * dst;
	
	dst = malloc(len+1);
	if (dst == NULL) {
		return NULL;
	}
	
	UInt8 * dst8 = (UInt8 *) dst;
	const UInt16 * src16 = (const UInt16 *) src;
	for (int i=0; i < len; i++) {
		if ((*src16 <= 127) || ((*src16 >= 160) && (*src16 <= 255)))  {
			*(dst8++) = *(src16++);
		}
		else {
			// Search in map
			int j;
			for (j=0; j < 256; j++) {
				if (*src16 == mapHPToUTF16[j]) {
					*(dst8++) = j;
					src16++;
					break;
				}
			}
			if (j==256) { // not found
				free(dst);
				return NULL;
			}
		}
	}
	*dst8 = 0; // EOS
	return dst;
}


