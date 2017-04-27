/*
	File:		NTXRsrcProject.mm

	Abstract:	Legacy Mac project document import implementation for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/

#import <sys/xattr.h>
#include <sys/attr.h>
#include <unistd.h>

#import <CoreServices/CoreServices.h>

#import "MacRsrcProject.h"
#import "ProjectTypes.h"
#import "Utilities.h"

extern Ref	MakeStringOfLength(const UniChar * str, ArrayIndex numChars);


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
#if 1
	struct FinderInfo {
		FileInfo info;
		ExtendedFileInfo xinfo;
	} x;
	ssize_t len = getxattr(inPath, XATTR_FINDERINFO_NAME, &x, sizeof(FinderInfo), 0, 0);
	return len < sizeof(FinderInfo) ? 'TEXT' : ntohl(x.info.fileType);



#else
	attrlist reqAttrs;
	memset(&reqAttrs, 0, sizeof(reqAttrs));
	reqAttrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	reqAttrs.fileattr = ATTR_FILE_FILETYPE;

	struct {
		uint32_t size;
		uint32_t fileTypeCode;
		uint32_t padding;
	} attrBuf;
	memset(&attrBuf, 0, sizeof(attrBuf));

	int err = getattrlist(inPath, &reqAttrs, &attrBuf, sizeof(attrBuf), 0L);
	return err ? 'TEXT' : ntohl(attrBuf.fileTypeCode);
#endif
}


const char *
FilenameFromFSSpec(void * inFSpec, ArrayIndex inLen)
{
	const char * filename;
	if (inLen == sizeof(FSSpecX)) {
		// we have a filespec
		FSSpecX * fsspec = (FSSpecX *)inFSpec;
		filename = (const char *)&fsspec->name[0];
	} else {
		// this is an alias
		FSAliasX * alias = (FSAliasX *)inFSpec;
		filename = (const char *)&alias->fileName[0];
	}
	// convert pascal -> c string
	static char cstr[64];
	size_t filenameLen = filename[0];
	strncpy(cstr, filename+1, filenameLen);
	cstr[filenameLen] = 0;
	return cstr;
	// caller must copy this if necessary
}


Ref
MakePoint(VPoint const& vpt)
{
	RefVar pt(AllocateFrame());
	SetFrameSlot(pt, MakeSymbol("h"), MAKEINT(ntohl(vpt.x)));
	SetFrameSlot(pt, MakeSymbol("v"), MAKEINT(ntohl(vpt.y)));
	return pt;
}

Ref
MakeRect(VRect const& vrect)
{
	RefVar rect(AllocateFrame());
	SetFrameSlot(rect, SYMA(top), MAKEINT(ntohl(vrect.top)));
	SetFrameSlot(rect, SYMA(left), MAKEINT(ntohl(vrect.left)));
	SetFrameSlot(rect, SYMA(bottom), MAKEINT(ntohl(vrect.bottom)));
	SetFrameSlot(rect, SYMA(right), MAKEINT(ntohl(vrect.right)));
	return rect;
}

Ref
ReadLayoutSettings(NSURL * url)
{
	int layoutType = FileTypeCode(url.fileSystemRepresentation) == 'PRTO' ? kUserProtoLayoutType : kNormalLayoutType;
	NTXRsrcFile * rf = [[NTXRsrcFile alloc] initWithURL:url];
	if (rf) {
		RsrcFMST * rsrc = (RsrcFMST *)[rf readResource:'FMST' number:9999];
		if (rsrc) {
			// set up the settings frames
			RefVar layoutSettings(AllocateFrame());
			SetFrameSlot(layoutSettings, MakeSymbol("ntkPlatform"), MAKEINT(0));
			SetFrameSlot(layoutSettings, MakeSymbol("fileVersion"), MAKEINT(ntohs(rsrc->version)));
			SetFrameSlot(layoutSettings, MakeSymbol("windowRect"), MakeRect(rsrc->windowPosition));
			SetFrameSlot(layoutSettings, MakeSymbol("layoutName"), MakeString(url.lastPathComponent));
			SetFrameSlot(layoutSettings, MakeSymbol("layoutType"), MAKEINT(layoutType));
			SetFrameSlot(layoutSettings, MakeSymbol("layoutSize"), MakePoint(rsrc->layoutSize));
			VPoint grid = {rsrc->grid[0].spacing, rsrc->grid[1].spacing};
			SetFrameSlot(layoutSettings, MakeSymbol("gridSize"), MakePoint(grid));
			SetFrameSlot(layoutSettings, MakeSymbol("gridState"), MAKEBOOLEAN(rsrc->grid[0].show));
			SetFrameSlot(layoutSettings, MakeSymbol("gridSnap"), MAKEBOOLEAN(rsrc->grid[0].snap));

//			uint8_t		isLinked;			// A boolean indicating whether or not this layout is linked to a linkedSubview.
//			Str255		linkedName;			// If this layout is linked to a linkedSubview, contains the name of the layout containing the linkedSubview.

			return layoutSettings;
		}
	}
	return NILREF;
}


#pragma mark - NTXRsrcFile
/* -----------------------------------------------------------------------------
	N T X R s r c F i l e
	An object to read legacy Mac project resource data.
----------------------------------------------------------------------------- */
@implementation NTXRsrcFile

- (id)initWithURL:(NSURL *)inURL {
	if (self = [super init]) {
		rsrcImage = NULL;
		rsrcData = NULL;
		self.url = inURL;

		const char * filePath = self.url.fileSystemRepresentation;
		// get size of resource fork
		rsrcLen = getxattr(filePath, XATTR_RESOURCEFORK_NAME, NULL, 0, 0, 0);
		if (rsrcLen == 0) {
			return nil;
		}
		fref = fopen(filePath, "rb");
		if (fref == NULL) {
			return nil;
		}
	}
	return self;
}

- (void)dealloc {
	if (rsrcImage) {
		free(rsrcImage), rsrcImage = NULL;
	}
	if (fref) {
		fclose(fref), fref = NULL;
	}
}


- (int)read4Bytes {
	uint32_t v;
	fread(&v, 1, 4, fref);
	return ntohl(v);
}


- (int)read2Bytes {
	uint16_t v;
	fread(&v, 1, 2, fref);
	return ntohs(v);
}


- (int)readByte {
	uint8_t v;
	fread(&v, 1, 1, fref);
	return v;
}

- (void)read:(NSUInteger)inCount into:(char *)inBuffer {
	fread(inBuffer, 1, inCount, fref);
}


// will have to do byte-swapping in here
- (void *)readResource:(OSType)inType number:(uint16_t)inNumber {
	if (rsrcImage == NULL) {
		// allocate sufficient length
		rsrcImage = (char *)malloc(rsrcLen);
		// Read the resource fork image
		getxattr(self.url.fileSystemRepresentation, XATTR_RESOURCEFORK_NAME, rsrcImage, rsrcLen, 0, 0);

		// point to the resource map
		rsrcMap = (RsrcMap *)(rsrcImage + ntohl(((RsrcHeader *)rsrcImage)->mapOffset));
		// point to the typelist
		rsrcTypeList = (RsrcList *)((char *)rsrcMap + ntohs(rsrcMap->typeListOffset));
		// point to the resource data
		rsrcData = rsrcImage + ntohl(((RsrcHeader *)rsrcImage)->dataOffset);
	}

	// walk the resource type list
	RsrcItem * r = rsrcTypeList->item;
	for (int i = 0, icount = ntohs(rsrcTypeList->count); i <= icount; ++i, ++r) {
		if (ntohl(r->type) == inType) {
			// we have resources of the required type
			RsrcRef * rr = (RsrcRef *)((char *)rsrcTypeList + ntohs(r->offset));
			for (int j = 0, jcount = ntohs(r->count); j <= jcount; j++, rr++) {
				if (ntohs(rr->id) == inNumber) {
					// we have a resource with the required number
					return rsrcData + ntohl(rr->offset);
				}
			}
		}
	}
	return NULL;
}

@end


#pragma mark - NTXRsrcProject
/* -----------------------------------------------------------------------------
	N T X R s r c P r o j e c t
----------------------------------------------------------------------------- */
@implementation NTXRsrcProject


- (id)initWithURL:(NSURL *)inURL {
	if (self = [super initWithURL:inURL]) {
		ULong format = self.read4Bytes;
		if (format != 103) {
			fclose(fref), fref = NULL;
			return nil;
		}
	}
	return self;
}


/* -----------------------------------------------------------------------------
	Import Mac project.
	Convert resource/data forks to project frame ref.
	Args:		--
	Return:	project ref
----------------------------------------------------------------------------- */

- (Ref)projectRef {
	//	stream in default project settings
	NSURL * url = [NSBundle.mainBundle URLForResource: @"CanonicalProject" withExtension: @"newtonstream"];
	CStdIOPipe pipe(url.fileSystemRepresentation, "r");
	RefVar proj(UnflattenRef(pipe));

	// assume files are in the same folder as the project -- we could try to find them but frankly life’s too short
	NSURL * basePath = [self.url URLByDeletingLastPathComponent];

	// read the data fork which contains the project items
	ArrayIndex itemCount = self.read2Bytes;
	ArrayIndex sortOrder = self.read4Bytes;	// ignored -- we use only build order

	RefVar projItems(GetFrameSlot(proj, MakeSymbol("projectItems")));

	RefVar fileItems(MakeArray(0));
	RefVar protoFileRef(AllocateFrame());
	SetClass(protoFileRef, MakeSymbol("fileReference"));
	SetFrameSlot(protoFileRef, MakeSymbol("fullPath"), RA(NILREF));
	for (ArrayIndex i = 0; i < itemCount; ++i) {
		// read aliases -- add to projectRef.projectItems.items
		char fsData[KByte];
		ULong itemLen = self.read4Bytes;
		if (itemLen > KByte) {
			itemLen = KByte;
			printf("ALIAS BUFFER OVERFLOW!\n");
		}
		[self read:itemLen into:fsData];
		const char * filename = FilenameFromFSSpec(fsData, itemLen);
		if (filename) {
			const char * filePath = [[basePath URLByAppendingPathComponent:[NSString stringWithCString:filename encoding:NSMacOSRomanStringEncoding]] fileSystemRepresentation];
			int fileType = 0;
			//convert to index
			switch (FileTypeCode(filePath)) {
			case 'FLFM':
			case 'PRTO':
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
			case 'CODE':
				fileType = kNativeCodeFileType;
				break;
			case 'rsrc':
				fileType = kResourceFileType;
				break;
			}

			SetFrameSlot(protoFileRef, MakeSymbol("fullPath"), MakeStringFromUTF8String(filePath));	// filePath is UTF8 encoded which MakeStringFromCString() can’t really handle

			RefVar fileItem(AllocateFrame());
			SetFrameSlot(fileItem, MakeSymbol("file"), Clone(protoFileRef));
			SetFrameSlot(fileItem, SYMA(type), MAKEINT(fileType));
			AddArraySlot(fileItems, fileItem);
		}
	}
	ArrayIndex mainLayout = self.read2Bytes;	// 1-based -- applies to specified sort order, not necessarily build order
															// so should sort fileItems to get this right
	if (mainLayout != 0 && --mainLayout < Length(fileItems)) {
		RefVar mainItem(GetArraySlot(fileItems, mainLayout));
		SetFrameSlot(mainItem, MakeSymbol("isMainLayout"), TRUEREF);
	}
	SetFrameSlot(projItems, MakeSymbol("items"), fileItems);

	// read the resource fork which contains the project settings
	RsrcPJPF * rsrc = (RsrcPJPF *)[self readResource:'PJPF' number:9999];
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
	switch (ntohl(rsrc->partType)) {
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
		if (rsrc->makeStream) {
			partType = kOutputStreamFile;
		} else {
			partType = kOutputCustomPart;
			if (rsrc->customPart) {
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
 
 	// ignore the resource fork which contains the window settings -- we need a MUCH larger window
//	VRect * wndw = (VRect *)[self readResource:'PJST' number:9999];

	return proj;
}

@end
