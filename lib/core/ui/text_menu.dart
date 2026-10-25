// Menu chọn chữ an toàn cho app trẻ em: chỉ Cắt / Sao chép / Dán / Chọn tất cả.
// Mặc định Flutter thêm "Tra cứu" (Look Up), "Tìm trên web" (Search Web), "Chia sẻ…" (Share) trên iOS, Live Text, và trên
// Android các mục "process text" (Dịch, ...) của app khác — bấm vào là mở app/trình duyệt khác KHÔNG qua khoá bố mẹ
// (App Store Guideline 1.3, Google Families). Trên iOS Flutter còn có thể dùng menu hệ thống (SystemContextMenu), không lọc
// được mục nào — builder này luôn vẽ menu của Flutter nên không bao giờ dùng menu hệ thống.
// Mọi TextField / SelectableText trong app phải truyền `contextMenuBuilder: safeContextMenuBuilder`
// (test/core/text_menu_test.dart quét lib/ để chắc chắn).
import 'package:flutter/material.dart';

/// Các nút được giữ lại trong menu chọn chữ.
const Set<ContextMenuButtonType> kSafeContextMenuTypes = {
  ContextMenuButtonType.cut,
  ContextMenuButtonType.copy,
  ContextMenuButtonType.paste,
  ContextMenuButtonType.selectAll,
};

/// Lọc danh sách nút: chỉ giữ cắt/chép/dán/chọn tất cả (bỏ Look Up, Search Web, Share, Live Text, process text...).
List<ContextMenuButtonItem> safeContextMenuItems(Iterable<ContextMenuButtonItem> items) =>
    [for (final b in items) if (kSafeContextMenuTypes.contains(b.type)) b];

/// `contextMenuBuilder` cho TextField / SelectableText: menu Flutter (không phải menu hệ thống iOS) với các nút an toàn.
Widget safeContextMenuBuilder(BuildContext context, EditableTextState state) {
  final items = safeContextMenuItems(state.contextMenuButtonItems);
  if (items.isEmpty) return const SizedBox.shrink();
  return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
}
