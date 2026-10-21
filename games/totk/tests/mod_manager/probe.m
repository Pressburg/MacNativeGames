// app/mod_manager.m: the overlay the game loads is rebuilt from the mods that are on, and the manifest names every
// file with its size, its own SHA-256 and the original's SHA-256 (as the runtime checks at start).
// The app's game folder is given, so the probe can point it at a fake one with a small RomFS image and index.
// usage: mod-manager-probe   (exit 0 = all checks passed)
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <stdio.h>
#include <string.h>
#include "mod_manager.h"

static int failures, checked;
static void check(int ok, const char *what) { checked++; if (!ok) { failures++; fprintf(stderr, "FAIL: %s\n", what); } }

static NSString *sha256_data(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

/* The index the app's RomFS backend writes (scripts/prepare_romfs_backend.py): the magic, the file count, the
   strings' size, then one row per file (offset, size, name offset, name length) and the names. */
static NSData *index_bytes(NSDictionary<NSString *, NSArray<NSNumber *> *> *files) {
    NSMutableData *rows = [NSMutableData data], *strings = [NSMutableData data];
    NSArray *names = [files.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *name in names) {
        uint64_t offset = files[name][0].unsignedLongLongValue, size = files[name][1].unsignedLongLongValue;
        uint32_t at = (uint32_t)strings.length, length = (uint32_t)(name.length + 1);
        [strings appendData:[name dataUsingEncoding:NSUTF8StringEncoding]];
        [strings appendBytes:"\0" length:1];
        uint64_t row[2] = {offset, size}; uint32_t tail[2] = {at, length};
        [rows appendBytes:row length:16]; [rows appendBytes:tail length:8];
    }
    NSMutableData *out = [NSMutableData data];
    uint64_t header[2] = {names.count, 24 + names.count * 24};
    [out appendBytes:"TOTKRFS1" length:8]; [out appendBytes:header length:16];
    [out appendData:rows]; [out appendData:strings];
    return out;
}

static NSString *put_file(NSString *path, NSData *data) {
    [NSFileManager.defaultManager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                           withIntermediateDirectories:YES attributes:nil error:nil];
    [data writeToFile:path atomically:YES];
    return path;
}

int main(void) {
    @autoreleasepool {
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mod-manager-probe"];
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        NSString *app = [root stringByAppendingPathComponent:@"totk"], *version = @"v121";
        NSString *romfs = [app stringByAppendingPathComponent:[NSString stringWithFormat:@"extracted/%@/romfs", version]];
        /* the app's image: two files the game has, and the index that names them */
        NSData *image = [NSData dataWithBytes:"ORIGINAL-A\0\0\0\0ORIGINAL-B\0\0" length:26];
        put_file([romfs stringByAppendingPathComponent:@"romfs.bin"], image);
        put_file([romfs stringByAppendingPathComponent:@"runtime-index.bin"],
              index_bytes(@{@"Pack/A.pack.zs": @[@0, @10], @"Pack/B.pack.zs": @[@12, @10]}));
        /* the app's own overlay: it replaces Pack/A.pack.zs itself */
        NSString *patches = [app stringByAppendingPathComponent:[NSString stringWithFormat:@"extracted/%@/romfs-patches", version]];
        put_file([patches stringByAppendingPathComponent:@"manifest.tsv"],
              [@"# path\tsize\tsha256\toriginal_sha256\nPack/A.pack.zs\t1\tdeadbeef\tdeadbeef\n" dataUsingEncoding:NSUTF8StringEncoding]);
        /* the library: two mods, one of them replacing a file the game has, the other adding a new one */
        NSString *library = [root stringByAppendingPathComponent:@"library"];
        NSData *modA = [@"MODIFIED-A" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *modNew = [@"A-NEW-FILE" dataUsingEncoding:NSUTF8StringEncoding];
        put_file([library stringByAppendingPathComponent:@"Fog/romfs/Pack/B.pack.zs"], modA);
        put_file([library stringByAppendingPathComponent:@"Extra/romfs/Pack/New.pack.zs"], modNew);
        /* the app's own file, which a mod also replaces: the manager leaves it out */
        put_file([library stringByAppendingPathComponent:@"Own/romfs/Pack/A.pack.zs"], [@"MODIFIED-A" dataUsingEncoding:NSUTF8StringEncoding]);
        NSString *overlay = [root stringByAppendingPathComponent:@"overlay"], *why = nil;
        BOOL ok = mod_manager_write_manifest_in(app, overlay, library, version, [NSSet setWithObjects:@"Fog", @"Extra", nil], &why);
        check(ok, "the overlay is written");
        NSString *manifest = [NSString stringWithContentsOfFile:[overlay stringByAppendingPathComponent:@"manifest.tsv"]
                                                        encoding:NSUTF8StringEncoding error:nil];
        check([manifest containsString:@"Pack/B.pack.zs"], "the mod's file is in the manifest");
        check([manifest containsString:@"Pack/New.pack.zs"], "the new file is in the manifest");
        check(![manifest containsString:@"Pack/A.pack.zs"], "the file the app replaces itself is left out");
        check([manifest containsString:sha256_data(modA)], "the file's own SHA-256 is in the manifest");
        check([manifest containsString:sha256_data([image subdataWithRange:NSMakeRange(12, 10)])], "the original's SHA-256 is in the manifest");
        check([manifest containsString:@"\t-\t"] || [manifest containsString:@"-\n"], "a new file has no original");
        BOOL copied = [NSFileManager.defaultManager fileExistsAtPath:[overlay stringByAppendingPathComponent:@"Pack/B.pack.zs"]];
        check(copied, "the file is copied into the overlay");
        /* a mod that is off is not in the overlay, and the file of one that was on is removed when it is turned off */
        ok = mod_manager_write_manifest_in(app, overlay, library, version, [NSSet setWithObject:@"Fog"], &why);
        manifest = [NSString stringWithContentsOfFile:[overlay stringByAppendingPathComponent:@"manifest.tsv"]
                                              encoding:NSUTF8StringEncoding error:nil];
        check(ok && ![manifest containsString:@"Pack/New.pack.zs"], "a mod that is off is not in the manifest");
        BOOL gone = ![NSFileManager.defaultManager fileExistsAtPath:[overlay stringByAppendingPathComponent:@"Pack/New.pack.zs"]];
        check(gone, "the file of a mod that was turned off is removed from the overlay");
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("{\"status\":\"%s\",\"probe\":\"mod-manager\",\"checked\":%d,\"failures\":%d}\n", failures ? "fail" : "pass", checked, failures);
    }
    return failures != 0;
}
