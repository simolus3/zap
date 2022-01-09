import 'dart:convert';

const zbase32 = _ZBase32Encoder();

class _ZBase32Encoder extends Converter<List<int>, String> {
  const _ZBase32Encoder();

  @override
  String convert(List<int> input) {
    final output = StringBuffer();
    startChunkedConversionStringSink(output)
      ..add(input)
      ..close();

    return output.toString();
  }

  @override
  Sink<List<int>> startChunkedConversion(Sink<String> sink) {
    return _ZBase32EncodingSink(_SinkOfStringToSinkString(sink));
  }

  Sink<List<int>> startChunkedConversionStringSink(StringSink sink) {
    return _ZBase32EncodingSink(sink);
  }
}

// This works by splitting the input into 5-bit chunks and mapping those via the
// alphabet.
class _ZBase32EncodingSink extends ByteConversionSinkBase {
  static const _alphabet = 'ybndrfg8ejkmcpqxot1uwisza345h769';

  static const _bitmasks = [
    0x80, // One bit remaining, 1000 0000
    0xc0, // Two bits remaining, 1100 0000
    0xe0, // Three bits remaining, 1110 0000
    0xf0, // Four bits remaining, 1111 0000
    0xf8, // Five bits remaining, 1111 1000
  ];

  final StringSink _output;

  var remaining = 5;
  var startedChunk = 0;

  _ZBase32EncodingSink(this._output);

  void _addByte(int byte) {
    _output.writeCharCode(_alphabet.codeUnitAt(byte));
  }

  @override
  void add(List<int> chunk) {
    for (final byte in chunk) {
      final mask = _bitmasks[remaining - 1];
      // Finish group with the first remaining bits
      _addByte(startedChunk | ((byte & mask) >> (8 - remaining)));

      if (remaining < 4) {
        // We want to take the next 5 bits after we already took 8 - remaining.
        // For example, if remaining = 1 then we took the first bit and the next
        // five are at 0111 1100, or 31 << 2.
        final shift = 3 - remaining;
        final nextGroupMask = 31 << shift;
        _addByte((byte & nextGroupMask) >> shift);

        // Finally, add the lower bits to the next group.
        startedChunk = (byte & (7 >> remaining)) << (remaining + 2);
        remaining = remaining + 2;
      } else {
        // Add lower bits to next group
        remaining = remaining - 3;
        startedChunk = (byte & ~mask) << remaining;
      }
    }
  }

  @override
  void close() {
    if (remaining != 5) {
      _output.writeCharCode(_alphabet.codeUnitAt(startedChunk));
    }
  }
}

class _SinkOfStringToSinkString extends StringSink {
  final Sink<String> _sink;

  _SinkOfStringToSinkString(this._sink);

  @override
  void write(Object? obj) {
    _sink.add(obj.toString());
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    var isFirst = true;
    for (final element in objects) {
      if (!isFirst) {
        _sink.add(separator);
      }
      isFirst = false;

      write(element);
    }
  }

  @override
  void writeCharCode(int charCode) {
    _sink.add(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? obj = '']) {
    write(obj);
    writeCharCode(0x0a);
  }
}
