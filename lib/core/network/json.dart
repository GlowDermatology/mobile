/// Small, forgiving readers for API JSON. The contract never omits keys (nulls
/// are explicit), but the app must not crash if a field is added or renamed.
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Json> asJsonList(Object? v) => v is List
    ? v
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.cast<String, dynamic>())
          .toList()
    : const [];
int asInt(Object? v, [int fallback = 0]) => v is int
    ? v
    : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback);
int? asIntOrNull(Object? v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));
String asString(Object? v, [String fallback = '']) =>
    v == null ? fallback : '$v';
String? asStringOrNull(Object? v) => v == null ? null : '$v';
bool asBool(Object? v) => v == true;
double? asDoubleOrNull(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
List<String> asStringList(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];
