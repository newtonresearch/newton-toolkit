/*
	File:		NTXDocument.mm

	Abstract:	An NTXDocument displays itself in the main project window using a view controller.

	Written by:		Newton Research, 2014.
*/

#import "NTXDocument.h"
#import "Utilities.h"
#import "NTK/Funcs.h"
#import "NTK/Globals.h"

extern void DefConst(const char * inSym, RefArg inVal);
extern "C" Ref FIntern(RefArg inRcvr, RefArg inStr);


extern NSNumberFormatter * gNumberFormatter;
extern NSDateFormatter * gDateFormatter;

#define kSecondsSince1904 2082844800


extern Ref GetGlobalConstant(RefArg inTag);

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
	Ref savedPrintDepth = GetGlobalVar(SYMA(printDepth));
	Ref savedPrintLength = GetGlobalVar(SYMA(printLength));
	DefGlobalVar(SYMA(printDepth), inDepth);
	DefGlobalVar(SYMA(printLength), inLength);
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
	DefGlobalVar(SYMA(printDepth), savedPrintDepth);
	DefGlobalVar(SYMA(printLength), savedPrintLength);
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
	A hierarchy of view templates.
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
Ref ReadLayoutSettings(NSURL * url);

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	NewtonErr err = noErr;
	newton_try
	{
		CStdIOPipe pipe(url.fileSystemRepresentation, "r");
		_layoutRef = UnflattenRef(pipe);

		RefVar templateHierarchy(GetFrameSlot(self.layoutRef, MakeSymbol("templateHierarchy")));
		if (ISNIL(templateHierarchy)) {
			// could well be Mac layout file -- read layoutSettings from resource fork
			RefVar macLayout(AllocateFrame());
			SetFrameSlot(macLayout, MakeSymbol("layoutSettings"), ReadLayoutSettings(url));
			SetFrameSlot(macLayout, MakeSymbol("templateHierarchy"), self.layoutRef);
			_layoutRef = macLayout;
		}
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
	Write layout NSOF text to disk.
	This will alter a Mac layout file so that NTK will no longer open it
	(although NTX will be able to reopen it).
----------------------------------------------------------------------------- */

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	NewtonErr err = noErr;
	newton_try
	{
#if 0
		// could do this to save in Mac format but we’d also need to update the resource fork
		RefVar settings(GetFrameSlot(self.layoutRef, MakeSymbol("layoutSettings")));
		Ref platform = GetFrameSlot(settings, MakeSymbol("ntkPlatform"));
		if (platform == MAKEINT(0)) {
			// is Mac layout file -- strip layoutSettings
			_layoutRef = GetFrameSlot(self.layoutRef, MakeSymbol("templateHierarchy"));
		}
#endif
		CStdIOPipe pipe(url.fileSystemRepresentation, "w");
		FlattenRef(self.layoutRef, pipe);
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

static bool fgUseStepChildren;

Ref
AddStepForm(RefArg parent, RefArg child) {
	RefVar childArraySym(fgUseStepChildren? SYMA(stepChildren) : SYMA(viewChildren));
	if (!FrameHasSlot(parent, childArraySym)) {
		SetFrameSlot(parent, childArraySym, AllocateArray(childArraySym, 0));
	}
	AddArraySlot(GetFrameSlot(parent, childArraySym), child);
}

Ref
StepDeclare(RefArg parent, RefArg child, RefArg tag) {
	RefVar childContextArraySym(fgUseStepChildren? SYMA(stepAllocateContext) : SYMA(allocateContext));
	if (!FrameHasSlot(parent, childContextArraySym)) {
		SetFrameSlot(parent, childContextArraySym, MakeArray(0));
	}
	AddArraySlot(GetFrameSlot(parent, childContextArraySym), tag);
	AddArraySlot(GetFrameSlot(parent, childContextArraySym), child);
}


Ref
BuildViewTemplate(RefArg viewTemplate, RefArg parent, RefArg namedViews, int depth) {

	// build thisView...
	RefVar thisView(AllocateFrame());
	DefGlobalVar(SYMA(thisView), thisView);

	// ...from slots from the template
	RefVar slots(Clone(GetFrameSlot(viewTemplate, SYMA(value))));	// we’re going to be removing before & after scripts

	// beforeScript
	RefVar script(GetFrameSlot(slots, SYMA(beforeScript)));
	if (NOTNIL(script)) {
		script = GetFrameSlot(script, SYMA(value));
		RemoveSlot(slots, SYMA(beforeScript));
		RefVar codeBlock(ParseString(script));
		if (NOTNIL(codeBlock)) {
			InterpretBlock(codeBlock, RA(NILREF));
		}
	}
	// afterScript
	script = GetFrameSlot(slots, SYMA(afterScript));
	if (NOTNIL(script)) {
		script = GetFrameSlot(script, SYMA(value));
		RemoveSlot(slots, SYMA(afterScript));
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
			proto = MAKEMAGICPTR(RVALUE(value));
			break;
		case 'CLAS':
			viewClass = value;
			break;
		default:
			switch (selector) {
			case 'EVAL':
			case 'SCPT':
				regularSlot = InterpretBlock(ParseString(value), RA(NILREF));
				break;
			case 'TEXT':
			case 'NUMB':
			case 'INTG':
			case 'RECT':
				regularSlot = value;
				break;
			case 'REAL':
				;
				break;
			case 'BOOL':
				regularSlot = MAKEBOOLEAN(NOTNIL(value));
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

	// if we have a proto or viewClass, add it
	if (NOTNIL(proto)) {
		SetFrameSlot(thisView, SYMA(_proto), proto);
	} else if (NOTNIL(viewClass)) {
		SetFrameSlot(thisView, SYMA(viewClass), viewClass);
	}

	// if template is named, add debug:<name> slot
	RefVar templateName(GetFrameSlot(viewTemplate, MakeSymbol("__ntName")));
	if (!IsString(templateName) || Length(templateName) == 0) {
		templateName = NILREF;
	}

	if (NOTNIL(templateName)) {
		SetFrameSlot(thisView, SYMA(debug), templateName);
		SetFrameSlot(namedViews, FIntern(RA(NILREF),templateName), thisView);
	}

	// afterScript
	if (NOTNIL(script)) {
		RefVar codeBlock(ParseString(script));
		if (NOTNIL(codeBlock)) {
			InterpretBlock(codeBlock, RA(NILREF));
		}
	}

	if (NOTNIL(parent)) {
		AddStepForm(parent, thisView);
	}

	RefVar declaredTo(GetFrameSlot(viewTemplate, MakeSymbol("__ntDeclare")));
	if (NOTNIL(declaredTo)) {
		RefVar declaredToName(GetFrameSlot(declaredTo, MakeSymbol("__ntName")));
		declaredTo = GetFrameSlot(namedViews, FIntern(RA(NILREF),declaredToName));

		RefVar templateSym(FIntern(RA(NILREF),templateName));
		SetFrameSlot(thisView, SYMA(preAllocatedContext), templateSym);
		SetFrameSlot(declaredTo, templateSym, RA(NILREF));
		StepDeclare(declaredTo, thisView, templateSym);
	}

	if (NOTNIL(stepChildren)) {
		FOREACH(stepChildren, child)
			BuildViewTemplate(child, thisView, namedViews, depth+1);
		END_FOREACH;
	}
	return thisView;
}


- (Ref)build {
	NewtonErr err = noErr;
	RefVar layout;
	newton_try
	{
		fgUseStepChildren = NOTNIL(GetGlobalConstant(MakeSymbol("kUseStepChildren")));
		RefVar viewTemplate(GetFrameSlot(self.layoutRef, MakeSymbol("templateHierarchy")));
		RefVar namedViews(AllocateFrame());
		layout = BuildViewTemplate(viewTemplate, RA(NILREF), namedViews, 0);
		DefConst(self.symbol.UTF8String, layout);
	}
//	newton_catch_all
//	{
//		err = (NewtonErr)(long)CurrentException()->data;;
//		layout = NILREF;
//	}
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

	RefVar slots(Clone(GetFrameSlot(viewTemplate, SYMA(value))));
	RefVar name(GetFrameSlot(viewTemplate, MakeSymbol("__ntName")));
	bool isNamed;
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
	RefVar script(GetFrameSlot(slots, SYMA(beforeScript)));
	if (NOTNIL(script)) {
		script = GetFrameSlot(script, SYMA(value));
		RemoveSlot(slots, SYMA(beforeScript));
		fprintf(fp, "// beforeScript for %s\n", (char *)nameStr);
		fprintf(fp, "%s\n", BinaryData(ASCIIString(script)));
	}
	// afterScript
	script = GetFrameSlot(slots, SYMA(afterScript));
	if (NOTNIL(script)) {
		script = GetFrameSlot(script, SYMA(value));
		RemoveSlot(slots, SYMA(afterScript));
	}
	fprintf(fp, "%s :=\n    {", (char *)nameStr);
	ArrayIndex index = 0, count = Length(slots);
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
			if (index > 0) {
				fprintf(fp, ",\n     ");
			}
			fprintf(fp, "%s: ", SymbolName(tag));
			switch (selector) {
			case 'TEXT':
				fprintf(fp, "\"%s\"", BinaryData(ASCIIString(value)));
				break;
			case 'EVAL':
				fprintf(fp, "%s", BinaryData(ASCIIString(value)));
				break;
			case 'SCPT':
				fprintf(fp, "\n%s", BinaryData(ASCIIString(value)));
				break;
			case 'NUMB':
			case 'INTG':
				fprintf(fp, "%ld", RVALUE(value));
				break;
			case 'REAL':
				;
				break;
			case 'BOOL':
				fprintf(fp, "%s", ISNIL(value)? "false":"true");
				break;
			case 'RECT':
				fprintf(fp, "{top:%ld, left:%ld, right:%ld, bottom:%ld}", RINT(GetFrameSlot(value,SYMA(top))), RINT(GetFrameSlot(value,SYMA(left))), RINT(GetFrameSlot(value,SYMA(right))), RINT(GetFrameSlot(value,SYMA(bottom))));
				break;
	//		case 'FONT':
	//		case 'PICT':
				break;
			}
			++index;
		}
	END_FOREACH;
	// if name is not anon, add debug:<name> slot
	if (isNamed) {
		fprintf(fp, ",\n     debug: \"%s\"", (char *)nameStr);
	}
	// if we have a proto or viewClass, add it last
	if (NOTNIL(proto)) {
		fprintf(fp, ",\n     _proto: @%ld", RVALUE(proto));
	} else if (NOTNIL(viewClass)) {
		fprintf(fp, ",\n     viewClass: %ld", RVALUE(viewClass));
	}
	fprintf(fp, "\n    };\n");

	// afterScript
	if (NOTNIL(script)) {
		fprintf(fp, "// afterScript for %s\nthisView := %s;\n", (char *)nameStr, (char *)nameStr);
		fprintf(fp, "%s\n", BinaryData(ASCIIString(script)));
	}

	if (parent) {
		fprintf(fp, "AddStepForm(%s, %s)\n", parent, (char *)nameStr);
	}

	RefVar declaredTo(GetFrameSlot(viewTemplate, MakeSymbol("__ntDeclare")));
	if (NOTNIL(declaredTo)) {
		name = GetFrameSlot(declaredTo, MakeSymbol("__ntName"));
		CDataPtr declaredToNameStr(ASCIIString(name));
		fprintf(fp, "StepDeclare(%s, %s, '%s)\n", (char *)declaredToNameStr, (char *)nameStr, (char *)nameStr);
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
	A Newton package.
	Read-only.
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
	fprintf(fp, "// Package file %s\n", filename);

	fprintf(fp, "// Name %s\n", self.name.UTF8String);
	fprintf(fp, "// Version %s%s\n", self.version.UTF8String, self.isCopyProtected?" (copy protected)":"");
	fprintf(fp, "// Size %s\n", self.size.UTF8String);
	fprintf(fp, "// Created %s\n", self.creationDate.UTF8String);
	fprintf(fp, "// %s\n", self.copyright.UTF8String);

	ArrayIndex partNum = 0;
	for (PkgPart * part in self.parts) {
		fprintf(fp, "\n// Part %d\n", partNum);
		PrintObject(fp, part.rootRef, 0, NILREF, MAKEINT(16));
	}
	fprintf(fp, "\n\n");
}

@end


#pragma mark -
/* -----------------------------------------------------------------------------
	N T X S t r e a m D o c u m e n t
	A Newton Streamed Object File (NSOF) object.
	Read-only.
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
	A C++ native (ie platform-specific) code module.
	Read-only.
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

