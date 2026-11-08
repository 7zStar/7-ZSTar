// Toolbar7zstar.h -- 7-ZSTar: new file
// Own toolbar art. Square bitmaps in five sizes let a button follow the system DPI
// without scaling at run time, which would blur them and, with the key-colour mask
// ImageList uses, fringe their edges. Include after resource.h. The resource IDs
// in 7zstar/toolbar.rc must match these constants.

#ifndef ZIP7_INC_TOOLBAR_7ZSTAR_H
#define ZIP7_INC_TOOLBAR_7ZSTAR_H

// Renumbered buttons would show each other's art. A new button is not visible
// from here: build/Test-Smoke.ps1 checks resource.h for that.
#if IDB_EXTRACT != IDB_ADD + 1 || IDB_TEST != IDB_ADD + 2 || IDB_COPY != IDB_ADD + 3 \
    || IDB_MOVE != IDB_ADD + 4 || IDB_DELETE != IDB_ADD + 5 || IDB_INFO != IDB_ADD + 6
#error toolbar art is indexed from IDB_ADD: see MAINTAINING.md, Part 1, category D
#endif

static const unsigned kToolbarArt_FirstId = 1000;
static const unsigned kToolbarArt_Sizes[] = { 24, 36, 48, 72, 96 };
static const unsigned kToolbarArt_NumSizes = Z7_ARRAY_SIZE(kToolbarArt_Sizes);

// The largest size that fits a button at the system DPI: a small button is
// 24 and a large one 48 at 100%, and the art is never scaled up.
static unsigned ToolbarArt_SizeIndex(bool large)
{
  int dpi = 96;
  const HDC dc = ::GetDC(NULL);
  if (dc)
  {
    dpi = ::GetDeviceCaps(dc, LOGPIXELSY);
    ::ReleaseDC(NULL, dc);
  }
  const unsigned want = (large ? 48u : 24u) * (unsigned)dpi / 96;
  unsigned index = 0;
  for (unsigned i = 1; i < kToolbarArt_NumSizes; i++)
    if (kToolbarArt_Sizes[i] <= want)
      index = i;
  return index;
}

static unsigned ToolbarArt_Size(bool large)
{
  return kToolbarArt_Sizes[ToolbarArt_SizeIndex(large)];
}

// bitmapResID is the button's large bitmap ID: IDB_ADD to IDB_INFO.
static HBITMAP ToolbarArt_Load(HINSTANCE instance, UINT bitmapResID, bool large)
{
  const unsigned id = kToolbarArt_FirstId
      + (bitmapResID - IDB_ADD) * kToolbarArt_NumSizes
      + ToolbarArt_SizeIndex(large);
  return ::LoadBitmap(instance, MAKEINTRESOURCE(id));
}

#endif
