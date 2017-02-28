/*	File:		NewtonKit.h	Contains:	Public interface to the Newton framework.	Written by:	Newton Research Group, 2005.*/#if !defined(__NEWTONKIT_H)#define __NEWTONKIT_H 1#if __LITTLE_ENDIAN__#define hasByteSwapping 1#endif// USE MAC MEMORY FUNCTIONS#define __NEWTONMEMORY_H 1#include <NTK/Objects.h>#include <NTK/Iterators.h>#include <NTK/RSSymbols.h>#include <NTK/Unicode.h>#include <NTK/NewtonScript.h>#include <NTK/OSErrors.h>#include <NTK/Pipes.h>// access to global NewtonScript varsextern Ref		gVarFrame;extern Ref *	RSgVarFrame;extern Ref		gFunctionFrame;extern Ref *	RSgFunctionFrame;// Some commonly used, but strangely private functions#ifdef __cplusplusextern "C" {#endifRef		GetProtoVariable(RefArg context, RefArg name, BOOL * exists = NULL);Ref		DoMessage(RefArg rcvr, RefArg msg, RefArg args);void		PrintObject(Ref obj, int indent);int		REPprintf(const char * inFormat, ...);void		REPflush(void);#ifdef __cplusplus}#endifextern void		FlattenRef(RefArg inRef, CPipe & inPipe);extern long		FlattenRefSize(RefArg inRef);extern Ref		UnflattenRef(CPipe & inPipe);extern long		UnflattenRefSize(CPipe & inPipe);#endif	/* __NEWTONKIT_H */