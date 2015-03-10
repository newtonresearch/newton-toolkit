/*
	File:		Utilities.h

	Contains:	Utility functions for the NCX app.

	Written by:	Newton Research Group, 2005.
*/

#import <Foundation/Foundation.h>
#include "NewtonKit.h"


extern Ref			SetBoundsRect(RefArg ioFrame, const Rect * inBounds);
extern Ref			ToObject(const Rect * inBounds);

extern NSString *	MakeNSString(RefArg inStr);
extern Ref			MakeString(NSString * inStr);
extern NSDate *	MakeNSDate(RefArg inDate);
extern Ref			MakeDate(NSDate * inDate);

extern BOOL			IsInternalStore(RefArg inStore);

extern Ref			BuildPath(NSString * inPath);
extern Ref			BuildFileList(NSString * inPath, NSArray * inFilter);
extern Ref			BuildFileInfo(NSString * inPath, NSString * inFile);

extern NSString *	GetPackageDetails(NSString * inPath, unsigned int * outSize);

extern NSURL *		ApplicationSupportFolder(void);
extern NSURL *		ApplicationSupportFile(NSString * inFilename);
extern NSURL *		ApplicationLogFile(void);
