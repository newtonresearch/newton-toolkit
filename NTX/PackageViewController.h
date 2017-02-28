/*
	File:		PackageViewController.h

	Abstract:	Interface for NTXPackageViewController class.

	Written by:		Newton Research, 2016.
*/

#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
	N T X P a c k a g e V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@interface NTXPackageViewController : NSViewController
@property IBOutlet NSStackView * stackView;
@property IBOutlet NSView * infoView;
-(void)viewWillLayout;
@end

