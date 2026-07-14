/// Incremental .qap appender (R22-C): the container is ordinary ZIP with
/// every entry STORE'd (cel blobs carry their own deflate), which makes
/// appends trivial and spec-legal — new local entries write over the old
/// central directory's position, then a fresh central directory + EOCD
/// close the file. Standard readers (including our own
/// `parseQapArchiveBytes`) see only the LATEST central directory, so a
/// re-saved `project.json` or a superseded cel simply shadows its old
/// bytes (garbage until compaction rewrites the file whole).
///
/// Crash contract: the central-directory rewrite is the only destructive
/// step. `appendQapEntries` first reads the old central directory into
/// memory; a crash mid-append leaves a file without a valid EOCD tail —
/// the caller keeps compaction (full atomic rewrite) as the recovery and
/// the periodic durability point.
library;

import 'dart:io';
import 'dart:typed_data';

/// One parsed central-directory record we care about.
class QapZipEntry {
  QapZipEntry({
    required this.name,
    required this.localHeaderOffset,
    required this.dataOffset,
    required this.length,
    required this.crc32,
  });

  final String name;
  final int localHeaderOffset;

  /// Offset of the entry's RAW bytes (STORE'd, so bytes == the payload).
  final int dataOffset;
  final int length;
  final int crc32;
}

/// The parsed tail of a .qap: every ACTIVE entry (latest central
/// directory) plus the offset where the central directory begins — the
/// append position.
class QapZipLayout {
  QapZipLayout({required this.entries, required this.centralDirectoryOffset});

  final List<QapZipEntry> entries;
  final int centralDirectoryOffset;

  QapZipEntry? entryNamed(String name) {
    for (final entry in entries) {
      if (entry.name == name) {
        return entry;
      }
    }
    return null;
  }
}

const int _eocdSignature = 0x06054b50;
const int _centralSignature = 0x02014b50;
const int _localSignature = 0x04034b50;

/// Parses the central directory of [bytes] (a complete .qap). Throws
/// [FormatException] when no EOCD is found (torn append — the caller
/// falls back to recovery/compaction).
QapZipLayout parseQapZipLayout(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  // EOCD: scan back over a possible comment (max 64KB + 22).
  final scanFloor = bytes.length - 22 - 65535 < 0
      ? 0
      : bytes.length - 22 - 65535;
  var eocd = -1;
  for (var i = bytes.length - 22; i >= scanFloor; i -= 1) {
    if (data.getUint32(i, Endian.little) == _eocdSignature) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) {
    throw const FormatException('No ZIP end-of-central-directory found.');
  }
  final entryCount = data.getUint16(eocd + 10, Endian.little);
  final centralOffset = data.getUint32(eocd + 16, Endian.little);

  final entries = <QapZipEntry>[];
  var cursor = centralOffset;
  for (var i = 0; i < entryCount; i += 1) {
    if (data.getUint32(cursor, Endian.little) != _centralSignature) {
      throw const FormatException('Corrupt central directory.');
    }
    final crc = data.getUint32(cursor + 16, Endian.little);
    final compressedSize = data.getUint32(cursor + 20, Endian.little);
    final nameLength = data.getUint16(cursor + 28, Endian.little);
    final extraLength = data.getUint16(cursor + 30, Endian.little);
    final commentLength = data.getUint16(cursor + 32, Endian.little);
    final localOffset = data.getUint32(cursor + 42, Endian.little);
    final name = String.fromCharCodes(
      bytes.sublist(cursor + 46, cursor + 46 + nameLength),
    );
    // Local header: fixed 30 bytes + its own name/extra lengths.
    final localNameLength = data.getUint16(localOffset + 26, Endian.little);
    final localExtraLength = data.getUint16(localOffset + 28, Endian.little);
    entries.add(
      QapZipEntry(
        name: name,
        localHeaderOffset: localOffset,
        dataOffset: localOffset + 30 + localNameLength + localExtraLength,
        length: compressedSize,
        crc32: crc,
      ),
    );
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  return QapZipLayout(entries: entries, centralDirectoryOffset: centralOffset);
}

/// Parses the layout straight from the FILE with tail-only reads (EOCD
/// scan window + central directory + 4 bytes per local header) — a
/// multi-gigabyte project must never load whole just to append a few
/// cels or list its entries.
QapZipLayout parseQapZipLayoutFile(String path) {
  final raf = File(path).openSync();
  try {
    final fileLength = raf.lengthSync();
    if (fileLength < 22) {
      throw const FormatException('No ZIP end-of-central-directory found.');
    }
    final tailLength = fileLength < 22 + 65535 ? fileLength : 22 + 65535;
    raf.setPositionSync(fileLength - tailLength);
    final tail = raf.readSync(tailLength);
    final tailData = ByteData.sublistView(tail);
    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i -= 1) {
      if (tailData.getUint32(i, Endian.little) == _eocdSignature) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      throw const FormatException('No ZIP end-of-central-directory found.');
    }
    final entryCount = tailData.getUint16(eocd + 10, Endian.little);
    final centralOffset = tailData.getUint32(eocd + 16, Endian.little);
    final eocdAbsolute = fileLength - tailLength + eocd;
    if (centralOffset > eocdAbsolute) {
      throw const FormatException('Corrupt central directory.');
    }

    raf.setPositionSync(centralOffset);
    final central = raf.readSync(eocdAbsolute - centralOffset);
    final data = ByteData.sublistView(central);
    final entries = <QapZipEntry>[];
    var cursor = 0;
    for (var i = 0; i < entryCount; i += 1) {
      if (cursor + 46 > central.length ||
          data.getUint32(cursor, Endian.little) != _centralSignature) {
        throw const FormatException('Corrupt central directory.');
      }
      final crc = data.getUint32(cursor + 16, Endian.little);
      final compressedSize = data.getUint32(cursor + 20, Endian.little);
      final nameLength = data.getUint16(cursor + 28, Endian.little);
      final extraLength = data.getUint16(cursor + 30, Endian.little);
      final commentLength = data.getUint16(cursor + 32, Endian.little);
      final localOffset = data.getUint32(cursor + 42, Endian.little);
      final name = String.fromCharCodes(
        central.sublist(cursor + 46, cursor + 46 + nameLength),
      );
      raf.setPositionSync(localOffset + 26);
      final localLengths = ByteData.sublistView(raf.readSync(4));
      entries.add(
        QapZipEntry(
          name: name,
          localHeaderOffset: localOffset,
          dataOffset:
              localOffset +
              30 +
              localLengths.getUint16(0, Endian.little) +
              localLengths.getUint16(2, Endian.little),
          length: compressedSize,
          crc32: crc,
        ),
      );
      cursor += 46 + nameLength + extraLength + commentLength;
    }
    return QapZipLayout(
      entries: entries,
      centralDirectoryOffset: centralOffset,
    );
  } finally {
    raf.closeSync();
  }
}

/// CRC-32 (ZIP polynomial), table-driven.
final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i += 1) {
    var c = i;
    for (var k = 0; k < 8; k += 1) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[i] = c;
  }
  return table;
}

int qapCrc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (var i = 0; i < bytes.length; i += 1) {
    c = _crcTable[(c ^ bytes[i]) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Appends [newEntries] ({name: raw bytes, STORE'd}) to the .qap at
/// [path] IN PLACE: new locals write from the old central directory's
/// offset, then the merged central directory (old actives minus shadowed
/// names minus [removeNames], plus the new entries) and a fresh EOCD
/// close the file. [removeNames] deletes entries outright (a cel that
/// became empty or moved away) — their bytes turn to garbage like any
/// shadowed entry, reclaimed at the next compaction. Returns the
/// resulting layout (offsets valid for the rewritten file).
QapZipLayout appendQapEntries({
  required String path,
  required Map<String, Uint8List> newEntries,
  Set<String> removeNames = const {},
}) {
  final file = File(path);
  // Tail-only parse: the append must not scale with file size.
  final layout = parseQapZipLayoutFile(path);

  final survivors = [
    for (final entry in layout.entries)
      if (!newEntries.containsKey(entry.name) &&
          !removeNames.contains(entry.name))
        entry,
  ];

  final builder = BytesBuilder(copy: false);
  final appended = <QapZipEntry>[];
  var writeOffset = layout.centralDirectoryOffset;

  Uint8List localHeader(String name, Uint8List bytes, int crc) {
    final nameBytes = Uint8List.fromList(name.codeUnits);
    final header = ByteData(30);
    header.setUint32(0, _localSignature, Endian.little);
    header.setUint16(4, 20, Endian.little); // version needed
    header.setUint16(6, 0, Endian.little); // flags
    header.setUint16(8, 0, Endian.little); // method 0 = STORE
    header.setUint32(10, 0, Endian.little); // dos time/date
    header.setUint32(14, crc, Endian.little);
    header.setUint32(18, bytes.length, Endian.little);
    header.setUint32(22, bytes.length, Endian.little);
    header.setUint16(26, nameBytes.length, Endian.little);
    header.setUint16(28, 0, Endian.little);
    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(nameBytes);
    return out.takeBytes();
  }

  for (final entry in newEntries.entries) {
    final crc = qapCrc32(entry.value);
    final header = localHeader(entry.key, entry.value, crc);
    appended.add(
      QapZipEntry(
        name: entry.key,
        localHeaderOffset: writeOffset,
        dataOffset: writeOffset + header.length,
        length: entry.value.length,
        crc32: crc,
      ),
    );
    builder
      ..add(header)
      ..add(entry.value);
    writeOffset += header.length + entry.value.length;
  }

  // Central directory over survivors + appended.
  final centralOffset = writeOffset;
  final central = BytesBuilder(copy: false);
  final all = [...survivors, ...appended];
  for (final entry in all) {
    final nameBytes = Uint8List.fromList(entry.name.codeUnits);
    final record = ByteData(46);
    record.setUint32(0, _centralSignature, Endian.little);
    record.setUint16(4, 20, Endian.little); // version made by
    record.setUint16(6, 20, Endian.little); // version needed
    record.setUint16(8, 0, Endian.little);
    record.setUint16(10, 0, Endian.little); // method STORE
    record.setUint32(12, 0, Endian.little); // time/date
    record.setUint32(16, entry.crc32, Endian.little);
    record.setUint32(20, entry.length, Endian.little);
    record.setUint32(24, entry.length, Endian.little);
    record.setUint16(28, nameBytes.length, Endian.little);
    record.setUint32(42, entry.localHeaderOffset, Endian.little);
    central
      ..add(record.buffer.asUint8List())
      ..add(nameBytes);
  }
  final centralBytes = central.takeBytes();
  final eocd = ByteData(22);
  eocd.setUint32(0, _eocdSignature, Endian.little);
  eocd.setUint16(8, all.length, Endian.little);
  eocd.setUint16(10, all.length, Endian.little);
  eocd.setUint32(12, centralBytes.length, Endian.little);
  eocd.setUint32(16, centralOffset, Endian.little);

  // One sequential write: truncate at the old central directory, then
  // locals + central + EOCD.
  final raf = file.openSync(mode: FileMode.append);
  try {
    raf.truncateSync(layout.centralDirectoryOffset);
    raf.setPositionSync(layout.centralDirectoryOffset);
    raf.writeFromSync(builder.takeBytes());
    raf.writeFromSync(centralBytes);
    raf.writeFromSync(eocd.buffer.asUint8List());
    raf.flushSync();
  } finally {
    raf.closeSync();
  }

  return QapZipLayout(entries: all, centralDirectoryOffset: centralOffset);
}
