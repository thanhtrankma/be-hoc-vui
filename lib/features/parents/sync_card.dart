// Thẻ "📱 Dùng trên nhiều máy" của Góc bố mẹ (syncCard() của app.js): tạo / nhập mã gia đình, đồng bộ ngay, ngắt, xoá bản trên máy chủ.
// CHỦ: agent I.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/sync/firebase_setup.dart';
import 'package:be_vui_hoc/features/sync/sync.dart';

import 'settings.dart';

/// Thông báo kết quả (msg() của web).
String syncMessage(SyncResult r) => r == 'ok'
    ? '✔ Đã đồng bộ'
    : r == 'notfound'
        ? 'Không tìm thấy mã này'
        : r == 'bad'
            ? 'Mã gồm 16 chữ và số'
            : 'Chưa kết nối được, thử lại sau';

/// '15/10 14:05' (toLocaleString vi-VN: giờ:phút ngày/tháng).
String fmtSyncTime(int ms) {
  if (ms == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}';
}

class SyncCard extends ConsumerStatefulWidget {
  const SyncCard({super.key});
  @override
  ConsumerState<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<SyncCard> {
  bool _show = false;
  bool _working = false;

  Future<void> _run(Future<SyncResult> Function() job, {bool toastIt = true}) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final r = await job();
      if (toastIt) toast(syncMessage(r));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncServiceProvider);
    if (!sync.supported || !RemoteFlags.syncEnabled) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: sync.changes,
      builder: (context, _, _) {
        final c = sync.code;
        final err = sync.lastErr;
        return ParentsSection(
          key: const Key('sync-card'),
          title: '📱 Dùng trên nhiều máy',
          children: c != null
              ? [
                  const LeftNote('Máy này đang đồng bộ. Nhập mã gia đình trên máy khác (điện thoại, iPad) để bé học tiếp đúng chỗ.'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SelectableText(
                      _show ? c : '••••-••••-••••-${c.substring(c.length - 4)}',
                      key: const Key('sync-code'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.5, fontFamily: kFontFamily),
                    ),
                    SmallBtn(key: const Key('sync-show'), label: '👁 Hiện mã', onTap: () => setState(() => _show = true)),
                  ]),
                  LeftNote(
                      'Lần đồng bộ gần nhất: ${fmtSyncTime(sync.lastAt)}${err != null ? ' · lần cuối lỗi (${err == 'offline' ? 'mất mạng' : 'máy chủ'})' : ''}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    SmallBtn(key: const Key('sync-now'), label: _working ? '⏳ Đang đồng bộ…' : '🔄 Đồng bộ ngay', onTap: () => _run(sync.syncNow)),
                    SmallBtn(
                      key: const Key('sync-leave'),
                      label: 'Ngắt máy này',
                      onTap: () async {
                        if (await confirmPanel('Ngắt máy này khỏi mã gia đình? Dữ liệu trên máy này vẫn giữ.', context: context)) {
                          await sync.leave();
                        }
                      },
                    ),
                    SmallBtn(
                      key: const Key('sync-wipe'),
                      label: 'Xoá bản trên máy chủ',
                      danger: true,
                      onTap: () async {
                        if (await confirmPanel(
                            'Xoá bản đồng bộ trên máy chủ? Các máy khác sẽ không nhận dữ liệu mới nữa (dữ liệu trên từng máy vẫn giữ).',
                            context: context)) {
                          await sync.leave(wipeServer: true);
                        }
                      },
                    ),
                  ]),
                ]
              : [
                  const LeftNote(
                      'Bé học trên nhiều máy? Bật đồng bộ để sao, bài đã học, đồ trong game đi theo bé. Không cần email hay mật khẩu: app tạo một mã gia đình 16 ký tự. Dữ liệu được mã hoá ngay trên máy bằng mã này rồi mới gửi lên máy chủ datpilot.com, nên máy chủ không đọc được. Giữ mã như giữ chìa khoá nhà.'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    SmallBtn(key: const Key('sync-create'), label: _working ? '⏳ …' : '✨ Tạo mã gia đình', onTap: () => _run(sync.create)),
                    SmallBtn(
                      key: const Key('sync-join'),
                      label: '🔑 Nhập mã từ máy khác',
                      onTap: () async {
                        final v = await promptPanel(context,
                            title: 'Nhập mã gia đình (16 chữ và số, lấy ở Góc bố mẹ trên máy đã bật đồng bộ):', maxLength: 24);
                        if (v == null || v.trim().isEmpty) return;
                        await _run(() async {
                          final r = await sync.join(v);
                          final store = ref.read(storeProvider);
                          if (r == 'ok' && store.profile == null && store.profiles.isNotEmpty) store.setActive(store.profiles.first.id);
                          return r;
                        });
                      },
                    ),
                  ]),
                ],
        );
      },
    );
  }
}
