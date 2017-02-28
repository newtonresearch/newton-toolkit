/*
	File:		NTXEditorView.h

	Contains:	NTXEditorView that despatches key input to NewtonScript handler.

	Written by:	Newton Research Group, 2007.
*/

#include "NewtonKit.h"

/* -----------------------------------------------------------------------------
	N T X E d i t o r V i e w
	A plain text view that accepts NewtonScript editing commands.
----------------------------------------------------------------------------- */

@interface NTXEditorView : NSTextView
{
	RefStruct ntxView;
}
@end

/* -----------------------------------------------------------------------------
	N T X P l a i n T e x t V i e w C o n t r o l l e r
	Controller for plain text view (ie not using NewtonScript editing commands).
----------------------------------------------------------------------------- */

@interface NTXPlainTextViewController : NSViewController
{
	IBOutlet NSTextView * textView;

	NSDictionary * userTxAttrs;
}
@property(readonly) NSString * fontName;
@property(readonly) NSInteger fontSize;
@end

