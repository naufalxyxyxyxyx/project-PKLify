import 'package:flutter/material.dart';

/// Describes rows without creating a widget for every stored record.
class LazySection {
  const LazySection(this.count, this.builder);
  final int count;
  final IndexedWidgetBuilder builder;

  factory LazySection.single(Widget child) => LazySection(1, (_, _) => child);
}

class LazySections extends StatelessWidget {
  const LazySections({super.key, required this.sections, this.storageKey});
  final List<LazySection> sections;
  final String? storageKey;

  @override
  Widget build(BuildContext context) {
    final ends = <int>[];
    var count = 0;
    for (final section in sections) {
      count += section.count;
      ends.add(count);
    }
    return ListView.builder(
      key: storageKey == null ? null : PageStorageKey(storageKey),
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        for (var i = 0; i < sections.length; i++) {
          if (index < ends[i]) {
            return sections[i].builder(
              context,
              index - (i == 0 ? 0 : ends[i - 1]),
            );
          }
        }
        throw RangeError.index(index, sections);
      },
    );
  }
}
