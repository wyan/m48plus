/*
 *   fetch.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h" // Added by mksg.de

#import "opcodes.h"

#define	F   0xFF							// F = function

typedef struct
	{
		const VOID  *pLnk;
		const DWORD dwTyp;
	} JMPTAB;

// jump tables
static const JMPTAB oF_[] =
{
	oF0,        F,
	oF1,        F,
	oF2,        F,
	oF3,        F,
	oF4,        F,
	oF5,        F,
	oF6,        F,
	oF7,        F,
	oF8,        F,
	oF9,        F,
	oFA,        F,
	oFB,        F,
	oFC,        F,
	oFD,        F,
	oFE,        F,
	oFF,        F
};

static const JMPTAB oE_[] =
{
	oE0,        F,
	oE1,        F,
	oE2,        F,
	oE3,        F,
	oE4,        F,
	oE5,        F,
	oE6,        F,
	oE7,        F,
	oE8,        F,
	oE9,        F,
	oEA,        F,
	oEB,        F,
	oEC,        F,
	oED,        F,
	oEE,        F,
	oEF,        F
};

static const JMPTAB oD_[] =
{
	oD0,        F,
	oD1,        F,
	oD2,        F,
	oD3,        F,
	oD4,        F,
	oD5,        F,
	oD6,        F,
	oD7,        F,
	oD8,        F,
	oD9,        F,
	oDA,        F,
	oDB,        F,
	oDC,        F,
	oDD,        F,
	oDE,        F,
	oDF,        F
};

static const JMPTAB oC_[] =
{
	oC0,        F,
	oC1,        F,
	oC2,        F,
	oC3,        F,
	oC4,        F,
	oC5,        F,
	oC6,        F,
	oC7,        F,
	oC8,        F,
	oC9,        F,
	oCA,        F,
	oCB,        F,
	oCC,        F,
	oCD,        F,
	oCE,        F,
	oCF,        F
};

static const JMPTAB oBb_[] =
{
	oBb0,       F,
	oBb1,       F,
	oBb2,       F,
	oBb3,       F,
	oBb4,       F,
	oBb5,       F,
	oBb6,       F,
	oBb7,       F,
	oBb8,       F,
	oBb9,       F,
	oBbA,       F,
	oBbB,       F,
	oBbC,       F,
	oBbD,       F,
	oBbE,       F,
	oBbF,       F
};

static const JMPTAB oBa_[] =
{
	oBa0,       F,
	oBa1,       F,
	oBa2,       F,
	oBa3,       F,
	oBa4,       F,
	oBa5,       F,
	oBa6,       F,
	oBa7,       F,
	oBa8,       F,
	oBa9,       F,
	oBaA,       F,
	oBaB,       F,
	oBaC,       F,
	oBaD,       F,
	oBaE,       F,
	oBaF,       F
};

static const JMPTAB oB_[] =
{
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBa_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2,
	oBb_,       2
};

static const JMPTAB oAb_[] =
{
	oAb0,       F,
	oAb1,       F,
	oAb2,       F,
	oAb3,       F,
	oAb4,       F,
	oAb5,       F,
	oAb6,       F,
	oAb7,       F,
	oAb8,       F,
	oAb9,       F,
	oAbA,       F,
	oAbB,       F,
	oAbC,       F,
	oAbD,       F,
	oAbE,       F,
	oAbF,       F
};

static const JMPTAB oAa_[] =
{
	oAa0,       F,
	oAa1,       F,
	oAa2,       F,
	oAa3,       F,
	oAa4,       F,
	oAa5,       F,
	oAa6,       F,
	oAa7,       F,
	oAa8,       F,
	oAa9,       F,
	oAaA,       F,
	oAaB,       F,
	oAaC,       F,
	oAaD,       F,
	oAaE,       F,
	oAaF,       F
};

static const JMPTAB oA_[] =
{
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAa_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2,
	oAb_,       2
};

static const JMPTAB o9b_[] =
{
	o9b0,       F,
	o9b1,       F,
	o9b2,       F,
	o9b3,       F,
	o9b4,       F,
	o9b5,       F,
	o9b6,       F,
	o9b7,       F,
	o9b8,       F,
	o9b9,       F,
	o9bA,       F,
	o9bB,       F,
	o9bC,       F,
	o9bD,       F,
	o9bE,       F,
	o9bF,       F
};

static const JMPTAB o9a_[] =
{
	o9a0,       F,
	o9a1,       F,
	o9a2,       F,
	o9a3,       F,
	o9a4,       F,
	o9a5,       F,
	o9a6,       F,
	o9a7,       F,
	o9a8,       F,
	o9a9,       F,
	o9aA,       F,
	o9aB,       F,
	o9aC,       F,
	o9aD,       F,
	o9aE,       F,
	o9aF,       F
};

static const JMPTAB o9_[] =
{
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9a_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2,
	o9b_,       2
};

static const JMPTAB o8B_[] =
{
	o8B0,       F,
	o8B1,       F,
	o8B2,       F,
	o8B3,       F,
	o8B4,       F,
	o8B5,       F,
	o8B6,       F,
	o8B7,       F,
	o8B8,       F,
	o8B9,       F,
	o8BA,       F,
	o8BB,       F,
	o8BC,       F,
	o8BD,       F,
	o8BE,       F,
	o8BF,       F
};

static const JMPTAB o8A_[] =
{
	o8A0,       F,
	o8A1,       F,
	o8A2,       F,
	o8A3,       F,
	o8A4,       F,
	o8A5,       F,
	o8A6,       F,
	o8A7,       F,
	o8A8,       F,
	o8A9,       F,
	o8AA,       F,
	o8AB,       F,
	o8AC,       F,
	o8AD,       F,
	o8AE,       F,
	o8AF,       F
};

static const JMPTAB o81B_[] =
{
	o_invalid4, F,
	o81B1,      F,							// normally o_invalid4, beep patch
	o81B2,      F,
	o81B3,      F,
	o81B4,      F,
	o81B5,      F,
	o81B6,      F,
	o81B7,      F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F,
	o_invalid4, F
};

static const JMPTAB o81Af2_[] =
{
	o81Af20,    F,
	o81Af21,    F,
	o81Af22,    F,
	o81Af23,    F,
	o81Af24,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o81Af28,    F,
	o81Af29,    F,
	o81Af2A,    F,
	o81Af2B,    F,
	o81Af2C,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F
};

static const JMPTAB o81Af1_[] =
{
	o81Af10,    F,
	o81Af11,    F,
	o81Af12,    F,
	o81Af13,    F,
	o81Af14,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o81Af18,    F,
	o81Af19,    F,
	o81Af1A,    F,
	o81Af1B,    F,
	o81Af1C,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F
};

static const JMPTAB o81Af0_[] =
{
	o81Af00,    F,
	o81Af01,    F,
	o81Af02,    F,
	o81Af03,    F,
	o81Af04,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o81Af08,    F,
	o81Af09,    F,
	o81Af0A,    F,
	o81Af0B,    F,
	o81Af0C,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F
};

static const JMPTAB o81A_[] =
{
	o81Af0_,    5,
	o81Af1_,    5,
	o81Af2_,    5,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F
};

static const JMPTAB o819_[] =
{
	o819f0,     F,
	o819f1,     F,
	o819f2,     F,
	o819f3,     F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F
};

static const JMPTAB o818_[] =
{
	o818f0x,    F,
	o818f1x,    F,
	o818f2x,    F,
	o818f3x,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o818f8x,    F,
	o818f9x,    F,
	o818fAx,    F,
	o818fBx,    F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F,
	o_invalid6, F
};

static const JMPTAB o81_[] =
{
	o810,       F,
	o811,       F,
	o812,       F,
	o813,       F,
	o814,       F,
	o815,       F,
	o816,       F,
	o817,       F,
	o818_,      4,
	o819_,      4,
	o81A_,      4,
	o81B_,      3,
	o81C,       F,
	o81D,       F,
	o81E,       F,
	o81F,       F
};

static const JMPTAB o8081_[] =
{
	o80810,     F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F,
	o_invalid5, F
};

static const JMPTAB o808_[] =
{
	o8080,      F,
	o8081_,     4,
	o8082X,     F,
	o8083,      F,
	o8084n,     F,
	o8085n,     F,
	o8086n,     F,
	o8087n,     F,
	o8088n,     F,
	o8089n,     F,
	o808An,     F,
	o808Bn,     F,
	o808C,      F,
	o808D,      F,
	o808E,      F,
	o808F,      F
};

static const JMPTAB o80_[] =
{
	o800,       F,
	o801,       F,
	o802,       F,
	o803,       F,
	o804,       F,
	o805,       F,
	o806,       F,
	o807,       F,
	o808_,      3,
	o809,       F,
	o80A,       F,
	o80B,       F,
	o80Cn,      F,
	o80Dn,      F,
	o80E,       F,
	o80Fn,      F
};

static const JMPTAB o8_[] =
{
	o80_,       2,
	o81_,       2,
	o82n,       F,
	o83n,       F,
	o84n,       F,
	o85n,       F,
	o86n,       F,
	o87n,       F,
	o88n,       F,
	o89n,       F,
	o8A_,       2,
	o8B_,       2,
	o8Cd4,      F,
	o8Dd5,      F,
	o8Ed4,      F,
	o8Fd5,      F
};

static const JMPTAB o15_[] =
{
	o150a,      F,
	o151a,      F,
	o152a,      F,
	o153a,      F,
	o154a,      F,
	o155a,      F,
	o156a,      F,
	o157a,      F,
	o158x,      F,
	o159x,      F,
	o15Ax,      F,
	o15Bx,      F,
	o15Cx,      F,
	o15Dx,      F,
	o15Ex,      F,
	o15Fx,      F
};

static const JMPTAB o14_[] =
{
	o140,       F,
	o141,       F,
	o142,       F,
	o143,       F,
	o144,       F,
	o145,       F,
	o146,       F,
	o147,       F,
	o148,       F,
	o149,       F,
	o14A,       F,
	o14B,       F,
	o14C,       F,
	o14D,       F,
	o14E,       F,
	o14F,       F
};

static const JMPTAB o13_[] =
{
	o130,       F,
	o131,       F,
	o132,       F,
	o133,       F,
	o134,       F,
	o135,       F,
	o136,       F,
	o137,       F,
	o138,       F,
	o139,       F,
	o13A,       F,
	o13B,       F,
	o13C,       F,
	o13D,       F,
	o13E,       F,
	o13F,       F
};

static const JMPTAB o12_[] =
{
	o120,       F,
	o121,       F,
	o122,       F,
	o123,       F,
	o124,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F,
	o128,       F,
	o129,       F,
	o12A,       F,
	o12B,       F,
	o12C,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F
};

static const JMPTAB o11_[] =
{
	o110,       F,
	o111,       F,
	o112,       F,
	o113,       F,
	o114,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F,
	o118,       F,
	o119,       F,
	o11A,       F,
	o11B,       F,
	o11C,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F
};

static const JMPTAB o10_[] =
{
	o100,       F,
	o101,       F,
	o102,       F,
	o103,       F,
	o104,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F,
	o108,       F,
	o109,       F,
	o10A,       F,
	o10B,       F,
	o10C,       F,
	o_invalid3, F,
	o_invalid3, F,
	o_invalid3, F
};

static const JMPTAB o1_[] =
{
	o10_,       2,
	o11_,       2,
	o12_,       2,
	o13_,       2,
	o14_,       2,
	o15_,       2,
	o16x,       F,
	o17x,       F,
	o18x,       F,
	o19d2,      F,
	o1Ad4,      F,
	o1Bd5,      F,
	o1Cx,       F,
	o1Dd2,      F,
	o1Ed4,      F,
	o1Fd5,      F
};

static const JMPTAB o0E_[] =
{
	o0Ef0,      F,
	o0Ef1,      F,
	o0Ef2,      F,
	o0Ef3,      F,
	o0Ef4,      F,
	o0Ef5,      F,
	o0Ef6,      F,
	o0Ef7,      F,
	o0Ef8,      F,
	o0Ef9,      F,
	o0EfA,      F,
	o0EfB,      F,
	o0EfC,      F,
	o0EfD,      F,
	o0EfE,      F,
	o0EfF,      F
};

static const JMPTAB o0_[] =
{
	o00,        F,
	o01,        F,
	o02,        F,
	o03,        F,
	o04,        F,
	o05,        F,
	o06,        F,
	o07,        F,
	o08,        F,
	o09,        F,
	o0A,        F,
	o0B,        F,
	o0C,        F,
	o0D,        F,
	o0E_,       3,
	o0F,        F
};

static const JMPTAB o_[] =
{
	o0_,        1,
	o1_,        1,
	o2n,        F,
	o3X,        F,
	o4d2,       F,
	o5d2,       F,
	o6d3,       F,
	o7d3,       F,
	o8_,        1,
	o9_,        1,
	oA_,        1,
	oB_,        1,
	oC_,        1,
	oD_,        1,
	oE_,        1,
	oF_,        1
};

// opcode dispatcher
VOID EvalOpcode(LPBYTE I)
{
	DWORD         dwTemp,dwIndex = 0;
	JMPTAB const *pJmpTab = o_;
	
	do
	{
		dwTemp  = I[dwIndex];				// table entry
		_ASSERT(dwTemp <= 0xf);				// found packed data
		dwIndex = pJmpTab[dwTemp].dwTyp;	// next pointer type
		pJmpTab = pJmpTab[dwTemp].pLnk;		// next pointer to table/function
	}
	while (dwIndex != F);					// reference to table? -> again
	
	((VOID (*)(LPBYTE)) pJmpTab)(I);		// call function
	return;
}