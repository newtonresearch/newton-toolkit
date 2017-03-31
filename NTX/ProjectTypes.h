/*
	File:		ProjectTypes.h

	Contains:	Project type declarations for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/

/* -----------------------------------------------------------------------------
	Part type in outputSettings.partType
		0 Application
		1 Book
		2 Auto
		3 Store
		4 Stream
		5 Custom
----------------------------------------------------------------------------- */
enum
{
	kOutputApplication,
	kOutputBook,
	kOutputAutoPart,
	kOutputStorePart,
	kOutputStreamFile,
	kOutputCustomPart
};


/* -----------------------------------------------------------------------------
	File type in projectItems.items.type
		0 Layout file (also used for user-proto and print layout files)
		1 Bitmap file
		2 Metafile file (unused)
		3 Sound file
		4 Book file (deprecated in favor of script items)
		5 Script file (NewtonScript source file)
		6 Package file
		7 Stream file
		8 Native C++ code module file
----------------------------------------------------------------------------- */
enum
{
	kLayoutFileType,
	kBitmapFileType,
	kMetafileType,
	kSoundFileType,
	kBookFileType,
	kScriptFileType,
	kPackageFileType,
	kStreamFileType,
	kNativeCodeFileType,

//	additional type codes used by NTX
	kGroupType,
	kProjectFileType
};

