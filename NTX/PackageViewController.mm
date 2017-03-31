/*
	File:		PackageViewController.mm

	Abstract:	Implementation of NTXPackageViewController subclasses.

	Written by:		Newton Research, 2016.
*/

#import "PackageViewController.h"
#import "NTXDocument.h"
#import "PkgPart.h"


/* -----------------------------------------------------------------------------
	N T X P a c k a g e V i e w C o n t r o l l e r
----------------------------------------------------------------------------- */

@implementation NTXPackageViewController

-(void)viewWillLayout {
	[super viewWillLayout];

	NSStoryboard * sb = self.storyboard;

	// add view controllers for package part info
	NTXPackageDocument * document = self.representedObject;
	NSView * prevview = self.infoView;
	for (PkgPart * part in document.parts) {
		NSViewController * viewController = [sb instantiateControllerWithIdentifier:[self viewControllerNameFor:part.partType]];
		NSView * subview = viewController.view;
		NSStackView * superview = self.stackView;
		viewController.representedObject = part;
		[subview setTranslatesAutoresizingMaskIntoConstraints:NO];
		[superview addSubview:subview];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeLeft	 relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeLeft	multiplier:1 constant:0]];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeRight	 relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeRight	multiplier:1 constant:0]];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeTop	 relatedBy:NSLayoutRelationEqual toItem:prevview attribute:NSLayoutAttributeBottom	multiplier:1 constant:0]];
//		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeBottom	multiplier:1 constant:0]];
		prevview = subview;
	}
}


/* -----------------------------------------------------------------------------
	Return storyboard viewcontroller id for part type.
----------------------------------------------------------------------------- */

- (NSString *)viewControllerNameFor:(unsigned int)inType {
	NSString * name;
	switch (inType) {
	case 'form':
	case 'auto':
		name = @"formPartViewController";
		break;
	case 'book':
		name = @"bookPartViewController";
		break;
//	case 'soup':
//		name = @"soupPartViewController";
//		break;
	default:
		name = @"PartViewController";
		break;
	}
	return name;
}

@end
