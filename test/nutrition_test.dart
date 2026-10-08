import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  FitState fresh() {
    final fit = FitState();
    fit.seedNutritionIfEmpty();
    return fit;
  }

  test('seed plan reproduces the verified protocol day (golden totals)', () {
    final fit = fresh();
    final t = fit.plannedTotals;
    // Oracle: recomp/verify_macros.py — 1,788 kcal, P 126.5, C 246.2,
    // F 30.5, fibre 30.0.
    expect(t.kcal, closeTo(1788, 1));
    expect(t.protein, closeTo(126.5, 0.2));
    expect(t.carbs, closeTo(246.2, 0.2));
    expect(t.fat, closeTo(30.5, 0.2));
    expect(t.fibre, closeTo(30.0, 0.2));
    // Atwater cross-check within 3%.
    expect((t.atwater - t.kcal).abs() / t.kcal, lessThan(0.03));
  });

  test('per-slot totals match the protocol', () {
    final fit = fresh();
    expect(fit.slotTotals('b').kcal, closeTo(379, 1));
    expect(fit.slotTotals('l').kcal, closeTo(593, 1));
    expect(fit.slotTotals('d').kcal, closeTo(532, 1));
    expect(fit.slotTotals('s').kcal, closeTo(284, 1));
  });

  test('1900 fallback: rice 45->70 g and snack milk 400->500 ml', () {
    final fit = fresh();
    fit.setPlannedGrams('d', 'rice', 70);
    fit.setPlannedGrams('s', 'milk', 500);
    final t = fit.plannedTotals;
    expect(t.kcal, closeTo(1911, 1));
    expect(t.protein, closeTo(131.7, 0.2));
    expect(t.fibre, closeTo(30.3, 0.2));
  });

  test('intake overrides only the logged foods, day-scoped', () {
    final fit = fresh();
    final today = DateTime.now();
    // Plan is 230 g chicken/day (120 lunch + 110 dinner); log 260 g.
    fit.setIntake('chicken', 260);
    expect(fit.totalsFor(today).protein,
        greaterThan(fit.plannedTotals.protein));
    // A different day still follows the plan.
    expect(fit.totalsFor(today.subtract(const Duration(days: 1))).protein,
        closeTo(fit.plannedTotals.protein, 0.01));
    // Setting back to the planned amount removes the override.
    fit.setIntake('chicken', 230);
    expect(fit.totalsFor(today).protein,
        closeTo(fit.plannedTotals.protein, 0.01));
  });

  test('grocery list defaults to one week', () {
    final fit = fresh();
    final rows = fit.groceryList();
    final chicken = rows.firstWhere((r) => r.food.id == 'chicken');
    expect(chicken.grams, closeTo(1610, 1)); // 230 g/day × 7
    final milk = rows.firstWhere((r) => r.food.id == 'milk');
    expect(milk.grams, closeTo(5250, 1)); // 750 ml/day × 7
    expect(fit.groceryList(days: 14)
        .firstWhere((r) => r.food.id == 'chicken').grams, closeTo(3220, 1));
  });

  test('14-day moving average and protocol §8 bands', () {
    final fit = fresh();
    final today = DateTime(2026, 10, 25);
    // 14 days at 60.0 → average 60.0
    for (var i = 13; i >= 0; i--) {
      fit.bodyweight.add(
          BodyweightEntry(today.subtract(Duration(days: i)), 60.0));
    }
    expect(fit.movingAverage14(today: today), closeTo(60.0, 0.01));
    expect(fit.weightTrendBand(previousAvg: 60.0, today: today), 'recomp');
    // Previous average 60.8 → down 0.8 → cut-too-hard
    expect(fit.weightTrendBand(previousAvg: 60.8, today: today), 'cut-too-hard');
    // Previous average 59.2 → up 0.8 → gaining
    expect(fit.weightTrendBand(previousAvg: 59.2, today: today), 'gaining');
    // Fewer than 14 logged days → unknown
    final fit2 = fresh();
    expect(fit2.movingAverage14(today: today), isNull);
  });

  test('nutrition survives a JSON round-trip', () {
    final fit = fresh();
    fit.setPlannedGrams('b', 'oats', 45);
    final json = fit.toJson();
    final fit2 = FitState();
    fit2.applyBackup(json);
    expect(fit2.plannedTotals.kcal, closeTo(fit.plannedTotals.kcal, 0.01));
    final oats = fit2.mealSlots
        .firstWhere((s) => s.id == 'b')
        .items
        .firstWhere((i) => i.foodId == 'oats');
    expect(oats.grams, 45);
  });
}
