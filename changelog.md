# TSupport-Advance ( TSP-A )

This is magisk module DO NOT FLASH FROM RECOVERY!

Merge version of TSupport and CITadvance. Might lose some feature from TSupport but its not a problem the main objective is working better than TSupport or CITadvance.

This module support for older and newer version of Magisk/KSU/APATCH. `Action button` only available for Magisk 27008+ so dont ask me why there is no `Action button`.

## Installation

Install from Magisk/KernelSU/Apatch Manager.

About PIF Generator configuration, you can hold your screen for a second and it will automatically set to default settings. Useful if your VOL+ and VOL- having issue. ( Its time to buy new phone! )

Auto add app to `target.txt` every 1 minutes. This can be disable, add/create new file `stop-tspa-auto-target` in Internal Storage ( `/sdcard` or `/storage` ). Condition triggered if Action button clicked or after boot.

By default it will be auto mode. You can add `customize.txt` to Internal Storage `/sdcard` or `/storage` to customize package name when added to `target.txt`, If you add package name with `!` at the end of the package name in `customize.txt` then that package name will be force to use Generated Certificate Support ( GCS ) and force use Leaf Hack Mode ( LHM ) if you add `?` at the end of the package name. You can also add only `!` without package name to force all package to use GCS by default. More info about `!` and `?` you can read from Tricky Store description. ( No link! find your own! )

spoofProvider - Set to False/No if youre using PlayIntegrityFix Fork

spoofSignature - Set to True/Yes if your ROM Sign is Testkey.

## Requirements

- Magisk/KernelSU/Apatch ( Recommended to use Magisk 27008+ )
- Tricky Store
- PlayIntegrityFix

## Acknowledgements

This repository incorporates code from the osm0sis project ([PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork)). I acknowledge that the original authors and contributors have created valuable work, and I encourage users to respect the licensing terms of the original project.

## License

```
Open Source License

Copyright © 2024 Citra-Standalone

This code is open for free use, modification, and redistribution under these terms:

Free to use, modify, or share for any purpose, whether commercial or non-commercial.
Credit original authors in any form of distribution or usage.
Retain this license in any modified or redistributed versions.
Provided “as is,” without any warranty. Authors are not liable for any misuse.

Using this code means you agree to these terms.
```

---

## Changelog ( R241104 )
- Customization ( `exclude.txt` now `customize.txt` )