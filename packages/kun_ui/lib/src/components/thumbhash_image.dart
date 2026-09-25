// Copyright (c) 2023 Evan Wallace
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Port of thumbHashToRGBA and thumbHashToApproximateAspectRatio from
// thumbhash@0.1.1 (thumbhash/thumbhash.js).

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width, height and unpremultiplied RGBA from a ThumbHash.
///
/// Not a supported public API; used by [KunThumbHashImage], [KunImage] and
/// tests.
@internal
typedef ThumbHashRgba = ({int width, int height, Uint8List rgba});

/// Decodes a base64 ThumbHash to width, height and RGBA bytes.
///
/// Returns null when [hash] is not valid base64, the payload is shorter than
/// the 5-byte header, or the header yields a zero dimension. Not a supported
/// public API.
@internal
ThumbHashRgba? tryDecodeThumbHash(String hash) {
  if (hash.isEmpty) {
    return null;
  }
  final Uint8List bytes;
  try {
    bytes = base64.decode(hash);
  } on FormatException {
    return null;
  }
  if (bytes.length < 5) {
    return null;
  }
  final ThumbHashRgba decoded = _thumbHashToRgba(bytes);
  if (decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }
  return decoded;
}

int _byte(Uint8List hash, int index) =>
    index >= 0 && index < hash.length ? hash[index] : 0;

double _thumbHashToApproximateAspectRatio(Uint8List hash) {
  final int header = _byte(hash, 3);
  final bool hasAlpha = (_byte(hash, 2) & 0x80) != 0;
  final bool isLandscape = (_byte(hash, 4) & 0x80) != 0;
  final int lx = isLandscape ? (hasAlpha ? 5 : 7) : header & 7;
  final int ly = isLandscape ? header & 7 : (hasAlpha ? 5 : 7);
  return ly == 0 ? 0 : lx / ly;
}

ThumbHashRgba _thumbHashToRgba(Uint8List hash) {
  final int header24 =
      _byte(hash, 0) | (_byte(hash, 1) << 8) | (_byte(hash, 2) << 16);
  final int header16 = _byte(hash, 3) | (_byte(hash, 4) << 8);
  final double lDc = (header24 & 63) / 63;
  final double pDc = ((header24 >> 6) & 63) / 31.5 - 1;
  final double qDc = ((header24 >> 12) & 63) / 31.5 - 1;
  final double lScale = ((header24 >> 18) & 31) / 31;
  final bool hasAlpha = (header24 >> 23) != 0;
  final double pScale = ((header16 >> 3) & 63) / 63;
  final double qScale = ((header16 >> 9) & 63) / 63;
  final bool isLandscape = (header16 >> 15) != 0;
  final int lx = math.max(3, isLandscape ? (hasAlpha ? 5 : 7) : header16 & 7);
  final int ly = math.max(3, isLandscape ? header16 & 7 : (hasAlpha ? 5 : 7));
  final double aDc = hasAlpha ? (_byte(hash, 5) & 15) / 15 : 1;
  final double aScale = (_byte(hash, 5) >> 4) / 15;

  final int acStart = hasAlpha ? 6 : 5;
  int acIndex = 0;

  List<double> decodeChannel(int nx, int ny, double scale) {
    final List<double> ac = <double>[];
    for (int cy = 0; cy < ny; cy++) {
      for (int cx = cy != 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
        final int packed = _byte(hash, acStart + (acIndex >> 1));
        ac.add((((packed >> ((acIndex & 1) << 2)) & 15) / 7.5 - 1) * scale);
        acIndex++;
      }
    }
    return ac;
  }

  final List<double> lAc = decodeChannel(lx, ly, lScale);
  final List<double> pAc = decodeChannel(3, 3, pScale * 1.25);
  final List<double> qAc = decodeChannel(3, 3, qScale * 1.25);
  final List<double> aAc =
      hasAlpha ? decodeChannel(5, 5, aScale) : const <double>[];

  final double ratio = _thumbHashToApproximateAspectRatio(hash);
  final int w = (ratio > 1 ? 32 : 32 * ratio).round();
  final int h = (ratio > 1 ? 32 / ratio : 32).round();
  if (w <= 0 || h <= 0) {
    return (width: w, height: h, rgba: Uint8List(0));
  }
  final Uint8List rgba = Uint8List(w * h * 4);
  final List<double> fx =
      List<double>.filled(math.max(lx, hasAlpha ? 5 : 3), 0);
  final List<double> fy =
      List<double>.filled(math.max(ly, hasAlpha ? 5 : 3), 0);

  for (int y = 0, i = 0; y < h; y++) {
    for (int x = 0; x < w; x++, i += 4) {
      double l = lDc;
      double p = pDc;
      double q = qDc;
      double a = aDc;

      final int fxN = math.max(lx, hasAlpha ? 5 : 3);
      for (int cx = 0; cx < fxN; cx++) {
        fx[cx] = math.cos(math.pi / w * (x + 0.5) * cx);
      }
      final int fyN = math.max(ly, hasAlpha ? 5 : 3);
      for (int cy = 0; cy < fyN; cy++) {
        fy[cy] = math.cos(math.pi / h * (y + 0.5) * cy);
      }

      for (int cy = 0, j = 0; cy < ly; cy++) {
        final double fy2 = fy[cy] * 2;
        for (int cx = cy != 0 ? 0 : 1; cx * ly < lx * (ly - cy); cx++, j++) {
          l += lAc[j] * fx[cx] * fy2;
        }
      }

      for (int cy = 0, j = 0; cy < 3; cy++) {
        final double fy2 = fy[cy] * 2;
        for (int cx = cy != 0 ? 0 : 1; cx < 3 - cy; cx++, j++) {
          final double f = fx[cx] * fy2;
          p += pAc[j] * f;
          q += qAc[j] * f;
        }
      }

      if (hasAlpha) {
        for (int cy = 0, j = 0; cy < 5; cy++) {
          final double fy2 = fy[cy] * 2;
          for (int cx = cy != 0 ? 0 : 1; cx < 5 - cy; cx++, j++) {
            a += aAc[j] * fx[cx] * fy2;
          }
        }
      }

      final double b = l - 2 / 3 * p;
      final double r = (3 * l - b + q) / 2;
      final double g = r - q;
      rgba[i] = _channelToUint8(r);
      rgba[i + 1] = _channelToUint8(g);
      rgba[i + 2] = _channelToUint8(b);
      rgba[i + 3] = _channelToUint8(a);
    }
  }
  return (width: w, height: h, rgba: rgba);
}

int _channelToUint8(double value) {
  final double clamped = math.max(0, 255 * math.min(1, value));
  return clamped.toInt();
}

/// The web `KunImage` blur-up placeholder, as an [ImageProvider] an app can
/// paint on its own — for example while a full image is held back.
///
/// [hash] is the base64 ThumbHash the web `thumbhash` prop takes. Pixels are
/// built from raw RGBA through [ui.ImageDescriptor.raw] (`rgba8888`), never
/// through a PNG: a consuming Android device could not decode the PNG some
/// third-party ThumbHash ports emit.
class KunThumbHashImage extends ImageProvider<KunThumbHashImage> {
  /// Creates a provider for a base64 ThumbHash.
  const KunThumbHashImage(this.hash);

  /// The base64 ThumbHash, the same string the web `thumbhash` prop takes.
  final String hash;

  @override
  Future<KunThumbHashImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<KunThumbHashImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    KunThumbHashImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load(key));
  }

  static Future<ImageInfo> _load(KunThumbHashImage key) async {
    final ThumbHashRgba? pixels = tryDecodeThumbHash(key.hash);
    if (pixels == null) {
      throw StateError('KunThumbHashImage: invalid hash');
    }
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(pixels.rgba);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: pixels.width,
      height: pixels.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    final ui.FrameInfo frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is KunThumbHashImage && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;
}
