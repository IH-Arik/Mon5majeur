class BonusInventory {
  final int sixthManCharges;
  final int chefCurryCharges;
  final int luxuryTaxCharges;
  final bool liveScoringActive;
  final bool stopPubActive;

  const BonusInventory({
    this.sixthManCharges = 0,
    this.chefCurryCharges = 0,
    this.luxuryTaxCharges = 0,
    this.liveScoringActive = false,
    this.stopPubActive = false,
  });

  factory BonusInventory.fromJson(Map<String, dynamic> json) {
    return BonusInventory(
      sixthManCharges: (json['sixth_man_charges'] as num?)?.toInt() ?? 0,
      chefCurryCharges: (json['chef_curry_charges'] as num?)?.toInt() ?? 0,
      luxuryTaxCharges: (json['luxury_tax_charges'] as num?)?.toInt() ?? 0,
      liveScoringActive: json['live_scoring_active'] as bool? ?? false,
      stopPubActive: json['stop_pub_active'] as bool? ?? false,
    );
  }

  static const empty = BonusInventory();
}
