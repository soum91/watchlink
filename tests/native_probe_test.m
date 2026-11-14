#import "../Native/Probe.m"

static void Require(BOOL value, NSString *message) {
    if (!value) { fprintf(stderr,"Probe test failed: %s\n",message.UTF8String); exit(1); }
}
int main(void) {
    @autoreleasepool {
        NSFileManager *fm=NSFileManager.defaultManager;
        NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *container=[root stringByAppendingPathComponent:@"private-test-container-identifier"];
        [fm createDirectoryAtPath:[container stringByAppendingPathComponent:@"Library/DeviceRegistry"] withIntermediateDirectories:YES attributes:nil error:nil];
        NSDictionary *metadata=@{@"MCMMetadataIdentifier":@"com.apple.nanoregistry.private-test-owner"};
        NSString *file=[container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        [metadata writeToFile:file atomically:YES];
        NSDictionary *survey=DirectorySurvey(root);
        Require([survey[@"containerMetadataRead"] unsignedIntegerValue]==1,@"read bounded container metadata");
        Require([survey[@"knownComponents"] containsObject:@"nanoregistry"],@"detect known component category");
        Require([survey[@"knownComponentStorage"][@"nanoregistry"][0][@"registry"][@"metadata"] boolValue],@"detect candidate registry storage");
        NSString *json=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:survey options:0 error:nil] encoding:NSUTF8StringEncoding];
        Require([json rangeOfString:@"private-test"].location==NSNotFound,@"do not export container names or identifiers");
        [fm removeItemAtPath:file error:nil];
        NSString *outside=[root stringByAppendingPathComponent:@"outside-test.plist"];
        [metadata writeToFile:outside atomically:YES];
        symlink(outside.fileSystemRepresentation,file.fileSystemRepresentation);
        Require([DirectorySurvey(root)[@"containerMetadataRead"] unsignedIntegerValue]==0,@"do not follow metadata symlinks");
        [fm removeItemAtPath:root error:nil];
        [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        for (int i=0;i<70;i++) [fm createDirectoryAtPath:[root stringByAppendingPathComponent:[NSString stringWithFormat:@"entry-%d",i]] withIntermediateDirectories:NO attributes:nil error:nil];
        survey=DirectorySurvey(root);
        Require([survey[@"entriesVisited"] unsignedIntegerValue]==64 && [survey[@"limitReached"] boolValue],@"bound enumeration work");
        [fm removeItemAtPath:root error:nil];
        Require(![DirectorySurvey(root)[@"enumerated"] boolValue],@"report inaccessible or absent target");
        puts("Native container discovery, redaction, symlink and work-limit checks passed.");
    }
    return 0;
}
