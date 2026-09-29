#!/usr/bin/env python3
import plistlib
import os
import glob
import sys

# Trova l'ultimo archivio creato
archives_dir = os.path.expanduser('~/Library/Developer/Xcode/Archives')
archives = glob.glob(f"{archives_dir}/*/*.xcarchive")

if not archives:
    print("❌ Nessun archivio trovato.")
    sys.exit(1)

latest_archive = max(archives, key=os.path.getmtime)
print(f"📦 Archivio selezionato: {latest_archive}")

# Valore di build stabile (macOS release stabile, es. 25F71 o simile)
STABLE_BUILD = "25F71"
patched_count = 0

for root, dirs, files in os.walk(latest_archive):
    for f in files:
        if f == "Info.plist":
            p = os.path.join(root, f)
            try:
                with open(p, 'rb') as fp:
                    pl = plistlib.load(fp)
                
                changed = False
                if pl.get("BuildMachineOSBuild") != STABLE_BUILD:
                    old_val = pl.get("BuildMachineOSBuild")
                    pl["BuildMachineOSBuild"] = STABLE_BUILD
                    changed = True
                
                if changed:
                    with open(p, 'wb') as fp:
                        plistlib.dump(pl, fp)
                    patched_count += 1
                    print(f"  ✓ Modificato: {os.path.basename(os.path.dirname(p))}/{f} ({old_val} -> {STABLE_BUILD})")
            except Exception as e:
                print(f"  ⚠️ Errore su {p}: {e}")

print(f"\n🎉 Completato! Modificati {patched_count} file Info.plist con BuildMachineOSBuild = {STABLE_BUILD}.")
print("Ora puoi andare in Xcode Organizer e fare 'Distribute App' -> 'Upload'.")
