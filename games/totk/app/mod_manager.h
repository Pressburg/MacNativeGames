/* The player's RomFS mods: the manager window (app/mod_manager.m).

   The game loads one overlay: the version folder (~/Library/Application Support/MacNativeGames/TOTK/mods/<version>),
   whose manifest.tsv names each file it replaces or adds. The manager keeps a library of installed mods next to it
   (…/mods-library/<version>/<mod name>/, each in the layout --mod takes: exefs/ for code, romfs/ for data) and
   rebuilds the overlay from the mods that are on: their romfs/ files are copied in and the manifest is written
   against the app's own RomFS (scripts/make_mod_manifest.py does the same at build time).

   A mod's code half (exefs/) cannot be applied while the game runs: the code modules are rewritten for Apple silicon
   at build time and bound by hash, so a code patch needs a build with --mod. The manager says so instead of pretending.
   The app bundle stays read-only: everything is written under ~/Library/Application Support. */
#pragma once
#import <Cocoa/Cocoa.h>

/* Rebuilds the overlay the game loads from the mods that are on: the RomFS path -> the file, and the app's version
   (v0, v112, v121, v143) to find the app's own RomFS. Returns NO and says why in *why when the overlay could not be
   written. The files of a mod are its romfs/ half, under their RomFS paths. */
BOOL mod_manager_write_manifest(NSString *versionFolder, NSString *libraryFolder, NSString *version,
                                 NSSet<NSString *> *on, NSString **why);

/* The same, with the app's game folder (the one that holds extracted/<version>/romfs) given: the probe uses a
   fake one, the window the app's own. */
BOOL mod_manager_write_manifest_in(NSString *appRoot, NSString *versionFolder, NSString *libraryFolder, NSString *version,
                                    NSSet<NSString *> *on, NSString **why);

/* Opens the manager. versionFolder: the folder the game loads (the overlay). libraryFolder: the installed mods. */
void mod_manager_show(NSString *versionFolder, NSString *libraryFolder, NSString *version);
