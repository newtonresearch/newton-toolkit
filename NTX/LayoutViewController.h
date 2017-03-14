/*
	File:		LayoutViewController.h

	Abstract:	The NTXLayoutViewController controls the view template hierarchy sidebar view.
					The source list is an NSOutlineView representing the layout stream file’s templatehierarchy slot.

	SlotDescriptor := {value: "Example",
							 __ntDataType: "TEXT",
							 __ntFlags: 0,
							 __ntEffect: 0}

	ViewTemplateDescriptor := {value: {<tag>:<SlotDescriptor>,...},	tag=stepChildren => slot descriptor value is array of ViewTemplateDescriptors
									   __ntId: 'protoApp,
									   __ntName: "MainView",
										__ntDeclare: nil,
										__ntExternalFile: nil}

	Written by:		Newton Research, 2016.
*/

#import <Cocoa/Cocoa.h>
#import "NewtonKit.h"

/* -----------------------------------------------------------------------------
	N T X L a y o u t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the view template list view.
----------------------------------------------------------------------------- */
@interface NTXLayoutViewController : NSSplitViewController
{
	IBOutlet NSSplitViewItem * templateListItem;
}
- (void)toggleCollapsed;
@end


/* -----------------------------------------------------------------------------
	N T X T e m p l a t e L i s t V i e w C o n t r o l l e r
	A list of view templates, like Xcode’s.
----------------------------------------------------------------------------- */
@interface NTXTemplateListViewController : NSViewController
{
	// outline sidebar
	IBOutlet NSOutlineView * sidebarView;

	RefStruct templateHierarchy;
}
@property(readonly) Ref selectedViewTemplate;
@end

@interface NTXTemplateDescriptor : NSObject
{
	RefStruct viewTemplateDescriptor;
}
@property(assign) Ref value;
@property(readonly) NSString * title;
@property(readonly) bool hasChildren;
- (id)init:(RefArg)descriptor;
@end

@interface NTXSlotDescriptor : NSObject
{
	RefStruct slotDescriptor;
}
@property(assign) Ref value;
@property(strong) NSString * tag;
@property(readonly) NSString * title;
@property(readonly) NSString * type;
@property(readonly) int flags;

// TEXT
@property(strong) NSString * text;
// NUMB
@property NSInteger number;
// BOOL
@property BOOL boolean;
// RECT
@property NSInteger boundsLeft;
@property NSInteger boundsRight;
@property(readonly) NSInteger boundsWidth;
@property NSInteger boundsTop;
@property NSInteger boundsBottom;
@property(readonly) NSInteger boundsHeight;

// viewFlags
@property BOOL _vVisible;
@property BOOL _vReadOnly;
@property BOOL _vApplication;
@property BOOL _vCalculateBounds;
@property BOOL _vNoKeys;
@property BOOL _vClipping;
@property BOOL _vFloating;
@property BOOL _vWriteProtected;
@property BOOL _vNoScripts;
@property BOOL _vSingleUnit;
@property BOOL _vClickable;
@property BOOL _vStrokesAllowed;
@property BOOL _vGesturesAllowed;
@property BOOL _vCharsAllowed;
@property BOOL _vNumbersAllowed;
@property BOOL _vLettersAllowed;
@property BOOL _vPunctuationAllowed;
@property BOOL _vShapesAllowed;
@property BOOL _vMathAllowed;
@property BOOL _vAnythingAllowed;
@property BOOL _vCapsRequired;
@property BOOL _vCustomDictionaries;
@property NSInteger _vField;

// viewFormat
@property NSInteger _vfPen;
@property NSInteger _vfRoundness;
@property NSInteger _vfInset;
@property NSInteger _vfShadow;
@property NSInteger _vfFrame;
@property NSInteger _vfFill;
@property NSInteger _vfLines;

// viewJustify;
@property NSInteger _vjParentH;
@property NSInteger _vjParentV;
@property NSInteger _vjSiblingH;
@property NSInteger _vjSiblingV;
@property NSInteger _vjTextH;
@property NSInteger _vjTextV;
@property NSInteger _vjTextLimits;
@property BOOL _vjReflow;
@property BOOL _vjChildrenLasso;

- (id)init:(RefArg)descriptor;
@end


/* -----------------------------------------------------------------------------
	N T X S l o t L i s t V i e w C o n t r o l l e r
	A list of slots in a view template.
----------------------------------------------------------------------------- */

@interface NTXSlotListViewController : NSViewController
{
	// single-column table of slots in the view template
	IBOutlet NSTableView * listView;

	RefStruct viewTemplateValue;
	NSMutableArray * slots;
}
@end


/* -----------------------------------------------------------------------------
	N T X S l o t E d i t o r V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */
@class NTXEditorView;

@interface NTXSlotEditorViewController : NSViewController
{
	IBOutlet NTXEditorView * slotView;
}
@end

