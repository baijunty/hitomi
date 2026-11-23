import 'dart:io';

import 'package:hitomi/src/http_server.dart';
import 'package:test/test.dart';

/// /sync、/delete 的「本地 / 局域网」门槛使用的客户端地址选取规则。
///
/// 回归背景：Web 端浏览器拿不到自己的局域网 IP，x-real-ip 头为空，
/// 旧实现 `InternetAddress(空串)` 抛 FormatException，Web 端所有同步请求
/// 都变成 500，阅读历史 / 收藏因此无法同步。
void main() {
  group('pickClientAddress', () {
    final peer = InternetAddress('192.168.1.50');

    test('桌面端自报的 x-real-ip 优先于对端地址', () {
      expect(pickClientAddress('10.0.0.8', peer)?.address, '10.0.0.8');
    });

    test('浏览器不带 x-real-ip 时回退到连接对端地址', () {
      expect(pickClientAddress(null, peer)?.address, '192.168.1.50');
    });

    test('x-real-ip 为空串（Web 端 localIp 返回空）时回退', () {
      expect(pickClientAddress('', peer)?.address, '192.168.1.50');
    });

    test('x-real-ip 非法时回退而不是抛异常', () {
      expect(pickClientAddress('not-an-ip', peer)?.address, '192.168.1.50');
    });

    test('头与对端地址都缺失时返回 null（调用方按未授权处理）', () {
      expect(pickClientAddress(null, null), isNull);
    });
  });

  group('unmapIPv4Mapped', () {
    test('IPv4-mapped IPv6 还原为 IPv4', () {
      final mapped = InternetAddress('::ffff:192.168.1.5');
      final v4 = unmapIPv4Mapped(mapped);
      expect(v4.type, InternetAddressType.IPv4);
      expect(v4.address, '192.168.1.5');
    });

    test('IPv4-mapped 环回还原后 isLoopback 为真', () {
      expect(unmapIPv4Mapped(InternetAddress('::ffff:127.0.0.1')).isLoopback,
          isTrue);
    });

    test('普通 IPv6 / IPv4 原样返回', () {
      final v6 = InternetAddress('fe80::1');
      expect(unmapIPv4Mapped(v6).address, 'fe80::1');
      final v4 = InternetAddress('10.0.0.8');
      expect(unmapIPv4Mapped(v4).address, '10.0.0.8');
    });
  });
}
