/*
	File:		ProjectWindowController.mm

	Abstract:	Implementation of NTXWindowController class.

	Written by:		Newton Research, 2014.

	TO DO:		sort soup columns based on underlying data, not string representation
					don’t allow Select All of outline view
*/

#import "ProjectWindowController.h"
#import "PreferenceKeys.h"
#import "ImageAndTextCell.h"
#import "ProjectItem.h"
#import "ProjectDocument.h"
#import "NTXDocument.h"
#import "NTXEditorView.h"
#import "DockEvent.h"
#import "DockErrors.h"

extern NSString *	MakeNSString(RefArg inStr);

#define kNTXReorderPasteboardType @"NTXSourceListItemPboardType"


#pragma mark NSSplitView (collapse)
/* -----------------------------------------------------------------------------
	N S S p l i t V i e w
	Category that toggles collapsed state of a split view using private method
	-[NSSplitView _setSubview:isCollapsed:]
----------------------------------------------------------------------------- */

@interface NSSplitView (collapse)
- (void)toggleSubview:(NSView *)inView;
@end

@implementation NSSplitView (collapse)
- (void)toggleSubview:(NSView *)inView
{
    SEL selector = @selector(_setSubview:isCollapsed:);
    NSMethodSignature *signature = [NSSplitView instanceMethodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self;
    invocation.selector = selector;
    [invocation setArgument:&inView atIndex:2];
    BOOL arg = ![self isSubviewCollapsed:inView];
    [invocation setArgument:&arg atIndex:3];
    [invocation invoke];
}
@end


#pragma mark NTXSplitView
/* -----------------------------------------------------------------------------
	N T X S p l i t V i e w
	The vertical split view containing the content and inspector text.
	We want the divider to be thick enough to display the TellUser() text.
----------------------------------------------------------------------------- */

@implementation NTXSplitView

- (CGFloat) dividerThickness
{
	return 20.0;
}

- (void) drawDividerInRect:(NSRect)inRect
{
	NSString * txt = ((NTXProjectWindowController *)self.window.windowController).tellUserText;
	if (txt && txt.length > 0)
	{
		NSRect box = NSInsetRect(inRect, 10.0, 0.0);
		box.origin.y += 13.0;
		[self lockFocus];
		[txt drawWithRect:box options:0 attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:11.0], NSFontAttributeName,
																														  [NSColor blackColor], NSForegroundColorAttributeName,
																														  nil]];
		[self unlockFocus];
	}
}

@end


#pragma mark NTXOutlineView
/* -----------------------------------------------------------------------------
	N T X O u t l i n e V i e w
	This is the source list view in the left-hand sidebar.
	We don’t ever want to select all source files.
----------------------------------------------------------------------------- */

@implementation NTXOutlineView

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem
{
	if ([inItem action] == @selector(selectAll:))
		return NO;
}

- (void) selectAll: (id) sender
{
	/* don’t do this */
}

@end


#pragma mark NTXProjectWindowController
/* -----------------------------------------------------------------------------
	N T X P r o j e c t W i n d o w C o n t r o l l e r
	The window controller displays:
		0 Layout file (also used for user-proto and print layout files)
		1 Bitmap file
		2 Metafile file (unused)
		3 Sound file
		4 Book file (deprecated in favor of script items)
		5 Script file (NewtonScript source file)
		6 Package file
		7 Stream file
		8 Native C++ code module file
	depending on the selection in the NSOutlineView.
	It acts as the data source and delegate for the NSOutlineView.
----------------------------------------------------------------------------- */
static void *ProgressObserverContext = &ProgressObserverContext;
static void *ProjectObserverContext = &ProjectObserverContext;

@implementation NTXProjectWindowController

/* -----------------------------------------------------------------------------
	Initialize.
----------------------------------------------------------------------------- */

- (id) initWithWindow: (NSWindow *) inWindow
{
	if (self = [super initWithWindow: inWindow])
	{
		sourceListRoot = nil;
		projectNode = nil;
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Don’t show .newtproj file extension in window title.
-----------------------------------------------------------------------------

- (NSString *) windowTitleForDocumentDisplayName: (NSString *) inDisplayName
{
	NTXProjectDocument * theDocument = self.document;
	NSString * title = [inDisplayName stringByDeletingPathExtension];
	if (title == nil)
		title = @"Newton Toolkit Project";
	return title;
}*/


/* -----------------------------------------------------------------------------
	Initialize after nib has been loaded.
----------------------------------------------------------------------------- */

- (void) windowDidLoad
{
	[super windowDidLoad];	// do we need this?
	// show toolbar items in title area
	self.window.titleVisibility = NSWindowTitleHidden;
	self.shouldCascadeWindows = NO;

	NTXProjectDocument * theDocument = self.document;
	NSURL * projectURL = [theDocument fileURL];
	if (projectURL)
		[self setWindowFrameAutosaveName:[projectURL lastPathComponent]];

	// observe changes to the document’s project items so we can update the source list
	[theDocument addObserver:self
				  forKeyPath:@"projectItems"
					  options:NSKeyValueObservingOptionInitial
					  context:ProjectObserverContext];

	// observe changes to the document’s progress so we can update the progress box
	[theDocument.progress addObserver:self
				  forKeyPath:@"localizedDescription"
					  options:NSKeyValueObservingOptionInitial
					  context:ProgressObserverContext];
	theDocument.progress.localizedDescription = @"Welcome to NewtonScript!";

	// set up text attributes
	NSFont * userTxFont = [NSFont fontWithName:@"Menlo" size:11.0];
	NSFont * newtonTxFont = [NSFont fontWithName:@"Menlo-Bold" size:11.0];
	// calculate tab width
	NSFont * charWidthFont = [userTxFont screenFontWithRenderingMode:NSFontDefaultRenderingMode];
	NSInteger tabWidth = 3;	// [[NSUserDefaults standardUserDefaults] integerForKey:TabWidth];
	CGFloat charWidth = [@" " sizeWithAttributes:[NSDictionary dictionaryWithObject:charWidthFont forKey:NSFontAttributeName]].width;
	if (charWidth == 0)
		charWidth = [charWidthFont maximumAdvancement].width;
	// use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle * txStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[txStyle setTabStops:[NSArray array]];
	[txStyle setDefaultTabInterval:(charWidth * tabWidth)];

	newtonTxAttrs = [NSDictionary dictionaryWithObjectsAndKeys:newtonTxFont, NSFontAttributeName,
																					[txStyle copy], NSParagraphStyleAttributeName,
																					nil];
	userTxAttrs = [NSDictionary dictionaryWithObjectsAndKeys:	userTxFont, NSFontAttributeName,
																					[txStyle copy], NSParagraphStyleAttributeName,
																					nil];

	[inspectorView setAutomaticQuoteSubstitutionEnabled:NO];
	[inspectorView setAllowsUndo:YES];

	// redirect stdout to us
	redirector = [NTXOutputRedirect redirect_stdout];
	[redirector setListener:self];

	// when the window closes, undo those hooks
	[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(windowWillClose:)
															  name:NSWindowWillCloseNotification
															object:[self window]];

	sourceListRoot = [[NSTreeNode alloc] initWithRepresentedObject: [[NTXProjectItem alloc] init]];
	NSMutableArray * sidebarItems = [sourceListRoot mutableChildNodes];

	// create root node to represent the project settings
	projectNode = [[NSTreeNode alloc] initWithRepresentedObject: [[NTXProjectSettingsItem alloc] initWithProject: theDocument]];
	[sidebarItems addObject: projectNode];

	[self buildSourceList];

	// restore the saved selection
	[sidebarView selectRowIndexes: [NSIndexSet indexSetWithIndex: theDocument.selectedItem] byExtendingSelection: NO];
	// enable it
	[sidebarView setEnabled: YES];

	// scroll to the top in case the outline contents is very long
	[[[sidebarView enclosingScrollView] verticalScroller] setFloatValue: 0.0];
	[[[sidebarView enclosingScrollView] contentView] scrollToPoint: NSMakePoint(0,0)];

	// register to get our custom type, strings, and filenames
	[sidebarView registerForDraggedTypes:[NSArray arrayWithObjects:kNTXReorderPasteboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
	[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
}


- (void) buildSourceList
{
	// add projectItems to the project root node
	NSMutableArray * sidebarItems = [projectNode mutableChildNodes];
	[sidebarItems removeAllObjects];
	for (NTXProjectItem * item in ((NTXProjectDocument *)self.document).projectItems)
	{
		NSTreeNode * itemNode = [[NSTreeNode alloc] initWithRepresentedObject: item];
		[sidebarItems addObject: itemNode];
	}

	// expand the project
	[sidebarView reloadData];
	[sidebarView expandItem: projectNode];
}


/* -----------------------------------------------------------------------------
	Update the progress box when changes to the document’s progress are observed.
----------------------------------------------------------------------------- */

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == ProgressObserverContext)
	{
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			NSProgress *progress = object;
//			progressBox.barValue = progress.fractionCompleted;
//			progressBox.statusText = progress.localizedDescription;
//			progressBox.needsDisplay = YES;
	  }];
	}
	else if (context == ProjectObserverContext)
	{
		[self buildSourceList];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


/* -----------------------------------------------------------------------------
	Save the currently selected project item.
	Args:		sender
	Return:	--
-----------------------------------------------------------------------------

- (IBAction) saveDocument: (id) sender
{
NSLog(@"-[NTXProjectWindowController saveDocument:]");
	if (currentSelection)
	{
		// tell source item to save itself
		[currentSelection saveDocument];
	}
}*/


/* -----------------------------------------------------------------------------
	Remove dependents when the window is about to close.
----------------------------------------------------------------------------- */

- (void) windowWillClose: (NSNotification *) inNotification
{
	// restore stdout
	[redirector setListener:nil];

	// stop listening for notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[((NTXProjectDocument *)self.document).progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(localizedDescription)) context:ProgressObserverContext];
}


/* -----------------------------------------------------------------------------
	Insert text into the inspector text view.
----------------------------------------------------------------------------- */

- (void) insertText: (NSString *) inText
{
	if (inText)
	{
		NSAttributedString * str = [[NSAttributedString alloc] initWithString: inText attributes: newtonTxAttrs];
		[[inspectorView textStorage] insertAttributedString: str atIndex: [inspectorView selectedRange].location];
	}
}


/* -----------------------------------------------------------------------------
	ALWAYS use our text attributes.
----------------------------------------------------------------------------- */

- (void) textViewDidChangeSelection:(NSNotification *) inNotification
{
	[[inNotification object] setTypingAttributes: userTxAttrs];
}


/* -----------------------------------------------------------------------------
	Respond to TellUser() from NewtonScript.
----------------------------------------------------------------------------- */

- (void) tellUser: (NSString *) inStr
{
	self.tellUserText = inStr;
	contentSplitView.needsDisplay = YES;
}


/* -----------------------------------------------------------------------------
	Load text into the inspector.
----------------------------------------------------------------------------- */

- (void) loadText: (NSURL *) inURL
{
	[inspectorView setTextContainerInset:NSMakeSize(4.0, 4.0)];

	NSError * __autoreleasing err;
	NSString * txStr = [NSString stringWithContentsOfURL:inURL encoding:NSUTF8StringEncoding error: &err];
	if (txStr == nil)
		txStr = [NSString stringWithUTF8String:""];
	NSAttributedString * attrStr = [[NSAttributedString alloc] initWithString:txStr attributes:userTxAttrs];
	[[inspectorView textStorage] setAttributedString:attrStr];
}


/* -----------------------------------------------------------------------------
	Save inspector text.
----------------------------------------------------------------------------- */

- (void) saveText: (NSURL *) inURL
{
	NSError * __autoreleasing err = nil;
	[[[inspectorView textStorage] string] writeToURL:inURL atomically:NO encoding:NSUTF8StringEncoding error:&err];
}


#if 0
/* -----------------------------------------------------------------------------
	Enable main menu item for above.
	Also for the Edit menu Delete item, which the current view controller might
	use.
	Args:		inItem
	Return:	YES => enable
----------------------------------------------------------------------------- */

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>) inItem
{
// Edit menu
	if ([inItem action] == @selector(delete:))
	{
		libraryStoreNodeToDelete = nil;
		// can delete old stores
		if ([[self window] firstResponder] == sidebarView)
		{
			NSInteger rowIndex;
			if ((rowIndex = [sidebarView selectedRow]) >= 0
			&&  [[sidebarView itemAtRow: rowIndex] parentNode] == libraryNode)
			{
				libraryStoreNodeToDelete = [sidebarView itemAtRow: rowIndex];
				return YES;
			}
		}
		// can delete soup entries
		else if ([currentViewController respondsToSelector:@selector(validateUserInterfaceItem:)])
			return [(NCInfoController<NCUIValidation> *)currentViewController validateUserInterfaceItem:inItem];
	}

// Window menu
	// we can always open the inspector panel, even if there’s nothing to inspect
	else if ([inItem action] == @selector(showInspectorPanel:))
		return YES;

	return NO;
}

- (IBAction) delete: (id) sender
{
	// if we are deleting a library store we probably need to maintain that state
	if (libraryStoreNodeToDelete)
	{
		NCStore * storeObj = libraryStoreNodeToDelete.representedObject;
		NSAlert * alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle: NSLocalizedString(@"delete", nil)];
		[alert addButtonWithTitle: NSLocalizedString(@"cancel", nil)];
		[alert setMessageText: [NSString stringWithFormat:@"Deleting the %@ store from your library will permanently remove all the information and packages it contains from Newton Connection.", storeObj.name]];
		[alert setInformativeText:@"Your Newton device will not be affected."];
		[alert setShowsSuppressionButton:YES];
		[alert setAlertStyle: NSWarningAlertStyle];

		NSInteger result = [alert runModal];
		[alert release];
		if (result == NSAlertFirstButtonReturn)
		{
			NCDocument * theDocument = self.document;
			// perform deletion from core data via document
			[[theDocument deviceObj] removeStoresObject: storeObj];
			// and remove node from the source view
			NSMutableArray * sidebarItems = [libraryNode mutableChildNodes];
			[sidebarItems removeObject: libraryStoreNodeToDelete];
			if (sidebarItems.count == 0)
			{
				[[sidebarRoot mutableChildNodes] removeObject: libraryNode];
				libraryNode = nil;
			}
			[sidebarView reloadData];
		}
	}

	else if ([currentViewController respondsToSelector:@selector(performDeleteAction)])
		[(NCInfoController<NCUIValidation> *)currentViewController performDeleteAction];
}

#endif

#pragma mark Split views

/* -----------------------------------------------------------------------------
	Show/hide the navigator sidebar or debug area.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) toggleSplit: (id) sender
{
	NSInteger item = ((NSSegmentedControl *)sender).selectedSegment;
	if (item == 0)
		[navSplitView toggleSubview:navigatorView];
	else
		[contentSplitView toggleSubview:debugView];
}


- (IBAction) toggleDebug: (id) sender
{
/*
	[contentView layoutIfNeeded];
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *inContext) {
		[inContext setAllowsImplicitAnimation: YES];
		// Make all constraint changes here
		[contentView layoutIfNeeded];
	}];
*/
}


#pragma mark - NSSplitViewDelegate methods
/* -----------------------------------------------------------------------------
	Support for collapsing split views
----------------------------------------------------------------------------- */
#define kMinConstrainValue 100.0f

- (BOOL) splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    BOOL canCollapseSubview = NO;
	
    NSArray *splitViewSubviews = [splitView subviews];
    NSUInteger splitViewSubviewCount = [splitViewSubviews count];
    if (subview == [splitViewSubviews objectAtIndex:0] || subview == [splitViewSubviews objectAtIndex:(splitViewSubviewCount - 1)])
	{
		canCollapseSubview = YES;
    }
	return canCollapseSubview;
}


- (BOOL) splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
    // yes, if you can collapse you should collapse it
    return YES;
}


- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(NSInteger)index
{
    CGFloat constrainedCoordinate = proposedCoordinate;
    if (index == 0)
    {
		constrainedCoordinate = proposedCoordinate + kMinConstrainValue;
    }
    return constrainedCoordinate;
}


- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(NSInteger)index
{
    CGFloat constrainedCoordinate = proposedCoordinate;
    if (index == 1)
	{
		constrainedCoordinate = proposedCoordinate - kMinConstrainValue;
    }
	
    return constrainedCoordinate;	
}


#pragma mark - File menu actions
/* -----------------------------------------------------------------------------
	Create a new layout document.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) newLayoutDocument: (id) sender
{
	;
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
	NSSavePanel * dlg = [NSSavePanel savePanel];
	dlg.title = @"New NewtonScript File";
	dlg.allowedFileTypes = [NSArray arrayWithObject:NTXScriptFileType];
	[dlg runModal];
	// create the file
	NSError * __autoreleasing err = nil;
	[[NSData data] writeToURL:dlg.URL options:0 error:&err];
	// add to projectItems
	[self.document addFiles:[NSArray arrayWithObject:dlg.URL] afterIndex:sidebarView.selectedRow];
}


/* -----------------------------------------------------------------------------
	Add documents to the project.
		present Open dialog, multiple selection
		will only allow document types we know about!
		add them to projectItems frame after current selection (if any) else at end
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
	[self.document addFiles:dlg.URLs afterIndex:sidebarView.selectedRow];
}


#pragma mark - Build menu actions
/* -----------------------------------------------------------------------------
	Build the current project.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) buildPackage: (id) sender
{
	[self.document build];
}


/* -----------------------------------------------------------------------------
	Build the current project and download it to Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) downloadPackage: (id) sender
{
	NSURL * pkg = [self.document build];
//	if (pkg)
//		[[NSApp delegate] download: pkg];
}


/* -----------------------------------------------------------------------------
	Export the current project to text.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction) exportPackage: (id) sender
{
	NSError * __autoreleasing err = nil;
	[self.document writeToURL:[self.document fileURL] ofType:@"public.plain-text" error:&err];
}


#pragma mark Item View
/* -----------------------------------------------------------------------------
	Change the information subview.
----------------------------------------------------------------------------- */

- (void) changeItemView
{
	// if more than one item selected, ignore this
	if ([sidebarView numberOfSelectedRows] != 1)
		return;

// also ignore this if selected item has no viewController, eg is group

	((NTXProjectDocument *)self.document).selectedItem = [sidebarView selectedRow];

	// remove any previous item view
	[self removeItemView];

	NSTreeNode * theNode = [sidebarView itemAtRow: [sidebarView selectedRow]];
	currentSelection = [theNode representedObject];

	// currentSelection is an NTXProjectItem
	// access view controller via currentSelection.document.viewController
	// which instantiates document > controller if necessary

	NTXEditViewController * viewController;
	if ((viewController = currentSelection.document.viewController))
	{
		NSView * itemView = [viewController containerView];
		// tell viewController we’re going to show
		[viewController willShow];

		// make sure our added subview is placed and resizes correctly
		if (itemView)
		{
			NSDictionary *views = NSDictionaryOfVariableBindings(itemView);
			[itemView setTranslatesAutoresizingMaskIntoConstraints:NO];
			[placeholderView addSubview:itemView];
			[placeholderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[itemView]|" options:0 metrics:nil views:views]];
			[placeholderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[itemView]-0-|" options:0 metrics:nil views:views]];
		}
	}
}


/* -----------------------------------------------------------------------------
	Remove the information subview.
----------------------------------------------------------------------------- */

- (void) removeItemView
{
	if (currentSelection)
	{
		NTXEditViewController * viewController = currentSelection.document.viewController;
		// tell viewController we’re going away
		[viewController willHide];
		[[viewController containerView] removeFromSuperview];
		currentSelection = nil;
	}
}


#pragma mark - NSOutlineView item insertion/deletion
/* -----------------------------------------------------------------------------
	Handle menu items.
----------------------------------------------------------------------------- */

- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
	if ([menuItem action] == @selector(delete:))
	{
		// The delete selection item should be disabled if nothing is selected.
		return [[sidebarView selectedRowIndexes] count] > 0;
	}
	return YES;
}


- (IBAction) delete: (id) sender
{
	[sidebarView beginUpdates];
	[[sidebarView selectedRowIndexes] enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger row, BOOL *stop)
	{
		NSTreeNode *node = [sidebarView itemAtRow:row];
		// remove item from document
		;
		// more complicated than we need right now, but allows for items to be grouped in future
		NSTreeNode *parent = [node parentNode];
		NSMutableArray *childNodes = [parent mutableChildNodes];
		NSInteger index = [childNodes indexOfObject:node];
		[childNodes removeObjectAtIndex:index];
		if (parent == sourceListRoot)
		{
			parent = nil; // NSOutlineView doesn't know about our root node, so we use nil
		}
		[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:parent withAnimation:NSTableViewAnimationEffectFade | NSTableViewAnimationSlideLeft];
	}];
	[sidebarView endUpdates];
}


#pragma mark - NSOutlineViewDelegate protocol
/* -----------------------------------------------------------------------------
	Determine whether an item is a group title.
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView isGroupItem: (id) inItem
{
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

- (BOOL) outlineView: (NSOutlineView *) inView shouldShowOutlineCellForItem: (id) inItem;
{
	id item = [inItem representedObject];
	return [item isKindOfClass: [NTXProjectSettingsItem class]];
}

//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item;

/* -----------------------------------------------------------------------------
	We can select everything.
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView shouldSelectItem: (id) inItem
{
	return YES;
}

/* -----------------------------------------------------------------------------
	We use the ImageAndTextCell class to display a 16x16 image against some items.
----------------------------------------------------------------------------- */

- (void) outlineView: (NSOutlineView *) inView willDisplayCell: (NSCell *) inCell forTableColumn: (NSTableColumn *) inColumn item: (id) inItem
{
	NTXProjectItem * item = [inItem representedObject];
	ImageAndTextCell * imageAndTextCell = (ImageAndTextCell *) inCell;
	[imageAndTextCell setImage: item.image];
}

/* -----------------------------------------------------------------------------
	If file does not exist at URL, make text red.
----------------------------------------------------------------------------- */

- (NSCell *) outlineView: (NSOutlineView *) inView dataCellForTableColumn: (NSTableColumn *) inColumn item: (id) inItem
{
	NTXProjectItem * item = [inItem representedObject];
	NSTextFieldCell * cell = [inColumn dataCell];

	NSFileManager * fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[[item url] path]])
		[cell setTextColor: [NSColor blackColor]];
	else
		[cell setTextColor: [NSColor redColor]];
	return cell;
}


/* -----------------------------------------------------------------------------
	The selection changed -- update the placeholder view accordingly.
	Need to do this rather than outlineViewAction b/c we can also change
	the selection programmatically.
----------------------------------------------------------------------------- */

- (void) outlineViewSelectionDidChange: (NSNotification *) inNotification
{
	[self changeItemView];
}


#pragma mark - NSOutlineViewDataSource protocol

- (NSArray *) childrenForItem: (id) inItem
{
	return inItem ? [inItem childNodes] : [sourceListRoot childNodes];
}


/* -----------------------------------------------------------------------------
	Return the number of children a particular item has.
	Because we are using a standard tree of NSDictionary, we can just return
	the count.
----------------------------------------------------------------------------- */

- (NSInteger) outlineView: (NSOutlineView *) inView numberOfChildrenOfItem: (id) inItem
{
	NSArray * children = [self childrenForItem: inItem];
	return [children count];
}


/* -----------------------------------------------------------------------------
	NSOutlineView will iterate over every child of every item, recursively asking
	for the entry at each index. Return the item at a given index.
----------------------------------------------------------------------------- */

- (id) outlineView: (NSOutlineView *) inView child: (int) index ofItem: (id) inItem
{
    NSArray * children = [self childrenForItem: inItem];
    // This will return an NSTreeNode with our model object as the representedObject
    return [children objectAtIndex: index];
}


/* -----------------------------------------------------------------------------
	Determine whether an item can be expanded.
	In our case, if an item has children then it is expandable.    
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView isItemExpandable: (id) inItem
{
	return ![inItem isLeaf];
}


/* -----------------------------------------------------------------------------
	NSOutlineView calls this for each column in your NSOutlineView, for each item.
	Return what you want displayed in each column.
----------------------------------------------------------------------------- */

- (id) outlineView: (NSOutlineView *) inView objectValueForTableColumn: (NSTableColumn *) inColumn byItem: (id) inItem
{
	NTXProjectItem * item = [inItem representedObject];
	return item.name;
}


/* -----------------------------------------------------------------------------
	Optional method: needed to allow editing.
----------------------------------------------------------------------------- */

- (void) outlineView: (NSOutlineView *) inView setObjectValue: (id) inObject forTableColumn: (NSTableColumn *) inColumn byItem: (id) inItem
{
	NTXProjectItem * item = [inItem representedObject];
	item.name = inObject;	// property setter will rename URL on disk
}


/* -----------------------------------------------------------------------------
	Drag reordering.
	In 10.7 multiple drag images are supported by using this delegate method.
----------------------------------------------------------------------------- */

- (id <NSPasteboardWriting>) outlineView: (NSOutlineView *) inView pasteboardWriterForItem: (id) inItem
{
	return (id <NSPasteboardWriting>) [inItem representedObject];
}


/* -----------------------------------------------------------------------------
	Setup a local reorder.
----------------------------------------------------------------------------- */

- (void)outlineView: (NSOutlineView *) inView draggingSession: (NSDraggingSession *) inSession willBeginAtPoint: (NSPoint) inPoint forItems: (NSArray *) inDraggedItems
{
	_draggedNodes = inDraggedItems;
	[inSession.draggingPasteboard setData:[NSData data] forType:kNTXReorderPasteboardType];
}


/* -----------------------------------------------------------------------------
	If the session ended in the trash then delete all the items.
----------------------------------------------------------------------------- */

- (void) outlineView: (NSOutlineView *) inView draggingSession: (NSDraggingSession *) session endedAtPoint: (NSPoint) screenPoint operation: (NSDragOperation) operation
{
	if (operation == NSDragOperationDelete)
	{
		[sidebarView beginUpdates];

		[_draggedNodes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id node, NSUInteger index, BOOL *stop)
		{
			// remove item from document
			id parent = [node parentNode];
			NSMutableArray *children = [parent mutableChildNodes];
			NSInteger childIndex = [children indexOfObject:node];
			[children removeObjectAtIndex:childIndex];
			[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parent == sourceListRoot ? nil : parent withAnimation:NSTableViewAnimationEffectFade];
		}];

		[sidebarView endUpdates];
	}

	_draggedNodes = nil;
}



- (BOOL) treeNode: (NSTreeNode *) treeNode isDescendantOfNode: (NSTreeNode *) parentNode
{
	while (treeNode != nil)
	{
		if (treeNode == parentNode)
			return YES;
		treeNode = [treeNode parentNode];
	}
	return NO;
}


- (BOOL) _dragIsLocalReorder: (id <NSDraggingInfo>) info
{
    // It is a local drag if the following conditions are met:
    if ([info draggingSource] == sidebarView)
	 {
        // We were the source
        if (_draggedNodes != nil)
		  {
            // Our nodes were saved off
            if ([[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kNTXReorderPasteboardType]] != nil) {
                // Our pasteboard marker is on the pasteboard
                return YES;
            }
        }
    }
    return NO;
}


- (NSDragOperation)outlineView: (NSOutlineView *) inView validateDrop: (id <NSDraggingInfo>) info proposedItem: (id) inItem proposedChildIndex: (NSInteger) childIndex
{
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
	if (item.isContainer)
	{
		// We can always drop on a container
	}
	else
	{
		// We don’t allow dropping on a leaf. Refuse the drop: (we may get called again with a between)
		if (childIndex == NSOutlineViewDropOnItemIndex)
		{
			result = NSDragOperationNone;
		}
	}

	// If we are allowing the drop, we see if we are draggng from ourselves and dropping into a descendent, which wouldn't be allowed...
	if (result != NSDragOperationNone)
	{
		// Indicate that we will animate the drop items to their final location
		info.animatesToDestination = YES;
		if ([self _dragIsLocalReorder:info])
		{
			if (targetNode != sourceListRoot)
			{
				for (NSTreeNode *draggedNode in _draggedNodes)
				{
					if ([self treeNode:targetNode isDescendantOfNode:draggedNode])
					{
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


- (void) _performInsertWithDragInfo: (id <NSDraggingInfo>) info parentNode: (NSTreeNode *) parentNode childIndex: (NSInteger)childIndex
{
	// NSOutlineView's root is nil
	id outlineParentItem = parentNode == sourceListRoot ? nil : parentNode;
	NSMutableArray *childNodeArray = [parentNode mutableChildNodes];
	NSInteger outlineColumnIndex = [[sidebarView tableColumns] indexOfObject:[sidebarView outlineTableColumn]];

	// Enumerate all items dropped on us and create new model objects for them    
	NSArray *classes = [NSArray arrayWithObject:[NTXProjectItem class]];
	__block NSInteger insertionIndex = childIndex;
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop)
		{
			NTXProjectItem *newNodeData = (NTXProjectItem *)draggingItem.item;
			// Wrap the model object in a tree node
			NSTreeNode *treeNode = [NSTreeNode treeNodeWithRepresentedObject:newNodeData];
			// Add it to the model
			[childNodeArray insertObject:treeNode atIndex:insertionIndex];
			[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] inParent:outlineParentItem withAnimation:NSTableViewAnimationEffectGap];
			// Update the final frame of the dragging item
			NSInteger row = [sidebarView rowForItem:treeNode];
			draggingItem.draggingFrame = [sidebarView frameOfCellAtColumn:outlineColumnIndex row:row];

			// Insert all children one after another
			insertionIndex++;
		}];
}


- (void) _performDragReorderWithDragInfo: (id <NSDraggingInfo>) info parentNode: (NSTreeNode *) newParent childIndex: (NSInteger) childIndex
{
	// We will use the dragged nodes we saved off earlier for the objects we are actually moving
	NSAssert(_draggedNodes != nil, @"_draggedNodes should be valid");

	NSMutableArray *childNodeArray = [newParent mutableChildNodes];

	// We want to enumerate all things in the pasteboard. To do that, we use a generic NSPasteboardItem class
	NSArray *classes = [NSArray arrayWithObject:[NSPasteboardItem class]];
	__block NSInteger insertionIndex = childIndex;
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop)
		{
			// We ignore the draggingItem.item -- it is an NSPasteboardItem. We only care about the index. The index is deterministic, and can directly be used to look into the initial array of dragged items.
			NSTreeNode *draggedTreeNode = [_draggedNodes objectAtIndex:index];

			// Remove this node from its old location
			NSTreeNode *oldParent = [draggedTreeNode parentNode];
			NSMutableArray *oldParentChildren = [oldParent mutableChildNodes];
			NSInteger oldIndex = [oldParentChildren indexOfObject:draggedTreeNode];
			[oldParentChildren removeObjectAtIndex:oldIndex];
			// Tell the table it is going away; make it pop out with NSTableViewAnimationEffectNone, as we will animate the draggedItem to the final target location.
			// Don't forget that NSOutlineView uses 'nil' as the root parent.
			[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:oldIndex] inParent:oldParent == sourceListRoot ? nil : oldParent withAnimation:NSTableViewAnimationEffectNone];

			// Insert this node into the new location and new parent
			if (oldParent == newParent) {
				// Moving it from within the same parent! Account for the remove, if it is past the oldIndex
				if (insertionIndex > oldIndex) {
					 insertionIndex--; // account for the remove
				}
			}
			[childNodeArray insertObject:draggedTreeNode atIndex:insertionIndex];

			// Tell NSOutlineView about the insertion; let it leave a gap for the drop animation to come into place
			[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] inParent:newParent == sourceListRoot ? nil : newParent withAnimation:NSTableViewAnimationEffectGap];

			insertionIndex++;
		}];

	// Now that the move is all done (according to the table), update the draggingFrames for the all the items we dragged. -frameOfCellAtColumn:row: gives us the final frame for that cell
	NSInteger outlineColumnIndex = [[sidebarView tableColumns] indexOfObject:[sidebarView outlineTableColumn]];
	[info enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop)
		{
			NSTreeNode *draggedTreeNode = [_draggedNodes objectAtIndex:index];
			NSInteger row = [sidebarView rowForItem:draggedTreeNode];
			draggingItem.draggingFrame = [sidebarView frameOfCellAtColumn:outlineColumnIndex row:row];
		}];
}


- (BOOL) outlineView: (NSOutlineView *) inView acceptDrop: (id <NSDraggingInfo>) info item: (id) inItem childIndex: (NSInteger) childIndex
{
	NSTreeNode *targetNode = inItem;
	// A target of "nil" means we are on the main root tree
	if (targetNode == nil)
	  return NO;

	NTXProjectItem * item = [targetNode representedObject];

	// Determine the parent to insert into and the child index to insert at.
	if (!item.isContainer)
	{
	  // If our target is a leaf, and we are dropping on it
	  if (childIndex == NSOutlineViewDropOnItemIndex)
	  {
			// If we are dropping on a leaf, we will have to turn it into a container node
			item.isContainer = YES;
			childIndex = 0;
	  } else {
			// We will be dropping on the item's parent at the target index of this child, plus one
			NSTreeNode *oldTargetNode = targetNode;
			targetNode = [targetNode parentNode];
			childIndex = [[targetNode childNodes] indexOfObject:oldTargetNode] + 1;
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

	// Return YES to indicate we were successful with the drop. Otherwise, it would slide back the drag image.
	return YES;
}


/* Multi-item dragging destination support. */

- (void) outlineView: (NSOutlineView *) inView updateDraggingItemsForDrag: (id <NSDraggingInfo>) draggingInfo
{
	// If the source is ourselves, then don't do anything. If it isn't, we update things
	if (![self _dragIsLocalReorder:draggingInfo])
	{
		// We will be doing an insertion; update the dragging items to have an appropriate image
		NSArray *classes = [NSArray arrayWithObject:[NTXProjectItem class]];

		// Create a copied temporary cell to draw to images
		NSTableColumn *tableColumn = [sidebarView outlineTableColumn];
		ImageAndTextCell *tempCell = [[tableColumn dataCell] copy];

		// Calculate a base frame for new cells
		NSRect cellFrame = NSMakeRect(0, 0, [tableColumn width], [inView rowHeight]);

		// Subtract out the intercellSpacing from the width only. The rowHeight is sans-spacing
		cellFrame.size.width -= [inView intercellSpacing].width;

		[draggingInfo enumerateDraggingItemsWithOptions:0 forView:sidebarView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop)
			{
				NTXProjectItem *newNodeData = (NTXProjectItem *)draggingItem.item;
				// Wrap the model object in a tree node
				NSTreeNode *treeNode = [NSTreeNode treeNodeWithRepresentedObject:newNodeData];
				draggingItem.draggingFrame = cellFrame;
				
				draggingItem.imageComponentsProvider = ^(void)
					{
						 // Setup the cell with this temporary data
						 id objectValue = [self outlineView:inView objectValueForTableColumn:tableColumn byItem:treeNode];
						 [tempCell setObjectValue:objectValue];
						 [self outlineView:inView willDisplayCell:tempCell forTableColumn:tableColumn item:treeNode];
						 // Ask the table for the image components from that cell
						 return (NSArray *)[tempCell draggingImageComponentsWithFrame:cellFrame inView:inView];
					};            
			}];
	}
}


- (void) addLeaf: (id) sender
{
	NTXProjectItem *childNodeData = [[NTXProjectItem alloc] init];
	[self addNewDataToSelection:childNodeData];
}


- (void) addNewDataToSelection: (NTXProjectItem *) newChildData
{
	NSTreeNode *selectedNode;
	// We are inserting as a child of the last selected node. If there are none selected, insert it as a child of the treeData itself
	if ([sidebarView selectedRow] != -1)
	  selectedNode = [sidebarView itemAtRow:[sidebarView selectedRow]];
	else
	  selectedNode = sourceListRoot;

	// If the selected node is a container, use its parent. We access the underlying model object to find this out.
	// In addition, keep track of where we want the child.
	NSInteger childIndex;
	NSTreeNode *parentNode;

	NTXProjectItem * item = [selectedNode representedObject];
	if (item.isContainer) {
	  // Since it was already a container, we insert it as the first child
	  childIndex = 0;
	  parentNode = selectedNode;
	} else {
	  // The selected node is not a container, so we use its parent, and insert after the selected node
	  parentNode = [selectedNode parentNode]; 
	  childIndex = [[parentNode childNodes] indexOfObject:selectedNode ] + 1; // + 1 means to insert after it.
	}

	// Use the new 10.7 API to update the tree directly in an animated fashion
	[sidebarView beginUpdates];

	// Now, create a tree node for the data and insert it as a child and tell the outlineview about our new insertion
	NSTreeNode *childTreeNode = [NSTreeNode treeNodeWithRepresentedObject:newChildData];
	[[parentNode mutableChildNodes] insertObject:childTreeNode atIndex:childIndex];
	// NSOutlineView uses 'nil' as the root parent
	if (parentNode == sourceListRoot) {
	  parentNode = nil;
	}
	[sidebarView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parentNode withAnimation:NSTableViewAnimationEffectFade];

	[sidebarView endUpdates];

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
