# Third-party notices — libharu wrapper runtime DLLs

This directory's PDF runtime consists of three third-party DLLs. Versions
below were verified from the shipped binaries themselves (not assumed):
`hpdf.dll` self-reports 2.4.6 via `HPDF_GetVersion()` and embedded version
strings; `zlib.dll` / `libpng16.dll` via their embedded version strings and
`VersionInfo` resources.

| DLL | Component | Version | License | Upstream |
| --- | --------- | ------- | ------- | -------- |
| `hpdf.dll` | libharu | 2.4.6 | ZLIB license | <https://github.com/libharu/libharu> (releases: <https://github.com/libharu/libharu/releases>) |
| `zlib.dll` | zlib | 1.3.1 | zlib license | <https://zlib.net> |
| `libpng16.dll` | libpng | 1.6.50 | PNG Reference Library License version 2 | <http://www.libpng.org/pub/png/libpng.html> |

All three licenses permit use and redistribution in commercial software,
including in unmodified binary form, subject to the restrictions reproduced
below (keep this file with any distribution of the DLLs).

---

## 1. libharu 2.4.6 — `hpdf.dll`

ZLIB-style license, verbatim from
<https://raw.githubusercontent.com/libharu/libharu/master/LICENSE>:

```
Copyright (C) 1999-2006 Takeshi Kanno
Copyright (C) 2007-2009 Antony Dovgal

This software is provided 'as-is', without any express or implied warranty.

In no event will the authors be held liable for any damages arising from the
use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software in
    a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

 2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

 3. This notice may not be removed or altered from any source distribution.
```

---

## 2. zlib 1.3.1 — `zlib.dll`

zlib license (shipped DLL is 1.3.1, copyright years per its own embedded
notice: "deflate 1.3.1 Copyright 1995-2024 Jean-loup Gailly and Mark Adler").
Text per <https://zlib.net/zlib_license.html>:

```
Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software in
    a product, an acknowledgment in the product documentation would be
    appreciated but is not required.
 2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.
 3. This notice may not be removed or altered from any source distribution.

 Jean-loup Gailly        Mark Adler
 jloup@gzip.org          madler@alumni.caltech.edu
```

---

## 3. libpng 1.6.50 — `libpng16.dll`

The shipped 1.6.50 is governed by **PNG Reference Library License version 2**
(version 1 applies only to libpng 0.5 through 1.6.35). Verbatim from
<http://www.libpng.org/pub/png/src/libpng-LICENSE.txt>:

```
COPYRIGHT NOTICE, DISCLAIMER, and LICENSE

PNG Reference Library License version 2
---------------------------------------

 * Copyright (c) 1995-2026 The PNG Reference Library Authors.
 * Copyright (c) 2018-2026 Cosmin Truta.
 * Copyright (c) 2000-2002, 2004, 2006-2018 Glenn Randers-Pehrson.
 * Copyright (c) 1996-1997 Andreas Dilger.
 * Copyright (c) 1995-1996 Guy Eric Schalnat, Group 42, Inc.

The software is supplied "as is", without warranty of any kind,
express or implied, including, without limitation, the warranties
of merchantability, fitness for a particular purpose, title, and
non-infringement.  In no event shall the Copyright owners, or
anyone distributing the software, be liable for any damages or
other liability, whether in contract, tort or otherwise, arising
from, out of, or in connection with the software, or the use or
other dealings in the software, even if advised of the possibility
of such damage.

Permission is hereby granted to use, copy, modify, and distribute
this software, or portions hereof, for any purpose, without fee,
subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you
    must not claim that you wrote the original software.  If you
    use this software in a product, an acknowledgment in the product
    documentation would be appreciated, but is not required.

 2. Altered source versions must be plainly marked as such, and must
    not be misrepresented as being the original software.

 3. This Copyright notice may not be removed or altered from any
    source or altered source distribution.
```

For reference, the historical PNG Reference Library License version 1
(covering only libpng 0.5–1.6.35, none of it shipped here) is included in the
same upstream file: <http://www.libpng.org/pub/png/src/libpng-LICENSE.txt>.
