/*
	File:		NCXPreferences.h

	Contains:	Preferences controller for the NTX app.

	Written by:	Newton Research Group, 2013.
*/

#import <Cocoa/Cocoa.h>
#import "PreferenceKeys.h"

@interface NTXPreferenceController : NSWindowController <NSToolbarDelegate>
{
//	preference panes
	IBOutlet NSView * fGeneralView, * fUpdateView;

//	serial prefs
	NSArray * ports;
	NSString * serialPort;
	NSUInteger serialSpeed;
	IBOutlet NSPopUpButton * serialPortPopup;

//	software update prefs
	IBOutlet NSPopUpButton * frequencyPopUp;
	IBOutlet NSButton * autoCheck;
}

+ (NTXPreferenceController *) sharedController;
+ (int) preferredSerialPort: (NSString * __strong *) outPort bitRate: (NSUInteger *) outRate;

- (IBAction) showPreferencesPanel: (id) sender;
- (IBAction) setPrefsView: (id) sender;

//	serial prefs
- (IBAction) updateSerialPort: (id) sender;

//	software update prefs
- (IBAction) updateFrequency: (id) sender;
@end
