/*
	File:		FeedbackProtocol.h

	Abstract:	Feedback Protocol from toolkit communicatoins layer to UI.

	Written by:	Newton Research, 2015.
*/

#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
	Keys for notifications sent by the communications layer.
----------------------------------------------------------------------------- */
extern NSString * const kNubConnectionDidChangeNotification;
extern NSString * const kNubOwnerDidChangeNotification;

/* -----------------------------------------------------------------------------
	N T X N u b F e e d b a c k
	Protocol for reporting received objects.
----------------------------------------------------------------------------- */
@protocol NTXNubFeedback
@property(readonly) NSProgress * progress;
- (void)receivedText:(NSString *)inText;
- (void)receivedObject:(RefArg)inObject;
@end

