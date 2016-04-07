/*
	File:		ProjectDocument.h

	Contains:	Project document declarations for the Newton Toolkit.
					NTX uses WindowsNTK format -- an NSOF flattened project object.
					We can also import MacNTK project files, but we don’t save that format.
					Project settings are held in a Ref object, projectRef.
					The project’s files are built into an NSMuatable Array, projectItems, for convenience.
					This array is used to populate the source list sidebar and is
					modified whan files are added/moved/deleted.
					The master projectRef.projectItems Ref is updated before building the project
					or flattening it out to disk.

	To do:	save Inspector text as attributed string
				save changes to files
				save window split positions
				collapse window subviews properly
				don’t skip a line on up-arrow from bottom line
				add views for non-NewtonScript file types:
					easily done for .newtonpkg, .newtonstream
					move on to .newtonlayout
				comms sometimes dropped for no apparent reason

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
@class NTXProjectWindowController, NTXEditViewController, NTXReader;

@interface NTXProjectDocument : NSDocument
{
	// the project, as flattened to disk
	RefStruct projectRef;
	NTXProjectWindowController * windowController;
}
@property(strong) NSProgress * progress;
@property(strong) NTXEditViewController * viewController;

@property(assign) Ref projectRef;
// the files in projectRef.projectItems.items[] as NTXProjectItem*s
@property(strong) NSMutableArray * projectItems;
@property(assign) NSInteger selectedItem;

// Build menu actions
- (IBAction) buildPackage: (id) sender;
- (IBAction) downloadPackage: (id) sender;
- (IBAction) exportPackage: (id) sender;

- (NSURL *) build;								// build package/stream
- (Ref) import:(NTXReader *)inReader;		// import MacNTK project -- data & resource forks
@end
