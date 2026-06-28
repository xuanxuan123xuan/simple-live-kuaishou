import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  group('KuaishouSite.resolveRoomTitle', () {
    test('prefers the room caption over the author name', () {
      expect(
        KuaishouSite.resolveRoomTitle({
          'caption': '今晚冲榜',
          'author': {'name': '测试主播'},
          'gameInfo': {'name': '王者荣耀'},
        }),
        '今晚冲榜',
      );
    });

    test('falls back through stream, game, and author fields', () {
      expect(
        KuaishouSite.resolveRoomTitle({
          'liveStream': {'caption': '直播流标题'},
          'author': {'name': '测试主播'},
        }),
        '直播流标题',
      );
      expect(
        KuaishouSite.resolveRoomTitle({
          'gameInfo': {'name': '主机游戏'},
          'author': {'name': '测试主播'},
        }),
        '主机游戏',
      );
      expect(
        KuaishouSite.resolveRoomTitle({
          'author': {'name': '测试主播'},
        }),
        '测试主播',
      );
    });
  });

  group('KuaishouSite.resolveLiveStatus', () {
    test('accepts explicit live flags', () {
      expect(KuaishouSite.resolveLiveStatus({'isLiving': true}), isTrue);
      expect(KuaishouSite.resolveLiveStatus({'living': 1}), isTrue);
    });

    test('uses playable stream evidence when the flag is stale', () {
      expect(
        KuaishouSite.resolveLiveStatus({
          'isLiving': false,
          'liveStream': {
            'id': 'stream-id',
            'playUrls': {
              'h264': {
                'adaptationSet': {
                  'representation': [
                    {'url': 'https://example.com/live.flv'},
                  ],
                },
              },
            },
          },
        }),
        isTrue,
      );
    });

    test('does not mark an empty stream as live', () {
      expect(
        KuaishouSite.resolveLiveStatus({
          'isLiving': false,
          'liveStream': {'id': '', 'playUrls': const {}},
        }),
        isFalse,
      );
    });
  });
}
