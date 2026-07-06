import 'dart:convert';
import 'dart:typed_data';

/// Big-endian cursor over ABR file bytes (Photoshop formats are BE).
class AbrByteReader {
  AbrByteReader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int offset = 0;

  int get length => _bytes.length;
  int get remaining => _bytes.length - offset;
  bool get isAtEnd => offset >= _bytes.length;

  int readUint8() {
    _require(1);
    return _data.getUint8(offset++);
  }

  int readInt16() {
    _require(2);
    final value = _data.getInt16(offset);
    offset += 2;
    return value;
  }

  int readUint16() {
    _require(2);
    final value = _data.getUint16(offset);
    offset += 2;
    return value;
  }

  int readInt32() {
    _require(4);
    final value = _data.getInt32(offset);
    offset += 4;
    return value;
  }

  double readFloat64() {
    _require(8);
    final value = _data.getFloat64(offset);
    offset += 8;
    return value;
  }

  Uint8List readBytes(int count) {
    _require(count);
    final view = Uint8List.sublistView(_bytes, offset, offset + count);
    offset += count;
    return view;
  }

  /// Fixed-length ASCII (chunk signatures, type tags).
  String readAscii(int count) => ascii.decode(readBytes(count));

  /// Pascal string: one length byte followed by that many characters.
  String readPascalString() {
    final length = readUint8();
    return latin1.decode(readBytes(length));
  }

  /// Photoshop descriptor key/classID: 4 bytes of length; zero means a
  /// four-character code, otherwise that many characters follow.
  String readKeyString() {
    final length = readInt32();
    return latin1.decode(readBytes(length == 0 ? 4 : length));
  }

  /// Photoshop unicode string: UTF-16BE code-unit count, then the units;
  /// a trailing NUL is stripped.
  String readUnicodeString() {
    final count = readInt32();
    final units = Uint16List(count);
    for (var index = 0; index < count; index += 1) {
      units[index] = readUint16();
    }
    var end = count;
    while (end > 0 && units[end - 1] == 0) {
      end -= 1;
    }
    return String.fromCharCodes(units, 0, end);
  }

  void skip(int count) {
    _require(count);
    offset += count;
  }

  void _require(int count) {
    if (offset + count > _bytes.length) {
      throw const FormatException('Unexpected end of ABR data.');
    }
  }
}
