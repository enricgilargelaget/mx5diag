import 'package:flutter_test/flutter_test.dart';
import 'package:mx5diag/data/models.dart';
import 'package:mx5diag/obd/obd_parser.dart';
import 'package:mx5diag/services/bateria.dart';

void main() {
  group('DTC', () {
    test('bytes a código', () {
      expect(bytesADtc(0x01, 0x71), 'P0171');
      expect(bytesADtc(0x03, 0x01), 'P0301');
      expect(bytesADtc(0x41, 0x23), 'C0123');
      expect(bytesADtc(0xC1, 0x00), 'U0100');
      expect(bytesADtc(0, 0), isNull);
    });

    test('respuesta CAN de una trama', () {
      expect(parsearDtcs('43 02 01 71 03 01 \r\r>'), ['P0171', 'P0301']);
    });

    test('respuesta CAN sin códigos', () {
      expect(parsearDtcs('43 00 \r>'), isEmpty);
    });

    test('respuesta CAN multitrama', () {
      const raw = '00A\r0: 43 04 01 71 03 01\r1: 04 20 01 33 00 00 00\r\r>';
      expect(parsearDtcs(raw), ['P0171', 'P0301', 'P0420', 'P0133']);
    });

    test('respuesta no CAN (ISO 9141 / KWP)', () {
      expect(parsearDtcs('43 01 71 03 01 00 00\r>'), ['P0171', 'P0301']);
    });

    test('NO DATA', () {
      expect(parsearDtcs('NO DATA\r>'), isEmpty);
    });
  });

  group('PIDs y tensión', () {
    test('rpm', () {
      final b = datosPid('41 0C 1A F8\r>', '0C')!;
      expect(pidsBasicos.firstWhere((p) => p.codigo == '0C').formula(b), 1726);
    });
    test('ATRV', () {
      expect(parsearVoltaje('12.6V\r>'), 12.6);
      expect(parsearVoltaje('ERROR'), isNull);
    });
  });

  group('Batería', () {
    test('reposo', () {
      expect(evaluarReposo(12.7).estado, Estado.verde);
      expect(evaluarReposo(12.2).estado, Estado.amarillo);
      expect(evaluarReposo(11.9).estado, Estado.rojo);
    });
    test('carga', () {
      expect(evaluarCarga(14.2).estado, Estado.verde);
      expect(evaluarCarga(15.1).estado, Estado.rojo);
    });
  });
}
