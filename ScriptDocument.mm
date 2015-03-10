/*
	File:		ScriptDocument.mm

	Abstract:	An NTXScriptDocument uses NSTextStorage for persistent text storage
					and displays itself in the main project window using an NTXEditorView:NSTextView
					controlled by an NTXScriptViewController.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
#import "NewtonKit.h"
#import "ScriptViewController.h"

extern Ref		ParseFile(const char * inFilename);


/* -----------------------------------------------------------------------------
	N T X S c r i p t D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXScriptDocument


/* -----------------------------------------------------------------------------
	Initialize.
----------------------------------------------------------------------------- */

- (id) init
{
	if (self = [super init])
	{
		textStorage = nil;
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Read NewtonScript text from disk.
	NSTextView * txView = viewController.targetView; -- how do we put textStorage into this?
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	[[self undoManager] disableUndoRegistration];

	NSDictionary * docAttrs = nil;

	// set font
	NSFont * txFont = [NSFont fontWithName:@"Menlo" size:11.0];
	// calculate tab width
	NSFont * charWidthFont = [txFont screenFontWithRenderingMode:NSFontDefaultRenderingMode];
	NSInteger tabWidth = 3;	// [[NSUserDefaults standardUserDefaults] integerForKey:TabWidth];
	CGFloat charWidth = [@" " sizeWithAttributes:[NSDictionary dictionaryWithObject:charWidthFont forKey:NSFontAttributeName]].width;
	if (charWidth == 0)
		charWidth = [charWidthFont maximumAdvancement].width;
	// use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle * txStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[txStyle setTabStops:[NSArray array]];
	[txStyle setDefaultTabInterval:(charWidth * tabWidth)];

	NSDictionary * userTxAttrs = [NSDictionary dictionaryWithObjectsAndKeys:	txFont, NSFontAttributeName,
																										[txStyle copy], NSParagraphStyleAttributeName,
																										nil];

	NSError * __autoreleasing error = nil;
	if (textStorage == nil)
	{
		NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:	NSPlainTextDocumentType, NSDocumentTypeDocumentOption,
																									userTxAttrs, NSDefaultAttributesDocumentOption,
																									nil];
		textStorage = [[NSTextStorage alloc] initWithURL:url options:options documentAttributes:NULL error:&error];
	}
	else
	{
		NSString * newContents = [[NSString alloc] initWithContentsOfURL:url usedEncoding:NULL error:&error];
		if (newContents)
		{

			[[textStorage mutableString] setString:newContents];
			[textStorage addAttributes:userTxAttrs range:NSMakeRange(0, [newContents length])];
		}
	}

	[[self undoManager] enableUndoRegistration];
	return error == NULL;
}


/* -----------------------------------------------------------------------------
	Write NewtonScript text to disk.
----------------------------------------------------------------------------- */

- (BOOL) writeToURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	[[textStorage string] writeToURL:url atomically:NO encoding:NSUTF8StringEncoding error:outError];
}


+ (BOOL)autosavesInPlace
{
    return YES;
}


/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	self.viewController = [[NTXScriptViewController alloc] initWithTextStorage:textStorage];
}


/* -----------------------------------------------------------------------------
	Evaluate our NewtonScript.
----------------------------------------------------------------------------- */

- (int) evaluate
{
	NSError * __autoreleasing err = nil;
	[self writeToURL:[self fileURL] ofType:@"com.newton.script" error:&err];

	ParseFile([[self fileURL] fileSystemRepresentation]);
	return noErr;
}


/* -----------------------------------------------------------------------------
	Export our NewtonScript.
	Text files are output verbatim, bracketed by:
	// Beginning of text file <fileName>
	// End of text file <fileName>
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NSError * __autoreleasing err;
	NSString * filename = [[self fileURL] lastPathComponent];
	NSString * body = [NSString stringWithContentsOfURL:[self fileURL] encoding:NSUTF8StringEncoding error:&err];
	return [NSString stringWithFormat:	@"// Beginning of text file %@\n"
													@"%@\n"
													@"// End of text file %@\n\n", filename, body, filename];
}

@end
