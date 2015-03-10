/*
	File:		NTXDocument.mm

	Abstract:	An NTXDocument displays itself in the main project window using a view controller.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
#import "NewtonKit.h"


/* -----------------------------------------------------------------------------
	N T X D o c u m e n t
----------------------------------------------------------------------------- */

@implementation NTXDocument

/* -----------------------------------------------------------------------------
	Base class stubs.
----------------------------------------------------------------------------- */

- (int) evaluate
{ return -1; }

- (NSString *) exportToText
{ return nil; }

@end



/* -----------------------------------------------------------------------------
	N T X L a y o u t D o c u m e n t
----------------------------------------------------------------------------- */

@implementation NTXLayoutDocument

/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	NTXIconViewController * ourController = [[NTXIconViewController alloc] initWithNibName: @"IconView" bundle: nil];
	[ourController loadView];
	ourController.image = [NSImage imageNamed:@"layout"];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Read layout NSOF from disk.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError * __autoreleasing *) outError
{
	return YES;
}


+ (BOOL)autosavesInPlace
{
    return NO;
}


/* -----------------------------------------------------------------------------
	Evaluate our layout.
----------------------------------------------------------------------------- */

- (int) evaluate
{
// create constant |layout_<filename>| := <viewref>;
	return noErr;
}


/* -----------------------------------------------------------------------------
	Export our layout.
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NSString * filename = [[self fileURL] lastPathComponent];
	NSString * body = @"<viewRef>";	// need to expand this!
	return [NSString stringWithFormat:@"constant |layout_%@| := %@\n", filename, body];
}

@end


/* -----------------------------------------------------------------------------
	N T X N a t i v e C o d e D o c u m e n t
----------------------------------------------------------------------------- */

@implementation NTXNativeCodeDocument

/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	NTXIconViewController * ourController = [[NTXIconViewController alloc] initWithNibName: @"IconView" bundle: nil];
	[ourController loadView];
	ourController.image = [NSImage imageNamed:@"nativecode"];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Read native code module from disk.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	return YES;
}


+ (BOOL)autosavesInPlace
{
    return NO;
}


/* -----------------------------------------------------------------------------
	Evaluate our native code module.
----------------------------------------------------------------------------- */

- (int) evaluate
{
// DefConst('<filename>, <frameOfCodeFile>);
	return noErr;
}


/* -----------------------------------------------------------------------------
	Export our native code module, like so.
		DefConst('<filename>, <frameOfCodeFile>);
	For some reason this is commented out.
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NSString * filename = [[self fileURL] lastPathComponent];
	NSString * body = @"<frameOfCodeFile>";	// need to unflatten this
	return [NSString stringWithFormat:@"DefConst('|%@|, %@)\n", filename, body];
}

@end

