/*
	File:		NTXSettingsViewController.mm

	Abstract:	Implementation of NTXSettingsViewController class.

	Written by:		Newton Research, 2014.
*/

#import "ScriptViewController.h"
#import "NTXEditorView.h"

const CGFloat LargeNumberForText = 1.0e7; // Any larger dimensions and the text could become blurry.

@implementation NTXScriptViewController

/* Sets up a standard Cocoa text system, made up of a layout manager, text container, and text view, as well as the text storage given as an initialization parameter.
 */
- (id)initWithTextStorage:(NSTextStorage *)inStorage
{
	if (self = [super init])
	{
		_textStorage = inStorage;
		NSLayoutManager *layoutManager = [self layoutManagerForTextStorage:_textStorage];
		NSTextContainer *textContainer = [self textContainerForLayoutManager:layoutManager];
		_textView = [self textViewForTextContainer:textContainer]; // not retained, the text storage is owner of the whole system
	}
	return self;
}

/* No special action is taken, but subclasses can override this to configure the layout manager more specifically.
 */
- (NSLayoutManager *)layoutManagerForTextStorage:(NSTextStorage *)inStorage
{
	NSLayoutManager * __autoreleasing layoutManager = [[NSLayoutManager alloc] init];
	[inStorage addLayoutManager:layoutManager];
	return layoutManager;
}

/* The text container is created with very large dimensions so as not to impede the natural flow of the text by forcing it to wrap. The value of LargeNumberForText was not chosen arbitrarily; any larger and the text would begin to look blurry. It's a limitation of floating point numbers and goes all the way down to Postscript. No other special action is taken in setting up the text container, but subclasses can override this to configure it more specifically.
 */
- (NSTextContainer *)textContainerForLayoutManager:(NSLayoutManager *)layoutManager
{
	NSTextContainer * __autoreleasing textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:NO];
	[textContainer setHeightTracksTextView:NO];
	[layoutManager addTextContainer:textContainer];
	return textContainer;
}

/* Sets up a text view with reasonable initial settings. Subclasses can override this to configure it more specifically.
 */
- (NSTextView *)textViewForTextContainer:(NSTextContainer *)textContainer
{
	NSTextView * __autoreleasing view = [[NTXEditorView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100) textContainer:textContainer];

	[view setDelegate:(id<NSTextViewDelegate>)self];

	// Set up size attributes
	[view setHorizontallyResizable:YES];
	[view setVerticallyResizable:YES];
//	[view setAutoresizingMask:NSViewNotSizable];
	[view setTextContainerInset:NSMakeSize(0, 2)];

	// Set up editing attributes
	[view setSelectable:YES];
	[view setEditable:YES];
	[view setAllowsUndo:YES];

	// Set up rich text attributes
	[view setRichText:NO];
	[view setImportsGraphics:NO];
	[view setUsesFontPanel:NO];
	[view setUsesRuler:NO];
	[view setAutomaticQuoteSubstitutionEnabled:NO];

	[view setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	return view;
}

#pragma mark -

/* This is the view that will be added to the window. Subclasses might choose to make this a box or scroll view, for example.
 */
- (NSView *)containerView
{
	if (!scrollView)
	{
		NSTextView *documentView = self.textView;

		scrollView = [[NSScrollView alloc] initWithFrame:[documentView frame]];
		[scrollView setBorderType:NSBezelBorder];
		[scrollView setHasVerticalScroller:YES];
		[scrollView setHasHorizontalScroller:YES];
		[scrollView setAutohidesScrollers:YES];
//		[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

		[scrollView setDocumentView:documentView];
	}
	return scrollView;
}

- (NSTextStorage *)textStorage
{
	return _textStorage;
}

- (void)setTextStorage:(NSTextStorage *)newStorage
{
	if (_textStorage != newStorage)
	{
		[[self.textView layoutManager] replaceTextStorage:newStorage];
		_textStorage = newStorage;
	}
}


#pragma mark -

- (void) textViewDidChangeSelection:(NSNotification *)inNotification
{
	NSTextView * txView = [inNotification object];
	NSFont * txFont = [NSFont fontWithName:@"Menlo" size:11.0];
	[txView setFont:txFont];
}

@end
