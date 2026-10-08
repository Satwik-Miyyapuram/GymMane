// Nutrition data model — plain data classes, mirroring the repo's
// models/*.dart conventions (toJson / fromJson, no framework imports).
//
// Values are per 100 g (per 100 ml for liquids). Composition constants in the
// seed set are USDA FoodData Central / NEVO-aligned; see CREDITS.md.

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    this.liquid = false,
  });

  final String id;
  final String name;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final bool liquid; // true → grams mean millilitres

  String get unit => liquid ? 'ml' : 'g';

  FoodItem copyWith({
    String? name,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
    double? fibre,
  }) =>
      FoodItem(
        id: id,
        name: name ?? this.name,
        kcal: kcal ?? this.kcal,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        fibre: fibre ?? this.fibre,
        liquid: liquid,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kcal': kcal,
        'p': protein,
        'c': carbs,
        'f': fat,
        'fi': fibre,
        if (liquid) 'liq': true,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        kcal: ((j['kcal'] ?? 0) as num).toDouble(),
        protein: ((j['p'] ?? 0) as num).toDouble(),
        carbs: ((j['c'] ?? 0) as num).toDouble(),
        fat: ((j['f'] ?? 0) as num).toDouble(),
        fibre: ((j['fi'] ?? 0) as num).toDouble(),
        liquid: (j['liq'] ?? false) as bool,
      );
}

/// One ingredient line in a meal slot: a food and its planned amount.
class PlannedItem {
  const PlannedItem(this.foodId, this.grams);

  final String foodId;
  final double grams;

  PlannedItem copyWith({double? grams}) => PlannedItem(foodId, grams ?? this.grams);

  Map<String, dynamic> toJson() => {'id': foodId, 'g': grams};

  factory PlannedItem.fromJson(Map<String, dynamic> j) => PlannedItem(
        (j['id'] ?? '') as String,
        ((j['g'] ?? 0) as num).toDouble(),
      );
}

class MealSlot {
  const MealSlot({required this.id, required this.name, required this.items});

  final String id;
  final String name;
  final List<PlannedItem> items;

  MealSlot copyWith({String? name, List<PlannedItem>? items}) => MealSlot(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory MealSlot.fromJson(Map<String, dynamic> j) => MealSlot(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => PlannedItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class MacroTargets {
  const MacroTargets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  MacroTargets copyWith({
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
    double? fibre,
  }) =>
      MacroTargets(
        kcal: kcal ?? this.kcal,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        fibre: fibre ?? this.fibre,
      );

  Map<String, dynamic> toJson() =>
      {'kcal': kcal, 'p': protein, 'c': carbs, 'f': fat, 'fi': fibre};

  factory MacroTargets.fromJson(Map<String, dynamic> j) => MacroTargets(
        kcal: ((j['kcal'] ?? 0) as num).toDouble(),
        protein: ((j['p'] ?? 0) as num).toDouble(),
        carbs: ((j['c'] ?? 0) as num).toDouble(),
        fat: ((j['f'] ?? 0) as num).toDouble(),
        fibre: ((j['fi'] ?? 0) as num).toDouble(),
      );
}

/// A per-day deviation from the plan: foodId → grams actually eaten.
/// Only stored days differ from the plan; unlogged days use the plan as-is.
class IntakeDay {
  IntakeDay(this.date, this.grams);

  final DateTime date; // normalised to midnight
  final Map<String, double> grams; // foodId → grams eaten that day

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'g': grams.map((k, v) => MapEntry(k, v)),
      };

  factory IntakeDay.fromJson(Map<String, dynamic> j) => IntakeDay(
        DateTime.tryParse((j['d'] ?? '') as String) ?? DateTime.now(),
        ((j['g'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
}

/// Summed macros for a set of amounts.
class MacroTotals {
  const MacroTotals(this.kcal, this.protein, this.carbs, this.fat, this.fibre);

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  static const zero = MacroTotals(0, 0, 0, 0, 0);

  MacroTotals operator +(MacroTotals o) => MacroTotals(
        kcal + o.kcal,
        protein + o.protein,
        carbs + o.carbs,
        fat + o.fat,
        fibre + o.fibre,
      );

  /// Atwater cross-check: 4P + 4C + 9F.
  double get atwater => protein * 4 + carbs * 4 + fat * 9;
}

// ---------------------------------------------------------------------------
// Seed set: the Recomp Protocol v1.0 foods and 4-slot plan (docs/
// recomp-protocol-v1.md, Appendix A). Food values per 100 g (milk per 100 ml),
// USDA FDC / NEVO-aligned. The seed is applied once, on first launch, and the
// user can edit everything afterwards.
// ---------------------------------------------------------------------------

const List<FoodItem> kSeedFoods = [
  FoodItem(id: 'oats', name: 'Oats', kcal: 372, protein: 13.5, carbs: 58.7, fat: 7.0, fibre: 10.0),
  FoodItem(id: 'egg', name: 'Whole egg', kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, fibre: 0),
  FoodItem(id: 'whites', name: 'Egg whites', kcal: 52, protein: 11.0, carbs: 0.7, fat: 0.2, fibre: 0),
  FoodItem(id: 'milk', name: 'Skim milk (magere melk)', kcal: 34, protein: 3.4, carbs: 5.0, fat: 0.1, fibre: 0, liquid: true),
  FoodItem(id: 'chicken', name: 'Chicken breast', kcal: 120, protein: 22.5, carbs: 0, fat: 2.6, fibre: 0),
  FoodItem(id: 'pasta', name: 'Durum pasta', kcal: 359, protein: 12.5, carbs: 72.0, fat: 1.5, fibre: 3.0),
  FoodItem(id: 'rice', name: 'White rice (sona masoori)', kcal: 356, protein: 7.1, carbs: 78.9, fat: 0.7, fibre: 1.3),
  FoodItem(id: 'lentils', name: 'Red lentils, dry', kcal: 352, protein: 25.0, carbs: 60.0, fat: 1.1, fibre: 11.0),
  FoodItem(id: 'broccoli', name: 'Broccoli', kcal: 34, protein: 2.8, carbs: 4.4, fat: 0.4, fibre: 2.6),
  FoodItem(id: 'passata', name: 'Passata', kcal: 29, protein: 1.4, carbs: 5.0, fat: 0.2, fibre: 1.4),
  FoodItem(id: 'tin_tomato', name: 'Canned tomato', kcal: 24, protein: 1.2, carbs: 4.1, fat: 0.2, fibre: 1.5),
  FoodItem(id: 'onion', name: 'Onion', kcal: 40, protein: 1.1, carbs: 9.3, fat: 0.1, fibre: 1.7),
  FoodItem(id: 'carrot', name: 'Carrot', kcal: 41, protein: 0.9, carbs: 9.6, fat: 0.2, fibre: 2.8),
  FoodItem(id: 'mushroom', name: 'Mushrooms', kcal: 22, protein: 3.1, carbs: 3.3, fat: 0.3, fibre: 1.0),
  FoodItem(id: 'sweet_potato', name: 'Sweet potato', kcal: 86, protein: 1.6, carbs: 20.0, fat: 0.1, fibre: 3.0),
  FoodItem(id: 'banana', name: 'Banana', kcal: 89, protein: 1.1, carbs: 22.8, fat: 0.3, fibre: 2.6),
  FoodItem(id: 'oil', name: 'Groundnut/olive oil', kcal: 884, protein: 0, carbs: 0, fat: 100, fibre: 0),
  FoodItem(id: 'peas', name: 'Peas', kcal: 77, protein: 5.2, carbs: 13.6, fat: 0.4, fibre: 5.1),
];

const List<MealSlot> kSeedSlots = [
  MealSlot(id: 'b', name: 'Breakfast', items: [
    PlannedItem('oats', 40),
    PlannedItem('egg', 50),
    PlannedItem('milk', 350),
    PlannedItem('onion', 30),
    PlannedItem('tin_tomato', 40),
    PlannedItem('oil', 2),
  ]),
  MealSlot(id: 'l', name: 'Lunch', items: [
    PlannedItem('chicken', 120),
    PlannedItem('pasta', 80),
    PlannedItem('broccoli', 150),
    PlannedItem('passata', 150),
    PlannedItem('onion', 40),
    PlannedItem('carrot', 40),
    PlannedItem('oil', 4),
  ]),
  MealSlot(id: 'd', name: 'Dinner', items: [
    PlannedItem('chicken', 110),
    PlannedItem('rice', 45),
    PlannedItem('lentils', 25),
    PlannedItem('broccoli', 180),
    PlannedItem('mushroom', 60),
    PlannedItem('onion', 30),
    PlannedItem('tin_tomato', 50),
    PlannedItem('oil', 6),
  ]),
  MealSlot(id: 's', name: 'Snack', items: [
    PlannedItem('milk', 400),
    PlannedItem('banana', 70),
    PlannedItem('sweet_potato', 100),
  ]),
];

const MacroTargets kSeedTargets =
    MacroTargets(kcal: 1800, protein: 128, carbs: 247, fat: 32, fibre: 30);
