/*
 *  m48MenuSettings.m
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

#import "m48MenuSettings.h"
#import "m48MenuSettingsSwitch.h"
#import "m48MenuSettingsSlider.h"
#import "m48MenuSettingsVolumeSlider.h"
#import "m48MenuSettingsMultiValue.h"

#define kViewTag				1

@implementation m48MenuSettings

@synthesize preferenceSpecifiers = _preferenceSpecifiers;

-(id)initWithPropertyList:(NSString *)resource {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        NSString *errorDesc = nil;
        NSPropertyListFormat format;
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:resource ofType:@"plist"];
        NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
		NSDictionary * temp;
        temp = (NSDictionary *)[NSPropertyListSerialization
								propertyListFromData:plistXML
								mutabilityOption:NSPropertyListMutableContainersAndLeaves
								format:&format errorDescription:&errorDesc];
        if (!temp) {
            //DEBUG NSLog(errorDesc);
            [errorDesc release];
        }
		self.preferenceSpecifiers = (NSArray *)[temp objectForKey:@"PreferenceSpecifiers"];
		self.title = (NSString *)[temp objectForKey:@"Title"];
    }
    return self;	
}

- (id)initWithSettingsDict:(NSDictionary *)aDict {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.preferenceSpecifiers = (NSArray *)[aDict objectForKey:@"PreferenceSpecifiers"];
		self.title = (NSString *)[aDict objectForKey:@"Title"];
	}
	return self;
}

- (void)dealloc {
	[_preferenceSpecifiers release];
    [super dealloc];
}

#pragma mark -
#pragma mark Implementation of viewController;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
	return ([self.navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation]);
}

- (void)viewWillAppear:(BOOL)animated {
	[self.tableView reloadData];
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)viewDidAppear:(BOOL)animated {
	[self.navigationController setToolbarHidden:YES animated:animated];
	[super viewDidAppear:animated];
}

#pragma mark -
#pragma mark UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	// Count
	NSEnumerator * objectEnumerator = [_preferenceSpecifiers objectEnumerator];
	NSInteger ctr = 0;
	NSDictionary * anObject;
	NSString * aString;
	while (anObject = [objectEnumerator nextObject]) {
		aString = [anObject objectForKey:@"Type"];
		if ([aString isEqual:@"PSGroupSpecifier"]) {
			ctr++;
		}
	}
	return ctr;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	// Count
	NSEnumerator * objectEnumerator = [_preferenceSpecifiers objectEnumerator];
	NSInteger ctr = 0;
	NSDictionary * anObject;
	NSString * aString;
	while (anObject = [objectEnumerator nextObject]) {
		aString = [anObject objectForKey:@"Type"];
		if ([aString isEqual:@"PSGroupSpecifier"]) {
			if (ctr == section) {
				aString = [anObject objectForKey:@"Title"];
				break;
			}
			ctr++;
		}
	}
	return aString;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	// Count
	NSEnumerator * objectEnumerator = [_preferenceSpecifiers objectEnumerator];
	NSInteger ctr = 0;
	NSInteger ctr2 = -1;
	NSDictionary * anObject;
	NSString * aString;
	while (anObject = [objectEnumerator nextObject]) {
		aString = [anObject objectForKey:@"Type"];
		if ([aString isEqual:@"PSGroupSpecifier"]) {
			if (ctr2 >= 0) // Stop counting
				return ctr2;
			if (ctr == section)
				ctr2 = 0; // Start counting
			ctr++;
		}
		else if (ctr2 >= 0) ctr2++;
	}
	if (ctr2 < 0)
		return 0;
	else
		return ctr2;
}

// to determine which UITableViewCell to be used on a given row.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	
		
	// Find the proper dictionary
	// Count
	NSEnumerator * objectEnumerator = [_preferenceSpecifiers objectEnumerator];
	NSInteger ctr = 0;
	NSInteger ctr2 = -1;
	NSDictionary * anObject;
	NSString * aString;
	while (anObject = [objectEnumerator nextObject]) {
		aString = [anObject objectForKey:@"Type"];
		if ([aString isEqual:@"PSGroupSpecifier"]) {
			if (ctr == indexPath.section)
				ctr2 = 0; // Start counting		
			ctr++;
		}
		else {
			if (ctr2 == indexPath.row) break;
			if (ctr2 >= 0) ctr2++;
		}
	}

	aString = [anObject objectForKey:@"Type"];
	
	// Retrieve a cell of the type required
	static NSString *kDisplayCellID_CellStyleDefault = @"DisplayCellID_CellStyleDefault";
	static NSString *kDisplayCellID_CellStyleValue1 = @"DisplayCellID_CellStyleValue1";
	
	if ([aString isEqual:@"PSMultiValueSpecifier"] == NO) {
		cell = [self.tableView dequeueReusableCellWithIdentifier:kDisplayCellID_CellStyleDefault];
		if (cell == nil)
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDisplayCellID_CellStyleDefault] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		else
		{
			// the cell is being recycled, remove old embedded controls
			UIView *viewToRemove = nil;
			viewToRemove = [cell viewWithTag:kViewTag];
			if (viewToRemove)
				[viewToRemove removeFromSuperview];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
	}
	else {
		cell = [self.tableView dequeueReusableCellWithIdentifier:kDisplayCellID_CellStyleValue1];
		if (cell == nil)
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kDisplayCellID_CellStyleValue1] autorelease];
		}
	}
	CGFloat width = cell.bounds.size.width;
	CGFloat margin = (self.view.bounds.size.width <= 480.0)?10.0:45.0;
	
	if ([aString isEqual:@"PSToggleSwitchSpecifier"]) { // Generate a toggle switch
		cell.textLabel.text = [anObject objectForKey:@"Title"];
		CGRect frame = CGRectMake(width - 50.0 - 10.0 - margin, 7.0, 50.0, 28.0);
		m48MenuSettingsSwitch * aSwitch = [[m48MenuSettingsSwitch alloc] initWithFrame:frame andSettingsDict:anObject];
		aSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		aSwitch.tag = kViewTag;	// tag this view for later so we can remove it from recycled table cells
		[cell addSubview:aSwitch];
		//[cell.contentView addSubview:aSwitch];
		[aSwitch release];
	}
	else if ([aString isEqual:@"PSSliderSpecifier"]) {
		cell.textLabel.text = [anObject objectForKey:@"Title"];
		CGFloat textLabelWidth = 60.0;
		CGRect frame = CGRectMake(10.0 + textLabelWidth + 15.0 + margin, 4.0, 0.0, 20.0);
		frame.size.width = width - frame.origin.x - 10.0 - margin;
		m48MenuSettingsSlider * aSlider = [[m48MenuSettingsSlider alloc] initWithFrame:frame andSettingsDict:anObject];
		aSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		aSlider.tag = kViewTag;	// tag this view for later so we can remove it from recycled table cells
		[cell addSubview:aSlider];
		[aSlider release];
	}
	else if ([aString isEqual:@"PSVolumeSliderSpecifier"]) {
		cell.textLabel.text = [anObject objectForKey:@"Title"];
		CGFloat textLabelWidth = 50.0;
		CGRect frame = CGRectMake(10.0 + textLabelWidth + 15.0 + margin, 4.0, 0.0, 20.0);
		frame.size.width = width - frame.origin.x - 10.0 - margin;
		m48MenuSettingsVolumeSlider * aSlider = [[m48MenuSettingsVolumeSlider alloc] initWithFrame:frame andSettingsDict:anObject];
		aSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		aSlider.tag = kViewTag;	// tag this view for later so we can remove it from recycled table cells
		[cell addSubview:aSlider];
		[aSlider release];
	}
	else if ([aString isEqual:@"PSMultiValueSpecifier"]) {
		cell.textLabel.text = [anObject objectForKey:@"Title"];
		cell.detailTextLabel.text = [m48MenuSettingsMultiValue getCurrentTitleForSettingsDict:anObject];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	else if ([aString isEqual:@"PSChildPaneSpecifier"]) {
		cell.textLabel.text = [anObject objectForKey:@"Title"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	}
	else {
		; //cell.textLabel.text = aString;
	}

	
	return cell;
}


// the table's selection has changed, show the alert or action sheet
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Find the proper dictionary
	// Count
	NSEnumerator * objectEnumerator = [_preferenceSpecifiers objectEnumerator];
	NSInteger ctr = 0;
	NSInteger ctr2 = -1;
	NSDictionary * anObject;
	NSString * aString;
	while (anObject = [objectEnumerator nextObject]) {
		aString = [anObject objectForKey:@"Type"];
		if ([aString isEqual:@"PSGroupSpecifier"]) {
			if (ctr == indexPath.section)
				ctr2 = 0; // Start counting		
			ctr++;
		}
		else {
			if (ctr2 == indexPath.row) break;
			if (ctr2 >= 0) ctr2++;
		}
	}
	
	aString = [anObject objectForKey:@"Type"];
	if ([aString isEqual:@"PSMultiValueSpecifier"]) {
		m48MenuSettingsMultiValue * nextTableViewController = [[m48MenuSettingsMultiValue alloc] initWithSettingsDict:anObject];
		[self.navigationController pushViewController:nextTableViewController animated:YES];
		[nextTableViewController release];
	}
	else if ([aString isEqual:@"PSChildPaneSpecifier"]) {
		m48MenuSettings * nextTableViewController = [[m48MenuSettings alloc] initWithSettingsDict:anObject];
		[self.navigationController pushViewController:nextTableViewController animated:YES];
		[nextTableViewController release];
	}
		
	// deselect the current row (don't keep the table selection persistent)
	//[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
	

}

@end
