class GoldPriceCalculator {
  // This is an editable modelling assumption, not a verified live Indian duty rate.
  static const double importDutyAssumption = 0.15;

  static Map<String, double> calculateAllPrices({
    required double internationalInrPerGram,
  }) {
    final estimated24K = internationalInrPerGram * (1 + importDutyAssumption);
    return {
      '24K': estimated24K,
      '22K': estimated24K * (22 / 24),
      '18K': estimated24K * (18 / 24),
    };
  }
}
