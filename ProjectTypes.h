/*
	File:		ProjectTypes.h

	Contains:	Project type declarations for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/


// outputSettings.partType codes
enum
{
	kOutputApplication,
	kOutputBook,
	kOutputAutoPart,
	kOutputStorePart,
	kOutputStreamFile,
	kOutputCustomPart
};


// projectItems.items.type codes
enum
{
	kLayoutFileType,		// also used for user-proto and print layout files
	kBitmapFileType,
	kMetafileType,			//	unused
	kSoundFileType,
	kBookFileType,			// deprecated in favor of script items
	kScriptFileType,		// NewtonScript source file
	kPackageFileType,
	kStreamFileType,
	kNativeCodeFileType,

//	additional type codes used by NTX
	kGroupType,
	kProjectFileType
};

