import '../../core/bytes/endian_utils.dart';
import 'dart:convert';

/// A single TLV entry encoded as `TYPE LENGTH_H LENGTH_L VALUE`.
class Tlv {
  final int type;
  final List<int> value;

  Tlv({required this.type, required List<int> value})
    : value = List<int>.unmodifiable(value) {
    _validateUint8(type, 'type');
    _validateLength(this.value.length);
    for (var i = 0; i < this.value.length; i++) {
      _validateUint8(this.value[i], 'value[$i]');
    }
  }

  int get length => value.length;

  List<int> toBytes() {
    return <int>[type, ...EndianUtils.uint16ToBytesBE(length), ...value];
  }

  String asAsciiString() => String.fromCharCodes(value);

  String asUtf8String() => utf8.decode(value, allowMalformed: true);

  Tlv copyWith({int? type, List<int>? value}) {
    return Tlv(type: type ?? this.type, value: value ?? this.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tlv &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(value, other.value);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(value));

  @override
  String toString() {
    return 'Tlv('
        'type: 0x${type.toRadixString(16).toUpperCase().padLeft(2, '0')}, '
        'length: $length)';
  }

  static void _validateUint8(int value, String name) {
    if (value < 0 || value > 0xFF) {
      throw ArgumentError('$name must be 0-255, but got $value');
    }
  }

  static void _validateLength(int value) {
    if (value < 0 || value > 0xFFFF) {
      throw ArgumentError('TLV length must be 0-65535, but got $value');
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
