/*
 *   files.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "emu48.h"
#import "ops.h"
#import "io.h"								// I/O register definitions
#import "xml.h"
#import "m48Errors.h"
#import "i28f160.h"						// flash support



/*
#define MAX_PATH 255 //added temporarily by mksg.de 
TCHAR  szEmuDirectory[MAX_PATH];
TCHAR  szDocDirectory[MAX_PATH];
TCHAR  szCurrentKml[MAX_PATH];
TCHAR  szBackupKml[MAX_PATH];
TCHAR  szCurrentFilename[MAX_PATH];
TCHAR  szBackupFilename[MAX_PATH];
TCHAR  szBufferFilename[MAX_PATH];
TCHAR  szPort2Filename[MAX_PATH];
 */
#define MAX_PATH 255
char   szCurrentXml[MAX_PATH];

BYTE   cCurrentRomType = 0;					// Model -> hardware
UINT   nCurrentClass = 0;					// Class -> derivate
LPBYTE pbyRom = NULL;
BOOL   bRomWriteable = TRUE;				// flag if ROM writeable
DWORD  dwRomSize = 0;
LPBYTE pbyRomDirtyPage = NULL;
DWORD  dwRomDirtyPageSize;
WORD   wRomCrc = 0;							// fingerprint of patched ROM
LPBYTE pbyPort2 = NULL;
BOOL   bPort2Writeable = FALSE;
BOOL   bPort2IsShared = FALSE;
DWORD  dwPort2Size = 0;						// size of mapped port2
DWORD  dwPort2Mask = 0;
WORD   wPort2Crc = 0;						// fingerprint of port2
BOOL   bBackup = FALSE;

NSFileHandle * _romFile = nil;
NSFileHandle * _port2File = nil;
NSFileHandle * _port2Map = nil;

// document signatures
// legacy Emu48
//static BYTE pbySignatureA[16] = "Emu38 Document\xFE";
//static BYTE pbySignatureB[16] = "Emu39 Document\xFE";
//static BYTE pbySignatureE[16] = "Emu48 Document\xFE";
//static BYTE pbySignatureW[16] = "Win48 Document\xFE";
//static BYTE pbySignatureV[16] = "Emu49 Document\xFE";
// m48
static BYTE pbySignatureM[16] = "m48 Document 1\xFE";

//mksg static HANDLE hCurrentFile = NULL;

static BOOL    bRomPacked;

//################
//#
//#    Directory Helper Tool
//#
//################

// deleted mksg

//################
//#
//#    Patch
//#
//################

static __inline BYTE Asc2Nib(BYTE c)
{
	if (c<'0') return 0;
	if (c<='9') return c-'0';
	if (c<'A') return 0;
	if (c<='F') return c-'A'+10;
	if (c<'a') return 0;
	if (c<='f') return c-'a'+10;
	return 0;
}

// functions to restore ROM patches
typedef struct tnode
{
	BOOL   bPatch;							// TRUE = ROM address patched
	DWORD  dwAddress;						// patch address
	BYTE   byROM;							// original ROM value
	BYTE   byPatch;							// patched ROM value
	struct tnode *next;						// next node
} TREENODE;

static TREENODE *nodePatch = NULL;

static BOOL PatchNibble(DWORD dwAddress, BYTE byPatch)
{
	TREENODE *p;

	_ASSERT(pbyRom);						// ROM defined
	if ((p = (TREENODE *) malloc(sizeof(TREENODE))) == NULL)
		return TRUE;

	p->bPatch = TRUE;						// address patched
	p->dwAddress = dwAddress;				// save current values
	p->byROM = pbyRom[dwAddress];
	p->byPatch = byPatch;
	p->next = nodePatch;					// save node
	nodePatch = p;

	pbyRom[dwAddress] = byPatch;			// patch ROM
	return FALSE;
}

static VOID RestorePatches(VOID)
{
	TREENODE *p;

	_ASSERT(pbyRom);						// ROM defined
	while (nodePatch != NULL)
	{
		// restore original data
		pbyRom[nodePatch->dwAddress] = nodePatch->byROM;

		p = nodePatch->next;				// save pointer to next node
		free(nodePatch);					// free node
		nodePatch = p;						// new node
	}
	return;
}

VOID UpdatePatches(BOOL bPatch)
{
	TREENODE *p = nodePatch;

	_ASSERT(pbyRom);						// ROM defined
	while (p != NULL)
	{
		if (bPatch)							// patch ROM
		{
			if (!p->bPatch)					// patch only if not patched
			{
				// use original data for patch restore
				p->byROM = pbyRom[p->dwAddress];

				// restore patch data
				pbyRom[p->dwAddress] = p->byPatch;
				p->bPatch = TRUE;			// address patched
			}
			else
			{
				_ASSERT(FALSE);				// call ROM patch on a patched ROM
			}
		}
		else								// restore ROM
		{
			// restore original data
			pbyRom[p->dwAddress] = p->byROM;
			p->bPatch = FALSE;				// address not patched
		}

		p = p->next;						// next node
	}
	return;
}

BOOL PatchRom(NSString * filename)
{
	NSFileHandle * _file = nil;
	LARGE_INTEGER  dwFileSize = {0};
	//DWORD  lBytesRead = 0;
	LPBYTE    lpStop,lpBuf = NULL;
	DWORD  dwAddress = 0;
	UINT   nPos = 0;

	
	// Datei öffnen
	if ( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
		_file = [NSFileHandle fileHandleForReadingAtPath:filename];
	}
	else {
		return FALSE;
	}
	
	NSDictionary * tempFileAttributes =  [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL];
	dwFileSize.QuadPart = [[tempFileAttributes valueForKey:NSFileSize] intValue];

	if (dwFileSize.u.LowPart <= 5)
	{ // file is too small.
		[_file closeFile];
		return FALSE;
	}
	if (dwFileSize.u.HighPart != 0) // Sollte so ein Fall überhaupt berücksichtigt werden?
	{ // file is too large.
		[_file closeFile];
		return FALSE;
	}
	
	lpBuf = malloc(dwFileSize.u.LowPart+1);
	if (lpBuf == NULL)
	{
		[_file closeFile];
		return FALSE;
	}
	
	NSData * _tempData = [_file readDataOfLength:dwFileSize.u.LowPart];
	[_tempData getBytes:lpBuf];
	//ReadFile(hFile, lpBuf, dwFileSizeLow, &lBytesRead, NULL);
	[_file closeFile];
	lpBuf[dwFileSize.u.LowPart] = 0;
	nPos = 0;
	while (lpBuf[nPos])
	{
		do // remove blank space
		{
			if (  (lpBuf[nPos]!=' ')
				&&(lpBuf[nPos]!='\n')
				&&(lpBuf[nPos]!='\r')
				&&(lpBuf[nPos]!='\t')) break;
			nPos++;
		} while (lpBuf[nPos]);
		if (lpBuf[nPos]==';') // comment ?
		{
			do
			{
				nPos++;
				if (lpBuf[nPos]=='\n')
				{
					nPos++;
					break;
				}
			} while (lpBuf[nPos]);
			continue;
		}
		dwAddress = strtoul(&lpBuf[nPos], &lpStop, 16);
		nPos += (UINT) (lpStop - &lpBuf[nPos]) + 1;
		if (*lpStop != ':' || *lpStop == 0)
			continue;
		while (lpBuf[nPos])
		{
			if (isxdigit(lpBuf[nPos]) == FALSE) break;
			// patch ROM and save original nibble
			PatchNibble(dwAddress, Asc2Nib(lpBuf[nPos]));
			dwAddress = (dwAddress+1)&(dwRomSize-1);
			nPos++;
		}
	}
	free(lpBuf);
	return TRUE;
}



//################
//#
//#    ROM
//#
//################

BOOL CrcRom(WORD *pwChk)					// calculate fingerprint of ROM
{
	DWORD *pdwData,dwSize;
	DWORD dwChk = 0;

	_ASSERT(pbyRom);						// view on ROM
	pdwData = (DWORD *) pbyRom;

	_ASSERT((dwRomSize % sizeof(*pdwData)) == 0);
	dwSize = dwRomSize / sizeof(*pdwData);	// file size in DWORD's

	// use checksum, because it's faster
	while (dwSize-- > 0)
	{
		DWORD dwData = *pdwData++;
		if ((dwData & 0xF0F0F0F0) != 0)		// data packed?
			return FALSE;
		dwChk += dwData;
	}

	*pwChk = (WORD) ((dwChk >> 16) + (dwChk & 0xFFFF));
	return TRUE;
}

BOOL MapRom(NSString * filename)
{
	DWORD  dwSize,dwFileSize;

	// open ROM for writing
	BOOL bRomRW = (cCurrentRomType == 'X' || cCurrentRomType == 'Q') ? bRomWriteable : FALSE;

	if (pbyRom != NULL)
	{
		return FALSE;
	}
	
	if (bRomRW)								// ROM writeable
	{
		if ( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
			if ( [[NSFileManager defaultManager] isWritableFileAtPath:filename] ) {
				_romFile = [NSFileHandle fileHandleForUpdatingAtPath:filename];
			}
			else
			{ 
				bRomRW = FALSE; // ROM not writeable
				_romFile = [NSFileHandle fileHandleForReadingAtPath:filename];
				
			}
			
		}
		else {
			return FALSE;
		}
	}
	else
	{
		_romFile = [NSFileHandle fileHandleForReadingAtPath:filename];
	}
		

	if (_romFile == nil)
	{
		return FALSE;
	}
	[_romFile retain];

	NSDictionary * tempFileAttributes =  [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL];
	dwRomSize = [[tempFileAttributes valueForKey:NSFileSize] intValue];

	if (dwRomSize <= 4)
	{ // file is too small.
		
		[_romFile closeFile]; // Wird später Autoreleased
		_romFile = nil;
		dwRomSize = 0;
		return FALSE;
	}

	// read the first 4 bytes
	NSData * data = [_romFile readDataOfLength:sizeof(dwSize)];
	[data getBytes:&dwSize];
	

	dwFileSize = dwRomSize;					// calculate ROM image buffer size
	bRomPacked = (dwSize & 0xF0F0F0F0) != 0; // ROM image packed
	if (bRomPacked)	dwRomSize *= 2;			// unpacked ROM image has double size

	pbyRom = malloc(dwRomSize);
	if (pbyRom == NULL)
	{
		[_romFile closeFile]; 
		[_romFile release];
		_romFile = nil;
		dwRomSize = 0;
		return FALSE;
	}

	*(DWORD *) pbyRom = dwSize;			// save first 4 bytes

	// load rest of file content
	data = [_romFile readDataOfLength:(dwFileSize - sizeof(dwSize))];
	[data getBytes:&pbyRom[sizeof(dwSize)]];
	//mksg funktioniert so nicht mehr _ASSERT(dwFileSize - sizeof(dwSize) == dwRead);

	if (bRomRW)								// ROM is writeable
	{
		// no. of dirty pages
		dwRomDirtyPageSize = dwRomSize / ROMPAGESIZE;

		// alloc dirty page table
		pbyRomDirtyPage = malloc(sizeof(*pbyRomDirtyPage) * dwRomDirtyPageSize);
		if (pbyRomDirtyPage == NULL)
		{
			free(pbyRom);	// free ROM image
			pbyRom = NULL;
			[_romFile closeFile];
			[_romFile release];
			_romFile = nil;
			dwRomSize = 0;
			return FALSE;
		}
	}
	else
	{
		[_romFile closeFile];
		[_romFile release];
		_romFile = nil;
	}

	if (bRomPacked)						// packed ROM image
	{
		dwSize = dwRomSize;				// destination start address
		while (dwFileSize > 0)			// unpack source
		{
			BYTE byValue = pbyRom[--dwFileSize];
			pbyRom[--dwSize] = byValue >> 4;
			pbyRom[--dwSize] = byValue & 0xF;
		}
	}
	return TRUE;
}

VOID UnmapRom(VOID)
{
	if (pbyRom == NULL) return;				// ROM not mapped
	if (_romFile != nil)					// ROM file still open
	{
		DWORD i,dwLastPos;

		RestorePatches();					// restore ROM Patches
		dwLastPos = (DWORD) -1;				// last writing position

		// scan every dirty page
		for (i = 0; i < dwRomDirtyPageSize; i++)
		{
			if (pbyRomDirtyPage[i])			// page dirty
			{
				DWORD dwSize,dwLinPos,dwFilePos,dwWritten;

				dwSize = ROMPAGESIZE;		// bytes to write
				dwLinPos = i * ROMPAGESIZE;	// position inside emulator memory
				dwFilePos = dwLinPos;		// ROM file position

				if (bRomPacked)				// repack data
				{
					LPBYTE pbySrc,pbyDest;
					DWORD  j;

					dwSize /= 2;			// adjust no. of bytes to write
					dwFilePos /= 2;			// linear pos in packed file

					// pack data in page
					pbySrc = pbyDest = &pbyRom[dwLinPos];
					for (j = 0; j < dwSize; j++)
					{
						*pbyDest =  *pbySrc++;
						*pbyDest |= *pbySrc++ << 4;
						pbyDest++;
					}
				}

				if (dwLastPos != dwFilePos)	// not last writing position
				{
					[_romFile seekToFileOffset:0];
					//SetFilePointer(hRomFile,dwFilePos,NULL,FILE_BEGIN);
				}

				// Quick fix / we do not write the ROM when leaving
				//[_romFile writeData:[NSData dataWithBytes:&pbyRom[dwLinPos] length:dwSize]];
				dwWritten = dwSize;
				//WriteFile(hRomFile,&pbyRom[dwLinPos],dwSize,&dwWritten,NULL);
				dwLastPos = dwFilePos + dwSize;
			}
		}

		_ASSERT(pbyRomDirtyPage);
		free(pbyRomDirtyPage);
		[_romFile closeFile];
		[_romFile release];
		_romFile = nil;
		pbyRomDirtyPage = NULL;
	}

	free(pbyRom);		// free ROM image
	pbyRom = NULL;
	dwRomSize = 0;
	wRomCrc = 0;
	return;
}



//################
//#
//#    Port2
//#
//################

BOOL CrcPort2(WORD *pwCrc)					// calculate fingerprint of port2
{
	DWORD dwCount;
	DWORD dwFileSize;

	*pwCrc = 0;

	// port2 CRC isn't available
	if (pbyPort2 == NULL) return TRUE;

	//dwFileSize = GetFileSize(hPort2File, &dwCount); // get real filesize
	_ASSERT(dwCount == 0);					// isn't created by MapPort2()
    dwFileSize = 4*1024*1024;

	for (dwCount = 0;dwCount < dwFileSize; ++dwCount)
	{
		if ((pbyPort2[dwCount] & 0xF0) != 0) // data packed?
			return FALSE;

		*pwCrc = (*pwCrc >> 4) ^ (((*pwCrc ^ ((WORD) pbyPort2[dwCount])) & 0xf) * 0x1081);
	}
	return TRUE;
}

BOOL MapPort2(NSString * filename)
{
	// Dirty hack to create empty 4MB
	DWORD dwFileSizeLo = 4*1024*1024;
	pbyPort2 = malloc(dwFileSizeLo);
    bPort2Writeable = TRUE;
	dwPort2Mask = (dwFileSizeLo - 1) >> 18;
	dwPort2Size = dwFileSizeLo / 2048;
	return TRUE;
	/*
	DWORD dwFileSizeLo, dwFileSizeHi, dwCount;

	if (pbyPort2 != NULL) return FALSE;
	bPort2Writeable = TRUE;
	dwPort2Size = 0;						// reset size of port2

	if ( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
		if ( [[NSFileManager defaultManager] isWritableFileAtPath:filename] ) {
			_port2File = [NSFileHandle fileHandleForUpdatingAtPath:filename];
		}
		else {
			bPort2Writeable = FALSE;
			_port2File = [NSFileHandle fileHandleForReadingAtPath:filename];
		}
	}
	else {
		// Dirty hack: einfach eine leere Datei mit dem Namen erzeugen
		_romFile = [NSFileHandle fileHandleForUpdatingAtPath:filename];
	}
	
	if (_romFile == nil)
	{
		return FALSE;
	}
			
	NSDictionary * tempFileAttributes =  [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL];
	dwFileSizeLo = [[tempFileAttributes valueForKey:NSFileSize] intValue];
	
	if (dwFileSizeLo > (4*1024*1024) ) // Limit soll 4MB sein
	{ // file is too large.
		[_port2File closeFile];
		_port2File = nil;
		dwPort2Mask = 0;
		bPort2Writeable = FALSE;
		return FALSE;
	}

	// count number of set bits
	for (dwCount = 0, dwFileSizeHi = dwFileSizeLo; dwFileSizeHi != 0;dwFileSizeHi >>= 1)
	{
		if ((dwFileSizeHi & 0x1) != 0) ++dwCount;
	}

	// size not 32, 128, 256, 512, 1024, 2048 or 4096 KB
	if (dwCount != 1 || (dwFileSizeLo & 0xFF02FFFF) != 0)
	{
		[_port2File closeFile];
		_port2File = nil;
		dwPort2Mask = 0;
		bPort2Writeable = FALSE;
		return FALSE;
	}
	
	dwPort2Mask = (dwFileSizeLo - 1) >> 18;	// mask for valid address lines of the BS-FF
	
	
	hPort2Map = CreateFileMapping(hPort2File, NULL, bPort2Writeable ? PAGE_READWRITE : PAGE_READONLY,
								  0, dwFileSizeLo, NULL);
	if (hPort2Map == NULL)
	{
		CloseHandle(hPort2File);
		hPort2File = NULL;
		dwPort2Mask = 0;
		bPort2Writeable = FALSE;
		return FALSE;
	}
	pbyPort2 = MapViewOfFile(hPort2Map, bPort2Writeable ? FILE_MAP_WRITE : FILE_MAP_READ, 0, 0, dwFileSizeLo);
	if (pbyPort2 == NULL)
	{
		CloseHandle(hPort2Map);
		CloseHandle(hPort2File);
		hPort2Map = NULL;
		hPort2File = NULL;
		dwPort2Mask = 0;
		bPort2Writeable = FALSE;
		return FALSE;
	}
	dwPort2Size = dwFileSizeLo / 2048;		// mapping size of port2

	if (CrcPort2(&wPort2Crc) == FALSE)		// calculate fingerprint of port2
	{
		UnmapPort2();						// free memory
		AbortMessage(_T("Packed Port 2 image detected!"));
		return FALSE;
	}
	return TRUE; */
}

VOID UnmapPort2(VOID)
{
	if (pbyPort2 == NULL) return;
	//UnmapViewOfFile(pbyPort2);
	//CloseHandle(hPort2Map);
	//CloseHandle(hPort2File);
    free(pbyPort2);
	pbyPort2 = NULL;
	//hPort2Map = NULL;
	//hPort2File = NULL;
	dwPort2Size = 0;						// reset size of port2
	dwPort2Mask = 0;
	bPort2Writeable = FALSE;
	wPort2Crc = 0;
	return;
}



//################
//#
//#    Documents
//#
//################

VOID ResetDocument(VOID)
{
	UnmapRom();

	KillXML();
	
	//if (hCurrentFile)
	//{
	//	CloseHandle(hCurrentFile);
	//	hCurrentFile = NULL;
	//}
	//szCurrentKml[0] = 0;
	//szCurrentFilename[0]=0;
	
	if (Chipset.Port0) free(Chipset.Port0);
	if (Chipset.Port1) free(Chipset.Port1);
	if (Chipset.Port2) free(Chipset.Port2); else UnmapPort2();
	ZeroMemory(&Chipset,sizeof(Chipset));
	ZeroMemory(&RMap,sizeof(RMap));			// delete MMU mappings
	ZeroMemory(&WMap,sizeof(WMap));
	return;
}

BOOL NewDocument(NSString * xmlFilename, NSError ** error) {
	NSString * errorString;
	
	//SaveBackup();
	ResetDocument();
	if (error != NULL) {
		*error = nil;
	}

	if (!InitXML(xmlFilename, error)) goto restore;

	// Try loading the ROM
	// Map Rom
	if (!(MapRom(getFullDocumentsPathForFile(xml->global->romFilename)))) {
		if (error != NULL) {
			errorString = @"Could not open specified ROM-file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		goto restore;
	}
	cCurrentRomType = xml->global->model;
	// Patch Rom
	if (xml->global->patchFilename != nil) {
		if (!(PatchRom(getFullDocumentsPathForFile(xml->global->patchFilename)))) {
			if (error != NULL) {
				errorString = @"Could not patch ROM.";
				*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			}
			goto restore;
		}
	}
	
	
	Chipset.nPosX = 0;
	Chipset.nPosY = 0;
	Chipset.type = cCurrentRomType;

	if (Chipset.type == '6' || Chipset.type == 'A')	// HP38G
	{
		Chipset.Port0Size = (Chipset.type == 'A') ? 32 : 64;
		Chipset.Port1Size = 0;
		Chipset.Port2Size = 0;

		Chipset.cards_status = 0x0;
	}
	if (Chipset.type == 'E')				// HP39/40G
	{
		Chipset.Port0Size = 128;
		Chipset.Port1Size = 0;
		Chipset.Port2Size = 128;

		Chipset.cards_status = 0xF;

		bPort2Writeable = TRUE;				// port2 is writeable
	}
	if (Chipset.type == 'S')				// HP48SX
	{
		Chipset.Port0Size = 32;
		Chipset.Port1Size = 128;
		Chipset.Port2Size = 0;

		Chipset.cards_status = 0x5;

		// use 2nd command line argument if defined
		//MapPort2((nArgc < 3) ? szPort2Filename : ppArgv[2]);
		//MapPort2(getFullDocumentsPathForFile(@"TestPort2File"));
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"emulatorPort2Enabled"] == YES) {
            MapPort2(@"nix");
        }
	}
	if (Chipset.type == 'G')				// HP48GX
	{
		Chipset.Port0Size = 128;
		Chipset.Port1Size = 128;
		Chipset.Port2Size = 0;

		Chipset.cards_status = 0xA;
		
		// use 2nd command line argument if defined
		//MapPort2((nArgc < 3) ? szPort2Filename : ppArgv[2]);
		//MapPort2(getFullDocumentsPathForFile(@"TestPort2File"));
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"emulatorPort2Enabled"] == YES) {
            MapPort2(@"nix");
        }
	}
	if (Chipset.type == 'X')				// HP49G
	{
		Chipset.Port0Size = 256;
		Chipset.Port1Size = 128;
		Chipset.Port2Size = 128;

		Chipset.cards_status = 0xF;
		bPort2Writeable = TRUE;				// port2 is writeable

		FlashInit();						// init flash structure
	}
	if (Chipset.type == 'Q')				// HP50G
	{
		Chipset.Port0Size = 256;
		Chipset.Port1Size = 128;
		Chipset.Port2Size = 463;            // MZI 463 * 2048 = 1MB
        
		Chipset.cards_status = 0xF;
		bPort2Writeable = TRUE;				// port2 is writeable
        
		FlashInit();						// init flash structure
        Chipset.d0size = 16;
	}

	Chipset.IORam[LPE] = RST;				// set ReSeT bit at power on reset

	// allocate port memory
	if (Chipset.Port0Size)
	{
		Chipset.Port0 = malloc(Chipset.Port0Size*2048);
		_ASSERT(Chipset.Port0 != NULL);
	}
	if (Chipset.Port1Size)
	{
		Chipset.Port1 = malloc(Chipset.Port1Size*2048);
		_ASSERT(Chipset.Port1 != NULL);
	}
	if (Chipset.Port2Size)
	{
		Chipset.Port2 = malloc(Chipset.Port2Size*2048);
		_ASSERT(Chipset.Port2 != NULL);
	}
	RomSwitch(0);							// boot ROM view of HP49G and map memory
	return TRUE;
restore:
	//RestoreBackup();
	//ResetBackup();

	// HP48SX/GX
	if (Chipset.type == 'S' || Chipset.type == 'G')
	{
		// use 2nd command line argument if defined
		//MapPort2((nArgc < 3) ? szPort2Filename : ppArgv[2]);
		//MapPort2(getFullDocumentsPathForFile(@"TestPort2File"));
	}
	if (pbyRom)
	{
		Map(0x00,0xFF);
	}
	return FALSE;
}



BOOL OpenDocument(NSString * documentFilename, NSError ** error) {
		
	NSFileHandle * hFile = nil;
	
	NSString * errorString;
	
	DWORD   lBytesRead,lSizeofChipset;
	BYTE    pbyFileSignature[16];
	LPBYTE  pbySig;
	UINT    ctBytesCompared;
	UINT    nLength;
	
	//mksg SaveBackup();
	ResetDocument();
	printf("Opening document at %s\n", documentFilename.cString);
	
	// Datei öffnen
	if ( [[NSFileManager defaultManager] fileExistsAtPath:documentFilename] ) {
		hFile = [NSFileHandle fileHandleForReadingAtPath:documentFilename];
	}
	else {
		if (error != NULL) {
			errorString = @"Could not open document.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		goto restore;
	}
	

	// Read and Compare signature
	ReadFile(hFile, pbyFileSignature, 16, &lBytesRead, NULL);
	switch (pbyFileSignature[0])
	{
		/* Support muss später wegen LittleEndian, BigEndian implementiert werden 
		case 'E':
			pbySig = (pbyFileSignature[3] == '3')
			? ((pbyFileSignature[4] == '8') ? pbySignatureA : pbySignatureB)
			: ((pbyFileSignature[4] == '8') ? pbySignatureE : pbySignatureV);
			for (ctBytesCompared=0; ctBytesCompared<14; ctBytesCompared++)
			{
				if (pbyFileSignature[ctBytesCompared]!=pbySig[ctBytesCompared])
				{					
					errorString = @"This file is not a valid Emu48 file.";
					*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
					goto restore;
				}
			}
			break;
		case 'W':
			for (ctBytesCompared=0; ctBytesCompared<14; ctBytesCompared++)
			{
				if (pbyFileSignature[ctBytesCompared]!=pbySignatureW[ctBytesCompared])
				{
					errorString = @"This file is not a valid Win48 file.";
					*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
					goto restore;
				}
			}
			break;
		*/
		case 'm':
			pbySig = pbySignatureM;
			for (ctBytesCompared=0; ctBytesCompared<14; ctBytesCompared++)
			{
				if (pbyFileSignature[ctBytesCompared]!=pbySig[ctBytesCompared])
				{
					if (error != NULL) {
						errorString = @"This file is not a valid m48 file.";
						*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
					}
					goto restore;
				}
			}
			break;
		default:
			if (error != NULL) {
				errorString = @"This file is not a valid file.";
				*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			}
			goto restore;
	}
	
	switch (pbyFileSignature[14])
	{
		case 0xFE: // Win48 2.1 / Emu4x 0.99.x format

			ReadFile(hFile, &nLength, sizeof(nLength), &lBytesRead, NULL);
		
			ReadFile(hFile, (void *) szCurrentXml, nLength, &lBytesRead, NULL);
			
			if (nLength != lBytesRead) goto read_err;
			szCurrentXml[nLength] = 0;
			break;
		case 0xFF: // Win48 2.05 format
			break;
		default:
			errorString = @"This file is for an unknown version of Emu48.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			goto restore;
	}
	
	// read chipset size inside file
	ReadFile(hFile, &lSizeofChipset, sizeof(lSizeofChipset), &lBytesRead, NULL);
	if (lBytesRead != sizeof(lSizeofChipset)) goto read_err;
	if (lSizeofChipset <= sizeof(Chipset))	// actual or older chipset version
	{
		// read chipset content
		ZeroMemory(&Chipset,sizeof(Chipset));	// init chipset
		ReadFile(hFile, &Chipset, lSizeofChipset, &lBytesRead, NULL);
	}
	else									// newer chipset version
	{
		// read my used chipset content
		ReadFile(hFile, &Chipset, sizeof(Chipset), &lBytesRead, NULL);
		
		// skip rest of chipset
		[hFile seekToFileOffset:([hFile offsetInFile] + lSizeofChipset-sizeof(Chipset))];
		lSizeofChipset = sizeof(Chipset);
	}
	Chipset.Port0 = NULL;					// delete invalid port pointers
	Chipset.Port1 = NULL;
	Chipset.Port2 = NULL;
	if (lBytesRead != lSizeofChipset) goto read_err;
	
	if (!isModelValid(Chipset.type))		// check for valid model in emulator state file
	{
		errorString = @"Emulator state file with invalid calculator model.";
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		goto restore;
	}
	

	if (szCurrentXml[0])
	{
		BOOL bOK = FALSE;
		
		// Look if we have the cached skin-file
		//DEBUG NSLog(@"Load cached xml");
		bOK = TryGetXmlCacheFile();
		
		if (!bOK) {
			//DEBUG NSLog(@"Load xml");
			bOK = InitXML(getFullDocumentsPathForFileUTF8(szCurrentXml), error);
            printf("Opening XML at %s\n", getFullDocumentsPathForFileUTF8(szCurrentXml).cString);
		}
		//DEBUG NSLog(@"Finished loading xml");
		//bOK = bOK && (cCurrentRomType == Chipset.type);
		bOK = bOK && (xml->global->model == Chipset.type);
		if (!bOK) goto restore;
	}
	else {
		errorString = @"Could not load xml-File.";
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		goto restore;
	}
	
	// Try loading the ROM
	// Map Rom
	if (!(MapRom(getFullDocumentsPathForFile(xml->global->romFilename)))) {
		errorString = @"Could not open specified ROM-file.";
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		goto restore;
	}
	cCurrentRomType = xml->global->model;
	// Patch Rom
	if (xml->global->patchFilename != nil) {
		if (!(PatchRom(getFullDocumentsPathForFile(xml->global->patchFilename)))) {
			errorString = @"Could not patch ROM.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			goto restore;
		}
	}
	
	// reload old button state
	ReloadButtons(Chipset.Keyboard_Row,sizeof(Chipset.Keyboard_Row));
	
	FlashInit();							// init flash structure
	
	if (Chipset.Port0Size)
	{
		Chipset.Port0 = malloc(Chipset.Port0Size*2048);
		if (Chipset.Port0 == NULL)
		{
			errorString = @"Error allocating memory.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			//DEBUG NSLog(@"Memory allocation Failure.");
			goto restore;
		}
		
		ReadFile(hFile, Chipset.Port0, Chipset.Port0Size*2048, &lBytesRead, NULL);
		if (lBytesRead != Chipset.Port0Size*2048) goto read_err;
	}
	
	if (Chipset.Port1Size)
	{
		Chipset.Port1 = malloc(Chipset.Port1Size*2048);
		if (Chipset.Port1 == NULL)
		{
			errorString = @"Error allocating memory.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
			//DEBUG NSLog(@"Memory allocation Failure.");
			goto restore;
		}
		
		ReadFile(hFile, Chipset.Port1, Chipset.Port1Size*2048, &lBytesRead, NULL);
		if (lBytesRead != Chipset.Port1Size*2048) goto read_err;
	}
	
	// HP48SX/GX
	if (cCurrentRomType=='S' || cCurrentRomType=='G')
	{
		//mksg MapPort2((nArgc < 3) ? szPort2Filename : ppArgv[2]);
        if (Chipset.Port2Size) { // indicates if this calculator was created with a port 2
            Chipset.Port2Size = 0;
            MapPort2(@"");
            if (pbyPort2 == NULL)
            {
                errorString = @"Error allocating memory.";
                *error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
                //DEBUG NSLog(@"Memory allocation Failure.");
                goto restore;
            }
            ReadFile(hFile, pbyPort2, dwPort2Size*2048, &lBytesRead, NULL);
            if (lBytesRead != dwPort2Size*2048) goto read_err;
            wRomCrc = Chipset.wPort2Crc;
        }
        
        /*
		// port2 changed and card detection enabled
		if (    Chipset.wPort2Crc != wPort2Crc
			&& (Chipset.IORam[CARDCTL] & ECDT) != 0 && (Chipset.IORam[TIMER2_CTRL] & RUN) != 0
			)
		{
			Chipset.HST |= MP;				// set Module Pulled
			IOBit(SRQ2,NINT,FALSE);			// set NINT to low
			Chipset.SoftInt = TRUE;			// set interrupt
			bInterrupt = TRUE;
		}
         */
	}
	else									// HP38G, HP39/40G, HP49G
	{
		if (Chipset.Port2Size)
		{
			Chipset.Port2 =malloc(Chipset.Port2Size*2048);
			if (Chipset.Port2 == NULL)
			{
				errorString = @"Error allocating memory.";
				*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
				//DEBUG NSLog(@"Memory allocation Failure.");
				goto restore;
			}
			
			ReadFile(hFile, Chipset.Port2, Chipset.Port2Size*2048, &lBytesRead, NULL);
			if (lBytesRead != Chipset.Port2Size*2048) goto read_err;
			
			bPort2Writeable = TRUE;
			Chipset.cards_status = 0xF;
		}
	}
	
	// Annunciators (da diese die Statemachine enthalten)
	/* ALT ... wir speichern nur ein Emu48-Fileformat und die logic wird in der XmlCache gespeichert
	nLength = sizeof(currentAnnunciators);
	ReadFile(hFile, &currentAnnunciators, nLength, &lBytesRead, NULL); 
	*/
	
	RomSwitch(Chipset.Bank_FF);				// reload ROM view of HP49G and map memory
    
	if (Chipset.wRomCrc != wRomCrc)			// ROM changed
	{
		CpuReset();
		Chipset.Shutdn = FALSE;				// automatic restart
	}
     
	
	//mksg strcpy(szCurrentFilename, szFilename);
	_ASSERT(hCurrentFile == NULL);
	
	[hFile closeFile];
	*error = nil;
	return TRUE;
	
read_err:
	errorString = @"This file must be truncated, and cannot be loaded.";
	*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
	goto restore;
	////DEBUG NSLog(@"This file must be truncated, and cannot be loaded.");
restore:
	if (nil != hFile)		// close if valid handle
		[hFile closeFile];
	//mksg RestoreBackup();
	//mksg ResetBackup();
	
	// HP48SX/GX
	if (cCurrentRomType=='S' || cCurrentRomType=='G')
	{
		// use 2nd command line argument if defined
		//mksg MapPort2((nArgc < 3) ? szPort2Filename : ppArgv[2]);
	}
	return FALSE;
}

BOOL WriteDocument(NSString * documentFilename, NSError ** error) {
	[[NSFileManager defaultManager] createFileAtPath:documentFilename contents:nil attributes:nil];
	NSFileHandle * file = [NSFileHandle fileHandleForWritingAtPath:documentFilename];
	
	NSString * errorString;
	
	if (file == nil) {
		if (error != NULL) {
			errorString = @"File could not be saved.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
		
	DWORD nLength;
	
	// Dokumentsignatur
	[file writeData:[NSData dataWithBytes:pbySignatureM length:16]];
	
	// Xml-Dateiname
	NSString * currentXmlFilenameAndDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlDirectory"];
	currentXmlFilenameAndDirectory = [currentXmlFilenameAndDirectory stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] stringForKey:@"internalCurrentXmlFilename"]];
	const char * currentXmlFilenameAndDirectoryUTF8;
	currentXmlFilenameAndDirectoryUTF8 = [currentXmlFilenameAndDirectory UTF8String];
	
	nLength = strlen(currentXmlFilenameAndDirectoryUTF8);
	[file writeData:[NSData dataWithBytes:&nLength length:sizeof(nLength)]]; 
	[file writeData:[NSData dataWithBytes:currentXmlFilenameAndDirectoryUTF8 length:nLength]]; 
	
	// Chipset
    // Dirty Port 2 support
    CrcPort2(&(Chipset.wPort2Crc)); 
    if ((cCurrentRomType == 'S') || (cCurrentRomType == 'G')) {
        if (pbyPort2) {
            Chipset.Port2Size = dwPort2Size*2048;
        }
    }
    
	nLength = sizeof(Chipset);
	[file writeData:[NSData dataWithBytes:&nLength length:sizeof(nLength)]]; 
	[file writeData:[NSData dataWithBytes:&Chipset length:nLength]]; 
	
	// Ports
	if (Chipset.Port0Size)
	{
		[file writeData:[NSData dataWithBytes:Chipset.Port0 length:Chipset.Port0Size*2048]];
	}
	if (Chipset.Port1Size)
	{
		[file writeData:[NSData dataWithBytes:Chipset.Port1 length:Chipset.Port1Size*2048]];
	}
    if ((cCurrentRomType == 'S') || (cCurrentRomType == 'G')) {
        if (pbyPort2) {
            [file writeData:[NSData dataWithBytes:pbyPort2 length:dwPort2Size*2048]];
        }
    }
    else {
        if (Chipset.Port2Size)
        {            
            [file writeData:[NSData dataWithBytes:Chipset.Port2 length:Chipset.Port2Size*2048]];
        } 
    }
	
	// Annunciators (da diese die statemachine enthalten, ans Ende gestellt, damit dies in Zukunft vielleicht wieder rausgenommern werden kann)
	/*
	nLength = sizeof(currentAnnunciators);
	[file writeData:[NSData dataWithBytes:&currentAnnunciators length:nLength]]; 	
	 */
	
	[file closeFile];
	return YES;
}

//################
//#
//#    Load and Save HP48 Objects
//#
//################

//mksg: copied from EMU48MS118

WORD WriteStack(UINT nStkLevel,LPBYTE lpBuf,DWORD dwSize)	// separated from LoadObject()
{
	BOOL   bBinary;
	DWORD  dwAddress, i;
	
	bBinary =  ((lpBuf[dwSize+0]=='H')
				&&  (lpBuf[dwSize+1]=='P')
				&&  (lpBuf[dwSize+2]=='H')
				&&  (lpBuf[dwSize+3]=='P')
				&&  (lpBuf[dwSize+4]=='4')
				&&  (lpBuf[dwSize+5]==((cCurrentRomType!='X') ? '8' : '9'))
				&&  (lpBuf[dwSize+6]=='-'));
	
	for (dwAddress = 0, i = 0; i < dwSize; i++)
	{
		BYTE byTwoNibs = lpBuf[i+dwSize];
		lpBuf[dwAddress++] = (BYTE)(byTwoNibs&0xF);
		lpBuf[dwAddress++] = (BYTE)(byTwoNibs>>4);
	}
	
	dwSize = dwAddress;						// unpacked buffer size
	
	if (bBinary == TRUE)
	{ // load as binary
		dwSize = RPL_ObjectSize(lpBuf+16,dwSize-16);
		if (dwSize == BAD_OB) return S_ERR_OBJECT;
		dwAddress = RPL_CreateTemp(dwSize);
		if (dwAddress == 0) return S_ERR_BINARY;
		Nwrite(lpBuf+16,dwAddress,dwSize);
	}
	else
	{ // load as string
		dwAddress = RPL_CreateTemp(dwSize+10);
		if (dwAddress == 0) return S_ERR_ASCII;
		Write5(dwAddress,0x02A2C);			// String
		Write5(dwAddress+5,dwSize+5);		// length of String
		Nwrite(lpBuf,dwAddress+10,dwSize);	// data
	}
	RPL_Push(nStkLevel,dwAddress);
	return S_ERR_NO;
}

#ifdef VERSIONPLUS
BOOL LoadObject(NSString * filename, NSError ** error)			// separated stack writing part
{
	NSFileHandle * hFile = nil;
	NSString * errorString;
	
	DWORD  dwFileSizeLow;
	DWORD  dwFileSizeHigh;
	LPBYTE lpBuf;
	WORD   wError;
	
	// Datei öffnen
	if ( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
		hFile = [NSFileHandle fileHandleForReadingAtPath:filename];
	}
	else {
		if (error != NULL) {
			errorString = @"Could not open file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	
	
	NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL];
	NSNumber * fileSize = [attributes objectForKey:NSFileSize];
	
	// Allow may 20;B
	if ([fileSize unsignedLongLongValue] > 10*1024*1024) {
		[hFile closeFile];
		return FALSE;
	}		
	
	dwFileSizeLow = [fileSize intValue];
	
	lpBuf = malloc(dwFileSizeLow*2);
	if (lpBuf == NULL)
	{
		[hFile closeFile];
		return FALSE;
	}
	ReadFile(hFile, lpBuf+dwFileSizeLow, dwFileSizeLow, &dwFileSizeHigh, NULL);
	[hFile closeFile];
	
	wError = WriteStack(1,lpBuf,dwFileSizeLow);
	
	if (wError == S_ERR_OBJECT) {
		if (error != NULL) {
			errorString = @"This isn't a valid binary file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
	}
	
	if (wError == S_ERR_BINARY) {
		if (error != NULL) {
			errorString = @"The calculator does not have enough free memory to load this binary file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
	}
	
	if (wError == S_ERR_ASCII) {
		if (error != NULL) {
			errorString = @"The calculator does not have enough free memory to load this text file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
	}
	
	free(lpBuf);
	return (wError == S_ERR_NO);
}


BOOL SaveObject(NSString * filename, NSError ** error)			// separated stack reading part
{
	NSFileHandle * hFile = nil;
	NSString * errorString;
	
	LPBYTE  pbyHeader;
	DWORD	lBytesWritten;
	DWORD   dwAddress;
	DWORD   dwLength;
	
	dwAddress = RPL_Pick(1);
	if (dwAddress == 0)
	{
		if (error != NULL) {
			errorString = @"Too few arguments.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return FALSE;
	}
	dwLength = (RPL_SkipOb(dwAddress) - dwAddress + 1) / 2;
	
	// Datei öffnen/überschreiben
	[[NSFileManager defaultManager] createFileAtPath:filename contents:nil attributes:nil];
	hFile = [NSFileHandle fileHandleForWritingAtPath:filename];
	if (hFile == nil) {
		if (error != NULL) {
			errorString = @"Could not open file.";
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	pbyHeader = (Chipset.type != 'X') ? BINARYHEADER48 : BINARYHEADER49;
	WriteFile(hFile, pbyHeader, 8, &lBytesWritten, NULL);
	
	while (dwLength--)
	{
		BYTE byByte = Read2(dwAddress);
		WriteFile(hFile, &byByte, 1, &lBytesWritten, NULL);
		dwAddress += 2;
	}
	
	[hFile closeFile];
	return TRUE;
}
#endif
