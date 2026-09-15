/// Standard Geohash encoding utility for SafeMate spatial route indexing.
/// Facilitates scalable PostgreSQL indexing on trips(origin_geohash, destination_geohash).
class GeohashHelper {
  const GeohashHelper._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes latitude and longitude coordinates into a Geohash string of specified [precision].
  static String encode(double latitude, double longitude, {int precision = 8}) {
    if (latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError('Latitude must be between -90.0 and 90.0');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError('Longitude must be between -180.0 and 180.0');
    }

    double minLat = -90.0;
    double maxLat = 90.0;
    double minLon = -180.0;
    double maxLon = 180.0;

    final StringBuffer buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final double mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          ch |= 1 << (4 - bit);
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final double mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }
}
