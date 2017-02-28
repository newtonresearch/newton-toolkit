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
@interface NTXScriptDocument ()
{
	NSTextStorage * _textStorage;
}
@end


@implementation NTXScriptDocument


/* -----------------------------------------------------------------------------
	Initialize.
----------------------------------------------------------------------------- */

- (id)init
{
	if (self = [super init]) {
		_textStorage = nil;
	}
	return self;
}


- (NSString *)storyboardName
{ return @"Script"; }


/* -----------------------------------------------------------------------------
	Read NewtonScript text from disk.
	NSTextView * txView = viewController.targetView; -- how do we put textStorage into this?
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
	[self.undoManager disableUndoRegistration];

	NSDictionary * docAttrs = nil;

	// set font
	NSFont * txFont = [NSFont fontWithName:@"Menlo" size:11.0];
	// calculate tab width
	NSFont * charWidthFont = [txFont screenFontWithRenderingMode:NSFontDefaultRenderingMode];
	NSInteger tabWidth = 3;	// [NSUserDefaults.standardUserDefaults integerForKey:@"TabWidth"];
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
	if (_textStorage == nil) {
		NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:	NSPlainTextDocumentType, NSDocumentTypeDocumentOption,
																									userTxAttrs, NSDefaultAttributesDocumentOption,
																									nil];
		_textStorage = [[NSTextStorage alloc] initWithURL:url options:options documentAttributes:NULL error:&error];
	} else {
		NSString * newContents = [[NSString alloc] initWithContentsOfURL:url usedEncoding:NULL error:&error];
		if (newContents) {

			[_textStorage.mutableString setString:newContents];
			[_textStorage addAttributes:userTxAttrs range:NSMakeRange(0, newContents.length)];
		}
	}

	[self.undoManager enableUndoRegistration];
	return error == NULL;
}


/* -----------------------------------------------------------------------------
	Write NewtonScript text to disk.
----------------------------------------------------------------------------- */

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	[_textStorage.string writeToURL:url atomically:NO encoding:NSUTF8StringEncoding error:outError];
}


+ (BOOL)autosavesInPlace
{
    return YES;
}


/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void)makeWindowControllers
{
//	self.viewController = [[NTXScriptViewController alloc] initWithTextStorage:_textStorage];
}


/* -----------------------------------------------------------------------------
	Evaluate our NewtonScript.
----------------------------------------------------------------------------- */

- (int)evaluate
{
//	always save before building -- there must be a better way to do this generically
	NSError * __autoreleasing err = nil;
	[self writeToURL:self.fileURL ofType:@"com.newton.script" error:&err];

	ParseFile(self.fileURL.fileSystemRepresentation);
	return noErr;
}


/* -----------------------------------------------------------------------------
	Export our NewtonScript.
	Text files are output verbatim, bracketed by:
	// Beginning of text file <fileName>
	// End of text file <fileName>
----------------------------------------------------------------------------- */

- (void)exportToText:(FILE *)fp error:(NSError * __autoreleasing *)outError
{
	const char * filename = self.fileURL.lastPathComponent.UTF8String;
	const char * sym = self.symbol.UTF8String;
	fprintf(fp, "// Beginning of text file %s\n", filename);

	// copy file
	char buf[BUFSIZ];
	size_t size;
	FILE * source = fopen(self.fileURL.fileSystemRepresentation, "rb");
	while ((size = fread(buf, 1, BUFSIZ, source)) != 0) {
		fwrite(buf, 1, size, fp);
	}
	fclose(source);

	fprintf(fp, "// End of text file %s\n\n", filename);
}

@end
