/*
	File:		ProjectDocument.h

	Contains:	Project document declarations for the Newton Toolkit.

	Written by:	Newton Research Group, 2014.
*/

#import <Cocoa/Cocoa.h>
#import "NTXEditorView.h"
#import "ProjectTypes.h"
#import "ProjectItem.h"

/* -----------------------------------------------------------------------------
	Types of file we recognise.
----------------------------------------------------------------------------- */
extern NSString * const NTXProjectFileType;
extern NSString * const NTXLayoutFileType;
extern NSString * const NTXScriptFileType;
extern NSString * const NTXStreamFileType;
extern NSString * const NTXCodeFileType;
extern NSString * const NTXPackageFileType;

/* -----------------------------------------------------------------------------
	N T X P r o j e c t D o c u m e n t
----------------------------------------------------------------------------- */
@class NTXEditViewController, NTXReader;

@interface NTXProjectDocument : NSDocument
{
	// the project, as flattened to disk
	RefStruct projectRef;
}
@property(strong) NSProgress * progress;
@property(strong) NTXEditViewController * viewController;

@property(assign) Ref projectRef;
// the files in projectRef.projectItems.items[] as NTXProjectItem*s
@property(strong) NSMutableArray * projectItems;
@property(assign) NSInteger selectedItem;

- (void) addFiles:(NSArray *)inFiles afterIndex:(NSInteger)index;

- (NSURL *) build;								// build package/stream
- (Ref) import:(NTXReader *)inReader;		// import MacNTK project -- data & resource forks
@end

