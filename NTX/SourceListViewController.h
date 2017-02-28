/*
	File:		SourceListViewController.h

	Abstract:	The NTXSourceListViewController controls the source list sidebar view.
					The source list is an NSOutlineView representing an NSArray of NTXProjectItem.

						projectItems: [
							"selectedItem": 1,
							"sortOrder": 0,
							"items": [
								[ "url": NSURL,
								  "type": 5,
								  "isMainLayout": NO ],
								  ...
							]
						]
					The NTXSourceListViewController represents this dictionary; displays/updates "items" and updates "selectedItem".

	Written by:		Newton Research, 2015.
*/

#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
	N T X S o u r c e S p l i t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the source list view.
----------------------------------------------------------------------------- */
@interface NTXSourceSplitViewController : NSSplitViewController
{
	IBOutlet NSSplitViewItem * sourceListItem;
}
- (void)toggleCollapsed;
@end


/* -----------------------------------------------------------------------------
	N T X S o u r c e L i s t V i e w C o n t r o l l e r
	A list of files, like Xcode’s.
----------------------------------------------------------------------------- */
@class NTXProjectItem;

@interface NTXSourceListViewController : NSViewController
{
	// outline sidebar
	IBOutlet NSOutlineView * sidebarView;

	// outline sidebar
	NSMutableArray<NSTreeNode *> * sourceList;
	NSTreeNode * projectNode;
	NSArray *_draggedNodes;
}

// MODEL
// source list containing array of NTXProjectItem
// the object is owned by the document but we can modify it when files are added/moved/deleted
// self.representedObject = NSMutableDictionary * projectItems;

@end
