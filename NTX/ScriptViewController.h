/*
	File:		NTXScriptViewController.h

	Abstract:	Interface for NTXScriptViewController class.

	Written by:		Newton Research, 2014.
*/

#import <Cocoa/Cocoa.h>

extern const CGFloat LargeNumberForText;

@interface NTXScriptViewController : NSViewController
{
	NSTextStorage * _textStorage;
}
@property(weak) NSTextStorage * textStorage;
@property IBOutlet NSTextView * textView;
@end
