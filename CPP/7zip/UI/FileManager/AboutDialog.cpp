// AboutDialog.cpp

#include "StdAfx.h"

#include "../../../../C/CpuArch.h"

#include "../../MyVersion.h"

#include "../Common/LoadCodecs.h"

#include "AboutDialog.h"
#include "PropertyNameRes.h"

#include "HelpUtils.h"
#include "LangUtils.h"

#ifdef Z7_LANG
static const UInt32 kLangIDs[] =
{
  IDT_ABOUT_INFO,
  // 7-ZSTar: the two buttons are translated by id (control id = language id)
  IDB_ABOUT_DONATE,
  IDB_ABOUT_HOMEPAGE
};
#endif

// 7-ZSTar: the official website (upstream base: https://www.7-zip.org/).
// The URL itself lives in C/7zVersion.h.
#define kHomePageURL TEXT(MY_WEBSITE_URL)
// 7-ZSTar: the Donate button opens the site's donate section, always the root
// page (not the /<language>/ one), which the site's own script routes.
#define kDonateURL TEXT(MY_WEBSITE_URL "/#donate")
#define kHelpTopic "start.htm"

#define LLL_(quote) L##quote
#define LLL(quote) LLL_(quote)

extern CCodecs *g_CodecsObj;

bool CAboutDialog::OnInit()
{
  #ifdef Z7_EXTERNAL_CODECS
  if (g_CodecsObj)
  {
    UString s;
    g_CodecsObj->GetCodecsErrorMessage(s);
    if (!s.IsEmpty())
      MessageBoxW(GetParent(), s, L"7-ZSTar", MB_ICONERROR);
  }
  #endif

  #ifdef Z7_LANG
  LangSetWindowText(*this, IDD_ABOUT);
  LangSetDlgItems(*this, kLangIDs, Z7_ARRAY_SIZE(kLangIDs));
  #endif
  SetItemText(IDT_ABOUT_VERSION, UString("7-ZSTar " MY_VERSION_CPU));
  SetItemText(IDT_ABOUT_DATE, LLL(MY_DATE));
  
  NormalizePosition();
  return CModalDialog::OnInit();
}

void CAboutDialog::OnHelp()
{
  ShowHelpWindow(kHelpTopic);
}

bool CAboutDialog::OnButtonClicked(unsigned buttonID, HWND buttonHWND)
{
  LPCTSTR url;
  switch (buttonID)
  {
    case IDB_ABOUT_HOMEPAGE: url = kHomePageURL; break;
    // 7-ZSTar:
    case IDB_ABOUT_DONATE: url = kDonateURL; break;
    default:
      return CModalDialog::OnButtonClicked(buttonID, buttonHWND);
  }

  #ifdef UNDER_CE
  SHELLEXECUTEINFO s;
  memset(&s, 0, sizeof(s));
  s.cbSize = sizeof(s);
  s.lpFile = url;
  ::ShellExecuteEx(&s);
  #else
  ::ShellExecute(NULL, NULL, url, NULL, NULL, SW_SHOWNORMAL);
  #endif

  return true;
}
