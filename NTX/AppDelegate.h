/*
	File:		Controller.h

	Contains:	Cocoa controller delegate declarations for the Newton Inspector.

	Written by:	Newton Research Group, 2007.
*/

#import <Cocoa/Cocoa.h>
#import "PreferenceKeys.h"


@protocol NTXSleepProtocol
- (BOOL) applicationCanSleep;
- (void) applicationWillSleep;
@end


/* -----------------------------------------------------------------------------
	N T X C o n t r o l l e r
----------------------------------------------------------------------------- */
@class NTXToolkitProtocolController;

@interface NTXController : NSObject <NTXSleepProtocol>
// Platform
@property(strong) NSString * currentPlatform;

// Application
- (BOOL)applicationCanSleep;

// Toolkit
- (void)setPlatform:(NSString *)inPlatform;

// Build menu actions
- (IBAction)installToolkit:(id)sender;
- (IBAction)takeScreenshot:(id)sender;
- (IBAction)disconnect:(id)sender;

// UI
- (void)showScreenshot:(NSImage *)inShot;
@end
