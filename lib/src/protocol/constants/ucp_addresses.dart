/// Well-known endpoint addresses used by the dummy guide.
class UcpAddresses {
  UcpAddresses._();

  static const int software = 0x01;
  static const int device = 0x10;

  static const int defaultSource = software;
  static const int defaultDestination = device;

  static bool isValid(int address) => address >= 0x00 && address <= 0xFF;
}
