/*
	File:		ROMResources.h

	Contains:	Built-in resource declarations.

	Written by:	Newton Research Group, 2007.
*/

#if !defined(__ROMRESOURCES__)
#define __ROMRESOURCES__ 1

#include "ROMSymbols.h"

#define DEFFRAME(name, ref) \
extern Ref * RS##name;
#define DEFFRAME2(name, tag1, value1, tag2, value2) \
extern Ref * RS##name;
#define DEFFRAME3(name, tag1, value1, tag2, value2, tag3, value3) \
extern Ref * RS##name;
#define DEFFRAME4(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4) \
extern Ref * RS##name;
#define DEFFRAME5(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5) \
extern Ref * RS##name;
#define DEFFRAME6(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6) \
extern Ref * RS##name;
#define DEFFRAME7(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6, tag7, value7) \
extern Ref * RS##name;
#include "FrameDefs.h"
#undef DEFFRAME
#undef DEFFRAME2
#undef DEFFRAME3
#undef DEFFRAME4
#undef DEFFRAME5
#undef DEFFRAME6
#undef DEFFRAME7

#endif	/* __ROMRESOURCES__ */
