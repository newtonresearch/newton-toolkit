/*
	File:		LayoutViewController.mm

	Abstract:	Implementation of NTXLayoutViewController subclasses.
					Interesting __platform slots:
						__ntDefaults: for RECT, SCPT, EVAL default values
						templateArray: array of symbol, frame pairs naming and defining proto templates
						viewClassArray: array of symbol, frame pairs naming and defining viewclass templates
						scriptSlots: frame of template descriptors for well-known viewScripts -- includes __ntHelp
						attributeSlots: frame of template descriptors for well-known slots -- includes __ntHelp
						templates: like templateArray but in frame form
						viewClasses: like viewClassArray but in frame form


	Written by:		Newton Research, 2016.
*/

#import "NTXDocument.h"
#import "AppDelegate.h"
#import "LayoutViewController.h"
#import "Utilities.h"
#import "NTK/Globals.h"
#import "MacRsrcTypes.h"


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X L a y o u t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the view template list view.
----------------------------------------------------------------------------- */
@implementation NTXLayoutViewController

- (IBAction)toggleTemplates:(id)sender {
	templateListItem.animator.collapsed = !templateListItem.isCollapsed;
}
@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X T e m p l a t e D e s c r i p t o r
	An item in the hierarchical list of view templates.
----------------------------------------------------------------------------- */
extern const char * FilenameFromFSSpec(void * inFSpec, ArrayIndex inLen);

@implementation NTXTemplateDescriptor

-(id)init:(RefArg)descriptor {
	if (self = [super init]) {
		viewTemplateDescriptor = descriptor;
	}
	return self;
}

-(Ref)value {
	return GetFrameSlot(viewTemplateDescriptor, SYMA(value));
}
-(void)setValue:(Ref)inValue {
	SetFrameSlot(viewTemplateDescriptor, SYMA(value), inValue);
}

-(NSString *)title {
	NSString * titleStr = [self protoName];
	RefVar name(GetFrameSlot(viewTemplateDescriptor, MakeSymbol("__ntName")));
	if (NOTNIL(name)) {
		titleStr = [NSString stringWithFormat:@"%@ : %@", titleStr, MakeNSString(name)];
	}
	return titleStr;
}

-(NSString *)protoName {
	RefVar vwTemplate(GetFrameSlot(viewTemplateDescriptor, MakeSymbol("__ntId")));
	if (EQ(vwTemplate, MakeSymbol("userProto"))) {
		// template is a slot descriptor whose value is an FSSpec
		vwTemplate = GetFrameSlot(viewTemplateDescriptor, SYMA(value));
		vwTemplate = GetFrameSlot(vwTemplate, MakeSymbol("__ntTemplate"));
		// might want to assert that vwTemplate.__ntDataType = "USER"
		RefVar value(GetFrameSlot(vwTemplate, SYMA(value)));
		const char * filename = FilenameFromFSSpec(BinaryData(value), Length(value));
		return [NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding];
	}
	return [NSString stringWithUTF8String:SymbolName(vwTemplate)];
}

-(bool)hasChildren {
	return FrameHasSlot(self.value, SYMA(stepChildren));
}

@end


#pragma mark -
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


#pragma mark NSOutlineView item insertion/deletion
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


#pragma mark NSOutlineViewDelegate protocol
/* -----------------------------------------------------------------------------
	Determine whether an item is a group title.
----------------------------------------------------------------------------- */

- (BOOL)outlineView:(NSOutlineView *)inView isGroupItem:(id)inItem {
	return NO;	// we don’t have any group items in the view template list
}

/* -----------------------------------------------------------------------------
	Show the disclosure triangle for the views with children.
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


#pragma mark NSOutlineViewDataSource protocol
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

- (id)outlineView:(NSOutlineView *)inView child:(NSInteger)index ofItem:(id)inItem {
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


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X S l o t D e s c r i p t o r
----------------------------------------------------------------------------- */
@implementation NTXSlotDescriptor

- (id)initTag:(RefArg)name value:(RefArg)descriptor {
	if (self = [super init]) {
		slotDescriptor = descriptor;

		if (EQ(name, MakeSymbol("__ntTemplate"))) {
			// it’s the viewClass or _proto
			if (self.type == 'CLAS') {
				self.tag = @"viewClass";
			} else {
				// must be 'PROT' or 'USER'
				self.tag = @"_proto";
			}
		} else {
			self.tag = [NSString stringWithUTF8String:SymbolName(name)];
		}
	}
	return self;
}


- (Ref)value {
	// validate
	RefVar v(GetFrameSlot(slotDescriptor, SYMA(value)));
	if (self.type == 'NUMB' && NOTINT(v)) {
		return 0;
	}
	return v;
}
-(void)setValue:(Ref)inValue {
	SetFrameSlot(slotDescriptor, SYMA(value), inValue);
}


- (NSString *)title {
	NSString * summary = nil;
	switch (self.type) {
	case 'NUMB':
	case 'INTG':
		summary = [NSString stringWithFormat:@"%ld", (long)self.number];
		break;
	case 'REAL':
		break;
	case 'BOOL':
		summary = self.boolean? @"true" : @"nil";
		break;
	case 'TEXT':
		summary = self.text;
		if (summary.length > 30) {
			summary = [[summary substringToIndex:30] stringByAppendingString:@"…"];
		}
		break;
//	case 'EVAL':
//		summary = self.text;
//		break;
	default: {
			RefVar frame(self.value);
			if (IsFrame(frame) && Length(frame) <= 4) {
				summary = @"{";
				FOREACH_WITH_TAG(frame, stag, slot)
					if (ISINT(slot)) {
						summary = [NSString stringWithFormat:@"%@ %s:%ld,", summary, SymbolName(stag), RVALUE(slot)];
					} else {
						summary = nil;
						break;
					}
				END_FOREACH
				if (summary != nil) {
					summary = [NSString stringWithFormat:@"%@ }", [summary substringToIndex:summary.length-1]];
				}
			}
		}
	}
	if (summary != nil) {
		return [NSString stringWithFormat:@"%@ : %@", self.tag, summary];
	}
	return self.tag;
}

- (const char *)typeString {
	return BinaryData(ASCIIString(GetFrameSlot(slotDescriptor, MakeSymbol("__ntDataType"))));
}

- (int)type {
	const char * typeStr = self.typeString;
	return (typeStr[0] << 24) + (typeStr[1] << 16) + (typeStr[2] << 8) + typeStr[3];
}

- (int)flags {
	return RINT(GetFrameSlot(slotDescriptor, MakeSymbol("__ntFlags")));
}

#pragma mark -
/* -----------------------------------------------------------------------------
	T E X T
----------------------------------------------------------------------------- */
- (NSString *)text {
	return MakeNSString(self.value);
}
- (void)setText:(NSString *)str {
	SetFrameSlot(slotDescriptor, SYMA(value), MakeString(str));
}

/* -----------------------------------------------------------------------------
	N U M B
----------------------------------------------------------------------------- */
- (NSInteger)number {
	return RINT(self.value);
}
- (void)setNumber:(NSInteger)inValue {
	self.value = MAKEINT(inValue);
}

/* -----------------------------------------------------------------------------
	B O O L
----------------------------------------------------------------------------- */
- (BOOL)boolean {
	return NOTNIL(self.value);
}
- (void)setBoolean:(BOOL)inValue {
	self.value = MAKEBOOLEAN(inValue);
}

#pragma mark -
/* -----------------------------------------------------------------------------
	R E C T
----------------------------------------------------------------------------- */
- (NSInteger)boundsLeft {
	return RINT(GetFrameSlot(self.value, SYMA(left)));
}
- (void)setBoundsLeft:(NSInteger)inValue {
	SetFrameSlot(self.value, SYMA(left), MAKEINT(inValue));
}
- (NSInteger)boundsRight {
	return RINT(GetFrameSlot(self.value, SYMA(right)));
}
- (void)setBoundsRight:(NSInteger)inValue {
	SetFrameSlot(self.value, SYMA(right), MAKEINT(inValue));
}
- (NSInteger)boundsWidth {
	return self.boundsRight - self.boundsLeft;
}
- (NSInteger)boundsTop {
	return RINT(GetFrameSlot(self.value, SYMA(top)));
}
- (void)setBoundsTop:(NSInteger)inValue {
	SetFrameSlot(self.value, SYMA(top), MAKEINT(inValue));
}
- (NSInteger)boundsBottom {
	return RINT(GetFrameSlot(self.value, SYMA(bottom)));
}
- (void)setBoundsBottom:(NSInteger)inValue {
	SetFrameSlot(self.value, SYMA(bottom), MAKEINT(inValue));
}
- (NSInteger)boundsHeight {
	return self.boundsBottom - self.boundsTop;
}

#pragma mark -
/* -----------------------------------------------------------------------------
	viewFlags
----------------------------------------------------------------------------- */
#import "ViewFlags.h"

- (BOOL)getFlag:(long)inBit {
	return (RINT(self.value) & inBit) != 0;
}
- (void)setFlag:(long)inBit on:(BOOL)inSet {
	long v = RINT(self.value);
	if (inSet) {
		FLAGSET(v, inBit);
	} else {
		FLAGCLEAR(v, inBit);
	}
	self.value = MAKEINT(v);
}

- (BOOL)_vVisible {
	return [self getFlag:vVisible];
}
- (void)set_vVisible:(BOOL)inValue {
	[self setFlag:vVisible on:inValue];
}

- (BOOL)_vReadOnly {
	return [self getFlag:vReadOnly];
}
- (void)set_vReadOnly:(BOOL)inValue {
	[self setFlag:vReadOnly on:inValue];
}

- (BOOL)_vApplication {
	return [self getFlag:vApplication];
}
- (void)set_vApplication:(BOOL)inValue {
	[self setFlag:vApplication on:inValue];
}

- (BOOL)_vCalculateBounds {
	return [self getFlag:vCalculateBounds];
}
- (void)set_vCalculateBounds:(BOOL)inValue {
	[self setFlag:vCalculateBounds on:inValue];
}

- (BOOL)_vClipping {
	return [self getFlag:vClipping];
}
- (void)set_vClipping:(BOOL)inValue {
	[self setFlag:vClipping on:inValue];
}

- (BOOL)_vFloating {
	return [self getFlag:vFloating];
}
- (void)set_vFloating:(BOOL)inValue {
	[self setFlag:vFloating on:inValue];
}

- (BOOL)_vWriteProtected {
	return [self getFlag:vWriteProtected];
}
- (void)set_vWriteProtected:(BOOL)inValue {
	[self setFlag:vWriteProtected on:inValue];
}

- (BOOL)_vSingleUnit {
	return [self getFlag:vSingleUnit];
}
- (void)set_vSingleUnit:(BOOL)inValue {
	[self setFlag:vSingleUnit on:inValue];
}

- (BOOL)_vClickable {
	return [self getFlag:vClickable];
}
- (void)set_vClickable:(BOOL)inValue {
	[self setFlag:vClickable on:inValue];
}

- (BOOL)_vStrokesAllowed {
	return [self getFlag:vStrokesAllowed];
}
- (void)set_vStrokesAllowed:(BOOL)inValue {
	[self setFlag:vStrokesAllowed on:inValue];
}

- (BOOL)_vGesturesAllowed {
	return [self getFlag:vGesturesAllowed];
}
- (void)set_vGesturesAllowed:(BOOL)inValue {
	[self setFlag:vGesturesAllowed on:inValue];
}

- (BOOL)_vCharsAllowed {
	return [self getFlag:vCharsAllowed];
}
- (void)set_vCharsAllowed:(BOOL)inValue {
	[self setFlag:vCharsAllowed on:inValue];
}

- (BOOL)_vNumbersAllowed {
	return [self getFlag:vNumbersAllowed];
}
- (void)set_vNumbersAllowed:(BOOL)inValue {
	[self setFlag:vNumbersAllowed on:inValue];
}

- (BOOL)_vLettersAllowed {
	return [self getFlag:vLettersAllowed];
}
- (void)set_vLettersAllowed:(BOOL)inValue {
	[self setFlag:vLettersAllowed on:inValue];
}

- (BOOL)_vPunctuationAllowed {
	return [self getFlag:vPunctuationAllowed];
}
- (void)set_vPunctuationAllowed:(BOOL)inValue {
	[self setFlag:vPunctuationAllowed on:inValue];
}

- (BOOL)_vShapesAllowed {
	return [self getFlag:vShapesAllowed];
}
- (void)set_vShapesAllowed:(BOOL)inValue {
	[self setFlag:vShapesAllowed on:inValue];
}

- (BOOL)_vMathAllowed {
	return [self getFlag:vMathAllowed];
}
- (void)set_vMathAllowed:(BOOL)inValue {
	[self setFlag:vMathAllowed on:inValue];
}

- (BOOL)_vAnythingAllowed {
	return (RINT(self.value) & vAnythingAllowed) == vAnythingAllowed;
}
- (void)set_vAnythingAllowed:(BOOL)inValue {
	if (inValue) {
		[self setFlag:vAnythingAllowed on:YES];
	}
}

- (BOOL)_vCapsRequired {
	return [self getFlag:vCapsRequired];
}
- (void)set_vCapsRequired:(BOOL)inValue {
	[self setFlag:vCapsRequired on:inValue];
}

- (BOOL)_vCustomDictionaries {
	return [self getFlag:vCustomDictionaries];
}
- (void)set_vCustomDictionaries:(BOOL)inValue {
	[self setFlag:vCustomDictionaries on:inValue];
}

- (BOOL)_vNoScripts {
	return [self getFlag:vNoScripts];
}
- (void)set_vNoScripts:(BOOL)inValue {
	[self setFlag:vNoScripts on:inValue];
}

- (NSInteger)_vField {
	return RINT(self.value) & 0x007C0000;
}
- (void)set_vField:(NSInteger)inValue {
	long v = RINT(self.value) & ~0x007C0000;
	self.value = MAKEINT(v + (inValue & 0x007C0000));
}

#pragma mark -
/* -----------------------------------------------------------------------------
	viewFormat
----------------------------------------------------------------------------- */

- (NSInteger)_vfPen {
	return (RINT(self.value) & vfPenMask) >> vfPenShift;
}
- (void)set_vfPen:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfPenMask;
	self.value = MAKEINT(v + (vfPen(inValue) & vfPenMask));
}

- (NSInteger)_vfRoundness {
	return (RINT(self.value) & vfRoundMask) >> vfRoundShift;
}
- (void)set_vfRoundness:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfRoundMask;
	self.value = MAKEINT(v + (vfRound(inValue) & vfRoundMask));
}

- (NSInteger)_vfInset {
	return (RINT(self.value) & vfInsetMask) >> vfInsetShift;
}
- (void)set_vfInset:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfInsetMask;
	self.value = MAKEINT(v + (vfInset(inValue) & vfInsetMask));
}

- (NSInteger)_vfShadow {
	return (RINT(self.value) & vfShadowMask) >> vfShadowShift;
}
- (void)set_vfShadow:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfShadowMask;
	self.value = MAKEINT(v + (vfShadow(inValue) & vfShadowMask));
}


- (NSInteger)_vfFrame {
	return (RINT(self.value) & vfFrameMask) >> vfFrameShift;
}
- (void)set_vfFrame:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfFrameMask;
	self.value = MAKEINT(v + ((inValue << vfFrameShift) & vfFrameMask));
}

- (NSInteger)_vfFill {
	return (RINT(self.value) & vfFillMask) >> vfFillShift;
}
- (void)set_vfFill:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfFillMask;
	self.value = MAKEINT(v + ((inValue << vfFillShift) & vfFillMask));
}

- (NSInteger)_vfLines {
	return (RINT(self.value) & vfLinesMask) >> vfLineShift;
}
- (void)set_vfLines:(NSInteger)inValue {
	long v = RINT(self.value) & ~vfLinesMask;
	self.value = MAKEINT(v + ((inValue << vfLineShift) & vfLinesMask));
}


#pragma mark -
/* -----------------------------------------------------------------------------
	viewJustify
----------------------------------------------------------------------------- */
#define vjSelfHShift			 0
#define vjSelfVShift			 2
#define vjParentHShift		 4
#define vjParentVShift		 6
#define vjSiblingHShift		 9
#define vjSiblingVShift		12
#define vjLineLimitShift	23

- (NSInteger)_vjParentH {
	return (RINT(self.value) & vjParentHMask) >> vjParentHShift;
}
- (void)set_vjParentH:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjParentHMask;
	self.value = MAKEINT(v + ((inValue << vjParentHShift) & vjParentHMask));
}

- (NSInteger)_vjParentV {
	return (RINT(self.value) & vjParentVMask) >> vjParentVShift;
}
- (void)set_vjParentV:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjParentVMask;
	self.value = MAKEINT(v + ((inValue << vjParentVShift) & vjParentVMask));
}

- (NSInteger)_vjSiblingH {
	return (RINT(self.value) & vjSiblingHMask) >> vjSiblingHShift;
}
- (void)set_vjSiblingH:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjSiblingHMask;
	self.value = MAKEINT(v + ((inValue << vjSiblingHShift) & vjSiblingHMask));
}

- (NSInteger)_vjSiblingV {
	return (RINT(self.value) & vjSiblingVMask) >> vjSiblingVShift;
}
- (void)set_vjSiblingV:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjSiblingVMask;
	self.value = MAKEINT(v + ((inValue << vjSiblingVShift) & vjSiblingVMask));
}

- (NSInteger)_vjTextH {
	return (RINT(self.value) & vjHMask);
}
- (void)set_vjTextH:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjHMask;
	self.value = MAKEINT(v + (inValue & vjHMask));
}

- (NSInteger)_vjTextV {
	return (RINT(self.value) & vjVMask) >> vjSelfVShift;
}
- (void)set_vjTextV:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjVMask;
	self.value = MAKEINT(v + ((inValue >> vjSelfVShift) & vjVMask));
}

- (NSInteger)_vjTextLimits {
	return (RINT(self.value) & vjLineLimitMask) >> vjLineLimitShift;
}
- (void)set_vjTextLimits:(NSInteger)inValue {
	long v = RINT(self.value) & ~vjLineLimitMask;
	self.value = MAKEINT(v + ((inValue << vjLineLimitShift) & vjLineLimitMask));
}

- (BOOL)_vjReflow {
	return [self getFlag:vjReflow];
}
- (void)set_vjReflow:(BOOL)inValue {
	[self setFlag:vjReflow on:inValue];
}

- (BOOL)_vjChildrenLasso {
	return [self getFlag:vjChildrenLasso];
}
- (void)set_vjChildrenLasso:(BOOL)inValue {
	[self setFlag:vjChildrenLasso on:inValue];
}


@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X S l o t L i s t V i e w C o n t r o l l e r
	A list of slots in a view template.
----------------------------------------------------------------------------- */
@implementation NTXSlotListViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(templateSelectionDidChange:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
	[listView setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];

	// build add-slot menu
	NSArray * sortDescr = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:nil ascending:YES selector:@selector(caseInsensitiveCompare:)]];

	RefVar platform(GetGlobalVar(MakeSymbol("__platform")));
	RefVar slotDefs(GetFrameSlot(platform, MakeSymbol("scriptSlots")));
	NSMutableArray * items = [[NSMutableArray alloc] initWithCapacity:Length(slotDefs)];
	if (IsFrame(slotDefs)) {
		FOREACH_WITH_TAG(slotDefs, tag, value)
			[items addObject:[NSString stringWithUTF8String:SymbolName(tag)]];
		END_FOREACH
		[items sortUsingDescriptors:sortDescr];
	}
	NSMenu * scriptMenu = [[NSMenu alloc] initWithTitle:@"Script"];
	for (NSString * title in items) {
		[scriptMenu addItemWithTitle:title action:@selector(addScript:) keyEquivalent:@""].target = self;
	}
	scriptMenu.autoenablesItems = NO;

	slotDefs = GetFrameSlot(platform, MakeSymbol("attributeSlots"));
	items = [[NSMutableArray alloc] initWithCapacity:Length(slotDefs)];
	if (IsFrame(slotDefs)) {
		FOREACH_WITH_TAG(slotDefs, tag, value)
			[items addObject:[NSString stringWithUTF8String:SymbolName(tag)]];
		END_FOREACH
		[items sortUsingDescriptors:sortDescr];
	}
	NSMenu * attributeMenu = [[NSMenu alloc] initWithTitle:@"Attribute"];
	for (NSString * title in items) {
		[attributeMenu addItemWithTitle:title action:@selector(addAttribute:) keyEquivalent:@""].target = self;
	}
	attributeMenu.autoenablesItems = NO;

	NSMenu * typeMenu = [[NSMenu alloc] initWithTitle:@"Add Slot"];
	for (NSString * title in @[@"Script", @"Text", @"Number", @"Booolean", @"Rectangle", @"-", @"Evaluate"]) {
		if ([title isEqualToString:@"-"]) {
			[typeMenu addItem:[NSMenuItem separatorItem]];
		} else {
			[typeMenu addItemWithTitle:title action:@selector(addSlot:) keyEquivalent:@""].target = self;
		}
	}
	typeMenu.autoenablesItems = NO;

	NSMenu * slotMenu = [[NSMenu alloc] initWithTitle:@"Add"];
	[slotMenu setSubmenu:typeMenu forItem:[slotMenu addItemWithTitle:@"Add Slot" action:nil keyEquivalent:@""]];
	[slotMenu addItem:[NSMenuItem separatorItem]];
	[slotMenu setSubmenu:scriptMenu forItem:[slotMenu addItemWithTitle:@"Script" action:nil keyEquivalent:@""]];
	[slotMenu setSubmenu:attributeMenu forItem:[slotMenu addItemWithTitle:@"Attribute" action:nil keyEquivalent:@""]];

	slotPopup.menu = slotMenu;
}


- (void)templateSelectionDidChange:(NSNotification *)inNotification {
	NSOutlineView * sender = inNotification.object;
	if (sender.window == self.view.window && [sender.delegate respondsToSelector:@selector(selectedViewTemplate)]) {
		viewTemplateValue = (Ref)[sender.delegate performSelector:@selector(selectedViewTemplate)];
		slots = [[NSMutableArray alloc] initWithCapacity:Length(viewTemplateValue)];
		FOREACH_WITH_TAG(viewTemplateValue, tag, slot)
			Ref flags = GetFrameSlot(slot, MakeSymbol("__ntFlags"));
			if (ISINT(flags) && FLAGTEST(RVALUE(flags), kSlotIsInvisible)) {
				// don’t show it
			} else {
				NTXSlotDescriptor * descriptor = [[NTXSlotDescriptor alloc] initTag:tag value:slot];
				[slots addObject:descriptor];
			}
		END_FOREACH
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


- (IBAction)addSlot:(id)sender {
NSLog(@"-[ addSlot:]");
}

- (IBAction)addScript:(id)sender {
NSLog(@"-[ addScript:]");
}

- (IBAction)addAttribute:(id)sender {
NSLog(@"-[ addAttribute:]");
}


#pragma mark NSTableViewDelegate protocol

// override to validate current slection and prevent change on error
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView {}

#pragma mark NSTableViewDataSource protocol

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


#pragma mark -
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
			NSString * tabName = [NSString stringWithFormat:@"%s", chosenSlot.typeString];
			switch (chosenSlot.type) {
			case 'SCPT':
			case 'EVAL':
				tabName = @"TEXT";
				break;
			case 'PROT':
			case 'CLAS':
			case 'USER':
			case 'LINK':
				tabName = @"viewTemplate";
				break;
			case 'NUMB':
				if ([chosenSlot.tag isEqualToString:@"viewFlags"] || [chosenSlot.tag isEqualToString:@"viewFormat"] || [chosenSlot.tag isEqualToString:@"viewJustify"] || [chosenSlot.tag isEqualToString:@"viewEffect"]) {
					tabName = chosenSlot.tag;
				}
			}

			// look up tab index from id
			NSInteger index = [self.tabView indexOfTabViewItemWithIdentifier:tabName];
			if (index == NSNotFound) {
				NSLog(@"tab view not found!");
				index = 0;
			}
			
			NSViewController * toViewController = self.tabViewItems[index].viewController;
			toViewController.representedObject = chosenSlot;
			self.selectedTabViewItemIndex = index;
		}
	}
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X V i e w T e m p l a t e C o n t r o l l e r
	The viewClass / _proto chooser.
----------------------------------------------------------------------------- */
#import "ProjectDocument.h"
#define kUserProtoBaseRef 999

@implementation NTXViewTemplateController

- (void)viewDidLoad {
	[super viewDidLoad];

	// build proto template menu
	NSMenu * protoMenu = [[NSMenu alloc] initWithTitle:@"View Template"];
	protoMenu.autoenablesItems = NO;
	NSArray * sortDescr = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)]];
	NSMutableArray<NSDictionary*> * items;

	NTXProjectDocument * doc = ((NSViewController *)self.parentViewController).view.window.windowController.document;
	NSArray<NTXProjectItem*> * userProtos = doc.userProtos;

	if (userProtos.count > 0) {
		items = [[NSMutableArray alloc] initWithCapacity:userProtos.count];
		int fakeRef = kUserProtoBaseRef;
		for (NTXProjectItem * item in userProtos) {
			[items addObject:@{@"title":item.name, @"value":[NSNumber numberWithInt:fakeRef++]}];
		}
		[items sortUsingDescriptors:sortDescr];
		for (NSDictionary * slot in items) {
			NSMenuItem * item = [protoMenu addItemWithTitle:[slot objectForKey:@"title"] action:@selector(updateTemplate:) keyEquivalent:@""];
			item.tag = [[slot objectForKey:@"value"] intValue];
			item.target = self;
		}

		[protoMenu addItem:[NSMenuItem separatorItem]];
	}
	
	RefVar platform(GetGlobalVar(MakeSymbol("__platform")));
	RefVar classes(GetFrameSlot(platform, MakeSymbol("viewClasses")));
	items = [[NSMutableArray alloc] initWithCapacity:Length(classes)];
	FOREACH_WITH_TAG(classes, tag, value)
		Ref viewClass = GetFrameSlot(value, SYMA(viewClass));
		[items addObject:@{@"title":[NSString stringWithUTF8String:SymbolName(tag)], @"value":[NSNumber numberWithInt:viewClass]}];
	END_FOREACH
	[items sortUsingDescriptors:sortDescr];
	for (NSDictionary * slot in items) {
		NSMenuItem * item = [protoMenu addItemWithTitle:[slot objectForKey:@"title"] action:@selector(updateTemplate:) keyEquivalent:@""];
		item.tag = [[slot objectForKey:@"value"] intValue];
		item.target = self;
	}

	[protoMenu addItem:[NSMenuItem separatorItem]];

	RefVar templates(GetFrameSlot(platform, MakeSymbol("templates")));
	items = [[NSMutableArray alloc] initWithCapacity:Length(templates)];
	FOREACH_WITH_TAG(templates, tag, value)
		Ref viewProto = GetFrameSlot(value, SYMA(_proto));
		[items addObject:@{@"title":[NSString stringWithUTF8String:SymbolName(tag)], @"value":[NSNumber numberWithInt:viewProto]}];
	END_FOREACH
	[items sortUsingDescriptors:sortDescr];
	for (NSDictionary * slot in items) {
		NSMenuItem * item = [protoMenu addItemWithTitle:[slot objectForKey:@"title"] action:@selector(updateTemplate:) keyEquivalent:@""];
		item.tag = [[slot objectForKey:@"value"] intValue];
		item.target = self;
	}

	protoPopup.menu = protoMenu;
	[protoPopup selectItemWithTag:((NTXSlotDescriptor*)self.representedObject).value];
}


- (IBAction)updateTemplate:(id)sender {
	Ref proto = (Ref)[(NSMenuItem*)sender tag];
	if (proto >= kUserProtoBaseRef) {
		;	// hmmm... make an FSAliasX to put in the value; or even better an NSURL
	} else {
		((NTXSlotDescriptor*)self.representedObject).value = proto;
	}
	// need to update selected row in NTXTemplateListViewController
}


@end


// may come in handy one day...

#if 0
- (void)setProtoName:(NSString *)protoName {
	Ref numericValue = 0;
	const char * name = protoName.UTF8String;
	RefVar platform(GetGlobalVar(SYMA(__platform)));
	RefVar classes(GetFrameSlot(platform, MakeSymbol("viewClasses")));
	RefVar templates(GetFrameSlot(platform, MakeSymbol("templates")));
	FOREACH_WITH_TAG(classes, tag, slot)
		if (strcmp(SymbolName(tag), name) == 0) {
			numericValue = GetFrameSlot(slot, MakeSymbol("viewClass"));
			break;
		}
	END_FOREACH
	if (numericValue == 0) {
		FOREACH_WITH_TAG(templates, tag, slot)
			if (strcmp(SymbolName(tag), name) == 0) {
				numericValue = GetFrameSlot(slot, MakeSymbol("_proto"));
				break;
			}
		END_FOREACH
	}
	if (numericValue != 0) {
		NTXSlotDescriptor * descr = self.representedObject;
		descr.value = numericValue;
	}
}

- (NSString *)protoName {
	NTXSlotDescriptor * descr = self.representedObject;
	Ref numericValue = descr.value;
	RefVar foundSymbol;
	RefVar platform(GetGlobalVar(SYMA(__platform)));
	RefVar classes(GetFrameSlot(platform, MakeSymbol("viewClasses")));
	RefVar templates(GetFrameSlot(platform, MakeSymbol("templates")));
	FOREACH_WITH_TAG(classes, tag, slot)
		if (GetFrameSlot(slot, MakeSymbol("viewClass")) == numericValue) {
			foundSymbol = tag;
			break;
		}
	END_FOREACH
	if (ISNIL(foundSymbol)) {
		FOREACH_WITH_TAG(templates, tag, slot)
			if (GetFrameSlot(slot, MakeSymbol("_proto")) == numericValue) {
				foundSymbol = tag;
				break;
			}
		END_FOREACH
	}
	if (ISNIL(foundSymbol)) {
		return @"clView";
	}
	return [NSString stringWithCString:SymbolName(foundSymbol) encoding:NSMacOSRomanStringEncoding];
}
#endif
