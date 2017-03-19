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
#import "ProjectItem.h"

/* -----------------------------------------------------------------------------
	N T X S o u r c e S p l i t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the source list and info views.
----------------------------------------------------------------------------- */
@interface NTXSourceSplitViewController : NSSplitViewController
{
	IBOutlet NSSplitViewItem * sourceListItem;
	IBOutlet NSSplitViewItem * infoItem;
}
- (void)toggleCollapsedSplit:(NSInteger)index;
@end


/* -----------------------------------------------------------------------------
	N T X S o u r c e L i s t V i e w C o n t r o l l e r
	A list of files, like Xcode’s.
----------------------------------------------------------------------------- */

@interface NTXSourceListViewController : NSViewController
{
	// outline sidebar view
	IBOutlet NSOutlineView * sidebarView;
}
- (void)populateSourceList;
@end


/* -----------------------------------------------------------------------------
	N T X I n f o V i e w C o n t r o l l e r
	Represents info for the selected source file.
----------------------------------------------------------------------------- */

@interface NTXInfoViewController : NSViewController
@end
