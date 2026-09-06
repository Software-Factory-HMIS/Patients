/// Shared lab-order grouping for screens and PDF (package vs standalone test).
class LabOrderPresenter {
  static bool isPackage(dynamic lab) {
    final type = (lab['type'] ?? '').toString();
    return type == 'package' ||
        type == 'package_test' ||
        lab['packageId'] != null;
  }

  static bool hasResult(dynamic lab) {
    final resultId = lab['resultId'];
    final resultValue = lab['resultValue'];
    return resultId != null ||
        (resultValue != null && resultValue.toString().isNotEmpty);
  }

  static List<String> pendingLabels(List<dynamic> labOrders) {
    final seen = <String>{};
    final labels = <String>[];
    for (final lab in labOrders) {
      if (isPackage(lab)) {
        final pkgName = (lab['packageName'] ?? 'N/A').toString().trim();
        final key = 'pkg_${lab['packageId'] ?? pkgName}_${lab['orderId'] ?? ''}';
        if (seen.add(key)) {
          labels.add('$pkgName (Package)');
        }
      } else {
        final name = (lab['testName'] ?? lab['packageName'] ?? 'N/A').toString();
        final key = 'test_${lab['testId'] ?? name}_${lab['orderId'] ?? ''}';
        if (seen.add(key)) {
          labels.add('$name (Test)');
        }
      }
    }
    return labels;
  }

  static List<MapEntry<String, List<dynamic>>> groupResultsByPackage(
    List<dynamic> results,
  ) {
    final groups = <String, List<dynamic>>{};
    final order = <String>[];
    for (final lab in results) {
      final key = isPackage(lab)
          ? 'pkg_${lab['packageId'] ?? lab['packageName']}_${lab['orderId'] ?? ''}'
          : 'standalone';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(lab);
    }
    return [
      for (final key in order)
        MapEntry(
          key == 'standalone'
              ? (groups[key]!.length > 1 ? 'Tests' : '')
              : (groups[key]!.first['packageName'] ?? 'Package').toString(),
          groups[key]!,
        ),
    ];
  }

  static String dedupeKey(Map<String, dynamic> m) {
    final resultId = m['resultId'] ?? m['resultID'] ?? m['ResultID'];
    if (resultId != null && resultId.toString().isNotEmpty) {
      return 'rid:$resultId';
    }
    final test = (m['testName'] ?? m['test'] ?? m['Test'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final date = (m['encounterDate'] ??
            m['date'] ??
            m['Date'] ??
            m['sampleDate'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final result = (m['resultValue'] ??
            m['result'] ??
            m['Result'] ??
            m['resultNumeric'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    return 't:$test|d:$date|r:$result';
  }

  static int countPackagesAndStandalone(List<dynamic> labOrdersRaw) {
    final packageKeys = <String>{};
    var standalone = 0;
    for (final order in labOrdersRaw) {
      final packageId = order['packageId'];
      if (packageId != null) {
        packageKeys.add('package_${packageId}_${order['orderId'] ?? ''}');
      } else {
        standalone++;
      }
    }
    return packageKeys.length + standalone;
  }
}
