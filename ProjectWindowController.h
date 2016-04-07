/*
	File:		ProjectWindowController.h

	Abstract:	The NTXProjectWindowController coordinates display of the document selected in the source list for editing.

	Written by:		Newton Research, 2015.
*/

#import "ToolkitProtocolController.h"
#import "SettingsViewController.h"
#import "SourceListViewController.h"
#import "InspectorViewController.h"
#import "NRProgressBox.h"
#import "stdioDirector.h"


/* -----------------------------------------------------------------------------
	N T X P r o j e c t W i n d o w C o n t r o l l e r
----------------------------------------------------------------------------- */
@class NTXDocument, NTXContentViewController;

@interface NTXProjectWindowController : NSWindowController <NTXNubFeedback>
{
	// progress
	IBOutlet NRProgressBox * progressBox;
}
@property(readonly) NSImage * connectionIcon;
@property(weak) NTXToolkitProtocolController * ntkNub;
@property(strong) NSProgress * progress;
// source split view controller (split view containing source list)
@property NTXSourceSplitViewController * sourceSplitController;
// content split view controller (split view containing TellUser text)
@property NTXInspectorSplitViewController * inspectorSplitController;
// document editor content controller
@property NTXContentViewController * contentController;

// show the document’s editor
- (void)editDocument:(NTXDocument *)inDocument;

//- (void) deviceDidDisconnect;

@end
