part of 'fit_state.dart';

/// Offline nutrition tracking: a 4-slot meal plan, macro targets, per-day
/// intake deviations, a 14-day weight moving average with the protocol's
/// adjustment bands, and a 14-day grocery aggregation.
///
/// Everything lives in the one JSON blob the app already persists, so the
/// module adds no storage of its own, no network and no dependencies.
mixin NutritionState on FitCore {
  final List<FoodItem> foods = List.of(kSeedFoods);
  final List<MealSlot> mealSlots = List.of(kSeedSlots);
  MacroTargets macroTargets = kSeedTargets;

  /// Days that deviate from the plan, keyed by midnight-normalised date.
  final Map<String, Map<String, double>> _intake = {};

  FoodItem? foodById(String id) {
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  MealSlot? slotById(String id) {
    for (final s in mealSlots) {
      if (s.id == id) return s;
    }
    return null;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) {
    final m = _midnight(d);
    return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }

  /// Planned grams per food, summed across slots (chicken appears in lunch and
  /// dinner; milk in breakfast and snack).
  Map<String, double> plannedGrams() {
    final out = <String, double>{};
    for (final slot in mealSlots) {
      for (final item in slot.items) {
        out[item.foodId] = (out[item.foodId] ?? 0) + item.grams;
      }
    }
    return out;
  }

  /// Planned grams with that day's logged amounts applied on top.
  Map<String, double> gramsFor(DateTime day) {
    final grams = plannedGrams();
    final logged = _intake[_key(day)];
    if (logged != null) {
      for (final e in logged.entries) {
        grams[e.key] = e.value;
      }
    }
    return grams;
  }

  MacroTotals totalsFrom(Map<String, double> grams) {
    var t = MacroTotals.zero;
    for (final e in grams.entries) {
      final f = foodById(e.key);
      if (f == null) continue;
      final k = e.value / 100;
      t = t +
          MacroTotals(
            f.kcal * k,
            f.protein * k,
            f.carbs * k,
            f.fat * k,
            f.fibre * k,
          );
    }
    return t;
  }

  MacroTotals get plannedTotals => totalsFrom(plannedGrams());

  MacroTotals totalsFor(DateTime day) => totalsFrom(gramsFor(day));

  MacroTotals get todayTotals => totalsFor(DateTime.now());

  MacroTotals slotTotals(String slotId) {
    final slot = slotById(slotId);
    if (slot == null) return MacroTotals.zero;
    final logged = _intake[_key(DateTime.now())];
    final grams = <String, double>{};
    for (final item in slot.items) {
      final g = logged != null && logged.containsKey(item.foodId)
          ? logged[item.foodId]!
          : item.grams;
      grams[item.foodId] = (grams[item.foodId] ?? 0) + g;
    }
    return totalsFrom(grams);
  }

  /// Records what was actually eaten. Setting a food back to its planned
  /// amount clears the override, so the day falls back to the plan.
  void setIntake(String foodId, double grams, {DateTime? day}) {
    final when = day ?? DateTime.now();
    final k = _key(when);
    final planned = plannedGrams()[foodId] ?? 0;
    final entry = Map<String, double>.of(_intake[k] ?? const {});
    if ((grams - planned).abs() < 0.005) {
      entry.remove(foodId);
    } else {
      entry[foodId] = grams.clamp(0, 5000);
    }
    if (entry.isEmpty) {
      _intake.remove(k);
    } else {
      _intake[k] = entry;
    }
    _persist();
    notifyListeners();
  }

  void setPlannedGrams(String slotId, String foodId, double grams) {
    final slot = slotById(slotId);
    if (slot == null) return;
    final next = <PlannedItem>[];
    for (final item in slot.items) {
      next.add(item.foodId == foodId
          ? item.copyWith(grams: grams.clamp(0, 5000))
          : item);
    }
    final i = mealSlots.indexOf(slot);
    mealSlots[i] = slot.copyWith(items: next);
    _persist();
    notifyListeners();
  }

  void setTargets(MacroTargets targets) {
    macroTargets = targets;
    _persist();
    notifyListeners();
  }

  /// Average of the logged weigh-ins over the last 14 days, newest first.
  /// Returns null until 14 days have been logged, because a shorter window is
  /// what the protocol calls noise.
  double? movingAverage14({DateTime? today}) {
    final end = _midnight(today ?? DateTime.now());
    final byDay = <String, double>{};
    for (final w in bodyweight) {
      final d = _midnight(w.date);
      if (d.isAfter(end) || end.difference(d).inDays >= 14) continue;
      byDay[_key(d)] = w.kg;
    }
    if (byDay.length < 14) return null;
    return byDay.values.reduce((a, b) => a + b) / byDay.length;
  }

  /// Average of the 14 logged days before the current window; null until it is
  /// full. Comparing the two is what the protocol's bands are based on.
  double? previousAverage14({DateTime? today}) {
    final end = _midnight(today ?? DateTime.now());
    final byDay = <String, double>{};
    for (final w in bodyweight) {
      final d = _midnight(w.date);
      final back = end.difference(d).inDays;
      if (d.isAfter(end) || back < 14 || back >= 28) continue;
      byDay[_key(d)] = w.kg;
    }
    if (byDay.length < 14) return null;
    return byDay.values.reduce((a, b) => a + b) / byDay.length;
  }

  /// Protocol section 8: compares this 14-day average with the previous one.
  String weightTrendBand({required double previousAvg, DateTime? today}) {
    final avg = movingAverage14(today: today);
    if (avg == null) return 'unknown';
    final delta = avg - previousAvg;
    if (delta <= -0.5) return 'cut-too-hard';
    if (delta >= 0.5) return 'gaining';
    return 'recomp';
  }

  int get daysLoggedInWindow {
    final end = _midnight(DateTime.now());
    final seen = <String>{};
    for (final w in bodyweight) {
      final d = _midnight(w.date);
      if (d.isAfter(end) || end.difference(d).inDays >= 14) continue;
      seen.add(_key(d));
    }
    return seen.length;
  }

  /// One row per ingredient in the plan, scaled to [days] days.
  List<GroceryRow> groceryList({int days = 14}) {
    final grams = plannedGrams();
    final rows = <GroceryRow>[];
    for (final e in grams.entries) {
      final f = foodById(e.key);
      if (f == null) continue;
      rows.add(GroceryRow(f, e.value * days));
    }
    rows.sort((a, b) => b.grams.compareTo(a.grams));
    return rows;
  }

  String groceryText({int days = 14}) {
    final rows = groceryList(days: days);
    final b = StringBuffer('GymMane - $days day grocery list\n');
    for (final r in rows) {
      b.write('\n${r.food.name}: ${r.grams.round()} ${r.food.unit}');
    }
    return b.toString();
  }

  /// Applies the seed plan once. Later launches keep the user's own plan.
  void seedNutritionIfEmpty() {
    if (mealSlots.isNotEmpty) return;
    mealSlots.addAll(kSeedSlots);
    macroTargets = kSeedTargets;
  }

  void loadNutrition(Map<String, dynamic> data) {
    final n = (data['nutrition'] as Map?)?.cast<String, dynamic>();
    if (n == null) {
      seedNutritionIfEmpty();
      return;
    }
    foods
      ..clear()
      ..addAll(((n['foods'] as List?) ?? const [])
          .map((e) => FoodItem.fromJson((e as Map).cast<String, dynamic>())));
    mealSlots
      ..clear()
      ..addAll(((n['slots'] as List?) ?? const [])
          .map((e) => MealSlot.fromJson((e as Map).cast<String, dynamic>())));
    macroTargets =
        MacroTargets.fromJson((n['targets'] as Map?)?.cast<String, dynamic>() ?? {});
    _intake.clear();
    for (final e in ((n['intake'] as Map?) ?? const {}).entries) {
      _intake[e.key as String] = ((e.value as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    }
    seedNutritionIfEmpty();
  }

  Map<String, dynamic> nutritionToJson() => {
        'foods': foods.map((f) => f.toJson()).toList(),
        'slots': mealSlots.map((s) => s.toJson()).toList(),
        'targets': macroTargets.toJson(),
        'intake': _intake.map((k, v) => MapEntry(k, Map<String, dynamic>.of(v))),
      };

  void goNutrition() => pushRoute('nutrition');

  void backFromNutrition() => popRoute(fallback: 'tools');
}

/// A grocery line: the food and the total amount to buy.
class GroceryRow {
  const GroceryRow(this.food, this.grams);

  final FoodItem food;
  final double grams;
}
