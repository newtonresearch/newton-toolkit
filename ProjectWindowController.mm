/*
	File:		ProjectWindowController.mm

	Abstract:	Implementation of NTXWindowController class.

	Written by:		Newton Research, 2014.
*/

#import "AppDelegate.h"
#import "ProjectWindowController.h"
#import "ContentViewController.h"
#import "ProjectItem.h"
#import "ProjectDocument.h"
#import "NTXDocument.h"
#import "NTXEditorView.h"
#import "Utilities.h"

extern NSString *	MakeNSString(RefArg inStr);
extern void			InitDrawing(CGContextRef inContext, int inScreenHeight);
extern void			DrawBits(const char * inBits, unsigned inHeight, unsigned inWidth, unsigned inRowBytes, unsigned inDepth);


#pragma mark - NTXProjectWindowController
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

@implementation NTXProjectWindowController

/* -----------------------------------------------------------------------------
	Initialize after nib has been loaded.
----------------------------------------------------------------------------- */

- (void) windowDidLoad
{
	[super windowDidLoad];

	// show toolbar items in title area
	self.window.titleVisibility = NSWindowTitleHidden;
	self.shouldCascadeWindows = NO;
	_connectionIcon = [NSImage imageNamed:@"disconnection"];

	self.progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];

	// start listening for notifications re: dis|connection
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(nubConnectionDidChange:)
																name:kNubConnectionDidChangeNotification
															 object:nil];

	// start listening for notifications re: change of nub ownership
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(nubOwnerDidChange:)
																name:kNubOwnerDidChangeNotification
															 object:nil];

	// start listening for notifications re: becoming key window
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(windowDidBecomeKey:)
																name:NSWindowDidBecomeKeyNotification
															 object:nil];

	// when the window closes, undo those hooks
	[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(windowWillClose:)
															  name:NSWindowWillCloseNotification
															object:[self window]];
}

- (void)setDocument:(id)inDocument
{
	[super setDocument:inDocument];

	NTXProjectDocument * theDocument = inDocument;
	NSURL * projectURL = theDocument.fileURL;
	if (projectURL)
		self.windowFrameAutosaveName = projectURL.lastPathComponent;
	// update our frame from the document
	//[self.window.setFrame: theDocument.windowFrame];

	// observe changes to our progress so we can update the progress box
	[self.progress addObserver:self
				  forKeyPath:@"localizedDescription"
					  options:NSKeyValueObservingOptionInitial
					  context:ProgressObserverContext];
	self.progress.localizedDescription = @"Welcome to NewtonScript!";

}


/* -----------------------------------------------------------------------------
	Show the document currently selected in the source list.
	Args:		inDocument
	Return:	--
----------------------------------------------------------------------------- */

- (void)editDocument:(NTXDocument *)inDocument
{
	if (inDocument) {
		[self.contentController show:inDocument.viewController];
		// hook up doc.undoManager = view.undoManager

		NSView * txView = inDocument.viewController.view;
		if ([txView isKindOfClass:NSTextView.class]) {
			NSUndoManager * um = inDocument.undoManager;
			um = txView.undoManager;
			if (inDocument.undoManager != txView.undoManager) {
				inDocument.undoManager = txView.undoManager;
			}
		}

	}
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
			progressBox.statusText = progress.localizedDescription;
			progressBox.needsDisplay = YES;
	  }];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


/* -----------------------------------------------------------------------------
	The toolkit protocol controller dis|connected.
	If connected and we are frontmost then request ownership of the nub
	else we do not own the nub.
----------------------------------------------------------------------------- */

- (void)nubConnectionDidChange:(NSNotification *)inNotification
{
	NSDictionary * info = inNotification.userInfo;
	if (info != nil && self == [NSApp keyWindow].windowController) {
		NTXToolkitProtocolController * sender = info[@"nub"];
		[sender requestOwnership:self];
	} else {
		_ntkNub = nil;
		_connectionIcon = [NSImage imageNamed:@"disconnection"];
	}
}


/* -----------------------------------------------------------------------------
	The toolkit protocol controller changed owner.
	If we are the requester then we own the nub (else we don’t).
----------------------------------------------------------------------------- */

- (void)nubOwnerDidChange:(NSNotification *)inNotification
{
	NSDictionary * info = inNotification.userInfo;
	if (info[@"owner"] == self) {
		_ntkNub = info[@"nub"];
		_connectionIcon = [NSImage imageNamed:@"connection"];
	} else {
		_ntkNub = nil;
		_connectionIcon = [NSImage imageNamed:@"disconnection"];
	}
}


/* -----------------------------------------------------------------------------
	If we become frontmost then request ownership of the nub.
----------------------------------------------------------------------------- */

- (void)windowDidBecomeKey:(NSNotification *)inNotification
{
	if (inNotification.object == self.window)
		[((NTXController *)[NSApp delegate]).ntkNub requestOwnership:self];
}


/* -----------------------------------------------------------------------------
	Remove dependents when the window is about to close.
----------------------------------------------------------------------------- */

- (void)windowWillClose:(NSNotification *)inNotification
{
	// update our frame in the document
	NTXProjectDocument * theDocument = self.document;
	//theDocument.windowFrame = self.window.frame;
	// also split positions
	// stop listening for notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(localizedDescription)) context:ProgressObserverContext];
}


/* -----------------------------------------------------------------------------
	Respond to TellUser() from NewtonScript.
----------------------------------------------------------------------------- */

- (void) tellUser: (NSString *) inStr
{
	self.inspectorSplitController.tellUserText = inStr;
}


/* -----------------------------------------------------------------------------
	Un|collapse a split view.
----------------------------------------------------------------------------- */

- (IBAction)toggleCollapsed:(id)sender
{
	NSInteger item = ((NSSegmentedControl *)sender).selectedSegment;
	if (item == 1) {
		[self.inspectorSplitController toggleCollapsed];
	} else {
		[self.sourceSplitController toggleCollapsed];
	}
}


#pragma mark NTXNubFeedback protocol
/* -----------------------------------------------------------------------------
	NTXNubFeedback protocol.
----------------------------------------------------------------------------- */

- (void)receivedText:(NSString *)inText
{
	printf("%s\n", inText.UTF8String);
}

- (void)receivedObject:(RefArg)inObject
{
	PrintObject(inObject, 0);
	printf("\n");
}

- (void)receivedScreenshot:(RefArg)inData
{
	// render PixMap into NSImage
	NSImage * theImage = nil;
	newton_try
	{
		if (IsFrame(inData)) {
			int shotHeight = RVALUE(GetFrameSlot(inData, SYMA(bottom))) - RVALUE(GetFrameSlot(inData, SYMA(top)));
			int shotWidth = RVALUE(GetFrameSlot(inData, SYMA(right))) - RVALUE(GetFrameSlot(inData, SYMA(left)));
			NSSize shotSize = NSMakeSize(shotWidth, shotHeight);

		// render PixelMap into NSImage
			theImage = [[NSImage alloc] initWithSize:shotSize];
			[theImage lockFocus];

			InitDrawing((CGContextRef) NSGraphicsContext.currentContext.graphicsPort, shotHeight);
			DrawBits(BinaryData(GetFrameSlot(inData, MakeSymbol("theBits"))), shotHeight, shotWidth,
						RINT(GetFrameSlot(inData, MakeSymbol("rowBytes"))), RINT(GetFrameSlot(inData, MakeSymbol("depth"))));

			[theImage unlockFocus];
		}
	}
	newton_catch_all
	{
		theImage = nil;
	}
	end_try;

	// ask the app delegate to show it
	[[NSApp delegate] performSelector:@selector(showScreenshot:) withObject:theImage];
}

@end
