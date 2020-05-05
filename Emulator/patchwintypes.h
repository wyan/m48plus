/*
 *  patchwintypes.h
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

#define __inline inline
#define CONST const

//#define _BIGENDIAN // LITTLE_ENDIAN machine

typedef signed short int		SHORT; // Later defined as signed 16bit int
typedef signed short int		SWORD;
typedef unsigned short int		WORD;
typedef unsigned int			DWORD;
typedef DWORD *					DWORD_PTR;
typedef signed long int			LONG;

typedef unsigned long long int	ULONGLONG; // Later defined as QWORD // should be unsigned 64bit variable
typedef signed long long int	LONGLONG; 

typedef signed int				INT;
typedef unsigned int			UINT;


typedef void					VOID;

typedef unsigned char			BYTE;
typedef unsigned char * 		LPBYTE;

typedef char					CHAR;
typedef char					TCHAR; // nu in stack.m benötigt
typedef char *					LPTSTR;
typedef char *					LPCTSTR;

typedef union _LARGE_INTEGER {
	DWORD LowPart;
	//LONG HighPart; Geht nicht in ANSI C, da annonymus structs nicht erlaubt sind.
	struct {
		DWORD LowPart;
		LONG HighPart;
	} u;
	LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER;

/* ursprünglich:
typedef union _LARGE_INTEGER {
	DWORD LowPart;
	LONG HighPart;
	struct {
		DWORD LowPart;
		LONG HighPart;
	} u;
	LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER; */

 
// TEMPORARY 2009/06/01
/*
 typedef struct _SYSTEMTIME {
 WORD wYear; 
 WORD wMonth; 
 WORD wDayOfWeek; 
 WORD wDay; 
 WORD wHour; 
 WORD wMinute; 
 WORD wSecond; 
 WORD wMilliseconds; 
 } SYSTEMTIME;
 */
 
/* Sizecheck yielded:
 // Size-check iPhone
 int a01 = sizeof(unsigned char); // 1
 int a02 = sizeof(char); // 1
 int a03 = sizeof(signed char); // 1
 
 //int b01 = sizeof(unsigned short short int); // not working
 //int b02 = sizeof(short short int); // not working 
 //int b03 = sizeof(signed short short int); // not working 
 
 int c01 = sizeof(unsigned short int); // 2
 int c02 = sizeof(short int); // 2
 int c03 = sizeof(signed short int); // 2
 
 int d01 = sizeof(unsigned int); // 4
 int d02 = sizeof(int); // 4
 int d03 = sizeof(signed int); // 4
 
 int e01 = sizeof(unsigned long int); // 4
 int e02 = sizeof(long int); // 4
 int e03 = sizeof(signed long int); // 4
 
 int f01 = sizeof(unsigned long long int); // 8
 int f02 = sizeof(long long int); // 8
 int f03 = sizeof(signed long long int); // 8
 
 
 int g = sizeof(float); // 4
 int h = sizeof(double); // 8
 //int j = sizeof(quad); // 8
 
 // Pointer
 int i = sizeof(id); // 4
 int j = sizeof(int *); // 4 
 
 int a01 = sizeof(uint8); // 1
 int a02 = sizeof(int8_t) ;  // 1
 int a03 = sizeof(sint8); // 1
 
 //int b01 = sizeof(unsigned short short int); // not working
 //int b02 = sizeof(short short int); // not working 
 //int b03 = sizeof(signed short short int); // not working 
 
 int c01 = sizeof(uint16); // 2
 int c02 = sizeof(int16_t); // 2
 int c03 = sizeof(sint16); // 2
 
 int d01 = sizeof(uint32); // 4
 int d02 = sizeof(int32_t); // 4
 int d03 = sizeof(sint32); // 4
 
 
 
 int f01 = sizeof(uint64); // 8
 int f02 = sizeof(int64_t); // 8
 int f03 = sizeof(sint64); // 8

*/