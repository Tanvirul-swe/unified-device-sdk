/// Product identifiers for supported devices.
///
/// Product IDs are 16-bit values where the high byte represents the
/// product category and the low byte identifies the specific product.
///
/// TODO: Populate with actual product IDs once hardware team finalizes them.
///       The current values are placeholders for development and testing.
class ProductIds {
  ProductIds._();

  // ---- Product Categories ----
  /// Placeholder category — replace with actual categories.
  static const int categoryPlaceholder1 = 0x01;

  /// Placeholder category — replace with actual categories.
  static const int categoryPlaceholder2 = 0x02;

  // ---- Placeholder Products ----
  /// Placeholder product ID for development/testing.
  static const int productPlaceholder1 = 0x0101;

  /// Placeholder product ID for development/testing.
  static const int productPlaceholder2 = 0x0102;

  /// Placeholder product ID for development/testing.
  static const int productPlaceholder3 = 0x0201;

  // ---- Unknown ----
  /// Used when the product ID cannot be determined.
  static const int unknown = 0x0000;

  /// Returns the product category for a given product ID.
  static int getCategory(int productId) => (productId >> 8) & 0xFF;

  /// Returns a human-readable name for a product ID.
  ///
  /// TODO: Update with actual product names once hardware team finalizes them.
  static String getProductName(int productId) {
    return _productNames[productId] ??
        'Unknown Product (0x${productId.toRadixString(16).toUpperCase().padLeft(4, '0')})';
  }

  static const Map<int, String> _productNames = {
    productPlaceholder1: 'Product Placeholder 1',
    productPlaceholder2: 'Product Placeholder 2',
    productPlaceholder3: 'Product Placeholder 3',
  };
}