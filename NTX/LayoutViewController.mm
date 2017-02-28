/*
	File:		LayoutViewController.mm

	Abstract:	Implementation of NTXLayoutViewController subclasses.

	Written by:		Newton Research, 2016.
*/

#import "NTXDocument.h"
#import "LayoutViewController.h"
#import "Utilities.h"

#define NTXShowViewTemplateNotification @"EditViewTemplate"

/* -----------------------------------------------------------------------------
	N T X T e m p l a t e D e s c r i p t o r
----------------------------------------------------------------------------- */

@implementation NTXTemplateDescriptor

-(id)init:(RefArg)descriptor {
	if (self = [super init]) {
		viewTemplateDescriptor = descriptor;
	}
	return self;
}

-(Ref) value {
	return GetFrameSlot(viewTemplateDescriptor, SYMA(value));
}

-(NSString *) title {
	RefVar proto(GetFrameSlot(viewTemplateDescriptor, MakeSymbol("__ntId")));
	RefVar name(GetFrameSlot(viewTemplateDescriptor, MakeSymbol("__ntName")));
	return [NSString stringWithFormat:@"%s : %@", SymbolName(proto), MakeNSString(name)];
}

-(bool) hasChildren {
	return FrameHasSlot(self.value, SYMA(stepChildren));
}

@end


/* -----------------------------------------------------------------------------
	N T X L a y o u t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the view template list view.
----------------------------------------------------------------------------- */
@implementation NTXLayoutViewController
- (void)toggleCollapsed {
}
@end


/* -----------------------------------------------------------------------------
	N T X T e m p l a t e L i s t V i e w C o n t r o l l e r
	A hierarchical list of view templates.

	SlotDescriptor := {value: "Example",
							 __ntDataType: "TEXT",
							 __ntFlags: 0,
							 __ntEffect: 0}

	ViewTemplateDescriptor := {value: {<tag>:<SlotDescriptor>,...},	tag=stepChildren => slot descriptor value is array of ViewTemplateDescriptors
									   __ntId: 'protoApp,
									   __ntName: "MainView",
										__ntDeclare: nil,
										__ntExternalFile: nil}
----------------------------------------------------------------------------- */

@implementation NTXTemplateListViewController

- (void)viewWillAppear {
	[super viewWillAppear];

	if (ISNIL(templateHierarchy)) {
		NTXLayoutDocument * document = (NTXLayoutDocument *)self.parentViewController.representedObject;
		templateHierarchy = GetFrameSlot(document.layoutRef, MakeSymbol("templateHierarchy"));
		self.representedObject = [[NTXTemplateDescriptor alloc] init:templateHierarchy];

		// expand the project
		[sidebarView reloadData];
		[sidebarView expandItem:nil expandChildren:YES];

		// enable it
		sidebarView.enabled = YES;

		// scroll to the top in case the outline contents is very long
		[sidebarView.enclosingScrollView.verticalScroller setFloatValue:0.0];
		[sidebarView.enclosingScrollView.contentView scrollToPoint:NSMakePoint(0,0)];

		// register to get our custom type, strings, and filenames
		[sidebarView registerForDraggedTypes:[NSArray arrayWithObjects:/*kNTXReorderPasteboardType,*/ NSStringPboardType, NSFilenamesPboardType, nil]];
		[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
		[sidebarView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	}
}


#pragma mark - NSOutlineView item insertion/deletion
/* -----------------------------------------------------------------------------
	Handle menu items.
----------------------------------------------------------------------------- */

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if (menuItem.action == @selector(selectAll:)) {
		// don’t select all view templates
		return NO;
	}
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
		NSTreeNode *parent = node.parentNode;
		NSMutableArray * childNodes = parent.mutableChildNodes;
		NSInteger index = [childNodes indexOfObject:node];
		[childNodes removeObjectAtIndex:index];
//		if (parent == sourceListRoot) parent = nil; // NSOutlineView doesn't know about our root node, so we use nil
		[sidebarView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:parent withAnimation:NSTableViewAnimationEffectFade | NSTableViewAnimationSlideLeft];
	}];
	[sidebarView endUpdates];
//	[self rebuildProjectItems];
}


#pragma mark - NSOutlineViewDelegate protocol
/* -----------------------------------------------------------------------------
	Determine whether an item is a group title.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView isGroupItem:(id)inItem {
	return NO;	// we don’t have any group items in the view template list
}

/* -----------------------------------------------------------------------------
	Show the disclosure triangle for the project.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView shouldShowOutlineCellForItem:(id)inItem {
	NTXTemplateDescriptor * item = inItem;
	return item.hasChildren;
}

//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item;

/* -----------------------------------------------------------------------------
	We can select anything.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView shouldSelectItem:(id)inItem {
	return YES;
}


#pragma mark - NSOutlineViewDataSource protocol
/* -----------------------------------------------------------------------------
	Each item in the templateHierarchy is a ViewTemplateDescriptor.
----------------------------------------------------------------------------- */

- (Ref)childrenForItem:(id)item {
	if (NOTNIL(templateHierarchy)) {
		if (item == nil) {
			return templateHierarchy;
		}

		NTXTemplateDescriptor * descriptor = (NTXTemplateDescriptor *)item;
		if (FrameHasSlot(descriptor.value, SYMA(stepChildren))) {
			RefVar stepChildren(GetFrameSlot(descriptor.value, SYMA(stepChildren)));
			return GetFrameSlot(stepChildren, SYMA(value));
		}
	}
	return NILREF;
}


/* -----------------------------------------------------------------------------
	Return the number of children a particular item has.
	Because we are using a standard tree of NSDictionary, we can just return
	the count.
----------------------------------------------------------------------------- */

- (NSInteger)outlineView:(NSOutlineView *)inView numberOfChildrenOfItem:(id)inItem {
	RefVar viewTemplates = [self childrenForItem:inItem];
	if (IsArray(viewTemplates)) {
		return Length(viewTemplates);
	}
	return 1;
}


/* -----------------------------------------------------------------------------
	NSOutlineView will iterate over every child of every item, recursively asking
	for the entry at each index. Return the item at a given index.
----------------------------------------------------------------------------- */

- (id)outlineView:(NSOutlineView *)inView child:(int)index ofItem:(id)inItem {
	RefVar viewTemplates = [self childrenForItem:inItem];
	if (IsArray(viewTemplates)) {
		return [[NTXTemplateDescriptor alloc] init:GetArraySlot(viewTemplates, index)];
	}
	return [[NTXTemplateDescriptor alloc] init:viewTemplates];
}


/* -----------------------------------------------------------------------------
	Determine whether an item can be expanded.
	In our case, if an item has children then it is expandable.    
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView isItemExpandable:(id)inItem {
	return ((NTXTemplateDescriptor *)inItem).hasChildren;
}


/* -----------------------------------------------------------------------------
	NSOutlineView calls this for each column in your NSOutlineView, for each item.
	Return what you want displayed in each column.
----------------------------------------------------------------------------- */

- (id)outlineView:(NSOutlineView *)inView viewForTableColumn:(NSTableColumn *)inColumn item:(id)inItem
{
	NTXTemplateDescriptor * item = (NTXTemplateDescriptor *)inItem;

	NSTableCellView * cellView = [inView makeViewWithIdentifier:@"ViewTemplate" owner:self];
	NSString * name = item.title;
	if (name) {
		cellView.textField.stringValue = name;
	}
	return cellView;
}


/* -----------------------------------------------------------------------------
	Optional method: needed to allow editing.
----------------------------------------------------------------------------- */

//- (void)outlineView:(NSOutlineView *)inView setObjectValue:(id)inObject forTableColumn:(NSTableColumn *)inColumn byItem:(id)inItem {
//	((NTXTemplateDescriptor *)inItem).title = inObject;
//}


/* -----------------------------------------------------------------------------
	The selection changed -- update the content view accordingly.
----------------------------------------------------------------------------- */

//- (void)outlineViewSelectionDidChange:(NSNotification *)inNotification
//{
//	NSTreeNode * theNode = [sidebarView itemAtRow:sidebarView.selectedRow];
//	NTXTemplateDescriptor * item = (NTXTemplateDescriptor *)[theNode representedObject];
//	[self.parentViewController templateSelectionDidChange:item];
//}


/* -----------------------------------------------------------------------------
	Return the selected view template.
----------------------------------------------------------------------------- */

- (Ref)selectedViewTemplate {
	NTXTemplateDescriptor * descriptor = [sidebarView itemAtRow:sidebarView.selectedRow];
	return descriptor.value;
}

@end


/* -----------------------------------------------------------------------------
	N T X S l o t D e s c r i p t o r
----------------------------------------------------------------------------- */

@implementation NTXSlotDescriptor

- (id)init:(RefArg)descriptor {
	if (self = [super init]) {
		slotDescriptor = descriptor;
	}
	return self;
}

- (Ref)value {
	return GetFrameSlot(slotDescriptor, SYMA(value));
}

@synthesize tag;

- (NSString *)title {
	NSString * summary = nil;
	NSString * slotType = self.type;
	if ([slotType isEqualToString:@"NUMB"] || [slotType isEqualToString:@"INTG"]) {
		summary = [NSString stringWithFormat:@"%ld", (long)self.number];
//	} else if ([slotType isEqualToString:@"REAL"]) {
	} else if ([slotType isEqualToString:@"BOOL"]) {
		summary = self.boolean? @"true" : @"nil";
	} else if ([slotType isEqualToString:@"TEXT"]) {
		summary = self.text;
		if (summary.length > 30) {
			summary = [[summary substringToIndex:30] stringByAppendingString:@"…"];
		}
//	} else if ([slotType isEqualToString:@"EVAL"]) {
//		summary = self.text;
	} else if (IsFrame(self.value)) {
		RefVar frame(self.value);
		if (Length(frame) <= 4) {
			summary = @"{";
			FOREACH_WITH_TAG(frame, stag, slot)
				if (ISINT(slot)) {
					summary = [NSString stringWithFormat:@"%@ %s:%ld,", summary, SymbolName(stag), RVALUE(slot)];
				} else {
					summary = nil;
					break;
				}
			END_FOREACH;
			if (summary != nil) {
				summary = [NSString stringWithFormat:@"%@ }", [summary substringToIndex:summary.length-1]];
			}
		}
	}
	if (summary != nil) {
		return [NSString stringWithFormat:@"%@ : %@", self.tag, summary];
	}
	return self.tag;
}

- (NSString *)type {
	return MakeNSString(GetFrameSlot(slotDescriptor, MakeSymbol("__ntDataType")));
}

- (int)flags {
	return RINT(GetFrameSlot(slotDescriptor, MakeSymbol("__ntFlags")));
}

- (NSString *)text {
	return MakeNSString(self.value);
}
- (void)setText:(NSString *)str {
	SetFrameSlot(slotDescriptor, SYMA(value), MakeString(str));
}

- (NSInteger)number {
	return RINT(self.value);
}

- (BOOL)boolean {
	return NOTNIL(self.value);
}

- (NSInteger)boundsLeft {
	return RINT(GetFrameSlot(self.value, SYMA(left)));
}
- (NSInteger)boundsRight {
	return RINT(GetFrameSlot(self.value, SYMA(right)));
}
- (NSInteger)boundsWidth {
	return self.boundsRight - self.boundsLeft;
}
- (NSInteger)boundsTop {
	return RINT(GetFrameSlot(self.value, SYMA(top)));
}
- (NSInteger)boundsBottom {
	return RINT(GetFrameSlot(self.value, SYMA(bottom)));
}
- (NSInteger)boundsHeight {
	return self.boundsBottom - self.boundsTop;
}


@end


/* -----------------------------------------------------------------------------
	N T X S l o t L i s t V i e w C o n t r o l l e r
	A list of slots in a view template.
----------------------------------------------------------------------------- */

@implementation NTXSlotListViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(templateSelectionDidChange:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
	[listView setSortDescriptors:[NSArray arrayWithObject: [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}


- (void)templateSelectionDidChange:(NSNotification *)inNotification {
	NSOutlineView * sender = inNotification.object;
	if (sender.window == self.view.window && [sender.delegate respondsToSelector:@selector(selectedViewTemplate)]) {
		viewTemplateValue = (Ref)[sender.delegate performSelector:@selector(selectedViewTemplate)];
		slots = [[NSMutableArray alloc] initWithCapacity:Length(viewTemplateValue)];
		FOREACH_WITH_TAG(viewTemplateValue, tag, slot)
			const char * slotName = SymbolName(tag);
			if (strcmp(slotName, "stepChildren") != 0 && strncmp(slotName, "__", 2) != 0) {
				NTXSlotDescriptor * descriptor = [[NTXSlotDescriptor alloc] init:slot];
				descriptor.tag = [NSString stringWithUTF8String:slotName];
				[slots addObject:descriptor];
			}
		END_FOREACH;
		[slots sortUsingDescriptors:listView.sortDescriptors];
		[listView deselectAll:self];
		[listView reloadData];
	}
}

- (NTXSlotDescriptor *)selectedSlot {
	if (listView.selectedRow < 0) {
		return nil;
	}
	return [slots objectAtIndex:listView.selectedRow];
}


#pragma mark - NSTableViewDelegate protocol

// override to validate current slection and prevent change on error
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView {}

#pragma mark - NSTableViewDataSource protocol

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return slots.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NTXSlotDescriptor * item = slots[row];
	return item.title;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	[slots sortUsingDescriptors:tableView.sortDescriptors];
	[tableView reloadData];
}

@end


/* -----------------------------------------------------------------------------
	N T X S l o t E d i t o r V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXSlotEditorViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slotSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:nil];
}

- (void)slotSelectionDidChange:(NSNotification *)inNotification {
	NSTableView * sender = inNotification.object;
	if (sender.window == self.view.window && [sender.delegate respondsToSelector:@selector(selectedSlot)]) {
		NTXSlotDescriptor * chosenSlot = (NTXSlotDescriptor *)[sender.delegate performSelector:@selector(selectedSlot)];
		if (chosenSlot != nil) {
			NSString * segueName = chosenSlot.type;
			if ([segueName isEqualToString:@"SCPT"] || [segueName isEqualToString:@"EVAL"]) {
				segueName = @"TEXT";
			} else if ([segueName isEqualToString:@"NUMB"] && ([chosenSlot.tag isEqualToString:@"viewFlags"] || [chosenSlot.tag isEqualToString:@"viewFormat"] || [chosenSlot.tag isEqualToString:@"viewJustify"] || [chosenSlot.tag isEqualToString:@"viewEffect"])) {
				segueName = chosenSlot.tag;
			}

			[self performSegueWithIdentifier:segueName sender:chosenSlot];
		}
	}
}


- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
	NSViewController * toViewController = (NSViewController *)segue.destinationController;
	toViewController.representedObject = sender;
//	toViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	NSViewController * fromViewController = (self.childViewControllers.count > 0)? [self.childViewControllers objectAtIndex:0] : nil;

	[self addChildViewController:toViewController];
//	[self transitionFromViewController:fromViewController toViewController:toViewController options:0 completionHandler:^{[fromViewController removeFromParentViewController];}];
	[self transitionFromViewController:fromViewController toViewController:toViewController];
}


- (void) transitionFromViewController:(NSViewController *)fromViewController toViewController:(NSViewController *)toViewController
{
	// remove any previous item view
	if (fromViewController) {
		[fromViewController.view removeFromSuperview];
		[fromViewController removeFromParentViewController];
	}

	if (toViewController) {
		NSView * subview = toViewController.view;
		// make sure our added subview is placed and resizes correctly
		if (subview) {
			[subview setTranslatesAutoresizingMaskIntoConstraints:NO];
			[self.view addSubview:subview];
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeLeft	 relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft	multiplier:1 constant:0]];
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeRight	 relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight	multiplier:1 constant:0]];
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeTop	 relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop		multiplier:1 constant:0]];
			[self.view addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom	multiplier:1 constant:0]];
		}
	}
}

@end
