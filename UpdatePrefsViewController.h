/*
	File:		UpdatePrefsViewController.h

	Contains:	Software update preferences controller for the NTX app.

	Written by:	Newton Research Group, 2015.
*/

#import <Cocoa/Cocoa.h>
#import "PreferenceKeys.h"

@interface UpdatePrefsViewController : NSViewController
{
//	software update prefs
	IBOutlet NSPopUpButton * frequencyPopUp;
	IBOutlet NSButton * autoCheck;
}

//	software update prefs
- (IBAction) updateFrequency: (id) sender;
@end
