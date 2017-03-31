/*
	File:		ProjectDocument.h

	Abstract:	Project document declarations for the Newton Toolkit.
					NTX uses WindowsNTK format -- an NSOF flattened project object.
					We can also import MacNTK project files, but we don’t save that format.
					Project settings are held in a frame Ref object, projectRef.
					The project’s file projectItems are mirrored in an NSMutableDictionary.
					This is used to populate the source list sidebar and is
					modified whan files are added/moved/deleted.
					The master projectRef.projectItems Ref is updated before building the project
					or flattening it out to disk.

					The document’s projectRef contains:
					projectRef: {
						...
						projectItems: {		<-- this is the frame we want
							selectedItem: nil,	// NTX extension -- more accurately, last viewed item
							sortOrder: 0,
							items: [
								{ file: { class:'fileReference, fullPath:"/Users/simon/Projects/newton-toolkit/Test/Demo/Playground.ns" },
								  type: 5,
								  isMainLayout: nil },
								  ...
							]
						}
					}
					We transform this to MacOS:
						projectItems: [
							"selectedItem": 1,
							"sortOrder": 0,
							"items": [
								[ "url": NSURL,
								  "type": 5,
								  "isMainLayout": NO ],
								  ...
							]
						]
					The NTXSourceListViewController represents this dictionary; displays/updates "items" and updates "selectedItem".


	To do:	save Inspector text as attributed string
				save changes to files
				save window split positions
				collapse window subviews properly
				don’t skip a line on up-arrow from bottom line
				add views for non-NewtonScript file types: .newtonlayout
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
@class NTXProjectWindowController;

@interface NTXProjectDocument : NSDocument
{
	// the project, as flattened to disk
	RefStruct _projectRef;
}
@property(readonly) NSString * storyboardName;
@property(assign) Ref projectRef;
// projectRef.projectItems -- the files in .items[] as NTXProjectItem*s
@property(strong) NSMutableDictionary * projectItems;

// package parts we build, of PackagePart class
@property(strong) NSMutableArray * parts;

@property(strong) NTXProjectWindowController * windowController;
//@property(strong) NSViewController * viewController;

// File menu actions
- (IBAction)saveAllProjectItems:(id)sender;

// Build menu actions
- (IBAction)buildPackage:(id)sender;
- (IBAction)downloadPackage:(id)sender;
- (IBAction)exportPackage:(id)sender;

- (NSURL *)buildPkg;								// build package/stream
- (NSData *)buildPackageData:(int)alignment;
@end
