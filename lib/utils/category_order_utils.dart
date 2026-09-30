enum CategoryOrderSection { liveTv, movies, tvShows }

extension CategoryOrderSectionKey on CategoryOrderSection {
  String get prefsKey {
    switch (this) {
      case CategoryOrderSection.liveTv:
        return 'category_order_live_tv';
      case CategoryOrderSection.movies:
        return 'category_order_movies';
      case CategoryOrderSection.tvShows:
        return 'category_order_tv_shows';
    }
  }
}

class CategoryOrderItem {
  final String id;
  final String label;

  const CategoryOrderItem({required this.id, required this.label});
}

/// Applies a saved order: known ids first, then any new ids in [defaultOrder].
List<String> applySavedCategoryOrder(
  List<String> defaultOrder,
  List<String> savedOrder,
) {
  if (savedOrder.isEmpty) return List<String>.from(defaultOrder);

  final result = <String>[];
  final remaining = defaultOrder.toSet();

  for (final id in savedOrder) {
    if (remaining.remove(id)) {
      result.add(id);
    }
  }

  for (final id in defaultOrder) {
    if (remaining.contains(id)) {
      result.add(id);
    }
  }

  return result;
}

List<CategoryOrderItem> orderItems(
  List<CategoryOrderItem> items,
  List<String> savedOrder,
) {
  final orderedIds = applySavedCategoryOrder(
    items.map((e) => e.id).toList(),
    savedOrder,
  );
  final byId = {for (final item in items) item.id: item};
  return orderedIds.map((id) => byId[id]).whereType<CategoryOrderItem>().toList();
}
