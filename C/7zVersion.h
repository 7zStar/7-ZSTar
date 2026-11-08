#define MY_VER_MAJOR 26
#define MY_VER_MINOR 5
#define MY_VER_BUILD 1 /* 7-ZSTar: revision number on top of upstream 26.05 */
#define MY_VERSION_NUMBERS "26.05.1"
#define MY_VERSION MY_VERSION_NUMBERS

/* 7-ZSTar: product branding; upstream base stays visible in MY_VERSION_NUMBERS */
#define MY_PRODUCT_NAME "7-ZSTar"

/* 7-ZSTar: this header has no include guard and may be included twice in one
   translation unit. The build-date block at the end redefines MY_DATE, so the
   second pass would redefine it with another value (C4005, fatal under -WX).
   Clearing it here, away from upstream's own MY_DATE line, makes that harmless. */
#undef MY_DATE

/* 7-ZSTar: single source for the repository URL. Used by the online-help
   fallback and - via installer\Build-Package.ps1, which parses this file -
   by the MSI's Apps & features links. Change it here and they all follow.
   Consumers wrap it in TEXT(); that macro is two-level (winnt.h __TEXT), so a
   macro argument expands correctly. */
#define MY_PROJECT_URL "https://github.com/7zStar/7-ZSTar"

/* 7-ZSTar: the official website, opened by the About dialog's button. The
   online help stays on MY_PROJECT_URL: it links to a section of the README. */
#define MY_WEBSITE_URL "https://www.7zstar.com"

#ifdef MY_CPU_NAME
  #define MY_VERSION_CPU MY_VERSION " (" MY_CPU_NAME ")"
#else
  #define MY_VERSION_CPU MY_VERSION
#endif

#define MY_DATE "2026-10-21"
#undef MY_COPYRIGHT
#undef MY_VERSION_COPYRIGHT_DATE
#define MY_AUTHOR_NAME "Igor Pavlov"
#define MY_COPYRIGHT_PD "Igor Pavlov : Public domain"
/* 7-ZSTar: keep upstream author copyright (LGPL), add project contributors.
   The About dialog shows each holder on its own line. These stay three plain
   literals because rc.exe does not join adjacent strings: keep the years in step. */
#define MY_COPYRIGHT_UPSTREAM "Copyright (c) 1999-2026 Igor Pavlov"
#define MY_COPYRIGHT_FORK "Copyright (c) 2026 7-ZSTar contributors"
#define MY_COPYRIGHT_CR "Copyright (c) 1999-2026 Igor Pavlov; (c) 2026 7-ZSTar contributors"

#ifdef USE_COPYRIGHT_CR
  #define MY_COPYRIGHT MY_COPYRIGHT_CR
#else
  #define MY_COPYRIGHT MY_COPYRIGHT_PD
#endif

#define MY_COPYRIGHT_DATE MY_COPYRIGHT " : " MY_DATE
#define MY_VERSION_COPYRIGHT_DATE MY_VERSION_CPU " : " MY_COPYRIGHT " : " MY_DATE

/* 7-ZSTar: build\Build.ps1 writes 7zBuildDate.h with the build date; without
   that header the date above stands. rc.exe skips this block, and no resource
   uses the date. It is a header rather than a -D flag because the flag would
   differ from the one the precompiled header was built with, and -WX makes
   that warning fatal. It sits down here, not around MY_DATE, so that upstream's
   date line, which changes every release, still merges without a conflict.
   The macros above that use MY_DATE expand where they are used, so they follow.
   This block and the "#undef MY_DATE" near the top are a pair: keep both. */
#if defined(__has_include)
  #if __has_include("7zBuildDate.h")
    #undef MY_DATE
    #include "7zBuildDate.h"
  #endif
#endif
