/*
	File:		NTXEditorView.mm

	Contains:	The text editing view for NTX.

	Written by:	Newton Research Group, 2007.
*/

#import <Cocoa/Cocoa.h>
#import "NTXEditorView.h"
#import "PreferenceKeys.h"
#import "NTK/Funcs.h"


extern Ref * RSgVarFrame;

Ref
GetGlobalVar(RefArg inSym)
{	
	return GetFrameSlot(RA(gVarFrame),inSym);
}


/*------------------------------------------------------------------------------
	N T X E d i t o r V i e w
------------------------------------------------------------------------------*/

@implementation NTXEditorView

/*------------------------------------------------------------------------------
	When awoken, set up a NewtonSript context frame for this text view.
		ntxView := { _proto: protoEditor , viewCObject: self };
	All editing is done within the NewtonSript context.
------------------------------------------------------------------------------*/

- (void) awakeFromNib
{
	[super awakeFromNib];

	ntxView = AllocateFrame();
	SetFrameSlot(ntxView, SYMA(_proto), GetGlobalVar(SYMA(protoEditor)));
	SetFrameSlot(ntxView, SYMA(viewCObject), (Ref)self);
}

- (id) initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container
{
	if (self = [super initWithFrame:frameRect textContainer:container])
	{
		ntxView = AllocateFrame();
		SetFrameSlot(ntxView, SYMA(_proto), GetGlobalVar(SYMA(protoEditor)));
		SetFrameSlot(ntxView, SYMA(viewCObject), (Ref)self);
	}
	return self;
}


/*------------------------------------------------------------------------------
	When a key is pressed, check whether it is an editing key.
	If so, dispatch it to the NewtonScript editing context.
	Otherwise let Cocoa handle it as usual.
------------------------------------------------------------------------------*/
extern void REPExceptionNotify(Exception * inException);

- (void) keyDown: (NSEvent *) inEvent
{
	unsigned short code = [inEvent keyCode];
	NSString * str = [inEvent charactersIgnoringModifiers];
	UniChar ch;
	unsigned int modifiers = [inEvent modifierFlags];

	if (code == 36 && (modifiers & NSCommandKeyMask))
	{
		// Command-Return -- send code to tethered Newton for execution
		// get selected text
		NSString * str = [self string];
		NSRange selected = [self selectedRange];
		if (selected.length == 0)
			selected = [str lineRangeForRange: selected];	// no selection => select current line
		str = [str substringWithRange:selected];
		// make new line for result
		NSUInteger insertionPt = selected.location + selected.length;
		[self setSelectedRange: NSMakeRange(insertionPt, 0)];
		[self insertText: @"\n"];
		[self setSelectedRange: NSMakeRange(insertionPt+1, 0)];
		// post notification for NTK nub
		[[NSNotificationCenter defaultCenter] postNotificationName: kEvaluateNewtonScript
																			 object: str
																		  userInfo: nil];
		return;
	}

	RefVar keyState(AllocateFrame());
	RefVar keyCode;
	if (str != nil && (ch = [str characterAtIndex: 0], [[NSCharacterSet characterSetWithRange: NSMakeRange(0x21, 0x5E)] characterIsMember:ch]))
	{
		keyCode = MAKECHAR(ch);
	}
	else
	{
		keyCode = MAKEINT(code);
		if (modifiers & NSShiftKeyMask)
			SetFrameSlot(keyState, SYMA(shift), RA(TRUEREF));
	}

	if (modifiers & NSControlKeyMask)
		SetFrameSlot(keyState, SYMA(control), RA(TRUEREF));
	if (modifiers & NSAlternateKeyMask)
		SetFrameSlot(keyState, SYMA(option), RA(TRUEREF));
	if (modifiers & NSCommandKeyMask)
		SetFrameSlot(keyState, SYMA(command), RA(TRUEREF));
	if (Length(keyState) > 0)
	{
		SetFrameSlot(keyState, SYMA(key), keyCode);
		keyCode = keyState;
	}

	RefVar args(MakeArray(1));
	SetArraySlot(args, 0, keyCode);

	RefVar handler;
	newton_try
	{
		handler = DoMessage(ntxView, SYMA(GetKeyHandler), args);
		if (NOTNIL(handler))
		{
			NSRange selected = [self selectedRange];
			args = MakeArray(2);
			SetArraySlot(args, 0, MAKEINT(selected.location));
			SetArraySlot(args, 1, MAKEINT(selected.length));
			DoMessage(ntxView, handler, args);						// need to dispatch this to the newt? task -- certainly not the idle task

			[self scrollRangeToVisible: [self selectedRange]];
		}
	}
	newton_catch_all
	{
		REPExceptionNotify(CurrentException());
	}
	end_try;

	if (ISNIL(handler))
		[self interpretKeyEvents: [NSArray arrayWithObject: inEvent]];
}

@end

