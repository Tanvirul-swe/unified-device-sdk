/// Profile identifiers used in the official UCP header.
class ProfileIds {
  ProfileIds._();

  static const int dummyM2m = 0x01;
  static const int defaultProfile = dummyM2m;

  static bool isValid(int profileId) => profileId >= 0x00 && profileId <= 0xFF;
}
