/*
	File:		Controller.h

	Contains:	Cocoa controller delegate declarations for the Newton Inspector.

	Written by:	Newton Research Group, 2007.
*/

#import <Cocoa/Cocoa.h>
#import "PreferenceKeys.h"
#import "NSApplication-NTXSupport.h"


/* -----------------------------------------------------------------------------
	N T X C o n t r o l l e r
----------------------------------------------------------------------------- */
@class NTXToolkitProtocolController;

@interface NTXController : NSObject <NTXSleepProtocol>
// Platform
@property(strong) NSString * currentPlatform;
// Toolkit app communication
@property(strong) NTXToolkitProtocolController * ntkNub;
//@property(strong) NTXWindowController * theWindowController;

// Application
- (BOOL) applicationCanSleep;

// Toolkit
- (void) setPlatform: (NSString *) inPlatform;

// File menu actions
// Build menu actions
- (IBAction) connectInspector: (id) sender;
- (IBAction) installToolkit: (id) sender;
- (IBAction) takeScreenshot: (id) sender;

- (void) download: (NSURL *) inURL;
@end
