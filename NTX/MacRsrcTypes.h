/*
	File:		MacRsrcTypes.h

	Abstract:	Mac NTK project resource types.

	Written by:	Newton Research Group, 2014.
*/

#import <Cocoa/Cocoa.h>

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
}__attribute__((packed));

struct RsrcData
{
	uint32_t	dataLength;
	char		data[];
}__attribute__((packed));

struct RsrcMap
{
	char		header[16];
	uint32_t nextMap;			// Handle to next resource map
	uint16_t	fRefNum;
	uint16_t	attributes;
	uint16_t	typeListOffset;	// Offset to Type list (from beginning of resource map in bytes)
	uint16_t	nameListOffset;	// Offset to Name list (from beginning of resource map in bytes)
	char		data[];
}__attribute__((packed));

struct RsrcRef
{
	uint16_t id;
	uint16_t name;
	uint32_t offset;
	uint32_t handle;
}__attribute__((packed));

struct RsrcItem
{
	uint32_t	type;
	uint16_t	count;				// Number of this type -1
	uint16_t	offset;				// Offset to Reference List for Type
}__attribute__((packed));

struct RsrcList
{
	uint16_t	count;				// Number of items -1
	RsrcItem	item[];
}__attribute__((packed));

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
	uint8_t		fasterSoups;			// A boolean controlling code generation. It corresponds to the “New-Style Stores (2.0 Only)” check box of the Output Settings panel of the Project Settings dialog.
	uint8_t		fourByteAlignment;	// A boolean controlling package generation. It corresponds to the “Tighter Object Packing (2.0 Only)” check box of the Project Settings panel of the Project Settings dialog.
	uint8_t		zippyCompression;		// A boolean controlling package generation. It corresponds to the “Faster Compression (2.0 Only)” check box of the Package Settings panel of the Project Settings dialog.
	uint8_t		padding5;
}__attribute__((packed));


/* -----------------------------------------------------------------------------
	FSSpecs are invalid for 64 bit, but we are reading a legacy struct.
----------------------------------------------------------------------------- */

struct FSSpecX
{
	int16_t		vRefNum;
	int32_t		parID;
	Str63			name;
}__attribute__((packed));

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
}__attribute__((packed));

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
}__attribute__((packed));


/* -----------------------------------------------------------------------------
	For layout files:
----------------------------------------------------------------------------- */

struct VPoint
{
	int32_t		y, x;
}__attribute__((packed));

struct VRect
{
	int32_t		top, left, bottom, right;
}__attribute__((packed));

struct GridInfo
{
	uint32_t		scope;			// Unused
	uint32_t		snap;				// True if gridding active
	uint8_t		show;				// True if gridding shown
	uint8_t		padding;
	uint32_t		spacing;			// Grid spacing
}__attribute__((packed));

struct RsrcFMST
{
	uint32_t		size;
	VRect			windowPosition;	// Layout window position. Bounding box of content region in global coordinates.
	Str63			reserved1;			// Obsolete.
	VPoint		layoutSize;			// Layout size.
	uint16_t		version;				// File version (currently 7).
	uint8_t		isLinked;			// A boolean indicating whether or not this layout is linked to a linkedSubview.
	uint8_t		padding1;
	Str255		linkedName;			// If this layout is linked to a linkedSubview, contains the name of the layout containing the linkedSubview.
	GridInfo		grid[2];				// Two GridInfo structs containing information about the layout window.
											// The first GridInfo contains information pertaining to vertical attributes of the layout window;
											// the second GridInfo does likewise for the horizontal attributes.
											// Note that both show fields are always both TRUE or both FALSE.
}__attribute__((packed));

