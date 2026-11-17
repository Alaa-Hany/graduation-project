// Phase 5 security tests: #7 safe retries + idempotency keys, #10 parent gate.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/widgets/parent_gate_dialog.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;
}

/// Answers every request with [status] and counts how often it was hit.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.status);

  final int status;
  int calls = 0;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'success': status < 400}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Dio _dioWithRetry(_CountingAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  dio.interceptors.add(
    RetryInterceptor(dio: dio, logger: Logger(level: Level.off), maxRetries: 2),
  );
  return dio;
}

Future<void> _pumpGateHost(
    WidgetTester tester, void Function(bool) onResult) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            // Seeded so the question is known: 6 + 1 = 7, 6 + 2 = 8 -> 7 × 8.
            onResult(
                await showParentGate(context, random: _FixedRandom([1, 2])));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(); // app localizations load asynchronously
}

class _FixedRandom implements Random {
  _FixedRandom(this._values);

  final List<int> _values;
  int _index = 0;

  @override
  int nextInt(int max) => _values[_index++ % _values.length];

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('#7 retries only replay safe requests', () {
    test('isSafeToRetry: GET yes, POST no, POST with Idempotency-Key yes', () {
      expect(RetryInterceptor.isSafeToRetry(RequestOptions(method: 'GET')),
          isTrue);
      expect(RetryInterceptor.isSafeToRetry(RequestOptions(method: 'POST')),
          isFalse);
      expect(
        RetryInterceptor.isSafeToRetry(
          RequestOptions(method: 'POST', headers: {'idempotency-key': 'k-1'}),
        ),
        isTrue,
      );
      expect(
        RetryInterceptor.isSafeToRetry(
          RequestOptions(method: 'DELETE', headers: {'Idempotency-Key': ' '}),
        ),
        isFalse,
      );
    });

    test('a failing POST is sent once, never replayed', () async {
      final adapter = _CountingAdapter(503);
      final dio = _dioWithRetry(adapter);
      await expectLater(dio.post<dynamic>('https://api.test/pay'),
          throwsA(isA<DioException>()));
      expect(adapter.calls, 1);
    });

    test('a failing GET is still retried', () async {
      final adapter = _CountingAdapter(503);
      final dio = _dioWithRetry(adapter);
      await expectLater(dio.get<dynamic>('https://api.test/reports'),
          throwsA(isA<DioException>()));
      expect(adapter.calls, 3); // first try + 2 retries
    });

    test('analytics writes carry the caller key, or a random one', () async {
      final adapter = _CountingAdapter(200);
      final api = ReportsApi(
        NetworkService(
          dio: Dio()..httpClientAdapter = adapter,
          secureStorage: _TestSecureStorage(),
          logger: Logger(level: Level.off),
        ),
      );

      await api.ingestActivityEvent(
        const {'child_id': 1, 'event_type': 'activity_completed'},
        idempotencyKey: 'progress-event:abc',
      );
      expect(
        adapter.lastOptions?.headers[NetworkService.idempotencyKeyHeader],
        'progress-event:abc',
      );

      await api.ingestSessionLog(const {'child_id': 1});
      final generated =
          adapter.lastOptions?.headers[NetworkService.idempotencyKeyHeader];
      expect(generated, isA<String>());
      expect((generated as String).isNotEmpty, isTrue);
    });
  });

  group('#10 parent gate before leaving the app', () {
    testWidgets('wrong answer keeps the gate closed, cancel returns false',
        (tester) async {
      bool? result;
      await _pumpGateHost(tester, (value) => result = value);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('7 × 8'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('parent_gate_answer')), '15');
      await tester.tap(find.byKey(const Key('parent_gate_continue')));
      await tester.pumpAndSettle();
      expect(find.text('That is not right. Please ask a grown-up.'),
          findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('the right answer lets the grown-up continue', (tester) async {
      bool? result;
      await _pumpGateHost(tester, (value) => result = value);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('parent_gate_answer')), '56');
      await tester.tap(find.byKey(const Key('parent_gate_continue')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('#24 Android permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('no Bluetooth permissions are declared', () {
      expect(manifest, isNot(contains('android.permission.BLUETOOTH')));
    });

    test('the mic permission the AI Buddy needs is still declared', () {
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
      expect(manifest, contains('android.permission.INTERNET'));
    });

    test('speech_to_text is started without Bluetooth support', () {
      final screen =
          File('lib/features/child_mode/ai_buddy/ai_buddy_screen.dart')
              .readAsStringSync();
      expect(screen, contains('SpeechToText.androidNoBluetooth'));
    });
  });

  group('#9 / #23 web hosting', () {
    test('firebase.json sends the security headers on every path', () {
      final config = jsonDecode(File('firebase.json').readAsStringSync())
          as Map<String, dynamic>;
      final rules =
          (config['hosting']['headers'] as List).cast<Map<String, dynamic>>();
      final all = rules.firstWhere((r) => r['source'] == '**');
      final keys = {
        for (final h in (all['headers'] as List).cast<Map<String, dynamic>>())
          h['key'] as String: h['value'] as String,
      };
      expect(keys['X-Frame-Options'], 'DENY');
      expect(keys['X-Content-Type-Options'], 'nosniff');
      final csp = keys['Content-Security-Policy']!;
      expect(csp, contains("frame-ancestors 'none'"));
      expect(csp, contains("object-src 'none'"));
      expect(csp, isNot(contains("'unsafe-eval'")));
      expect(csp, contains('https://www.youtube-nocookie.com'));
      // The app shell (index.html, JS) must never be served stale.
      expect(
        rules.any((r) =>
            (r['headers'] as List).any((h) =>
                h['key'] == 'Cache-Control' && h['value'] == 'no-cache') &&
            '${r['source']}'.contains('html')),
        isTrue,
      );
    });

    test('index.html allows zoom and has no inline script', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, isNot(contains('user-scalable=no')));
      expect(html, contains('<html lang="en">'));
      expect(RegExp(r'<script>').hasMatch(html), isFalse);
    });
  });
}
