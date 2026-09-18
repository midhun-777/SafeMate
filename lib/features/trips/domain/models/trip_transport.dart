/// Transport modes for SafeMate travel journeys.
library;

enum TripTransport {
  flight('flight', '✈ Flight', 'Air travel'),
  train('train', '🚆 Train', 'Rail network travel'),
  bus('bus', '🚌 Bus', 'Coach / bus transit'),
  car('car', '🚗 Car / Road Trip', 'Personal vehicle or carpool'),
  bike('bike', '🚲 Bike / Motorcycle', 'Two-wheeler journey'),
  flexible('flexible', '🔄 Flexible', 'Open to multiple modes of transport'),
  other('other', '✨ Other', 'Alternative transit');

  final String code;
  final String label;
  final String description;

  const TripTransport(this.code, this.label, this.description);

  static TripTransport fromCode(String? code) {
    if (code == 'road_trip') return TripTransport.car;
    if (code == 'backpacking' || code == 'cruise') return TripTransport.other;
    for (final mode in TripTransport.values) {
      if (mode.code == code) return mode;
    }
    return TripTransport.flexible;
  }
}
