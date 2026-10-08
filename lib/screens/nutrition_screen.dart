import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/nutrition.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Offline nutrition: Today (intake vs targets), Plan (edit the four slots),
/// Trend (14-day weight average and the protocol's adjustment bands) and
/// Grocery (the plan scaled to one week, shareable as text).
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _tab = 0;

  List<String> get _tabs =>
      [t.today, t.nutritionPlan, t.nutritionTrend, t.nutritionGrocery];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: ScreenHeader(
              title: t.nutrition,
              subtitle: _tabs[_tab],
              onBack: fit.backFromNutrition,
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _TabChip(
                label: _tabs[i],
                active: i == _tab,
                onTap: () => setState(() => _tab = i),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: switch (_tab) {
                0 => const _TodayTab(),
                1 => const _PlanTab(),
                2 => const _TrendTab(),
                _ => const _GroceryTab(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? gc.text : gc.bgRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? gc.text : gc.border),
        ),
        child: Text(
          label,
          style: AppTheme.f(13, color: active ? gc.bg : gc.textSecondary),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final frac = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: AppTheme.f(12, color: gc.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 8,
                backgroundColor: gc.bgRaised2,
                valueColor: AlwaysStoppedAnimation(
                    frac >= 0.95 ? gc.sage : gc.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              '${value.round()} / ${target.round()} g',
              textAlign: TextAlign.end,
              style: AppTheme.f(12, color: gc.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.logged});

  final MealSlot slot;

  /// true: the steppers edit today's intake. false: they edit the plan itself.
  final bool logged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final totals = fit.slotTotals(slot.id);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(slot.name,
                    style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
              ),
              Text(
                '${totals.kcal.round()} kcal · P ${totals.protein.round()} g',
                style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in slot.items)
            _FoodRow(slotId: slot.id, item: item, logged: logged),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.slotId,
    required this.item,
    required this.logged,
  });

  final String slotId;
  final PlannedItem item;
  final bool logged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final food = fit.foodById(item.foodId);
    if (food == null) return const SizedBox.shrink();
    final todayGrams = logged
        ? (fit.gramsFor(DateTime.now())[item.foodId] ?? item.grams)
        : item.grams;
    final step = food.liquid ? 25.0 : (todayGrams >= 100 ? 10.0 : 5.0);

    void change(double delta) {
      final next = todayGrams + delta;
      if (logged) {
        fit.setIntake(item.foodId, next);
      } else {
        fit.setPlannedGrams(slotId, item.foodId, next);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(food.name,
                style: AppTheme.f(14, weight: FontWeight.w500, color: gc.text)),
          ),
          StepperControl(
            value: '${todayGrams.round()} ${food.unit}',
            minWidth: 74,
            btnSize: 26,
            fontSize: 14,
            onDec: () => change(-step),
            onInc: () => change(step),
          ),
        ],
      ),
    );
  }
}

// --- Today -------------------------------------------------------------------

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final totals = fit.todayTotals;
    final targets = fit.macroTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      _Section(
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${totals.kcal.round()}',
                      style: AppTheme.f(34, weight: FontWeight.w800, color: gc.text)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 6),
                    child: Text('/ ${targets.kcal.round()} kcal',
                        style: AppTheme.f(14, weight: FontWeight.w500, color: gc.textSecondary)),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Atwater ${totals.atwater.round()}',
                        style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MacroBar(label: 'P', value: totals.protein, target: targets.protein),
              _MacroBar(label: 'C', value: totals.carbs, target: targets.carbs),
              _MacroBar(label: 'F', value: totals.fat, target: targets.fat),
              _MacroBar(
                  label: t.nutritionFibre,
                  value: totals.fibre,
                  target: targets.fibre),
            ],
          ),
        ),
      ),
        for (final slot in fit.mealSlots)
          _Section(child: _SlotCard(slot: slot, logged: true)),
      ],
    );
  }
}

// --- Plan --------------------------------------------------------------------

class _PlanTab extends StatelessWidget {
  const _PlanTab();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final planned = fit.plannedTotals;
    final targets = fit.macroTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      _Section(
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Planned day: ${planned.kcal.round()} kcal · P ${planned.protein.round()} · '
            'C ${planned.carbs.round()} · F ${planned.fat.round()} · '
            '${t.nutritionFibre} ${planned.fibre.round()} g\n${t.nutritionPlanNote}',
            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary),
          ),
        ),
      ),
      for (final slot in fit.mealSlots)
        _Section(child: _SlotCard(slot: slot, logged: false)),
      _Section(
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.nutritionMacroTargets,
                  style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 8),
              Text(
                'kcal ${targets.kcal.round()} · P ${targets.protein.round()} · '
                'C ${targets.carbs.round()} · F ${targets.fat.round()} · '
                '${t.nutritionFibre} ${targets.fibre.round()}',
                style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary),
              ),
              const SizedBox(height: 12),
              GhostButton(
                icon: PhosphorIconsRegular.chartLineUp,
                label: t.nutritionSwitchFallback,
                onTap: () => fit.setTargets(targets.kcal < 1850
                    ? targets.copyWith(kcal: 1900, protein: 132)
                    : targets.copyWith(kcal: 1800, protein: 128)),
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Trend -------------------------------------------------------------------

class _TrendTab extends StatefulWidget {
  const _TrendTab();

  @override
  State<_TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<_TrendTab> {
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  String _bandMessage(String band) => switch (band) {
        'recomp' => t.nutritionBandRecomp,
        'cut-too-hard' => t.nutritionBandCut,
        'gaining' => t.nutritionBandGain,
        _ => t.nutritionBandUnknown,
      };

  void _log() {
    final kg = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    if (kg == null || kg < 20 || kg > 400) return;
    fit.addBodyweight(kg);
    _kg.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final avg = fit.movingAverage14();
    final logged = fit.daysLoggedInWindow;
    final previous = fit.previousAverage14();
    final band = previous == null
        ? 'unknown'
        : fit.weightTrendBand(previousAvg: previous);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      _Section(
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.nutritionAvg14,
                  style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 8),
              Text(
                avg == null
                    ? t.nutritionNeedDays('${14 - logged}')
                    : '${avg.toStringAsFixed(2)} kg',
                style: AppTheme.f(avg == null ? 15 : 28,
                    weight: FontWeight.w800,
                    color: avg == null ? gc.textSecondary : gc.text),
              ),
              const SizedBox(height: 8),
              Text(_bandMessage(band),
                  style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
            ],
          ),
        ),
      ),
      _Section(
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kg,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: AppTheme.f(16, color: gc.text),
                  decoration: InputDecoration(
                    hintText: t.nutritionWeighHint,
                    hintStyle: AppTheme.f(14, weight: FontWeight.w500, color: gc.textTertiary),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: gc.bgRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gc.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gc.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GhostButton(
                icon: PhosphorIconsRegular.plus,
                label: t.nutritionLog,
                onTap: _log,
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Grocery -----------------------------------------------------------------

class _GroceryTab extends StatelessWidget {
  const _GroceryTab();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final rows = fit.groceryList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      _Section(
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.nutritionGroceryTitle,
                  style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 10),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.food.name,
                            style: AppTheme.f(14, weight: FontWeight.w500, color: gc.text)),
                      ),
                      Text(
                        '${r.grams.round()} ${r.food.unit}',
                        style: AppTheme.f(14, weight: FontWeight.w600, color: gc.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      _Section(
        child: GhostButton(
          icon: PhosphorIconsRegular.shareNetwork,
          label: t.share,
              onTap: () =>
                  SharePlus.instance.share(ShareParams(text: fit.groceryText())),
            ),
          ),
      ],
    );
  }
}
