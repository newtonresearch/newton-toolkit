/*
	File:		ProjectWindowController.h

	Abstract:	The NTXProjectWindowController coordinates display of the document selected in the source list for editing.

	Written by:		Newton Research, 2015.
*/

#import "ToolkitProtocolController.h"
#import "SettingsViewController.h"
#import "SourceListViewController.h"
#import "ContentViewController.h"
#import "InspectorViewController.h"
#import "NRProgressBox.h"
#import "stdioDirector.h"


/* -----------------------------------------------------------------------------
	N T X P r o j e c t W i n d o w C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXProjectWindowController : NSWindowController<NTXNubFeedback>
{
	// progress
	IBOutlet NRProgressBox * progressBox;
}
@property(nonatomic,assign,getter=isConnected) BOOL connected;
@property(nonatomic,strong) NSImage * connectionIcon;
@property(nonatomic,strong) NSProgress * progress;
@property(nonatomic,assign) NSString * progressText;		// updating this property will update the window’s progress box

// source split view controller (split view containing source list)
@property NTXSourceSplitViewController * sourceSplitController;
@property NTXSourceListViewController * sourceListController;
@property NTXInfoViewController * sourceInfoController;
// document editor content controller
@property NTXContentViewController * contentController;
// content split view controller (split view containing TellUser text)
@property NTXInspectorSplitViewController * inspectorSplitController;
@property NTXInspectorViewController * inspector;

// sidebar
- (void)sourceSelectionDidChange:(NTXProjectItem *)item;

@end
