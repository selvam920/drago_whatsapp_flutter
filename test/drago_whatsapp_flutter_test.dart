import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePhone', () {
    test('strips formatting and adds the chat suffix', () {
      expect(parsePhone('+91 98765-43210'), '919876543210@c.us');
      expect(parsePhone('(044) 2345 6789'), '04423456789@c.us');
    });

    test('passes full chat ids through', () {
      expect(parsePhone('120363012345@g.us'), '120363012345@g.us');
      expect(parsePhone(' 120363999@newsletter '), '120363999@newsletter');
    });

    test('parseGroup keeps legacy owner-timestamp ids', () {
      expect(parseGroup('919876543210-1612345678'),
          '919876543210-1612345678@g.us');
    });
  });

  group('jsParse', () {
    test('escapes quotes, backslashes and newlines as a JS literal', () {
      expect('a "b" \\ c\nd'.jsParse, r'"a \"b\" \\ c\nd"');
    });

    test('lists become JSON arrays', () {
      expect(['Yes', 'No'].jsParse, '["Yes","No"]');
    });

    test('null stays null, bools and numbers stay literal', () {
      expect((null as String?).jsParse, isNull);
      expect(true.jsParse, 'true');
      expect(3.jsParse, '3');
    });

    test('phoneParse is a quoted id', () {
      expect('98765 43210'.phoneParse, '"9876543210@c.us"');
    });
  });

  group('Message.parse ack', () {
    test('reads ack from a send result', () {
      final m = Message.parse({'id': 'true_91@c.us_ABC', 'ack': 1}).single;
      expect(m.ack, MessageAck.server);
      expect(m.isSent, isTrue);
      expect(m.isFailed, isFalse);
      expect(m.id?.serialized, 'true_91@c.us_ABC');
    });

    test('negative ack is a failure', () {
      final m = Message.parse('{"id":"x","ack":-1}').single;
      expect(m.isFailed, isTrue);
    });

    test('missing ack is pending', () {
      expect(Message.parse({'id': 'x'}).single.ack, MessageAck.pending);
    });
  });

  group('WhatsappChatSummary', () {
    test('kind and canPost from id and role', () {
      final list = WhatsappChatSummary.parseList([
        {'id': '1@g.us', 'name': 'Team', 'announce': true, 'isAdmin': false},
        {'id': '2@newsletter', 'name': 'Offers', 'role': 'owner'},
        {'id': '3@newsletter', 'name': 'News', 'role': 'subscriber'},
        {'id': '4@g.us', 'name': 'Open'},
      ]);
      expect(list.map((e) => e.kind), [
        WhatsappChatKind.group,
        WhatsappChatKind.newsletter,
        WhatsappChatKind.newsletter,
        WhatsappChatKind.group,
      ]);
      expect(list.map((e) => e.canPost), [false, true, false, true]);
    });
  });

  test('MessageButtons encode as plain keys', () {
    final b = MessageButtons(
      text: 'Visit',
      buttonData: 'https://example.com',
      buttonType: ButtonType.url,
    );
    expect(b.toJson(), {'text': 'Visit', 'url': 'https://example.com'});
  });
}
