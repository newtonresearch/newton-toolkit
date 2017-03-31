/*
	File:		NTXEditorView.mm

	Contains:	The text editing view for NTX.

	Written by:	Newton Research Group, 2007.
*/

#import <Cocoa/Cocoa.h>
#import "NTXEditorView.h"
#import "PreferenceKeys.h"
#import "NTK/Funcs.h"
#import "NTK/Globals.h"


/*------------------------------------------------------------------------------
	N T X E d i t o r V i e w
------------------------------------------------------------------------------*/

@implementation NTXEditorView

/*------------------------------------------------------------------------------
	When awoken, set up a NewtonSript context frame for this text view.
		ntxView := { _proto: protoEditor , viewCObject: self };
	All editing is done within the NewtonSript context.
------------------------------------------------------------------------------*/

- (void)awakeFromNib {
	[super awakeFromNib];
	[self initProtoEditor];
}

- (id)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container {
	if (self = [super initWithFrame:frameRect textContainer:container]) {
		[self initProtoEditor];
	}
	return self;
}

- (void)initProtoEditor {
	ntxView = AllocateFrame();
	SetFrameSlot(ntxView, SYMA(_proto), GetGlobalVar(SYMA(protoEditor)));
	SetFrameSlot(ntxView, SYMA(viewCObject), (Ref)self);
}


/*------------------------------------------------------------------------------
	When a key is pressed, check whether it is an editing key.
	If so, dispatch it to the NewtonScript editing context.
	Otherwise let Cocoa handle it as usual.
------------------------------------------------------------------------------*/
extern void REPExceptionNotify(Exception * inException);

- (void)keyDown:(NSEvent *)inEvent {
	unsigned short code = inEvent.keyCode;
	NSString * str = inEvent.charactersIgnoringModifiers;
	UniChar ch;
	unsigned int modifiers = inEvent.modifierFlags;

	if (code == 36 && (modifiers & NSEventModifierFlagCommand)) {
		// Command-Return -- send code to tethered Newton for execution
		// get selected text
		NSString * str = self.string;
		NSRange selected = self.selectedRange;
		if (selected.length == 0)
			selected = [str lineRangeForRange: selected];	// no selection => select current line
		str = [str substringWithRange:selected];
		// make new line for result
		NSUInteger insertionPt = selected.location + selected.length;
		[self insertText:@"\n" replacementRange:NSMakeRange(insertionPt, 0)];
		self.selectedRange = NSMakeRange(insertionPt+1, 0);
		// post notification for NTK nub
		[NSNotificationCenter.defaultCenter postNotificationName:kEvaluateNewtonScript
																		  object:str
																		userInfo:nil];
		return;
	}

	RefVar keyState(AllocateFrame());
	RefVar keyCode;
	if (str != nil && (ch = [str characterAtIndex:0], [[NSCharacterSet characterSetWithRange:NSMakeRange(0x21, 0x5E)] characterIsMember:ch])) {
		keyCode = MAKECHAR(ch);
	} else {
		keyCode = MAKEINT(code);
		if (modifiers & NSEventModifierFlagShift) {
			SetFrameSlot(keyState, SYMA(shift), RA(TRUEREF));
		}
	}

	if (modifiers & NSEventModifierFlagControl)
		SetFrameSlot(keyState, SYMA(control), RA(TRUEREF));
	if (modifiers & NSEventModifierFlagOption)
		SetFrameSlot(keyState, SYMA(option), RA(TRUEREF));
	if (modifiers & NSEventModifierFlagCommand)
		SetFrameSlot(keyState, SYMA(command), RA(TRUEREF));
	if (Length(keyState) > 0) {
		SetFrameSlot(keyState, SYMA(key), keyCode);
		keyCode = keyState;
	}

	RefVar args(MakeArray(1));
	SetArraySlot(args, 0, keyCode);

	RefVar handler;
	newton_try
	{
		handler = DoMessage(ntxView, SYMA(GetKeyHandler), args);
		if (NOTNIL(handler)) {
			NSRange selected = self.selectedRange;
			args = MakeArray(2);
			SetArraySlot(args, 0, MAKEINT(selected.location));
			SetArraySlot(args, 1, MAKEINT(selected.length));
			DoMessage(ntxView, handler, args);						// need to dispatch this to the newt? task -- certainly not the idle task

			[self scrollRangeToVisible:self.selectedRange];
		}
	}
	newton_catch_all
	{
		REPExceptionNotify(CurrentException());
	}
	end_try;

	if (ISNIL(handler)) {
		[self interpretKeyEvents: [NSArray arrayWithObject: inEvent]];
	}
}

@end


/* -----------------------------------------------------------------------------
	N T X P l a i n T e x t V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXPlainTextViewController

- (NSString *)fontName {
	return @"Menlo";
}

- (NSInteger)fontSize {
	return 11;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	// set up text attributes for inspector view
	NSFont * userTxFont = [NSFont fontWithName:@"Menlo" size:11.0];
	// calculate tab width
	NSFont * charWidthFont = [userTxFont screenFontWithRenderingMode:NSFontDefaultRenderingMode];
	NSInteger tabWidth = 3;	// [NSUserDefaults.standardUserDefaults integerForKey:@"TabWidth"];
	CGFloat charWidth = [@" " sizeWithAttributes:@{NSFontAttributeName:charWidthFont}].width;
	if (charWidth == 0)
		charWidth = charWidthFont.maximumAdvancement.width;
	// use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle * txStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
	txStyle.tabStops = @[ ];
	txStyle.defaultTabInterval = (charWidth * tabWidth);

	userTxAttrs = @{NSFontAttributeName:userTxFont, NSParagraphStyleAttributeName:txStyle.copy};
	textView.automaticQuoteSubstitutionEnabled = NO;
	textView.allowsUndo = YES;
}

@end
