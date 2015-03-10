/*
	File:		ProjectWindowController.h

	Abstract:	Interface for NTXWindowController class.

	Written by:		Newton Research, 2012.
*/

#import "SettingsViewController.h"
#import "NRProgressBox.h"
#import "stdioDirector.h"


/* -----------------------------------------------------------------------------
	N T X O u t l i n e V i e w
----------------------------------------------------------------------------- */

@interface NTXOutlineView : NSOutlineView
- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem;
- (void) selectAll: (id) sender;
@end


/* -----------------------------------------------------------------------------
	N T X S p l i t V i e w
----------------------------------------------------------------------------- */
@interface NTXSplitView : NSSplitView
@property NSString * statusText;
@end


/* -----------------------------------------------------------------------------
	N T X P r o j e c t W i n d o w C o n t r o l l e r
----------------------------------------------------------------------------- */
@class NTXProjectItem, NTXEditorView;

@interface NTXProjectWindowController : NSWindowController
{
	// MODEL
	// outline sidebar
	NSTreeNode						* sourceListRoot;
	NSTreeNode						* projectNode;
	NSArray							*_draggedNodes;

	// VIEW
	// split views
	IBOutlet NSSplitView			* navSplitView;
	IBOutlet NTXSplitView		* contentSplitView;
	IBOutlet NSView				* navigatorView;
	IBOutlet NSView				* contentView;
	IBOutlet NSView				* debugView;
	// outline sidebar
	IBOutlet NSOutlineView		* sidebarView;
	// switched content
	IBOutlet NSView				* placeholderView;
	// inspector
	IBOutlet NTXEditorView		* inspectorView;
	// progress
	IBOutlet NRProgressBox		* progressBox;

	NSDictionary * newtonTxAttrs;
	NSDictionary * userTxAttrs;
	NTXOutputRedirect * redirector;

	// CONTROLLER
	NTXProjectItem					* currentSelection;
}
// text to be diplayed from NS TellUser()
@property NSString * tellUserText;

//- (void) deviceDidDisconnect;

// detail view
- (void) removeItemView;
- (void) changeItemView;

// split view arrangement
- (IBAction) toggleSplit: (id) sender;

// Build menu actions
- (IBAction) buildPackage: (id) sender;
- (IBAction) downloadPackage: (id) sender;
- (IBAction) exportPackage: (id) sender;

@end
