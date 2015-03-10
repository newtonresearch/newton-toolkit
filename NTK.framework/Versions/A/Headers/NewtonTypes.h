/*
	File:		NewtonTypes.h

	Contains:	Global types for Newton build system.

	Written by:	Newton Research Group.
*/

#if !defined(__NEWTONTYPES_H)
#define __NEWTONTYPES_H 1

#include <stdint.h>

/* Base types */

typedef int8_t		SChar;
typedef uint8_t 	UChar;

typedef int8_t		SByte;
typedef uint8_t	UByte;

typedef int16_t	SShort;
typedef uint16_t	UShort;

typedef int32_t	SLong;
typedef uint32_t	ULong;

/* Array/String index -- also used to define length */
typedef uint32_t	ArrayIndex;
#define kIndexNotFound 0xFFFFFFFF

/* Error codes -- need to hold codes less than -32767 */
typedef int32_t	NewtonErr;

/* The type of objects in the OS */
typedef uint32_t	ObjectId;

/* Address types */
typedef uint32_t	VAddr;
typedef uint32_t	PAddr;

/* Ref types */

typedef int32_t Ref;

typedef struct
{
	Ref	ref;
	Ref	stackPos;
} RefHandle;

#if defined(__cplusplus)
class RefVar;
typedef const RefVar & RefArg;
#else
typedef RefHandle * RefVar;
typedef RefVar RefStruct;
typedef const RefVar RefArg;
#endif

typedef Ref (*MapSlotsFunction)(RefArg tag, RefArg value, unsigned anything);


#if !defined(nil)
#define nil 0
#endif

typedef signed char BOOL;
#define YES (BOOL)1
#define NO  (BOOL)0

#if !defined(__MACTYPES__)
#define __MACTYPES__ 1

typedef uint16_t	UniChar;


/* Pointer types */

typedef char *		Ptr;
typedef Ptr *		Handle;
typedef int32_t	(*ProcPtr)(void*);


/* Math types */

typedef int32_t Fixed;
typedef int32_t Fract;
typedef uint32_t UnsignedFixed;

#endif

#if defined(__cplusplus)

class SingleObject {};

inline ProcPtr
ptmf2ptf(int (SingleObject::*func)(int,void*))
{
	union
	{
		int (SingleObject::*fIn)(int,void*);
		ProcPtr	fOut;
	} map;

	map.fIn = func;
	return map.fOut;
}
#define MemberFunctionCast(_t, self, fn) (_t) ptmf2ptf((int (SingleObject::*)(int,void*)) fn)

#endif	/* __cplusplus */

#endif	/* __NEWTONTYPES_H */
