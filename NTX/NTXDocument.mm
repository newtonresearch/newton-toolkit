/*
	File:		NTXDocument.mm

	Abstract:	An NTXDocument displays itself in the main project window using a view controller.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
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

NewtonErr
PrintObject(FILE * inFP, RefArg inRef, int indent, Ref inLength, Ref inDepth)
{
	RedirectStdioOutTranslator(inFP);
	Ref savedPrintDepth = GetFrameSlot(RA(gVarFrame), SYMA(printDepth));
	Ref savedPrintLength = GetFrameSlot(RA(gVarFrame), SYMA(printLength));
	SetFrameSlot(RA(gVarFrame), SYMA(printDepth), inDepth);
	SetFrameSlot(RA(gVarFrame), SYMA(printLength), inLength);
	NewtonErr err = noErr;
	newton_try
	{
		PrintObject(inRef, indent);
	}
	newton_catch_all
	{
		REPprintf("\n*** Error printing object (%d). ***\n", CurrentException()->data);
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;
	REPprintf("\n\n");
	SetFrameSlot(RA(gVarFrame), SYMA(printDepth), savedPrintDepth);
	SetFrameSlot(RA(gVarFrame), SYMA(printLength), savedPrintLength);
	RedirectStdioOutTranslator(NULL);
	return err;
}


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
		if (newtout) {
			PrintObject(newtout, inRef, 0, NILREF, MAKEINT(1));
			fclose(newtout);
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

- (Ref)build {
	return NILREF;
}

- (void)exportToText:(FILE *)fp error:(NSError *__autoreleasing *)outError {
}

- (NSString *)storyboardName {
	return @"Settings";
}

- (NSString *)symbol {
	return self.fileURL.URLByDeletingPathExtension.lastPathComponent;
}

- (void)makeWindowControllers {
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X L a y o u t D o c u m e n t
----------------------------------------------------------------------------- */
#import "LayoutViewController.h"

@interface NTXLayoutDocument ()
{
	// the layout, as flattened to disk
	RefStruct _layoutRef;
}
@end


@implementation NTXLayoutDocument

- (Ref)layoutRef {
	return _layoutRef;
}

- (void)setLayoutRef:(Ref)inRef {
	_layoutRef = inRef;
}

- (NSString *)storyboardName {
	return @"Layout";
}

- (NSString *)symbol {
	return [NSString stringWithFormat:@"layout_%@", super.symbol];
}

/* -----------------------------------------------------------------------------
	Read layout NSOF from disk.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(url.fileSystemRepresentation, "r");
		_layoutRef = UnflattenRef(pipe);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	if (err && outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Compile our layout.
----------------------------------------------------------------------------- */
extern Ref ParseString(RefArg inStr);

Ref
AddStepForm(RefArg parent, RefArg child) {
	if (!FrameHasSlot(parent, SYMA(stepChildren))) {
		SetFrameSlot(parent, SYMA(stepChildren), AllocateArray(SYMA(stepChildren), 0));
	}
	AddArraySlot(GetFrameSlot(parent, SYMA(stepChildren)), child);
}

Ref
StepDeclare(RefArg parent, RefArg child, RefArg tag) {
}


Ref
BuildViewTemplate(RefArg viewTemplate, RefArg parent, int depth) {

	RefVar slots(GetFrameSlot(viewTemplate, MakeSymbol("value")));
	RefVar templateName(GetFrameSlot(viewTemplate, MakeSymbol("__ntName")));
	bool isDeclared = false;
	if (!IsString(templateName) || Length(templateName) == 0) {
		templateName = NILREF;
	}

	RefVar thisView(AllocateFrame());
	SetFrameSlot(RA(gVarFrame), MakeSymbol("thisView"), thisView);

	// beforeScript
	RefVar script(GetFrameSlot(viewTemplate, MakeSymbol("beforeScript")));
	if (NOTNIL(script)) {
		RefVar codeBlock(ParseString(script));
		if (NOTNIL(codeBlock)) {
			InterpretBlock(codeBlock, RA(NILREF));
		}
	}

	RefVar regularSlot, proto, viewClass, stepChildren;
	FOREACH_WITH_TAG(slots, tag, slot)
		RefVar value(GetFrameSlot(slot, SYMA(value)));
		RefVar type(GetFrameSlot(slot, MakeSymbol("__ntDataType")));
		CDataPtr typeData(ASCIIString(type));
		const char * typeStr = (const char *)typeData;
		int selector = (typeStr[0] << 24) + (typeStr[1] << 16) + (typeStr[2] << 8) + typeStr[3];
		switch (selector) {
		case 'ARAY':
			// it’s the stepChildren slot
			stepChildren = value;
			break;
		case 'PROT':
			proto = value;
			break;
		case 'CLAS':
			viewClass = value;
			break;
		default:
			switch (selector) {
			case 'TEXT':
				regularSlot = value;
				break;
			case 'EVAL':
				regularSlot = InterpretBlock(ParseString(value), RA(NILREF));
				break;
			case 'SCPT':
				regularSlot = ParseString(value);
				break;
			case 'NUMB':
			case 'INTG':
				regularSlot = value;
				break;
			case 'REAL':
				;
				break;
			case 'BOOL':
				regularSlot = MAKEBOOLEAN(NOTNIL(value));
				break;
			case 'RECT':
				regularSlot = value;
				break;
	//		case 'FONT':
	//		case 'PICT':
				break;
			default:
				regularSlot = NILREF;
			}
			SetFrameSlot(thisView, tag, regularSlot);
		}
	END_FOREACH;

	// if template is named, add debug:<name> slot
	if (NOTNIL(templateName)) {
		SetFrameSlot(thisView, SYMA(debug), templateName);
	}

	// if we have a proto or viewClass, add it last
	if (NOTNIL(proto)) {
		SetFrameSlot(thisView, SYMA(debug), proto);
	} else if (NOTNIL(viewClass)) {
		SetFrameSlot(thisView, SYMA(debug), viewClass);
	}

	// afterScript
	script = GetFrameSlot(viewTemplate, MakeSymbol("afterScript"));
	if (NOTNIL(script)) {
		// set up thisView
		RefVar codeBlock(ParseString(script));
		if (NOTNIL(codeBlock)) {
			InterpretBlock(codeBlock, RA(NILREF));
		}
	}

	if (parent) {
		AddStepForm(parent, thisView);
//		if (isDeclared) {
//			StepDeclare(parent, thisView, declaredSym);
//		}
	}

	if (NOTNIL(stepChildren)) {
		FOREACH(stepChildren, child)
			BuildViewTemplate(child, thisView, depth+1);
		END_FOREACH;
	}
	return thisView;
}


- (Ref)build {
	NewtonErr err = noErr;
	RefVar layout;
	newton_try
	{
		RefVar viewTemplate(GetFrameSlot(self.layoutRef, MakeSymbol("templateHierarchy")));
		layout = BuildViewTemplate(viewTemplate, NULL, 0);
		DefConst(self.symbol.UTF8String, layout);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
		layout = NILREF;
	}
	end_try;
	return layout;
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

Ref
PrintViewTemplate(FILE * fp, RefArg viewTemplate, const char * parent, int depth) {

	RefVar slots(GetFrameSlot(viewTemplate, MakeSymbol("value")));
	RefVar name(GetFrameSlot(viewTemplate, MakeSymbol("__ntName")));
	bool isNamed, isDeclared = false;
	if (IsString(name) && Length(name) > 0) {
		isNamed = true;
	} else {
		// make anon name
		RefVar proto(GetFrameSlot(viewTemplate, MakeSymbol("__ntTemplate")));
		char anon[256];
		sprintf(anon, "%s_v%ld_%d", parent? parent : "", RVALUE(proto), depth);
		name = MakeStringFromCString(anon);
		isNamed = false;
	}
	CDataPtr nameStr(ASCIIString(name));
	RefVar proto, viewClass, stepChildren;
	// beforeScript
	RefVar script(GetFrameSlot(viewTemplate, MakeSymbol("beforeScript")));
	if (NOTNIL(script)) {
		fprintf(fp, "// beforeScript for %s\n", (char *)nameStr);
		fprintf(fp, "%s\n", BinaryData(ASCIIString(script)));
	}
	fprintf(fp, "%s :=\n    {", (char *)nameStr);
	ArrayIndex index = 0, count = Length(slots);
	FOREACH_WITH_TAG(slots, tag, slot)
		RefVar value(GetFrameSlot(slot, SYMA(value)));
		RefVar type(GetFrameSlot(slot, MakeSymbol("__ntDataType")));
		CDataPtr typeStr(ASCIIString(type));
		++index;
		if (strncmp(typeStr, "ARAY", 4) == 0) {
			// it’s the stepChildren slot
			stepChildren = value;
		} else if (strncmp(typeStr, "PROT", 4) == 0) {
			proto = value;
		} else if (strncmp(typeStr, "CLAS", 4) == 0) {
			viewClass = value;
		} else {
			fprintf(fp, "%s: ", SymbolName(tag));

			if (strncmp(typeStr, "TEXT", 4) == 0) {
				fprintf(fp, "\"%s\"", BinaryData(ASCIIString(value)));
			} else if (strncmp(typeStr, "EVAL", 4) == 0) {
				fprintf(fp, "%s", BinaryData(ASCIIString(value)));
			} else if (strncmp(typeStr, "SCPT", 4) == 0) {
				fprintf(fp, "\n%s", BinaryData(ASCIIString(value)));
			} else if (strncmp(typeStr, "NUMB", 4) == 0 || strncmp(typeStr, "INTG", 4) == 0) {
				fprintf(fp, "%ld", RVALUE(value));
			} else if (strncmp(typeStr, "REAL", 4) == 0) {
			} else if (strncmp(typeStr, "BOOL", 4) == 0) {
				fprintf(fp, "%s", ISNIL(value)? "false":"true");
			} else if (strncmp(typeStr, "RECT", 4) == 0) {
				fprintf(fp, "{left:%ld, top:%ld, right:%ld, bottom:%ld}", RINT(GetFrameSlot(value,SYMA(left))), RINT(GetFrameSlot(value,SYMA(top))), RINT(GetFrameSlot(value,SYMA(right))), RINT(GetFrameSlot(value,SYMA(bottom))));
	//		} else if (strncmp(typeStr, "FONT", 4) == 0) {
	//		} else if (strncmp(typeStr, "PICT", 4) == 0) {
			}
			if (index < count) {
				fprintf(fp, ",\n    ");
			}
		}
	END_FOREACH;
	// if name is not anon, add debug:<name> slot
	if (isNamed) {
		fprintf(fp, ",\n    debug: \"%s\"", (char *)nameStr);
	}
	// if we have a proto or viewClass, add it last
	if (NOTNIL(proto)) {
		fprintf(fp, ",\n    _proto: @%ld", RVALUE(proto));
	} else if (NOTNIL(viewClass)) {
		fprintf(fp, ",\n    viewClass: %ld", RVALUE(viewClass));
	}
	fprintf(fp, "\n    };\n");

	// afterScript
	script = GetFrameSlot(viewTemplate, MakeSymbol("afterScript"));
	if (NOTNIL(script)) {
		fprintf(fp, "// afterScript for %s\nthisView := %s;\n", (char *)nameStr, (char *)nameStr);
		fprintf(fp, "%s\n", BinaryData(ASCIIString(script)));
	}

	if (parent) {
		fprintf(fp, "AddStepForm(%s, %s)\n", parent, (char *)nameStr);
		if (isDeclared) {
			fprintf(fp, "StepDeclare(%s, %s, '%s)\n", parent, (char *)nameStr, (char *)nameStr);
		}
	}
	fprintf(fp, "\n");

	if (NOTNIL(stepChildren)) {
		FOREACH(stepChildren, child)
			PrintViewTemplate(fp, child, (char *)nameStr, depth+1);
		END_FOREACH;
	}
	return name;
}


/* -----------------------------------------------------------------------------
	Export text representation of the layout.
----------------------------------------------------------------------------- */

- (void)exportToText:(FILE *)fp error:(NSError *__autoreleasing *)outError {
	NewtonErr err = noErr;
	const char * filename = self.fileURL.lastPathComponent.UTF8String;
	fprintf(fp, "// Beginning of file %s\n", filename);
	newton_try
	{
		RefVar viewTemplate(GetFrameSlot(self.layoutRef, MakeSymbol("templateHierarchy")));
		RefVar templateName(PrintViewTemplate(fp, viewTemplate, NULL, 0));
		CDataPtr nameStr(ASCIIString(templateName));
		fprintf(fp, "constant |%s| := %s\n", self.symbol.UTF8String, (char *)nameStr);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;
	fprintf(fp, "// End of file %s\n\n", filename);

	if (err && outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X P a c k a g e D o c u m e n t
----------------------------------------------------------------------------- */
#import "NTK/NewtonPackage.h"
#import "PkgPart.h"
#import "PackageViewController.h"

@implementation NTXPackageDocument

- (NSString *)storyboardName {
	return @"Package";
}

/* -----------------------------------------------------------------------------
	Read the package file; extract info from its directory header and
	part entries, and build our representation.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {

	NewtonPackage pkg(url.fileSystemRepresentation);
	const PackageDirectory * dir = pkg.directory();
	if (dir == NULL) {
		return NO;
	}

	// read relevant info out of directory into model instance variables
	int dataOffset = sizeof(PackageDirectory) + dir->numParts * sizeof(PartEntry);
	_ident = [NSString stringWithFormat: @"%u", dir->id];
	_isCopyProtected = (dir->flags & kCopyProtectFlag) != 0;
	_version = [NSString stringWithFormat: @"%u", dir->version];
	_copyright = [NSString stringWithCharacters: (UniChar *)((char *)dir + dataOffset + dir->copyright.offset) length: dir->copyright.length/sizeof(UniChar)];
	_name =  [NSString stringWithCharacters: (UniChar *)((char *)dir + dataOffset + dir->name.offset) length: dir->name.length/sizeof(UniChar)];
	_size = [NSString stringWithFormat: @"%@ bytes", [gNumberFormatter stringFromNumber: [NSNumber numberWithInt: dir->size]]];
	_creationDate = [gDateFormatter stringFromDate: [NSDate dateWithTimeIntervalSince1970: ((NSTimeInterval)dir->creationDate - kSecondsSince1904)]];

	ArrayIndex partCount = dir->numParts;
	if (partCount > 0) {
		_parts = [[NSMutableArray alloc] initWithCapacity: partCount];
	}
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

- (Ref)build {
	return NILREF;
}


/* -----------------------------------------------------------------------------
	Packages were not originally exported to text at all.
----------------------------------------------------------------------------- */

- (void)exportToText:(FILE *)fp error:(NSError *__autoreleasing *)outError {
	const char * filename = self.fileURL.lastPathComponent.UTF8String;
	fprintf(fp, "// Package file %s\n\n", filename);
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X S t r e a m D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXStreamDocument

- (NSString *) storyboardName {
	return @"Stream";
}

- (NSString *)symbol {
	return [NSString stringWithFormat:@"streamFile_%@", super.symbol];
}


/* -----------------------------------------------------------------------------
	Read NSOF stream file from disk.
	Create UI representation.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
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
														 attributes:@{ NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:NSFont.smallSystemFontSize],
																			NSForegroundColorAttributeName:NSColor.blackColor }];

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Stream files are defined:
		DefConst('|streamFile_<fileName>|, ReadStreamFile("<fileName>"));
		|streamFile_<fileName>|:?Install();
----------------------------------------------------------------------------- */

- (Ref)build {
	NewtonErr err = noErr;
	RefVar stream;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		stream = UnflattenRef(pipe);
		DefConst(self.symbol.UTF8String, stream);
		DoMessageIfDefined(stream, MakeSymbol("Install"), RA(NILREF), NULL);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;
		stream = NILREF;
	}
	end_try;

	return stream;
}


/* -----------------------------------------------------------------------------
	Export our NSOF stream, like so.
		DefConst('|streamFile_<fileName>|, ReadStreamFile("<fileName>"));
		|streamFile_<fileName>|:?Install();
----------------------------------------------------------------------------- */

- (void)exportToText:(FILE *)fp error:(NSError *__autoreleasing *)outError {
	const char * filename = self.fileURL.lastPathComponent.UTF8String;
	const char * sym = self.symbol.UTF8String;
	fprintf(fp, "// Stream file %s\n"
				   "DefConst('|%s|, ReadStreamFile(\"%s\");\n"
				   "|%s|:?Install();\n\n", filename, sym, filename, sym);
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X N a t i v e C o d e D o c u m e n t
----------------------------------------------------------------------------- */
@implementation NTXNativeCodeDocument

- (NSString *)storyboardName {
	return @"NativeCode";
}


/* -----------------------------------------------------------------------------
	Read native code module from disk.
	Create UI representation.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
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
			NSString * argStr = @"";
			for (int i = 1; i <= numOfArgs; ++i) {
				argStr = [NSString stringWithFormat:@"%@, RefArg arg%d", argStr, i];
			}
			if (fnNames == nil)
				fnNames = [NSString stringWithFormat:@"Ref %@(RefArg rcvr%@);", nameStr, argStr];
			else
				fnNames = [NSString stringWithFormat:@"%@\nRef %@(RefArg rcvr%@);", fnNames, nameStr, argStr];
			END_FOREACH;
			_entryPoints = [[NSAttributedString alloc] initWithString:fnNames
																		  attributes:@{ NSFontAttributeName:[NSFont systemFontOfSize:NSFont.smallSystemFontSize], NSForegroundColorAttributeName:NSColor.blackColor }];
		}
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	if (err && outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:ioErr userInfo:nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Compile our native code module, like so:
		DefConst('<filename>, <frameOfCodeFile>);
----------------------------------------------------------------------------- */

- (Ref)build {
	NewtonErr err = noErr;
	RefVar codeModule;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		codeModule = UnflattenRef(pipe);
		DefConst(self.symbol.UTF8String, codeModule);
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
		codeModule = NILREF;
	}
	end_try;

	return codeModule;
}


/* -----------------------------------------------------------------------------
	Export our native code module, like so.
		DefConst('<filename>, <frameOfCodeFile>);
	For some reason this is commented out.
----------------------------------------------------------------------------- */

- (void)exportToText:(FILE *)fp error:(NSError *__autoreleasing *)outError {
	const char * filename = self.fileURL.lastPathComponent.UTF8String;
	const char * sym = self.symbol.UTF8String;
	fprintf(fp, "// Native code module %s\n"
				   "DefConst('|%s|, ", filename, sym);

	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(self.fileURL.fileSystemRepresentation, "r");
		RefVar codeModule(UnflattenRef(pipe));
		PrintObject(fp, codeModule, 4, NILREF, MAKEINT(16));
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;;
	}
	end_try;

	if (err && outError)
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:ioErr userInfo:nil];
}

@end

