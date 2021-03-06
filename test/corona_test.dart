// Copyright (c) 2017, Frank. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:corona/corona.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

import 'package:corona/src/codec/convert.dart';

void main() {
  group('bool', () {
    test('all values', () {
      expect(readBool(writeBool(null)), null);
      expect(readBool(writeBool(true)), true);
      expect(readBool(writeBool(false)), false);
    });

    test('should throw when decoding is impossible', () {
      try {
        expect(readBool(new Uint8List.fromList(const <int>[3])), isNull);
      } catch (e) {
        expect(e, isException);
      }
    });
  });

  group('int', () {
    const int zero = 0;
    const int short = 0x80;
    const int long = 123456789123456789123456789123456789;
    const int shortNeg = -0x80;
    const int longNeg = -123456789123456789123456789123456789;

    test('zero value', () {
      expect(readInt(writeInt(null)), null);
      expect(readInt(writeInt(zero)), zero);
    });

    test('all bit ranges', () {
      expect(readInt(writeInt(short)), short);
      expect(readInt(writeInt(long)), long);
      expect(readInt(writeInt(shortNeg)), shortNeg);
      expect(readInt(writeInt(longNeg)), longNeg);
    });
  });

  group('uint', () {
    const int zero = 0;
    const int short = 0x80;
    const int long = 123456789123456789123456789123456789;

    test('zero value', () {
      expect(readUint(writeUint(zero)), zero);
    });

    test('all bit ranges', () {
      expect(readUint(writeUint(short)), short);
      expect(readUint(writeUint(long)), long);
    });
  });

  group('double', () {
    const double zero = .0;
    const double short = 1.23;
    const double long = 76484811.238415185874514;
    const double fract = 1/3;
    const double shortNeg = -1.23;
    const double longNeg = -76484811.238415185874514;
    const double fractNeg = -1/3;

    test('zero value', () {
      expect(readDouble(writeDouble(null)), null);
      expect(readDouble(writeDouble(zero)), zero);
    });

    test('all bit ranges', () {
      expect(readDouble(writeDouble(short)), short);
      expect(readDouble(writeDouble(long)), long);
      expect(readDouble(writeDouble(fract)), fract);
      expect(readDouble(writeDouble(shortNeg)), shortNeg);
      expect(readDouble(writeDouble(longNeg)), longNeg);
      expect(readDouble(writeDouble(fractNeg)), fractNeg);
    });
  });

  group('String', () {
    const String zero = '';
    const String strA = 'hello!';
    const String strB = 'hello\r\n\tthere!';
    const String strC = '漢字';

    test('zero value', () {
      expect(readString(writeString(null)), null);
      expect(readString(writeString(zero)), zero);
    });

    test('all bit ranges', () {
      expect(readString(writeString(strA)), strA);
      expect(readString(writeString(strB)), strB);
      expect(readString(writeString(strC)), strC);
    });
  });

  group('DateTime', () {
    DateTime dateTime = new DateTime(2017, 8, 9, 11, 31, 20, 541, 0);

    test('zero value', () {
      expect(readDateTime(writeDateTime(null)), null);
    });

    test('random date time', () {
      expect(readDateTime(writeDateTime(dateTime)), dateTime);
    });
  });

  group('Iterable', () {
    const Iterable<int> zeroList = const [];
    const Iterable<int> intList = const <int>[1, 2, 3, 4, 5];
    const Iterable<String> strList = const <String>[
      'Hi',
      'from',
      'some',
      'list',
      'values',
      '漢字'
    ];

    test('zero value', () {
      expect(readIterable(writeIterable(null, writeInt), readInt), null);
      expect(readIterable(writeIterable(zeroList, writeInt), readInt), zeroList);
    });

    test('types', () {
      expect(readIterable(writeIterable(intList, writeInt), readInt), intList);
      expect(readIterable(writeIterable(strList, writeString), readString),
          strList);
    });
  });
}
