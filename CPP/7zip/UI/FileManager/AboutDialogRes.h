#define IDD_ABOUT  2900

#define IDT_ABOUT_INFO  2901

#define IDI_LOGO             100
#define IDT_ABOUT_VERSION    101
#define IDT_ABOUT_DATE       102
// 7-ZSTar: a button's control id is also its language-string id
// (LangUtils.cpp LangSetDlgItems), so these two are Lang\*.txt strings 962
// and 963 and must not be renumbered. Both are unused upstream (upstream's
// IDB_ABOUT_HOMEPAGE was 110, which no language file has). The words come
// from Lang\donate.json via Lang\rebrand.py.
#define IDB_ABOUT_DONATE     962
#define IDB_ABOUT_HOMEPAGE   963
