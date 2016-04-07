/*
	File:		NTXDocument.mm

	Abstract:	An NTXDocument displays itself in the main project window using a view controller.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
#import "NewtonKit.h"
#import "Utilities.h"
#import "NTK/Funcs.h"

extern void DefConst(const char * inSym, RefArg inVal);


extern NSNumberFormatter * gNumberFormatter;
extern NSDateFormatter * gDateFormatter;

#define kSecondsSince1904 2082844800


/*------------------------------------------------------------------------------
	Make a NextStep string from a NewtonScript symbol.
	Args:		inStr			a NewtonScript symbol
	Return:	an NSString
------------------------------------------------------------------------------*/

NSString *
MakeNSSymbol(RefArg inSym)
{
	if (IsSymbol(inSym))
		return [NSString stringWithCString:SymbolName(inSym) encoding:NSMacOSRomanStringEncoding];
	return nil;
}


/*------------------------------------------------------------------------------
	Make a NextStep string from a NewtonScript object.
	Args:		inRef			a NewtonScript Ref object
	Return:	an NSString
------------------------------------------------------------------------------*/
extern void	RedirectStdioOutTranslator(FILE * inFRef);

NSString *
PrintObject(RefArg inRef)
{
	NewtonErr err = noErr;
	NSString * txt = nil;
	newton_try
	{
		// print into temporary file
		NSURL * docURL = ApplicationSupportFile(@"tmp.txt");
		NSString * path = docURL.path;
		NSDictionary * fileAttrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSFileExtensionHidden];
		[NSFileManager.defaultManager createFileAtPath:path contents:[NSData data] attributes:fileAttrs];

		FILE * newtout = fopen(path.fileSystemRepresentation, "w");
		if (newtout)
		{
			RedirectStdioOutTranslator(newtout);
			int savedPrintDepth = RVALUE(GetFrameSlot(RA(gVarFrame), SYMA(printDepth)));
			SetFrameSlot(RA(gVarFrame), SYMA(printDepth), MAKEINT(1));
			newton_try
			{
				REPprintf("\n");
				PrintObject(inRef, 0);
			}
			newton_catch_all
			{
				REPprintf("\n*** Error printing object (%d). ***\n", CurrentException()->data);
			}
			end_try;
			REPprintf("\n\n");
			SetFrameSlot(RA(gVarFrame), SYMA(printDepth), MAKEINT(savedPrintDepth));
			fclose(newtout);
			RedirectStdioOutTranslator(NULL);
		}

		// create string with contents of that file
		NSError *__autoreleasing err = nil;
		txt = [NSString stringWithContentsOfFile:path encoding:NSMacOSRomanStringEncoding error:&err];
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
		txt = @"Not a stream file!";
	}
	end_try;

	return txt;
}


/* -----------------------------------------------------------------------------
	N T X D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXDocument

/* -----------------------------------------------------------------------------
	Base class stubs.
----------------------------------------------------------------------------- */

- (int)evaluate
{ return -1; }

- (NSString *)exportToText
{ return nil; }

- (NSString *)symbol
{ return self.fileURL.URLByDeletingPathExtension.lastPathComponent; }

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X L a y o u t D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXLayoutDocument

- (NSString *)symbol
{
	return [NSString stringWithFormat:@"layout_%@", super.symbol];
}


/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	NTXIconViewController * ourController = [[NTXIconViewController alloc] initWithNibName: nil bundle: nil];
	ourController.representedObject = self;
	[ourController loadView];
	ourController.image = [NSImage imageNamed:@"layout"];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Read layout NSOF from disk.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError * __autoreleasing *) outError
{
	return YES;
}


/* -----------------------------------------------------------------------------
	Compile our layout.
----------------------------------------------------------------------------- */

- (int) evaluate
{
	DefConst(self.symbol.UTF8String, RA(NILREF));	// need to expand this!
	return noErr;
}


/* -----------------------------------------------------------------------------
	Export our layout.

	Layout files are bracketed by:
		// Beginning of file <fileName>
		// End of file <fileName>
		-each view is output as
			<viewName> := \n{<slots>}
		-anonymous views are named <parentName>_v<viewClassAsInt>_<seqWithinFile>
		-child views are added:
			AddStepForm(<parentName>, <viewName>);
		-and declared if necessary:
			StepDeclare(<parentName>, <viewName>, '<viewName>);
		-before and after scripts:
			// After Script for <viewName>
		-final declaration of topmost view:
			constant |layout_<viewName>| := <viewName>;
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NSString * body = [NSString stringWithFormat:@"constant |%@| := <viewName>", self.symbol];	// need to expand this!

	NSString * filename = self.fileURL.lastPathComponent;
	return [NSString stringWithFormat:@"// Beginning of file %@\n"
												  "%@\n"
												  "// End of file %@\n", filename, body, filename];
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X P a c k a g e D o c u m e n t
----------------------------------------------------------------------------- */
#import "NTK/NewtonPackage.h"
#import "PkgPart.h"

/*------------------------------------------------------------------------------
	Make a NextStep string from package directory data.
	Args:		inStr			a NewtonScript symbol
	Return:	an NSString
------------------------------------------------------------------------------*/

NSString *
MakeNSString(char * inPkgFile, int inBaseOffset, InfoRef info)
{
	NSString * s;
	UniChar * src = (UniChar *)(inPkgFile + inBaseOffset + info.offset);
	int count = info.length/sizeof(UniChar);
#if defined(hasByteSwapping)
	UniChar * dst, * buf;
	dst = buf = (UniChar *) malloc(info.length);
	for (int i = 0; i < count; ++i, ++src)
		*dst++ = BYTE_SWAP_SHORT(*src);
	src = buf;
#endif
	s = [NSString stringWithCharacters: src length: count];
#if defined(hasByteSwapping)
	free(buf);
#endif
	return s;
}


@implementation NTXPackageDocument

/* -----------------------------------------------------------------------------
	Load our storyboard.
----------------------------------------------------------------------------- */

- (void)makeWindowControllers
{
	NSStoryboard * sb = [NSStoryboard storyboardWithName:@"Package" bundle:nil];
	NTXEditorViewController * ourController = [sb instantiateInitialController];
	// add view controllers for the parts we have

	NSView * contentView = ((NSBox *)ourController.view).contentView;
	NSView * prevView = [contentView.subviews objectAtIndex:0];
//	NSRect windowFrame = windowController.window.frame;
	for (PkgPart * part in self.parts) {
		NSViewController * viewController = [sb instantiateControllerWithIdentifier:[self viewControllerNameFor:part.partType]];
		viewController.representedObject = part;
		[ourController addChildViewController:viewController];

		NSView * partView = viewController.view;
//		float ht = partView.frame.size.height;
//		windowFrame.size.height += ht;
//		windowFrame.origin.y -= ht;
		// need to do this now so that the partView is positioned corectly
//		[windowController.window setFrame:windowFrame display:NO];
		[contentView addSubview:partView positioned:NSWindowBelow relativeTo:prevView];

//		NSDictionary * views = NSDictionaryOfVariableBindings(partView, prevView);
//		[partView setTranslatesAutoresizingMaskIntoConstraints:NO];
//		[contentView addSubview:partView];
//		[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[partView]|" options:0 metrics:nil views:views]];
//		[contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[partView]" options:0 metrics:nil views:views]];

		prevView = partView;
	}

	ourController.representedObject = self;
	[ourController loadView];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Return storyboard viewcontroller id for part type.
----------------------------------------------------------------------------- */

- (NSString *)viewControllerNameFor:(unsigned int)inType
{
	NSString * name;
	switch (inType)
	{
	case 'form':
	case 'auto':
		name = @"formPartViewController";
		break;
	case 'book':
		name = @"bookPartViewController";
		break;
//	case 'soup':
//		name = @"soupPartViewController";
//		break;
	default:
		name = @"PartViewController";
		break;
	}
	return name;
}

/* -----------------------------------------------------------------------------
	Read the package file; extract info from its directory header and
	part entries, and build our representation.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {

	NewtonPackage pkg(url.fileSystemRepresentation);
	const PackageDirectory * dir = pkg.directory();
	int dataOffset = sizeof(PackageDirectory) + dir->numParts * sizeof(PartEntry);

	// read relevant info out of directory into model instance variables
	_ident = [NSString stringWithFormat: @"%u", dir->id];
	_isCopyProtected = (dir->flags & kCopyProtectFlag) != 0;
	_version = [NSString stringWithFormat: @"%u", dir->version];
	_copyright = MakeNSString((char *)dir, dataOffset, dir->copyright);
	_name = MakeNSString((char *)dir, dataOffset, dir->name);
	_size = [NSString stringWithFormat: @"%@ bytes", [gNumberFormatter stringFromNumber: [NSNumber numberWithInt: dir->size]]];
	_creationDate = [gDateFormatter stringFromDate: [NSDate dateWithTimeIntervalSince1970: ((NSTimeInterval)dir->creationDate - kSecondsSince1904)]];

	ArrayIndex partCount = dir->numParts;
	if (partCount > 0)
		_parts = [[NSMutableArray alloc] initWithCapacity: partCount];
	for (ArrayIndex partNum = 0; partNum < partCount; ++partNum) {
		const PartEntry * thePart = pkg.partEntry(partNum);

		PkgPart * partObj;
		unsigned int partType = thePart->type;
		if (partType == 'form'
		||  partType == 'auto')
			partObj = [PkgFormPart alloc];
		else if (partType == 'book')
			partObj = [PkgBookPart alloc];
		else
			partObj = [PkgPart alloc];

		partObj = [partObj init:thePart ref:pkg.partRef(partNum) data:pkg.partPkgData(partNum)->data sequence:partNum];
		[_parts addObject:partObj];
	}

	return YES;
}


/* -----------------------------------------------------------------------------
	The parts in this package should be added to the built package.
----------------------------------------------------------------------------- */

- (int) evaluate
{
	return noErr;
}


/* -----------------------------------------------------------------------------
	Packages are not exported to text at all.
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	return @"\n";
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X S t r e a m D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXStreamDocument

- (NSString *)symbol
{
	return [NSString stringWithFormat:@"streamFile_%@", super.symbol];
}


/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	NTXEditorViewController * ourController = [[NTXEditorViewController alloc] initWithNibName: @"NTXStreamViewController" bundle: nil];
	ourController.representedObject = self;
	[ourController loadView];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Read native code module from disk.
	Create UI representation.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	NewtonErr err = noErr;
	NSString * txt = nil;
	newton_try
	{
		CStdIOPipe pipe(url.fileSystemRepresentation, "r");
		RefVar stream(UnflattenRef(pipe));
		txt = PrintObject(stream);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
		txt = @"Not a stream file!";
	}
	end_try;

	// set text field with that string
	_text = [[NSAttributedString alloc] initWithString:txt
														attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Menlo" size:[NSFont smallSystemFontSize]], NSFontAttributeName,
																																[NSColor blackColor], NSForegroundColorAttributeName,
																																nil]];

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Stream files are defined:
		DefConst('|streamFile_<fileName>|, ReadStreamFile("<fileName>"));
		|streamFile_<fileName>|:?Install();
----------------------------------------------------------------------------- */

- (int) evaluate
{
	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		RefVar stream(UnflattenRef(pipe));
		DefConst(self.symbol.UTF8String, stream);
		DoMessageIfDefined(stream, MakeSymbol("Install"), RA(NILREF), NULL);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	return err;
}


/* -----------------------------------------------------------------------------
	Export our NSOF stream, like so.
		DefConst('|streamFile_<fileName>|, ReadStreamFile("<fileName>"));
		|streamFile_<fileName>|:?Install();
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NSString * sym = self.symbol;
	return [NSString stringWithFormat:@"// Stream file %@\n"
												  "DefConst('|%@|, ReadStreamFile(\"%@\");\n"
												  "|%@|:?Install();\n\n", self.fileURL.lastPathComponent, sym, self.fileURL.lastPathComponent, sym];
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X N a t i v e C o d e D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXNativeCodeDocument

/* -----------------------------------------------------------------------------
	Document instantiation calls in here to make window controllers.
	The project document owns the window, so make a view controller instead.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	NTXEditorViewController * ourController = [[NTXEditorViewController alloc] initWithNibName: @"NTXCodeViewController" bundle: nil];
	ourController.representedObject = self;
	[ourController loadView];
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	Read native code module from disk.
	Create UI representation.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(url.fileSystemRepresentation, "r");
		RefVar codeModule(UnflattenRef(pipe));
		_name = MakeNSSymbol(GetFrameSlot(codeModule, SYMA(name)));
		_cpu = MakeNSSymbol(GetFrameSlot(codeModule, MakeSymbol("CPUType")));

		RefVar code(GetFrameSlot(codeModule, SYMA(code)));
		_size = [NSString stringWithFormat: @"%@ bytes", [gNumberFormatter stringFromNumber:[NSNumber numberWithInt:Length(code)]]];

		_relocations = @"None";
		RefVar relocs(GetFrameSlot(codeModule, MakeSymbol("relocations")));
		if (NOTNIL(relocs)) {
			CDataPtr relocData(relocs);
			int32_t numOfRelocs = *(int32_t *)(char *)relocData;
			numOfRelocs = CANONICAL_LONG(numOfRelocs);
			_relocations = [NSString stringWithFormat:@"%@ locations", [gNumberFormatter stringFromNumber:[NSNumber numberWithInt:numOfRelocs]]];
		}

		_debugFile = MakeNSString(GetFrameSlot(codeModule, MakeSymbol("debugFile")));

		NSString * fnNames = nil;
		RefVar entryPoints(GetFrameSlot(codeModule, MakeSymbol("entryPoints")));
		if (IsArray(entryPoints)) {
			FOREACH(entryPoints, fnDescr)
			NSString * nameStr = MakeNSSymbol(GetFrameSlot(fnDescr, SYMA(name)));
			int numOfArgs = RINT(GetFrameSlot(fnDescr, MakeSymbol("numArgs")));
			NSString * argStr = [NSString stringWithFormat:@"(%d arg%@)", numOfArgs, numOfArgs == 1 ? @"" : @"s"];
			if (fnNames == nil)
				fnNames = [NSString stringWithFormat:@"%@%@", nameStr, argStr];
			else
				fnNames = [NSString stringWithFormat:@"%@\n%@%@", fnNames, nameStr, argStr];
			END_FOREACH;
			_entryPoints = [[NSAttributedString alloc] initWithString:fnNames
																attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
																																		[NSColor blackColor], NSForegroundColorAttributeName,
																																		nil]];
		}
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Compile our native code module, like so:
		DefConst('<filename>, <frameOfCodeFile>);
----------------------------------------------------------------------------- */

- (int) evaluate
{
	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		RefVar codeModule(UnflattenRef(pipe));
		DefConst(self.symbol.UTF8String, codeModule);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	return err;
}


/* -----------------------------------------------------------------------------
	Export our native code module, like so.
		DefConst('<filename>, <frameOfCodeFile>);
	For some reason this is commented out.
----------------------------------------------------------------------------- */

- (NSString *) exportToText
{
	NewtonErr err = noErr;
	NSString * txt;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		RefVar stream(UnflattenRef(pipe));
		txt = PrintObject(stream);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
		txt = @"Not a stream file!";
	}
	end_try;
	return [NSString stringWithFormat:@"// Native code module %@\n"
												  "DefConst('|%@|, %@)\n\n", self.fileURL.lastPathComponent, self.symbol, txt];
}

@end

