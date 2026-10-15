// Tiện ích chung (shuffle/sample/wait của ui.js, rand/pick/ramp của funcore.js, easing của funfx.js).
import 'dart:math' as math;

final math.Random rng = math.Random();

/// Bản sao đã xáo trộn (Fisher–Yates).
List<T> shuffle<T>(Iterable<T> a, [math.Random? r]) {
  final l = [...a];
  final rr = r ?? rng;
  for (var i = l.length - 1; i > 0; i--) {
    final j = rr.nextInt(i + 1);
    final t = l[i];
    l[i] = l[j];
    l[j] = t;
  }
  return l;
}

/// n phần tử ngẫu nhiên khác nhau.
List<T> sample<T>(Iterable<T> a, int n, [math.Random? r]) => shuffle(a, r).take(n).toList();

/// Một phần tử ngẫu nhiên.
T pick<T>(List<T> a, [math.Random? r]) => a[(r ?? rng).nextInt(a.length)];

/// Số thực ngẫu nhiên trong [a, b).
double rand(double a, double b) => a + rng.nextDouble() * (b - a);

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

double clampD(double v, [double a = 0, double b = 1]) => v < a ? a : (v > b ? b : v);
double lerp(double a, double b, double k) => a + (b - a) * k;

/// Giá trị đi từ a (cấp 1) tới b (cấp maxLv), tuyến tính (ramp() của funcore.js).
double ramp(int lv, double a, double b, [int maxLv = 60]) => a + (b - a) * math.min(1, math.max(0, lv) / (maxLv - 1));

/// Tiến dần về target theo tốc độ rate (độc lập khung hình).
double approach(double v, double target, double rate, double dt) => target + (v - target) * math.exp(-rate * dt);

double easeOut(double k) => 1 - (1 - k) * (1 - k) * (1 - k);
double easeIn(double k) => k * k * k;
double easeOutBack(double k) {
  const c = 1.70158;
  return 1 + (c + 1) * math.pow(k - 1, 3) + c * math.pow(k - 1, 2);
}

double easeOutElastic(double k) => k <= 0 ? 0 : k >= 1 ? 1 : math.pow(2, -10 * k) * math.sin((k * 10 - .75) * 2.094) + 1;

/// Lặp danh sách cho đủ n phần tử, xáo trộn, tránh hai phần tử liền nhau trùng (sequence() của quiz.js).
List<T> sequence<T>(List<T> items, int n) {
  final out = <T>[];
  if (items.isEmpty) return out;
  while (out.length < n) {
    final batch = shuffle(items);
    if (out.isNotEmpty && batch.first == out.last && batch.length > 1) batch.add(batch.removeAt(0));
    out.addAll(batch);
  }
  return out.take(n).toList();
}
