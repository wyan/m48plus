/*
 *   mru.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2007 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "resource.h"
#import "emu48.h"

#define ABBREV_FILENAME_LEN 24				// max. length for filenames

#define WCE_FCTN(fctn) wce_##fctn

static TCHAR  szOriginal[MAX_PATH] = _T("");

static LPTSTR *ppszFiles = NULL;			// pointer to MRU table
static INT    nEntry = 0;					// no. of MRU entries

static HMENU  hMruMenu = NULL;				// menu for MRU list
static INT    nMruPos;						// insert position for MRU list

static DWORD GetCutPathName(LPCTSTR szFileName, LPTSTR szBuffer, DWORD dwBufferLength, INT nCutLength)
{
	LPCTSTR lpFilePart;
	INT     nPathLen,nMaxPathLen;
	
	_ASSERT(nCutLength >= 0);				// 0 = only drive and name

	szBuffer[dwBufferLength-1] = 0;			// set EOS in target buffer

	// search for file part
	if ((lpFilePart = _tcsrchr(szFileName,_T('\\'))) != NULL)
	{
		nPathLen = lpFilePart - szFileName;	// path length excl. \ to name
		++lpFilePart;
	}
	else
	{
		nPathLen = 0;						// no path
		lpFilePart = szFileName;
	}

	// maximum length for path
	nMaxPathLen = nCutLength - lstrlen(lpFilePart);

	if (nPathLen + 1 > nMaxPathLen)			// have to cut path
	{
		TCHAR cDirTemp[_MAX_PATH];
		LPCTSTR szPtr;

		INT nPos = 0;						// path buffer pos

		// skip volume
		if ((szPtr = _tcschr(szFileName + 1,_T('\\'))) != NULL)
		{
			INT nLength = szPtr - szFileName;

			// enough room for \volume and "\...\"
			if (nLength + 5 <= nMaxPathLen)
			{
				_tcsncpy(cDirTemp,szFileName,nLength);
				nPos += nLength;
				nMaxPathLen -= nLength;
			}
		}

		if (nMaxPathLen >= 5)				// enough room for "\...\"
		{
			lstrcpy(&cDirTemp[nPos],_T("\\..."));
			nPos += 4;
			nMaxPathLen -= 5;				// need 5 chars for additional "\..." + "\"
		}

		if (nPos > 0)						// wrote a path part
		{
			// get earliest possible '\' character
			szPtr = &szFileName[nPathLen - nMaxPathLen];
			VERIFY(lpFilePart = _tcschr(szPtr,_T('\\')));
		}

		lstrcpy(&cDirTemp[nPos],lpFilePart); // copy path with preample to dir buffer
		_tcsncpy(szBuffer,cDirTemp,dwBufferLength);
	}
	else
	{
		_tcsncpy(szBuffer,szFileName,dwBufferLength);
	}
	return lstrlen(szBuffer);
}

static int wce_GetMenuItemCount(HMENU hMenu)
{
	const int MAX_NUM_ITEMS = 256;
	int iPos, iCount;
  
	MENUITEMINFO mii;
	memset((char *)&mii, 0, sizeof(MENUITEMINFO));
	mii.cbSize = sizeof(MENUITEMINFO);
  
	iCount = 0;
	for (iPos = 0; iPos < MAX_NUM_ITEMS; iPos++)
	{
 		if (!GetMenuItemInfo(hMenu, (UINT)iPos, TRUE, &mii))
			break;
		iCount++;
	}
  
	return iCount;
}

static UINT wce_GetMenuItemID(HMENU hMenu, int nPos)
{	
	MENUITEMINFO mii;
	memset((char *)&mii, 0, sizeof(mii));
	mii.cbSize = sizeof(mii); 
	mii.fMask  = MIIM_ID;
	GetMenuItemInfo(hMenu, nPos, TRUE, &mii);
  
	return mii.wID; 
}

static int wce_GetMenuString(HMENU hMenu, UINT uIDItem, LPWSTR lpString, int nMaxCount, UINT uFlag)
{ 
	MENUITEMINFO mii;
	memset((char *)&mii, 0, sizeof(MENUITEMINFO));
	mii.cbSize = sizeof(MENUITEMINFO);

	if (!GetMenuItemInfo(hMenu, 0, TRUE, &mii))
		return 0;
	
	mii.fMask      = MIIM_TYPE;  // to get dwTypeData
	mii.fType      = MFT_STRING; // to get dwTypeData
	mii.dwTypeData = lpString;
	mii.cch        = nMaxCount;

	if (uFlag == MF_BYPOSITION)
		GetMenuItemInfo(hMenu, uIDItem, TRUE, &mii);
	else
	{
		_ASSERT(uFlag == MF_BYCOMMAND);
		GetMenuItemInfo(hMenu, uIDItem, FALSE, &mii);
	}

	if (mii.dwTypeData != NULL)
		return _tcslen(lpString);

	return 0;
}

static BOOL IsWM6Device(VOID)
{
	OSVERSIONINFO osvi;

	osvi.dwOSVersionInfoSize = sizeof(osvi);
	GetVersionEx(&osvi);

	return    osvi.dwPlatformId == VER_PLATFORM_WIN32_CE
		   && osvi.dwMajorVersion >= 5 && osvi.dwMinorVersion >= 2;
}

static BOOL GetMenuPosForId(HMENU hMenu, UINT nItem)
{
	UINT nID;
	INT i,nMaxID;

	nMaxID = WCE_FCTN(GetMenuItemCount(hMenu));
	for (i = 0; i < nMaxID; ++i)
	{
		nID = WCE_FCTN(GetMenuItemID(hMenu,i));	// get ID

		if (nID == 0) continue;				// separator or invalid command

		if (nID > 0xFFFF)					// pointer to a popup menu
		{
			// recursive search 
			if (GetMenuPosForId((HMENU) nID,nItem))
				return TRUE;

			continue;
		}

		if (nID == nItem)					// found ID
		{
			hMruMenu = hMenu;				// remember menu and position
			nMruPos = i;
			return TRUE;
		}
	}
	return FALSE;
}

BOOL MruInit(INT nNum)
{
	_ASSERT(ppszFiles == NULL);				// MRU already initialized

	// no. of files in MRU list
	nEntry = ReadSettingsInt(_T("MRU"),_T("FileCount"),nNum);

	if (nEntry > 0)							// allocate MRU table
	{
		// create MRU table
		if ((ppszFiles = HeapAlloc(hHeap,0,nEntry * sizeof(*ppszFiles))) == NULL)
			return TRUE;

		// fill each entry
		for (nNum = 0; nNum < nEntry; ++nNum)
			ppszFiles[nNum] = NULL;

		MruReadList();						// read actual MRU list
	}
	return FALSE;
}

VOID MruCleanup(VOID)
{
	INT i;

	MruWriteList();							// write actual MRU list
	
	for (i = 0; i < nEntry; ++i)			// cleanup each entry
	{
		if (ppszFiles[i] != NULL)
			HeapFree(hHeap,0,ppszFiles[i]);	// cleanup entry
	}

	if (ppszFiles != NULL)					// table defined
	{
		HeapFree(hHeap,0,ppszFiles);		// free table
		ppszFiles = NULL;
	}
	return;
}

VOID MruAdd(LPCTSTR lpszEntry)
{
	INT i;

	if (nEntry == 0) return;				// no entries

	// look if entry is already in table
	for (i = 0; i < nEntry; ++i)
	{
		// already in table -> quit
		if (   ppszFiles[i] != NULL
			&& lstrcmpi(ppszFiles[i],lpszEntry) == 0)
		{
			return;
		}
	}

	i = nEntry - 1;							// last index
	if (ppszFiles[i] != NULL)
		HeapFree(hHeap,0,ppszFiles[i]);		// free oldest entry

	for (; i > 0; --i)						// move old entries 1 line down
	{
		ppszFiles[i] = ppszFiles[i-1];
	}

	// add new entry to top
	ppszFiles[0] = DuplicateString(lpszEntry);
	return;
}

VOID MruRemove(INT nIndex)
{
	HeapFree(hHeap,0,ppszFiles[nIndex]);	// free entry

	for (; nIndex < nEntry - 1; ++nIndex)	// move old entries 1 line up
	{
		ppszFiles[nIndex] = ppszFiles[nIndex+1];
	}

	ppszFiles[nIndex] = NULL;				// clear last line
	return;
}

INT MruEntries(VOID)
{
	return nEntry;
}

LPCTSTR MruFilename(INT nIndex)
{
	_ASSERT(ppszFiles != NULL);				// MRU not initialized
	_ASSERT(nIndex >= 0 && nIndex < nEntry); // inside range

	return ppszFiles[nIndex];
}

VOID MruUpdateMenu(HMENU hMenu)
{
	BOOL bEmpty,bFound,bWM6OS;
	INT  i;

	if (*szOriginal == 0)					// get orginal value of first recent entry
	{
		VERIFY(WCE_FCTN(GetMenuString(hMenu,ID_FILE_MRU_FILE1,szOriginal,ARRAYSIZEOF(szOriginal),MF_BYCOMMAND)));
	}

	// look for menu position of ID_FILE_MRU_FILE1
	bFound = GetMenuPosForId(hMenu,ID_FILE_MRU_FILE1);

	if (bFound && nEntry == 0)				// no entries
	{
		// delete MRU menu
		DeleteMenu(hMruMenu,nMruPos,MF_BYPOSITION);

		// delete following separator
		DeleteMenu(hMruMenu,nMruPos,MF_BYPOSITION);
	}

	if (nEntry == 0) return;				// no entries

	_ASSERT(ppszFiles != NULL);				// MRU not initialized

	bEmpty = TRUE;							// MRU list empty
	for (i = 0; i < nEntry; ++i)			// delete all menu entries
	{
		DeleteMenu(hMenu,ID_FILE_MRU_FILE1+i,MF_BYCOMMAND);

		if (ppszFiles[i] != NULL)			// valid entry
			bEmpty = FALSE;					// MRU list not empty
	}
	
	if (bEmpty)								// empty MRU list
	{
		// fill with orginal string
		VERIFY(InsertMenu(hMruMenu,nMruPos,MF_STRING | MF_BYPOSITION | MF_GRAYED,ID_FILE_MRU_FILE1,szOriginal));
		return;
	}

	bWM6OS = IsWM6Device();					// check if WM6 device or later

	for (i = 0; i < nEntry; ++i)			// add menu entries
	{
		if (ppszFiles[i] != NULL)			// valid entry
		{
			TCHAR   szMenuname[2*MAX_PATH+3];
			TCHAR   szCutname[MAX_PATH];
			LPCTSTR lpszSrc;
			LPTSTR  lpszPtr;

			// cut filename to fit into menu
			GetCutPathName(ppszFiles[i],szCutname,ARRAYSIZEOF(szCutname),bWM6OS ? ABBREV_FILENAME_LEN : 30);
			lpszSrc = szCutname;

			lpszPtr = szMenuname;			// adding accelerator key
			*lpszPtr++ = _T('&');
			*lpszPtr++ = _T('0') + ((i + 1) % 10);
			*lpszPtr++ = _T(' ');

			// copy file to view buffer and expand & to &&
			while (*lpszSrc != 0)
			{
				if (*lpszSrc == _T('&'))
				{
					*lpszPtr++ = *lpszSrc;
				}
				*lpszPtr++ = *lpszSrc++;
			}
			*lpszPtr = 0;

			VERIFY(InsertMenu(hMruMenu,nMruPos+i,MF_STRING | MF_BYPOSITION,ID_FILE_MRU_FILE1+i,szMenuname));
		}
	}
	return;
}

VOID MruWriteList(VOID)
{
	TCHAR szItemname[32];
	INT i;

	// no. of files in MRU list
	WriteSettingsInt(_T("MRU"),_T("FileCount"),nEntry);

	for (i = 0; i < nEntry; ++i)			// add menu entries
	{
		_ASSERT(ppszFiles != NULL);			// MRU not initialized
		wsprintf(szItemname,_T("File%d"),i+1);
		if (ppszFiles[i] != NULL)
		{
			WriteSettingsString(_T("MRU"),szItemname,ppszFiles[i]);
		}
		else
		{
			DelSettingsKey(_T("MRU"),szItemname);
		}
	}
	return;
}

VOID MruReadList(VOID)
{
	TCHAR  szFilename[MAX_PATH];
	TCHAR  szItemname[32];
	LPTSTR lpszValue;
	INT i;

	_ASSERT(ppszFiles != NULL);				// MRU not initialized

	for (i = 0; i < nEntry; ++i)			// add menu entries
	{
		wsprintf(szItemname,_T("File%d"),i+1);
		ReadSettingsString(_T("MRU"),szItemname,_T(""),szFilename,ARRAYSIZEOF(szFilename));

		if (ppszFiles[i] != NULL)			// already filled
		{
			HeapFree(hHeap,0,ppszFiles[i]);	// free entry
			ppszFiles[i] = NULL;			// clear last line
			lpszValue = _T("");
		}
		
		if (*szFilename)					// read a valid entry
		{
			ppszFiles[i] = DuplicateString(szFilename);
		}
	}
	return;
}
