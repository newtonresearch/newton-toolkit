/*
	File:		NTKProtocol.h

	Contains:	Newton Toolkit communications protocol.

	Written by:	Newton Research Group, 2007.
*/

#if !defined(__NTKPROTOCOL_H)
#define __NTKPROTOCOL_H 1

// from Newton/Events.h
typedef uint32_t EventClass;
typedef uint32_t EventId;
#define kNewtEventClass	'newt'

/*------------------------------------------------------------------------------
	The NTK protocol packet structure -- same as the dock.
------------------------------------------------------------------------------*/
typedef uint32_t EventType;

struct DockEventHeader
{
	EventClass	evtClass;
	EventId		evtId;
	EventType	tag;
	uint32_t		length;
};

#define kIndeterminateLength	0xFFFFFFFF


/*------------------------------------------------------------------------------
	The toolkit event id.
------------------------------------------------------------------------------*/
#define kToolkitEventId				'ntp '


/*------------------------------------------------------------------------------
	Default timeout in seconds if no comms acivity.
------------------------------------------------------------------------------*/
#define kDefaultTimeout				30


/*------------------------------------------------------------------------------
	NTK protocol commands.
------------------------------------------------------------------------------*/

// Newton -> Desktop
#define kTConnect						'cnnt'
#define kTDownload					'dpkg'

#define kTText							'text'
#define kTResult						'rslt'
#define kTEOM							'teom'

#define kTEnterBreakLoop			'eext'
#define kTExitBreakLoop				'bext'

#define kTExceptionError			'eerr'
#define kTExceptionMessage			'estr'
#define kTExceptionRef				'eref'

// Desktop -> Newton
#define kTOK							'okln'
#define kTExecute						'lscb'
#define kTSetTimeout					'stou'
#define kTDeletePackage				'pkgX'
#define kTLoadPackage				'pkg '

// Desktop -> Newton or Newton -> Desktop
#define kTObject						'fobj'
#define kTCode							'code'
#define kTTerminate					'term'

#endif	/* __NTKPROTOCOL_H */
