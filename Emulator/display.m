/*
 *   display.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "emu48.h"
#import "io.h"
#import "xml.h"

#define DISPLAY_FREQ	42	//19				// display update 1/frequency (1/64) in ms

#define NOCOLORS	2

#define B 0x00000000						// black
#define W 0x00FFFFFF						// white
#define I 0xFFFFFFFF						// ignore

#define LCD_ROW		(36*4)					// max. pixel per line

// main display lines, handle zero lines exception
#define LINES(n)	(((n) == 0) ? ((cCurrentRomType=='Q') ? 72 : 64) : ((n)+1))

BYTE *	lcdTextureBuffer = NULL;
BYTE *	lcdTextureBuffer1 = NULL;
BYTE *	lcdTextureBuffer2 = NULL;
int		timesNewTextureBufferDiffers;
BOOL	bStaticsFilterEnabled = TRUE;
int 	holdDelayStartVal = 6;
//WORD	currentAnnunciators = 0x0000;

static DWORD currentForegroundColor = 0xFFFFFFFF;
static DWORD currentBackgroundColor = 0x00000000;

LARGE_INTEGER lLcdRef;				// reference time for VBL counter

// for debugging puposes
unsigned char * pfix;

static CONST DWORD Pattern[] =
{
	0x00000000, 0x00000001, 0x00000100, 0x00000101,
	0x00010000, 0x00010001, 0x00010100, 0x00010101,
	0x01000000, 0x01000001, 0x01000100, 0x01000101,
	0x01010000, 0x01010001, 0x01010100, 0x01010101
};

static pthread_t		hCThreadLcd = NULL;
static pthread_cond_t	hEventLcd;
static pthread_mutex_t	hEventLcdLock;
static BOOL				hEventLcdPredicate;

VOID UpdateDisplay(VOID);

VOID UpdateContrast(BYTE byContrast)
{	
	BYTE temp;
	XmlColor tempColor;
	// when display is off use contrast 0
	if ((Chipset.IORam[BITOFFSET] & DON) == 0) byContrast = 0;

	// use this as catch of possible errors
	temp = xml->global->nLcdColors;
	
	if (temp < (byContrast+1)) {
		if (temp >= 1) {
			tempColor = *(xml->global->lcdColors);
			*((BYTE *)(&currentForegroundColor) + 0) = 0xFF*((tempColor.red));
			*((BYTE *)(&currentForegroundColor) + 1) = 0xFF*((tempColor.green));
			*((BYTE *)(&currentForegroundColor) + 2) = 0xFF*((tempColor.blue));
			*((BYTE *)(&currentForegroundColor) + 3) = 0xFF*(tempColor.alpha);	
		}
		else {
			currentForegroundColor = 0xFFFFFFFF;
		}
	}
	else {
		tempColor = *(xml->global->lcdColors + byContrast);
		*((BYTE *)(&currentForegroundColor) + 0) = 0xFF*((tempColor.red));
		*((BYTE *)(&currentForegroundColor) + 1) = 0xFF*((tempColor.green));
		*((BYTE *)(&currentForegroundColor) + 2) = 0xFF*((tempColor.blue));
		*((BYTE *)(&currentForegroundColor) + 3) = 0xFF*(tempColor.alpha);
	}
	
	if (temp < (byContrast+33)) {
		if (temp <= 1) {
			currentBackgroundColor = 0x00000000;
		}
		else {
			tempColor = *(xml->global->lcdColors + 1);
			*((BYTE *)(&currentBackgroundColor) + 0) = 0xFF*((tempColor.red));
			*((BYTE *)(&currentBackgroundColor) + 1) = 0xFF*((tempColor.green));
			*((BYTE *)(&currentBackgroundColor) + 2) = 0xFF*((tempColor.blue));
			*((BYTE *)(&currentBackgroundColor) + 3) = 0xFF*(tempColor.alpha);	
		}
	}
	else {
		tempColor = *(xml->global->lcdColors + byContrast + 32);
		*((BYTE *)(&currentBackgroundColor) + 0) = 0xFF*((tempColor.red));
		*((BYTE *)(&currentBackgroundColor) + 1) = 0xFF*((tempColor.green));
		*((BYTE *)(&currentBackgroundColor) + 2) = 0xFF*((tempColor.blue));
		*((BYTE *)(&currentBackgroundColor) + 3) = 0xFF*(tempColor.alpha);
	}
	
	return;
}

//****************
//*
//* LCD functions
//*
//****************

static inline void WritePixel(BYTE **d,DWORD p)
{
	if ((BYTE) (p >> 0)) {
		**((DWORD **) d) = currentForegroundColor;
	}
	else {
		**((DWORD **) d) = currentBackgroundColor;
	}
	*d += 4;
	
	if ((BYTE) (p >> 8)) {
		**((DWORD **) d) = currentForegroundColor;
	}
	else {
		**((DWORD **) d) = currentBackgroundColor;
	}
	*d += 4;
	
	if ((BYTE) (p >> 16)) {
		**((DWORD **) d) = currentForegroundColor;
	}
	else {
		**((DWORD **) d) = currentBackgroundColor;
	}
	*d += 4;
	
	if ((BYTE) (p >> 24)) {
		**((DWORD **) d) = currentForegroundColor;
	}
	else {
		**((DWORD **) d) = currentBackgroundColor;
	}
	*d += 4;

	return;
}

void inline UpdateDisplay(VOID)
{
	UINT  x, y, nLines;
	BYTE  *p;
	DWORD d;
	static BYTE Buf[36];
	
	BYTE * nextLcdTextureBuffer;
	if (lcdTextureBuffer == lcdTextureBuffer1) {
		nextLcdTextureBuffer = lcdTextureBuffer2;
	}
	else {
		nextLcdTextureBuffer = lcdTextureBuffer1;
	}
	
	// Versuch die screen-glitches wegzubekommen
	//[_csLCDLock lock];
	
	// main display area
	nLines = LINES(Chipset.lcounter);		// main display lines
    if (cCurrentRomType == 'Q') {           // MZI
        nLines = 72;
    }
	d = 0;									// pixel offset counter
	for (y = 0; y < nLines; ++y)
	{
		p = nextLcdTextureBuffer + 256*4*y;
		// read line with actual start1 address!!
		Npeek(Buf,d+Chipset.start1,36);
		
		for (x = 0; x < 36; ++x)
		{
			WritePixel(&p,Pattern[Buf[x]]);
		}
		d += (34 + Chipset.loffset + (Chipset.boffset / 4) * 2) & 0xFFFFFFFE;
	}

	// menu display area
	if (nLines < SCREENHEIGHT)						// menu area enabled
	{
		// calculate bitmap offset
		d = 0;								// pixel offset counter
		for (y = nLines; y < SCREENHEIGHT; ++y)
		{
			p = nextLcdTextureBuffer + 256*4*y;
			// 34 nibbles are viewed
			Npeek(Buf,d+Chipset.start2,34);
			for (x = 0; x < 34; ++x)
			{
				WritePixel(&p,Pattern[Buf[x]]);
			}
			d += 34;
		}	 
	}
	
	// Versuch die screen-glitches wegzubekommen
	//[_csLCDLock unlock];
	
	// debug screen glitch
	/*
	int debugSum=0;
	p = nextLcdTextureBuffer + 256*4*30 + 32*4*4;
	debugSum += ((*(p+0) & 0xFF) != 0);
	debugSum += ((*(p+1) & 0xFF) != 0);
	debugSum += ((*(p+2) & 0xFF) != 0);
	debugSum += ((*(p+3) & 0xFF) != 0);
	debugSum += ((*(p+4) & 0xFF) != 0);
	debugSum += ((*(p+5) & 0xFF) != 0);
	debugSum += ((*(p+6) & 0xFF) != 0);
	debugSum += ((*(p+7) & 0xFF) != 0);
	// Debug-Falle für die Screen-Glitches
	if (debugSum) {
		debugSum = 1;
	}
	 */
	//ende debug
	
	// Statistical Filter
	int amountDifferentPixels;
	DWORD * px;
	DWORD * py;
	if (!bStaticsFilterEnabled) {
		lcdTextureBuffer = nextLcdTextureBuffer;
	}
	else if (timesNewTextureBufferDiffers >= 5) {
		// Use new one
		lcdTextureBuffer = nextLcdTextureBuffer;
		timesNewTextureBufferDiffers = 0;
	}
	else {
		px = (DWORD *) lcdTextureBuffer;
		py = (DWORD *) nextLcdTextureBuffer;
		// Check if it differs by more than some percentage
		amountDifferentPixels = 0;
		for (x=0; x < SCREENHEIGHT*256; x=x+20) {
			if ( (*px) != (*py) ) {
				amountDifferentPixels++;
			}
			px = px + 20;
			py = py + 20;
		}
		if (amountDifferentPixels < 100) {
			lcdTextureBuffer = nextLcdTextureBuffer;
			timesNewTextureBufferDiffers = 0;
		}
		else {
			timesNewTextureBufferDiffers++;
		}
	}
	
	return;
}

VOID UpdateAnnunciators(VOID)
{
	DWORD newAnnunciators = 0x00000000;

	newAnnunciators = (BYTE)(Chipset.IORam[ANNCTRL] | (Chipset.IORam[ANNCTRL+1]<<4));
	// switch annunciators off if timer stopped
	if ((newAnnunciators & AON) == 0 || (Chipset.IORam[TIMER2_CTRL] & RUN) == 0)
		newAnnunciators = 0;

	newAnnunciators = newAnnunciators & (LA1 | LA2 | LA3 | LA4 | LA5 | LA6 );
	
	
	//additional annunciators
	if (Chipset.in != 0) {
		newAnnunciators |= LBTNDOWN;
	}
	
	if ((Chipset.IORam[BITOFFSET] & DON) != 0) {
		newAnnunciators |= LDON;
	}
	
	//drop statemachine, if no alpha
	/*
	if ((newAnnunciators & LA3)) {
		newAnnunciators |= currentAnnunciators & LALPHALOCK;
		newAnnunciators |= currentAnnunciators & LALPHASMALL;
	}
	*/
	newAnnunciators |= (xml->logicStateVec & LALPHALOCK);
	newAnnunciators |= (xml->logicStateVec & LALPHASMALL);
	
	xml->logicStateVec = (xml->logicStateVec & 0xFFFF0000) | (newAnnunciators & 0x0000FFFF);
	
	return;
}

static void* LcdThread(void * pParam)
{
	while (TimedWaitForEvent(&hEventLcd, &hEventLcdLock, &hEventLcdPredicate, DISPLAY_FREQ) == ETIMEDOUT)
	{
		if (lcdTextureBuffer)
			UpdateDisplay();				// update display
		QueryPerformanceCounter(&lLcdRef);	// actual time
	}
	return 0;
	UNREFERENCED_PARAMETER(pParam);
}

// LCD line counter calculation
BYTE GetLineCounter(VOID)
{
	LARGE_INTEGER lLC;
	BYTE          byTime;

	if (hCThreadLcd == NULL)				// display off
		return ((Chipset.IORam[LINECOUNT+1] & (LC5|LC4)) << 4) | Chipset.IORam[LINECOUNT];

	QueryPerformanceCounter(&lLC);			// get elapsed time since display update

	// elapsed ticks so far
	byTime = (BYTE) (((lLC.QuadPart - lLcdRef.QuadPart) << 12) / lFreq.QuadPart);

	if (byTime > 0x3F) byTime = 0x3F;		// all counts made

	return 0x3F - byTime;					// update display between VBL counter 0x3F-0x3E
}

VOID StartDisplay(BYTE byInitial)
{
	if (hCThreadLcd)						// LCD update thread running
		return;								// -> quit

	if (Chipset.IORam[BITOFFSET]&DON)		// display on?
	{
		// event to cancel Lcd refresh loop
		//CreateEvent(&hEventLcd, &hEventLcdLock, &hEventLcdPredicate);
		
		QueryPerformanceCounter(&lLcdRef);	// actual time of top line

		// adjust startup counter to get the right VBL value
		_ASSERT(byInitial <= 0x3F);			// line counter value 0 - 63
		lLcdRef.QuadPart -= ((LONGLONG) (0x3F - byInitial) * lFreq.QuadPart) >> 12;

		// start Lcd update thread
		//CreateThread(&hCThreadLcd, &LcdThread);
	}
	return;
}

VOID StopDisplay(VOID)
{
	BYTE a[2];
	ReadIO(a,LINECOUNT,2,TRUE);				// update VBL at display off time

	if (hCThreadLcd == NULL)				// thread stopped
		return;								// -> quit

	
	_ASSERT(hCThreadLcd);
	//SetEvent(&hEventLcd, &hEventLcdLock, &hEventLcdPredicate);	// leave Lcd update thread
	//(void) pthread_join(hCThreadLcd, NULL);
	//hCThreadLcd = NULL;		// set flag display update stopped								
	//DeleteEvent(&hEventLcd, &hEventLcdLock, &hEventLcdPredicate);  // close Lcd event
	
	return;
}

