/*
 *  m48MenuSettingsMultiValue.m
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

#import "m48MenuSettingsMultiValue.h"

#define kViewTag				1

@implementation m48MenuSettingsMultiValue

@synthesize key = _key;
@synthesize titles = _titles;
@synthesize values = _values;
@synthesize currentIndex = _currentIndex;

+ (NSString *)getCurrentTitleForSettingsDict:(NSDictionary *)aDict {
	NSArray * _titles = [aDict objectForKey:@"Titles"];
	NSArray * _values = [aDict objectForKey:@"Values"];
	NSString * _key =  [aDict objectForKey:@"Key"];
	
	// Decode current title
	NSString * val = [[NSUserDefaults standardUserDefaults] stringForKey:_key];
	NSString * temp;
	for (int i=[_values count]-1; i >= 0; i--) {
		temp = [_values objectAtIndex:i];
		if ([temp isEqual:val]) {
			return [[[_titles objectAtIndex:i] copy] autorelease];
		}
	}
	return nil;
}


- (id)initWithSettingsDict:(NSDictionary *)aDict {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		
		self.titles = [aDict objectForKey:@"Titles"];
		self.values = [aDict objectForKey:@"Values"];
		self.key =  [aDict objectForKey:@"Key"];
		
		// Decode current title
		NSString * val = [[NSUserDefaults standardUserDefaults] stringForKey:_key];
		NSString * temp;
		for (int i=[_values count]-1; i >= 0; i--) {
			temp = [_values objectAtIndex:i];
			if ([temp isEqual:val]) {
				self.currentIndex = i;
				break;
			}
		}
		self.title = [aDict objectForKey:@"Title"];
	}
	return self;
}



- (void)dealloc {
	[_titles release];
	[_values release];
	[_key release];
	[super dealloc];
}

#pragma mark -
#pragma mark UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_titles count];
}

// to determine which UITableViewCell to be used on a given row.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	
	static NSString *kDisplayCell_ID = @"DisplayCellID";
	cell = [self.tableView dequeueReusableCellWithIdentifier:kDisplayCell_ID];
	if (cell == nil)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDisplayCell_ID] autorelease];
		//cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	else
	{
		// the cell is being recycled, remove old embedded controls
		UIView *viewToRemove = nil;
		viewToRemove = [cell.contentView viewWithTag:kViewTag];
		if (viewToRemove)
			[viewToRemove removeFromSuperview];
	}
	
	cell.textLabel.text = [_titles objectAtIndex:[indexPath row]];
	if ([indexPath row] == _currentIndex) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		cell.textLabel.textColor = [UIColor colorWithRed:0.196 green:0.310 blue:0.522 alpha:1.0];
	}
	else {
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.textColor = [UIColor blackColor];
	}
	
	return cell;
}


// the table's selection has changed, show the alert or action sheet
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[NSUserDefaults standardUserDefaults] setObject:[_values objectAtIndex:[indexPath row]] forKey:_key];
	_currentIndex = [indexPath row];
	
	[tableView reloadData];
	[tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:NO];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

}


@end
