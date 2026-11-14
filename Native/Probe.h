#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif
NS_ASSUME_NONNULL_BEGIN
NSString *DWRunProbe(BOOL requestProtectedAccess);
#if TARGET_OS_IOS
// UIKit can raise Objective-C exceptions in restricted jailbreak installations.
// Return a generic error / nil controller instead of terminating Swift code.
NSString * _Nullable DWCopyReport(NSString *text);
UIViewController * _Nullable DWMakeReportExporter(NSURL *fileURL);
UIViewController * _Nullable DWMakeReportSharer(NSURL *fileURL);
#endif
NS_ASSUME_NONNULL_END
