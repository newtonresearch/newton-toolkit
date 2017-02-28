/*
	File:		NTXSettingsViewController.mm

	Abstract:	Implementation of NTXSettingsViewController class.

	Written by:		Newton Research, 2014.
*/

#import "SettingsViewController.h"
#import "ProjectDocument.h"
#import "Utilities.h"

extern NSString *	MakeNSString(RefArg inStr);


@implementation NTXPopupCell
/*
- (void) drawImageWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.size.width = 100;
	[super drawImageWithFrame:cellFrame inView:controlView];
}
*/
- (void)drawBorderAndBackgroundWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.size.width = 100;
	[super drawBorderAndBackgroundWithFrame:cellFrame inView:controlView];
}
@end


@interface NTXSettingsViewController (NewtonScript)
- (Ref) pathFor: (NSString *) inPath;
@end


@implementation NTXSettingsViewController

/* -----------------------------------------------------------------------------
	Initialize.
----------------------------------------------------------------------------- */

- (void)viewDidLoad
{
	[super viewDidLoad];

	settings = [[NSArray alloc] initWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"projectsettings" withExtension:@"plist"]];

	// build platform menu
	[platformMenu removeAllItems];
	// read platform filenames
	NSArray * platformURLs = [NSBundle.mainBundle URLsForResourcesWithExtension:nil subdirectory:@"Platforms"];
	for (NSURL * url in platformURLs)
	{
		NSString * platformName = [url lastPathComponent];
		NSMenuItem * platformItem = [[NSMenuItem alloc] initWithTitle:platformName action:NULL keyEquivalent:@""];
		[platformMenu addItem: platformItem];
	}

	// set menu font
	menuFont = [NSFont fontWithName:@"LucidaGrande" size:11.0];

	dispatch_async(dispatch_get_main_queue(), ^{
		[outlineView expandItem:nil expandChildren:YES];
	});
}


/* -----------------------------------------------------------------------------
	When the panel is hidden, save settings to project file.
-----------------------------------------------------------------------------

- (void)viewWillDisappear
{
}*/


#pragma mark NSOutlineViewDelegate protocol
/* -----------------------------------------------------------------------------
	Determine whether an item is a group title.
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView isGroupItem: (id) inItem
{
	return [inItem objectForKey:@"settings"] != nil;
}

/* -----------------------------------------------------------------------------
	Show the disclosure triangle for the project.
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView shouldShowOutlineCellForItem: (id) inItem;
{
	return [inItem objectForKey:@"settings"] != nil;
}


/* -----------------------------------------------------------------------------
	We can select everything.
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inView shouldSelectItem: (id) inItem
{
	return YES;
}


/* -----------------------------------------------------------------------------
	Return a cell appropriate for the value.
----------------------------------------------------------------------------- */

- (NSCell *) outlineView: (NSOutlineView *) inView dataCellForTableColumn: (NSTableColumn *) inColumn item: (id) inItem
{
	NSCell * __autoreleasing cell = nil;
   if ([[inColumn identifier] isEqualTo:@"value"])
	{
		NSString * cellType = [inItem objectForKey:@"type"];
		// instantiate cell of that type
		if ([cellType isEqualTo:@"boolean"])
		{
			cell = [[NTXPopupCell alloc] initTextCell:@"" pullsDown:NO];
			[cell setMenu:booleanMenu];
			[cell setBordered:NO];
			[cell setFont:menuFont];
		}
		else if ([cellType isEqualTo:@"part"])
		{
			cell = [[NTXPopupCell alloc] initTextCell:@"" pullsDown:NO];
			[cell setMenu:partMenu];
			[cell setBordered:NO];
			[cell setFont:menuFont];
		}
		else if ([cellType isEqualTo:@"platform"])
		{
			cell = [[NTXPopupCell alloc] initTextCell:@"" pullsDown:NO];
			[cell setMenu:platformMenu];
			[cell setBordered:NO];
			[cell setFont:menuFont];
		}
		else
			cell = [inColumn dataCell];
	}
	else
		cell = [inColumn dataCell];
	return cell;
}


/* -----------------------------------------------------------------------------
	Set initial value in popup cell.
----------------------------------------------------------------------------- */
#if 0
- (void) outlineView: (NSOutlineView *)inView willDisplayCell: (id)cell forTableColumn: (NSTableColumn *)inColumn item: (id)inItem
{
   if ([[inColumn identifier] isEqualTo:@"value"])
	{
		NSString * cellType = [inItem objectForKey:@"type"];
		if ([cellType isEqualTo:@"boolean"])
		{
		}
		else if ([cellType isEqualTo:@"part"])
		{
		}
		else if ([cellType isEqualTo:@"platform"])
		{
		}
	}
}
#endif

#pragma mark NSOutlineViewDataSource protocol

- (NSArray *) childrenForItem: (id) inItem
{
	return inItem ? [inItem objectForKey:@"settings"] : settings;
}


/* -----------------------------------------------------------------------------
	Return the number of children a particular item has.
	Because we are using a standard array of NSDictionary, we can just return
	the count.
----------------------------------------------------------------------------- */

- (NSInteger) outlineView: (NSOutlineView *) inOutlineView numberOfChildrenOfItem: (id) inItem
{
	NSArray * children = [self childrenForItem: inItem];
	return [children count];
}


/* -----------------------------------------------------------------------------
	NSOutlineView will iterate over every child of every item, recursively asking
	for the entry at each index. Return the item at a given index.
----------------------------------------------------------------------------- */

- (id) outlineView: (NSOutlineView *) inOutlineView child: (int) index ofItem: (id) inItem
{
    NSArray * children = [self childrenForItem: inItem];
    // This will return an NSDictionary defining the setting
    return [children objectAtIndex: index];
}


/* -----------------------------------------------------------------------------
	Determine whether an item can be expanded.
	In our case, if an item has children then it is expandable.    
----------------------------------------------------------------------------- */

- (BOOL) outlineView: (NSOutlineView *) inOutlineView isItemExpandable: (id) inItem
{
	return [inItem objectForKey:@"settings"] != nil;
}


/* -----------------------------------------------------------------------------
	NSOutlineView calls this for each column in your NSOutlineView, for each item.
	Return what you want displayed in each column.
----------------------------------------------------------------------------- */

- (id) outlineView: (NSOutlineView *) inOutlineView objectValueForTableColumn: (NSTableColumn *) inColumn byItem: (id) inItem
{
	// column 1 => title
	// column 2 => value of slot at path
   if ([[inColumn identifier] isEqualTo:@"title"])
		return [inItem objectForKey:@"title"];

	NSString * pathStr = [inItem objectForKey:@"path"];
	if (pathStr == nil)
		return nil;

	RefVar pathRef([self pathFor:pathStr]);
	RefVar value(GetFramePath(((NTXProjectDocument *)self.representedObject).projectRef, pathRef));

	NSString * cellType = [inItem objectForKey:@"type"];
	// return object for cell of that type
	if ([cellType isEqualTo:@"boolean"])
	{
		return [NSNumber numberWithUnsignedInt: NOTNIL(value) ? 0 : 1];
	}
	else if ([cellType isEqualTo:@"part"])
	{
		return [NSNumber numberWithUnsignedInt: RINT(value)];
	}
	else if ([cellType isEqualTo:@"platform"])
	{
		return [NSNumber numberWithUnsignedInt: [platformMenu indexOfItemWithTitle:MakeNSString(value)]];
	}

	// default is string
	return MakeNSString(value);
}


/* -----------------------------------------------------------------------------
	Optional method: needed to allow editing.
----------------------------------------------------------------------------- */

- (void) outlineView: (NSOutlineView *) inOutlineView setObjectValue: (id) inObject forTableColumn: (NSTableColumn *) inColumn byItem: (id) inItem
{
   if ([[inColumn identifier] isEqualTo:@"title"])
		return;

	RefVar value;

	NSString * cellType = [inItem objectForKey:@"type"];
	// make object for cell of that type
	if ([cellType isEqualTo:@"boolean"])
	{
		value = MAKEBOOLEAN([inObject unsignedIntValue] == 0);
	}
	else if ([cellType isEqualTo:@"part"])
	{
		value = MAKEINT([inObject unsignedIntValue]);
	}
	else if ([cellType isEqualTo:@"platform"])
	{
		value = MakeString([[platformMenu itemAtIndex:[inObject unsignedIntValue]] title]);
	}
	else
	{
		value = MakeString(inObject);
	}

	NSString * pathStr = [inItem objectForKey:@"path"];
	if (pathStr == nil)
		return;

	RefVar pathRef([self pathFor:pathStr]);
	SetFramePath(((NTXProjectDocument *)self.representedObject).projectRef, pathRef, value);
}


- (Ref) pathFor: (NSString *) inPath
{
	NSArray * pathParts = [inPath componentsSeparatedByString:@"."];
	NSUInteger pathCount = [pathParts count];
	RefVar pathExpr(MakeArray(pathCount));
	for (NSUInteger index = 0; index < pathCount; index++)
	{
		NSString * partPath = [pathParts objectAtIndex:index];
		SetArraySlot(pathExpr, index, MakeSymbol([partPath UTF8String]));
	}
	SetClass(pathExpr, SYMA(pathExpr));
	return pathExpr;
}

@end
