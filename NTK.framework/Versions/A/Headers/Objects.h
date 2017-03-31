/*
	File:		Objects.h

	Contains:	Newton object system.
					Basic object interface.

	Written by:	Newton Research Group.

	A function that takes more than one argument cannot safely take any Ref
	arguments, since it would be possible to invalidate a Ref argument in the
	process of evaluating another argument.  However, to avoid the overhead of
	automatic RefVar creation for critical functions such as EQ, versions are
	available that take Ref arguments (usually called something like EQRef).
	These versions should only be used when all the arguments are simple
	variable references or other expressions that cannot invalidate Refs.

	NOTE that this header declares and uses RefVar C++ classes, so is
	unsuitable for inclusion by plain C files.
*/

#if !defined(__OBJECTS_H)
#define __OBJECTS_H 1

//#if !defined(__CONFIGFRAMES_H)
//#include "ConfigFrames.h"
//#endif

#if !defined(__NEWTON_H)
#include "Newton.h"
#endif

/*------------------------------------------------------------------------------
	R e f   T a g   B i t s
------------------------------------------------------------------------------*/

#define kRefTagBits		  2
#if __LP64__
#define kRefValueBits	 62
#else
#define kRefValueBits	 30
#endif
#define kRefValueMask	(~0UL << kRefTagBits)
#define kRefTagMask		 ~kRefValueMask

#define kRefImmedBits	 2
#define kRefImmedMask	(~0UL << kRefImmedBits)

enum
{
	kTagInteger,
	kTagPointer,
	kTagImmed,
	kTagMagicPtr
};

enum
{
	kImmedSpecial,
	kImmedChar,
	kImmedBoolean,
	kImmedReserved
};


/*------------------------------------------------------------------------------
	O b j e c t   T a g   F u n c t i o n s
------------------------------------------------------------------------------*/

#define	MAKEINT(i)				(((long) (i)) << kRefTagBits)
#define	MAKEIMMED(t, v)		((((((long) (v)) << kRefImmedBits) | ((long) (t))) << kRefTagBits) | kTagImmed)
#define	MAKECHAR(c)				MAKEIMMED(kImmedChar, (unsigned) c)
#define	MAKEBOOLEAN(b)			(b ? TRUEREF : FALSEREF)
#define	MAKEPTR(p)				((Ref)((char*)p + 1))
#define	MAKEMAGICPTR(index)	((Ref) (((long) (index)) << kRefTagBits) | kTagMagicPtr)

// constant values for comparison with a Ref
#define	NILREF			MAKEIMMED(kImmedSpecial, 0)
#define	TRUEREF			MAKEIMMED(kImmedBoolean, 1)
#define	FALSEREF			NILREF
#define	INVALIDPTRREF	MAKEINT(0)

/*------------------------------------------------------------------------------
	I m m e d i a t e   C l a s s   C o n s t a n t s
------------------------------------------------------------------------------*/

#define	kWeakArrayClass		MAKEIMMED(kImmedSpecial, 1)
#define	kFaultBlockClass		MAKEIMMED(kImmedSpecial, 2)
#define	kFuncClass				MAKEIMMED(kImmedSpecial, 3)
#define	kBadPackageRef			MAKEIMMED(kImmedSpecial, 4)
#define	kUnstreamableObject	MAKEIMMED(kImmedSpecial, 5)
#define	kSymbolClass			MAKEIMMED(kImmedSpecial, 0x5555)

#define	kPlainFuncClass		0x0032
#define	kPlainCFunctionClass	0x0132
#define	kBinCFunctionClass	0x0232

#define	ISFUNCCLASS(r)	(((r) & 0xFF) == kFuncClass)
#define	FUNCKIND(r)		(((unsigned) r) >> 8)

#define	RTAG(r)			(((Ref) (r)) & kRefTagMask)
#define	RVALUE(r)		(((Ref) (r)) >> kRefTagBits)
#define	RIMMEDTAG(r)	(RVALUE(r) & ~kRefImmedMask)
#define	RIMMEDVALUE(r)	(RVALUE(r) >> kRefImmedBits)
#define	ISINT(r)			(RTAG(r) == kTagInteger)
#define	NOTINT(r)		(RTAG(r) != kTagInteger)
#define	ISPTR(r)			((((Ref) (r)) & kTagPointer) != 0)
#define	ISREALPTR(r)	(RTAG(r) == kTagPointer)
#define	NOTREALPTR(r)	(RTAG(r) != kTagPointer)
#define	ISMAGICPTR(r)	(RTAG(r) == kTagMagicPtr)
#define	ISIMMED(r)		(RTAG(r) == kTagImmed)
#define	ISCHAR(r)		(ISIMMED(r) && (RIMMEDTAG(r) == kImmedChar))
#define	ISBOOLEAN(r)	(ISIMMED(r) && (RIMMEDTAG(r) == kImmedBoolean))

#define	ISNIL(r)			(((Ref) (r)) == NILREF)
#define	NOTNIL(r)		(((Ref) (r)) != NILREF)
#define	ISFALSE(r)		(((Ref) (r)) == FALSEREF)
#define	ISTRUE(r)		(((Ref) (r)) != FALSEREF)

extern "C" int _RPTRError(Ref r), _RINTError(Ref r), _RCHARError(Ref r);

inline long	RINT(Ref r)		{ return ISINT(r) ? RVALUE(r) : _RINTError(r); }
inline UniChar	RCHAR(Ref r)	{ return ISCHAR(r) ? (UniChar) RIMMEDVALUE(r) : _RCHARError(r); }


/*------------------------------------------------------------------------------
	R e f V a r

	C++ stuff to keep Ref usage simple.
------------------------------------------------------------------------------*/
extern "C"
{
extern	RefHandle *		AllocateRefHandle(Ref targetObj);
extern	void				DisposeRefHandle(RefHandle * Handle);
extern	void				ClearRefHandles(void);

extern	void				IncrementCurrentStackPos();
extern	void				DecrementCurrentStackPos();
}

//______________________________________________________________________________

class RefVar
{
public:
				RefVar();
				RefVar(Ref r);
				RefVar(const RefVar & o);
				~RefVar();

	RefVar &	operator=(Ref r);
	RefVar &	operator=(const RefVar & o);

	operator	long() const;

	RefHandle *	h;
};

inline	RefVar::RefVar()
{ h = AllocateRefHandle(NILREF); }

inline	RefVar::RefVar(Ref r)
{ h = AllocateRefHandle(r); }

inline	RefVar::RefVar(const RefVar & o)
{ h = AllocateRefHandle(o.h->ref); }

inline	RefVar::~RefVar()
{ DisposeRefHandle(h); }

inline	RefVar &	RefVar::operator=(Ref r)
{ h->ref = r; return *this; }

inline	RefVar &	RefVar::operator=(const RefVar & o)
{ h->ref = o.h->ref; return *this; }

inline				RefVar::operator	long() const
{ return h->ref; }

//______________________________________________________________________________

typedef const RefVar& RefArg;

#define RA(_rs) *reinterpret_cast<RefVar*>(&RS##_rs)
#define SYMA(_name) RA(SYM##_name)

extern	Ref	RNILREF;
extern	Ref *	RSNILREF;
extern	Ref *	RSTRUEREF;

//______________________________________________________________________________

class RefStruct : public RefVar
{
public:
				RefStruct();
				RefStruct(const Ref r);
				RefStruct(const RefVar & o);
				RefStruct(const RefStruct & o);
				~RefStruct();

	RefStruct &	operator=(const Ref r);
	RefStruct &	operator=(const RefVar & o);
	RefStruct &	operator=(const RefStruct & o);
};

inline	RefStruct::RefStruct() : RefVar()
{ h->stackPos = 0; }

inline	RefStruct::RefStruct(const Ref r) : RefVar(r)
{ h->stackPos = 0; }

inline	RefStruct::RefStruct(const RefVar & o) : RefVar(o)
{ h->stackPos = 0; }

inline	RefStruct::RefStruct(const RefStruct & o) : RefVar(o)
{ h->stackPos = 0; }

inline	RefStruct::~RefStruct()
{ }

inline	RefStruct & RefStruct::operator=(const Ref r)
{ h->ref = r; return *this; }

inline	RefStruct & RefStruct::operator=(const RefVar & o)
{ h->ref = o.h->ref; return *this; }

inline	RefStruct & RefStruct::operator=(const RefStruct & o)
{ return operator=((const RefVar &) o); }


//______________________________________________________________________________

class CObjectPtr : public RefVar
{
public:
					CObjectPtr();
					CObjectPtr(Ref);
					CObjectPtr(RefArg);
					CObjectPtr(const RefStruct &);
					~CObjectPtr();

	CObjectPtr &	operator=(Ref);
	CObjectPtr &	operator=(const CObjectPtr &);

	operator char*() const;
};

//______________________________________________________________________________

class CDataPtr : public CObjectPtr
{
public:
					CDataPtr() : CObjectPtr() {}	// for MakeStringObject
					CDataPtr(Ref r) : CObjectPtr(r) {}	// for SPrintObject

	CDataPtr &	operator=(Ref);
	CDataPtr &	operator=(const CDataPtr &);

	operator char*() const;
	operator unsigned char*() const;
};


//______________________________________________________________________________
// Macros as Functions

extern	Ref 		MakeInt(int i);
extern	Ref	 	MakeChar(unsigned char c);
extern	Ref		MakeBoolean(int val);

extern	bool		IsInt(Ref r);
extern	bool		IsChar(Ref r);
extern	bool		IsPtr(Ref r);
extern	bool		IsMagicPtr(Ref r);
extern	bool		IsRealPtr(Ref r);

extern	Ref		AddressToRef(void *);
extern	void *	RefToAddress(Ref r);
extern	int		RefToInt(Ref r);			
extern	UniChar	RefToUniChar(Ref r);		

//______________________________________________________________________________
// Object Class Functions

extern	Ref		ClassOf(Ref r);
extern	bool		IsArray(Ref r);
extern	bool		IsBinary(Ref r);
extern	bool		IsLargeBinary(Ref ref);
extern	bool		IsFrame(Ref r);
extern	bool		IsFunction(Ref r);
extern	bool		IsNativeFunction(Ref r);
extern	bool		IsNumber(Ref r);
extern	bool		IsReadOnly(Ref r);
extern	bool		IsReal(Ref r);
extern	bool		IsString(Ref r);
extern	bool		IsSymbol(Ref r);
extern	bool		IsInstance(Ref obj, Ref super);
extern	bool		IsSubclass(Ref sub, Ref super);
extern	void		SetClass(RefArg obj, RefArg theClass);

//______________________________________________________________________________
// General Object Functions

extern	Ref		AllocateBinary(RefArg theClass, ArrayIndex length);
extern	void		BinaryMunger(RefArg a1, ArrayIndex a1start, ArrayIndex a1count,
										 RefArg a2, ArrayIndex a2start, ArrayIndex a2count);
extern	bool		EQRef(Ref a, Ref b);
inline	bool		EQ(RefArg a, RefArg b) { return EQRef(a, b); }
extern	Ptr		SetupListEQ(Ref obj);
extern	bool		ListEQ(Ref a, Ref b, Ptr bPtr);
// Make all references to target refer to replacement instead
extern	void		ReplaceObject(RefArg target, RefArg replacement);
// Shallow clone of obj
extern	Ref		Clone(RefArg obj);
// Deep clone of obj
extern	Ref		DeepClone(RefArg obj);
// Really deep clone of obj (including maps and ensuring symbols are in RAM)
extern	Ref		TotalClone(RefArg obj);
// Don't clone except as necessary to ensure maps and symbols are in RAM
extern	Ref		EnsureInternal(RefArg obj);

//______________________________________________________________________________
// Array Functions

extern	Ref		MakeArray(ArrayIndex length);
extern	Ref		AllocateArray(RefArg theClass, ArrayIndex length);
extern	void		ArrayMunger(RefArg a1, ArrayIndex a1start, ArrayIndex a1count,
										RefArg a2, ArrayIndex a2start, ArrayIndex a2count);
extern	void		AddArraySlot(RefArg obj, RefArg element);
extern	ArrayIndex	ArrayPosition(RefArg array, RefArg element, ArrayIndex start, RefArg test);
extern	bool		ArrayRemove(RefArg array, RefArg element);
extern	void 		ArrayRemoveCount(RefArg array, ArrayIndex start, ArrayIndex removeCount);
extern	Ref		GetArraySlot(RefArg array, ArrayIndex slot);
extern	void		SetArraySlot(RefArg array, ArrayIndex slot, RefArg value);
// Sorts an array
// test = '|<|, '|>|, '|str<|, '|str>|, or any function object returning -1,0,1 (as strcmp)
// key = NILREF (use the element directly), or a path, or any function object
extern	void		SortArray(RefArg array, RefArg test, RefArg key);		

//______________________________________________________________________________
// Frame & Slot Functions

extern	Ref		AllocateFrame(void);
extern	bool		FrameHasPath(RefArg obj, RefArg path);
extern	bool		FrameHasSlot(RefArg obj, RefArg slot);
extern	Ref		GetFramePath(RefArg obj, RefArg path);
extern	Ref		GetFrameSlot(RefArg obj, RefArg slot);
extern	ArrayIndex	Length(Ref obj);		// Length in bytes or slots
// MapSlots calls a function on each slot of an array or frame object, giving it
// the tag (integer or symbol) and contents of each slot.  "Anything" is passed to
// func.  If func returns anything but NILREF, MapSlots terminates.
typedef	Ref	 (*MapSlotsFunction)(RefArg tag, RefArg value, unsigned long anything);
extern	void		MapSlots(RefArg obj, MapSlotsFunction func, unsigned long anything);
extern	void		RemoveSlot(RefArg frame, RefArg tag);
extern	void		SetFramePath(RefArg obj, RefArg thePath, RefArg value);
extern	void		SetFrameSlot(RefArg obj, RefArg slot, RefArg value);
extern	void		SetLength(RefArg obj, ArrayIndex length);

//______________________________________________________________________________
// Symbol Functions

extern	Ref		MakeSymbol(const char * name);	// Create or return a symbol
extern	const char *	SymbolName(Ref sym);					// Return a symbol�s name
extern	ULong		SymbolHash(Ref sym);					// Return a symbol's hash value
extern	int		SymbolCompareLexRef(Ref sym1, Ref sym2);
extern	int		SymbolCompareLex(RefArg sym1, RefArg sym2);
extern	int		symcmp(const char * s1, const char * s2);		// Case-insensitive comparison

//______________________________________________________________________________
// String Manipulation Functions

extern	Ref		ASCIIString(RefArg str);
extern	Ref		MakeStringFromCString(const char * str);
extern	Ref		MakeString(const UniChar * str);
extern	UniChar*	GetUString(RefArg str);
extern	bool		StrBeginsWith(RefArg str, RefArg prefix);
extern	bool		StrEndsWith(RefArg str, RefArg suffix);
extern	void		StrCapitalize(RefArg str);
extern	void		StrCapitalizeWords(RefArg str);
extern	void		StrUpcase(RefArg str);
extern	void		StrDowncase(RefArg str);
extern	bool		StrEmpty(RefArg str);
extern	void		StrMunger(RefArg s1, ArrayIndex s1start, ArrayIndex s1count,
									 RefArg s2, ArrayIndex s2start, ArrayIndex s2count);
extern	ArrayIndex	StrPosition(RefArg str, RefArg substr, ArrayIndex startPos);
extern	ArrayIndex	StrReplace(RefArg str, RefArg substr, RefArg replacement, ArrayIndex count);
extern	Ref		Substring(RefArg str, ArrayIndex start, ArrayIndex count);
extern	void		TrimString(RefArg str);

//______________________________________________________________________________
// Numeric Conversion Functions

extern	int		CoerceToInt(Ref r);
extern	double	CoerceToDouble(Ref r);
extern	double	CDouble(Ref r);

extern	Ref		MakeReal(double d);

//______________________________________________________________________________
// Exception Handling Functions

extern	void		ThrowOSErr(NewtonErr err);			// Object Store, not Operating System

extern	void		ThrowRefException(ExceptionName name, RefArg data);
extern	void		ThrowOutOfBoundsException(RefArg obj, ArrayIndex index);
extern	void		ThrowBadTypeWithFrameData(NewtonErr errorCode, RefArg value);
extern	void		ThrowExFramesWithBadValue(NewtonErr errorCode, RefArg value);
extern	void		ThrowExCompilerWithBadValue(NewtonErr errorCode, RefArg value);
extern	void		ThrowExInterpreterWithSymbol(NewtonErr errorCode, RefArg value);

extern	void		ExceptionNotify(Exception * inException);

DeclareException(exFrames, exRootException);
DeclareException(exFramesData, exRootException);
DeclareException(exStore, exRootException);
DeclareException(exGraf, exRootException);
DeclareException(exOutOfMemory, exRootException);	// evt.ex.outofmem
DeclareBaseException(exRefException);					// type.ref, data is a RefStruct*

inline void OutOfMemory(void)
{ Throw(exOutOfMemory, (void *)-10007, (ExceptionDestructor) 0); }

//______________________________________________________________________________
// Object Accessors

extern	unsigned	ObjectFlags(Ref r);

// Direct access (must lock/unlock before using pointers)
extern	void		LockRef(Ref r);
extern	void		UnlockRef(Ref r);
extern	Ptr		BinaryData(Ref r);
extern	Ref *		Slots(Ref r);

// DON'T USE THESE DIRECTLY!!!!
// MUST USE with macros WITH_LOCKED_BINARY and END_WITH_LOCKED_BINARY see below
extern	Ptr		LockedBinaryPtr(RefArg obj);
extern	void		UnlockRefArg(RefArg obj);

//______________________________________________________________________________
// Garbage Collection Functions

extern	void		GC();

#if defined(hasObjectConsolidation)
extern	void		ConsolidateObjects(bool doTotally);
#endif	/* hasObjectConsolidation */

extern	void		AddGCRoot(Ref * root);
extern	void		RemoveGCRoot(Ref * root);
//void	ClearGCRoots();
//void	ClearGCHooks();

typedef void (*GCProcPtr)(void*);
extern	void		GCRegister(void * refCon, GCProcPtr proc);
extern	void		GCUnregister(void * refCon);

extern	void		DIYGCRegister(void * refCon, GCProcPtr markFunction, GCProcPtr updateFunction);
extern	void		DIYGCUnregister(void * refCon);
extern	void		DIYGCMark(Ref r);
extern	Ref		DIYGCUpdate(Ref r);


#endif	/* __OBJECTS_H */
