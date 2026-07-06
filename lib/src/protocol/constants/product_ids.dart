class ProductIds {
  ProductIds._();

  static const int genericUnknown = 0x00;
  static const int aunkurUcp1 = 0x01;
  static const int soilTestingDevice = aunkurUcp1;
  static const int weatherStation = 0x02;
  static const int fisheriesMonitoringSystem = 0x03;
  static const int waterFlowSystem = 0x04;
  static const int irrigationController = 0x05;
  static const int gatewayHub = 0x06;
  static const int powerEnergyDevice = 0x07;
  static const int broadcastAny = 0xFF;

  static bool isValid(int productId) {
    return productId >= 0x00 && productId <= 0xFF;
  }

  static String getProductName(int productId) {
    return _productNames[productId] ??
        'Unknown Product (0x${productId.toRadixString(16).toUpperCase().padLeft(2, '0')})';
  }

  static const Map<int, String> _productNames = {
    genericUnknown: 'Generic / Unknown',
    aunkurUcp1: 'Aunkur UCP1',
    weatherStation: 'Weather Station',
    fisheriesMonitoringSystem: 'Fisheries Monitoring System',
    waterFlowSystem: 'Water Flow System',
    irrigationController: 'Irrigation Controller',
    gatewayHub: 'Gateway / Hub',
    powerEnergyDevice: 'Power / Energy Device',
    broadcastAny: 'Broadcast / Any',
  };
}
