OBJS = \
  $O\StdAfx.obj \
  $(CURRENT_OBJS) \
  $(COMMON_OBJS) \
  $(WIN_OBJS) \
  $(WIN_CTRL_OBJS) \
  $(7ZIP_COMMON_OBJS) \
  $(UI_COMMON_OBJS) \
  $(AGENT_OBJS) \
  $(CONSOLE_OBJS) \
  $(EXPLORER_OBJS) \
  $(FM_OBJS) \
  $(GUI_OBJS) \
  $(AR_COMMON_OBJS) \
  $(AR_OBJS) \
  $(7Z_OBJS) \
  $(CAB_OBJS) \
  $(CHM_OBJS) \
  $(COM_OBJS) \
  $(ISO_OBJS) \
  $(NSIS_OBJS) \
  $(RAR_OBJS) \
  $(TAR_OBJS) \
  $(TARCHAIN_OBJS) \
  $(UDF_OBJS) \
  $(WIM_OBJS) \
  $(ZIP_OBJS) \
  $(COMPRESS_OBJS) \
  $(CRYPTO_OBJS) \
  $(C_OBJS) \
  $(ASM_OBJS) \
  $O\resource.res \

!include "../../../Build.mak"

# MAK_SINGLE_FILE = 1

!IFDEF MAK_SINGLE_FILE

!IFDEF CURRENT_OBJS
$(CURRENT_OBJS): ./$(*B).cpp
	$(COMPL)
!ENDIF


!IFDEF COMMON_OBJS
$(COMMON_OBJS): ../../../Common/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF WIN_OBJS
$(WIN_OBJS): ../../../Windows/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF WIN_CTRL_OBJS
$(WIN_CTRL_OBJS): ../../../Windows/Control/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF 7ZIP_COMMON_OBJS
$(7ZIP_COMMON_OBJS): ../../Common/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF AR_OBJS
$(AR_OBJS): ../../Archive/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF AR_COMMON_OBJS
$(AR_COMMON_OBJS): ../../Archive/Common/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF 7Z_OBJS
$(7Z_OBJS): ../../Archive/7z/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF CAB_OBJS
$(CAB_OBJS): ../../Archive/Cab/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF CHM_OBJS
$(CHM_OBJS): ../../Archive/Chm/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF COM_OBJS
$(COM_OBJS): ../../Archive/Com/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF ISO_OBJS
$(ISO_OBJS): ../../Archive/Iso/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF NSIS_OBJS
$(NSIS_OBJS): ../../Archive/Nsis/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF RAR_OBJS
$(RAR_OBJS): ../../Archive/Rar/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF TAR_OBJS
$(TAR_OBJS): ../../Archive/Tar/$(*B).cpp
	$(COMPL)
!ENDIF

# 7-ZSTar: M4 -- TarChain (tar.zst composite out-handler)
!IFDEF TARCHAIN_OBJS
$(TARCHAIN_OBJS): ../../Archive/TarChain/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF UDF_OBJS
$(UDF_OBJS): ../../Archive/Udf/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF WIM_OBJS
$(WIM_OBJS): ../../Archive/Wim/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF ZIP_OBJS
$(ZIP_OBJS): ../../Archive/Zip/$(*B).cpp
	$(COMPL) $(ZIP_FLAGS)
!ENDIF

!IFDEF COMPRESS_OBJS
$(COMPRESS_OBJS): ../../Compress/$(*B).cpp
	$(COMPL_O2)
!ENDIF

!IFDEF CRYPTO_OBJS
$(CRYPTO_OBJS): ../../Crypto/$(*B).cpp
	$(COMPL_O2)
!ENDIF

!IFDEF UI_COMMON_OBJS
$(UI_COMMON_OBJS): ../../UI/Common/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF AGENT_OBJS
$(AGENT_OBJS): ../../UI/Agent/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF CONSOLE_OBJS
$(CONSOLE_OBJS): ../../UI/Console/$(*B).cpp
	$(COMPL) $(CONSOLE_VARIANT_FLAGS)
!ENDIF

!IFDEF EXPLORER_OBJS
$(EXPLORER_OBJS): ../../UI/Explorer/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF FM_OBJS
$(FM_OBJS): ../../UI/FileManager/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF GUI_OBJS
$(GUI_OBJS): ../../UI/GUI/$(*B).cpp
	$(COMPL)
!ENDIF

!IFDEF C_OBJS
$(C_OBJS): ../../../../C/$(*B).c
	$(COMPL_O2)
!ENDIF


!ELSE

{.}.cpp{$O}.obj::
	$(COMPLB)
{../../../Common}.cpp{$O}.obj::
	$(COMPLB)
{../../../Windows}.cpp{$O}.obj::
	$(COMPLB)
{../../../Windows/Control}.cpp{$O}.obj::
	$(COMPLB)
{../../Common}.cpp{$O}.obj::
	$(COMPLB)

{../../UI/Common}.cpp{$O}.obj::
	$(COMPLB)
{../../UI/Agent}.cpp{$O}.obj::
	$(COMPLB)
{../../UI/Console}.cpp{$O}.obj::
	$(COMPLB) $(CONSOLE_VARIANT_FLAGS)
{../../UI/Explorer}.cpp{$O}.obj::
	$(COMPLB)
{../../UI/FileManager}.cpp{$O}.obj::
	$(COMPLB)
{../../UI/GUI}.cpp{$O}.obj::
	$(COMPLB)


{../../Archive}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Common}.cpp{$O}.obj::
	$(COMPLB)

{../../Archive/7z}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Cab}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Chm}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Com}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Iso}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Nsis}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Rar}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Tar}.cpp{$O}.obj::
	$(COMPLB)
# 7-ZSTar: M4 -- TarChain (tar.zst composite out-handler)
{../../Archive/TarChain}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Udf}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Wim}.cpp{$O}.obj::
	$(COMPLB)
{../../Archive/Zip}.cpp{$O}.obj::
	$(COMPLB) $(ZIP_FLAGS)

{../../Compress}.cpp{$O}.obj::
	$(COMPLB_O2)
{../../Crypto}.cpp{$O}.obj::
	$(COMPLB_O2)
{../../../../C}.c{$O}.obj::
	$(CCOMPLB)
# 7-ZSTar: vendored libzstd (compression side; C/zstd/UPSTREAM.txt) lives one
# level below C/ -- only bundles that list C/zstd/*.obj names in their own
# C_OBJS (currently Format7zF/Arc.mak and Bundles/Alone/makefile) ever trigger
# this rule.
{../../../../C/zstd}.c{$O}.obj::
	$(CCOMPLB)
# 7-ZSTar: xxHash (C/hashes/), a transitive dependency of C/zstd/ (see
# C/hashes/UPSTREAM.txt) -- same "only triggered if actually referenced" note
# as the C/zstd rule above applies here too.
{../../../../C/hashes}.c{$O}.obj::
	$(CCOMPLB)
# 7-ZSTar: M6a -- vendored codec libraries (C/lz4, C/lz5, C/lizard, C/brotli,
# C/fast-lzma2, see each dir's UPSTREAM.txt) + mcmilk's MT wrapper (C/zstdmt/,
# used by lz4/lz5/lizard/brotli; zstd has its own built-in MT and doesn't use
# this). Same "only triggered if actually referenced" note as the C/zstd rule
# above applies here too. -I flags and fast-lzma2's -D flags match
# mcmilk/7-Zip-zstd's own 7zip.mak exactly: C/zstdmt/*-mt_*.c use bare
# #include "lz4frame.h" etc (no relative path), so the compile of that
# directory needs every producer codec's own dir on the include search path;
# fast-lzma2 needs NO_XXHASH (avoid pulling in its own optional xxhash
# dependency -- this project already has one via C/hashes/) and
# FL2_7ZIP_BUILD (upstream's own "embedded in 7-Zip" build switch).
{../../../../C/lz4}.c{$O}.obj::
	$(CCOMPLB)
{../../../../C/lz5}.c{$O}.obj::
	$(CCOMPLB)
{../../../../C/lizard}.c{$O}.obj::
	$(CCOMPLB)
{../../../../C/brotli}.c{$O}.obj::
	$(CCOMPLB)
# 7-ZSTar: M8 -- needed to build fast-lzma2 for arm64 under -Wall -WX.
#
# -wd4746 is the flag that actually unblocks the build. C4746 does not mean
# "these semantics are wrong": it marks every direct access to a volatile
# variable whose behaviour depends on the /volatile setting, and it fires
# under both iso and ms. ARM targets default to /volatile:iso (x86/x64 and
# ARM64EC default to ms), which is why this only ever appeared on arm64.
#
# -volatile:ms is defensive, NOT a fix for any located race. Worth stating
# plainly, because the obvious guess is wrong: fast-lzma2 does not
# synchronise through bare volatile reads. The whole library declares
# volatile exactly once - `typedef LONG volatile FL2_atomic` (C/fast-lzma2/
# atomic.h) - and only ever touches it through InterlockedIncrement/
# InterlockedAdd, whose barrier guarantees come from the intrinsics
# themselves and are unaffected by /volatile. Real cross-thread coordination
# goes through CRITICAL_SECTION plus condition variables (fl2_pool.c,
# fl2_threading.h), i.e. OS primitives, equally unaffected. So ms semantics
# here buy defence in depth rather than repair anything, and the cost is
# correspondingly small: one variable, already accessed atomically.
#
# Scoped to this inference rule, so no other translation unit is affected.
# No-op on x86/x64, where ms is already the default.
{../../../../C/fast-lzma2}.c{$O}.obj::
	$(CCOMPLB) -DNO_XXHASH -DFL2_7ZIP_BUILD -volatile:ms -wd4746
{../../../../C/zstdmt}.c{$O}.obj::
	$(CCOMPLB) \
	-I ../../../../C/brotli \
	-I ../../../../C/hashes \
	-I ../../../../C/lizard \
	-I ../../../../C/lz4 \
	-I ../../../../C/lz5 \
	-I ../../../../C/zstd

!ENDIF

!include "Asm.mak"
