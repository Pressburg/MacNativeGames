/* The player's RomFS mods: the manager window (app/mod_manager.h).

   The game loads one overlay: the version folder, whose manifest.tsv names each file it replaces or adds. This
   window keeps a library of installed mods (each in the layout --mod takes: exefs/ for code, romfs/ for data) and
   rebuilds the overlay from the mods that are on: their romfs/ files are copied in and the manifest is written
   against the app's own RomFS, so the game can check every file at start (scripts/make_mod_manifest.py does the same
   at build time).

   A mod's code half cannot be applied while the game runs - the code modules are rewritten for Apple silicon at
   build time and bound by hash - so a code patch needs a build with --mod. The window says so instead of pretending.
   Nothing is written into the app bundle: the overlay and the library are under ~/Library/Application Support. */
#import "mod_manager.h"
#include <CommonCrypto/CommonDigest.h>
#include <stdio.h>
#include <string.h>
#include "game_version.h"
#include "include/totk_ui_lang.h"

#define UI(zh, en) @(TOTK_UI(zh, en))

/* ---- the app's own RomFS: the index and the image (scripts/prepare_romfs_backend.py writes the index) ---- */

/* The index's entries for the wanted paths: path -> @[offset, size] in the image. The index holds every file of the
   game (300,000 of them), so it is read once and only the wanted entries are kept. */
static NSDictionary<NSString *, NSArray<NSNumber *> *> *romfs_entries(NSString *appRoot, NSString *version, NSSet<NSString *> *wanted) {
    NSString *path = [appRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"extracted/%@/romfs/runtime-index.bin", version]];
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (data.length < 24) return @{};
    const uint8_t *bytes = data.bytes;
    if (memcmp(bytes, "TOTKRFS1", 8)) return @{};
    uint64_t count = 0, strings = 0;
    memcpy(&count, bytes + 8, 8); memcpy(&strings, bytes + 16, 8);
    if (strings > data.length || 24 + count * 24 > data.length) return @{};
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (uint64_t i = 0; i < count; i++) {
        const uint8_t *row = bytes + 24 + i * 24;
        uint64_t offset = 0, size = 0; uint32_t name = 0, length = 0;
        memcpy(&offset, row, 8); memcpy(&size, row + 8, 8); memcpy(&name, row + 16, 4); memcpy(&length, row + 20, 4);
        if (name + length > data.length) break;
        NSString *file = [[NSString alloc] initWithBytes:bytes + strings + name length:length - 1 encoding:NSUTF8StringEncoding];
        if (file && [wanted containsObject:file]) out[file] = @[@(offset), @(size)];
    }
    return out;
}

/* The SHA-256 of a file, or of a range of the app's image (hex, as the manifest wants it). */
static NSString *sha256_of(NSFileHandle *handle) {
    CC_SHA256_CTX ctx; CC_SHA256_Init(&ctx);
    while (YES) {
        NSData *chunk = [handle readDataOfLength:1 << 20];
        if (!chunk.length) break;
        CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}
static NSString *sha256_file(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    NSString *hex = sha256_of(handle);
    [handle closeFile];
    return hex;
}
static NSString *sha256_range(NSString *path, unsigned long long offset, unsigned long long size) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    [handle seekToFileOffset:offset];
    CC_SHA256_CTX ctx; CC_SHA256_Init(&ctx);
    unsigned long long left = size;
    while (left) {
        NSData *chunk = [handle readDataOfLength:(NSUInteger)(left < (1 << 20) ? left : (1 << 20))];
        if (!chunk.length) break;
        CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
        left -= chunk.length;
    }
    [handle closeFile];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

/* The paths the app replaces itself (its own RomFS overlay): a mod's copy of one of them is left out, because the
   game would take the app's file anyway (scripts/make_mod_manifest.py merges the two at build time). */
static NSSet<NSString *> *app_replaced_paths(NSString *appRoot, NSString *version) {
    NSString *folder = [appRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"extracted/%@", version]];
    NSMutableSet *paths = [NSMutableSet set];
    NSMutableArray<NSString *> *manifests = [NSMutableArray array];
    [manifests addObject:[folder stringByAppendingPathComponent:@"romfs-patches/manifest.tsv"]];
    NSString *out = [folder stringByAppendingPathComponent:@"romfs-patches-out"];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:out error:nil])
        [manifests addObject:[out stringByAppendingPathComponent:[name stringByAppendingPathComponent:@"manifest.tsv"]]];
    for (NSString *manifest in manifests) {
        NSString *text = [NSString stringWithContentsOfFile:manifest encoding:NSUTF8StringEncoding error:nil];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            NSRange tab = [line rangeOfString:@"\t"];
            if (tab.location != NSNotFound) [paths addObject:[line substringToIndex:tab.location]];
        }
    }
    return paths;
}

/* ---- the overlay the game loads ---- */

/* The files of a mod's romfs half: the RomFS path -> the file in the mod folder. */
static NSDictionary<NSString *, NSString *> *mod_files(NSString *libraryFolder, NSString *name) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSString *root = [[libraryFolder stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"romfs"];
    NSDirectoryEnumerator *walk = [NSFileManager.defaultManager enumeratorAtPath:root];
    for (NSString *relative in walk) {
        NSString *full = [root stringByAppendingPathComponent:relative];
        NSString *type = [NSFileManager.defaultManager attributesOfItemAtPath:full error:nil][NSFileType];
        if ([type isEqualToString:NSFileTypeDirectory]) continue;
        out[relative] = full;
    }
    return out;
}

/* Rebuilds the overlay the game loads: the enabled mods' romfs files are copied in and the manifest is written.
   The library's mods are the folders under libraryFolder; on holds the names of the ones that are on. */
BOOL mod_manager_write_manifest(NSString *versionFolder, NSString *libraryFolder, NSString *version,
                                 NSSet<NSString *> *on, NSString **why) {
    NSString *appRoot = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"totk"];
    return mod_manager_write_manifest_in(appRoot, versionFolder, libraryFolder, version, on, why);
}
BOOL mod_manager_write_manifest_in(NSString *appRoot, NSString *versionFolder, NSString *libraryFolder, NSString *version,
                                    NSSet<NSString *> *on, NSString **why) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableDictionary<NSString *, NSString *> *wanted = [NSMutableDictionary dictionary];   // RomFS path -> the file to copy
    for (NSString *name in [fm contentsOfDirectoryAtPath:libraryFolder error:nil]) {
        if (![on containsObject:name]) continue;
        NSDictionary *files = mod_files(libraryFolder, name);
        for (NSString *path in files) if (!wanted[path]) wanted[path] = files[path];
    }
    NSSet *replaced = app_replaced_paths(appRoot, version);
    NSMutableSet *skipped = [NSMutableSet set];
    for (NSString *path in [wanted.allKeys copy]) if ([replaced containsObject:path]) {
        [skipped addObject:path]; [wanted removeObjectForKey:path];
    }
    NSString *image = [appRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"extracted/%@/romfs/romfs.bin", version]];
    NSDictionary *entries = romfs_entries(appRoot, version, [NSSet setWithArray:wanted.allKeys]);
    /* The files the old overlay held and that no enabled mod holds any more are removed. */
    NSString *manifestPath = [versionFolder stringByAppendingPathComponent:@"manifest.tsv"];
    NSString *oldText = [NSString stringWithContentsOfFile:manifestPath encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [oldText componentsSeparatedByString:@"\n"]) {
        if (!line.length || [line hasPrefix:@"#"]) continue;
        NSRange tab = [line rangeOfString:@"\t"];
        NSString *path = tab.location == NSNotFound ? line : [line substringToIndex:tab.location];
        if (!wanted[path]) [fm removeItemAtPath:[versionFolder stringByAppendingPathComponent:path] error:nil];
    }
    int copied = 0, added = 0;
    for (NSString *path in wanted) {
        NSString *target = [versionFolder stringByAppendingPathComponent:path];
        [fm createDirectoryAtPath:[target stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [fm removeItemAtPath:target error:nil];
        if (![fm copyItemAtPath:wanted[path] toPath:target error:nil]) {
            *why = [NSString stringWithFormat:UI("复制 %@ 失败。", "Could not copy %@."), path];
            return NO;
        }
        copied++;
        NSNumber *size = [fm attributesOfItemAtPath:target error:nil][NSFileSize];
        NSString *sha = sha256_file(target);
        NSArray *entry = entries[path];
        NSString *original = @"-";
        if (entry) {
            original = sha256_range(image, ((NSNumber *)entry[0]).unsignedLongLongValue, ((NSNumber *)entry[1]).unsignedLongLongValue) ?: @"-";
            if ([original isEqualToString:@"-"]) {
                *why = [NSString stringWithFormat:UI("读不到 %@ 的原文件哈希。", "Could not read the original's hash for %@."), path];
                return NO;
            }
        } else added++;
        [lines addObject:[NSString stringWithFormat:@"%@\t%@\t%@\t%@", path, size ?: @0, sha ?: @"-", original]];
    }
    NSMutableString *manifest = [NSMutableString stringWithString:@"# path\tsize\tsha256\toriginal_sha256 (written by the mod manager)\n"];
    for (NSString *line in lines) [manifest appendFormat:@"%@\n", line];
    [fm createDirectoryAtPath:versionFolder withIntermediateDirectories:YES attributes:nil error:nil];
    if (![manifest writeToFile:manifestPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        *why = UI("写不了清单文件。", "Could not write the manifest.");
        return NO;
    }
    NSMutableString *note = [NSMutableString string];
    [note appendFormat:UI("%d 个模组开启，%d 个文件（其中 %d 个是游戏里没有的新文件）。", "%d mods on, %d files (%d of them new to the game)."),
                  (int)on.count, copied, added];
    if (skipped.count) [note appendFormat:UI(" %d 个文件由 App 自己替换，没有采用。", " %d files are replaced by the app itself and were left out."), (int)skipped.count];
    *why = note;
    return YES;
}

/* ---- the window ---- */

@interface ModManager : NSObject <NSWindowDelegate>
@property NSWindow *window;
@property NSMutableArray<NSString *> *mods;
@property NSMutableSet<NSString *> *on;             // the mods that are on
@property NSMutableDictionary<NSString *, NSButton *> *checks;
@property NSTextField *note;
@property NSString *versionFolder, *libraryFolder, *version;
@end

@implementation ModManager

/* The mods in the library: a folder with a romfs/ or an exefs/ half. */
- (void)readLibrary {
    self.mods = [NSMutableArray array]; self.on = [NSMutableSet set]; self.checks = [NSMutableDictionary dictionary];
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *name in [fm contentsOfDirectoryAtPath:self.libraryFolder error:nil]) {
        NSString *folder = [self.libraryFolder stringByAppendingPathComponent:name];
        NSString *type = [fm attributesOfItemAtPath:folder error:nil][NSFileType];
        if (![type isEqualToString:NSFileTypeDirectory]) continue;
        [self.mods addObject:name];
        [self.on addObject:name];      // a newly installed mod is on
    }
    [self.mods sortUsingSelector:@selector(localizedStandardCompare:)];
}

- (NSString *)summary:(NSString *)name {
    NSUInteger files = mod_files(self.libraryFolder, name).count;
    NSString *exefs = [[self.libraryFolder stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"exefs"];
    BOOL hasCode = [NSFileManager.defaultManager fileExistsAtPath:exefs];
    if (hasCode && files) return [NSString stringWithFormat:UI("%lu 个数据文件，另有代码补丁（需要重新构建）", "%lu data files, and code patches (a build is needed)"), (unsigned long)files];
    if (hasCode) return UI("只有代码补丁（需要重新构建）", "Code patches only (a build is needed)");
    return [NSString stringWithFormat:UI("%lu 个数据文件", "%lu data files"), (unsigned long)files];
}

- (void)build {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *name in self.mods) {
        NSButton *check = [NSButton checkboxWithTitle:name target:self action:@selector(toggled:)];
        check.identifier = name; check.state = [self.on containsObject:name] ? NSControlStateValueOn : NSControlStateValueOff;
        self.checks[name] = check;
        NSTextField *summary = [NSTextField labelWithString:[self summary:name]];
        summary.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize]; summary.textColor = NSColor.secondaryLabelColor;
        NSStackView *row = [NSStackView stackViewWithViews:@[check, summary]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal; row.spacing = 10; row.alignment = NSLayoutAttributeCenterY;
        [rows addObject:row];
    }
    if (!rows.count) {
        NSTextField *empty = [NSTextField labelWithString:UI("还没有安装模组。点“安装模组”选一个模组文件夹（它的 romfs/ 是数据，exefs/ 是代码补丁）。",
                                                           "No mods yet. \"Install a mod\" takes a mod folder (its romfs/ is data, its exefs/ are code patches).")];
        empty.textColor = NSColor.secondaryLabelColor; [rows addObject:empty];
    }
    NSStackView *list = [NSStackView stackViewWithViews:rows];
    list.orientation = NSUserInterfaceLayoutOrientationVertical; list.alignment = NSLayoutAttributeLeading; list.spacing = 8;
    NSButton *install = [NSButton buttonWithTitle:UI("安装模组…", "Install a mod…") target:self action:@selector(install:)];
    NSButton *remove = [NSButton buttonWithTitle:UI("删除选中的模组", "Remove the selected mod") target:self action:@selector(remove:)];
    NSButton *close = [NSButton buttonWithTitle:UI("完成", "Done") target:self action:@selector(close:)];
    close.keyEquivalent = @"\r";
    NSStackView *buttons = [NSStackView stackViewWithViews:@[install, remove, close]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal; buttons.spacing = 10;
    self.note = [NSTextField wrappingLabelWithString:@""];
    self.note.textColor = NSColor.secondaryLabelColor; self.note.preferredMaxLayoutWidth = 560;
    NSStackView *stack = [NSStackView stackViewWithViews:@[list, self.note, buttons]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.alignment = NSLayoutAttributeLeading; stack.spacing = 14;
    stack.edgeInsets = NSEdgeInsetsMake(18, 20, 18, 20);
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 340) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = [NSString stringWithFormat:@"%@ — %@", @GAME_NAME, UI("模组", "Mods")];
    self.window.contentView = stack; self.window.delegate = self; self.window.releasedWhenClosed = NO;
}

- (void)refresh {
    NSString *why = nil;
    if (!mod_manager_write_manifest(self.versionFolder, self.libraryFolder, self.version, self.on, &why))
        self.note.stringValue = why ?: UI("重建失败。", "The rebuild failed.");
    else self.note.stringValue = why;
}

- (void)toggled:(NSButton *)check {
    if (check.state == NSControlStateValueOn) [self.on addObject:check.identifier];
    else [self.on removeObject:check.identifier];
    [self refresh];
}

- (void)install:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES; panel.canChooseFiles = NO; panel.allowsMultipleSelection = NO;
    panel.message = UI("选一个模组文件夹（里面有 romfs/ 或 exefs/）。", "Choose a mod folder (it holds romfs/ or exefs/).");
    if ([panel runModal] != NSModalResponseOK || !panel.URL) return;
    NSString *source = panel.URL.path, *name = panel.URL.lastPathComponent;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *target = [self.libraryFolder stringByAppendingPathComponent:name];
    if ([fm fileExistsAtPath:target]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = UI("已经有同名的模组了。", "A mod with that name is already there.");
        alert.informativeText = [NSString stringWithFormat:UI("%@ 已经存在；要替换它吗？", "%@ is already there; replace it?"), name];
        [alert addButtonWithTitle:UI("替换", "Replace")]; [alert addButtonWithTitle:UI("取消", "Cancel")];
        if ([alert runModal] != NSAlertFirstButtonReturn) return;
        [fm removeItemAtPath:target error:nil];
    }
    [fm createDirectoryAtPath:self.libraryFolder withIntermediateDirectories:YES attributes:nil error:nil];
    if (![fm copyItemAtPath:source toPath:target error:nil]) {
        self.note.stringValue = [NSString stringWithFormat:UI("复制 %@ 失败。", "Could not copy %@."), name];
        return;
    }
    [self readLibrary]; [self build]; [self refresh];
}

- (void)remove:(id)sender {
    (void)sender;
    NSString *name = nil;
    for (NSString *candidate in self.mods) if (self.checks[candidate].state == NSControlStateValueOn) name = candidate;
    if (!name) { self.note.stringValue = UI("先勾选要删除的模组。", "Tick the mod to remove first."); return; }
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:UI("删除模组 %@？", "Remove the mod %@?"), name];
    alert.informativeText = UI("它会从模组库里删掉；游戏加载的版本文件夹会随之重建。", "It is deleted from the library; the folder the game loads is rebuilt.");
    [alert addButtonWithTitle:UI("删除", "Remove")]; [alert addButtonWithTitle:UI("取消", "Cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    [NSFileManager.defaultManager removeItemAtPath:[self.libraryFolder stringByAppendingPathComponent:name] error:nil];
    [self readLibrary]; [self build]; [self refresh];
}

- (void)close:(id)sender {
    (void)sender;
    [self.window close];
}

@end

void mod_manager_show(NSString *versionFolder, NSString *libraryFolder, NSString *version) {
    ModManager *manager = [ModManager new];
    manager.versionFolder = versionFolder; manager.libraryFolder = libraryFolder; manager.version = version;
    [manager readLibrary]; [manager build]; [manager refresh];
    [manager.window center]; [manager.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
