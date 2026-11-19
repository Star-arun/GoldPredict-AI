class GoldPriceCalculator {
  // Configurable assumptions, not a live market premium.
  static const double importDuty = 0.15;
  static const double tamilNaduPremium = 0.0;

  static double calculateTamilNaduPrice({
    required double internationalInrPerGram,
  }) {
    return internationalInrPerGram * (1 + importDuty) * (1 + tamilNaduPremium);
  }

  static Map<String, double> calculateAllPrices({
    required double internationalInrPerGram,
  }) {
    final price24K = calculateTamilNaduPrice(
      internationalInrPerGram: internationalInrPerGram,
    );

    return {
      '24K': price24K,
      '22K': price24K * (22 / 24),
      '18K': price24K * (18 / 24),
    };
  }
}
