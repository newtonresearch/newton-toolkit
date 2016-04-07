/*
	File:		NTXScriptViewController.h

	Abstract:	Interface for NTXScriptViewController class.

	Written by:		Newton Research, 2014.
*/

#import <Cocoa/Cocoa.h>
#import "EditorViewController.h"

extern const CGFloat LargeNumberForText;

@interface NTXScriptViewController : NTXEditorViewController
{
	NSTextStorage * _textStorage;
	NSScrollView * scrollView;
}
@property(weak) NSTextStorage * textStorage;
@property(readonly) NSTextView * textView;

- (id)initWithTextStorage:(NSTextStorage *)textStorage;

- (NSLayoutManager *)layoutManagerForTextStorage:(NSTextStorage *)givenStorage;
- (NSTextContainer *)textContainerForLayoutManager:(NSLayoutManager *)layoutManager;
- (NSTextView *)textViewForTextContainer:(NSTextContainer *)textContainer;

@end
