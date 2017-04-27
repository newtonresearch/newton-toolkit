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
#import "NTK/Globals.h"

extern "C" Ref		FIntern(RefArg rcvr, RefArg inStr);
extern "C" Ref		ArrayInsert(RefArg ioArray, RefArg inObj, ArrayIndex index);
extern	  Ref		MakeStringOfLength(const UniChar * str, ArrayIndex numChars);
extern	  Ref		MakeStringFromUTF8String(const char * inStr);
extern	  Ref		ParseString(RefArg inStr);

extern NSString *	MakeNSSymbol(RefArg inSym);
extern Ref			GetGlobalConstant(RefArg inTag);
extern Ref			GetAllGlobalConstants(void);


extern Ref *		RSformInstallScript;
extern Ref *		RSformRemoveScript;
extern Ref *		RSautoInstallScript;

DeclareException(exCompilerData, exCompiler);


#pragma mark - NTXProjectDocument
/* -----------------------------------------------------------------------------
	N T X P r o j e c t D o c u m e n t
----------------------------------------------------------------------------- */

inline Ref SetPartFrameSlot(RefArg inTag, RefArg inValue) {
	return NSCallGlobalFn(SYMA(SetPartFrameSlot), inTag, inValue);
/*
func(slot, value)
begin
if not GlobalVarExists('partFrame) then
	DefGlobalVar('partFrame, {});
GetGlobalVar('partFrame).(slot) := value;
end
*/
}

inline Ref GetPartFrameSlot(RefArg inTag) {
	return NSCallGlobalFn(SYMA(GetPartFrameSlot), inTag);
/*
func(slot)
begin
if GlobalVarExists('partFrame) then
	GetGlobalVar('partFrame).(slot);
end
*/
}


/*------------------------------------------------------------------------------
	Define global constant for build.
	Args:		inSym			global var
				inVal			its value
	Return:	--
------------------------------------------------------------------------------*/
extern "C" {
Ref	FDefineGlobalConstant(RefArg rcvr, RefArg inTag, RefArg inObj);
Ref	FUnDefineGlobalConstant(RefArg rcvr, RefArg inTag);
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
//NSLog(@"MakeDateType(%@) -> %u", [inDate description], kSecondsSince1904 + (Date)inDate.timeIntervalSince1970);
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
	Initialize.
	Initialize the projectRef with default values -- can be used for a new
	document.
----------------------------------------------------------------------------- */

- (id)init {
	if (self = [super init]) {
	//	stream in default project settings
		NSURL * url = [NSBundle.mainBundle URLForResource: @"CanonicalProject" withExtension: @"newtonstream"];
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
}


/* -----------------------------------------------------------------------------
	Return the window frame.
	We expect the caller to make any conversion from window to content frame.
----------------------------------------------------------------------------- */

- (NSRect)windowFrame {
	NSRect theFrame = NSMakeRect(100, 100, 720, 360);
	newton_try {
		RefVar windowRect = GetFrameSlot(self.projectRef, MakeSymbol("windowRect"));
		if (NOTNIL(windowRect)) {
			// windowRect is a frame: { top:x, left:x, right:x, bottom:x }
			int top = RINT(GetFrameSlot(windowRect, SYMA(top)));
			int left = RINT(GetFrameSlot(windowRect, SYMA(left)));
			int bottom = RINT(GetFrameSlot(windowRect, SYMA(bottom)));
			int right = RINT(GetFrameSlot(windowRect, SYMA(right)));

			// if bottom > top the origin is top-left
			if (bottom > top) {
				// we need origin bottom-left
				int screenHeight = NSScreen.mainScreen.frame.size.height;
				top = screenHeight - top;
				bottom = screenHeight - bottom;
			}
			theFrame.origin.x = left;
			theFrame.origin.y = bottom;
			theFrame.size.width = right - left;
			theFrame.size.height = top - bottom;
		} else {
			theFrame.origin.y = NSScreen.mainScreen.frame.size.height - theFrame.origin.y - theFrame.size.height;
		}
	}
	newton_catch_all {
	}
	end_try;

	return theFrame;
}

/* -----------------------------------------------------------------------------
	Set the window frame.
	We expect the caller to have already made any conversion from content to
	window frame.
	This will save the frame in CG coordinates, ie wrt bottom-left of display.
----------------------------------------------------------------------------- */
#define canonicalRect MAKEMAGICPTR(36)

- (void)setWindowFrame:(NSRect)frame {
	RefVar windowRect(Clone(canonicalRect));
	SetFrameSlot(windowRect, SYMA(top), MAKEINT(frame.origin.y + frame.size.height));
	SetFrameSlot(windowRect, SYMA(left), MAKEINT(frame.origin.x));
	SetFrameSlot(windowRect, SYMA(bottom), MAKEINT(frame.origin.y));
	SetFrameSlot(windowRect, SYMA(right), MAKEINT(frame.origin.x + frame.size.width));

	SetFrameSlot(self.projectRef, MakeSymbol("windowRect"), windowRect);
	[self updateChangeCount:NSChangeDone];
}


/* -----------------------------------------------------------------------------
	Do the same for window split poitions.
----------------------------------------------------------------------------- */

- (NSArray<NSNumber*> *)windowSplits {
	NSMutableArray<NSNumber*> * theSplits = [[NSMutableArray alloc] init];
	newton_try {
		RefVar windowSplits = GetFrameSlot(self.projectRef, MakeSymbol("windowSplits"));
		if (NOTNIL(windowSplits)) {
			// windowSplits is an array: [ split-width, split-isCollapsed,... ]
			for(ArrayIndex i = 0, count = Length(windowSplits); i < count; ++i) {
				Ref value = GetArraySlot(windowSplits, i);
				if ((i & 1) == 0) {
					[theSplits addObject:[NSNumber numberWithInt:RINT(value)]];
				} else {
					[theSplits addObject:[NSNumber numberWithBool:NOTNIL(value)]];
				}
			}
		}
	}
	newton_catch_all {
	}
	end_try;

	return theSplits;
}

- (void)setWindowSplits:(NSArray<NSNumber*> *)splits {
	RefVar splitPositions(MakeArray(0));

	ArrayIndex i = 0;
	for (NSNumber * item in splits) {
		if ((i & 1) == 0) {
			AddArraySlot(splitPositions, MAKEINT(item.intValue));
		} else {
			AddArraySlot(splitPositions, MAKEBOOLEAN(item.boolValue));
		}
		++i;
	}

	SetFrameSlot(self.projectRef, MakeSymbol("windowSplits"), splitPositions);
	[self updateChangeCount:NSChangeDone];
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
		NTXRsrcProject * data = [[NTXRsrcProject alloc] initWithURL:url];
		if (data) {
			// the file appears to be a Mac NTK project
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
				if (NOTNIL(GetFrameSlot(projItem, MakeSymbol("isMainLayout")))) {
					projectItem.isMainLayout = YES;
				}
				if (NOTNIL(GetFrameSlot(projItem, MakeSymbol("isExcluded")))) {
					projectItem.isExcluded = YES;
				}
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
	END_FOREACH

	Ref selection;
	NSInteger selItem = NOTNIL(selection = GetFrameSlot(projectItemsRef, MakeSymbol("selectedItem"))) ? RINT(selection) : -1;
	NSInteger sortOrder = NOTNIL(selection = GetFrameSlot(projectItemsRef, MakeSymbol("sortOrder"))) ? RINT(selection) : -1;

	self.projectItems = [NSMutableDictionary dictionaryWithDictionary:
									@{ @"selectedItem":[NSNumber numberWithInteger:selItem],
										@"sortOrder":[NSNumber numberWithInteger:sortOrder],
										@"items":projItems }];
}


/* -----------------------------------------------------------------------------
	Return an array of NTXProjectItem that are userProto layouts in the project.
----------------------------------------------------------------------------- */

- (NSArray<NTXProjectItem*> *)userProtos {
	NSMutableArray<NTXProjectItem*> * thoseProtos = [[NSMutableArray alloc] init];
	for (NTXProjectItem * item in [self.projectItems objectForKey:@"items"]) {
		if (item.isLayout) {
			NTXLayoutDocument * document = (NTXLayoutDocument *)item.document;
			if (document.layoutType == kUserProtoLayoutType) {
				[thoseProtos addObject:item];
			}
		}
	}
	return thoseProtos;
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
		if (sourceItem.isMainLayout) {
			SetFrameSlot(item, MakeSymbol("isMainLayout"), MAKEBOOLEAN(true));
		}
		if (sourceItem.isExcluded) {
			SetFrameSlot(item, MakeSymbol("isExcluded"), MAKEBOOLEAN(true));
		}
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

			[NTXLayoutDocument startBuild];	// yep, even though we’re only exporting
			for (NTXProjectItem * item in [self.projectItems objectForKey:@"items"])
			{
				[self report:[NSString stringWithFormat:@"Exporting %@ to text", item.name]];
				[item.document exportToText:fp error:&err];
				if (err) {
					break;
				}
			}
			[NTXLayoutDocument finishBuild];
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


- (IBAction)saveAllProjectItems:(id)sender {

	for (NTXProjectItem * item in self.projectItems[@"items"]) {
		[item.document saveDocument:self];
	}
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
	[self buildPkg];
}


/* -----------------------------------------------------------------------------
	Build the current project and download it to Newton device.
	Args:		sender
	Return:	--
----------------------------------------------------------------------------- */

- (IBAction)downloadPackage:(id)sender {
	NSURL * pkg = [self buildPkg];
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
	Return:	the main layout, or NILREF
				errors will be thrown
----------------------------------------------------------------------------- */

- (Ref)evaluate {
	RefVar mainLayout;
	[NTXLayoutDocument startBuild];
	for (NTXProjectItem * item in [self.projectItems objectForKey:@"items"]) {
		if (!item.isExcluded) {
			RefVar result([item build]);
			if (item.isMainLayout) {
				mainLayout = result;
			}
		}
	}
	[NTXLayoutDocument finishBuild];
	return mainLayout;
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
extern Ref ForwardReference(Ref r);

- (NSURL *)buildPkg {
	// sync our projectItems with source list
	[self updateProjectItems];

	// get settings frames
	RefVar projectSettings(GetFrameSlot(_projectRef, MakeSymbol("projectSettings")));
	RefVar profilerSettings(GetFrameSlot(_projectRef, MakeSymbol("profilerSettings")));
	RefVar packageSettings(GetFrameSlot(_projectRef, MakeSymbol("packageSettings")));
	RefVar outputSettings(GetFrameSlot(_projectRef, MakeSymbol("outputSettings")));

	// youy can’t just set a separate build heap (even though the original does so somehow)
//	int buildHeapSize = [NSUserDefaults.standardUserDefaults integerForKey:@"BuildHeapSize"] * KByte;
//	CObjectHeap * buildHeap = new CObjectHeap(buildHeapSize);
	// because creating a new CObjectHeap changes objRoot and leaves the vars obj dangling
	// it might be thought through, but for now we’ll just use the same BIG heap and remove afterwards whatever we created during the build

	RefVar origVars(Clone(gVarFrame));
	RefVar origConsts(GetAllGlobalConstants());
	// set build constants -- should we really be doing this in a build-constants frame?
	DefConst("kAppName", GetFrameSlot(outputSettings, MakeSymbol("applicationName")));			// string
	DefConst("kAppSymbol", FIntern(RA(NILREF), GetFrameSlot(outputSettings, MakeSymbol("applicationSymbol"))));	// symbol
	DefConst("kAppString", GetFrameSlot(outputSettings, MakeSymbol("applicationSymbol")));		// string
	DefConst("kPackageName", GetFrameSlot(packageSettings, MakeSymbol("packageName")));		// string
	DefConst("kDebugOn", GetFrameSlot(projectSettings, MakeSymbol("debugBuild")));					// boolean
	DefConst("kProfileOn", GetFrameSlot(profilerSettings, MakeSymbol("compileForProfiling")));		// boolean
	DefConst("kIgnoreNativeKeyword", GetFrameSlot(projectSettings, MakeSymbol("ignoreNative")));		// boolean
	DefConst("home", MakeStringFromUTF8String(self.fileURL.URLByDeletingLastPathComponent.fileSystemRepresentation));	// string
	DefConst("language", GetFrameSlot(projectSettings, MakeSymbol("language")));		// string
	// some more undocumented constants for the compiler
	DefConst("kCheckGlobalFunctions", GetFrameSlot(projectSettings, MakeSymbol("checkGlobalFunctions")));
	DefConst("kOldBuildRules", GetFrameSlot(projectSettings, MakeSymbol("oldBuildRules")));
	DefConst("kUseStepChildren", GetFrameSlot(projectSettings, MakeSymbol("useStepChildren")));
	DefConst("kSuppressByteCodes", GetFrameSlot(projectSettings, MakeSymbol("suppressByteCodes")));
	DefConst("kFasterFunctions", GetFrameSlot(projectSettings, MakeSymbol("fasterFunctions")));

	// as build progresses it may add globals:
	//	PT_<filename>
	//	layout_<filename>, thisView
	//	streamFile_<filename>
	// partFrame, InstallScript, RemoveScript

	// say what we’re doing
	RefVar packageNameStr(GetFrameSlot(packageSettings, MakeSymbol("packageName")));
	[self report:[NSString stringWithFormat:@"Building package %@", MakeNSString(packageNameStr)]];

	// build parts with appropriate pointer ref alignment
	int alignment = NOTNIL(GetFrameSlot(packageSettings, MakeSymbol("fourByteAlignment"))) ? 4 : 8;

	// clear parts array
	self.parts = [[NSMutableArray alloc] init];

	NewtonErr err = noErr;
	newton_try
	{
		int partType = RINT(GetFrameSlot(outputSettings, SYMA(partType)));
		switch (partType) {
		case kOutputStreamFile:
			{
				// this one’s a bit different -- it doesn’t generate a package
				// evaluate all sources
				[self evaluate];

				// get the result
				RefVar resultSlot(GetFrameSlot(outputSettings, MakeSymbol("topFrameExpression")));
				RefVar result(GetGlobalVar(FIntern(RA(NILREF), resultSlot)));
				// flatten to stream file
				NSURL * streamURL = [self.fileURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"newtonstream"];
				CStdIOPipe pipe(streamURL.fileSystemRepresentation, "w");
				FlattenRef(result, pipe);
				[self report:@"Build successful"];
			}
			break;

		case kOutputApplication:
			{
				NSCallGlobalFn(SYMA(UnDefGlobalVar), SYMA(partFrame));

				// evaluate all sources
				RefVar theForm([self evaluate]);
				// if there was an exception/error then bail now
				// NTK seems to do this:
				SetFrameSlot(theForm, SYMA(appSymbol), GetGlobalConstant(MakeSymbol("kAppSymbol")));

				// set the usual slots
				RefVar privatePartFrame(AllocateFrame());
				SetFrameSlot(privatePartFrame, SYMA(app), GetGlobalConstant(MakeSymbol("kAppSymbol")));
				SetFrameSlot(privatePartFrame, SYMA(text), GetGlobalConstant(MakeSymbol("kAppName")));
				//icon

				RefVar devGlobal;
				// if slots were added to the global partFrame, copy them to our part frame
				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(partFrame));
				if (IsFrame(devGlobal)) {
					FOREACH_WITH_TAG(devGlobal, tag, value)
						SetFrameSlot(privatePartFrame, tag, value);
					END_FOREACH
				}

				// copy the main layout to the part frame
				if (NOTNIL(theForm)) {
					SetFrameSlot(privatePartFrame, SYMA(theForm), theForm);
				}

				// copy global InstallScript and RemoveScript, if they exist, to the part frame
				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(InstallScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(privatePartFrame, SYMA(devInstallScript), devGlobal);
				SetFrameSlot(privatePartFrame, SYMA(InstallScript), RA(formInstallScript));

				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(RemoveScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(privatePartFrame, SYMA(devRemoveScript), devGlobal);
				SetFrameSlot(privatePartFrame, SYMA(RemoveScript), RA(formRemoveScript));

				[self.parts addObject:[[NTXPackagePart alloc] initWith:privatePartFrame type:"form" alignment:alignment]];
				NSCallGlobalFn(SYMA(UnDefGlobalVar), SYMA(partFrame));
			}
			break;

		case kOutputAutoPart:
			{
				NSCallGlobalFn(SYMA(UnDefGlobalVar), SYMA(partFrame));

				// evaluate all sources
				[self evaluate];

				RefVar privatePartFrame(AllocateFrame());
				RefVar devGlobal;
				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(InstallScript));
				if (NOTNIL(devGlobal)) {
					SetFrameSlot(privatePartFrame, SYMA(devInstallScript), devGlobal);
					SetFrameSlot(privatePartFrame, SYMA(InstallScript), RA(autoInstallScript));
				}
				// else should probably warn user
				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(RemoveScript));
				if (NOTNIL(devGlobal))
					SetFrameSlot(privatePartFrame, SYMA(devRemoveScript), devGlobal);
				// copy global partData, if it exists, to the part frame .partData
				devGlobal = NSCallGlobalFn(SYMA(GetGlobalVar), SYMA(partData));
				if (NOTNIL(devGlobal))
					SetFrameSlot(privatePartFrame, SYMA(partData), devGlobal);
				[self.parts addObject:[[NTXPackagePart alloc] initWith:privatePartFrame type:"auto" alignment:alignment]];
				RemoveSlot(RA(gVarFrame), SYMA(partFrame));
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
				RefVar customPartType(GetFrameSlot(outputSettings, MakeSymbol("customPartType")));
				char customPartTypeStr[8];
				ConvertFromUnicode(GetUString(customPartType), customPartTypeStr);
				RefVar topFrameSlot(GetFrameSlot(outputSettings, MakeSymbol("topFrameExpression")));
				RefVar partFrame(NSCallGlobalFn(SYMA(GetGlobalVar), FIntern(RA(NILREF), topFrameSlot)));
				[self.parts addObject:[[NTXPackagePart alloc] initWith:partFrame type:customPartTypeStr alignment:alignment]];
			}
			break;
		}
	}
	newton_catch(exCompilerData)
	{
		RefStruct * r = (RefStruct *)CurrentException()->data;
		err = RVALUE(GetFrameSlot(*r, SYMA(errorCode)));
		const char * errText = BinaryData(ASCIIString(GetFrameSlot(*r, SYMA(value))));
		const char * file = BinaryData(ASCIIString(GetFrameSlot(*r, SYMA(filename))));
		int line = RVALUE(GetFrameSlot(*r, SYMA(lineNumber)));
		REPprintf("Error in %s, line %d:\n%s\n", file, line, errText);
		self.parts = nil;
	}
	newton_catch_all
	{
		err = (NewtonErr)(long)CurrentException()->data;
		self.parts = nil;
	}
	end_try;

	// clear build constants
	RefVar consts(GetAllGlobalConstants());
	FOREACH_WITH_TAG(consts, tag, value)
		if (!FrameHasSlot(origConsts, tag)) {
			FUnDefineGlobalConstant(RA(NILREF), tag);
		}
	END_FOREACH

	// package up the part and write out the package file
	NSURL * pkgURL = nil;
	if (self.parts != nil && self.parts.count > 0) {
		// build package directory, part entries, etc
		NSData * pkgData = [self buildPackageData:alignment];
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

- (NSData *)buildPackageData:(int)alignment {
	RefVar pkgSettings(GetFrameSlot(_projectRef, MakeSymbol("packageSettings")));
	RefVar copyrightStr(GetFrameSlot(pkgSettings, MakeSymbol("copyright")));
	RefVar packageNameStr(GetFrameSlot(pkgSettings, MakeSymbol("packageName")));

	ArrayIndex copyrightStrLen = Length(copyrightStr);
	ArrayIndex nameStrLen = Length(packageNameStr);

//	alloc directory as NSMutableData; can later -writeToURL:
	NSMutableData * pkgData = [[NSMutableData alloc] initWithLength:sizeof(PackageDirectory) + self.parts.count*sizeof(PartEntry)];
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
	PartEntry *  partEntry = dir->parts;
	for (NTXPackagePart * part in self.parts) {
		// append part entry
		*partEntry = *part.entry;
		++partEntry;
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

// now, info for each part
	dir = (PackageDirectory *)pkgData.mutableBytes;	// data may have moved
	partEntry = dir->parts;
	ULong partInfoOffset = copyrightStrLen + nameStrLen;
	for (NTXPackagePart * part in self.parts) {
		[pkgData appendBytes:part.info length:part.infoLen];
		partEntry->info.offset = partInfoOffset;
		partInfoOffset += part.infoLen;
		++partEntry;
	}

// align pkgData
	NSUInteger misalignment = pkgData.length & (alignment-1);
	if (misalignment) {
		[pkgData increaseLengthBy:alignment-misalignment];
	}

// backpatch dir.directorySize
	dir = (PackageDirectory *)pkgData.mutableBytes;	// data may have moved
	dir->directorySize = pkgData.length;

// ignore relocation data for now -- we don’t do native funcs
//	for (NTXPackagePart * part in parts) {
//		[pkgData appendBytes:part.relocationData length:part.relocationDataLen];
//	}

//	add part data
	ArrayIndex partNum = 0;
	ULong partDataOffset = 0;
	for (NTXPackagePart * part in self.parts) {
		[part buildPartData:pkgData.length];
		[pkgData appendBytes:part.data length:part.dataLen];
		dir = (PackageDirectory *)pkgData.mutableBytes;	// data may have moved
		partEntry = &dir->parts[partNum];
		partEntry->offset = partDataOffset;
		partDataOffset += part.dataLen;
#if defined(hasByteSwapping)
		partEntry->offset = BYTE_SWAP_LONG(partEntry->offset);
		partEntry->size = BYTE_SWAP_LONG(partEntry->size);
		partEntry->size2 = BYTE_SWAP_LONG(partEntry->size2);
		partEntry->flags = BYTE_SWAP_LONG(partEntry->flags);
		partEntry->info.offset = BYTE_SWAP_SHORT(partEntry->info.offset);
		partEntry->info.length = BYTE_SWAP_SHORT(partEntry->info.length);
		partEntry->compressor.offset = BYTE_SWAP_SHORT(partEntry->compressor.offset);
		partEntry->compressor.length = BYTE_SWAP_SHORT(partEntry->compressor.length);
#endif
		++partNum;
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
		_dirEntry.flags = kNOSPart + kNotifyFlag;
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
	_dirEntry.size2 = _dirEntry.size;
	return &_dirEntry;
}

- (const char *)info {
	if (infoStr == nil) {
		RefVar pf(GetGlobalConstant(MakeSymbol("platformVersion")));
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
