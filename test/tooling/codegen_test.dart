import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'codegen_test.freezed.dart';
part 'codegen_test.g.dart';

/// Guards the Sprint 06 code-generation configuration.
///
/// Every model in the application is `freezed` + `json_serializable`
/// (docs/CODING_STANDARDS.md §6) and every DTO maps to snake_case Postgres
/// columns (§11). Those two facts are settings in `build.yaml`, and a silent
/// change to them would surface much later as a field arriving null from
/// Supabase. These models exist only to assert the pipeline's behaviour.
@freezed
abstract class CodegenProbeUnit with _$CodegenProbeUnit {
  const factory CodegenProbeUnit({required String unitLabel}) =
      _CodegenProbeUnit;

  factory CodegenProbeUnit.fromJson(Map<String, dynamic> json) =>
      _$CodegenProbeUnitFromJson(json);
}

@freezed
abstract class CodegenProbe with _$CodegenProbe {
  const factory CodegenProbe({
    required String mealName,
    required int estimatedCost,
    required CodegenProbeUnit servingUnit,
  }) = _CodegenProbe;

  factory CodegenProbe.fromJson(Map<String, dynamic> json) =>
      _$CodegenProbeFromJson(json);
}

void main() {
  const CodegenProbe probe = CodegenProbe(
    mealName: 'Chicken Adobo',
    estimatedCost: 180,
    servingUnit: CodegenProbeUnit(unitLabel: 'serving'),
  );

  group('code generation contract', () {
    test('freezed generates value equality', () {
      expect(
        probe,
        const CodegenProbe(
          mealName: 'Chicken Adobo',
          estimatedCost: 180,
          servingUnit: CodegenProbeUnit(unitLabel: 'serving'),
        ),
      );
    });

    test('freezed generates copyWith', () {
      final CodegenProbe repriced = probe.copyWith(estimatedCost: 220);

      expect(repriced.estimatedCost, 220);
      expect(repriced.mealName, probe.mealName);
      expect(repriced, isNot(probe));
    });

    test('json keys are renamed to snake_case', () {
      expect(
        probe.toJson().keys,
        containsAll(<String>['meal_name', 'estimated_cost', 'serving_unit']),
      );
    });

    test('nested models serialize through their own toJson', () {
      expect(probe.toJson()['serving_unit'], <String, dynamic>{
        'unit_label': 'serving',
      });
    });

    test('models round-trip through json', () {
      expect(CodegenProbe.fromJson(probe.toJson()), probe);
    });

    test('a malformed payload names the offending field', () {
      Object? thrown;
      try {
        CodegenProbe.fromJson(<String, dynamic>{
          'meal_name': 'Chicken Adobo',
          'estimated_cost': 'not-a-number',
          'serving_unit': <String, dynamic>{'unit_label': 'serving'},
        });
      } on Object catch (error) {
        thrown = error;
      }

      expect(thrown, isA<CheckedFromJsonException>());
      expect((thrown! as CheckedFromJsonException).key, 'estimated_cost');
    });
  });
}
