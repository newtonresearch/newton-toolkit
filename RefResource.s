;	File:		RefResource.s
;
;	Contains:	Ref resources -- symbols, strings, arrays and frames.
;
;	Written by:	Newton Research Group, 2007.

		.data
		.align	2

#define NILREF 2
#define MAKEINT(n) (n<<2)
#define MAKEMAGICPTR(n) (n<<2)+3
#define MAKEPTR(p) p+1

;-------------------------------------------------------------------------------
;	Symbols.
;-------------------------------------------------------------------------------

#define DEFSYM(name, len, hash) \
SYM##name: \
		.long		((12+len)<<8) + 0x40, 0 @\
		.long		0x55552 @\
		.long		hash @\
		.asciz	#name @\
		.align	2
#define DEFSYM_(name, sym, len, hash) \
SYM##name: \
		.long		((12+len)<<8) + 0x40, 0 @\
		.long		0x55552 @\
		.long		hash @\
		.asciz	sym @\
		.align	2
#include "Symbol_Defs.h"
#undef DEFSYM
#undef DEFSYM_


;-------------------------------------------------------------------------------
;	Frames.
;-------------------------------------------------------------------------------

#define DEFFRAME(name, ref)
#define DEFFRAME2(name, tag1, value1, tag2, value2) \
name##Map: \
		.long		((4+2)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2) @\
name: \
		.long		((3+2)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2
#define DEFFRAME3(name, tag1, value1, tag2, value2, tag3, value3) \
name##Map: \
		.long		((4+3)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2), MAKEPTR(SYM##tag3) @\
name: \
		.long		((3+3)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2, value3
#define DEFFRAME4(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4) \
name##Map: \
		.long		((4+4)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2), MAKEPTR(SYM##tag3), MAKEPTR(SYM##tag4) @\
name: \
		.long		((3+4)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2, value3, value4
#define DEFFRAME5(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5) \
name##Map: \
		.long		((4+5)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2), MAKEPTR(SYM##tag3), MAKEPTR(SYM##tag4), MAKEPTR(SYM##tag5) @\
name: \
		.long		((3+5)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2, value3, value4, value5
#define DEFFRAME6(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6) \
name##Map: \
		.long		((4+6)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2), MAKEPTR(SYM##tag3), MAKEPTR(SYM##tag4), MAKEPTR(SYM##tag5), MAKEPTR(SYM##tag6) @\
name: \
		.long		((3+6)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2, value3, value4, value5, value6
#define DEFFRAME7(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6, tag7, value7) \
name##Map: \
		.long		((4+7)<<10) + 0x41, 0, MAKEINT(2), NILREF @\
		.long		MAKEPTR(SYM##tag1), MAKEPTR(SYM##tag2), MAKEPTR(SYM##tag3), MAKEPTR(SYM##tag4), MAKEPTR(SYM##tag5), MAKEPTR(SYM##tag6), MAKEPTR(SYM##tag7) @\
name: \
		.long		((3+7)<<10) + 0x43, 0, MAKEPTR(name##Map) @\
		.long		value1, value2, value3, value4, value5, value6, value7
#include "FrameDefs.h"
#undef DEFFRAME
#undef DEFFRAME2
#undef DEFFRAME3
#undef DEFFRAME4
#undef DEFFRAME5
#undef DEFFRAME6
#undef DEFFRAME7


;-------------------------------------------------------------------------------
;	Phase II -- create Refs and Ref stars for pseudo-RefArg creation.
;-------------------------------------------------------------------------------

#define DEFSYM(name) \
		.globl	_RSYM##name, _RSSYM##name @\
_RSYM##name: \
		.long		MAKEPTR(SYM##name) @\
_RSSYM##name: \
		.long		_RSYM##name
#define DEFSYM_(name, sym) \
		.globl	_RSYM##name, _RSSYM##name @\
_RSYM##name: \
		.long		MAKEPTR(SYM##name) @\
_RSSYM##name: \
		.long		_RSYM##name
#include "SymbolDefs.h"
#undef DEFSYM
#undef DEFSYM_


#define DEFARRAY(name) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME(name, ref) \
		.globl	_RS##name @\
_R##name: \
		.long		ref @\
_RS##name: \
		.long		_R##name
#define DEFFRAME2(name, tag1, value1, tag2, value2) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME3(name, tag1, value1, tag2, value2, tag3, value3) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME4(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME5(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME6(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#define DEFFRAME7(name, tag1, value1, tag2, value2, tag3, value3, tag4, value4, tag5, value5, tag6, value6, tag7, value7) \
		.globl	_RS##name @\
_R##name: \
		.long		MAKEPTR(name) @\
_RS##name: \
		.long		_R##name
#include "FrameDefs.h"
#undef DEFARRAY
#undef DEFFRAME
#undef DEFFRAME2
#undef DEFFRAME3
#undef DEFFRAME4
#undef DEFFRAME5
#undef DEFFRAME6
#undef DEFFRAME7
