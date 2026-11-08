// FastLzma2Encoder.h -- 7-ZSTar: new file (M6a)
//
// Ported from mcmilk/7-Zip-zstd, where this class (CFastEncoder) lives
// directly inside the official Lzma2Encoder.h/.cpp (their own fork adds it
// there). This project keeps it in its own new file instead, to honor the
// "minimize official-file diffs" constraint -- see
// CPP/7zip/Compress/Lzma2Encoder.cpp's own untouched state (diff against
// upstream 26.05 is zero) and FastLzma2Register.cpp's header comment for
// how CFastEncoder still reaches NCompress::NLzma2::SetLzma2Prop (a
// non-static, externally-linked helper already defined in the official,
// unmodified Lzma2Encoder.cpp) via a forward declaration instead.
//
// Fast LZMA2 (C/fast-lzma2/, UPSTREAM.txt) is a multi-threaded LZMA2
// encoder using a radix-based match finder instead of the official
// single-threaded LzFind -- it produces a bitstream indistinguishable from
// (and decodable by) the official NCompress::NLzma2::CDecoder; only the
// *encoder* differs. See FastLzma2Register.cpp for how it registers as an
// alternative encoder under the official LZMA2 coder id (0x21) rather than
// a coder/format id of its own.

#ifndef ZIP7_INC_FAST_LZMA2_ENCODER_H
#define ZIP7_INC_FAST_LZMA2_ENCODER_H

#include "../../../C/fast-lzma2/fast-lzma2.h"

#include "../../Common/MyCom.h"

#include "../ICoder.h"

namespace NCompress {
namespace NLzma2 {

class CFastEncoder Z7_final:
  public ICompressCoder,
  public ICompressSetCoderProperties,
  public ICompressWriteCoderProperties,
  public CMyUnknownImp
{
  Z7_COM_UNKNOWN_IMP_3(
      ICompressCoder,
      ICompressSetCoderProperties,
      ICompressWriteCoderProperties)

  Z7_IFACE_COM7_IMP(ICompressCoder)
  Z7_IFACE_COM7_IMP(ICompressSetCoderProperties)
  Z7_IFACE_COM7_IMP(ICompressWriteCoderProperties)

public:
  class FastLzma2
  {
  public:
    FastLzma2();
    ~FastLzma2();
    HRESULT SetCoderProperties(const PROPID *propIDs, const PROPVARIANT *props, UInt32 numProps);
    size_t GetDictSize() const;
    HRESULT Begin();
    BYTE* GetAvailableBuffer(unsigned long& size);
    HRESULT AddByteCount(size_t count, ISequentialOutStream *outStream, ICompressProgressInfo *progress);
    HRESULT End(ISequentialOutStream *outStream, ICompressProgressInfo *progress);
    void Cancel();

  private:
    bool UpdateProgress(ICompressProgressInfo *progress);
    HRESULT WaitAndReport(size_t& res, ICompressProgressInfo *progress);
    HRESULT WriteBuffers(ISequentialOutStream *outStream);

    FL2_CStream* fcs;
    FL2_dictBuffer dict;
    size_t dict_pos;

    FastLzma2(const FastLzma2&) = delete;
    FastLzma2& operator=(const FastLzma2&) = delete;
  };

  FastLzma2 _encoder;
};

}}

#endif
