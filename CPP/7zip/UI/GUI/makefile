PROG = 7zG.exe
CFLAGS = $(CFLAGS) \
  -DZ7_LANG \
  -DZ7_EXTERNAL_CODECS \

# 7-ZSTar: M3 - CompressDialog.cpp (GUI_OBJS below) now calls the C-style
# ZstdEncProps_* functions directly (dictionary/order/thread/memory combo
# population -- see ZstdEncoderProps.h) instead of going through the
# Z7_EXTERNAL_CODECS dynamic-load path used for actual compression, so this
# target needs ZstdEncoderProps.obj (COMPRESS_OBJS) and enough of the vendored
# libzstd compression sources (C_OBJS/ZSTD_ENC_OBJS below) to satisfy it,
# even though it never links the full ZstdEncoder.obj coder itself (the real
# compression happens out-of-process in the dynamically-loaded 7z.dll, which
# already carries the full zstd encoder from M2). See the detailed comment in
# ../../Bundles/Format7zF/Arc.mak for what each -wd suppresses.
#
# 7-ZSTar: M8 -- -wd4668 added for x86. C/zstd/mem.h tests `#if _M_X64`, and
# that macro simply does not exist on a 32-bit target, so C4668 ("not defined
# as a preprocessor macro, replacing with 0") fires and -WX turns it into an
# error. It never appeared while only x64 was being built. This list stays
# shorter than Alone/Arc.mak's because this target compiles zstd only - none
# of the M6a libraries or fast-lzma2 are linked here.
CFLAGS = $(CFLAGS) -DZSTD_MULTITHREAD -wd4710 -wd4711 -wd4820 -wd4464 -wd4574 -wd5045 -wd4668

!IFDEF UNDER_CE
LIBS = $(LIBS) ceshell.lib Commctrl.lib
!ELSE
LIBS = $(LIBS) comctl32.lib htmlhelp.lib comdlg32.lib gdi32.lib
CFLAGS = $(CFLAGS) -DZ7_DEVICE_FILE
!ENDIF

GUI_OBJS = \
  $O\BenchmarkDialog.obj \
  $O\CompressDialog.obj \
  $O\ExtractDialog.obj \
  $O\ExtractGUI.obj \
  $O\GUI.obj \
  $O\HashGUI.obj \
  $O\UpdateCallbackGUI.obj \
  $O\UpdateCallbackGUI2.obj \
  $O\UpdateGUI.obj \

COMMON_OBJS = \
  $O\CommandLineParser.obj \
  $O\CRC.obj \
  $O\DynLimBuf.obj \
  $O\IntToString.obj \
  $O\Lang.obj \
  $O\ListFileUtils.obj \
  $O\MyString.obj \
  $O\MyVector.obj \
  $O\NewHandler.obj \
  $O\StringConvert.obj \
  $O\StringToInt.obj \
  $O\UTFConvert.obj \
  $O\Wildcard.obj \

WIN_OBJS = \
  $O\Clipboard.obj \
  $O\CommonDialog.obj \
  $O\DLL.obj \
  $O\ErrorMsg.obj \
  $O\FileDir.obj \
  $O\FileFind.obj \
  $O\FileIO.obj \
  $O\FileLink.obj \
  $O\FileName.obj \
  $O\FileSystem.obj \
  $O\MemoryGlobal.obj \
  $O\MemoryLock.obj \
  $O\PropVariant.obj \
  $O\PropVariantConv.obj \
  $O\Registry.obj \
  $O\ResourceString.obj \
  $O\Shell.obj \
  $O\Synchronization.obj \
  $O\System.obj \
  $O\SystemInfo.obj \
  $O\TimeUtils.obj \
  $O\Window.obj \

WIN_CTRL_OBJS = \
  $O\ComboBox.obj \
  $O\Dialog.obj \
  $O\ListView.obj \

7ZIP_COMMON_OBJS = \
  $O\CreateCoder.obj \
  $O\FilePathAutoRename.obj \
  $O\FileStreams.obj \
  $O\FilterCoder.obj \
  $O\LimitedStreams.obj \
  $O\MethodProps.obj \
  $O\MultiOutStream.obj \
  $O\ProgressUtils.obj \
  $O\PropId.obj \
  $O\StreamObjects.obj \
  $O\StreamUtils.obj \
  $O\UniqBlocks.obj \

UI_COMMON_OBJS = \
  $O\ArchiveCommandLine.obj \
  $O\ArchiveExtractCallback.obj \
  $O\ArchiveOpenCallback.obj \
  $O\Bench.obj \
  $O\DefaultName.obj \
  $O\EnumDirItems.obj \
  $O\Extract.obj \
  $O\ExtractingFilePath.obj \
  $O\HashCalc.obj \
  $O\LoadCodecs.obj \
  $O\OpenArchive.obj \
  $O\PropIDUtils.obj \
  $O\SetProperties.obj \
  $O\SortUtils.obj \
  $O\TempFiles.obj \
  $O\Update.obj \
  $O\UpdateAction.obj \
  $O\UpdateCallback.obj \
  $O\UpdatePair.obj \
  $O\UpdateProduce.obj \
  $O\WorkDir.obj \
  $O\ZipRegistry.obj \

AR_COMMON_OBJS = \
  $O\ItemNameUtils.obj \
  $O\OutStreamWithCRC.obj \

FM_OBJS = \
  $O\EditDialog.obj \
  $O\ExtractCallback.obj \
  $O\FormatUtils.obj \
  $O\HelpUtils.obj \
  $O\LangUtils.obj \
  $O\ListViewDialog.obj \
  $O\MemDialog.obj \
  $O\OpenCallback.obj \
  $O\ProgramLocation.obj \
  $O\PropertyName.obj \
  $O\RegistryUtils.obj \
  $O\SplitUtils.obj \
  $O\StringUtils.obj \
  $O\OverwriteDialog.obj \
  $O\PasswordDialog.obj \
  $O\ProgressDialog2.obj \

FM_OBJS = $(FM_OBJS) \
  $O\BrowseDialog.obj \
  $O\ComboDialog.obj \
  $O\SysIconUtils.obj \

EXPLORER_OBJS = \
  $O\MyMessages.obj \

COMPRESS_OBJS = \
  $O\CopyCoder.obj \
  $O\ZstdEncoderProps.obj \

C_OBJS = \
  $O\Alloc.obj \
  $O\CpuArch.obj \
  $O\DllSecur.obj \
  $O\Threads.obj \

# 7-ZSTar: M3 - vendored libzstd 1.5.7 (C/zstd/), compression side only,
# needed to satisfy ZstdEncoderProps.obj (see CFLAGS comment above). Same
# list as ../../Bundles/Alone/makefile / ../../Bundles/Format7zF/Arc.mak.
ZSTD_ENC_OBJS = \
  $O\debug.obj \
  $O\entropy_common.obj \
  $O\error_private.obj \
  $O\fse_compress.obj \
  $O\fse_decompress.obj \
  $O\hist.obj \
  $O\huf_compress.obj \
  $O\pool.obj \
  $O\threading.obj \
  $O\zstd_common.obj \
  $O\zstd_compress.obj \
  $O\zstd_compress_literals.obj \
  $O\zstd_compress_sequences.obj \
  $O\zstd_compress_superblock.obj \
  $O\zstd_double_fast.obj \
  $O\zstd_fast.obj \
  $O\zstd_lazy.obj \
  $O\zstd_ldm.obj \
  $O\zstd_opt.obj \
  $O\zstd_preSplit.obj \
  $O\zstdmt_compress.obj \
  $O\xxhash.obj \

C_OBJS = $(C_OBJS) $(ZSTD_ENC_OBJS)

!include "../../Crc.mak"
!include "../../Sort.mak"

!include "../../7zip.mak"
