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
#import "DockErrors.h"

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

@interface NTXProjectWindowController ()
{
	BOOL _isConnected;
}
@end

@implementation NTXProjectWindowController
@synthesize connectionIcon;
@synthesize progress;
@synthesize progressText;

/* -----------------------------------------------------------------------------
	Initialize after nib has been loaded.
----------------------------------------------------------------------------- */

- (void) windowDidLoad {
	[super windowDidLoad];

	// show toolbar items in title area
	self.window.titleVisibility = NSWindowTitleHidden;
	self.shouldCascadeWindows = NO;
	_isConnected = NO;
	self.connectionIcon = [NSImage imageNamed:@"Disconnected"];

	self.progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];

	// start listening for notifications re: becoming key window
	[[NSNotificationCenter defaultCenter] addObserver:self
														  selector:@selector(windowDidBecomeKey:)
																name:NSWindowDidBecomeKeyNotification
															 object:nil];

	// when the window closes, undo those hooks
	[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(windowWillClose:)
															  name:NSWindowWillCloseNotification
															object:self.window];


	// defer population until window has fully loaded
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.sourceListController populateSourceList];
	});
}

- (void)setDocument:(id)inDocument {
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

// save all documents represented in the project
- (IBAction)saveAllDocuments:(id)sender {
	[self.document saveAllProjectItems:sender];
}

#pragma mark Item View
/* -----------------------------------------------------------------------------
	The user selected a source document.
	Change the information subview.
----------------------------------------------------------------------------- */

- (void)sourceSelectionDidChange:(NTXProjectItem *)item {
	self.sourceInfoController.representedObject = item;
	if (item) {
		NTXDocument * chosenDoc = item.document;
		if (chosenDoc) {
			[self.contentController performSegueWithIdentifier:chosenDoc.storyboardName sender:chosenDoc];
			// hook up doc.undoManager = view.undoManager
//			NSView * txView = inDocument.viewController.view;
//			if ([txView isKindOfClass:NSTextView.class]) {
//				NSUndoManager * um = inDocument.undoManager;
//				um = txView.undoManager;
//				if (inDocument.undoManager != txView.undoManager) {
//					inDocument.undoManager = txView.undoManager;
//				}
//			}
		}
	}
}


/* -----------------------------------------------------------------------------
	Update the progress box when changes to the document’s progress are observed.
----------------------------------------------------------------------------- */

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == ProgressObserverContext) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			NSProgress * progres = object;
//			progressBox.barValue = progres.fractionCompleted;
			progressBox.statusText = progres.localizedDescription;
			progressBox.needsDisplay = YES;
	  }];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


/* -----------------------------------------------------------------------------
	The NTK nub status changed: probably disconnected.
----------------------------------------------------------------------------- */

- (void)nubStatusDidChange:(NSNotification *)inNotification {
	NSNumber * err = inNotification.userInfo[@"error"];
	if (err.intValue == kDockErrDisconnected) {
		self.connected = NO;
		if (NSApp.keyWindow == self.window) {
			[NTXToolkitProtocolController bind:self];		// we want the frontmost window to bind; not necessarily this one
		}
	}
}


/* -----------------------------------------------------------------------------
	If we become frontmost then request ownership of the nub.
----------------------------------------------------------------------------- */

- (void)windowDidBecomeKey:(NSNotification *)inNotification {
	if (inNotification.object == self.window) {
		[NTXToolkitProtocolController bind:self];
	}
}


/* -----------------------------------------------------------------------------
	Remove dependents when the window is about to close.
----------------------------------------------------------------------------- */

- (void)windowWillClose:(NSNotification *)inNotification {
	[NTXToolkitProtocolController unbind:self];
	// update our frame in the document
	NTXProjectDocument * theDocument = self.document;
	//theDocument.windowFrame = self.window.frame;
	// also split positions
	// stop listening for notifications
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(localizedDescription)) context:ProgressObserverContext];
}


/* -----------------------------------------------------------------------------
	Respond to TellUser() from NewtonScript.
----------------------------------------------------------------------------- */

- (void)tellUser:(NSString *)inStr {
	self.inspectorSplitController.tellUserText = inStr;
}


/* -----------------------------------------------------------------------------
	Un|collapse a split view.
----------------------------------------------------------------------------- */

- (IBAction)toggleCollapsed:(id)sender {
	NSInteger item = ((NSSegmentedControl *)sender).selectedSegment;
	if (item == 0) {
		[self.sourceSplitController toggleSourceList:sender];
	} else if (item == 1) {
		[self.inspectorSplitController toggleInspector:sender];
	} else if (item == 2) {
		[self.sourceSplitController toggleSourceInfo:sender];
	}
}


#pragma mark NTXNubFeedback protocol
/* -----------------------------------------------------------------------------
	NTXNubFeedback protocol.
----------------------------------------------------------------------------- */

- (void)setConnected:(BOOL)inConnected {
	_isConnected = inConnected;
	self.connectionIcon = [NSImage imageNamed:inConnected?@"Connected":@"Disconnected"];
	if (!inConnected) {
		[NTXToolkitProtocolController unbind:self];
	}
}

- (BOOL)isConnected {
	return _isConnected;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingIsConnected {
	return [NSSet setWithObject:@"connected"];
}

- (void)receivedText:(NSString *)inText {
	printf("%s\n", inText.UTF8String);
}


- (void)receivedObject:(RefArg)inObject {
	PrintObject(inObject, 0);
	printf("\n");
}


- (void)receivedScreenshot:(RefArg)inData {
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
