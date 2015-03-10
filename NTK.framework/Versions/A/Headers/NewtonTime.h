/*
	File:		NewtonTime.h

	Contains:	Timing gear for Newton build system.

	Written by:	Newton Research Group.
	
	To do:		remove ticks

*/

#if !defined(__NEWTONTIME_H)
#define __NEWTONTIME_H 1

#if !defined(__NEWTONTYPES_H)
#include "NewtonTypes.h"
#endif

#if !defined(__KERNELTYPES_H)
#include "KernelTypes.h"
#endif


/*--------------------------------------------------------------------------------
	NOTE
	The maximum time that can be represented by a Timeout is 14 minutes.
	If you need to compute a future time that is a greater amount into the future,
	you must use a CTime and apply your own conversion beyond minutes.
	For example, if you wanted to get the time for one day you would:
		CTime oneDay(1*24*60, kMinutes);
	(1 day, 24 hours in a day, 60 minutes in an hour)
--------------------------------------------------------------------------------*/

typedef uint32_t	HardwareTimeUnits;
typedef uint32_t	Timeout;

enum
{
	kNoTimeout = 0,
	kTimeOutImmediate = 0xFFFFFFFF
};

const Timeout kSleepForever = 0xFFFFFFFF;		// will cause sleep never to return


/*--------------------------------------------------------------------------------
	Use TimeUnits enumeration to construct relative time values
	These enumerations would be the second argument to the CTime
	constructor that takes amount and units. For example a relative
	CTime object that is 10 seconds in length could be constructed as:

		CTime(10, kSeconds)

	Note that the send delayed call in ports takes an ABSOLUTE CTime
	object. Such an object is created by getting the absolute time
	from GetGlobalTime() + delta.
--------------------------------------------------------------------------------*/

#if defined(hasCirrus)

/* New chipset has a different time base than old. We change it here. */

enum TimeUnits
{
	kSystemTimeUnits	=       1,			// to convert to (amount, units)
	kMicroseconds		=       4,			// clock ticks in a microsecond (3.6864MHz clk)
	kMilliseconds		=    3686,
	kMacTicks			=   61440,			// for compatibility
	kSeconds				= 3686400,
	kMinutes				=      60 * kSeconds
};

#else	/* use microseconds */

enum TimeUnits
{
	kSystemTimeUnits	=     1,							// to convert to (amount, units)
	kMicroseconds		=     1,							// number of units in a microsecond (sic)
	kMilliseconds		=  1000 * kMicroseconds,
	kSeconds				=  1000 * kMilliseconds,
	kMinutes				=    60 * kSeconds
};

#endif

ULong		RealClock(void);						// gets minutes based realtime clock
ULong		RealClockSeconds(void);				// gets seconds based realtime clock
void		SetRealClock(ULong minutes);		// sets realtime clock minutes - since 1/1/04 12:00am
void		SetRealClockSeconds(ULong seconds);	// sets realtime clock seconds - since 1/1/04 12:00am


#ifdef __cplusplus

#if TARGET_RT_BIG_ENDIAN
struct Int64
{
	 int32_t hi;
	uint32_t lo;
};
#else
struct Int64
{
	uint32_t lo;
	 int32_t hi;
};
#endif

/*--------------------------------------------------------------------------------
	C T i m e

	CTimes are used to represent moments in time.
	For instance, if you want to send a message a day from now, you find now
	and add in one day.
--------------------------------------------------------------------------------*/

class CTime
{
public:
			CTime()								{ }
			CTime(const CTime & x)			{ fTime = x.fTime; };
			CTime(ULong low)					{ set(low); }
			CTime(ULong low, ULong high)	{ set(low, SLong(high)); }
			CTime(ULong amount, TimeUnits units) { set(amount, units); }

	void 	set(ULong low)						{ fTime.part.lo = low; fTime.part.hi = 0L; }
	void 	set(ULong low, SLong high)		{ fTime.part.lo = low; fTime.part.hi = high; }
	void	set(ULong amount, TimeUnits units);

	ULong	convertTo(TimeUnits units);

			operator	ULong()	const			{ return fTime.part.lo; }

	CTime operator+  (const CTime& b)	{ CTime ret(*this); ret.fTime.full += b.fTime.full; return ret; }
	CTime operator-  (const CTime& b)	{ CTime ret(*this); ret.fTime.full -= b.fTime.full; return ret; }

	BOOL	operator== (const CTime& b) const	{ return fTime.full == b.fTime.full; }
	BOOL	operator!= (const CTime& b) const	{ return fTime.full != b.fTime.full; }
	BOOL	operator>  (const CTime& b) const	{ return fTime.full >  b.fTime.full; }
	BOOL	operator>= (const CTime& b) const	{ return fTime.full >= b.fTime.full; }
	BOOL	operator<  (const CTime& b) const	{ return fTime.full <  b.fTime.full; }
	BOOL	operator<= (const CTime& b) const	{ return fTime.full <= b.fTime.full; }

//private:
//	friend ULong	CTimeToMilliseconds(CTime inTime);
//	friend ULong	GetTicks(void);	// we want to lose this eventually

	union
	{
		int64_t	full;
		Int64		part;	// CUPort::sendGoo needs hi,lo longs
	} fTime;
};

// GetGlobalTime -
// returns a CTime moment representing the current time.
extern "C" CTime	GetGlobalTime(void);

// GetTaskTime -
// returns a CTime duration representing the time spent in the specified task.
extern "C" CTime	GetTaskTime(ObjectId inTaskId = 0);

// TimeFromNow -
// returns a CTime moment representing a time in the future.
// NOTE: You can only specify a moment up to 14 minutes into the future
// using this method.  If you need a longer distance into the future,
// simply add the future CTime duration to the current time from GetGlobalTime.
extern "C" CTime	TimeFromNow(Timeout inDeltaTime);

ULong		CTimeToMilliseconds(CTime inTime);

void		Wait(ULong inMilliseconds);
void		Sleep(Timeout inTimeout);
void		SleepTill(CTime * inFutureTime);

#endif	/* __cplusplus */

#endif	/* __NEWTONTIME_H */
