/*	File:		Iterators.h	Contains:	Array and frame slot iterators.	Written by:	Newton Research Group.*/#if !defined(__ITERATORS_H)#define __ITERATORS_H 1/*----------------------------------------------------------------------	C O b j e c t I t e r a t o r----------------------------------------------------------------------*/class CObjectIterator{public:				CObjectIterator(RefArg inObj, bool includeSiblings = NO);				~CObjectIterator();	void		reset(void);	void		resetWithObject(RefArg inObj);	int		next(void);	bool		done(void);	Ref		tag(void);	Ref		value(void);private:	RefStruct	fTag;	RefStruct	fValue;	RefStruct	fObj;	bool			fIncludeSiblings;	int			fIndex;	// reset to -1 before iteration	ArrayIndex	fLength;	RefStruct	fMapRef;	// NILREF indicates an Array iterator	ExceptionCleanup	x;};inline Ref	CObjectIterator::tag(void){ return fTag; }inline Ref  CObjectIterator::value(void){ return fValue; }#define FOREACH(obj, value_var) \	{ \		CObjectIterator * _iter = new CObjectIterator(obj); \		if (_iter == NULL) OutOfMemory(); \		RefVar value_var; \		unwind_protect { \			while (!_iter->done()) { \				value_var = _iter->value();#define FOREACH_WITH_TAG(obj, tag_var, value_var) \	{ \		CObjectIterator * _iter = new CObjectIterator(obj); \		if (_iter == NULL) OutOfMemory(); \		RefVar tag_var; \		RefVar value_var; \		unwind_protect { \			while (!_iter->done()) { \				tag_var = _iter->tag(); \				value_var = _iter->value();#define END_FOREACH \				_iter->next(); \			} \		} \		on_unwind { \			delete _iter; \		} \		end_unwind; \	}/* This is used like	RefVar obj;	...	FOREACH(obj, value)		...		DoSomething(value);		...	END_FOREACH	...or 	RefVar obj;	...	FOREACH_WITH_TAG(obj, tag, value)		...		if (tag == kSomething)			DoSomething(value);		...	END_FOREACH	...*/ #define WITH_LOCKED_BINARY(obj, ptr_var) \	unwind_protect { \		void * ptr_var = LockedBinaryPtr(obj);#define END_WITH_LOCKED_BINARY(obj) \	} \	on_unwind { \		UnlockRefArg(obj); \	} \	end_unwind;/*----------------------------------------------------------------------	P r e c e d e n t s----------------------------------------------------------------------*/class CPrecedents{public:				CPrecedents();				~CPrecedents();	ArrayIndex	add(RefArg inObj);	ArrayIndex	find(RefArg inObj);	Ref			get(ArrayIndex index);	void			set(ArrayIndex index, RefArg inObj);private:	RefStruct	fPrecArray;	ArrayIndex	fNumEntries;};#endif	/* __ITERATORS_H */