/*
 *   stack.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2005 Christoph Gieﬂelink
 *
 *   Version: Emu48 for Windows Mobile v1.18 
 */
#import "patchwinpch.h"
#include "emu48.h"
#include "io.h"
#import "m48Errors.h"
#import "patchHPEncoding.h"

#define fnRadix		51						// fraction mark
#define fnApprox	105						// exact / approx. mode (HP49G)

#define DOINT		0x02614					// Precision Integer (HP49G)
#define DOREAL		0x02933					// Real
#define DOCMP		0x02977					// Complex
#define DOCSTR		0x02A2C					// String

BOOL bDetectClpObject = TRUE;				// try to detect clipboard object

//################
//#
//#    Low level subroutines
//#
//################

static INT RPL_GetZInt(BYTE CONST *pbyNum,INT nIntLen,LPTSTR cp,INT nSize)
{
	INT i = 0;								// character counter

	_ASSERT(nSize > 0);						// target buffer size

	if (nIntLen > 1)						// has sign nibble
	{
		--nIntLen;							// remove sign from digit length

		// check for valid sign
		_ASSERT(pbyNum[nIntLen] == 0 || pbyNum[nIntLen] == 9);
		if (pbyNum[nIntLen] == 9)			// negative number
		{
			*cp++ = _T('-');				// add sign
			--nSize;						// dec dest buffer size
			++i;							// wrote one character
		}
	}

	if (nIntLen >= nSize) return 0;			// dest buffer overflow
	i += nIntLen;							// adjust character counter

	while (nIntLen-- > 0)					// write all digits
	{
		// check for valid digit
		_ASSERT(pbyNum[nIntLen] >= 0 && pbyNum[nIntLen] <= 9);
		*cp++ = _T('0') + pbyNum[nIntLen];	// and write
	}
	*cp = 0;								// set EOS
	return i;
}

static INT RPL_SetZInt(LPCTSTR cp,LPBYTE pbyNum,INT nSize)
{
	BYTE bySign;
	INT  nStrLen,nNumSize;

	_ASSERT(nSize > 0);						// target buffer size

	nStrLen = strlen(cp);					// source string length

	if (   nStrLen == 0						// empty string
		// precisition integer contain only these numbers
		|| strspn(cp,_T("0123456789+-")) != nStrLen)
		return 0;

	bySign = (*cp != _T('-')) ? 0 : 9;		// set sign nibble
	if (*cp == _T('-') || *cp == _T('+'))	// skip sign character
	{
		++cp;
		--nStrLen;
	}

	if (nStrLen == 1 && *cp == _T('0'))		// special code for zero
	{
		*pbyNum = 0;						// zero data
		return 1;							// finish
	}

	// nStrLen = no. of digits without sign
	if (nStrLen >= nSize)					// destination buffer too small
		return 0;

	nNumSize = nStrLen + 1;					// no. of written data

	while (--nStrLen >= 0)					// eval all digits
	{
		TCHAR c = cp[nStrLen];

		// only '0' .. '9' are valid here
		if (!((c >= _T('0')) || (c <= _T('9'))))
			return 0;

		c -= _T('0');		
		*pbyNum++ = (BYTE) c;
	}
	*pbyNum = bySign;						// add sign

	return nNumSize;
}

static INT RPL_GetBcd(BYTE CONST *pbyNum,INT nMantLen,INT nExpLen,CONST TCHAR cDec,LPTSTR cp,INT nSize)
{
	BYTE byNib;
	LONG v,lExp;
	BOOL bPflag,bExpflag;
	INT  i;

	lExp = 0;
	for (v = 1; nExpLen--; v *= 10)			// fetch exponent
	{
		lExp += (LONG) *pbyNum++ * v;		// calc. exponent
	}

	if (lExp > v / 2) lExp -= v;			// negative exponent

	lExp -= nMantLen - 1;					// set decimal point to end of mantissa

	i = 0;									// first character
	bPflag = FALSE;							// show no decimal point

	// scan mantissa
	for (v = (LONG) nMantLen - 1; v >= 0 || bPflag; v--)
	{
		if (v >= 0L)						// still mantissa digits left
			byNib = *pbyNum++;
		else
			byNib = 0;						// zero for negativ exponent

		if (!i)								// still delete zeros at end
		{
			if (byNib == 0 && lExp && v > 0) // delete zeros
			{
				lExp++;						// adjust exponent
				continue;
			}

			// TRUE at x.E
			bExpflag = v + lExp >= nMantLen || lExp < -nMantLen;
			bPflag = !bExpflag && v < -lExp; // decimal point flag at neg. exponent
		}

		// set decimal point
		if ((bExpflag && v == 0) || (!lExp && i))
		{
			if (i >= nSize) return 0;		// dest buffer overflow
			cp[i++] = cDec;					// write decimal point
			if (v < 0)						// no mantissa digits any more
			{
				if (i >= nSize) return 0;	// dest buffer overflow
				cp[i++] = _T('0');			// write heading zero
			}
			bPflag = FALSE;					// finished with negativ exponents
		}

		if (v >= 0 || bPflag)
		{
			if (i >= nSize) return 0;		// dest buffer overflow
			cp[i++] = (TCHAR) byNib + _T('0'); // write character
		}

		lExp++;								// next position
	}

	if (*pbyNum == 9)						// negative number
	{
		if (i >= nSize) return 0;			// dest buffer overflow
		cp[i++] = _T('-');					// write sign
	}

	if (i >= nSize) return 0;				// dest buffer overflow
	cp[i] = 0;								// set EOS

	for (v = 0; v < (i / 2); v++)			// reverse string
	{
		TCHAR cNib = cp[v];					// swap chars
		cp[v] = cp[i-v-1];
		cp[i-v-1] = cNib;
	}

	// write number with exponent
	if (bExpflag)
	{
		if (i + 5 >= nSize) return 0;		// dest buffer overflow
		i += sprintf(&cp[i],_T("E%d"),lExp-1);
	}
	return i;
}

static INT RPL_SetBcd(LPCTSTR cp,INT nMantLen,INT nExpLen,CONST TCHAR cDec,LPBYTE pbyNum,INT nSize)
{
	TCHAR cVc[] = _T(".0123456789eE+-");

	BYTE byNum[80];
	INT  i,nIp,nDp,nMaxExp;
	LONG lExp;

	cVc[0] = cDec;							// replace decimal char
	
	if (   nMantLen + nExpLen >= nSize		// destination buffer too small
		|| !*cp								// empty string
		|| strspn(cp,cVc) != strlen(cp) // real contain only these numbers
		|| strlen(cp) >= ARRAYSIZEOF(byNum)) // ignore too long reals
		return 0;

	byNum[0] = (*cp != _T('-')) ? 0 : 9;	// set sign nibble
	if (*cp == _T('-') || *cp == _T('+'))	// skip sign character
		cp++;

	// only '.', '0' .. '9' are valid here
	if (!((*cp == cDec) || (*cp >= _T('0')) || (*cp <= _T('9'))))
		return 0;

	nIp = 0;								// length of integer part
	if (*cp != cDec)						// no decimal point
	{
		// count integer part
	    while (*cp >= _T('0') && *cp <= _T('9'))
			byNum[++nIp] = *cp++ - _T('0');
		if (!nIp) return 0;
	}

	// only '.', 'E', 'e' or end are valid here
	if (!(!*cp || (*cp == cDec) || (*cp == _T('E')) || (*cp == _T('e'))))
		return 0;

	nDp = 0;								// length of decimal part
	if (*cp == cDec)						// decimal point
	{
		cp++;								// skip '.'

		// count decimal part
		while (*cp >= _T('0') && *cp <= _T('9'))
			byNum[nIp + ++nDp] = *cp++ - _T('0');
	}

	// count number of heading zeros in mantissa
	for (i = 0; byNum[i+1] == 0 && i + 1 < nIp + nDp; ++i) { }

	if (i > 0)								// have to normalize
	{
		INT j;

		nIp -= i;							// for later ajust of exponent
		for (j = 1; j <= nIp + nDp; ++j)	// normalize mantissa
			byNum[j] = byNum[j + i];
	}

	if (byNum[1] == 0)						// number is 0
	{
		ZeroMemory(pbyNum,nMantLen + nExpLen + 1);
		return nMantLen + nExpLen + 1;
	}

	for (i = nIp + nDp; i < nMantLen;)		// fill rest of mantissa with 0
		byNum[++i] = 0;

	// must be 'E', 'e' or end
	if (!(!*cp || (*cp == _T('E')) || (*cp == _T('e'))))
		return 0;

	lExp = 0;
	if (*cp == _T('E') || *cp == _T('e'))
	{
		cp++;								// skip 'E'

		i = FALSE;							// positive exponent
		if (*cp == _T('-') || *cp == _T('+'))
		{
			i = (*cp++ == _T('-'));			// adjust exponent sign
		}

		// exponent symbol must be followed by number
		if (*cp < _T('0') || *cp > _T('9')) return 0;

		while (*cp >= _T('0') && *cp <= _T('9'))
			lExp = lExp * 10 + *cp++ - _T('0');

		if (i) lExp = -lExp;
	}

	if (*cp != 0) return 0;

	// adjust exponent value with exponent from normalized mantissa
	lExp += nIp - 1;

	// calculate max. posive exponent
	for (nMaxExp = 5, i = 1; i < nExpLen; ++i)
		nMaxExp *= 10;

	// check range of exponent
	if ((lExp < 0 && -lExp >= nMaxExp) || (lExp >= nMaxExp))
		return 0;

	if (lExp < 0) lExp += 2 * nMaxExp;		// adjust negative offset

	for (i = nExpLen; i > 0; --i)			// convert number into digits
	{
		byNum[nMantLen + i] = (BYTE) (lExp % 10);
		lExp /= 10;
	}

	// copy to target in reversed order
	for (i = nMantLen + nExpLen; i >= 0; --i)
		*pbyNum++ = byNum[i];

	return nMantLen + nExpLen + 1;
}

static INT RPL_GetComplex(BYTE CONST *pbyNum,INT nMantLen,INT nExpLen,CONST TCHAR cDec,LPTSTR cp,INT nSize)
{
	INT   nLen,nPos;
	TCHAR cSep;

	cSep = (cDec == _T('.'))				// current separator
		 ? _T(',')							// radix mark '.' -> ',' separator
		 : _T(';');							// radix mark ',' -> ';' separator

	nPos = 0;								// write buffer position

	if (nSize < 5) return 0;				// target buffer to small
	nSize -= 4;								// reserved room for (,)\0

	cp[nPos++] = _T('(');					// start of complex number

	// real part
	nLen = RPL_GetBcd(pbyNum,12,3,cDec,&cp[1],nSize);
	if (nLen == 0) return 0;				// target buffer to small

	_ASSERT(nLen <= nSize);

	nPos += nLen;							// actual buffer postion
	nSize -= nLen;							// remainder target buffer size

	cp[nPos++] = cSep;						// write of complex number seperator

	// imaginary part
	nLen = RPL_GetBcd(&pbyNum[16],12,3,cDec,&cp[nPos],nSize);
	if (nLen == 0) return 0;				// target buffer to small

	nPos += nLen;							// actual buffer postion

	cp[nPos++] = _T(')');					// end of complex number
	cp[nPos] = 0;							// EOS

	_ASSERT((INT) lstrlen(cp) == nPos);

	return nPos;
}

static INT RPL_SetComplex(LPCTSTR cp,INT nMantLen,INT nExpLen,CONST TCHAR cDec,LPBYTE pbyNum,INT nSize)
{
	LPTSTR pcSep,pszData;
	INT    nLen;
	TCHAR  cSep;

	nLen = 0;								// read data length

	cSep = (cDec == _T('.'))				// current separator
		 ? _T(',')							// radix mark '.' -> ',' separator
		 : _T(';');							// radix mark ',' -> ';' separator

	// create a working copy of the string
	pszData = malloc(strlen(cp));
	strcpy(pszData, cp);
	if (pszData != NULL)
	{
		INT nStrLength = strlen(pszData);	// string length

		// complex number with brackets around
		if (   nStrLength > 0
			&& pszData[0]              == _T('(')
			&& pszData[nStrLength - 1] == _T(')'))
		{
			pszData[--nStrLength] = 0;		// replace ')' with EOS

			// search for number separator
			if ((pcSep = strchr(pszData+1,cSep)) != NULL)
			{
				INT nLen1st;

				*pcSep = 0;					// set EOS for 1st substring

				// decode 1st substring
				nLen1st = RPL_SetBcd(pszData+1,nMantLen,nExpLen,cDec,&pbyNum[0],nSize);
				if (nLen1st > 0)
				{
					// decode 2nd substring
					nLen = RPL_SetBcd(pcSep+1,nMantLen,nExpLen,cDec,&pbyNum[nMantLen+nExpLen+1],nSize-nLen1st);
					if (nLen > 0)
					{
						nLen += nLen1st;	// complete Bcd length
					}
				}
			}
		}
		free(pszData);
	}
	return nLen;
}


//################
//#
//#    Object subroutines
//#
//################

#if 0
static INT IsRealNumber(LPCTSTR cp,INT nMantLen,INT nExpLen,CONST TCHAR cDec,LPBYTE pbyNum,INT nSize)
{
	LPTSTR lpszNumber;
	INT    nLength = 0;

	if ((lpszNumber = DuplicateString(cp)) != NULL)
	{
		LPTSTR p = lpszNumber;
		INT i;

		// cut heading whitespaces
		for (; *p == _T(' ') || *p == _T('\t'); ++p) { }

		// cut tailing whitespaces
		for (i = lstrlen(p); --i >= 0;)
		{
			if (p[i] != _T(' ') && p[i] != _T('\t'))
				break;
		}
		p[++i] = 0;							// new EOS

		nLength = RPL_SetBcd(p,nMantLen,nExpLen,cDec,pbyNum,nSize);
		HeapFree(hHeap,0,lpszNumber);
	}
	return nLength;
}
#endif

static TCHAR GetRadix(VOID)
{
	// get locale decimal point
	// GetLocaleInfo(LOCALE_USER_DEFAULT,LOCALE_SDECIMAL,&cDecimal,1);

	return RPL_GetSystemFlag(fnRadix) ? _T(',') : _T('.');
}

static INT DoInt(DWORD dwAddress,LPTSTR cp,INT nSize)
{
	LPBYTE lpbyData;
	INT    nLength,nIntLen;

	nIntLen = Read5(dwAddress) - 5;			// no. of digits
	if (nIntLen <= 0) return 0;				// error in calculator object

	nLength = 0;
	if ((lpbyData = malloc(nIntLen)))
	{
		// get precisition integer object content and decode it
		Npeek(lpbyData,dwAddress+5,nIntLen);
		nLength = RPL_GetZInt(lpbyData,nIntLen,cp,nSize);
		free(lpbyData);
	}
	return nLength;
}

static INT DoReal(DWORD dwAddress,LPTSTR cp,INT nSize)
{
	BYTE byNumber[16];

	// get real object content and decode it
	Npeek(byNumber,dwAddress,ARRAYSIZEOF(byNumber));
	return RPL_GetBcd(byNumber,12,3,GetRadix(),cp,nSize);
}

static INT DoComplex(DWORD dwAddress,LPTSTR cp,INT nSize)
{
	BYTE byNumber[32];

	// get complex object content and decode it
	Npeek(byNumber,dwAddress,ARRAYSIZEOF(byNumber));
	return RPL_GetComplex(byNumber,12,3,GetRadix(),cp,nSize);
}


//################
//#
//#    Stack routines
//#
//################

//
// ID_STACK_COPY
//
BOOL OnStackCopy(NSError ** error)					// copy data from stack
{
	TCHAR  cBuffer[128];	
	LPBYTE lpbyData;
	DWORD  dwAddress,dwObject,dwSize;
	
	NSString * pasteboardString = nil;
	NSString * errorString = nil;
	
	_ASSERT(nState == SM_RUN);				// emulator must be in RUN state
	if (WaitForSleepState())				// wait for cpu SHUTDN then sleep state
	{
		if (error != NULL) {
			errorString = @"Emulator is busy.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESTK userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return 0;
	}

	_ASSERT(nState == SM_SLEEP);

	if ((dwAddress = RPL_Pick(1)) == 0)		// pick address of level1 object
	{
		//mksg Errors in m48 won't give sounds
		//MessageBeep(MB_OK);					// error beep
		goto error;
	}

	switch (dwObject = Read5(dwAddress))	// select object
	{
	case DOINT:  // Precision Integer (HP49G)
	case DOREAL: // real object
	case DOCMP:  // complex object
		dwAddress += 5;						// object content

		switch (dwObject)
		{
		case DOINT: // Precision Integer (HP49G)
			// get precision integer object content and decode it
			dwSize = DoInt(dwAddress,cBuffer,ARRAYSIZEOF(cBuffer));
			break;
		case DOREAL: // real object
			// get real object content and decode it
			dwSize = DoReal(dwAddress,cBuffer,ARRAYSIZEOF(cBuffer));
			break;
		case DOCMP: // complex object
			// get complex object content and decode it
			dwSize = DoComplex(dwAddress,cBuffer,ARRAYSIZEOF(cBuffer));
			break;
		}

		// calculate buffer size
		dwSize = (dwSize + 1) * sizeof(*cBuffer);
		
		pasteboardString = [NSString stringWithCString:cBuffer length:dwSize];
		if (pasteboardString == nil) { 
			goto error;
		}
			
		break;
	case DOCSTR: // string
		dwAddress += 5;						// address of string length
		dwSize = (Read5(dwAddress) - 5) / 2; // length of string
		dwSize++;							// with EOS

		// memory allocation for clipboard data
			/*
		if ((hClipObj = GlobalAlloc(GMEM_MOVEABLE,dwSize*sizeof(TCHAR))) == NULL)
			goto error;
			 */

		// create temporary buffer for byte data
		if ((lpbyData = malloc(dwSize)) != NULL)
		{
			DWORD i;
			char temp;
			// copy data into byte buffer
			for (i = 0, dwAddress += 5; i < dwSize - 1; dwAddress += 2) {
				temp = Read2(dwAddress);
				lpbyData[i++] = temp;
			}
			lpbyData[i] = '\0';				// set EOS

			//pasteboardString = [NSString stringWithCString:(char *)lpbyData  encoding:NSWindowsCP1252StringEncoding];
			//pasteboardString = [NSString stringWithCString:(char *)lpbyData  encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatinUS)];
			unichar * utf16 = codepageHPToUTF16((char *) lpbyData);
			int len = strlen((char *)lpbyData);
			free(lpbyData);
			if (utf16 == NULL) {
				free(lpbyData);
				goto error;
			}
			pasteboardString = [NSString stringWithCharacters:utf16 length:len];
			free(utf16); // IMPORTANT!
			if (pasteboardString == nil) { 
				goto error;
			}

			
		}
		break;
	default:
		//mksg Errors in m48 won't give sounds
		//MessageBeep(MB_OK);			// error beep				
		goto error;
	}

	[[UIPasteboard generalPasteboard] setString:pasteboardString];
	//[[UIPasteboard generalPasteboard] setValue:pasteboardString forKey:kUTTypeText];
	//[[UIPasteboard generalPasteboard] setValue:pasteboardString forKey:@"public.text"];

	return 1;
	
error:
	if (error != NULL) {
		errorString = @"Could not copy item.";
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESTK userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
	}
	SwitchToState(SM_RUN);
	return 0;
}

//
// ID_STACK_PASTE
//
BOOL OnStackPaste(NSError ** error)					// paste data to stack
{
	BOOL bSuccess = FALSE;

	NSString * pasteboardString = nil;
	NSString * errorString;
	
	pasteboardString = [[UIPasteboard generalPasteboard] string];
	
	// check if clipboard format is available
	if (pasteboardString == nil)
	{
		//MessageBeep(MB_OK);					// error beep
		if (error != NULL) {
			errorString = @"No valid pasteboard item.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESTK userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return 0;
	}

	// calculator off, turn on
	if (!(Chipset.IORam[BITOFFSET]&DON))
	{
		KeyboardEvent(TRUE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];
		
		[NSThread sleepForTimeInterval:(dwWakeupDelay/1000)];
		//sleep(dwWakeupDelay); => nur ganze Sekunden!?
		KeyboardEvent(FALSE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];

		// wait for sleep mode
		while (Chipset.Shutdn == FALSE) {
			[NSThread sleepForTimeInterval:0];
			//sleep(0);
		}
	}

	_ASSERT(nState == SM_RUN);				// emulator must be in RUN state
	if (WaitForSleepState())				// wait for cpu SHUTDN then sleep state
	{
		if (error != NULL) {
			errorString = @"The emulator is busy.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESTK userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		goto cancel;
	}

	_ASSERT(nState == SM_SLEEP);

	

	LPCTSTR lpstrClipdata;
	LPBYTE  lpbyData;
	
	//lpstrClipdata = (LPCTSTR) [pasteboardString cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	
	unichar * utf16 = (unichar *) [pasteboardString cStringUsingEncoding:NSUnicodeStringEncoding];
	lpstrClipdata = codepageUTF16ToHP(utf16, [pasteboardString length]);
	
	if (lpstrClipdata)
	{
		BYTE  byNumber[128];
		DWORD dwAddress;
		INT   s;

		do
		{
			if (bDetectClpObject)	// autodetect clipboard object enabled
			{
				// HP49G in exact mode
				if ((cCurrentRomType == 'X' || cCurrentRomType=='Q') && !RPL_GetSystemFlag(fnApprox))
				{
					// try to convert string to HP49 precision integer
					s = RPL_SetZInt(lpstrClipdata,byNumber,sizeof(byNumber));

					if (s > 0)		// is a real number for exact mode
					{
						// get TEMPOB memory for HP49 precision integer object
						dwAddress = RPL_CreateTemp(s+5+5);
						if ((bSuccess = (dwAddress > 0)))
						{
							Write5(dwAddress,DOINT); // prolog
							Write5(dwAddress+5,s+5); // size
							Nwrite(byNumber,dwAddress+10,s); // data

							// push object to stack
							RPL_Push(1,dwAddress);
						}
						break;
					}
				}

				// try to convert string to real format
				_ASSERT(16 <= ARRAYSIZEOF(byNumber));
				s = RPL_SetBcd(lpstrClipdata,12,3,GetRadix(),byNumber,sizeof(byNumber));

				if (s > 0)			// is a real number
				{
					_ASSERT(s == 16); // length of real number BCD coded

					// get TEMPOB memory for real object
					dwAddress = RPL_CreateTemp(16+5);
					if ((bSuccess = (dwAddress > 0)))
					{
						Write5(dwAddress,DOREAL); // prolog
						Nwrite(byNumber,dwAddress+5,s); // data

						// push object to stack
						RPL_Push(1,dwAddress);
					}
					break;
				}

				// try to convert string to complex format
				_ASSERT(32 <= ARRAYSIZEOF(byNumber));
				s = RPL_SetComplex(lpstrClipdata,12,3,GetRadix(),byNumber,sizeof(byNumber));

				if (s > 0)			// is a real complex
				{
					_ASSERT(s == 32); // length of complex number BCD coded

					// get TEMPOB memory for complex object
					dwAddress = RPL_CreateTemp(16+16+5);
					if ((bSuccess = (dwAddress > 0)))
					{
						Write5(dwAddress,DOCMP); // prolog
						Nwrite(byNumber,dwAddress+5,s); // data

						// push object to stack
						RPL_Push(1,dwAddress);
					}
					break;
				}
			}

			// any other format
			{
				DWORD dwSize = strlen(lpstrClipdata);
				if ((lpbyData = malloc(dwSize * 2)))
				{
					LPBYTE lpbySrc,lpbyDest;
					DWORD  dwLoop;

					// copy data UNICODE -> ASCII
//					WideCharToMultiByte(CP_ACP, WC_COMPOSITECHECK,
//										lpstrClipdata, dwSize,
//										lpbyData+dwSize, dwSize, NULL, NULL);
					memcpy(lpbyData+dwSize, lpstrClipdata, dwSize);
					

					// unpack data
					lpbySrc = lpbyData+dwSize;
					lpbyDest = lpbyData;
					dwLoop = dwSize;
					while (dwLoop-- > 0)
					{
						BYTE byTwoNibs = *lpbySrc++;
						*lpbyDest++ = (BYTE) (byTwoNibs & 0xF);
						*lpbyDest++ = (BYTE) (byTwoNibs >> 4);
					}

					dwSize *= 2;	// size in nibbles

					// get TEMPOB memory for string object
					dwAddress = RPL_CreateTemp(dwSize+10);
					if ((bSuccess = (dwAddress > 0)))
					{
						Write5(dwAddress,DOCSTR); // String
						Write5(dwAddress+5,dwSize+5); // length of String
						Nwrite(lpbyData,dwAddress+10,dwSize); // data

						// push object to stack
						RPL_Push(1,dwAddress);
					}
					free(lpbyData);
				}
			}
		}
		while (FALSE);
		free(lpstrClipdata); // IMPORTANT
	}
	
	

	SwitchToState(SM_RUN);					// run state
	while (nState!=nNextState) {
		[NSThread sleepForTimeInterval:0];
		//sleep(0);
	}
	_ASSERT(nState == SM_RUN);

	if (bSuccess == FALSE)					// data not copied
		goto cancel;

	KeyboardEvent(TRUE,0,0x8000);
	[NSThread sleepForTimeInterval:0.05];
	
	[NSThread sleepForTimeInterval:(dwWakeupDelay/1000)];
	//sleep(dwWakeupDelay); => nur ganze Sekunden!?
	KeyboardEvent(FALSE,0,0x8000);
	[NSThread sleepForTimeInterval:0.05];

	// wait for sleep mode
	while (Chipset.Shutdn == FALSE) {
		[NSThread sleepForTimeInterval:0];
		//sleep(0);
	}
	
	return 1;

cancel:
	if (error != NULL) {
		errorString = @"Could not paste item.";
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESTK userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
	}
	return 0;
}
