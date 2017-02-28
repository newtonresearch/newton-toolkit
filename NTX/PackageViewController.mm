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

-(void)viewWillLayout
{
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
#if 0
		[superview addView:subview inGravity:NSStackViewGravityBottom];
#else
		[subview setTranslatesAutoresizingMaskIntoConstraints:NO];
		[superview addSubview:subview];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeLeft	 relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeLeft	multiplier:1 constant:0]];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeRight	 relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeRight	multiplier:1 constant:0]];
		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeTop	 relatedBy:NSLayoutRelationEqual toItem:prevview attribute:NSLayoutAttributeBottom	multiplier:1 constant:0]];
//		[superview addConstraint:[NSLayoutConstraint constraintWithItem:subview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeBottom	multiplier:1 constant:0]];
		prevview = subview;
#endif
	}

	// add view controllers for the parts we have
//	NSView * containerView = self.infoView;
//	NSRect containerFrame = containerView.frame;
//	NSSize partSize;
//	float ht = containerFrame.size.height;
//	float infoHt = ht;
//	containerFrame.origin.y += ht;
//	containerFrame.size.height = 0;
//	for (NSViewController * part in self.childViewControllers) {
//		ht = part.view.frame.size.height;
//		infoHt += ht;
//		partSize = part.view.frame.size;
//		partSize.width = containerFrame.size.width;
//		[part.view setFrameSize:partSize];
//		containerFrame.origin.y -= ht;
//		containerFrame.size.height += ht;
//		[containerView setFrameOrigin:containerFrame.origin];
//		[containerView setFrameSize:containerFrame.size];
//		[containerView addSubview:part.view];
//	}

	// scroll to the top
//	[containerView.enclosingScrollView.verticalScroller setFloatValue:0.0];
//	[containerView.enclosingScrollView.contentView scrollToPoint:NSMakePoint(0,0)];

//	NSDictionary * views = NSDictionaryOfVariableBindings(containerView);
//	[containerView setTranslatesAutoresizingMaskIntoConstraints:NO];
//	[superView addSubview:containerView];
//	[superView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[containerView]|" options:0 metrics:nil views:views]];
//	[superView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[containerView]" options:0 metrics:nil views:views]];

}


/* -----------------------------------------------------------------------------
	Return storyboard viewcontroller id for part type.
----------------------------------------------------------------------------- */

- (NSString *)viewControllerNameFor:(unsigned int)inType
{
	NSString * name;
	switch (inType)
	{
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

