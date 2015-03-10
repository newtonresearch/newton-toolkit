/*
	File:		NSApplication-NTXSupport.h

	Contains:	NSApplication support category declarations for the Newton Inspector.

	Written by:	Newton Research Group, 2007.
*/

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibDeclarations.h> // For IBAction

@interface NSApplication (NTX)
- (IBAction) showPreferencesPanel: (id) sender;
- (IBAction) reportBugs: (id) sender;
@end


@protocol NTXSleepProtocol
- (BOOL) applicationCanSleep;
- (void) applicationWillSleep;
@end