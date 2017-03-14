/*
	File:		ProjectDocument.mm

	Contains:	Project document implementation for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/

#import <sys/xattr.h>
#include <sys/attr.h>
#include <unistd.h>

#import <CoreServices/CoreServices.h>

#import "AppDelegate.h"
#import "ToolkitProtocolController.h"
#import "ProjectDocument.h"
#import "MacRsrcProject.h"
#import "PackagePart.h"
#import "ProjectWindowController.h"
#import "Utilities.h"
#import "NTXDocument.h"
#import "NTK/ObjectHeap.h"

extern "C" Ref		FIntern(RefArg inRcvr, RefArg inStr);
extern "C" Ref		ArrayInsert(RefArg ioArray, RefArg inObj, ArrayIndex index);
extern	  Ref		MakeStringOfLength(const UniChar * str, ArrayIndex numChars);
extern	  Ref		MakeStringFromUTF8String(const char * inStr);
extern	  Ref		ParseString(RefArg inStr);

extern NSString *	MakeNSSymbol(RefArg inSym);

extern Ref *		RSgConstantsFrame;
extern Ref *		RSformInstallScript;
extern Ref *		RSformRemoveScript;
extern Ref *		RSautoInstallScript;


#pragma mark - NTXProjectDocument
/* -----------------------------------------------------------------------------
	N T X P r o j e c t D o c u m e n t
----------------------------------------------------------------------------- */

/*------------------------------------------------------------------------------
	Define global constant for build.
	Args:		inSym			global var
				inVal			its value
	Return:	--
------------------------------------------------------------------------------*/
extern "C" {
Ref	FDefineGlobalConstant(RefArg inRcvr, RefArg inTag, RefArg inObj);
Ref	FUnDefineGlobalConstant(RefArg inRcvr, RefArg inTag);
}

void
DefConst(const char * inSym, RefArg inVal)
{
	FDefineGlobalConstant(RA(NILREF), MakeSymbol(inSym), inVal);
}

void
UnDefConst(const char * inSym)
{
	FUnDefineGlobalConstant(RA(NILREF), MakeSymbol(inSym));
}


/*------------------------------------------------------------------------------
	Convert a string object from Mac OS 7 path to URL path.
	Replace : -> /
	Args:		inPath		the path string object
	Return:	string
------------------------------------------------------------------------------*/

NSString *
MakePathString(RefArg inPath)
{
	return MakeNSString(inPath);
}


/*------------------------------------------------------------------------------
	Convert a date object to Newton Date type.
	Args:		inDate		the date object
	Return:	number of minutes since 1904
------------------------------------------------------------------------------*/
#define kMinutesSince1904 34714080
#define kSecondsSince1904 2082844800

Date
MakeDateType(NSDate * inDate)
{
NSLog(@"MakeDateType(%@) -> %u", [inDate description], kSecondsSince1904 + (Date)inDate.timeIntervalSince1970);
	return kSecondsSince1904 + (Date)inDate.timeIntervalSince1970;
}


/* -----------------------------------------------------------------------------
	Types of file we recognise.
----------------------------------------------------------------------------- */
NSString * const NTXProjectFileType = @"com.newton.project";
NSString * const NTXLayoutFileType = @"com.newton.layout";
NSString * const NTXScriptFileType = @"com.newton.script";
NSString * const NTXStreamFileType = @"com.newton.stream";
NSString * const NTXCodeFileType = @"com.newton.nativecode";
NSString * const NTXPackageFileType = @"com.newton.package";


@implementation NTXProjectDocument

- (Ref) projectRef { return _projectRef; }
- (void) setProjectRef: (Ref) inRef { _projectRef = inRef; }


/* -----------------------------------------------------------------------------
	Project documents should autosave.
----------------------------------------------------------------------------- */

+ (BOOL)autosavesInPlace {
	return YES;
}


/* -----------------------------------------------------------------------------
	Initialize.
	Initialize the projectRef with default values -- can be used for a new
	document.
----------------------------------------------------------------------------- */

- (id)init {
	if (self = [super init]) {
	//	stream in default project settings
		NSURL * url = [NSBundle.mainBundle URLForResource: @"CanonicalProject" withExtension: @"stream"];
		CStdIOPipe pipe(url.fileSystemRepresentation, "r");
		_projectRef = UnflattenRef(pipe);
	}
	return self;
}


- (NSString *)storyboardName {
	return @"Settings";
}


/* -----------------------------------------------------------------------------
	Make the project window.
----------------------------------------------------------------------------- */

- (void)makeWindowControllers {
	NTXProjectWindowController * windowController = [[NSStoryboard storyboardWithName:@"Project" bundle:nil] instantiateInitialController];
	[self addWindowController: windowController];
	self.windowController = windowController;

	newton_try
	{
		RefVar windowRect = GetFrameSlot(self.projectRef, MakeSymbol("windowRect"));
		if (NOTNIL(windowRect)) {
			// windowRect is a frame: { top:x, left:x, bottom:x, right:x }
			int windowTop = RINT(GetFrameSlot(windowRect, SYMA(top)));
			int windowLeft = RINT(GetFrameSlot(windowRect, SYMA(left)));
			int windowBottom = RINT(GetFrameSlot(windowRect, SYMA(bottom)));
			int windowRight = RINT(GetFrameSlot(windowRect, SYMA(right)));
			// to which we add the split positions: { sourceSplit:x, debugSplit:x }  0 => split is not shown
			;	// set window’s bounds/splits accordingly
		}
	}
	newton_catch_all
	{
	}
	end_try;

}


/* -----------------------------------------------------------------------------
	Report feedback in our window’s progress box.
----------------------------------------------------------------------------- */

- (void)report:(NSString *)inFeedback {
	self.windowController.progress.localizedDescription = inFeedback;
}


/* -----------------------------------------------------------------------------
	Read the project from disk.
	NTX uses WindowsNTK format -- an NSOF flattened project object.
	We can also import MacNTK project files, but we don’t save that format.
----------------------------------------------------------------------------- */

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
	NewtonErr err = noErr;
	newton_try
	{
		NTXRsrcProject * data;
		if ([url.pathExtension isEqualToString:@"ntk"] && (data = [[NTXRsrcProject alloc] initWithURL:url]) != nil) {
		// the file has a resource fork so assume it’s a Mac NTK project
			_projectRef = data.projectRef;
		} else {
			CStdIOPipe pipe(url.fileSystemRepresentation, "r");
			_projectRef = UnflattenRef(pipe);
		}

		[self buildSourceList:url];
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


- (void)buildSourceList:(NSURL *)inProjectURL {
	inProjectURL = inProjectURL.URLByDeletingLastPathComponent;	// we want the folder now

	NTXProjectItem * projectItem;

	RefVar projectItemsRef(GetFrameSlot(_projectRef, MakeSymbol("projectItems")));
	RefVar items = GetFrameSlot(projectItemsRef, MakeSymbol("items"));

	// add projectItems to our list
	NSMutableArray * projItems = [[NSMutableArray alloc] initWithCapacity:Length(items)];

	NSURL * itemURL;
//	NSUInteger groupLen = 0;
	FOREACH(items, projItem)
		int filetype;
		RefVar fileRef(GetFrameSlot(projItem, MakeSymbol("file")));
		if (NOTNIL(fileRef)) {
			if (EQ(ClassOf(fileRef), MakeSymbol("fileReference"))) {
				NSString * path;
				RefVar pathRef;
				// preferred path is in 'fullPath as per NTK 1.6.2
				pathRef = GetFrameSlot(fileRef, MakeSymbol("fullPath"));
				if (NOTNIL(pathRef)) {
					NSString * pathStr = MakePathString(pathRef);
					itemURL = [NSURL fileURLWithPath:MakePathString(pathRef) isDirectory:NO];
				} else {
					// try 'relativePath as per NTK 1.6.2
					pathRef = GetFrameSlot(fileRef, MakeSymbol("relativePath"));
					if (NOTNIL(pathRef)) {
						itemURL = [inProjectURL URLByAppendingPathComponent:MakePathString(pathRef)];
					} else {
						// fall back to 'deltaFromProject
						pathRef = GetFrameSlot(fileRef, MakeSymbol("deltaFromProject"));
						if (NOTNIL(pathRef)) {
							itemURL = [inProjectURL URLByAppendingPathComponent:MakePathString(pathRef)];
							// NTK Formats says this can also be a full path!
						}
					}
				}
				//XFAIL(!itemURL) ?
				filetype = RINT(GetFrameSlot(projItem, MakeSymbol("type")));
				if (filetype < 0)	// plainC files may not be encoded correctly by Mac->Win converter
					filetype = kNativeCodeFileType;
				projectItem = [[NTXProjectItem alloc] initWithURL:itemURL type:filetype];
				if (NOTNIL(GetFrameSlot(projItem, MakeSymbol("isMainLayout"))))
					projectItem.isMainLayout = YES;
				[projItems addObject: projectItem];
// if groupLen > 0 then begin groupLen--; if groupLen == 0 then unstack sidebarItems end
			} else if (EQ(ClassOf(fileRef), MakeSymbol("fileGroup"))) {
// if groupLen > 0 then error -- terminate current group early: unstack sidebarItems
				NSString * groupName = MakeNSString(GetFrameSlot(fileRef, MakeSymbol("name")));
//				groupLen = RINT(GetFrameSlot(fileRef, MakeSymbol("length")));
				projectItem = [[NTXProjectItem alloc] initWithURL:[NSURL URLWithString:groupName] type:kGroupType];
				[projItems addObject: projectItem];
// if groupLen > 0 then begin stack sidebarItems; create new sidebarItems end
			}
		}
	END_FOREACH;

	Ref selection;
	NSInteger selItem = NOTNIL(selection = GetFrameSlot(projectItemsRef, MakeSymbol("selectedItem"))) ? RINT(selection) : -1;
	NSInteger sortOrder = NOTNIL(selection = GetFrameSlot(projectItemsRef, MakeSymbol("sortOrder"))) ? RINT(selection) : -1;

	self.projectItems = [NSMutableDictionary dictionaryWithDictionary:
									@{ @"selectedItem":[NSNumber numberWithInteger:selItem],
										@"sortOrder":[NSNumber numberWithInteger:sortOrder],
										@"items":projItems }];
}


/* -----------------------------------------------------------------------------
	Update the projectItems array from the current source list.
	projectRef: {
		...
		projectItems: {		<-- this is the frame we want
			selectedItem: nil,	// NTX extension
			sortOrder: 0,
			items: [
				{ file: { class:'fileReference, fullPath:"/Users/simon/Projects/newton-toolkit/Test/Demo/Playground.ns" },
				  type: 5,
				  isMainLayout: nil },
				  ...
			]
		}
	}
----------------------------------------------------------------------------- */

- (void)updateProjectItems {
	NSArray * sourceItems = [self.projectItems objectForKey:@"items"];
	// create items array
	RefVar fileItems(MakeArray(sourceItems.count));
	// create proto file item frame -- we’re going to update the fullPath slot
	RefVar protoFileRef(AllocateFrame());
	SetClass(protoFileRef, MakeSymbol("fileReference"));
	SetFrameSlot(protoFileRef, MakeSymbol("fullPath"), RA(NILREF));

	ArrayIndex i = 0;
	for (NTXProjectItem * sourceItem in sourceItems) {
		RefVar fileRef(Clone(protoFileRef));
		SetFrameSlot(fileRef, MakeSymbol("fullPath"), MakeStringFromUTF8String(sourceItem.url.fileSystemRepresentation));

		RefVar item(AllocateFrame());
		SetFrameSlot(item, MakeSymbol("file"), fileRef);
		SetFrameSlot(item, SYMA(type), MAKEINT(sourceItem.type));
		SetFrameSlot(item, MakeSymbol("isMainLayout"), MAKEBOOLEAN(sourceItem.isMainLayout));
		SetArraySlot(fileItems, i++, item);
	}

	if (NOTNIL(_projectRef)) {
		// create projectItems frame
		RefVar projItems(AllocateFrame());
		NSInteger selectedItem = [(NSNumber *)[self.projectItems objectForKey:@"selectedItem"] integerValue];
		SetFrameSlot(projItems, MakeSymbol("selectedItem"), (selectedItem >= 0) ? MAKEINT(selectedItem) : NILREF);
		SetFrameSlot(projItems, MakeSymbol("sortOrder"), MAKEINT(0));
		SetFrameSlot(projItems, MakeSymbol("items"), fileItems);
		// update project frame
		SetFrameSlot(_projectRef, MakeSymbol("projectItems"), projItems);
	}
}


/* -----------------------------------------------------------------------------
	Write the project to disk.
	Flatten it to NSOF.
	Alternatively, write out a text representation.
----------------------------------------------------------------------------- */

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
	NewtonErr err = noErr;
	[self updateProjectItems];

	if ([typeName isEqualTo:@"public.plain-text"]) {
		//	export a text representation of the project into a file named <projectName>.text
		NSError *__autoreleasing err = nil;
		NSURL * path = [url.URLByDeletingPathExtension URLByAppendingPathExtension:@"text"];

		FILE * fp = fopen(path.fileSystemRepresentation, "w");
		if (fp) {
			NSString * when = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
			fprintf(fp, "// Text of project %s written on %s\n\n", url.lastPathComponent.UTF8String, when.UTF8String);

			for (NTXProjectItem * item in [self.projectItems objectForKey:@"items"])
			{
				[self report:[NSString stringWithFormat:@"Exporting %@ to text", item.name]];
				[item.document exportToText:fp error:&err];
				if (err) {
					break;
				}
			}
			fclose(fp);
		}

		if (err) {
			[self report:[NSString stringWithFormat:@"Export failed: %@", err.localizedDescription]];
		} else {
			[self report:@"Export successful"];
		}
	}
	else
	{
		// update windowRect & split positions
//		RefVar windowRect = GetFrameSlot(self.projectRef, MakeSymbol("windowRect"));

		// save settings and source list
		CStdIOPipe pipe(url.fileSystemRepresentation, "w");
		newton_try
		{
			FlattenRef(_projectRef, pipe);
		}
		newton_catch_all
		{
			err = (NewtonErr)(long)CurrentException()->data;;
		}
		end_try;

	}

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


#pragma mark - Build menu actions

/* -----------------------------------------------------------------------------
	Enable main menu items as per app logic.
		Build
			Build Package		always
			Download Package	if we are tethered
			Export Package		always

	Args:		inItem
	Return:	YES => enable
----------------------------------------------------------------------------- */

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)inItem {
	if (inItem.action == @selector(downloadPackage:)) {
		return gNTXNub != nil && gNTXNub.isTethered;
	}
	return YES;
}


/* -----------------------------------------------------------------------------
	Build the current project.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)buildPackage:(id)sender {
	[self build];
}


/* -----------------------------------------------------------------------------
	Build the current project and download it to Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)downloadPackage:(id)sender {
	NSURL * pkg = [self build];
	if (pkg) {
		if (gNTXNub != nil && gNTXNub.isTethered) {
			[gNTXNub installPackage:pkg];
		}
	}
}


/* -----------------------------------------------------------------------------
	Export the current project to text.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)exportPackage:(id)sender {
	NSError *__autoreleasing err = nil;
	[self writeToURL:self.fileURL ofType:@"public.plain-text" error:&err];
}


#pragma mark -
/* -----------------------------------------------------------------------------
	Compile all the sources.

	When compiling a file:
	stream
		unflatten it -> topFrame
		if topFrame actually is a frame, and topFrame.install exists and is a function, call it
		create constant streamFile_<filename>

	package
		add part(s) in package to self.parts

	NewtonScript text
		evaluate it

	layout
		assert _proto or viewClass exists
		execute beforeScript, if it exists
		process layout
		execute afterScript, if it exists
		create constant layout_<filename>

	resource
		TBD

	Args:		--
	Return:	--
				The result will be in gVarFrame somewhere.
----------------------------------------------------------------------------- */

- (void)evaluate {
	for (NTXProjectItem * item in [self.projectItems objectForKey:@"items"]) {
		[item.document evaluate];
	}
}


/* -----------------------------------------------------------------------------
	Build the source into the output part type specified in outputSettings.partType.

	Install and Remove scripts are mapped by NTK -> devInstall|RemoveScript.
	A DeletionScript() can optionally be set in the partFrame, to be called when icon scrubbed.

=== auto parts ===
	top-level partFrame might have:
	{ text: "Demo",
	  icon: {...},
	  iconPro: {...},
	  partData: {...}
	}
	but that’s all optional and must be set explicitly by the dev.
	MUST have both InstallScript and RemoveScript (Newton Toolkit User’s Guide 4-28)
	although later (4-44) it says auto-remove parts don’t have their RemoveScript called.
	NTK munges the partFrame:
		Rename InstallScript -> devInstallScript.
		Rename RemoveScript -> devRemoveScript.
		InstallScript := func(partFrame, removeFrame) begin
			removeFrame := EnsureInternal({RemoveScript:partFrame.devRemoveScript});
			partFrame:devInstallScript(partFrame, removeFrame);	// dev can add extra slots to removeFrame
			removeFrame
		end;

	removeFrame:RemoveScript() is called automatically after installation.
	auto parts are not persistent, so no need to nil out Install|Remove scripts

=== form parts ===
	top-level partFrame is:
	{ app: '|Demo:simple|,
	  text: "Demo",
	  icon: {...},
	  iconPro: {...},
	  theForm: {...}
	}
	Install|Remove scripts are optional. text and icon slots ditto.
	NTK munges the partFrame:
		Rename InstallScript -> devInstallScript.
		Rename RemoveScript -> devRemoveScript.
		InstallScript := func(partFrame) begin
			local extras := vars.extras;
			if IsArray(extras) then begin
				foreach one in extras do begin
					if one.app = partFrame.app then begin
						GetRoot():Notify(kNotifyAlert, "Extras Drawer", "The application you just installed conflicts with another application. Please contact the application vendor for an updated version.");
						break
					end
				end
			end;
			if HasSlot(partFrame, 'devInstallScript) then begin
				partFrame:?devInstallScript();
				RemoveSlot(partFrame, 'devInstallScript)
			end;
			partFrame.InstallScript := nil
		end;

		RemoveScript := func(removeFrame) begin
			if HasSlot(removeFrame, 'devRemoveScript) then
				removeFrame:devRemoveScript()
			// no point making it nil, package is going anyway
		end;

	it always does this even if there are no Install|Remove scripts

=== book parts ===
	top-level partFrame is:
	{ book: { version: 2,
				 isbn: "xx:12345678",
				 ...
				 contents: [...] }
	}
	No Install|Remove scripts.


=== font parts ===
	top-level partFrame is:
	{ Monaco: { name: "Monaco", ...}
	}
	We’re never going to generate fonts.

=== store, custom parts ===
	No Install|Remove scripts.

	Args:		--
	Return:	URL of package file so it can be downloaded to tethered device
				if necessary
----------------------------------------------------------------------------- */

- (NSURL *)build {
	// sync our projectItems with source list
	[self updateProjectItems];

	// get settings frames
	RefVar projectSettings(GetFrameSlot(_projectRef, MakeSymbol("projectSettings")));
	RefVar profilerSettings(GetFrameSlot(_projectRef, MakeSymbol("profilerSettings")));
	RefVar packageSettings(GetFrameSlot(_projectRef, MakeSymbol("packageSettings")));
	RefVar outputSettings(GetFrameSlot(_projectRef, MakeSymbol("outputSettings")));

	// set a separate build heap
	int buildHeapSize = [NSUserDefaults.standardUserDefaults integerForKey:@"BuildHeapSize"] * KByte;
	CObjectHeap * buildHeap = new CObjectHeap(buildHeapSize);
	CObjectHeap * saveHeap = gHeap;
	gHeap = buildHeap;

	NewtonErr err = noErr;
	newton_try
	{
		// set build constants
		DefConst("kAppName", GetFrameSlot(outputSettings, MakeSymbol("applicationName")));			// string
		DefConst("kAppSymbol", FIntern(RA(NILREF), GetFrameSlot(outputSettings, MakeSymbol("applicationSymbol"))));	// symbol
		DefConst("kAppString", GetFrameSlot(outputSettings, MakeSymbol("applicationSymbol")));		// string
		DefConst("kPackageName", GetFrameSlot(packageSettings, MakeSymbol("packageName")));		// string
		DefConst("kDebugOn", GetFrameSlot(projectSettings, MakeSymbol("debugBuild")));					// boolean
		DefConst("kProfileOn", GetFrameSlot(profilerSettings, MakeSymbol("compileForProfiling")));		// boolean
		DefConst("kIgnoreNativeKeyword", GetFrameSlot(projectSettings, MakeSymbol("ignoreNative")));		// boolean
		DefConst("home", MakeStringFromUTF8String(self.fileURL.URLByDeletingLastPathComponent.fileSystemRepresentation));	// string
		DefConst("language", GetFrameSlot(projectSettings, MakeSymbol("language")));		// string
		// as build progresses it may add globals:
		//	PT_<filename>
		//	layout_<filename>
		//	streamFile_<filename>
		// partFrame, InstallScript, RemoveScript

		// say what we’re doing
		RefVar packageNameStr(GetFrameSlot(packageSettings, MakeSymbol("packageName")));
		[self report:[NSString stringWithFormat:@"Building package %@", MakeNSString(packageNameStr)]];

		// clear parts array
		self.parts = [[NSMutableArray alloc] init];

		// build parts with appropriate pointer ref alignment
		int alignment = NOTNIL(GetFrameSlot(packageSettings, MakeSymbol("fourByteAlignment"))) ? 4 : 8;

		int partType = RINT(GetFrameSlot(outputSettings, SYMA(partType)));
		switch (partType) {
		case kOutputStreamFile:
			{
				// this one’s a bit different -- it doesn’t generate a package
				// evaluate all sources
				[self evaluate];

				// get the result
				RefVar resultSlot(GetFrameSlot(outputSettings, MakeSymbol("topFrameExpression")));
				RefVar result(GetFrameSlot(RA(gVarFrame), FIntern(RA(NILREF), resultSlot)));
				// flatten to stream file
				NSURL * streamURL = [self.fileURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"newtonstream"];
				CStdIOPipe pipe(streamURL.fileSystemRepresentation, "w");
				FlattenRef(result, pipe);
			}
			break;

		case kOutputApplication:
			{
				// evaluate all sources
				[self evaluate];
				// if there was an exception/error then bail now

				RefVar partFrame(AllocateFrame());
				// set the usual slots
				SetFrameSlot(partFrame, SYMA(text), GetFrameSlot(RA(gConstantsFrame), MakeSymbol("kAppName")));
				SetFrameSlot(partFrame, SYMA(app), GetFrameSlot(RA(gConstantsFrame), MakeSymbol("kAppSymbol")));
				//icon
				//theForm

				// copy global InstallScript and RemoveScript, if they exist, to the part frame
				RefVar devGlobal;
				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(InstallScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(partFrame, SYMA(devInstallScript), devGlobal);
				SetFrameSlot(partFrame, SYMA(InstallScript), RA(formInstallScript));

				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(RemoveScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(partFrame, SYMA(devRemoveScript), devGlobal);
				SetFrameSlot(partFrame, SYMA(RemoveScript), RA(formRemoveScript));

				// copy slots from global partFrame, if it exists, to the part frame
				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(partFrame));
				if (IsFrame(devGlobal)) {
					FOREACH_WITH_TAG(devGlobal, tag, value)
						SetFrameSlot(partFrame, tag, value);
					END_FOREACH;
				}
				[self.parts addObject:[[NTXPackagePart alloc] initWith:partFrame type:"form" alignment:alignment]];
			}
			break;

		case kOutputAutoPart:
			{
				// evaluate all sources
				[self evaluate];

				RefVar partFrame(AllocateFrame());
				RefVar devGlobal;
				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(InstallScript));
				if (NOTNIL(devGlobal)) {
					SetFrameSlot(partFrame, SYMA(devInstallScript), devGlobal);
					SetFrameSlot(partFrame, SYMA(InstallScript), RA(autoInstallScript));
				}
				// else should probably warn user
				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(RemoveScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(partFrame, SYMA(devRemoveScript), devGlobal);
				// copy global partData, if it exists, to the part frame .partData
				devGlobal = GetFrameSlot(RA(gVarFrame), SYMA(partData));
				if (NOTNIL(devGlobal))
					SetFrameSlot(partFrame, SYMA(partData), devGlobal);
				[self.parts addObject:[[NTXPackagePart alloc] initWith:partFrame type:"auto" alignment:alignment]];
			}
			break;

		case kOutputBook:
	//		TBD
			break;

		case kOutputStorePart:
			{
	//		create global theStore
				// evaluate all sources (which presumably write to theStore)
				[self evaluate];

	// create 2 parts
	// 1: kNOSPart {} type=0
				RefVar partFrame(AllocateFrame());
				[self.parts addObject:[[NTXPackagePart alloc] initWith:partFrame type:NULL alignment:alignment]];

	// 2: kRawPart+kNotifyFlag type=soup
	//   info=copy of part0 info
	//   raw data=PSS objects
				[self.parts addObject:[[NTXPackagePart alloc] initWithRawData:NULL size:0 type:"soup"]];
			}
			break;

		case kOutputCustomPart:
			{
				// evaluate all sources
				[self evaluate];

				// result: top level frame is (outputSettings.topFrameExpression)
				RefVar topFrameSlot(GetFrameSlot(outputSettings, MakeSymbol("topFrameExpression")));
				RefVar partFrame(GetFrameSlot(RA(gVarFrame), FIntern(RA(NILREF), topFrameSlot)));
				RefVar customPartType(GetFrameSlot(outputSettings, MakeSymbol("customPartType")));
				char customPartTypeStr[8];
				ConvertFromUnicode(GetUString(customPartType), customPartTypeStr);
				[self.parts addObject:[[NTXPackagePart alloc] initWith:partFrame type:customPartTypeStr alignment:alignment]];
			}
			break;
		}
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;
		self.parts = nil;
	}
	end_try;

	// package up the part and write out the package file
	NSURL * pkgURL = nil;
	if (self.parts != nil && self.parts.count > 0) {
		// build package directory, part entries, etc
		NSData * pkgData = [self buildPackageData];
		if (pkgData) {
			// write to package file
			NSError *__autoreleasing err = nil;
			pkgURL = [self.fileURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"newtonpkg"];
			if ([pkgData writeToURL:pkgURL options:0 error:&err]) {
				[self report:@"Build successful"];
			} else {
				[self report:[NSString stringWithFormat:@"Failed to save package: %@", err.localizedDescription]];
			}
		}
	}

	// can finally dispose the build heap
	gHeap = saveHeap;
	delete buildHeap;

	if (err)
		[self report:[NSString stringWithFormat:@"Build failed: %d", err]];
	return pkgURL;
}


/* -----------------------------------------------------------------------------
	Package Format
	Baasically:
		header
			directory struct
			array of part entry structs
			directory data
		relocation info (optional)
		part data
	see Newton Formats, 1-4
	also PackageManager.cc : CPrivatePackageIterator

	when building, we need to:
		build array of parts
			main part 0 is result of build
			other parts are contained in packages in the project

	NOTE
		we’re going to need to big-endian all this

----------------------------------------------------------------------------- */
const char * const kPackageMagicNumber = "package01";

- (NSData *)buildPackageData {
	RefVar pkgSettings(GetFrameSlot(_projectRef, MakeSymbol("packageSettings")));
	RefVar copyrightStr(GetFrameSlot(pkgSettings, MakeSymbol("copyright")));
	RefVar packageNameStr(GetFrameSlot(pkgSettings, MakeSymbol("packageName")));

	ArrayIndex copyrightStrLen = Length(copyrightStr);
	ArrayIndex nameStrLen = Length(packageNameStr);

//	alloc directory as NSMutableData; can later -writeToURL:
	NSMutableData * pkgData = [[NSMutableData alloc] initWithLength:sizeof(PackageDirectory)];
// fill in directory
	PackageDirectory * dir = (PackageDirectory *)pkgData.mutableBytes;
	memcpy(dir->signature, kPackageMagicNumber, sizeof(dir->signature));
	memcpy(&dir->id, "xxxx", sizeof(dir->id));

	dir->flags = 0;
	if (NOTNIL(GetFrameSlot(pkgSettings, MakeSymbol("dispatchOnly")))) dir->flags |= kAutoRemoveFlag;
	if (NOTNIL(GetFrameSlot(pkgSettings, MakeSymbol("copyProtected")))) dir->flags |= kCopyProtectFlag;
	if ( ISNIL(GetFrameSlot(pkgSettings, MakeSymbol("optimizeSpeed")))) dir->flags |= kNoCompressionFlag;
	if (NOTNIL(GetFrameSlot(pkgSettings, MakeSymbol("zippyCompression")))) dir->flags |= kUseFasterCompressionFlag;

	RefVar versionStr(GetFrameSlot(pkgSettings, MakeSymbol("version")));
	char verStrBuf[16];
	ConvertFromUnicode((UniChar *)BinaryData(versionStr), verStrBuf);
	// convert to int
	dir->version = atoi(verStrBuf);
	dir->copyright.offset = 0;
	dir->copyright.length = copyrightStrLen;
	dir->name.offset = copyrightStrLen;
	dir->name.length = nameStrLen;
	dir->size = 0;								//	total size of package including this directory
	dir->creationDate = MakeDateType([NSDate date]);
	dir->modifyDate = 0;
	dir->directorySize = 0;					//	size of this directory including part entries & data
	dir->numParts = self.parts.count;

//	create part entries
	for (NTXPackagePart * part in self.parts) {
		// append part entry
		[pkgData appendBytes:part.entry length:sizeof(PartEntry)];
	}

//	add variable length part info
// firstly, copyright and name Unicode strings
#if defined(hasByteSwapping)
	[pkgData appendBytes:"" length:1];
	[pkgData appendBytes:GetUString(copyrightStr) length:copyrightStrLen-1];
	[pkgData appendBytes:"" length:1];
	[pkgData appendBytes:GetUString(packageNameStr) length:nameStrLen-1];
#else
	[pkgData appendBytes:GetUString(copyrightStr) length:copyrightStrLen];
	[pkgData appendBytes:GetUString(packageNameStr) length:nameStrLen];
#endif

	ULong partInfoOffset = copyrightStrLen + nameStrLen;
	ULong partDataOffset = 0;
	for (NTXPackagePart * part in self.parts) {
		[pkgData appendBytes:part.info length:part.infoLen];
		[part updateInfoOffset:&partInfoOffset dataOffset:&partDataOffset];
	}

// long-align pkgData
	NSUInteger misalignment = pkgData.length & 3;
	if (misalignment)
		[pkgData increaseLengthBy:4-misalignment];

// backpatch dir.directorySize
	dir = (PackageDirectory *)pkgData.mutableBytes;	// data may have moved
	dir->directorySize = pkgData.length;

// ignore relocation data for now -- we don’t do native funcs
//	for (NTXPackagePart * part in parts) {
//		[pkgData appendBytes:part.relocationData length:part.relocationDataLen];
//	}

//	add part data
	for (NTXPackagePart * part in self.parts) {
		// long-align pkgData
		misalignment = pkgData.length & 3;
		if (misalignment)
			[pkgData increaseLengthBy:4-misalignment];
		[part buildPartData:pkgData.length];
		[pkgData appendBytes:part.data length:part.dataLen];
	}

// backpatch dir.size
	dir = (PackageDirectory *)pkgData.mutableBytes;	// data may have moved
	dir->size = pkgData.length;

#if defined(hasByteSwapping)
	dir->id = BYTE_SWAP_LONG(dir->id);
	dir->flags = BYTE_SWAP_LONG(dir->flags);
	dir->version = BYTE_SWAP_LONG(dir->version);
	dir->copyright.offset = BYTE_SWAP_SHORT(dir->copyright.offset);
	dir->copyright.length = BYTE_SWAP_SHORT(dir->copyright.length);
	dir->name.offset = BYTE_SWAP_SHORT(dir->name.offset);
	dir->name.length = BYTE_SWAP_SHORT(dir->name.length);
	dir->size = BYTE_SWAP_LONG(dir->size);
	dir->creationDate = BYTE_SWAP_LONG(dir->creationDate);
	dir->modifyDate = BYTE_SWAP_LONG(dir->modifyDate);
	dir->directorySize = BYTE_SWAP_LONG(dir->directorySize);
	dir->numParts = BYTE_SWAP_LONG(dir->numParts);
#endif

// return immutable package data
	return [NSData dataWithData:pkgData];
}

@end


#pragma mark - NTXPackagePart
/* -----------------------------------------------------------------------------
	N T X P a c k a g e P a r t
----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
	Calculate space needed for 32-bit Ref.
	Args:		inRef				the ref
				ioMap				set of Refs already visited
				inAlignment		4 or 8-byte alignment
	Return:	memory requirement of 32-bit Ref
----------------------------------------------------------------------------- */
#include "unordered_set"
typedef std::unordered_set<Ref> RefScanMap;

size_t
ScanRef(Ref inRef, RefScanMap &ioMap, int inAlignment)
{
	if (ISREALPTR(inRef)) {
		if (ioMap.count(inRef) > 0) {
			// ignore this object if it has already been scanned
			return 0;
		}
		ioMap.insert(inRef);

		ArrayObject * obj = (ArrayObject *)ObjectPtr(inRef);
		// we call it an ArrayObject, but all objects share the header/class which is all we’re really interested in
		size_t refSize = sizeof(ArrayObject32);
		// for frames, class is actually the map which needs fixing too
		refSize += ScanRef(obj->objClass, ioMap, inAlignment);

		//	if it’s a frame / array, step through each slot / element adding space for those
		if ((obj->flags & kObjSlotted) != 0) {
			Ref * refPtr = obj->slot;
			for (ArrayIndex count = (obj->size - sizeof(ArrayObject)) / sizeof(Ref); count > 0; --count, ++refPtr) {
				refSize += sizeof(Ref32) + ScanRef(*refPtr, ioMap, inAlignment);
			}
		} else {
			refSize += (obj->size - sizeof(BinaryObject));
		}
		return ALIGN(refSize, inAlignment);
	}
	// else it’s an immediate which requires no additional space
	return 0;
}


/*------------------------------------------------------------------------------
	Copy 64-bit Ref object tree to big-endian 32-bit Ref object tree.
	Source is a pointer ref -> 1-element array -> top part expression.

	Args:		inRef				64-bit Ref
				inDstPtr			pointer to 32-bit pointer Ref object
				ioMap				map of 64-bit pointer Ref to 32-bit offset Ref
				inBaseAddr		base address of package from which refs are offsets
				inAlignment		4 or 8-byte alignment
	Return:	32-bit big-endian (package-relative if pointer) ref
------------------------------------------------------------------------------*/

#if defined(hasByteSwapping)
bool
IsObjClass(Ref obj, const char * inClassName)
{
	if (ISPTR(obj) && ((SymbolObject *)ObjectPtr(obj))->objClass == kSymbolClass) {
		const char * subName = SymbolName(obj);
		for ( ; *subName && *inClassName; subName++, inClassName++) {
			if (tolower(*subName) != tolower(*inClassName)) {
				return false;
			}
		}
		return (*inClassName == 0 && (*subName == 0 || *subName == '.'));
	}
	return false;
}
#endif


#include <map>
typedef std::map<Ref, Ref32> RefOffsetMap;

Ref32
FixUpRef(Ref inRef, ArrayObject32 * &ioObjPtr, char * inBasePtr, RefOffsetMap &ioMap, int inAlignment)
{
	if (ISREALPTR(inRef)) {
		Ref32 ref;
		RefOffsetMap::iterator findMapping = ioMap.find(inRef);
		if (findMapping != ioMap.end()) {
			// we have already fixed up this ref -- return its package-relative offset ref
			return findMapping->second;
		}
		// map 64-bit pointer ref -> 32-bit big-endian package-relative pointer ref
		ref = REF((char *)ioObjPtr - inBasePtr);
		std::pair<Ref, Ref32> mapping = std::make_pair(inRef, CANONICAL_LONG(ref));
		ioMap.insert(mapping);

		ArrayObject * srcPtr = (ArrayObject *)ObjectPtr(inRef);	// might not actually be an ArrayObject, but header/class are common to all pointer objects
		// first, remember THIS dst object
		ArrayObject32 * dstPtr = ioObjPtr;

		ArrayIndex count;
		size_t dstSize;
		if ((srcPtr->flags & kObjSlotted)) {
			//	work out size for 32-bit Ref slots
			count = (srcPtr->size - sizeof(ArrayObject)) / sizeof(Ref);
			dstSize = sizeof(ArrayObject32) + count * sizeof(Ref32);
		} else {
			// adjust for change in header size
			dstSize = srcPtr->size - sizeof(ArrayObject) + sizeof(ArrayObject32);
		}
		dstPtr->size = CANONICAL_SIZE(dstSize);
		dstPtr->flags = kObjReadOnly | (srcPtr->flags & kObjMask);
		dstPtr->gc.stuff = 0;

		//	update/align ioObjPtr to next object
		ioObjPtr = (ArrayObject32 *)((char *)ioObjPtr + ALIGN(dstSize, inAlignment));
		// for frames, class is actually the map which needs fixing too; non-slotted refs may need byte-swapping anyway so we always need to do this
		dstPtr->objClass = FixUpRef(srcPtr->objClass, ioObjPtr, inBasePtr, ioMap, inAlignment);

		if ((srcPtr->flags & kObjSlotted)) {
			//	iterate over src slots; fix them up
			Ref * srcRefPtr = srcPtr->slot;
			Ref32 * dstRefPtr = dstPtr->slot;
			for ( ; count > 0; --count, ++srcRefPtr, ++dstRefPtr) {
				*dstRefPtr = FixUpRef(*srcRefPtr, ioObjPtr, inBasePtr, ioMap, inAlignment);
			}
		} else {
			memcpy(dstPtr->slot, srcPtr->slot, dstSize - sizeof(ArrayObject32));
#if defined(hasByteSwapping)
			if (srcPtr->objClass == kSymbolClass) {
				// symbol -- byte-swap hash
				SymbolObject32 * sym = (SymbolObject32 *)dstPtr;
				sym->hash = BYTE_SWAP_LONG(sym->hash);
//NSLog(@"'%s", sym->name);
			} else if (IsObjClass(srcPtr->objClass, "string")) {
				// string -- byte-swap UniChar characters
				UniChar * s = (UniChar *)dstPtr->slot;
				for (count = (dstSize - sizeof(StringObject32)) / sizeof(UniChar); count > 0; --count, ++s)
					*s = BYTE_SWAP_SHORT(*s);
//NSLog(@"\"%@\"", [NSString stringWithCharacters:(const UniChar *)srcPtr->slot length:(dstSize - sizeof(StringObject32)) / sizeof(UniChar)]);
			} else if (IsObjClass(srcPtr->objClass, "real")) {
				// real number -- byte-swap 64-bit double
				uint32_t tmp;
				uint32_t * dbp = (uint32_t *)dstPtr->slot;
				tmp = BYTE_SWAP_LONG(dbp[1]);
				dbp[1] = BYTE_SWAP_LONG(dbp[0]);
				dbp[0] = tmp;
			} else if (IsObjClass(srcPtr->objClass, "UniC")) {
				// EncodingMap -- byte-swap UniChar characters
				UShort * table = (UShort *)dstPtr->slot;
				UShort formatId, unicodeTableSize;

				*table = formatId = BYTE_SWAP_SHORT(*table), ++table;
				if (formatId == 0) {
					// it’s 8-bit to UniCode
					*table = unicodeTableSize = BYTE_SWAP_SHORT(*table), ++table;
					*table = BYTE_SWAP_SHORT(*table), ++table;		// revision
					*table = BYTE_SWAP_SHORT(*table), ++table;		// tableInfo
					for (ArrayIndex i = 0; i < unicodeTableSize; ++i, ++table) {
						*table = BYTE_SWAP_SHORT(*table);
					}
				} else if (formatId == 4) {
					// it’s UniCode to 8-bit
					*table = BYTE_SWAP_SHORT(*table), ++table;		// revision
					*table = BYTE_SWAP_SHORT(*table), ++table;		// tableInfo
					*table = unicodeTableSize = BYTE_SWAP_SHORT(*table), ++table;
					for (ArrayIndex i = 0; i < unicodeTableSize*3; ++i, ++table) {
						*table = BYTE_SWAP_SHORT(*table);
					}
				}
			}
#endif
		}
		ref = REF((char *)dstPtr - inBasePtr);
		return CANONICAL_LONG(ref);
	}
	return CANONICAL_LONG(inRef);
}


#define kInfoStr "Newton Toolkit 1.6.4; platform file Newton 2.1 v5"
#define kInfoStrLen 50

@implementation NTXPackagePart

- (id)initWithRawData:(const void *)content size:(int)contentSize type:(const char *)type {
	if (self = [super init]) {
		_dirEntry.type = type ? *(ULong *)type : 0;
		_dirEntry.flags = kRawPart + kNotifyFlag;
		infoStr = nil;
		_dirEntry.info.length = self.infoLen;
		_dirEntry.size = contentSize;
		partRoot = (ArrayObject32 *)content;
	}
	return self;
}


- (id)initWith:(RefArg)content type:(const char *)type alignment:(int)inAlignment {
	if (self = [super init]) {
		_dirEntry.type = type ? *(ULong *)type : 0;
		_dirEntry.flags = kNOSPart;
		infoStr = nil;
		_dirEntry.info.length = self.infoLen;

/*
	From “Newton Formats 1.1”, 1-16:
	The first object in the part is used to locate the part frame.
	It is required to be an array of class NIL with one slot, which points to the part frame.
	In OS 2.0, the low-order bit of the second long of this array—normally set to zero in all objects—is used as an alignment flag.
	If the bit is set, the objects in the part are padded to four-byte boundaries. Otherwise, the objects are padded to eight-byte boundaries.
	Only eight-byte-aligned parts can be used on Newton OS versions prior to 2.0.
*/
		_partData = MakeArray(1);
		SetClass(_partData, RA(NILREF));
		SetArraySlot(_partData, 0, content);
		_alignment = inAlignment;

		// calculate size for 32-bit refs
		RefScanMap map;
		_dirEntry.size = ScanRef(_partData, map, _alignment);

		// build part data later
		partRoot = NULL;
	}
	return self;
}


- (void)updateInfoOffset:(ULong *)ioInfoOffset dataOffset:(ULong *)ioDataOffset {
	_dirEntry.info.offset = *ioInfoOffset;  *ioInfoOffset += _dirEntry.info.length;
	_dirEntry.offset = *ioDataOffset;  *ioDataOffset += _dirEntry.size;
}


- (void)buildPartData:(NSUInteger)inBaseOffset {
	// alloc 32-bit part data
	partRoot = (ArrayObject32 *)malloc(_dirEntry.size);
	if (partRoot == NULL) {
		// report error
		return;
	}

	// copy partData array Ref object to 32-bit big-endian .offset-relative-addressed object tree
	ArrayObject32 * objPtr = partRoot;
	RefOffsetMap map;
	FixUpRef(_partData, objPtr, (char *)partRoot - inBaseOffset, map, _alignment);

	if (_alignment == 4) {
		partRoot->gc.stuff = CANONICAL_LONG(k4ByteAlignmentFlag);
	}
}


- (PartEntry *)entry {
#if defined(hasByteSwapping)
	static PartEntry pe = _dirEntry;
	pe.offset = BYTE_SWAP_LONG(pe.offset);
	pe.size = BYTE_SWAP_LONG(pe.size);
	pe.size2 = pe.size;
	pe.flags = BYTE_SWAP_LONG(pe.flags);
	pe.info.offset = BYTE_SWAP_SHORT(pe.info.offset);
	pe.info.length = BYTE_SWAP_SHORT(pe.info.length);
	pe.compressor.offset = BYTE_SWAP_SHORT(pe.compressor.offset);
	pe.compressor.length = BYTE_SWAP_SHORT(pe.compressor.length);
	return &pe;
#else
	_dirEntry.size2 = _dirEntry.size;
	return &_dirEntry;
#endif
}

- (const char *)info {
	if (infoStr == nil) {
		RefVar pf(GetFrameSlot(RA(gConstantsFrame), MakeSymbol("platformVersion")));
		NSString * platformVerStr1 = MakeNSSymbol(GetFrameSlot(pf, MakeSymbol("platformFile")));
		NSString * platformVerStr2 = MakeNSSymbol(GetFrameSlot(pf, SYMA(version)));
		NSString * toolkitVerStr = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		infoStr = [NSString stringWithFormat:@"Newton Toolkit %@; platform file %@ %@", toolkitVerStr, platformVerStr1, platformVerStr2].UTF8String;
	}
	return infoStr;
}

- (NSUInteger)infoLen {
	return strlen(self.info);
}

- (const void *)data {
	return partRoot;
}

- (NSUInteger)dataLen {
	return _dirEntry.size;
}

- (const void *)relocationData {
	return NULL;
}

- (NSUInteger)relocationDataLen {
	return 0;
}

@end
