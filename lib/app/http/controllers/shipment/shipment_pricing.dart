const Map<String, List<String>> _cityGroups = {
  'amman': ['عمان', 'عمّان', 'amman'],
  'zarqa': ['الزرقاء', 'zarqa'],
  'irbid': ['إربد', 'اربد', 'irbid'],
  'ajloun': ['عجلون', 'ajloun'],
  'jerash': ['جرش', 'jerash'],
  'salt': ['السلط', 'salt'],
  'madaba': ['مادبا', 'madaba'],
  'karak': ['الكرك', 'karak'],
  'tafileh': ['الطفيلة', 'tafileh'],
  'maan': ['معان', 'maan'],
  'aqaba': ['العقبة', 'aqaba'],
  'mafraq': ['المفرق', 'mafraq'],
  'balqa': ['البلقاء', 'balqa'],
};

const Map<String, Map<String, double>> _distancePrices = {
  'amman': {'zarqa': 2.0, 'salt': 2.5, 'madaba': 2.5, 'balqa': 2.5, 'jerash': 3.0, 'irbid': 3.5, 'ajloun': 3.5, 'mafraq': 3.5, 'karak': 4.0, 'tafileh': 4.5, 'maan': 5.0, 'aqaba': 5.5},
  'zarqa': {'amman': 2.0, 'mafraq': 2.5, 'jerash': 3.0, 'irbid': 3.5, 'salt': 3.0, 'aqaba': 5.5},
  'irbid': {'ajloun': 2.0, 'jerash': 2.0, 'mafraq': 2.5, 'zarqa': 3.5, 'amman': 3.5, 'aqaba': 6.0},
};

const Map<String, double> _sizeMultiplier = {
  'small': 1.0,
  'medium': 1.5,
  'large': 2.0,
};

const Map<String, double> _urgencyMultiplier = {
  'normal': 1.0,
  'urgent': 2.5,
};

String _normalizeCity(String city) {
  final lower = city.trim().toLowerCase();
  for (final entry in _cityGroups.entries) {
    for (final alias in entry.value) {
      if (lower == alias || lower.contains(alias)) {
        return entry.key;
      }
    }
  }
  return lower;
}

double calculateSuggestedPrice({
  required String fromCity,
  required String toCity,
  required String size,
  required String urgency,
}) {
  final from = _normalizeCity(fromCity);
  final to = _normalizeCity(toCity);

  double basePrice;

  if (from == to) {
    basePrice = 1.5;
  } else {
    basePrice = _distancePrices[from]?[to] ??
        _distancePrices[to]?[from] ??
        3.5; // default for unknown pairs
  }

  final sizeMult = _sizeMultiplier[size] ?? 1.0;
  final urgencyMult = _urgencyMultiplier[urgency] ?? 1.0;

  return double.parse((basePrice * sizeMult * urgencyMult).toStringAsFixed(2));
}

bool citiesMatch(String tripCity, String shipmentCity) {
  return _normalizeCity(tripCity) == _normalizeCity(shipmentCity);
}
