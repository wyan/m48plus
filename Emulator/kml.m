/*
 *   kml.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "patchwince.h"

#include "emu48.h"
#include "kml.h"


// #define LONGHOLDTIME	750					// key long hold detection time in ms

static VOID			FatalError(VOID);
static VOID			InitLex(NSString * szScript);
static VOID			CleanLex(VOID);
static VOID			SkipWhite(UINT nMode);
static TokenId		ParseToken(UINT nMode);
static DWORD		ParseInteger(VOID);
static char *		ParseString(VOID);
static TokenId		Lex(UINT nMode);
static KmlLine*		ParseLine(TokenId eCommand);
static KmlLine*		ParseLines(VOID);
static KmlBlock*	ParseBlock(TokenId eBlock);
static KmlBlock*	ParseBlocks(VOID);
static VOID			FreeLines(KmlLine* pLine);
static VOID			FreeBlocks(KmlBlock* pBlock);
//static VOID			PressButton(UINT nId);
//static VOID			ReleaseButton(UINT nId);
//static VOID			PressButtonById(UINT nId);
//static VOID			ReleaseButtonById(UINT nId);
//static NSString *   GetStringParam(KmlBlock* pBlock, TokenId eBlock, TokenId eCommand, UINT nParam);
//static DWORD		GetIntegerParam(KmlBlock* pBlock, TokenId eBlock, TokenId eCommand, UINT nParam);
//static KmlLine*		SkipLines(KmlLine* pLine, TokenId eCommand);
//static KmlLine*		If(KmlLine* pLine, BOOL bCondition);
//static KmlLine*		RunLine(KmlLine* pLine);
//static KmlBlock*	LoadKMLGlobal(NSString * _filename);

KmlBlock*				pKml = NULL;
static KmlBlock*		pVKey[256];
static BYTE				byVKeyMap[256];
static KmlButton		pButton[256];
static KmlAnnunciator	pAnnunciator[6];
static UINT				nButtons = 0;
static UINT				nScancodes = 0;
static UINT				nAnnunciators = 0;
static BOOL				bDebug = TRUE;
static UINT				nLexLine;
static UINT				nLexInteger;
static UINT				nBlocksIncludeLevel;
static UINT				nLinesIncludeLevel;
static DWORD			nKMLFlags = 0;
static char *			szLexString;
static char *			szText;
static const char *		szLexDelim[] =
{
	" \t\n\r",							// valid whitespaces for LEX_BLOCK
	" \t\n\r",							// valid whitespaces for LEX_COMMAND
	" \t\r"								// valid whitespaces for LEX_PARAM
};

static KmlToken pLexToken[] =
{
	{TOK_ANNUNCIATOR,000001,11,"Annunciator"},
	{TOK_BACKGROUND, 000000,10,"Background"},
	{TOK_IFPRESSED,  000001, 9,"IfPressed"},
	{TOK_RESETFLAG,  000001, 9,"ResetFlag"},
	{TOK_SCANCODE,   000001, 8,"Scancode"},
	{TOK_HARDWARE,   000002, 8,"Hardware"},
	{TOK_MENUITEM,   000001, 8,"MenuItem"},
	{TOK_ORIENTATION,000001, 8,"Vertical"},
	{TOK_SETFLAG,    000001, 7,"SetFlag"},
	{TOK_RELEASE,    000001, 7,"Release"},
	{TOK_VIRTUAL,    000000, 7,"Virtual"},
	{TOK_INCLUDE,    000002, 7,"Include"},
	{TOK_NOTFLAG,    000001, 7,"NotFlag"},
	{TOK_MENUBAR,    000001, 7,"Menubar"},
	{TOK_ZOOMDIV,    000001, 7,"ZoomDiv"},
	{TOK_GLOBAL,     000000, 6,"Global"},
	{TOK_AUTHOR,     000002, 6,"Author"},
	{TOK_BITMAP,     000002, 6,"Bitmap"},
	{TOK_OFFSET,     000011, 6,"Offset"},
	{TOK_BUTTON,     000001, 6,"Button"},
	{TOK_IFFLAG,     000001, 6,"IfFlag"},
	{TOK_ONDOWN,     000000, 6,"OnDown"},
	{TOK_NOHOLD,     000000, 6,"NoHold"},
	{TOK_TOPBAR,     000001, 6,"Topbar"},
	{TOK_TITLE,      000002, 5,"Title"},
	{TOK_OUTIN,      000011, 5,"OutIn"},
	{TOK_PATCH,      000002, 5,"Patch"},
	{TOK_PRINT,      000002, 5,"Print"},
	{TOK_DEBUG,      000001, 5,"Debug"},
	{TOK_COLOR,      001111, 5,"Color"},
	{TOK_MODEL,      000002, 5,"Model"},
	{TOK_CLASS,      000001, 5,"Class"},
	{TOK_PRESS,      000001, 5,"Press"},
	{TOK_TYPE,       000001, 4,"Type"},
	{TOK_SIZE,       000011, 4,"Size"},
	{TOK_ZOOM,       000001, 4,"Zoom"},
	{TOK_DOWN,       000011, 4,"Down"},
	{TOK_ELSE,       000000, 4,"Else"},
	{TOK_ONUP,       000000, 4,"OnUp"},
	{TOK_MAP,        000011, 3,"Map"},
	{TOK_ROM,        000002, 3,"Rom"},
	{TOK_VGA,        000001, 3,"Vga"},
	{TOK_LCD,        000000, 3,"Lcd"},
	{TOK_END,        000000, 3,"End"},
	{0,              000000, 0,""}
};

static CONST TokenId eIsGlobalBlock[] =
{
	TOK_GLOBAL,
	TOK_BACKGROUND,
	TOK_LCD,
	TOK_ANNUNCIATOR,
	TOK_BUTTON,
	TOK_SCANCODE
};

static CONST TokenId eIsBlock[] =
{
	TOK_IFFLAG,
	TOK_IFPRESSED,
	TOK_ONDOWN,
	TOK_ONUP
};

static BOOL  bClicking = FALSE;
static UINT  uButtonClicked = 0;

static BOOL  bPressed = FALSE;				// no key pressed
static UINT  uLastPressedKey = 0;			// var for last pressed key

#if defined LONGHOLDTIME
static BOOL  bLongHold = FALSE;				// key long hold not active
static DWORD dwLongTime;
#endif

//################
//#
//#    Compilation Result
//#
//################

//static UINT nLogLength = 0;
//static NSString * szLog = NULL;
/*
static VOID ClearLog()
{
	nLogLength = 0;
	if (szLog != NULL)
	{
		HeapFree(hHeap,0,szLog);
		szLog = NULL;
	}
	return;
}*/
/*
static VOID //AddToLog(NSString * szString)
{
	UINT nLength = lstrlen(szString) + 2;	// CR+LF
	if (szLog == NULL)
	{
		nLogLength = nLength + 1;			// \0
		szLog = HeapAlloc(hHeap,0,nLogLength*sizeof(szLog[0]));
		if (szLog==NULL)
		{
			nLogLength = 0;
			return;
		}
		lstrcpy(szLog,szString);
	}
	else
	{
		NSString * szLogTmp = HeapReAlloc(hHeap,0,szLog,(nLogLength+nLength)*sizeof(szLog[0]));
		if (szLogTmp == NULL)
		{
			ClearLog();
			return;
		}
		szLog = szLogTmp;
		lstrcpy(&szLog[nLogLength-1],szString);
		nLogLength += nLength;
	}
	szLog[nLogLength-3] = _T('\r');
	szLog[nLogLength-2] = _T('\n');
	szLog[nLogLength-1] = 0;
	return;
}*/
/*
static VOID __cdecl //PrintfToLog(NSString * lpFormat, ...)
{
	TCHAR cOutput[1024];
	va_list arglist;

	va_start(arglist,lpFormat);
	wvsprintf(cOutput,lpFormat,arglist);
	//AddToLog(cOutput);
	va_end(arglist);
	return;
}*/
/*
static BOOL CALLBACK KMLLogProc(HWND hDlg, UINT message, DWORD wParam, LONG lParam)
{
	NSString * szString;

	switch (message)
	{
	case WM_INITDIALOG:
		// set OK
		SHDoneButton(hDlg,lParam ? SHDB_SHOW : SHDB_HIDE);
		// set IDC_TITLE
		szString = GetStringParam(pKml, TOK_GLOBAL, TOK_TITLE, 0);
		if (szString == NULL) szString = _T("Untitled");
		SetDlgItemText(hDlg,IDC_TITLE,szString);
		// set IDC_AUTHOR
		szString = GetStringParam(pKml, TOK_GLOBAL, TOK_AUTHOR, 0);
		if (szString == NULL) szString = _T("<Unknown Author>");
		SetDlgItemText(hDlg,IDC_AUTHOR,szString);
		// set IDC_KMLLOG
		szString = szLog;
		if (szString == NULL) szString = _T("Memory Allocation Failure.");
		SetDlgItemText(hDlg,IDC_KMLLOG,szString);
		// set IDC_ALWAYSDISPLOG
		SendDlgItemMessage(hDlg,IDC_ALWAYSDISPLOG,BM_SETCHECK,bAlwaysDisplayLog,0);
		return TRUE;
	case WM_COMMAND:
		wParam = LOWORD(wParam);
		if ((wParam==IDOK)||(wParam==IDCANCEL))
		{
			bAlwaysDisplayLog = SendDlgItemMessage(hDlg,IDC_ALWAYSDISPLOG,BM_GETCHECK,0,0);
			EndDialog(hDlg, wParam);
			return TRUE;
		}
		break;
	}
	return FALSE;
}*/
/*
BOOL DisplayKMLLog(BOOL bOkEnabled)
{
	return IDOK == DialogBoxParam(hApp,
								  MAKEINTRESOURCE(IDD_KMLLOG),
								  hWnd,
								  (DLGPROC)KMLLogProc,
								  bOkEnabled);
}
*/


//################
//#
//#    Choose Script
//#
//################
/*
typedef struct _KmlScript
{
	NSString * _filename;
	NSString * szTitle;
	DWORD  nId;
	struct _KmlScript* pNext;
} KmlScript;

static KmlScript* pKmlList = NULL;
static CHAR cKmlType;
/*
static VOID DestroyKmlList(VOID)
{
	KmlScript* pList;

	while (pKmlList)
	{
		pList = pKmlList->pNext;
		HeapFree(hHeap,0,pKmlList->_filename);
		HeapFree(hHeap,0,pKmlList->szTitle);
		HeapFree(hHeap,0,pKmlList);
		pKmlList = pList;
	}
	return;
}

static VOID CreateKmlList(VOID)
{
	HANDLE hFindFile;
	WIN32_FIND_DATA pFindFileData;
	UINT nKmlFiles;

	_ASSERT(pKmlList == NULL);				// KML file list must be empty
	hFindFile = FindFirstFile(FullFilename(_T("*.KML")),&pFindFileData);
	if (hFindFile == INVALID_HANDLE_VALUE) return;
	nKmlFiles = 0;
	do
	{
		KmlScript* pScript;
		KmlBlock*  pBlock;
		NSString * szTitle;

		pBlock = LoadKMLGlobal(pFindFileData.cFileName);
		if (pBlock == NULL) continue;
		// check for correct KML script platform
		szTitle = GetStringParam(pBlock,TOK_GLOBAL,TOK_HARDWARE,0);
		if (szTitle == NULL || lstrcmpi(_T(HARDWARE),szTitle) != 0)
		{
			FreeBlocks(pBlock);
			continue;
		}
		// check for supported Model
		szTitle = GetStringParam(pBlock,TOK_GLOBAL,TOK_MODEL,0);
		// skip all scripts with invalid or different Model statement
		if (   (szTitle == NULL)
			|| (cKmlType && szTitle[0] != cKmlType)
			|| !isModelValid(szTitle[0]))
		{
			FreeBlocks(pBlock);
			continue;
		}
		VERIFY(pScript = HeapAlloc(hHeap,0,sizeof(KmlScript)));
		pScript->_filename = DuplicateString(pFindFileData.cFileName);
		szTitle = GetStringParam(pBlock,TOK_GLOBAL,TOK_TITLE,0);
		if (szTitle == NULL) szTitle = pScript->_filename;
		pScript->szTitle = DuplicateString(szTitle);
		FreeBlocks(pBlock);
		pScript->nId = nKmlFiles;
		pScript->pNext = pKmlList;
		pKmlList = pScript;
		nKmlFiles++;
	} while (FindNextFile(hFindFile,&pFindFileData));
	FindClose(hFindFile);
	return;
};

static BOOL CALLBACK ChooseKMLProc(HWND hDlg, UINT message, DWORD wParam, LONG lParam)
{
	HWND hList;
	KmlScript* pList;
	UINT nIndex;

	switch (message)
	{
	case WM_INITDIALOG:
		SetDlgItemText(hDlg,IDC_EMUDIR,szEmuDirectory);
		hList = GetDlgItem(hDlg,IDC_KMLSCRIPT);
		SendMessage(hList, CB_RESETCONTENT, 0, 0);
		pList = pKmlList;
		while (pList)
		{
			nIndex = SendMessage(hList, CB_ADDSTRING, 0, (LPARAM)pList->szTitle);
			SendMessage(hList, CB_SETITEMDATA, nIndex, (LPARAM)pList->nId);
			pList = pList->pNext;
		}
		SendMessage(hList, CB_SETCURSEL, 0, 0);
		return TRUE;
	case WM_COMMAND:
		switch (LOWORD(wParam))
		{
		case IDC_UPDATE:
			DestroyKmlList();
			GetDlgItemText(hDlg,IDC_EMUDIR,szEmuDirectory,ARRAYSIZEOF(szEmuDirectory));
			CreateKmlList();
			hList = GetDlgItem(hDlg,IDC_KMLSCRIPT);
			SendMessage(hList, CB_RESETCONTENT, 0, 0);
			pList = pKmlList;
			while (pList)
			{
				nIndex = SendMessage(hList, CB_ADDSTRING, 0, (LPARAM)pList->szTitle);
				SendMessage(hList, CB_SETITEMDATA, nIndex, (LPARAM)pList->nId);
				pList = pList->pNext;
			}
			SendMessage(hList, CB_SETCURSEL, 0, 0);
			return TRUE;
		case IDOK:
			GetDlgItemText(hDlg,IDC_EMUDIR,szEmuDirectory,ARRAYSIZEOF(szEmuDirectory));
			hList = GetDlgItem(hDlg,IDC_KMLSCRIPT);
			nIndex = SendMessage(hList, CB_GETCURSEL, 0, 0);
			nIndex = SendMessage(hList, CB_GETITEMDATA, nIndex, 0);
			pList = pKmlList;
			while (pList)
			{
				if (pList->nId == nIndex)
				{
					lstrcpy(szCurrentKml, pList->_filename);
					EndDialog(hDlg, IDOK);
					break;
				}
				pList = pList->pNext;
			}
			return TRUE;
		case IDCANCEL:
			EndDialog(hDlg, IDCANCEL);
			return TRUE;
		}
	}
	return FALSE;
	// mksg.de // UNREFERENCED_PARAMETER(lParam);
}

BOOL DisplayChooseKml(CHAR cType)
{
	INT nResult;
	cKmlType = cType;
	CreateKmlList();
	nResult = DialogBox(hApp, MAKEINTRESOURCE(IDD_CHOOSEKML), hWnd, (DLGPROC)ChooseKMLProc);
	DestroyKmlList();
	return (nResult == IDOK);
}
*/

//################
//#
//#    Script Parsing
//#
//################

static VOID FatalError(VOID)
{
	//PrintfToLog(_T("Fatal Error at line %i"), nLexLine);
	szText[0] = 0;
	return;
}

static VOID InitLex(NSString * _script)
{
	const char * temp;
	nLexLine = 1;
	temp = [_script UTF8String];
	szText = malloc(strlen(temp)*sizeof(char));
	strcpy(szText, temp);
	return;
}

static VOID CleanLex(VOID)
{
	nLexLine = 0;
	nLexInteger = 0;
	szLexString = NULL;
	free(szText);
	szText = NULL;
	return;
}

static BOOL IsGlobalBlock(TokenId eId)
{
	UINT i;

	for (i = 0; i < ARRAYSIZEOF(eIsGlobalBlock); ++i)
	{
		if (eId == eIsGlobalBlock[i]) return TRUE;
	}
	return FALSE;
}

static BOOL IsBlock(TokenId eId)
{
	UINT i;

	for (i = 0; i < ARRAYSIZEOF(eIsBlock); ++i)
	{
		if (eId == eIsBlock[i]) return TRUE;
	}
	return FALSE;
}
/*
static NSString * GetStringOf(TokenId eId)
{
	UINT i;

	for (i = 0; pLexToken[i].nLen; ++i)
	{
		if (pLexToken[i].eId == eId) return pLexToken[i].szName;
	}
	return _T("<Undefined>");
}*/

static VOID SkipWhite(UINT nMode)
{
	char * pcDelim;

	while (*szText)
	{
		// search for delimiter
		if ((pcDelim = strchr(szLexDelim[nMode],*szText)) != NULL)
		{
			_ASSERT(*pcDelim != 0);			// no EOS 
			if (*pcDelim == '\n') nLexLine++;
			szText++;
			continue;
		}
		if (*szText == '#')					// start of remark
		{
			// skip until LF or EOS
			do szText++; while (*szText != '\n' && *szText != 0);
			if (nMode != LEX_PARAM) continue;
		}
		break;
	}
	return;
}


static TokenId ParseToken(UINT nMode)
{
	UINT i,j;

	for (i = 0; szText[i]; i++)				// search for delimeter
	{
		if (strchr(szLexDelim[nMode],szText[i]) != NULL)
			break;
	}
	if (i == 0) return TOK_NONE;

	// token length longer or equal than current command
	for (j = 0; pLexToken[j].nLen >= i; ++j)
	{
		if (pLexToken[j].nLen == i)			// token length has command length
		{
			if (strncmp(pLexToken[j].szName,szText,i) == 0)
			{
				szText += i;				// remove command from text
				return pLexToken[j].eId;	// return token Id
			}
		}
	}
	szText[i] = 0;							// token not found, set EOS
	if (bDebug)
	{
		//PrintfToLog(_T("%i: Undefined token %s"),nLexLine,szText);
	}
	return TOK_NONE;
}

static DWORD ParseInteger(VOID)
{
	DWORD nNum = 0;
	while (_istdigit(*szText))
	{
		nNum = nNum * 10 + ((*szText) - '0');
		szText++;
	}
	return nNum;
}

static char * ParseString(VOID)
{
	char * lpszString;
	UINT   nLength;
	UINT   nBlock;

	szText++;								// skip leading '"'
	nLength = 0;
	nBlock = 256;
	lpszString = malloc(nBlock * sizeof(lpszString[0]));
	while (*szText != _T('"'))
	{
		if (nLength == nBlock - 1)			// ran out of buffer space
		{
			nBlock += 256;
			lpszString = realloc(lpszString,nBlock * sizeof(lpszString[0]));
		}

		if (*szText == _T('\\')) szText++;	// skip '\' escape char
		if (*szText == 0)					// EOS found inside string
		{
			free(lpszString);
			FatalError();
			return NULL;
		}
		lpszString[nLength++] = *szText++;	// save char
	}
	szText++;								// skip ending '"'
	lpszString[nLength] = 0;				// set EOS

	// release unnecessary allocated bytes
	return  realloc(lpszString,(nLength+1) * sizeof(lpszString[0]));
}

static TokenId Lex(UINT nMode)
{
	_ASSERT(nMode >= LEX_BLOCK && nMode <= LEX_PARAM);
	_ASSERT(nMode >= 0 && nMode < ARRAYSIZEOF(szLexDelim));

	SkipWhite(nMode);
	if (_istdigit(*szText))
	{
		nLexInteger = ParseInteger();
		return TOK_INTEGER;
	}
	if (*szText == _T('"'))
	{
		szLexString = ParseString();
		return TOK_STRING;
	}
	if (nMode == LEX_PARAM)
	{
		if (*szText == _T('\n'))			// end of line
		{
			nLexLine++;						// next line
			szText++;						// skip LF
			return TOK_EOL;
		}
		if (*szText == 0)					// end of file
		{
			return TOK_EOL;
		}
	}
	return ParseToken(nMode);
}

static KmlLine* ParseLine(TokenId eCommand)
{
	UINT     i, j;
	DWORD    nParams;
	TokenId  eToken;
	KmlLine* pLine;

	for (i = 0; pLexToken[i].nLen; ++i)
	{
		if (pLexToken[i].eId == eCommand) break;
	}
	if (pLexToken[i].nLen == 0) return NULL;

	pLine = malloc(sizeof(KmlLine));
	pLine->eCommand = eCommand;

	for (j = 0, nParams = pLexToken[i].nParams; TRUE; nParams >>= 3)
	{
		// check for parameter overflow
		_ASSERT(j < ARRAYSIZEOF(pLine->nParam));

		eToken = Lex(LEX_PARAM);			// decode argument token
		if ((nParams & 7) == TYPE_NONE)
		{
			if (eToken != TOK_EOL)
			{
				//PrintfToLog(_T("%i: Too many parameters for %s (%i expected)."), nLexLine, pLexToken[i].szName, j);
				break;						// free memory of arguments
			}
			return pLine;					// normal exit -> parsed line
		}
		if ((nParams & 7) == TYPE_INTEGER)
		{
			if (eToken != TOK_INTEGER)
			{
				//PrintfToLog(_T("%i: Parameter %i of %s must be an integer."), nLexLine, j+1, pLexToken[i].szName);
				break;						// free memory of arguments
			}
			pLine->nParam[j++] = nLexInteger;
			continue;
		}
		if ((nParams & 7) == TYPE_STRING)
		{
			if (eToken != TOK_STRING)
			{
				//PrintfToLog(_T("%i: Parameter %i of %s must be a string."), nLexLine, j+1, pLexToken[i].szName);
				break;						// free memory of arguments
			}
			pLine->nParam[j++] = (DWORD_PTR) szLexString;
			continue;
		}
		_ASSERT(FALSE);						// unknown parameter type
		break;
	}

	// if last argument was string, free it
	if (eToken == TOK_STRING) free(szLexString);

	nParams = pLexToken[i].nParams;			// get argument types of command
	for (i = 0; i < j; ++i)					// handle all scanned arguments
	{
		if ((nParams & 7) == TYPE_STRING)	// string type
		{
			free((void *)pLine->nParam[i]);
		}
		nParams >>= 3;						// next argument type
	}
	free(pLine);
	return NULL;
}

static KmlLine* ParseLines(VOID)
{
	KmlLine* pFirst = NULL;
	KmlLine* pLine  = NULL;
	TokenId  eToken;
	UINT     nLevel = 0;

	while ((eToken = Lex(LEX_COMMAND)))
	{
		if (IsGlobalBlock(eToken))			// check for block command
		{
			//PrintfToLog(_T("%i: Invalid Command %s."), nLexLine, GetStringOf(eToken));
			goto abort;
		}
		if (IsBlock(eToken)) nLevel++;
		if (eToken == TOK_INCLUDE)
		{
				// mksg: Erst einmal rasgenommen und die INCLUDE-Funktionalität somit nicht implementiert
				FatalError();
				goto abort;
			
		}
		if (eToken == TOK_END)
		{
			if (nLevel)
			{
				nLevel--;
			}
			else
			{
				if (pLine) pLine->pNext = NULL;
				return pFirst;
			}
		}
		if (pFirst)
		{
			pLine = pLine->pNext = ParseLine(eToken);
		}
		else
		{
			pLine = pFirst = ParseLine(eToken);
		}
		if (pLine == NULL)					// parsing error
			goto abort;
	}
	if (nLinesIncludeLevel)
	{
		if (pLine) pLine->pNext = NULL;
		return pFirst;
	}
abort:
	if (pFirst)
	{
		FreeLines(pFirst);
	}
	return NULL;
}

static KmlBlock* ParseBlock(TokenId eType)
{
	UINT      u1;
	KmlBlock* pBlock;
	TokenId   eToken;

	nLinesIncludeLevel = 0;

	pBlock = malloc(sizeof(KmlBlock));
	pBlock->eType = eType;

	u1 = 0;
	while (pLexToken[u1].nLen)
	{
		if (pLexToken[u1].eId == eType) break;
		u1++;
	}
	if (pLexToken[u1].nParams)
	{
		eToken = Lex(LEX_COMMAND);
		switch (eToken)
		{
		case TOK_NONE:
			//AddToLog(_T("Open Block at End Of File."));
			free(pBlock);
			FatalError();
			return NULL;
		case TOK_INTEGER:
			if ((pLexToken[u1].nParams&7)!=TYPE_INTEGER)
			{
				//AddToLog(_T("Wrong block argument."));
				free(pBlock);
				FatalError();
				return NULL;
			}
			pBlock->nId = nLexInteger;
			break;
		default:
			//AddToLog(_T("Wrong block argument."));
			free(pBlock);
			FatalError();
			return NULL;
		}
	}

	pBlock->pFirstLine = ParseLines();

	if (pBlock->pFirstLine == NULL)			// break on ParseLines error
	{
		free(pBlock);
		pBlock = NULL;
	}

	return pBlock;
}


static KmlBlock* ParseBlocks(VOID)
{
	TokenId eToken;
	KmlBlock* pFirst = NULL;
	KmlBlock* pBlock = NULL;
	
	while ((eToken=Lex(LEX_BLOCK))!=TOK_NONE)
	{
		if (eToken == TOK_INCLUDE)
		{
			FatalError();
			goto abort;
		}
		if (!IsGlobalBlock(eToken))			// check for valid block commands
		{
			//PrintfToLog(_T("%i: Invalid Block %s."), nLexLine, GetStringOf(eToken));
			FatalError();
			goto abort;
		}
		if (pFirst)
			pBlock = pBlock->pNext = ParseBlock(eToken);
		else
			pBlock = pFirst = ParseBlock(eToken);
		if (pBlock == NULL)
		{
			//AddToLog(_T("Invalid block."));
			FatalError();
			goto abort;
		}
	}
	if (pFirst) pBlock->pNext = NULL;
	if (*szText != 0)						// still KML text left
	{
		FatalError();						// error unknown block token
		goto abort;
	}
	return pFirst;
abort:
	if (pFirst) FreeBlocks(pFirst);
	return NULL;
	
}



//################
//#
//#    Initialization Phase
//#
//################

static VOID InitGlobal(KmlBlock* pBlock)
{
	KmlLine* pLine = pBlock->pFirstLine;
	while (pLine)
	{
		switch (pLine->eCommand)
		{
		case TOK_TITLE:
			//PrintfToLog(_T("Title: %s"), (NSString *)pLine->nParam[0]);
			break;
		case TOK_AUTHOR:
			//PrintfToLog(_T("Author: %s"), (NSString *)pLine->nParam[0]);
			break;
		case TOK_PRINT:
			//AddToLog((NSString *)pLine->nParam[0]);
			break;
		case TOK_HARDWARE:
			//PrintfToLog(_T("Hardware Platform: %s"), (NSString *)pLine->nParam[0]);
			break;
		case TOK_MODEL:
			cCurrentRomType = ((BYTE *)pLine->nParam[0])[0];
			//PrintfToLog(_T("Calculator Model : %c"), cCurrentRomType);
			break;
		case TOK_CLASS:
			nCurrentClass = (UINT) pLine->nParam[0];
			//PrintfToLog(_T("Calculator Class : %u"), nCurrentClass);
			break;
		case TOK_DEBUG:
			bDebug = (BOOL) ((UINT) pLine->nParam[0]) & 1;
			//PrintfToLog(_T("Debug %s"), bDebug?_T("On"):_T("Off"));
			break;
		case TOK_ROM:
			if (pbyRom != NULL)
			{
				//PrintfToLog(_T("Rom %s Ignored."), (NSString *)pLine->nParam[0]);
				//AddToLog(_T("Please put only one Rom command in the Global block."));
				break;
			}
			if (!MapRom((char *)pLine->nParam[0]))
			{
				//PrintfToLog(_T("Cannot open Rom %s"), (NSString *)pLine->nParam[0]);
				break;
			}
			//PrintfToLog(_T("Rom %s Loaded."), (NSString *)pLine->nParam[0]);
			break;
		case TOK_PATCH:
			if (pbyRom == NULL)
			{
				//PrintfToLog(_T("Patch %s ignored."), (NSString *)pLine->nParam[0]);
				//AddToLog(_T("Please put the Rom command before any Patch."));
				break;
			}
			if (PatchRom((char *)pLine->nParam[0]) == TRUE)
				;
				//PrintfToLog(_T("Patch %s Loaded"), (NSString *)pLine->nParam[0]);
			else
				//PrintfToLog(_T("Patch %s is Wrong or Missing"), (NSString *)pLine->nParam[0]);
			break;
		case TOK_BITMAP:
			//if (hMainDC != NULL)
			{
				//PrintfToLog(_T("Bitmap %s Ignored."), (NSString *)pLine->nParam[0]);
				//AddToLog(_T("Please put only one Bitmap command in the Global block."));
				break;
			}
			//if (!CreateMainBitmap((NSString *)pLine->nParam[0]))
			{
				//PrintfToLog(_T("Cannot Load Bitmap %s."), (NSString *)pLine->nParam[0]);
				break;
			}
			//PrintfToLog(_T("Bitmap %s Loaded."), (NSString *)pLine->nParam[0]);
			break;
		default:
				;
			//PrintfToLog(_T("Command %s Ignored in Block %s"), GetStringOf(pLine->eCommand), GetStringOf(pBlock->eType));
		}
		pLine = pLine->pNext;
	}
	return;
}
/*
static KmlLine* InitBackground(KmlBlock* pBlock)
{
	KmlLine* pLine = pBlock->pFirstLine;
	while (pLine)
	{
		switch (pLine->eCommand)
		{
		case TOK_VGA:
			if (pLine->nParam[0] == 1)
				nAppZoom = 1;
			break;
		case TOK_TOPBAR:
			if (pLine->nParam[0] == 0)
				nFullScreen |= TOPBAR_OFF;
			break;
		case TOK_MENUBAR:
			if (pLine->nParam[0] == 0)
				nFullScreen |= MENUBAR_OFF;
			break;
		case TOK_OFFSET:
			nBackgroundX = pLine->nParam[0];
			nBackgroundY = pLine->nParam[1];
			break;
		case TOK_SIZE:
			nBackgroundW = pLine->nParam[0];
			nBackgroundH = pLine->nParam[1];
			break;
		case TOK_END:
			return pLine;
		default:
			//PrintfToLog(_T("Command %s Ignored in Block %s"), GetStringOf(pLine->eCommand), GetStringOf(pBlock->eType));
		}
		pLine = pLine->pNext;
	}
	return NULL;
}

static KmlLine* InitLcd(KmlBlock* pBlock)
{
	KmlLine* pLine = pBlock->pFirstLine;
	while (pLine)
	{
		switch (pLine->eCommand)
		{
		case TOK_OFFSET:
			nLcdX = pLine->nParam[0];
			nLcdY = pLine->nParam[1];
			break;
		case TOK_ORIENTATION:
			nVertical = pLine->nParam[0];
			if (nVertical > 2) nVertical = 0;
			break;
		case TOK_ZOOM:
			nLcdZoom = pLine->nParam[0];
			break;
		case TOK_ZOOMDIV:
			nLcdDiv = pLine->nParam[0];
			if (nLcdDiv < 1) nLcdDiv = 1;
			break;
		case TOK_COLOR:
			SetLcdColor(pLine->nParam[0],pLine->nParam[1],pLine->nParam[2],pLine->nParam[3]);
			break;
		case TOK_END:
			return pLine;
		default:
			//PrintfToLog(_T("Command %s Ignored in Block %s"), GetStringOf(pLine->eCommand), GetStringOf(pBlock->eType));
		}
		pLine = pLine->pNext;
	}
	return NULL;
}
*/
static KmlLine* InitAnnunciator(KmlBlock* pBlock)
{
	KmlLine* pLine = pBlock->pFirstLine;
	UINT nId = pBlock->nId-1;
	if (nId >= ARRAYSIZEOF(pAnnunciator))
	{
		//PrintfToLog(_T("Wrong Annunciator Id %i"), nId);
		return NULL;
	}
	nAnnunciators++;
	while (pLine)
	{
		switch (pLine->eCommand)
		{
		case TOK_OFFSET:
			pAnnunciator[nId].nOx = (UINT) pLine->nParam[0];
			pAnnunciator[nId].nOy = (UINT) pLine->nParam[1];
			break;
		case TOK_DOWN:
			pAnnunciator[nId].nDx = (UINT) pLine->nParam[0];
			pAnnunciator[nId].nDy = (UINT) pLine->nParam[1];
			break;
		case TOK_SIZE:
			pAnnunciator[nId].nCx = (UINT) pLine->nParam[0];
			pAnnunciator[nId].nCy = (UINT) pLine->nParam[1];
			break;
		case TOK_END:
			return pLine;
		default:
				;
			//PrintfToLog(_T("Command %s Ignored in Block %s"), GetStringOf(pLine->eCommand), GetStringOf(pBlock->eType));
		}
		pLine = pLine->pNext;
	}
	return NULL;
}

static VOID InitButton(KmlBlock* pBlock)
{
	KmlLine* pLine = pBlock->pFirstLine;
	UINT nLevel = 0;
	if (nButtons>=256)
	{
		//AddToLog(_T("Only the first 256 buttons will be defined."));
		return;
	}
	pButton[nButtons].nId = pBlock->nId;
	pButton[nButtons].bDown = FALSE;
	pButton[nButtons].nType = 0; // default : user defined button
	while (pLine)
	{
		if (nLevel)
		{
			if (IsBlock(pLine->eCommand)) nLevel++;
			if (pLine->eCommand == TOK_END) nLevel--;
			pLine = pLine->pNext;
			continue;
		}
		if (IsBlock(pLine->eCommand)) nLevel++;
		switch (pLine->eCommand)
		{
		case TOK_TYPE:
			pButton[nButtons].nType = (UINT) pLine->nParam[0];
			break;
		case TOK_OFFSET:
			pButton[nButtons].nOx = (UINT) pLine->nParam[0];
			pButton[nButtons].nOy = (UINT) pLine->nParam[1];
			break;
		case TOK_DOWN:
			pButton[nButtons].nDx = (UINT) pLine->nParam[0];
			pButton[nButtons].nDy = (UINT) pLine->nParam[1];
			break;
		case TOK_SIZE:
			pButton[nButtons].nCx = (UINT) pLine->nParam[0];
			pButton[nButtons].nCy = (UINT) pLine->nParam[1];
			break;
		case TOK_OUTIN:
			pButton[nButtons].nOut = (UINT) pLine->nParam[0];
			pButton[nButtons].nIn  = (UINT) pLine->nParam[1];
			break;
		case TOK_ONDOWN:
			pButton[nButtons].pOnDown = pLine;
			break;
		case TOK_ONUP:
			pButton[nButtons].pOnUp = pLine;
			break;
		case TOK_NOHOLD:
			pButton[nButtons].dwFlags &= ~(BUTTON_VIRTUAL);
			pButton[nButtons].dwFlags |= BUTTON_NOHOLD;
			break;
		case TOK_VIRTUAL:
			pButton[nButtons].dwFlags &= ~(BUTTON_NOHOLD);
			pButton[nButtons].dwFlags |= BUTTON_VIRTUAL;
			break;
		default:
			;
			//PrintfToLog(_T("Command %s Ignored in Block %s %i"), GetStringOf(pLine->eCommand), GetStringOf(pBlock->eType), pBlock->nId);
		}
		pLine = pLine->pNext;
	}
	if (nLevel)
		;
		//PrintfToLog(_T("%i Open Block(s) in Block %s %i"), nLevel, GetStringOf(pBlock->eType), pBlock->nId);
	nButtons++;
	return;
}
/*


//################
//#
//#    Execution
//#
//################

static KmlLine* SkipLines(KmlLine* pLine, TokenId eCommand)
{
	UINT nLevel = 0;
	while (pLine)
	{
		if (IsBlock(pLine->eCommand)) nLevel++;
		if (pLine->eCommand==eCommand)
		{
			if (nLevel == 0) return pLine->pNext;
		}
		if (pLine->eCommand == TOK_END)
		{
			if (nLevel)
				nLevel--;
			else
				break;
		}
		pLine = pLine->pNext;
	}
	return pLine;
}

static KmlLine* If(KmlLine* pLine, BOOL bCondition)
{
	pLine = pLine->pNext;
	if (bCondition)
	{
		while (pLine)
		{
			if (pLine->eCommand == TOK_END)
			{
				pLine = pLine->pNext;
				break;
			}
			if (pLine->eCommand == TOK_ELSE)
			{
				pLine = SkipLines(pLine, TOK_END);
				break;
			}
			pLine = RunLine(pLine);
		}
	}
	else
	{
		pLine = SkipLines(pLine, TOK_ELSE);
		while (pLine)
		{
			if (pLine->eCommand == TOK_END)
			{
				pLine = pLine->pNext;
				break;
			}
			pLine = RunLine(pLine);
		}
	}
	return pLine;
}

static KmlLine* RunLine(KmlLine* pLine)
{
	switch (pLine->eCommand)
	{
	case TOK_MAP:
		if (byVKeyMap[pLine->nParam[0]&0xFF]&1)
			PressButtonById(pLine->nParam[1]);
		else
			ReleaseButtonById(pLine->nParam[1]);
		break;
	case TOK_PRESS:
		PressButtonById(pLine->nParam[0]);
		break;
	case TOK_RELEASE:
		ReleaseButtonById(pLine->nParam[0]);
		break;
	case TOK_MENUITEM:
		PostMessage(hWnd, WM_COMMAND, 0x19C40+(pLine->nParam[0]&0xFF), 0);
		break;
	case TOK_SETFLAG:
		nKMLFlags |= 1<<(pLine->nParam[0]&0x1F);
		break;
	case TOK_RESETFLAG:
		nKMLFlags &= ~(1<<(pLine->nParam[0]&0x1F));
		break;
	case TOK_NOTFLAG:
		nKMLFlags ^= 1<<(pLine->nParam[0]&0x1F);
		break;
	case TOK_IFPRESSED:
		return If(pLine,byVKeyMap[pLine->nParam[0]&0xFF]);
		break;
	case TOK_IFFLAG:
		return If(pLine,(nKMLFlags>>(pLine->nParam[0]&0x1F))&1);
	default:
		break;
	}
	return pLine->pNext;
}

*/

//################
//#
//#    Clean Up
//#
//################

static VOID FreeLines(KmlLine* pLine)
{
	while (pLine)
	{
		KmlLine* pThisLine = pLine;
		UINT i = 0;
		DWORD nParams;
		while (pLexToken[i].nLen)			// search in all token definitions
		{
			// break when token definition found
			if (pLexToken[i].eId == pLine->eCommand) break;
			i++;							// next token definition
		}
		nParams = pLexToken[i].nParams;		// get argument types of command
		i = 0;								// first parameter
		while ((nParams&7))					// argument left
		{
			if ((nParams&7) == TYPE_STRING)	// string type
			{
				free((void *)pLine->nParam[i]);
			}
			i++;							// incr. parameter buffer index
			nParams >>= 3;					// next argument type
		}
		pLine = pLine->pNext;				// get next line
		free(pThisLine);
	}
	return;
}

VOID FreeBlocks(KmlBlock* pBlock)
{
	while (pBlock)
	{
		KmlBlock* pThisBlock = pBlock;
		pBlock = pBlock->pNext;
		FreeLines(pThisBlock->pFirstLine);
		free(pThisBlock);
	}
	return;
}
/*
VOID KillKML(VOID)
{
	if ((nState==SM_RUN)||(nState==SM_SLEEP))
	{
		AbortMessage(_T("FATAL: KillKML while emulator is running !!!"));
		SwitchToState(SM_RETURN);
		DestroyWindow(hWnd);
	}
	UnmapRom();
	DestroyLcdBitmap();
	DestroyMainBitmap();
	if (hPalette)
	{
		BOOL err;

		if (hWindowDC) SelectPalette(hWindowDC, hOldPalette, FALSE);
		err = DeleteObject(hPalette);
		_ASSERT(err != FALSE);				// freed resource memory
		hPalette = NULL;
	}
	bClicking = FALSE;
	uButtonClicked = 0;
	FreeBlocks(pKml);
	pKml = NULL;
	nButtons = 0;
	nScancodes = 0;
	nAnnunciators = 0;
	bDebug = TRUE;
	nKMLFlags = 0;
	ZeroMemory(pButton, sizeof(pButton));
	ZeroMemory(pAnnunciator, sizeof(pAnnunciator));
	ZeroMemory(pVKey, sizeof(pVKey));
	ClearLog();
	nAppZoom = 1;
	nFullScreen = 0;						// top and menu bar on
	nVertical = 0;
	nBackgroundX = 0;
	nBackgroundY = 0;
	nBackgroundW = 0;
	nBackgroundH = 0;
	if (hWindowDC)
	{
		nBackgroundW = GetDeviceCaps(hWindowDC,HORZRES);
		nBackgroundH = GetDeviceCaps(hWindowDC,VERTRES);
	}
	nLcdZoom = 1;
	nLcdDiv = 1;
	cCurrentRomType = 0;
	nCurrentClass = 0;
	ResizeWindow();
	return;
}



//################
//#
//#    Extract Keyword's Parameters
//#
//################

static NSString * GetStringParam(KmlBlock* pBlock, TokenId eBlock, TokenId eCommand, UINT nParam)
{
	while (pBlock)
	{
		if (pBlock->eType == eBlock)
		{
			KmlLine* pLine = pBlock->pFirstLine;
			while (pLine)
			{
				if (pLine->eCommand == eCommand)
				{
					return (NSString *)pLine->nParam[nParam];
				}
				pLine = pLine->pNext;
			}
		}
		pBlock = pBlock->pNext;
	}
	return NULL;
}

static DWORD GetIntegerParam(KmlBlock* pBlock, TokenId eBlock, TokenId eCommand, UINT nParam)
{
	while (pBlock)
	{
		if (pBlock->eType == eBlock)
		{
			KmlLine* pLine = pBlock->pFirstLine;
			while (pLine)
			{
				if (pLine->eCommand == eCommand)
				{
					return pLine->nParam[nParam];
				}
				pLine = pLine->pNext;
			}
		}
		pBlock = pBlock->pNext;
	}
	return 0;
}



//################
//#
//#    Buttons
//#
//################

static INT iSqrt(INT nNumber)				// integer y=sqrt(x) function
{
	INT m, b = 0, t = nNumber;

	do
	{
		m = (b + t + 1) / 2;				// median number
		if (m * m - nNumber > 0)			// calculate x^2-y
			t = m;							// adjust upper border
		else
			b = m;							// adjust lower border
	}
	while(t - b > 1);

	return b;
}

static VOID AdjustPixel(UINT x, UINT y, BYTE byOffset)
{
	COLORREF rgb;
	WORD     wB, wG, wR;

	rgb = GetPixel(hWindowDC, x, y);

	// adjust color red
	wR = (((WORD) rgb) & 0x00FF) + byOffset;
	if (wR > 0xFF) wR = 0xFF;
	rgb >>= 8;
	// adjust color green
	wG = (((WORD) rgb) & 0x00FF) + byOffset;
	if (wG > 0xFF) wG = 0xFF;
	rgb >>= 8;
	// adjust color blue
	wB = (((WORD) rgb) & 0x00FF) + byOffset;
	if (wB > 0xFF) wB = 0xFF;

	SetPixel(hWindowDC, x, y, RGB(wR,wG,wB));
	return;
}



static POINT pLineArray[2];

static BOOL MoveToEx(HDC hDC,int x, int y, LPPOINT old)
{
	if (old != NULL) *old = pLineArray[0];
	pLineArray[0].x = x;
	pLineArray[0].y = y;
	return TRUE;
}

static BOOL LineTo(HDC hDC,int x,int y)
{
	BOOL result;
	pLineArray[1].x = x;
	pLineArray[1].y = y;

	result = Polyline(hDC,pLineArray,ARRAYSIZEOF(pLineArray));
	pLineArray[0] = pLineArray[1];
	return result;
}

static VOID DrawButton(UINT nId)
{
	UINT x0 = pButton[nId].nOx - nBackgroundX;
	UINT y0 = pButton[nId].nOy - nBackgroundY;

	EnterCriticalSection(&csGDILock);		// solving NT GDI problems
	{
		switch (pButton[nId].nType)
		{
		case 0: // bitmap key
			if (pButton[nId].bDown)
			{
				StretchBlt(hWindowDC,
					       x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   pButton[nId].nDx, pButton[nId].nDy,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
			else
			{
				// update background only
				StretchBlt(hWindowDC,
						   x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   x0 + nBackgroundX, y0 + nBackgroundY,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
			break;
		case 1: // shift key to right down
			if (pButton[nId].bDown)
			{
				HPEN hPen;

				INT x1 = x0+pButton[nId].nCx-nAppZoom;
				INT y1 = y0+pButton[nId].nCy-nAppZoom;
				StretchBlt(hWindowDC,
						   (x0+3) * nAppZoom,(y0+3) * nAppZoom,
						   (pButton[nId].nCx-5) * nAppZoom,(pButton[nId].nCy-5) * nAppZoom,
						   hMainDC,
						   x0+2+nBackgroundX,y0+2+nBackgroundY,
						   pButton[nId].nCx-5,pButton[nId].nCy-5,
						   SRCCOPY);

				// black pen
				hPen = SelectObject(hWindowDC, CreatePen(PS_SOLID,nAppZoom,RGB(0,0,0)));
				MoveToEx(hWindowDC, x0 * nAppZoom, y0 * nAppZoom, NULL);
				LineTo(  hWindowDC, x1 * nAppZoom, y0 * nAppZoom);
				MoveToEx(hWindowDC, x0 * nAppZoom, y0 * nAppZoom, NULL);
				LineTo(  hWindowDC, x0 * nAppZoom, y1 * nAppZoom);
				DeleteObject(SelectObject(hWindowDC, hPen));

				// white pen
				hPen = SelectObject(hWindowDC, CreatePen(PS_SOLID,nAppZoom,RGB(255,255,255)));
				MoveToEx(hWindowDC, x1 * nAppZoom,     y0 * nAppZoom, NULL);
				LineTo(  hWindowDC, x1 * nAppZoom,     y1 * nAppZoom);
				MoveToEx(hWindowDC, x0 * nAppZoom,     y1 * nAppZoom, NULL);
				LineTo(  hWindowDC, (x1 - nAppZoom) * nAppZoom + 2, y1 * nAppZoom);
				DeleteObject(SelectObject(hWindowDC, hPen));
			}
			else
			{
				StretchBlt(hWindowDC,
						   x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   x0 + nBackgroundX, y0 + nBackgroundY,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
			break;
		case 2: // do nothing
			break;
		case 3: // invert key color
			if (pButton[nId].bDown)
			{
				PatBlt(hWindowDC, x0 * nAppZoom, y0 * nAppZoom,
					   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom, DSTINVERT);
			}
			else
			{
				StretchBlt(hWindowDC,
						   x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   x0 + nBackgroundX, y0 + nBackgroundY,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
			break;
		case 4: // background key for display
			if (pButton[nId].bDown)
			{
				// update background only
				StretchBlt(hWindowDC,
						   x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   x0 + nBackgroundX, y0 + nBackgroundY,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
			else
			{
				RECT Rect;
				Rect.left = x0;
				Rect.top  = y0;
				Rect.right  = Rect.left + pButton[nId].nCx;
				Rect.bottom = Rect.top + pButton[nId].nCy;
				InvalidateRect(hWnd, &Rect, FALSE);	// call WM_PAINT for background and display redraw
			}
			break;
		default: // black key, default drawing on illegal types
			if (pButton[nId].bDown)
			{
				PatBlt(hWindowDC, x0 * nAppZoom, y0 * nAppZoom,
					   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom, BLACKNESS);
			}
			else
			{
				// update background only
				StretchBlt(hWindowDC,
						   x0 * nAppZoom, y0 * nAppZoom,
						   pButton[nId].nCx * nAppZoom, pButton[nId].nCy * nAppZoom,
						   hMainDC,
						   x0 + nBackgroundX, y0 + nBackgroundY,
						   pButton[nId].nCx, pButton[nId].nCy,
						   SRCCOPY);
			}
		}
	}
	LeaveCriticalSection(&csGDILock);
	return;
}

static VOID PressButton(UINT nId)
{
	if (pButton[nId].bDown) return;			// key already pressed -> exit

	pButton[nId].bDown = TRUE;
	DrawButton(nId);
	if (pButton[nId].nIn)
	{
		KeyboardEvent(TRUE,pButton[nId].nOut,pButton[nId].nIn);
	}
	else
	{
		KmlLine* pLine = pButton[nId].pOnDown;
		while ((pLine)&&(pLine->eCommand!=TOK_END))
		{
			pLine = RunLine(pLine);
		}
	}
	return;
}

static VOID ReleaseButton(UINT nId)
{
	pButton[nId].bDown = FALSE;
	DrawButton(nId);
	if (pButton[nId].nIn)
	{
		KeyboardEvent(FALSE,pButton[nId].nOut,pButton[nId].nIn);
	}
	else
	{
		KmlLine* pLine = pButton[nId].pOnUp;
		while ((pLine)&&(pLine->eCommand!=TOK_END))
		{
			pLine = RunLine(pLine);
		}
	}
	return;
}

static VOID PressButtonById(UINT nId)
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if (nId == pButton[i].nId)
		{
			PressButton(i);
			return;
		}
	}
	return;
}

static VOID ReleaseButtonById(UINT nId)
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if (nId == pButton[i].nId)
		{
			ReleaseButton(i);
			return;
		}
	}
	return;
}

static VOID ReleaseAllButtons(VOID)			// release all buttons
{
	UINT i;
	for (i=0; i<nButtons; i++)				// scan all buttons
	{
		if (pButton[i].bDown)				// button pressed
			ReleaseButton(i);				// release button
	}

	bPressed = FALSE;						// key not pressed
	bClicking = FALSE;						// var uButtonClicked not valid (no virtual or nohold key)
	uButtonClicked = 0;						// set var to default
}

VOID ReloadButtons(BYTE *Keyboard_Row, UINT nSize)
{
	UINT i;
	for (i=0; i<nButtons; i++)				// scan all buttons
	{
		if (pButton[i].nOut < nSize)		// valid out code
		{
			// get state of button from keyboard matrix
			pButton[i].bDown = ((Keyboard_Row[pButton[i].nOut] & pButton[i].nIn) != 0);
		}
	}
}

VOID RefreshButtons(RECT *rc)
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if (   pButton[i].bDown
			&& rc->right  >  (LONG) (pButton[i].nOx)
			&& rc->bottom >  (LONG) (pButton[i].nOy)
			&& rc->left   <= (LONG) (pButton[i].nOx + pButton[i].nCx)
			&& rc->top    <= (LONG) (pButton[i].nOy + pButton[i].nCy))
		{
			// on button type 3 and 5 clear complete key area before drawing
			if (pButton[i].nType == 3 || pButton[i].nType == 5)
			{
				UINT x0 = pButton[i].nOx;
				UINT y0 = pButton[i].nOy;
				EnterCriticalSection(&csGDILock); // solving NT GDI problems
				{
					StretchBlt(hWindowDC,
							   (x0 - nBackgroundX) * nAppZoom, (y0 - nBackgroundY) * nAppZoom,
							   pButton[i].nCx * nAppZoom, pButton[i].nCy * nAppZoom,
							   hMainDC,
							   x0, y0,
							   pButton[i].nCx, pButton[i].nCy,
							   SRCCOPY);
				}
				LeaveCriticalSection(&csGDILock);
			}
			DrawButton(i);					// redraw pressed button
		}
	}
	return;
}



//################
//#
//#    Annunciators
//#
//################

VOID DrawAnnunciator(UINT nId, BOOL bOn)
{
	UINT nSx,nSy;

	--nId;									// zero based ID
	if (nId >= ARRAYSIZEOF(pAnnunciator)) return;
	if (bOn)
	{
		nSx = pAnnunciator[nId].nDx;		// position of annunciator
		nSy = pAnnunciator[nId].nDy;
	}
	else
	{
		nSx = pAnnunciator[nId].nOx;		// position of background
		nSy = pAnnunciator[nId].nOy;
	}
	EnterCriticalSection(&csGDILock);		// solving NT GDI problems
	{
		StretchBlt(hWindowDC,
			(pAnnunciator[nId].nOx - nBackgroundX) * nAppZoom, (pAnnunciator[nId].nOy - nBackgroundY) * nAppZoom,
			pAnnunciator[nId].nCx * nAppZoom, pAnnunciator[nId].nCy * nAppZoom,
			hMainDC,
			nSx, nSy,
			pAnnunciator[nId].nCx, pAnnunciator[nId].nCy,
			SRCCOPY);
	}
	LeaveCriticalSection(&csGDILock);
	return;
}



//################
//#
//#    Mouse
//#
//################

static BOOL ClipButton(UINT x, UINT y, UINT nId)
{
	x += nBackgroundX * nAppZoom;			// source display offset
	y += nBackgroundY * nAppZoom;

	return (pButton[nId].nOx * nAppZoom <= x)
		&& (pButton[nId].nOy * nAppZoom <= y)
		&& (x < (pButton[nId].nOx+pButton[nId].nCx) * nAppZoom)
		&& (y < (pButton[nId].nOy+pButton[nId].nCy) * nAppZoom);
}

BOOL IsButtonArea(UINT x, UINT y)
{
	UINT i;

	for (i = 0; i < nButtons; i++)			// scan all buttons
	{
		if (ClipButton(x,y,i))				// position inside button area?
			return TRUE;
	}
	return FALSE;
}

VOID MouseButtonDownAt(UINT nFlags, DWORD x, DWORD y)
{
	UINT i;

#if defined LONGHOLDTIME
	bLongHold = TRUE;
	dwLongTime = GetTickCount();
#endif

	for (i=0; i<nButtons; i++)
	{
		if (ClipButton(x,y,i))
		{
			if (pButton[i].dwFlags&BUTTON_NOHOLD)
			{
				if (nFlags&MK_LBUTTON)		// use only with left mouse button
				{
					bClicking = TRUE;
					uButtonClicked = i;
					uLastPressedKey = i;	// save pressed key
					bPressed = TRUE;		// var uLastPressedKey valid
					pButton[i].bDown = TRUE;
					DrawButton(i);
				}
				return;
			}
			if (pButton[i].dwFlags&BUTTON_VIRTUAL)
			{
				if (!(nFlags&MK_LBUTTON))	// use only with left mouse button
					return;
				bClicking = TRUE;
				uButtonClicked = i;
			}
			uLastPressedKey = i;			// save pressed key
			bPressed = TRUE;				// var uLastPressedKey valid
			PressButton(i);
			return;
		}
	}
}

VOID MouseButtonUpAt(UINT nFlags, DWORD x, DWORD y)
{
	UINT i;

#if defined LONGHOLDTIME
	// key long hold active and lond hold time elapsed
	if (bLongHold && (GetTickCount() - dwLongTime) >= LONGHOLDTIME)
	{
		bLongHold = FALSE;					// prepare long hold for next key
		return;								// ignore mouse up
	}
	bLongHold = FALSE;						// deactivate key long hlod

	if (bPressed)							// emulator key pressed
	{
		ReleaseAllButtons();				// release all buttons
		return;
	}
#endif
	for (i=0; i<nButtons; i++)
	{
		if (ClipButton(x,y,i))
		{
			if ((bClicking)&&(uButtonClicked != i)) break;
#if defined LONGHOLDTIME
			ReleaseButton(i);
#else
			if (i == uLastPressedKey)		// releasing last pressed key?
				ReleaseAllButtons();		// release all buttons
#endif
			break;
		}
	}
	bClicking = FALSE;
	uButtonClicked = 0;
	return;
 	// mksg.de // UNREFERENCED_PARAMETER(nFlags);
}

VOID MouseMovesTo(UINT nFlags, DWORD x, DWORD y)
{
	if (!(nFlags&MK_LBUTTON)) return;						// left mouse key not pressed -> quit
#if defined LONGHOLDTIME
	if ((bPressed) && !(ClipButton(x,y,uLastPressedKey)))	// not on last pressed key
	{
		bLongHold = FALSE;									// deactivate key long hlod
		ReleaseAllButtons();								// release all buttons
	}
#endif
	if (!bClicking) return;									// normal emulation key -> quit

	if (pButton[uButtonClicked].dwFlags&BUTTON_NOHOLD)
	{
		if (ClipButton(x,y, uButtonClicked) != pButton[uButtonClicked].bDown)
		{
			pButton[uButtonClicked].bDown = !pButton[uButtonClicked].bDown;
			DrawButton(uButtonClicked);
		}
		return;
	}
	if (pButton[uButtonClicked].dwFlags&BUTTON_VIRTUAL)
	{
		if (!ClipButton(x,y, uButtonClicked))
		{
			ReleaseButton(uButtonClicked);
			bClicking = FALSE;
			uButtonClicked = 0;
		}
		return;
	}
	return;
}



//################
//#
//#    Keyboard
//#
//################

VOID RunKey(BYTE nId, BOOL bPressed)
{
	if (pVKey[nId])
	{
		KmlLine* pLine = pVKey[nId]->pFirstLine;
		byVKeyMap[nId] = bPressed;
		while (pLine) pLine = RunLine(pLine);
	}
	else
	{
		if (bDebug&&bPressed)
		{
			TCHAR szTemp[128];
			wsprintf(szTemp,_T("Scancode %i"),nId);
			InfoMessage(szTemp);
		}
	}
	return;
}



//################
//#
//#    Macro player
//#
//################

VOID PlayKey(UINT nOut, UINT nIn, BOOL bPressed)
{
	// scan from last buttons because LCD buttons mostly defined first
	INT i = nButtons;						
	while (--i >= 0)
	{
		if (pButton[i].nOut == nOut && pButton[i].nIn == nIn)
		{
			if (bPressed)
				PressButton(i);
			else
				ReleaseButton(i);
			return;
		}
	}
	return;
}



//################
//#
//#    Load and Initialize Script
//#
//################

static KmlBlock* LoadKMLGlobal(NSString * _filename)
{
	HANDLE    hFile;
	NSString *    lpBuf;
	KmlBlock* pBlock;
	DWORD     eToken;

	hFile = CreateFile(FullFilename(_filename),
					   GENERIC_READ,
					   FILE_SHARE_READ,
					   NULL,
					   OPEN_EXISTING,
					   FILE_ATTRIBUTE_NORMAL,
					   NULL);
	if (hFile == INVALID_HANDLE_VALUE) return NULL;
	if ((lpBuf = MapKMLFile(hFile)) == NULL)
		return NULL;

	InitLex(lpBuf);
	pBlock = NULL;
	while ((eToken = Lex(LEX_BLOCK)) != TOK_NONE)
	{
		if (eToken == TOK_GLOBAL)
		{
			pBlock = ParseBlock(eToken);
			if (pBlock) pBlock->pNext = NULL;
			break;
		}
	}
	CleanLex();
	ClearLog();
	HeapFree(hHeap,0,lpBuf);
	return pBlock;
}*/

BOOL InitKML(NSString * _filename, BOOL bNoLog)
{
	NSString *    _buffer;
	KmlBlock*	  pBlock;
	BOOL		  bOk = FALSE;

	//KillKML();

	nBlocksIncludeLevel = 0;
	
	_buffer = [[NSString alloc] initWithContentsOfFile:_filename];
	

	InitLex(_buffer);
	pKml = ParseBlocks();
	CleanLex();

	[_buffer release];
	
	
	if (pKml == NULL) goto quit;

	pBlock = pKml;
	while (pBlock)
	{
		switch (pBlock->eType)
		{
		case TOK_BUTTON:
			InitButton(pBlock);
			break;
		case TOK_SCANCODE:
			nScancodes++;
			pVKey[pBlock->nId] = pBlock;
			break;
		case TOK_ANNUNCIATOR:
			InitAnnunciator(pBlock);
			break;
		case TOK_GLOBAL:
			InitGlobal(pBlock);
			break;
		case TOK_LCD:
			//InitLcd(pBlock);
			break;
		case TOK_BACKGROUND:
			//InitBackground(pBlock);
			break;
		default:
			//PrintfToLog(_T("Block %s Ignored."), GetStringOf(pBlock->eType));
			pBlock = pBlock->pNext;
		}
		pBlock = pBlock->pNext;
	}

	if (!isModelValid(cCurrentRomType))
	{
		//AddToLog(_T("This KML Script doesn't specify a valid model."));
		goto quit;
	}
	if (pbyRom == NULL)
	{
		//AddToLog(_T("This KML Script doesn't specify the ROM to use, or the ROM could not be loaded."));
		goto quit;
	}/*
	if (hMainDC == NULL)
	{
		//AddToLog(_T("This KML Script doesn't specify the background bitmap, or bitmap could not be loaded."));
		goto quit;
	}
	if (!CrcRom(&wRomCrc))					// build patched ROM fingerprint and check for unpacked data
	{
		//AddToLog(_T("Packed ROM image detected."));
		UnmapRom();							// free memory
		goto quit;
	}

	CreateLcdBitmap();

	//PrintfToLog(_T("%i Buttons Defined"), nButtons);
	//PrintfToLog(_T("%i Scancodes Defined"), nScancodes);
	//PrintfToLog(_T("%i Annunciators Defined"), nAnnunciators);

	bOk = TRUE;
*/
quit:
	if (bOk)
	{
		if (!bNoLog)
		{
			//AddToLog(_T("Press Ok to Continue."));
			//if (bAlwaysDisplayLog&&(!DisplayKMLLog(bOk)))
			{
				//KillKML();
				return FALSE;
			}
		}
	}
	else
	{
		//AddToLog(_T("Press Cancel to Abort."));
		//if (!DisplayKMLLog(bOk))
		{
			//KillKML();
			return FALSE;
		}
	}

	//ResizeWindow();
	//ClearLog();
	return bOk;
}
