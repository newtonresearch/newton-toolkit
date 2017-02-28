/*
	File:		SourceListViewController.m

	Abstract:	Implementation of NTXSourceListViewController class.

	Written by:		Newton Research, 2014.
*/

#import "SourceListViewController.h"
#import "ProjectWindowController.h"
#import "PreferenceKeys.h"
#import "ProjectItem.h"
#import "ProjectDocument.h"
#import "NTXDocument.h"
#import "Utilities.h"

#define kNTXReorderPasteboardType @"NTXSourceListItemPboardType"


#pragma mark - Split views
/* -----------------------------------------------------------------------------
	N T X S o u r c e S p l i t V i e w C o n t r o l l e r
	The sidebar half of the split view can be collapsed by a button
	in the window.
----------------------------------------------------------------------------- */
@implementation NTXSourceSplitViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	NTXProjectWindowController * wc = self.view.window.windowController;
	wc.sourceSplitController = self;
}

- (void)toggleCollapsed {
	sourceListItem.animator.collapsed = !sourceListItem.isCollapsed;
}

@end


#pragma mark - NTXSourceListViewController
/* -----------------------------------------------------------------------------
	N T X S o u r c e L i s t V i e w C o n t r o l l e r
	The source list controller represents the NTXProjectItems contained
	in the project document.
	It acts as the data source and delegate for the NSOutlineView.
----------------------------------------------------------------------------- */
@implementation NTXSourceListViewController


- (void)viewDidLoad
{
	[super viewDidLoad];

	// set up sidebar items ready to be populated when Newton connects
	sourceList = [[NSMutableArray alloc] init];

	// defer population until window has fully loaded
	dispatch_async(dispatch_get_main_queue(), ^{
		NTXProjectWindowController * wc = self.view.window.windowController;
		wc.sourceListController = self;

		[self populateSourceList];
	});
}


- (void)populateSourceList {

	if (self.representedObject == nil) {
		NTXProjectDocument * doc = [self.view.window.windowController document];
		self.representedObject = doc.projectItems;

		sourceList = [[NSMutableArray alloc] init];

		// create root node to represent the project settings
		projectNode = [[NSTreeNode alloc] initWithRepresentedObject:[[NTXProjectSettingsItem alloc] initWithProject:doc]];
		[sourceList addObject:projectNode];

		// build the source list tree from the document’s array of project items.
		// add projectItems to the project root node

		NSMutableArray * sidebarItems = projectNode.mutableChildNodes;
		NSArray * items = [doc.projectItems objectForKey:@"items"];
		for (NTXProjectItem * item in items) {
			NSTreeNode * itemNode = [[NSTreeNode alloc] initWithRepresentedObject:item];
			[sidebarItems addObject:itemNode];
		}

		// expand the project
		[sidebarView reloadData];
		[sidebarView expandItem:projectNode];

		// enable it
		sidebarView.enabled = YES;

		// scroll to the top in case the outline contents is very long
		[sidebarView.enclosingScrollView.verticalScroller setFloatValue:0.0];
		[sidebarView.enclosingScrollView.contentView scrollToPoint:NSMakePoint(0,0)];

		// register to get our custom type, strings, and filenames
		[sidebarView registerForDraggedTypes:[NSArray arrayWithObjects:kNTXReorderPasteboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
		[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
		[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];

		// restore the saved selection
		NSInteger selItem = [doc.projectItems[@"selectedItem"] integerValue] + 1;
		if (selItem >= items.count)
			selItem = 0;
		[sidebarView selectRowIndexes:[NSIndexSet indexSetWithIndex:selItem] byExtendingSelection:NO];
	}
}


- (IBAction)doubleClickedItem:(NSOutlineView *)sender {
	id item = [sender itemAtRow:sender.clickedRow];
 	if ([self outlineView:sender shouldShowOutlineCellForItem:item]) {
		if ([sender isItemExpanded:item]) {
			[sender collapseItem:item];
		} else {
			[sender expandItem:item];
		}
	}
}


/* -----------------------------------------------------------------------------
	Add files chosen by the user to the sourcelist.
	Args:		inFiles		NSArray of NSURL
	Return:	--
----------------------------------------------------------------------------- */
extern NSArray * gTypeNames;

- (int)filetype:(NSURL *)inURL
{
	int filetype = 0;
	// translate url extension to filetype
	CFStringRef extn = (__bridge CFStringRef)inURL.pathExtension;
	CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extn, NULL);
	for (NSString * type in gTypeNames) {
		if (UTTypeConformsTo(fileUTI, (__bridge CFStringRef)[NSString stringWithFormat:@"com.newton.%@", type])) {
			break;
		}
		++filetype;
	}
	if (filetype == gTypeNames.count) {
		// we didn’t recognise the type of file!
		if (UTTypeConformsTo(fileUTI, (__bridge CFStringRef)@"public.plain-text")) {
			// but we do allow plain text
			filetype = kScriptFileType;
		} else {
			// nope, really don’t like it
			filetype = -1;
		}
	}
	return filetype;
}

- (void) addToSourceList:(NSArray *)inFiles
{
  	NSMutableArray * sidebarItems = [projectNode mutableChildNodes];
	NSInteger afterIndex = sidebarView.selectedRow;

	NSMutableDictionary * projectItems = (NSMutableDictionary *)self.representedObject;
	NSMutableArray * items = [projectItems objectForKey:@"items"];

	// foreach url in inFiles
	//		make an NTXProjectItem
	//		make a tree node representing that item
	//		add the node to the tree
	for (NSURL * url in inFiles) {
		// translate url extension to filetype
		int filetype = [self filetype:url];
		if (filetype == -1)
			continue;	// we didn’t recognise the type of file!

		NTXProjectItem * item = [[NTXProjectItem alloc] initWithURL:url type:filetype];
		NSTreeNode * itemNode = [[NSTreeNode alloc] initWithRepresentedObject:item];
		if (afterIndex >= 0) {
			[items insertObject:item atIndex:afterIndex];
			[sidebarItems insertObject:itemNode atIndex:afterIndex];
			++afterIndex;
		} else {
			[items addObject:item];
			[sidebarItems addObject:itemNode];
		}
	}
	[sidebarView reloadData];

	NTXProjectDocument * doc = [self.view.window.windowController document];
	[doc updateChangeCount:NSChangeDone];
}


/* -----------------------------------------------------------------------------
	Rebuild the current source list array of project items.
	Args:		--
	Return:	--
----------------------------------------------------------------------------- */

- (void) rebuildProjectItems
{
	NSMutableDictionary * projectItems = (NSMutableDictionary *)self.representedObject;
	NSMutableArray * sidebarItems = [projectNode mutableChildNodes];
	NSMutableArray * items = [[NSMutableArray alloc] initWithCapacity:sidebarItems.count];
	for (NSTreeNode * itemNode in sidebarItems) {
		[items addObject: itemNode.representedObject];
	}
	[projectItems setObject:items forKey:@"items"];
	[projectItems setObject:[NSNumber numberWithInteger:sidebarView.selectedRow-1] forKey:@"selectedItem"];

	NTXProjectDocument * doc = [self.view.window.windowController document];
	[doc updateChangeCount:NSChangeDone];
}


#pragma mark - File menu actions
/* -----------------------------------------------------------------------------
	Create a new layout document.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) newLayoutDocument: (id) sender
{
	[self newDocument:@"Layout" type:NTXLayoutFileType];
}


/* -----------------------------------------------------------------------------
	Create a new proto template document.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) newProtoDocument: (id) sender
{
	;
}


/* -----------------------------------------------------------------------------
	Create a new NewtonScript document.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) newTextDocument: (id) sender
{
	[self newDocument:@"NewtonScript" type:NTXScriptFileType];
}


/* -----------------------------------------------------------------------------
	Create a new  document.
	Args:		inType	UTI of document
	Return:	--
----------------------------------------------------------------------------- */

- (void) newDocument:(NSString *)inName type:(NSString *)inType
{
	NSSavePanel * dlg = [NSSavePanel savePanel];
	dlg.title = [NSString stringWithFormat:@"New %@ File", inName];
	dlg.allowedFileTypes = [NSArray arrayWithObject:inType];
	[dlg runModal];
	// create the file
	NSError * __autoreleasing err = nil;
	[[NSData data] writeToURL:dlg.URL options:0 error:&err];
	// add to source list
	[self addToSourceList:[NSArray arrayWithObject:dlg.URL]];
}


/* -----------------------------------------------------------------------------
	Add documents to the project.
		present Open dialog, multiple selection
		will only allow document types we know about!
		add them to projectItems array after current selection (if any) else at end
		update sourcelist sidebar
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) addFiles: (id) sender
{
	NSOpenPanel * dlg = [NSOpenPanel openPanel];
	dlg.title = @"Add Files";
	dlg.allowsMultipleSelection = YES;
	dlg.canChooseFiles = YES;
	dlg.allowedFileTypes = [NSArray arrayWithObjects:NTXLayoutFileType,NTXScriptFileType,NTXStreamFileType,NTXCodeFileType,NTXPackageFileType, nil];
	[dlg runModal];
	// add to projectItems
	[self addToSourceList:dlg.URLs];
}


#pragma mark - NSOutlineView item insertion/deletion
/* -----------------------------------------------------------------------------
	Handle menu items.
----------------------------------------------------------------------------- */

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {

	if (menuItem.action == @selector(selectAll:))
		return NO;

	if (menuItem.action == @selector(delete:)) {
		// The delete selection item should be disabled if nothing is selected.
		return sidebarView.selectedRowIndexes.count > 0;
	}
	return YES;
}


- (IBAction)selectAll:(id)sender {
	// just don’t do it
}


- (IBAction)delete:(id)sender {
	[sidebarView beginUpdates];
	[[sidebarView selectedRowIndexes] enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger row, BOOL *stop) {
		NSTreeNode *node = [sidebarView itemAtRow:row];
		// more complicated than we need right now, but allows for items to be grouped in future
		NSTreeNode *parent = node.parentNode;
		NSMutableArray * childNodes = parent.mutableChildNodes;
		NSInteger index = [childNodes indexOfObject:node];
		[childNodes removeObjectAtIndex:index];
		[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:parent withAnimation:NSTableViewAnimationEffectFade | NSTableViewAnimationSlideLeft];
	}];
	[sidebarView endUpdates];
	[self rebuildProjectItems];
}


#pragma mark - NSOutlineViewDelegate protocol
/* -----------------------------------------------------------------------------
	Determine whether an item is a group title.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView isGroupItem:(id)inItem {
#if 0
	id item = [inItem representedObject];
	return [item isKindOfClass: [NTXProjectSettingsItem class]];
#else
	return NO;	// don’t make the project settings item look any different to a file project item
#endif
}

/* -----------------------------------------------------------------------------
	Show the disclosure triangle for the project.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView shouldShowOutlineCellForItem:(id)inItem {
	id item = [inItem representedObject];
	return [item isKindOfClass: [NTXProjectSettingsItem class]];
}

//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item;

/* -----------------------------------------------------------------------------
	We can select everything.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView shouldSelectItem:(id)inItem {
	return YES;
}


#pragma mark - NSOutlineViewDataSource protocol

- (NSArray *)childrenForItem:(id)inItem {
	return inItem ? [inItem childNodes] : sourceList;
}


/* -----------------------------------------------------------------------------
	Return the number of children a particular item has.
	Because we are using a standard tree of NSDictionary, we can just return
	the count.
----------------------------------------------------------------------------- */

- (NSInteger)outlineView:(NSOutlineView *)inView numberOfChildrenOfItem:(id)inItem {
	NSArray * children = [self childrenForItem:inItem];
	return children.count;
}


/* -----------------------------------------------------------------------------
	NSOutlineView will iterate over every child of every item, recursively asking
	for the entry at each index. Return the item at a given index.
----------------------------------------------------------------------------- */

- (id)outlineView:(NSOutlineView *)inView child:(int)index ofItem:(id)inItem {
    NSArray * children = [self childrenForItem:inItem];
    // This will return an NSTreeNode with our model object as the representedObject
    return children[index];
}


/* -----------------------------------------------------------------------------
	Determine whether an item can be expanded.
	In our case, if an item has children then it is expandable.    
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView isItemExpandable:(id)inItem {
	return ![inItem isLeaf];
}


/* -----------------------------------------------------------------------------
	NSOutlineView calls this for each column in your NSOutlineView, for each item.
	Return what you want displayed in each column.
----------------------------------------------------------------------------- */

- (id)outlineView:(NSOutlineView *)inView viewForTableColumn:(NSTableColumn *)inColumn item:(id)inItem
{
	NTXProjectItem * item = [inItem representedObject];

	NSTableCellView * cellView = [inView makeViewWithIdentifier:@"Source" owner:self];
	if (item.name) {
		cellView.textField.stringValue = item.name;
		// If file does not exist at URL, make text red.
		if ([NSFileManager.defaultManager fileExistsAtPath:item.url.path]) {
			cellView.textField.textColor = NSColor.blackColor;
		} else {
			cellView.textField.textColor = NSColor.redColor;
		}
	}
	if (item.image) {
		cellView.imageView.image = item.image;
	}
	return cellView;
}


/* -----------------------------------------------------------------------------
	Optional method: needed to allow editing.
----------------------------------------------------------------------------- */

- (void)outlineView:(NSOutlineView *)inView setObjectValue:(id)inObject forTableColumn:(NSTableColumn *)inColumn byItem:(id)inItem {
	NTXProjectItem * item = [inItem representedObject];
	item.name = inObject;	// property setter will rename URL on disk
}


/* -----------------------------------------------------------------------------
	The selection changed -- update the content view accordingly.
----------------------------------------------------------------------------- */

- (void)outlineViewSelectionDidChange:(NSNotification *)inNotification
{
	// remember the selected item while we’re here
	NSMutableDictionary * projectItems = (NSMutableDictionary *)self.representedObject;
	[projectItems setObject:[NSNumber numberWithInteger:sidebarView.selectedRow-1] forKey:@"selectedItem"];

	NSTreeNode * theNode = [sidebarView itemAtRow:sidebarView.selectedRow];
	NTXProjectItem * item = [theNode representedObject];
	[self.view.window.windowController sourceSelectionDidChange:item];
}


/* -----------------------------------------------------------------------------
	Drag reordering.
	Multiple drag images are supported by using this delegate method.
----------------------------------------------------------------------------- */

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)inView pasteboardWriterForItem:(id)inItem {
	return (id <NSPasteboardWriting>) [inItem representedObject];
}


/* -----------------------------------------------------------------------------
	Setup a local reorder.
----------------------------------------------------------------------------- */

- (void)outlineView:(NSOutlineView *)inView draggingSession:(NSDraggingSession *)inSession willBeginAtPoint:(NSPoint)inPoint forItems:(NSArray *)inDraggedItems {
	_draggedNodes = inDraggedItems;
	[inSession.draggingPasteboard setData:[NSData data] forType:kNTXReorderPasteboardType];
}


/* -----------------------------------------------------------------------------
	If the session ended in the trash then delete all the items.
----------------------------------------------------------------------------- */

- (void)outlineView:(NSOutlineView *)inView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	if (operation == NSDragOperationDelete) {
		[sidebarView beginUpdates];
		[_draggedNodes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id node, NSUInteger index, BOOL *stop) {
			// remove item from document
			id parent = [node parentNode];
			NSMutableArray *children = [parent mutableChildNodes];
			NSInteger childIndex = [children indexOfObject:node];
			[children removeObjectAtIndex:childIndex];
			[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parent withAnimation:NSTableViewAnimationEffectFade];
		}];
		[sidebarView endUpdates];
		[self rebuildProjectItems];
	}

	_draggedNodes = nil;
}



- (BOOL)treeNode:(NSTreeNode *)treeNode isDescendantOfNode:(NSTreeNode *)parentNode {
	while (treeNode != nil) {
		if (treeNode == parentNode)
			return YES;
		treeNode = [treeNode parentNode];
	}
	return NO;
}


- (BOOL)_dragIsLocalReorder:(id<NSDraggingInfo>)info {
    // It is a local drag if the following conditions are met:
    if ([info draggingSource] == sidebarView) {
        // We were the source
        if (_draggedNodes != nil) {
            // Our nodes were saved off
            if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kNTXReorderPasteboardType]] != nil) {
                // Our pasteboard marker is on the pasteboard
                return YES;
            }
        }
    }
    return NO;
}


- (NSDragOperation)outlineView:(NSOutlineView *)inView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)inItem proposedChildIndex:(NSInteger)childIndex {
	// To make it easier to see exactly what is called, uncomment the following line:
//	NSLog(@"outlineView:validateDrop:proposedItem:%@ proposedChildIndex:%ld", inItem, (long)childIndex);

	// This method validates whether or not the proposal is a valid one.
	// We start out by assuming that we will do a "generic" drag operation, which means we are accepting the drop. If we return NSDragOperationNone, then we are not accepting the drop.
	NSDragOperation result = NSDragOperationGeneric;

	// Check to see what we are proposed to be dropping on
	NSTreeNode *targetNode = inItem;
	// A target of "nil" means we are on the main root tree
	if (targetNode == nil)
		return NSDragOperationNone;

	NTXProjectItem * item = [targetNode representedObject];
	if (item.isContainer) {
		// We can always drop on a container
	} else {
		// We don’t allow dropping on a leaf. Refuse the drop: (we may get called again with a between)
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			result = NSDragOperationNone;
		}
	}

	// If we are allowing the drop, we see if we are draggng from ourselves and dropping into a descendent, which wouldn't be allowed...
	if (result != NSDragOperationNone) {
		// Indicate that we will animate the drop items to their final location
		info.animatesToDestination = YES;
		if ([self _dragIsLocalReorder:info]) {
			if (targetNode != nil) {
				for (NSTreeNode *draggedNode in _draggedNodes) {
					if ([self treeNode:targetNode isDescendantOfNode:draggedNode]) {
						// Yup, it is, refuse it.
						result = NSDragOperationNone;
						break;
					}
				}
			}
		}
	}

	// To see what we decide to return, uncomment this line
//	NSLog(result == NSDragOperationNone ? @" - Refusing drop" : @" + Accepting drop");

	return result;    
}


/* -----------------------------------------------------------------------------
	Insert dragged items.
----------------------------------------------------------------------------- */

- (void)_performInsertWithDragInfo:(id<NSDraggingInfo>)info parentNode:(NSTreeNode *)parentNode childIndex:(NSInteger)childIndex {
NSLog(@"-_performInsertWithDragInfo: %@", info.description);
	// NSOutlineView's root is nil
	NSMutableArray *childNodeArray = parentNode.mutableChildNodes;
	NSInteger outlineColumnIndex = [sidebarView.tableColumns indexOfObject:sidebarView.outlineTableColumn];

	// Enumerate all items dropped on us and create new model objects for them    
	NSArray *classes = [NSArray arrayWithObject:[NTXProjectItem class]];
	__block NSInteger insertionIndex = childIndex;
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
		NTXProjectItem *newNodeData = (NTXProjectItem *)draggingItem.item;
		int filetype = [self filetype:newNodeData.url];		// this won’t have been set
		if (filetype >= 0) {
			newNodeData.type = filetype;
			// Wrap the model object in a tree node
			NSTreeNode *treeNode = [NSTreeNode treeNodeWithRepresentedObject:newNodeData];
			// Add it to the model
			[childNodeArray insertObject:treeNode atIndex:insertionIndex];
			[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] inParent:parentNode withAnimation:NSTableViewAnimationEffectGap];
			// Update the final frame of the dragging item
			NSInteger row = [sidebarView rowForItem:treeNode];
			draggingItem.draggingFrame = [sidebarView frameOfCellAtColumn:outlineColumnIndex row:row];

			// Insert all children one after another
			++insertionIndex;
		}
	}];
}


- (void)_performDragReorderWithDragInfo:(id<NSDraggingInfo>)info parentNode:(NSTreeNode *)newParent childIndex:(NSInteger)childIndex {
	// We will use the dragged nodes we saved off earlier for the objects we are actually moving
	NSAssert(_draggedNodes != nil, @"_draggedNodes should be valid");

	NSMutableArray *childNodeArray = [newParent mutableChildNodes];

	// We want to enumerate all things in the pasteboard. To do that, we use a generic NSPasteboardItem class
	NSArray *classes = [NSArray arrayWithObject:[NSPasteboardItem class]];
	__block NSInteger insertionIndex = childIndex;
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
		// We ignore the draggingItem.item -- it is an NSPasteboardItem. We only care about the index. The index is deterministic, and can directly be used to look into the initial array of dragged items.
		NSTreeNode *draggedTreeNode = [_draggedNodes objectAtIndex:index];

		// Remove this node from its old location
		NSTreeNode *oldParent = draggedTreeNode.parentNode;
		NSMutableArray *oldParentChildren = oldParent.mutableChildNodes;
		NSInteger oldIndex = [oldParentChildren indexOfObject:draggedTreeNode];
		[oldParentChildren removeObjectAtIndex:oldIndex];
		// Tell the table it is going away; make it pop out with NSTableViewAnimationEffectNone, as we will animate the draggedItem to the final target location.
		// Don't forget that NSOutlineView uses 'nil' as the root parent.
		[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:oldIndex] inParent:oldParent withAnimation:NSTableViewAnimationEffectNone];

		// Insert this node into the new location and new parent
		if (oldParent == newParent) {
			// Moving it from within the same parent! Account for the remove, if it is past the oldIndex
			if (insertionIndex > oldIndex) {
				 --insertionIndex; // account for the remove
			}
		}
		[childNodeArray insertObject:draggedTreeNode atIndex:insertionIndex];

		// Tell NSOutlineView about the insertion; let it leave a gap for the drop animation to come into place
		[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] inParent:newParent withAnimation:NSTableViewAnimationEffectGap];

		++insertionIndex;
	}];

	// Now that the move is all done (according to the table), update the draggingFrames for the all the items we dragged. -frameOfCellAtColumn:row: gives us the final frame for that cell
	NSInteger outlineColumnIndex = [[sidebarView tableColumns] indexOfObject:[sidebarView outlineTableColumn]];
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
		NSTreeNode *draggedTreeNode = [_draggedNodes objectAtIndex:index];
		NSInteger row = [sidebarView rowForItem:draggedTreeNode];
		draggingItem.draggingFrame = [sidebarView frameOfCellAtColumn:outlineColumnIndex row:row];
	}];
}


- (BOOL) outlineView:(NSOutlineView *)inView acceptDrop:(id<NSDraggingInfo>)info item:(id)inItem childIndex:(NSInteger)childIndex {
	NSTreeNode *targetNode = inItem;
	// A target of "nil" means we are on the main root tree
	if (targetNode == nil)
		return NO;

	NTXProjectItem * item = targetNode.representedObject;

	// Determine the parent to insert into and the child index to insert at.
	if (!item.isContainer) {
		// If our target is a leaf, and we are dropping on it
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			// If we are dropping on a leaf, we will have to turn it into a container node
			item.isContainer = YES;
			childIndex = 0;
		} else {
			// We will be dropping on the item's parent at the target index of this child, plus one
			NSTreeNode *oldTargetNode = targetNode;
			targetNode = targetNode.parentNode;
			childIndex = [targetNode.childNodes indexOfObject:oldTargetNode] + 1;
		}
	} else {            
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			// Insert it at the start, if we were dropping on it
			childIndex = 0;
		}
	}

	// Group all insert or move animations together
	[sidebarView beginUpdates];
	// If the source was ourselves, we use our dragged nodes and do a reorder
	if ([self _dragIsLocalReorder:info]) {
		[self _performDragReorderWithDragInfo:info parentNode:targetNode childIndex:childIndex];
	} else {
		[self _performInsertWithDragInfo:info parentNode:targetNode childIndex:childIndex];
	}
	[sidebarView endUpdates];

	[self rebuildProjectItems];
	// Return YES to indicate we were successful with the drop. Otherwise, it would slide back the drag image.
	return YES;
}


/* Multi-item dragging destination support. */

- (void) outlineView:(NSOutlineView *)inView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
	// If the source is ourselves, then don't do anything. If it isn't, we update things
	if (![self _dragIsLocalReorder:draggingInfo]) {
		// We will be doing an insertion; update the dragging items to have an appropriate image
		NSArray *classes = [NSArray arrayWithObject:[NTXProjectItem class]];

		// Create a copied temporary cell to draw to images
		NSTableColumn *tableColumn = sidebarView.outlineTableColumn;
//		NSTableCellView *tempCell = [tableColumn.dataCell copy];

		// Calculate a base frame for new cells
		NSRect cellFrame = NSMakeRect(0, 0, tableColumn.width, inView.rowHeight);

		// Subtract out the intercellSpacing from the width only. The rowHeight is sans-spacing
		cellFrame.size.width -= inView.intercellSpacing.width;

		[draggingInfo enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
			NTXProjectItem *newNodeData = (NTXProjectItem *)draggingItem.item;
			// Wrap the model object in a tree node
			NSTreeNode *treeNode = [NSTreeNode treeNodeWithRepresentedObject:newNodeData];
			draggingItem.draggingFrame = cellFrame;
			
//			draggingItem.imageComponentsProvider = ^(void) {
//				 // Setup the cell with this temporary data
//				 id objectValue = [self outlineView:inView objectValueForTableColumn:tableColumn byItem:treeNode];
//				 [tempCell setObjectValue:objectValue];
//				 [self outlineView:inView willDisplayCell:tempCell forTableColumn:tableColumn item:treeNode];
//				 // Ask the table for the image components from that cell
//				 return (NSArray *)[tempCell draggingImageComponentsWithFrame:cellFrame inView:inView];
//			};            
		}];
	}
}


- (void)addLeaf:(id)sender {
	NTXProjectItem *childNodeData = [[NTXProjectItem alloc] init];
	[self addNewDataToSelection:childNodeData];
}


- (void)addNewDataToSelection:(NTXProjectItem *)newChildData {
	NSTreeNode *selectedNode;
	// We are inserting as a child of the last selected node. If there are none selected, insert it as a child of the treeData itself
	if ([sidebarView selectedRow] != -1) {
		selectedNode = [sidebarView itemAtRow:[sidebarView selectedRow]];
	} else {
		selectedNode = nil;	// will crash
	}

	// If the selected node is a container, use its parent. We access the underlying model object to find this out.
	// In addition, keep track of where we want the child.
	NSInteger childIndex;
	NSTreeNode *parentNode;

	NTXProjectItem * item = selectedNode.representedObject;
	if (item.isContainer) {
		// Since it was already a container, we insert it as the first child
		childIndex = 0;
		parentNode = selectedNode;
	} else {
		// The selected node is not a container, so we use its parent, and insert after the selected node
		parentNode = [selectedNode parentNode];
		childIndex = [[parentNode childNodes] indexOfObject:selectedNode ] + 1; // + 1 means to insert after it.
	}

	// update the tree directly in an animated fashion
	[sidebarView beginUpdates];
	// Now, create a tree node for the data and insert it as a child and tell the outlineview about our new insertion
	NSTreeNode *childTreeNode = [NSTreeNode treeNodeWithRepresentedObject:newChildData];
	[[parentNode mutableChildNodes] insertObject:childTreeNode atIndex:childIndex];
	// NSOutlineView uses 'nil' as the root parent
	[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parentNode withAnimation:NSTableViewAnimationEffectFade];
	[sidebarView endUpdates];
	[self rebuildProjectItems];

	NSInteger newRow = [sidebarView rowForItem:childTreeNode];
	if (newRow >= 0) {
		[sidebarView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		NSInteger column = 0;
		// With "full width" cells, there is no column
		if (newChildData.isContainer ) {
			column = -1;
		}
		[sidebarView editColumn:column row:newRow withEvent:nil select:YES];
	}
}

@end
