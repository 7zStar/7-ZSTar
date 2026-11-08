// HelpUtils.cpp

#include "StdAfx.h"

#include "HelpUtils.h"

#if defined(UNDER_CE) || defined(__MINGW32_VERSION)

void ShowHelpWindow(LPCSTR)
{
}

#else

/* USE_EXTERNAL_HELP creates new help process window for each HtmlHelp() call.
   HtmlHelp() call uses one window. */

#if defined(__MINGW32_VERSION) /* || defined(Z7_OLD_WIN_SDK) */
#define USE_EXTERNAL_HELP
#endif

// #define USE_EXTERNAL_HELP

#ifdef USE_EXTERNAL_HELP

#include "../../../Windows/ProcessUtils.h"
#include "../../../Windows/FileDir.h"
#include "../../../Windows/FileName.h"

#else
#include <HtmlHelp.h>
#endif

#include "../../../Common/StringConvert.h"

#include "../../../Windows/DLL.h"
#include "../../../Windows/FileFind.h"

// 7-ZSTar: for MY_PROJECT_URL (see the fallback comment below)
#include "../../MyVersion.h"

#define kHelpFileName "7-zip.chm"
#define kHelpTopicPrefix "::/"

/* 7-ZSTar: the packages ship upstream's 7-zip.chm next to the executable
   (vendored - see Help\UPSTREAM.md; the HTML it is compiled from exists only
   inside upstream's binary releases, not in DOC\ or anywhere else in the
   source tree). It can still be missing: someone copies just the .exe out of
   the portable zip, or a future build drops it. Without the file, HtmlHelp()
   is handed a path that cannot resolve and the Help entries do nothing at all
   - measured, not assumed: no window, no hh.exe. So fall back to the online
   documentation. Every topic lands on the same page; the anchor names the
   "Documentation" section of the project README. */
#define kOnlineHelpURL TEXT(MY_PROJECT_URL "#documentation")

void ShowHelpWindow(LPCSTR topicFile)
{
  FString path = NWindows::NDLL::GetModuleDirPrefix();
  path += kHelpFileName;
  // 7-ZSTar: no help file next to the executable -> online documentation.
  if (!NWindows::NFile::NFind::DoesFileExist_FollowLink(path))
  {
    ::ShellExecute(NULL, NULL, kOnlineHelpURL, NULL, NULL, SW_SHOWNORMAL);
    return;
  }
  path += kHelpTopicPrefix;
  path += topicFile;
 #ifdef USE_EXTERNAL_HELP
  FString prog;

  #ifdef UNDER_CE
    prog = "\\Windows\\";
  #else
    if (!NWindows::NFile::NDir::GetWindowsDir(prog))
      return;
    NWindows::NFile::NName::NormalizeDirPathPrefix(prog);
  #endif
  prog += "hh.exe";

  UString params;
  params += '"';
  params += fs2us(path);
  params += '"';

  NWindows::CProcess process;
  const WRes wres = process.Create(fs2us(prog), params, NULL); // curDir);
  if (wres != 0)
  {
    /*
    HRESULT hres = HRESULT_FROM_WIN32(wres);
    ErrorMessageHRESULT(hres, imageName);
    return hres;
    */
  }
 #else
  // HWND hwnd = NULL;
  HtmlHelp(NULL, GetSystemString(fs2us(path)), HH_DISPLAY_TOPIC, 0);
 #endif
}

#endif
