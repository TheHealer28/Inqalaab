#!/usr/bin/env python3

import pathlib
import shutil
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
LIB_DIRS = [
    ROOT / "apps/ios/Libraries/ios",
    ROOT / "apps/ios/Libraries/sim",
]

REPLACEMENTS = [
    (
        b"smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp1.inqalaab.chat",
        b"smp://jKkKmm64Gf6jWa2unI5t0QudCoTZxxFp8o28fDZWZU4=@smp1.inqalaab.chat",
    ),
    (
        b"smp://C31ddjLb0YEyO4Wog4l4FSt9hey51GqftqIuTm7_FsY=@smp2.inqalaab.chat",
        b"smp://JfdjUvMRakyzH7yzucTLoxKsY-EfvA0bMTj7kZG3Szs=@smp2.inqalaab.chat",
    ),
]


def patch_archive(path: pathlib.Path) -> int:
    data = path.read_bytes()
    original = data

    for old, new in REPLACEMENTS:
        if len(old) != len(new):
            raise ValueError(f"Length mismatch for {old!r} -> {new!r}")
        data = data.replace(old, new)

    if data == original:
        return 0

    backup = path.with_name(path.name + ".bak-smpalign")
    if not backup.exists():
        shutil.copy2(path, backup)

    path.chmod(path.stat().st_mode | 0o200)
    path.write_bytes(data)
    path.chmod(path.stat().st_mode & ~0o222)
    return 1


def main() -> int:
    patched = 0
    for lib_dir in LIB_DIRS:
        for archive in sorted(lib_dir.glob("libHS*.a")):
            patched += patch_archive(archive)
    print(f"Patched {patched} staged Haskell archives")
    return 0


if __name__ == "__main__":
    sys.exit(main())
