/*
	File:		NSApplication-NTXSupport.h

	Contains:	NSApplication support category declarations for the Newton Inspector.

	Written by:	Newton Research Group, 2007.
*/

#import "NSApplication-NTXSupport.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Preferences.h"

@implementation NSApplication (NTX)

/*------------------------------------------------------------------------------
	Handle Preferences application menu item.
	Args:		sender
	Return:	--
------------------------------------------------------------------------------*/

- (IBAction) showPreferencesPanel: (id) sender
{
	[[NTXPreferenceController sharedController] showPreferencesPanel: sender];
}


/*------------------------------------------------------------------------------
	Handle Report Bugs application menu item.
	Args:		sender
	Return:	--
------------------------------------------------------------------------------*/

- (IBAction) reportBugs: (id) sender
{
	NSURL * url = [NSURL URLWithString: @"mailto:simonbell@me.com"
													 "?subject=Newton%20Toolkit%20Bug%20Report"
												  /*"&body=Share%20and%20Enjoy"*/ ];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

@end
