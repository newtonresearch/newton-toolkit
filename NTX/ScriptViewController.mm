/*
	File:		NTXScriptViewController.mm

	Abstract:	Implementation of NTXScriptViewController class.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
#import "ScriptViewController.h"
#import "NTXEditorView.h"

const CGFloat LargeNumberForText = 1.0e7; // Any larger dimensions and the text could become blurry.

@implementation NTXScriptViewController


- (void)viewDidLoad
{
	[super viewDidLoad];
	NTXScriptDocument * document = (NTXScriptDocument *)self.representedObject;
	self.textStorage = document.textStorage;
}


/* No special action is taken, but subclasses can override this to configure the layout manager more specifically.
 */
- (NSLayoutManager *)layoutManagerForTextStorage:(NSTextStorage *)inStorage
{
	NSLayoutManager * layoutManager = [[NSLayoutManager alloc] init];
	[inStorage addLayoutManager:layoutManager];
	return layoutManager;
}

/* The text container is created with very large dimensions so as not to impede the natural flow of the text by forcing it to wrap. The value of LargeNumberForText was not chosen arbitrarily; any larger and the text would begin to look blurry. It's a limitation of floating point numbers and goes all the way down to Postscript. No other special action is taken in setting up the text container, but subclasses can override this to configure it more specifically.
 */
- (NSTextContainer *)textContainerForLayoutManager:(NSLayoutManager *)layoutManager
{
	NSTextContainer * textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:NO];
	[textContainer setHeightTracksTextView:NO];
	[layoutManager addTextContainer:textContainer];
	return textContainer;
}


- (NSTextStorage *)textStorage
{
	return _textStorage;
}

- (void)setTextStorage:(NSTextStorage *)newStorage
{
	if (_textStorage != newStorage)
	{
		[self.textView.layoutManager replaceTextStorage:newStorage];
		_textStorage = newStorage;
	}
}


#pragma mark -

- (void)textViewDidChangeSelection:(NSNotification *)inNotification
{
	NSTextView * txView = [inNotification object];
	NSFont * txFont = [NSFont fontWithName:@"Menlo" size:11.0];
	[txView setFont:txFont];
}

@end
