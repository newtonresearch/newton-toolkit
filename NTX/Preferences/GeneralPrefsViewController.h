/*
	File:		GeneralPrefsViewController.h

	Contains:	General preferences view controller for the NTX app.

	Written by:	Newton Research Group, 2015.
*/

#import <Cocoa/Cocoa.h>
#import "PreferenceKeys.h"

@interface GeneralPrefsViewController : NSViewController
{
//	serial prefs
	NSArray * ports;
	NSString * serialPort;
	NSUInteger serialSpeed;
	IBOutlet NSPopUpButton * serialPortPopup;
}

+ (int) preferredSerialPort: (NSString * __strong *) outPort bitRate: (NSUInteger *) outRate;

//	serial prefs
- (IBAction) updateSerialPort: (id) sender;
@end
