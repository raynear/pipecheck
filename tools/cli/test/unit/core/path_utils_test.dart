import 'package:boilerplate_cli/core/path_utils.dart';
import 'package:test/test.dart';

void main() {
  group('expandUserPath', () {
    test('expands bare ~ to home', () {
      expect(expandUserPath('~', home: '/Users/me'), '/Users/me');
    });

    test('expands ~/... to home-relative path', () {
      expect(
        expandUserPath('~/keys/app.jks', home: '/Users/me'),
        '/Users/me/keys/app.jks',
      );
    });

    test('leaves absolute paths untouched (ignores projectRoot)', () {
      expect(
        expandUserPath('/etc/keys/app.jks',
            home: '/Users/me', projectRoot: '/proj'),
        '/etc/keys/app.jks',
      );
    });

    test('joins relative path against projectRoot when provided', () {
      expect(
        expandUserPath('android/app.jks', projectRoot: '/proj'),
        '/proj/android/app.jks',
      );
    });

    test('returns relative path unchanged when no projectRoot', () {
      expect(expandUserPath('android/app.jks'), 'android/app.jks');
    });

    test('fail-safe: empty HOME keeps raw ~ path so error is diagnosable', () {
      // A missing HOME must not silently resolve ~/x to /x — keep it raw.
      expect(expandUserPath('~/app.jks', home: ''), '~/app.jks');
      expect(expandUserPath('~', home: ''), '~');
    });

    test('empty input returns empty', () {
      expect(expandUserPath('', projectRoot: '/proj'), '');
    });

    test('does not treat a tilde mid-path as home (~backup only expands prefix)', () {
      expect(
        expandUserPath('dir/~cache/x', projectRoot: '/proj'),
        '/proj/dir/~cache/x',
      );
    });
  });
}
