
#import "Controller.h"

#import <mach/mach_port.h>
#import <mach/mach_interface.h>
#import <mach/mach_init.h>

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>

io_connect_t		gRootPort;

void callback(void * x, io_service_t y, natural_t messageType, void * messageArg)
{
	switch (messageType)
	{
	case kIOMessageSystemWillSleep:
		[(NTXController *)[NSApp delegate] applicationWillSleep];
		IOAllowPowerChange(gRootPort, (long) messageArg);
		break;
	case kIOMessageCanSystemSleep:
		if ([(NTXController *)[NSApp delegate] applicationCanSleep])
			IOAllowPowerChange(gRootPort, (long) messageArg);
		else
			IOCancelPowerChange(gRootPort, (long) messageArg);
		break;
/*	case kIOMessageSystemHasPoweredOn:
		printf("Just had a nice snooze\n");
		break; */
	}
}



int main(int argc, const char * argv[])
{
	IONotificationPortRef notify;
	io_object_t anIterator;

	gRootPort = IORegisterForSystemPower(0, &notify, callback, &anIterator);
	CFRunLoopAddSource(CFRunLoopGetCurrent(),
							IONotificationPortGetRunLoopSource(notify),
							kCFRunLoopDefaultMode);
                        
	return NSApplicationMain(argc, argv);
}
