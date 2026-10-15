// Quét tràn bố cục trên máy hẹp (Android 320/360dp) và điện thoại xoay ngang: dựng MỌI màn/route, mọi kiểu bài của
// mọi đảo, Khu vui chơi + màn bắt đầu của từng game (cửa hàng, kho vũ khí, ga-ra, chọn chế độ), RPG, phòng/thú cưng/
// thi tài/lớp 1/album, góc bố mẹ/báo cáo/cài đặt/bằng khen và bảng thưởng — ở 320×640, 360×780 và 780×360,
// cỡ chữ 1.0 (và 1.3 cho các màn chính). Lỗi nào (kể cả RenderFlex overflow) cũng làm test hỏng, kèm widget gây lỗi.
import 'dart:io';

import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';
import 'package:be_vui_hoc/core/game/registry.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/fun/action/act_core.dart';
import 'package:be_vui_hoc/features/fun/action/funracer.dart';
import 'package:be_vui_hoc/features/fun/action/funshooter.dart';
import 'package:be_vui_hoc/features/fun/action/funtank.dart';
import 'package:be_vui_hoc/features/rpg/rpgcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/fun_action/helpers.dart';

const kSizes = [Size(320, 640), Size(360, 780), Size(780, 360)];

late ContentBundle bundle;

/// Gom lỗi của Flutter (FlutterError.onError) trong thân test, kèm vị trí widget gây lỗi trong lib/.
class Sweep {
  Sweep(this.tester);
  final WidgetTester tester;
  final List<String> problems = [];
  String where = '';
  void Function(FlutterErrorDetails)? _old;

  void install() {
    _old = FlutterError.onError;
    FlutterError.onError = (d) => _add(d.exception, d.toString());
  }

  void uninstall() => FlutterError.onError = _old;

  void _add(Object e, String full) {
    final first = e.toString().split('\n').first;
    final locs = RegExp(r'(lib|test)/[\w/]+\.dart:\d+(:\d+)?').allMatches(full).map((m) => m[0]).toSet().take(4).join(', ');
    final msg = '[$where] $first${locs.isEmpty ? '' : ' @ $locs'}';
    if (!problems.contains(msg)) {
      problems.add(msg);
      debugPrint('SWEEP $msg');
    }
  }

  /// Lỗi bắt bởi khung test (không qua FlutterError.onError).
  void check() {
    final e = tester.takeException();
    if (e != null) _add(e, e.toString());
  }

  /// Chạy một bước; lỗi được ghi lại, không dừng cả lượt quét.
  Future<void> step(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      _add(e, '$e\n$st');
    }
    check();
  }

  Future<void> run(Future<void> Function() body) async {
    install();
    try {
      await body();
    } catch (e, st) {
      _add(e, '$e\n$st');
    } finally {
      uninstall();
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }
}

class App {
  App(this.store, this.audio, this.container);
  final AppStore store;
  final SilentAudio audio;
  final ProviderContainer container;
  GoRouter get router => container.read(routerProvider);
}

/// Bé có sẵn tiến độ: vài sao, nhiều vé, thú cưng, mốc tiến bộ (cho báo cáo/bằng khen).
void richProfile(AppStore store, {bool pet = true}) {
  final p = store.addProfile('Bảo Ngọc', 'robot');
  store.updateProfile(p.id, {'tier': 2});
  p.json['tickets'] = 9999;
  p.json['stars'] = 9;
  if (pet) {
    p.json['pet'] = <String, dynamic>{
      'type': 'dog', 'name': 'Cún Bông', 'xp': 40, 'food': 70, 'water': 70, 'clean': 80, 'happy': 80, 'energy': 90,
      'last': store.now().millisecondsSinceEpoch, 'wear': <String, dynamic>{},
    };
  }
  for (final k in const ['letters:b', 'vnwords:bò', 'tone:sắc', 'twoWords:t0', 'sentences:s0', 'ruleWords:r0', 'addFacts:0,1', 'en_animals:cat']) {
    store.recordAnswer('x', [k], false, const []);
  }
  final l = store.learn(p);
  l['since'] = store.today();
  l['ms'] = ['w10', 'm20', 'i:count:2'];
  l['msAt'] = {'w10': store.today(), 'm20': store.today(), 'i:count:2': store.today()};
  store.save();
}

Future<App> pumpApp(WidgetTester tester, Size size, {double scale = 1, void Function(AppStore s)? prep, bool parentFun = false}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final store = AppStore((await tester.runAsync(SharedPreferences.getInstance))!);
  (prep ?? richProfile)(store);
  final audio = SilentAudio(voice: bundle.voice, store: store);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentBundleProvider.overrideWithValue(bundle),
      storeProvider.overrideWith((ref) => store),
      audioProvider.overrideWithValue(audio),
      startedProvider.overrideWith((ref) => true),
      parentFunProvider.overrideWith((ref) => parentFun),
    ],
    child: const BeVuiHocApp(),
  ));
  await tester.pump();
  final container = ProviderScope.containerOf(tester.element(find.byType(BeVuiHocApp)));
  return App(store, audio, container);
}

/// Cho thời gian chạy (giả) + nạp ảnh thật (ngoài fake async).
Future<void> settle(WidgetTester tester, {int ms = 2000}) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    if (t == 300) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 6));
}

Future<void> visit(Sweep s, App app, String path, {int ms = 2000}) async {
  s.where = '$path ${s.tester.view.physicalSize / 3} x${s.tester.platformDispatcher.textScaleFactor}';
  await s.step(() async {
    app.router.go(path);
    await settle(s.tester, ms: ms);
  });
}

/// Bấm một nút (nếu có) rồi chờ.
Future<bool> tapIf(Sweep s, Finder f, {String? label, int ms = 1500}) async {
  if (f.evaluate().isEmpty) return false;
  // Nút nằm dưới màn (trang cuộn): cuộn tới trước khi bấm.
  await s.step(() async {
    await s.tester.ensureVisible(f.first);
    await s.tester.pump(const Duration(milliseconds: 100));
  });
  final hit = f.hitTestable();
  if (hit.evaluate().isEmpty) return false;
  if (label != null) s.where = '${s.where.split(' » ').first} » $label';
  await s.step(() async {
    await s.tester.tap(hit.first, warnIfMissed: false);
    await settle(s.tester, ms: ms);
  });
  return true;
}

/// Chờ game nạp hình xong (vòng xoay tải): giải mã ảnh thật ngoài fake async.
Future<void> waitLoaded(WidgetTester tester) async {
  for (var k = 0; k < 80 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; k++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Đóng panel đang mở (Back của Android).
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, ms: 600);
}

/// Các bài khác kiểu nhau của một đảo (kind + tập khoá của JSON bài). SWEEP_ALL=1: mọi bài (chạy lâu, ~10 phút).
List<int> distinctLevels(Island isl) {
  if (Platform.environment['SWEEP_ALL'] == '1') return [for (final l in levelsOf(isl, bundle.content)) l.i];
  final seen = <String>{};
  final out = <int>[];
  for (final l in levelsOf(isl, bundle.content)) {
    final keys = l.json.keys.where((k) => !const {'name', 'tier', 'img', 'hide'}.contains(k)).toList()..sort();
    if (seen.add('${l.json['kind']}|${keys.join(',')}')) out.add(l.i);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
    rpgArtLoader = (imgs, sheets) async => RpgArt.empty();
    // Hình của game hành động nạp sẵn ở zone thật (bộ đệm hình của core giữ Future toàn cục).
    final ctx = FakeFun().ctx;
    await Gfx.load(
      [...racerImgs(ctx), for (final m in bundle.data.mascots) m.img, ...kShooterImgs, ...kTankImgs],
      ['racing/racing', 'fxa/fx', 'toon/robot', 'space/space', 'tanks/tanks'],
    );
  });

  Future<void> sweepSizes(WidgetTester tester, Future<void> Function(Sweep s, App app) body,
      {List<double> scales = const [1], void Function(AppStore s)? prep, bool parentFun = false}) async {
    final s = Sweep(tester);
    await s.run(() async {
      for (final scale in scales) {
        for (final size in kSizes) {
          final app = await pumpApp(tester, size, scale: scale, prep: prep, parentFun: parentFun);
          s.where = '$size x$scale';
          await body(s, app);
          await unmount(tester);
          s.check();
        }
      }
    });
  }

  testWidgets('màn chính (cỡ chữ 1.0 và 1.3)', (tester) async {
    await sweepSizes(tester, scales: const [1, 1.3], (s, app) async {
      await visit(s, app, '/');
      await visit(s, app, '/map');
      for (final isl in bundle.data.islands.where((i) => i.route == null && !i.soon)) {
        await visit(s, app, '/island/${isl.id}', ms: 800);
      }
      for (final p in ['/buddies', '/room', '/pet', '/album', '/duel', '/lop1', '/fun', '/rpg', '/parent', '/report/${app.store.profile!.id}']) {
        await visit(s, app, p);
      }
      for (final k in const ['letters:b', 'vnwords:bò', 'tone:sắc', 'twoWords:t0', 'sentences:s0', 'ruleWords:r0', 'addFacts:0,1', 'en_animals:cat']) {
        await visit(s, app, '/review/x/${Uri.encodeComponent(k)}', ms: 2500);
      }
      await visit(s, app, '/new');
      await s.step(() async {
        await tester.enterText(find.byKey(const Key('name-input')), 'Bảo Ngọc Anh');
        await settle(tester, ms: 300);
      });
      await tapIf(s, find.byKey(const Key('name-next')), label: 'new step 2');
      app.store.addProfile('Minh Khôi', 'superhero');
      await visit(s, app, '/kids');
    });
  });

  testWidgets('màn nghỉ (hết giờ) và thú cưng chưa nhận nuôi', (tester) async {
    await sweepSizes(tester, scales: const [1, 1.3], prep: (st) {
      richProfile(st, pet: false);
      st.setSetting('limit', 15);
      st.addUsage(3600);
    }, (s, app) async {
      await visit(s, app, '/rest');
      app.store.setSetting('limit', 0);
      await visit(s, app, '/pet');
      await tapIf(s, find.byKey(const Key('adopt-dog')), label: 'adopt dog');
    });
  });

  for (final islId in const ['letters', 'spell', 'trace', 'read', 'count', 'math', 'life', 'english', 'memory', 'logic', 'code', 'arcade', 'music', 'art', 'explore']) {
    testWidgets('bài các kiểu: đảo $islId', (tester) async {
      final isl = bundle.data.island(islId)!;
      await sweepSizes(tester, (s, app) async {
        for (final li in distinctLevels(isl)) {
          await visit(s, app, '/play/$islId/$li', ms: 3000);
        }
      });
    });
  }

  testWidgets('bảng hỏi: chọn cấp, khoá bố mẹ, đổi tên, xoá bé', (tester) async {
    Finder prefix(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(p));
    await sweepSizes(tester, scales: const [1, 1.3], prep: (st) {
      richProfile(st);
      st.profile!.json.remove('tier');
      st.save();
    }, (s, app) async {
      await visit(s, app, '/map');
      await tapIf(s, find.byKey(const Key('tier-2')), label: 'pick tier');
      await tapIf(s, find.byKey(const Key('parent-btn')), label: 'parent gate');
      await back(tester);
      await visit(s, app, '/parent');
      await tapIf(s, prefix('rename-'), label: 'rename');
      await back(tester);
      await tapIf(s, prefix('remove-'), label: 'remove');
      await back(tester);
    });
  });

  testWidgets('bảng thưởng, ăn mừng mốc, bằng khen', (tester) async {
    debugGameOverrides['count'] = const PlaceholderGame('count', owner: 'test', webFile: 'count.js');
    addTearDown(() => debugGameOverrides.remove('count'));
    await sweepSizes(tester, scales: const [1, 1.3], (s, app) async {
      await visit(s, app, '/play/count/0');
      await tapIf(s, find.byKey(const Key('placeholder-finish')), label: 'result panel', ms: 4000);
      await back(tester);
      // Báo cáo → bằng khen
      await visit(s, app, '/report/${app.store.profile!.id}');
      final ms = find.byKey(const ValueKey('ms-w10'));
      if (ms.evaluate().isNotEmpty) await tester.ensureVisible(ms);
      await tapIf(s, ms, label: 'certificate', ms: 2500);
      await back(tester);
    });
  });

  testWidgets('Khu vui chơi: kết quả game', (tester) async {
    debugFunOverrides['racer'] = const PlaceholderFunGame('racer', owner: 'test', webFile: 'funracer.js');
    addTearDown(() => debugFunOverrides.remove('racer'));
    await sweepSizes(tester, scales: const [1, 1.3], (s, app) async {
      await visit(s, app, '/fun/racer');
      for (var k = 0; k < 3; k++) {
        await tapIf(s, find.text('Thắng (thử)'), label: 'fun result $k');
      }
    });
  });

  testWidgets('Khu vui chơi: màn bắt đầu của mọi game', (tester) async {
    await sweepSizes(tester, (s, app) async {
      await visit(s, app, '/fun');
      for (final g in kFunGames) {
        await visit(s, app, '/fun/${g.id}', ms: 1500);
        expect(find.byKey(const Key('fun-quit')), findsOneWidget, reason: g.id);
        await s.step(() async {
          await waitLoaded(tester);
          await settle(tester, ms: 500);
        });
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: '${g.id} còn đang tải');
        // Màn bắt đầu (cửa hàng/kho/ga-ra/chọn chế độ) → vào chơi: HUD của game.
        for (final k in const ['shop-play', 'hero-play', 'hunt-play', 'vs-bot', 'arcade-balloon']) {
          if (await tapIf(s, find.byKey(Key(k)), label: k, ms: 2000)) break;
        }
        await visit(s, app, '/fun', ms: 300);
      }
    });
  });

  testWidgets('RPG: làng, cửa hàng, đồng đội, vùng, màn', (tester) async {
    await sweepSizes(tester, scales: const [1, 1.3], (s, app) async {
      await visit(s, app, '/rpg');
      await tapIf(s, find.byKey(const Key('rpg-shop')), label: 'shop');
      await back(tester);
      await tapIf(s, find.byKey(const Key('rpg-pets')), label: 'pets');
      await back(tester);
      await tapIf(s, find.byKey(const Key('rpg-zone-0')), label: 'zone 0');
      await back(tester);
      await visit(s, app, '/rpg/0/0', ms: 2500);
    });
  });

  testWidgets('phòng, thú cưng, thi tài, lớp 1, góc bố mẹ: thao tác', (tester) async {
    await sweepSizes(tester, scales: const [1, 1.3], (s, app) async {
      await visit(s, app, '/duel');
      final topic = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('duel-topic-'));
      await tapIf(s, topic, label: 'duel topic', ms: 3000);
      await visit(s, app, '/lop1');
      final act = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('cls-card-'));
      await tapIf(s, act, label: 'lop1 card');
      await visit(s, app, '/parent');
      await tapIf(s, find.byKey(const Key('credits-show')), label: 'credits');
      final tier = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('tier-'));
      await tapIf(s, tier, label: 'choose tier');
      await back(tester);
      await visit(s, app, '/fun');
      await tapIf(s, find.byKey(const Key('parentfun-btn')), label: 'parent fun');
    });
  });
}
