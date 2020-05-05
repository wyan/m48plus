/*
 *  m48Errors.h
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

#define ERROR_DOMAIN @"de.mksg.m48.ErrorDomain"

#define EXML	1		/* Error when parsing Xml-File */
#define EFIO	2		/* Error regarding file operations */
#define EWWW	3		/* Error regarding internet access */
#define ESND	4		/* Error regarding sound engine */
#define ESTK	5		/* Error regarding copy and paste stack */
#define EEMU	6		/* Errors regarding the emulator itself */