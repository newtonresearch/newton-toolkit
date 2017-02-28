/*
	File:		InspectorViewController.mm

	Abstract:	Implementation of InspectorViewController subclasses.

	Written by:		Newton Research, 2015.
*/

#import "ProjectWindowController.h"
#import "InspectorViewController.h"
#import "NTXEditorView.h"
#import "stdioDirector.h"
#import "Utilities.h"


/* -----------------------------------------------------------------------------
	N T X I n s p e c t o r S p l i t V i e w C o n t r o l l e r
	We want to be able to (un)collapse the inspector view.
----------------------------------------------------------------------------- */
@interface NTXInspectorSplitViewController ()
{
	NSString * _tellUserText;
}
@end

@implementation NTXInspectorSplitViewController

- (void)viewDidLoad {
	NTXProjectWindowController * wc = self.view.window.windowController;
	wc.inspectorSplitController = self;
	[super viewDidLoad];
}

- (void)setTellUserText:(NSString *)inStr {
	_tellUserText = inStr;
	self.splitView.needsDisplay = YES;
}

- (NSString *)tellUserText {
	return _tellUserText;
}

- (void)toggleCollapsed {
	inspectorItem.animator.collapsed = !inspectorItem.isCollapsed;
}

@end


#pragma mark NTXSplitView
/* -----------------------------------------------------------------------------
	N T X S p l i t V i e w
	The vertical split view containing the content and inspector text.
	We want the divider to be thick enough to display the TellUser() text.
----------------------------------------------------------------------------- */
@implementation NTXSplitView

- (CGFloat)dividerThickness {
	return 20.0;
}

- (void)drawDividerInRect:(NSRect)inRect {
	NSString * txt = ((NTXInspectorSplitViewController *)self.delegate).tellUserText;
	if (txt && txt.length > 0) {
		NSRect box = NSInsetRect(inRect, 10.0, 0.0);
		box.origin.y += 13.0;
		[self lockFocus];
		[txt drawWithRect:box options:0 attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:NSFont.smallSystemFontSize],
																	NSForegroundColorAttributeName:NSColor.blackColor}];
		[self unlockFocus];
	}
}

@end


/* -----------------------------------------------------------------------------
	I n s p e c t o r V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */
@interface NTXInspectorViewController ()
{
	NSDictionary * newtonTxAttrs;
	NSDictionary * userTxAttrs;
	NTXOutputRedirect * redirector;
}
@end

@implementation NTXInspectorViewController

/* -----------------------------------------------------------------------------
	Set up text appearance.
----------------------------------------------------------------------------- */

- (void)viewDidLoad {
	[super viewDidLoad];

	// set up text attributes for inspector view
	NSFont * userTxFont = [NSFont fontWithName:@"Menlo" size:11.0];
	NSFont * newtonTxFont = [NSFont fontWithName:@"Menlo-Bold" size:11.0];
	// calculate tab width
	NSFont * charWidthFont = [userTxFont screenFontWithRenderingMode:NSFontDefaultRenderingMode];
	NSInteger tabWidth = 3;	// [NSUserDefaults.standardUserDefaults integerForKey:@"TabWidth"];
	CGFloat charWidth = [@" " sizeWithAttributes:@{NSFontAttributeName:charWidthFont}].width;
	if (charWidth == 0)
		charWidth = charWidthFont.maximumAdvancement.width;
	// use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle * txStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
	txStyle.tabStops = @[ ];
	txStyle.defaultTabInterval = charWidth * tabWidth;

	newtonTxAttrs = @{ NSFontAttributeName:newtonTxFont, NSParagraphStyleAttributeName:txStyle.copy };
	userTxAttrs = @{ NSFontAttributeName:userTxFont, NSParagraphStyleAttributeName:txStyle.copy };

	inspectorView.automaticQuoteSubstitutionEnabled = NO;
	inspectorView.allowsUndo = YES;
}


/* -----------------------------------------------------------------------------
	Redirect Newton REP output here when the view is about to open.
----------------------------------------------------------------------------- */

- (void)viewWillAppear {
	[super viewWillAppear];
	NSURL * itu = self.inspectorTextURL;
	if (itu) {
		[self loadText:itu];
	}

#if 1		// don’t redirect if you want an easy debug life
	// redirect stdout to us
	redirector = [NTXOutputRedirect redirect_stdout];
	[redirector setListener:self];
#endif
}


/* -----------------------------------------------------------------------------
	Undo hooks when the view is about to close.
----------------------------------------------------------------------------- */

- (void)viewWillDisappear {
	// save inspector text
	NSURL * itu = self.inspectorTextURL;
	if (itu) {
		[self saveText:itu];
	}

	// restore stdout
	[redirector setListener:nil];
}


/* -----------------------------------------------------------------------------
	Return URL of per-project persistent inspector text file.
----------------------------------------------------------------------------- */

- (NSURL *)inspectorTextURL {
	NSDocument * doc = [self.view.window.windowController document];
	NSURL * projectURL = doc.fileURL;
	if (projectURL) {
		return ApplicationSupportFile([NSString stringWithFormat:@"%@-Inspector.text", projectURL.URLByDeletingPathExtension.lastPathComponent]);
	}
	return nil;
}


/* -----------------------------------------------------------------------------
	Load text into the inspector.
----------------------------------------------------------------------------- */

- (void)loadText:(NSURL *)inURL {

	[inspectorView setTextContainerInset:NSMakeSize(4.0, 4.0)];

	NSError *__autoreleasing err = nil;
	NSString * txStr = [NSString stringWithContentsOfURL:inURL encoding:NSUTF8StringEncoding error: &err];
	if (txStr == nil) {
		txStr = [NSString stringWithUTF8String:""];
	}
	NSAttributedString * attrStr = [[NSAttributedString alloc] initWithString:txStr attributes:userTxAttrs];
	[inspectorView.textStorage setAttributedString:attrStr];
}


/* -----------------------------------------------------------------------------
	Save inspector text.
----------------------------------------------------------------------------- */

- (void)saveText:(NSURL *)inURL {
	NSError *__autoreleasing err = nil;
	[inspectorView.textStorage.string writeToURL:inURL atomically:NO encoding:NSUTF8StringEncoding error:&err];
}


/* -----------------------------------------------------------------------------
	Insert text into the inspector text view.
----------------------------------------------------------------------------- */

- (void)insertText:(NSString *)inText {
	if (inText) {
		NSAttributedString * str = [[NSAttributedString alloc] initWithString:inText attributes:newtonTxAttrs];
		[inspectorView.textStorage insertAttributedString:str atIndex:inspectorView.selectedRange.location];
	}
}


/* -----------------------------------------------------------------------------
	ALWAYS use our text attributes.
----------------------------------------------------------------------------- */

- (void)textViewDidChangeSelection:(NSNotification *)inNotification {
	[inNotification.object setTypingAttributes:userTxAttrs];
}


@end
