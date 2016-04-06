/*
	File:		ProjectDocument.mm

	Contains:	Project document implementation for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/

#import <sys/xattr.h>
#include <sys/attr.h>
#include <unistd.h>

#import <CoreServices/CoreServices.h>

#import "ProjectDocument.h"
#import "ProjectWindowController.h"
#import "Utilities.h"
#import "NTXDocument.h"

extern "C" Ref		FIntern(RefArg inRcvr, RefArg inStr);
extern "C" Ref		ArrayInsert(RefArg ioArray, RefArg inObj, ArrayIndex index);
extern "C" Ref		MakeStringOfLength(const UniChar * str, size_t numChars);


/* -----------------------------------------------------------------------------
	T Y P E S
	Mac project resource definitions.
----------------------------------------------------------------------------- */

struct RsrcHeader
{
	uint32_t	dataOffset;
	uint32_t	mapOffset;
	uint32_t	dataLength;
	uint32_t	mapLength;
//	char		reserved[112];
//	char		applicationSpecificData[128];
} __attribute__((packed));

struct RsrcData
{
	uint32_t	dataLength;
	char		data[];
} __attribute__((packed));

struct RsrcMap
{
	char		header[16];
	uint32_t nextMap;			// Handle to next resource map
	uint16_t	fRefNum;
	uint16_t	attributes;
	uint16_t	typeListOffset;	// Offset to Type list (from beginning of resource map in bytes)
	uint16_t	nameListOffset;	// Offset to Name list (from beginning of resource map in bytes)
	char		data[];
} __attribute__((packed));

struct RsrcRef
{
	uint16_t id;
	uint16_t name;
	uint32_t offset;
	uint32_t handle;
} __attribute__((packed));

struct RsrcItem
{
	uint32_t	type;
	uint16_t	count;				// Number of this type -1
	uint16_t	offset;				// Offset to Reference List for Type
} __attribute__((packed));

struct RsrcList
{
	uint16_t	count;				// Number of items -1
	RsrcItem	item[];
} __attribute__((packed));

// Resource attributes:
/*
bit 7 (reserved)
bit 6 resSysHeap
bit5 resPurgeable
bit 4 resLocked
bit 3 resProtected
bit 2 resPreload
bit 1 resChanged
bit 0 (reserved)
*/

struct RsrcPJPF
{
	uint32_t		size;
	Str32Field	applicationName;		// A Pascal string containing the name of the application in the built package. It corresponds to the “Name” edit text item of the Output Settings panel of the Project Settings dialog.
	Str32Field	iconName;				// A Pascal string containing the name of the 'PICT' resource used for the application’s icon.
	Str32Field	platform;				// A Pascal string containing the platform name.
	Str32Field	packageName;			// A Pascal string containing the name of the package. It corresponds to the “Name” edit text item of the Package Settings panel of the Project Settings dialog.
	Str32Field	applicationSymbol;	// A Pascal string containing the symbol of the application in the built package. It corresponds to the “Symbol” edit text item of the Output Settings panel of the Project Settings dialog.
	Str32Field	version;					// A Pascal string containing the version typed into the “Version” edit text item of the Package Settings panel of the Project Settings dialog. This string must be convertible to an integer between 0 and 9999.
	Str63			copyright;				// A Pascal string containing the version typed into the “Copyright” edit text item of the Package Settings panel of the Project Settings dialog
	uint8_t		optimizeSpeed;			// A boolean controlling code generation. It corresponds to the “Use Compression” check box of the Package Settings panel of the Project Settings dialog. Note that the boolean value stored is the opposite of setting of the check box.
	uint8_t		copyProtected;			// A boolean controlling package generation. It corresponds to the “Copy Protected” check box of the Package Settings panel of the Project Settings dialog.
	uint8_t		deleteOnDownload;		// A boolean controlling package downloading. It corresponds to the “Delete Old Package on Download” check box of the Package Settings panel of the Project Settings dialog.
	uint8_t		debugBuild;				// A boolean indicating whether or not the package will be built with debugging features. It corresponds to the “Compile for Debugging” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		autoClose;				// A boolean specifying whether or not the application should close when another “auto close” application is launched. It corresponds to the “Auto Close” check box of the Output Settings panel of the Project Settings dialog.
	uint8_t		padding1;
	Str63			iconFile;				// A Pascal string containing the name of the file containing the 'PICT' resource used for the application’s icon.
	uint8_t		customPart;				// A boolean indicating that the “Custom Part” radio button of the Output Settings panel of the Project Settings dialog is set.
	uint8_t		padding2;
	OSType		partType;				// A value indicating the type of package built. It can be one of the following values: 'form' 'book' 'auto' 'soup'
	Str255		topFrameExpression;	// A Pascal string containing the expression typed into the “Result” edit text item of the Output Settings panel of the Project Settings dialog.
	uint8_t		makeStream;				// A boolean indicating that the “Stream File” radio button of the Output Settings panel of the Project Settings dialog is set.
	uint8_t		dispatchOnly;			// A boolean controlling package generation. It corresponds to the “Auto Remove Package” check box of the Package Settings panel of the Project Settings dialog.
	uint8_t		newton20Only;			// A boolean controlling code generation. It corresponds to the “Newton 2.0 Platform Only” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		padding3;
	uint8_t		compileForProfiling;	// A boolean controlling code generation. It corresponds to the “Compile for Profiling” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		compileForSpeed;		// A boolean controlling code generation. It corresponds to the “Profile Native Functions” check box of the Project Settings panel of the Project Settings dialog. Note that the boolean value stored is the opposite of setting of the check box.
	uint8_t		detailedSystemCalls;	// A boolean controlling profiling. Currently hard-coded to FALSE, and can’t be changed by the user.
	uint8_t		padding4;
	uint16_t		memory;					// An integer controlling profiling. Currently hard-coded to 4K, it can’t be changed by the user.
	uint8_t		percent;					// An integer controlling profiling. Currently set to 4 (indicating 100%), but unused.
	uint8_t		detailedUserFunctions;// A boolean controlling profiling. Currently hard-coded to TRUE, and can’t be changed by the user.
	Str63			language;				// A Pascal string containing the specified language. It corresponds to the “Language” edit text item of the Project Settings panel of the Project Settings dialog.
	uint8_t		ignoreNative;			// A boolean indicating how the NewtonScript “native” keyword should be handled. It corresponds to the “Ignore Native Keyword” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		checkGlobalFunctions;// A boolean specifying whether or not global functions should be checked against a list of known global functions during compile time. It corresponds to the “Check Global Function Calls” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		oldBuildRules;			// A boolean specifying compatibility mode for projects created by Macintosh NTK 1.0. It corresponds to the “NTK 1.0 Build Rules” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		useStepChildren;		// A boolean specifying how child views should be handled. It corresponds to the “Use stepChildren Slot” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		suppressByteCodes;	// A boolean controlling code generation. It corresponds to the “Suppress Byte Code” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		fasterFunctions;		// A boolean controlling code generation. It corresponds to the “Faster Functions (2.0 Only)” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		fasterSoups;			// A boolean controlling code generation. It corresponds to the “New- Style Stores (2.0 Only)” check box of the Output Settings panel of the Project Settings dialog.
	uint8_t		fourByteAlignment;	// A boolean controlling package generation. It corresponds to the “Tighter Object Packing (2.0 Only)” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		zippyCompression;		// A boolean controlling package generation. It corresponds to the “Faster Compression (2.0 Only)” check box of the Package Settings panel of the Project Settings dialog.
	uint8_t		padding5;
} __attribute__((packed));


/* -----------------------------------------------------------------------------
	FSSpecs are invalid for 64 bit, but we are reading a legacy struct.
----------------------------------------------------------------------------- */

struct FSSpecX
{
	int16_t		vRefNum;
	int32_t		parID;
	Str63			name;
} __attribute__((packed));

struct FSInfoX
{
	int16_t		strType;				// Extended Info End = -1; Directory Name = 0; Directory IDs = 1; Absolute Path = 2; AppleShare Zone Name = 3; AppleShare Server Name = 4; AppleShare User Name = 5; Driver Name = 6; Revised AppleShare info = 9; AppleRemoteAccess dialup info = 10;  others for Mac OS X
									// 02 => full classic Mac OS path
									// 0E => Unicode filename prefixed by uint16_t length
									// 0F => Unicode volume name prefixed by uint16_t length
									// 12 => full Mac OS X path
									// 13 => path separator character
	uint16_t		strLen;
	char			str[];
} __attribute__((packed));

struct FSAliasX
{
	uint32_t		typeName;
	uint16_t		aliasSize;
	uint16_t		version;				// current(!) version = 2
	uint16_t		kind;
	uint8_t		volNameLen;			// p-string
	char			volName[27];
	uint32_t		volCreationDate;	// seconds since 1904
	uint16_t		volSignature;
	uint16_t		volType;				// Fixed HD = 0; Network Disk = 1; 400kB FD = 2;800kB FD = 3; 1.4MB FD = 4; Other Ejectable Media = 5
	uint32_t		parentDirId;
	Str63			fileName;			// p-string
	uint32_t		fileNo;
	uint32_t		fileCreationDate;
	uint32_t		fileType;
	uint32_t		fileCreator;
	uint16_t		nlvlFrom;
	uint16_t		nlvlTo;
	uint32_t		volAttributes;
	uint16_t		volId;
	int8_t		reserved1[10];
	FSInfoX		extendedInfo[];
} __attribute__((packed));

/*------------------------------------------------------------------------------
	Make a new string object from a Pascal string.
	Args:		str		the P string
	Return:	Ref		the NS string
------------------------------------------------------------------------------*/

Ref
MakeStringFromPString(const uint8_t * str)
{
	ArrayIndex strLen = *str;
	RefVar	obj(AllocateBinary(SYMA(string), (strLen + 1) * sizeof(UniChar)));
	ConvertToUnicode(str+1, (UniChar *) BinaryData(obj), strLen);
	return obj;
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
	Convert a UTF8 string to a string object.
	The Newton ROM doesn’t do UTF encoding.
	Args:		inStr
	Return:	string object
------------------------------------------------------------------------------*/

Ref
MakeStringFromUTF8String(const char * inStr)
{
	UniChar str16[256];
	NSString * str = [NSString stringWithUTF8String:inStr];
	NSInteger strLen = str.length;
	if (strLen > 255)
		strLen = 255;
	[str getCharacters:str16 range:NSMakeRange(0,strLen)];
	return MakeStringOfLength(str16, strLen);
}


/*------------------------------------------------------------------------------
	Read file type code of file at Mac OS 7 path.
	Args:		inPath		the path string object
	Return:	four-char-code
------------------------------------------------------------------------------*/

uint32_t
FileTypeCode(const char * inPath)
{
	attrlist reqAttrs;
	memset(&reqAttrs, 0, sizeof(reqAttrs));
	reqAttrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	reqAttrs.fileattr = ATTR_FILE_FILETYPE;
	struct {
		uint32_t size;
		uint32_t fileTypeCode;
		uint32_t padding;
	} attrBuf;

	int err = getattrlist(inPath, &reqAttrs, &attrBuf, sizeof(attrBuf), 0L);
	return err ? 'TEXT' : ntohl(attrBuf.fileTypeCode);
}


#pragma mark - NTXReader
/* -----------------------------------------------------------------------------
	N T X R e a d e r
	An object to read legacy Mac project resource data.
----------------------------------------------------------------------------- */

@interface NTXReader : NSObject
{
	FILE * fref;
	int rsrcLen;
	char * rsrcImage;
	char * rsrcData;
	RsrcMap * rsrcMap;
	RsrcList * rsrcTypeList;
}
@property(copy) NSURL * url;
@property(readonly) int read4Bytes;
@property(readonly) int read2Bytes;
@property(readonly) int readByte;
- (void) read: (NSUInteger) inCount into: (char *) inBuffer;
- (void *) readResource: (OSType) inType number: (uint16_t) inNumber;
@end

@implementation NTXReader

- (id) initWithURL: (NSURL *) inURL
{
	if (self = [super init])
	{
		rsrcImage = NULL;
		rsrcData = NULL;
		self.url = inURL;

		const char * filePath = self.url.fileSystemRepresentation;
		// get size of resource fork
		rsrcLen = getxattr(filePath, XATTR_RESOURCEFORK_NAME, NULL, 0, 0, 0);
		if (rsrcLen == 0)
			self = nil;
		fref = fopen(filePath, "rb");
		if (fref == NULL)
			self = nil;
	}
	return self;
}

- (void) dealloc
{
	if (rsrcImage)
		free(rsrcImage);
	if (fref)
		fclose(fref);
}


- (int) read4Bytes
{
	uint32_t v;
	fread(&v, 1, 4, fref);
	return ntohl(v);
}


- (int) read2Bytes
{
	uint16_t v;
	fread(&v, 1, 2, fref);
	return ntohs(v);
}


- (int) readByte
{
	uint8_t v;
	fread(&v, 1, 1, fref);
	return v;
}

- (void) read: (NSUInteger) inCount into: (char *) inBuffer
{
	fread(inBuffer, 1, inCount, fref);
}


// will have to do byte-swapping in here
- (void *) readResource: (OSType) inType number: (uint16_t) inNumber
{
	if (rsrcImage == NULL)
	{
		// allocate sufficient length
		rsrcImage = (char *)malloc(rsrcLen);
		// Read the resource fork image
		getxattr([[self.url path] fileSystemRepresentation], XATTR_RESOURCEFORK_NAME, rsrcImage, rsrcLen, 0, 0);

		// point to the resource map
		rsrcMap = (RsrcMap *)(rsrcImage + ntohl(((RsrcHeader *)rsrcImage)->mapOffset));
		// point to the typelist
		rsrcTypeList = (RsrcList *)((char *)rsrcMap + ntohs(rsrcMap->typeListOffset));
		// point to the resource data
		rsrcData = rsrcImage + ntohl(((RsrcHeader *)rsrcImage)->dataOffset);
	}

	// walk the resource type list
	RsrcItem * r = rsrcTypeList->item;
	for (int i = 0, icount = ntohs(rsrcTypeList->count); i <= icount; ++i, ++r)
	{
		if (ntohl(r->type) == inType)
		{
			// we have resources of the required type
			RsrcRef * rr = (RsrcRef *)((char *)rsrcTypeList + ntohs(r->offset));
			for (int j = 0, jcount = ntohs(r->count); j <= jcount; j++, rr++)
			{
				if (ntohs(rr->id) == inNumber)
				{
					// we have a resource with the required number
					return rsrcData + ntohl(rr->offset);
				}
			}
		}
	}
	return NULL;
}

@end


#pragma mark - NTXProjectDocument
/* -----------------------------------------------------------------------------
	N T X P r o j e c t D o c u m e n t
----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
	Types of file we recognise.
----------------------------------------------------------------------------- */
NSString * const NTXProjectFileType = @"com.newton.project";
NSString * const NTXLayoutFileType = @"com.newton.layout";
NSString * const NTXScriptFileType = @"com.newton.script";
NSString * const NTXStreamFileType = @"com.newton.stream";
NSString * const NTXCodeFileType = @"com.newton.nativecode";
NSString * const NTXPackageFileType = @"com.newton.pkg";


@implementation NTXProjectDocument

- (Ref) projectRef { return projectRef; }
- (void) setProjectRef: (Ref) inRef { projectRef = inRef; }


/* -----------------------------------------------------------------------------
	Project documents should autosave.
----------------------------------------------------------------------------- */

+ (BOOL) autosavesInPlace
{
	return YES;
}


/* -----------------------------------------------------------------------------
	Initialize.
	Initialize the projectRef with default values -- can be used for a new
	document.
----------------------------------------------------------------------------- */

- (id) init
{
	if (self = [super init])
	{
	//	stream in default project settings
		NSURL * url = [[NSBundle mainBundle] URLForResource: @"ProjectRoot" withExtension: @"stream"];
		CStdIOPipe pipe([[url path] fileSystemRepresentation], "r");
		self.projectRef = UnflattenRef(pipe);
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Make the project window.
----------------------------------------------------------------------------- */

- (void) makeWindowControllers
{
	self.progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];

	NTXProjectWindowController * myController = [[NTXProjectWindowController alloc] initWithWindowNibName: @"ProjectWindow"];
	[self addWindowController: myController];

	NTXSettingsViewController * ourController = [[NTXSettingsViewController alloc] initWithNibName: @"ProjectSettings" bundle: nil];
	ourController.document = self;
	self.viewController = ourController;
}


/* -----------------------------------------------------------------------------
	A chance for more initialization.
----------------------------------------------------------------------------- */

- (void) windowControllerDidLoadNib: (NSWindowController *) inController
{
	[super windowControllerDidLoadNib: inController];
	// Add any code here that needs to be executed once the windowController has loaded the document's window.
}


/* -----------------------------------------------------------------------------
	Read the project from disk.
	NTX uses WindowsNTK format -- an NSOF flattened project object.
	We can also import MacNTK project files, but we don’t save that format.
----------------------------------------------------------------------------- */

- (BOOL) readFromURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	NewtonErr err = noErr;
	newton_try
	{
		NTXReader * data;
		if ([[url pathExtension] isEqualToString:@"ntk"] && (data = [[NTXReader alloc] initWithURL:url]) != nil)
		// the file has a resource fork so assume it’s a Mac NTK project
			projectRef = [self import:data];
		else
		{
			CStdIOPipe pipe([[url path] fileSystemRepresentation], "r");
			projectRef = UnflattenRef(pipe);
		}

		[self buildSourceList:url];
	}
	newton_catch_all
	{
		err = (NewtonErr)(unsigned long)CurrentException()->data;;
	}
	end_try;

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


- (void) buildSourceList: (NSURL *) inProjectURL
{
	inProjectURL = [inProjectURL URLByDeletingLastPathComponent];	// we want the folder now

	NTXProjectItem * projectItem;

	RefVar items(GetFrameSlot(projectRef, MakeSymbol("projectItems")));
	items = GetFrameSlot(items, MakeSymbol("items"));

	// add projectItems to our list
	NSMutableArray * projItems = [[NSMutableArray alloc] initWithCapacity:Length(items)];

	NSURL * itemURL;
//	NSUInteger groupLen = 0;
	FOREACH(items, projItem)
		int filetype;
		RefVar fileRef(GetFrameSlot(projItem, MakeSymbol("file")));
		if (NOTNIL(fileRef))
		{
			if (EQ(ClassOf(fileRef), MakeSymbol("fileReference")))
			{
				NSString * path;
				RefVar pathRef;
				// preferred path is in 'fullPath as per NTK 1.6.2
				pathRef = GetFrameSlot(fileRef, MakeSymbol("fullPath"));
				if (NOTNIL(pathRef))
				{
					NSString * pathStr = MakePathString(pathRef);
					itemURL = [NSURL fileURLWithPath:MakePathString(pathRef) isDirectory:NO];
				}
				else
				{
					// try 'relativePath as per NTK 1.6.2
					pathRef = GetFrameSlot(fileRef, MakeSymbol("relativePath"));
					if (NOTNIL(pathRef))
					{
						itemURL = [inProjectURL URLByAppendingPathComponent:MakePathString(pathRef)];
					}
					else
					{
						// fall back to 'deltaFromProject
						pathRef = GetFrameSlot(fileRef, MakeSymbol("deltaFromProject"));
						if (NOTNIL(pathRef))
						{
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
			}
			else if (EQ(ClassOf(fileRef), MakeSymbol("fileGroup")))
			{
// if groupLen > 0 then error -- terminate current group early: unstack sidebarItems
				NSString * groupName = MakeNSString(GetFrameSlot(fileRef, MakeSymbol("name")));
//					groupLen = RINT(GetFrameSlot(fileRef, MakeSymbol("length")));
				projectItem = [[NTXProjectItem alloc] initWithURL:[NSURL URLWithString:groupName] type:kGroupType];
				[projItems addObject: projectItem];
// if groupLen > 0 then begin stack sidebarItems; create new sidebarItems end
			}
		}
	END_FOREACH;

	// windowController is observing changes so will update source list
	self.projectItems = projItems;
}


/* -----------------------------------------------------------------------------
	Write the project to disk.
	Flatten it to NSOF.
	Alternatively, write out a text representation.
----------------------------------------------------------------------------- */

- (BOOL) writeToURL: (NSURL *) url ofType: (NSString *) typeName error: (NSError **) outError
{
	NewtonErr err = noErr;

	if ([typeName isEqualTo:@"public.plain-text"])
	{
		/* -----------------------------------------------------------------------------
			Export a text representation of the project into a file named <projectName>.text
			First line is:
				// Text of project <projectName> written on <date> at <time>
			followed by files in the source list - each document implements -exportToText: to do this
			Text files are output verbatim, bracketed by:
				// Beginning of text file <fileName>
				// End of text file <fileName>
			Stream files are defined:
				DefConst('|streamFile_<fileName>|, ReadStreamFile("<fileName>"));
				|streamFile_<fileName>|:?install();
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

			Show progress -- "Dumping to text" && each file being processed.
		----------------------------------------------------------------------------- */
		NSURL * destination = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"text"];

		NSString * filename = [destination lastPathComponent];
		NSString * when = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
		NSString * exportedText = [NSString stringWithFormat:@"// Text of project %@ written on %@\n\n", filename, when];

		for (NTXProjectItem * item in self.projectItems)
		{
//			NSString * status = [NSString stringWithFormat:@"Dumping to text %@", item.name];
NSLog(@"Dumping to text %@", item.name);
			exportedText = [exportedText stringByAppendingString:[item.document exportToText]];
		}

		NSError * __autoreleasing err = nil;
		[exportedText writeToURL:destination atomically:YES encoding:NSUTF8StringEncoding error:&err];
	}
	else
	{
		// save settings and source list
		CStdIOPipe pipe([[url path] fileSystemRepresentation], "w");

		newton_try
		{
			FlattenRef(projectRef, pipe);
		}
		newton_catch_all
		{
			err = (NewtonErr)(unsigned long)CurrentException()->data;;
		}
		end_try;

	}

	if (err && outError)
		*outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: ioErr userInfo: nil];

	return err == noErr;
}


/* -----------------------------------------------------------------------------
	Return the index of the selected source list item.
	We remember this across ProjectDocument close/open.
	** This is an NTX extension to the WindowsNTK project format. **
----------------------------------------------------------------------------- */

- (NSInteger) selectedItem
{
	RefVar items, selection;
	if (NOTNIL(projectRef)
	&&  NOTNIL(items = GetFrameSlot(projectRef, MakeSymbol("projectItems")))
	&&  NOTNIL(selection = GetFrameSlot(items, MakeSymbol("selectedItem"))))
	{
		return RINT(selection);
	}
	return 0;
}


- (void) setSelectedItem: (NSInteger) inSelection
{
	RefVar items;
	if (NOTNIL(projectRef)
	&&  NOTNIL(items = GetFrameSlot(projectRef, MakeSymbol("projectItems"))))
	{
		SetFrameSlot(items, MakeSymbol("selectedItem"), MAKEINT(inSelection));
	}
}


/* -----------------------------------------------------------------------------
	Add files to the project.
	Add them to the document’s projectItems array then refresh the sourcelist
	to keep it in sync.
	(We need to do that after adding/moving/deleting files in the sourcelist.)
	Args:		inFiles
				index			-1 => append inFiles
	Return:	--
----------------------------------------------------------------------------- */
extern NSArray * gTypeNames;

- (void) addFiles:(NSArray *)inFiles afterIndex:(NSInteger)index
{
	RefVar items;
	if (NOTNIL(projectRef)
	&&  NOTNIL(items = GetFrameSlot(projectRef, MakeSymbol("projectItems")))
	&&  NOTNIL(items = GetFrameSlot(items, MakeSymbol("items"))))
	{
		RefVar item(AllocateFrame());
		RefVar fileRef(AllocateFrame());
		int filetype;

		SetClass(fileRef, MakeSymbol("fileReference"));
		for (NSURL * url in inFiles)
		{
			NSLog(@"Adding %s", url.fileSystemRepresentation);

			// translate url extension to filetype
			CFStringRef extn = (__bridge CFStringRef)url.pathExtension;
			filetype = 0;
			CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extn, NULL);
			for (NSString * type in gTypeNames)
			{
				if (UTTypeConformsTo(fileUTI, (__bridge CFStringRef)[NSString stringWithFormat:@"com.newton.%@", type]))
					break;
				++filetype;
			}
			if (filetype == gTypeNames.count)
				;	// we didn’t recognise the type of file!

			SetFrameSlot(fileRef, MakeSymbol("fullPath"), MakeStringFromUTF8String(url.fileSystemRepresentation));

			SetFrameSlot(item, MakeSymbol("file"), fileRef);
			SetFrameSlot(item, MakeSymbol("type"), MAKEINT(filetype));

			if (index < 0)
			{
				// append to end of list
				AddArraySlot(items, item);
			}
			else
			{
				ArrayInsert(items, item, ++index);
			}
		}
	}
	[self buildSourceList:self.fileURL];
}


#pragma mark -
/* -----------------------------------------------------------------------------
	Evaluate all the sources.
	Args:		--
	Return:	--
				The result will be in gVarFrame somewhere.
----------------------------------------------------------------------------- */

- (void) evaluate
{
	for (NTXProjectItem * item in self.projectItems)
	{
		[item.document evaluate];
	}

#if 0
		switch (filetype)
		{
		case kLayoutFileType:
			// create constant |layout_<filename>| := <viewref>;
			break;

		case kBitmapFileType:
			break;
//		case kMetafileType:		unused
		case kSoundFileType:
//		case kBookFileType:		deprecated
			break;

		case kScriptFileType:
		// NewtonScript source -- just parse it
			ParseFile([[filepath path] fileSystemRepresentation]);
			break;

		case kPackageFileType:
			// does not get exported to text at all
			break;

		case kStreamFileType:
			// create constant |streamFile_<filename>| then install it, eg
			// DefConst('|streamFile_plainC|, ReadStreamFile("plainC"));
			// |streamFile_plainC|:?install();
			break;

		case kNativeCodeFileType:
			// DefConst('<filename>, <frameOfCodeFile>);
			// for some reason this is commented out /*..*/ when exported to text
			break;
		}
#endif
}


/* -----------------------------------------------------------------------------
	Build the source into the output part type specified in
	outputSettings.partType.
	stream =>
		evaluate all files
		result is (outputSettings.topFrameExpression)
		write that in NSOF to <projectURL>.newtonstream
	auto | store | custom part =>
		evaluate all files
		result is partData
		create package directory info
		write to <projectURL>.newtonpkg
	application | book
		ditto but packaging is specific to that output type
	Args:		--
	Return:	URL of package file so it can be downloaded if necessary
----------------------------------------------------------------------------- */

- (NSURL *) build
{
	NSURL * pkgURL = nil;
	RefVar outputSettings(GetFrameSlot(projectRef, MakeSymbol("outputSettings")));
	int partType = RINT(GetFrameSlot(outputSettings, MakeSymbol("partType")));
	switch (partType)
	{
	case kOutputStreamFile:
		{
			// evaluate all sources
			[self evaluate];
			// get the result
			RefVar resultSlot(GetFrameSlot(outputSettings, MakeSymbol("topFrameExpression")));
			RefVar result(GetFrameSlot(RA(gVarFrame), FIntern(RA(NILREF), resultSlot)));
			// flatten to stream file
			NSURL * streamURL = [[[self fileURL] URLByDeletingPathExtension] URLByAppendingPathExtension:@"newtonstream"];
			// this is not a package -- do not set pkgURL
			CStdIOPipe pipe([[streamURL path] fileSystemRepresentation], "w");
			FlattenRef(result, pipe);
		}
		break;

	case kOutputApplication:
	case kOutputBook:
		{
			// for now, just evaluate all sources -- assume they will print something interesting
			[self evaluate];
		}
		break;

	case kOutputAutoPart:
	case kOutputStorePart:
	case kOutputCustomPart:
		break;
	}
	return pkgURL;
}

#if 0
/* -----------------------------------------------------------------------------
	Package Format
		see Newton Formats, 1-4
		also PackageManager.cc : CPrivatePackageIterator
			directory -- header + part entries + directory data
			relocation info (optional)
			part data

#import "PackageTypes.h"
#import "PackageParts.h"

set up struct PackageDirectory
{
	char		signature[8];		//	'package0' or 'package1'
	ULong		id;
	ULong		flags;				//	defined below
	ULong		version;				//	arbitrary number
	InfoRef	copyright;			//	Unicode copyright notice - optional
	InfoRef	name;					//	Unicode package name - unique
	ULong		size;					//	total size of package including this directory
	Date		creationDate;
	Date		modifyDate;
	ULong		reserved3;
	ULong		directorySize;		//	size of this directory including part entries & data
	ULong		numParts;			//	number of parts in the package
	PartEntry parts[];
};


----------------------------------------------------------------------------- */


/** Create a new binary object that contains the object tree in package format.
 *
 * This function creates a binary object, containing the representaion of
 * a whole hierarchy of objects in the Newton package format. The binary
 * data can be written directly to disk to create a Newton readable .pkg file.
 * 
 * NewtWritePkg was tested on hierarchies created by NewtReadPackage, reading
 * a random bunch of .pkg files containing Newton Script applications. The 
 * packages created were identiacla to the original packages.
 *
 * @todo	NewtWritePkg does not support a relocation table yet which may 
 *			be needed to save native function of a higher complexity.
 * @todo	Error handling is not yet implemented.
 * @todo	Named magic poiners are not supported yet.
 * @todo	Only NOS parts are currently supported. We still must implement
 *			Protocol parts and Raw parts. 
 *
 * @param rpkg	[in] object hierarchy describing the package
 *
 * @retval	binary object with package
 */
newtRef NewtWritePkg(newtRefArg package)
{
	pkg_stream_t	pkg;
	int32_t			num_parts, i, ix;
	newtRef			parts, result;

	// setup pkg_stream_t
	memset(&pkg, 0, sizeof(pkg));

#	ifdef HAVE_LIBICONV
	{	char *encoding = NewtDefaultEncoding();
		pkg.to_utf16 = iconv_open("UTF-16BE", encoding);
	}
#	endif /* HAVE_LIBICONV */

	// find the array of parts that we will write
	ix = NewtFindSlotIndex(package, NSSYM(parts));
	if (ix>=0) {
		parts = NewtGetFrameSlot(package, ix);
		num_parts = NewtFrameLength(parts);
		pkg.header_size = sizeof(pkg_header_t) + num_parts * sizeof(pkg_part_t);

		// start setting up the header with whatever we know
			// sig
		PkgWriteData(&pkg, 0, "package0", 8);
		pkg.data[7] = (uint8_t)('0' + PkgGetSlotInt(package, NSSYM(pkg_version), 0));
			// type
		PkgWriteU32(&pkg, 8, PkgGetSlotInt(package, NSSYM(type), 0x78787878)); // "xxxx"
			// flags
		PkgWriteU32(&pkg, 12, PkgGetSlotInt(package, NSSYM(flags), 0));
			// version
		PkgWriteU32(&pkg, 16, PkgGetSlotInt(package, NSSYM(version), 0));
			// copyright
		PgkWriteVarData(&pkg, 20, package, NSSYM(copyright));
			// name
		PgkWriteVarData(&pkg, 24, package, NSSYM(name));
			// date
		PkgWriteU32(&pkg, 32, time(0L)+2082844800);
			// reserved2
		PkgWriteU32(&pkg, 36, 0); 
			// reserved3
		PkgWriteU32(&pkg, 40, 0); 
			// numParts
		PkgWriteU32(&pkg, 48, num_parts);

		// calculate the size of the header so we can correctly set our refs in the parts
		for (i=0; i<num_parts; ++i) {
			newtRef part = NewtGetArraySlot(parts, i);
			PgkWriteVarData(&pkg, sizeof(pkg_header_t) + i*sizeof(pkg_part_t) + 24, part, NSSYM(info));
		}

		// the original file has this (c) message embedded
		{	
#ifdef _MSC_VER
			char msg[] = "Newtonª ToolKit Package © 1992-1997, Apple Computer, Inc.";
#else
			char msg[] = "Newtonï½ª ToolKit Package ï½© 1992-1997, Apple Computer, Inc.";
#endif
			PkgWriteData(&pkg, pkg.header_size + pkg.var_data_size, msg, sizeof(msg));
			pkg.var_data_size += sizeof(msg);
		}

		pkg.part_offset = pkg.directory_size = PkgAlign(&pkg, pkg.header_size + pkg.var_data_size);
			// directorySize
		PkgWriteU32(&pkg, 44, pkg.directory_size);

		// create all parts
		for (i=0; i<num_parts; ++i) {
			newtRef part = NewtGetArraySlot(parts, i);
			pkg.part_header_offset = sizeof(pkg_header_t) + i*sizeof(pkg_part_t);
			PkgWritePart(&pkg, part);
		}
	}

	// finish filling in the header
		// size
	PkgWriteU32(&pkg, 28, pkg.size);

	result = NewtMakeBinary(NSSYM(package), pkg.data, pkg.size, false);

	// clean up our allocations
	if (pkg.data) 
		free(pkg.data);

#	ifdef HAVE_LIBICONV
		iconv_close(pkg.to_utf16);
#	endif /* HAVE_LIBICONV */

	return result;
}
#endif

#pragma mark -
/* -----------------------------------------------------------------------------
	Import Mac project.
	Convert resource/data forks to project frame ref.
	Args:		--
	Return:	project ref
----------------------------------------------------------------------------- */

- (Ref) import: (NTXReader *) data
{
	//	stream in default project settings
	NSURL * url = [[NSBundle mainBundle] URLForResource: @"ProjectRoot" withExtension: @"stream"];
	CStdIOPipe pipe([[url path] fileSystemRepresentation], "r");
	RefVar proj(UnflattenRef(pipe));

	// assume files are in the same folder as the project -- we could try to find them but frankly life’s too short
	NSURL * basePath = [data.url URLByDeletingLastPathComponent];

	// read the data fork which contains the project items
	ULong format = data.read4Bytes;				// always 103
	ArrayIndex itemCount = data.read2Bytes;
	ArrayIndex sortOrder = data.read4Bytes;	// ignored -- we use only build order

	RefVar projItems(GetFrameSlot(proj, MakeSymbol("projectItems")));

	RefVar fileItems(MakeArray(0));
	RefVar protoFileItem(AllocateFrame());
	SetClass(protoFileItem, MakeSymbol("fileReference"));
	SetFrameSlot(protoFileItem, MakeSymbol("fullPath"), RA(NILREF));
	for (ArrayIndex i = 0; i < itemCount; ++i)
	{
		char * filename = NULL;
		// read aliases -- add to projectRef.projectItems.items
		ULong itemLen = data.read4Bytes;
		if (itemLen == sizeof(FSSpecX))
		{
			// we must convert a filespec
			FSSpecX fspec;
			[data read:itemLen into:(char *)&fspec];
			filename = (char *)&fspec.name[0];
		}
		else
		{
			// this is an alias
			if (itemLen > KByte)
				printf("ALIAS BUFFER OVERFLOW!\n");
			char aliasData[KByte];
			[data read:itemLen into:aliasData];
			FSAliasX * alias = (FSAliasX *)aliasData;
			filename = (char *)&alias->fileName[0];
		}
		if (filename)
		{
			const char * filePath;
			char cstr[64];
			size_t filenameLen = *(uint8_t *)filename;
			strncpy(cstr, filename+1, filenameLen);
			cstr[filenameLen] = 0;
			filePath = [[basePath URLByAppendingPathComponent:[NSString stringWithCString:cstr encoding:NSMacOSRomanStringEncoding]] fileSystemRepresentation];
			int fileType = 0;
			//convert to index
			switch (FileTypeCode(filePath))
			{
			case 'FLFM':
				fileType = kLayoutFileType;
				break;
			case 'TIFF':
				fileType = kBitmapFileType;
				break;
			case 'SND ':
				fileType = kSoundFileType;
				break;
			case 'TEXT':
				fileType = kScriptFileType;
				break;
			case 'PKG ':
				fileType = kPackageFileType;
				break;
			case 'STRM':
				fileType = kStreamFileType;
				break;
			case 'CODE':	// really?
				fileType = kNativeCodeFileType;
				break;
			}

//			SetFrameSlot(protoFileItem, MakeSymbol("fullPath"), MakeStringFromCString(filePath));	// filePath is UTF8 encoded which MakeStringFromCString() can’t really handle
			SetFrameSlot(protoFileItem, MakeSymbol("fullPath"), MakeStringFromUTF8String(filePath));

			RefVar fileItem(AllocateFrame());
			SetFrameSlot(fileItem, MakeSymbol("file"), Clone(protoFileItem));
			SetFrameSlot(fileItem, SYMA(type), MAKEINT(fileType));
			AddArraySlot(fileItems, fileItem);
		}
	}
	ArrayIndex mainLayout = data.read2Bytes;	// 1-based -- applies to specified sort order, not necessarily build order
															// so should sort fileItems to get this right
	if (mainLayout != 0 && --mainLayout < Length(fileItems))
	{
		RefVar mainItem(GetArraySlot(fileItems, mainLayout));
		SetFrameSlot(mainItem, MakeSymbol("isMainLayout"), TRUEREF);
	}
	SetFrameSlot(projItems, MakeSymbol("items"), fileItems);

	// read the resource fork which contains the project settings
	RsrcPJPF * rsrc = (RsrcPJPF *)[data readResource:'PJPF' number:9999];
// XFAIL(rsrc == NULL)

	// set up the settings frames
	RefVar projectSettings(GetFrameSlot(proj, MakeSymbol("projectSettings")));
	SetFrameSlot(projectSettings, MakeSymbol("platform"), MakeStringFromPString(rsrc->platform));
	SetFrameSlot(projectSettings, MakeSymbol("language"), MakeStringFromPString(rsrc->language));
	SetFrameSlot(projectSettings, MakeSymbol("debugBuild"), MAKEBOOLEAN(rsrc->debugBuild));
	SetFrameSlot(projectSettings, MakeSymbol("ignoreNative"), MAKEBOOLEAN(rsrc->ignoreNative));
	SetFrameSlot(projectSettings, MakeSymbol("checkGlobalFunctions"), MAKEBOOLEAN(rsrc->checkGlobalFunctions));
	SetFrameSlot(projectSettings, MakeSymbol("oldBuildRules"), MAKEBOOLEAN(rsrc->oldBuildRules));
	SetFrameSlot(projectSettings, MakeSymbol("useStepChildren"), MAKEBOOLEAN(rsrc->useStepChildren));
	SetFrameSlot(projectSettings, MakeSymbol("suppressByteCodes"), MAKEBOOLEAN(rsrc->suppressByteCodes));
	SetFrameSlot(projectSettings, MakeSymbol("fasterFunctions"), MAKEBOOLEAN(rsrc->fasterFunctions));

	RefVar outputSettings(GetFrameSlot(proj, MakeSymbol("outputSettings")));
	SetFrameSlot(outputSettings, MakeSymbol("applicationName"), MakeStringFromPString(rsrc->applicationName));
	SetFrameSlot(outputSettings, MakeSymbol("applicationSymbol"), MakeStringFromPString(rsrc->applicationSymbol));

	int partType;
	const char * partTypeStr;
	char partTypeStrBuf[5];
	switch (ntohl(rsrc->partType))
	{
	case 'form':
		partType = kOutputApplication;
		partTypeStr = "form";
		break;
	case 'book':
		partType = kOutputBook;
		partTypeStr = "book";
		break;
	case 'auto':
		partType = kOutputAutoPart;
		partTypeStr = "auto";
		break;
	case 'soup':
		partType = kOutputStorePart;
		partTypeStr = "soup";
		break;
	default:
		partTypeStr = "UNKN";
		if (rsrc->makeStream)
			partType = kOutputStreamFile;
		else
		{
			partType = kOutputCustomPart;
			if (rsrc->customPart)
			{
				partTypeStrBuf[0] = rsrc->partType >> 24;
				partTypeStrBuf[1] = rsrc->partType >> 16;
				partTypeStrBuf[2] = rsrc->partType >>  8;
				partTypeStrBuf[3] = rsrc->partType;
				partTypeStrBuf[4] = 0;
				partTypeStr = partTypeStrBuf;
			}
		}
 	}
	SetFrameSlot(outputSettings, MakeSymbol("partType"), MAKEINT(partType));
	SetFrameSlot(outputSettings, MakeSymbol("customPartType"), MakeStringFromCString(partTypeStr));
//	iconFile
	SetFrameSlot(outputSettings, MakeSymbol("topFrameExpression"), MakeStringFromPString(rsrc->topFrameExpression));
	SetFrameSlot(outputSettings, MakeSymbol("autoClose"), MAKEBOOLEAN(rsrc->autoClose));
	SetFrameSlot(outputSettings, MakeSymbol("fasterSoups"), MAKEBOOLEAN(rsrc->fasterSoups));
	
	RefVar packageSettings(GetFrameSlot(proj, MakeSymbol("packageSettings")));
	SetFrameSlot(packageSettings, MakeSymbol("packageName"), MakeStringFromPString(rsrc->packageName));
	SetFrameSlot(packageSettings, MakeSymbol("version"), MakeStringFromPString(rsrc->version));
	SetFrameSlot(packageSettings, MakeSymbol("copyright"), MakeStringFromPString(rsrc->copyright));
	SetFrameSlot(packageSettings, MakeSymbol("optimizeSpeed"), MAKEBOOLEAN(rsrc->optimizeSpeed));
	SetFrameSlot(packageSettings, MakeSymbol("copyProtected"), MAKEBOOLEAN(rsrc->copyProtected));
	SetFrameSlot(packageSettings, MakeSymbol("deleteOnDownload"), MAKEBOOLEAN(rsrc->deleteOnDownload));
	SetFrameSlot(packageSettings, MakeSymbol("dispatchOnly"), MAKEBOOLEAN(rsrc->dispatchOnly));
	SetFrameSlot(packageSettings, MakeSymbol("newton20Only"), MAKEBOOLEAN(rsrc->newton20Only));
	SetFrameSlot(packageSettings, MakeSymbol("fourByteAlignment"), MAKEBOOLEAN(rsrc->fourByteAlignment));
	SetFrameSlot(packageSettings, MakeSymbol("zippyCompression"), MAKEBOOLEAN(rsrc->zippyCompression));

	RefVar profilerSettings(GetFrameSlot(proj, MakeSymbol("profilerSettings")));
	SetFrameSlot(profilerSettings, MakeSymbol("memory"), MAKEINT(rsrc->memory));
	SetFrameSlot(profilerSettings, MakeSymbol("percent"), MAKEINT(rsrc->percent));
	SetFrameSlot(profilerSettings, MakeSymbol("compileForProfiling"), MAKEBOOLEAN(rsrc->compileForProfiling));
	SetFrameSlot(profilerSettings, MakeSymbol("compileForSpeed"), MAKEBOOLEAN(rsrc->compileForSpeed));
	SetFrameSlot(profilerSettings, MakeSymbol("detailedSystemCalls"), MAKEBOOLEAN(rsrc->detailedSystemCalls));
	SetFrameSlot(profilerSettings, MakeSymbol("detailedUserFunctions"), MAKEBOOLEAN(rsrc->detailedUserFunctions));
 
	return proj;
}

@end

