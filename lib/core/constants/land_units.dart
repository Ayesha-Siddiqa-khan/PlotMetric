/// Fixed land-measurement conversion constants for PlotMetric v1.0.
///
/// Profile: 272.25 sq ft per Marla convention.
/// - 1 Kanal = 20 Marla = 180 Sarsai = 5,445 sq ft
/// - 1 Marla = 9 Sarsai = 272.25 sq ft
/// - 1 Sarsai = 30.25 sq ft
///
/// Exact integer centi-Sarsai (1/100th of a Sarsai):
/// - 1 Kanal = 18,000 centi-Sarsai
/// - 1 Marla = 900 centi-Sarsai
/// - 1 Sarsai = 100 centi-Sarsai
/// - 1 centi-Sarsai = 0.3025 sq ft (3,025 ten-thousandths of a sq ft)
class LandUnits {
  const LandUnits._();

  static const int marlasPerKanal = 20;
  static const int sarsaisPerMarla = 9;
  static const int sarsaisPerKanal = 180;

  static const int centiSarsaisPerKanal = 18000;
  static const int centiSarsaisPerMarla = 900;
  static const int centiSarsaisPerSarsai = 100;

  /// Multiplier to convert centi-Sarsai to 1/10,000 sq ft
  static const int tenThousandthsSqFtPerCentiSarsai = 3025;

  /// Input bounds
  static const int maxKanal = 1000000;
  static const int maxMarla = 19;
  static const double maxSarsai = 8.99;
  static const int maxSarsaiCenti = 899;

  /// Built-in purpose suggestions
  static const List<String> defaultPurposes = [
    'Nil',
    'Total Area',
    'Roads',
    'Sewerage',
    'Mosque',
    'Dispensary',
    'Graveyard',
    'Parks',
    'School',
    'Community Centre',
    'Water Supply',
    'Utilities',
    'Commercial',
    'Residential',
    'Other',
  ];
}
