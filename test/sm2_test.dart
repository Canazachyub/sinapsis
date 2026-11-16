import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinapsis/core/srs/sm2.dart';
import 'package:sinapsis/core/utils/titulo_contenido.dart';
import 'package:sinapsis/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:sinapsis/features/notes/data/datasources/notes_srs_datasource.dart';
import 'package:sinapsis/features/notes/data/models/note_model.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  group('Sm2 (algoritmo puro)', () {
    test('nota nueva: primeros intervalos 1 y 6 días con "Bien"', () {
      var e = EstadoSrs.nueva;
      expect(e.esNueva, isTrue);
      e = Sm2.calificar(e, CalificacionSrs.bien, t0);
      expect(e.intervalo, 1);
      expect(e.repeticiones, 1);
      expect(e.vence, t0.add(const Duration(days: 1)));
      expect(e.esNueva, isFalse);

      e = Sm2.calificar(e, CalificacionSrs.bien, t0);
      expect(e.intervalo, 6);
      e = Sm2.calificar(e, CalificacionSrs.bien, t0);
      expect(e.intervalo, 15); // 6 × 2.5
      expect(e.ease, 2.5);
    });

    test('"Otra vez" reinicia a 0, vuelve en 10 min y suma lapso si estaba aprendida', () {
      final aprendida = const EstadoSrs(
          ease: 2.5, intervalo: 15, repeticiones: 3, lapsos: 0,
          vence: null, ultimoRepaso: null);
      final e = Sm2.calificar(
          aprendida.copiarCon(ultimoRepaso: t0, vence: t0), CalificacionSrs.otraVez, t0);
      expect(e.intervalo, 0);
      expect(e.repeticiones, 0);
      expect(e.lapsos, 1);
      expect(e.ease, 2.3);
      expect(e.vence, t0.add(const Duration(minutes: 10)));

      // En una nueva no cuenta como lapso ni baja el ease y vuelve en 1 min.
      final n = Sm2.calificar(EstadoSrs.nueva, CalificacionSrs.otraVez, t0);
      expect(n.lapsos, 0);
      expect(n.ease, 2.5);
      expect(n.esNueva, isFalse);
      expect(n.etapa, 'Aprendiendo');
      expect(n.vence, t0.add(const Duration(minutes: 1)));
    });

    test('nota nueva tipo Anki: Otra vez <1 min, Difícil 10 min, Bien 1 d, Fácil 4 d', () {
      final p = Sm2.previsualizar(EstadoSrs.nueva);
      expect(p[CalificacionSrs.otraVez], const Duration(minutes: 1));
      expect(p[CalificacionSrs.dificil], const Duration(minutes: 10));
      expect(p[CalificacionSrs.bien], const Duration(days: 1));
      expect(p[CalificacionSrs.facil], const Duration(days: 4));
      expect(
        CalificacionSrs.values.map((c) => Sm2.formatearIntervalo(p[c]!)),
        ['<1 min', '10 min', '1 d', '4 d'],
      );

      // Difícil en nueva: paso de 10 min, sin lapso ni penalizar el ease.
      final d = Sm2.calificar(EstadoSrs.nueva, CalificacionSrs.dificil, t0);
      expect(d.vence, t0.add(const Duration(minutes: 10)));
      expect(d.intervalo, 0);
      expect(d.repeticiones, 0);
      expect(d.lapsos, 0);
      expect(d.ease, 2.5);
      expect(d.etapa, 'Aprendiendo');
      // Y después "Bien" gradúa a 1 día.
      final b = Sm2.calificar(d, CalificacionSrs.bien, t0);
      expect(b.intervalo, 1);
    });

    test('Difícil: ease −0.15 e intervalo ×1.2; Fácil: ease +0.15 e intervalo ×ease×1.3', () {
      final base = EstadoSrs(
          ease: 2.5, intervalo: 10, repeticiones: 3, vence: t0, ultimoRepaso: t0);
      final d = Sm2.calificar(base, CalificacionSrs.dificil, t0);
      expect(d.intervalo, 12);
      expect(d.ease, 2.35);
      final f = Sm2.calificar(base, CalificacionSrs.facil, t0);
      expect(f.intervalo, 33); // 10 × 2.5 × 1.3 = 32.5 → 33
      expect(f.ease, 2.65);
      final b = Sm2.calificar(base, CalificacionSrs.bien, t0);
      expect(b.intervalo, 25);
    });

    test('orden de intervalos: Otra vez < Difícil ≤ Bien < Fácil', () {
      for (final e in [
        EstadoSrs.nueva,
        EstadoSrs(ease: 2.5, intervalo: 1, repeticiones: 1, vence: t0, ultimoRepaso: t0),
        EstadoSrs(ease: 1.3, intervalo: 2, repeticiones: 2, vence: t0, ultimoRepaso: t0),
        EstadoSrs(ease: 2.8, intervalo: 40, repeticiones: 6, vence: t0, ultimoRepaso: t0),
      ]) {
        final p = Sm2.previsualizar(e);
        expect(p[CalificacionSrs.otraVez]!, lessThan(p[CalificacionSrs.dificil]!));
        expect(p[CalificacionSrs.dificil]!, lessThanOrEqualTo(p[CalificacionSrs.bien]!));
        expect(p[CalificacionSrs.bien]!, lessThan(p[CalificacionSrs.facil]!));
      }
    });

    test('el ease nunca baja de 1.3', () {
      var e = EstadoSrs(ease: 1.35, intervalo: 5, repeticiones: 3, vence: t0, ultimoRepaso: t0);
      e = Sm2.calificar(e, CalificacionSrs.dificil, t0);
      expect(e.ease, 1.3);
      e = Sm2.calificar(e, CalificacionSrs.otraVez, t0);
      expect(e.ease, 1.3);
    });

    test('calidad 0-5 se mapea a los 4 botones', () {
      expect(CalificacionSrs.desdeCalidad(0), CalificacionSrs.otraVez);
      expect(CalificacionSrs.desdeCalidad(2), CalificacionSrs.otraVez);
      expect(CalificacionSrs.desdeCalidad(3), CalificacionSrs.dificil);
      expect(CalificacionSrs.desdeCalidad(4), CalificacionSrs.bien);
      expect(CalificacionSrs.desdeCalidad(5), CalificacionSrs.facil);
    });

    test('formato de intervalos', () {
      expect(Sm2.formatearIntervalo(const Duration(minutes: 1)), '<1 min');
      expect(Sm2.formatearIntervalo(const Duration(minutes: 10)), '10 min');
      expect(Sm2.formatearIntervalo(const Duration(days: 1)), '1 d');
      expect(Sm2.formatearIntervalo(const Duration(days: 45)), '1,5 meses');
      expect(Sm2.formatearIntervalo(const Duration(days: 400)), '1,1 años');
    });

    test('vencidaEn compara por día local', () {
      final e = EstadoSrs(vence: DateTime(2026, 11, 15, 23, 0), ultimoRepaso: t0, intervalo: 1, repeticiones: 1);
      expect(e.vencidaEn(DateTime(2026, 11, 15, 8)), isTrue);
      expect(e.vencidaEn(DateTime(2026, 11, 14, 23)), isFalse);
      expect(EstadoSrs.nueva.vencidaEn(t0), isFalse);
    });
  });

  group('NoteModel JSON compatible', () {
    final antiguo = {
      'id': 'n1',
      'courseId': 'c1',
      'userId': 'u1',
      'title': 'Corazón',
      'content': '[{"insert":"hola\\n"}]',
      'tags': [],
      'occlusionMarks': [],
      'imageOcclusions': [],
      'createdAt': '2025-10-22T02:28:13.716393',
      'updatedAt': '2025-12-18T12:57:44.723074',
    };

    test('nota antigua sin campos SRS carga como nueva', () {
      final m = NoteModel.fromJson(antiguo);
      expect(m.srs, EstadoSrs.nueva);
      expect(m.toEntity().srs.esNueva, isTrue);
    });

    test('campos SRS con tipos inválidos no rompen la carga', () {
      final m = NoteModel.fromJson({
        ...antiguo,
        'srsEase': 'x',
        'srsDue': 'no-es-fecha',
        'srsInterval': 6.0,
      });
      expect(m.srsEase, 2.5);
      expect(m.srsDue, isNull);
      expect(m.srsInterval, 6);
    });

    test('ida y vuelta conserva el estado', () {
      final e = Sm2.calificar(EstadoSrs.nueva, CalificacionSrs.bien, t0);
      final m = NoteModel.fromJson(antiguo).conSrs(e);
      final m2 = NoteModel.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(m2.srs, e);
    });
  });

  group('NotesSRSDataSource sobre SharedPreferences', () {
    Map<String, dynamic> nota(String id, {String course = 'c1', int dias = 0}) => {
          'id': id,
          'courseId': course,
          'userId': 'u1',
          'title': 'Nota $id',
          'content': '[{"insert":"x\\n"}]',
          'createdAt': DateTime(2025, 1, 1 + dias).toIso8601String(),
          'updatedAt': DateTime(2025, 1, 1 + dias).toIso8601String(),
        };

    Future<(NotesSRSDataSource, NotesLocalDataSourceImpl, SharedPreferences)> crear(
        {Map<String, Object> extra = const {}}) async {
      SharedPreferences.setMockInitialValues({
        'NOTES_DATA': jsonEncode({
          'a': nota('a'),
          'b': nota('b', dias: 1),
          'c': nota('c', course: 'c2', dias: 2),
        }),
        ...extra,
      });
      final prefs = await SharedPreferences.getInstance();
      final local = NotesLocalDataSourceImpl(prefs: prefs);
      final ds = NotesSRSDataSource(prefs, notas: local);
      return (ds, local, prefs);
    }

    test('cola inicial = todas nuevas; tras "Bien" sale de la cola hasta mañana', () async {
      final (ds, _, prefs) = await crear();
      ds.reloj = () => t0;
      expect((await ds.colaDeRepaso('u1')).map((n) => n.id), ['a', 'b', 'c']);
      expect((await ds.colaDeRepaso('u1', courseId: 'c2')).map((n) => n.id), ['c']);

      await ds.calificar('a', CalificacionSrs.bien);
      expect((await ds.colaDeRepaso('u1')).map((n) => n.id), ['b', 'c']);

      ds.reloj = () => t0.add(const Duration(days: 1));
      expect((await ds.pendientesHoy('u1')).map((n) => n.id), ['a']);

      final h = jsonDecode(prefs.getString('SRS_HISTORIAL')!) as Map;
      expect(h['2026-11-15']['repasos'], 1);
      expect(h['2026-11-15']['aciertos'], 1);
    });

    test('límite de nuevas por día desde srs_config', () async {
      final (ds, _, _) = await crear(extra: {
        'srs_config': jsonEncode({'newCardsPerDay': 2}),
      });
      ds.reloj = () => t0;
      expect((await ds.nuevas('u1')).length, 2);
      await ds.calificar('a', CalificacionSrs.bien);
      expect(ds.nuevasRestantesHoy(), 1);
      expect((await ds.nuevas('u1')).map((n) => n.id), ['b']);
    });

    test('resumen: retención real, racha y "—" sin datos', () async {
      final (ds, _, _) = await crear();
      ds.reloj = () => t0;
      var r = await ds.resumen('u1');
      expect(r.retencion30, isNull);
      expect(r.racha, 0);
      expect(r.totalNotas, 3);
      expect(r.nuevas, 3);

      ds.reloj = () => t0.subtract(const Duration(days: 1));
      await ds.calificar('a', CalificacionSrs.otraVez);
      ds.reloj = () => t0;
      await ds.calificar('b', CalificacionSrs.bien);
      await ds.calificar('c', CalificacionSrs.facil);
      r = await ds.resumen('u1');
      expect(r.retencion30, closeTo(2 / 3, 1e-9));
      expect(r.racha, 2);
      expect(r.repasadasHoy, 2);
      expect(r.pendientesHoy, 1); // 'a' venció ayer + 1 min
      expect(r.proximoRepaso, isNotNull);
    });

    test('guardar una nota con SRS antiguo (o desde Supabase) no borra el progreso', () async {
      final (ds, local, _) = await crear();
      ds.reloj = () => t0;
      final vieja = await local.getNote('a'); // cargada antes de repasar
      await ds.calificar('a', CalificacionSrs.bien);
      await local.updateNote(vieja.copyWith(title: 'Editada'));
      final tras = await local.getNote('a');
      expect(tras.title, 'Editada');
      expect(tras.srs.intervalo, 1);
      await local.saveNote(NoteModel.fromJson(nota('a'))); // como pullNotes
      expect((await local.getNote('a')).srs.intervalo, 1);
      // reiniciar sí puede volver a "nueva"
      await ds.reiniciarProgreso('a');
      expect((await local.getNote('a')).srs.esNueva, isTrue);
    });
  });

  group('contenidoEmpiezaConTitulo', () {
    test('encabezado Quill igual al título', () {
      final c = jsonEncode([
        {'insert': 'Anatomía del corazón'},
        {'insert': '\n', 'attributes': {'header': 1}},
        {'insert': 'texto\n'},
      ]);
      expect(contenidoEmpiezaConTitulo(c, 'ANATOMÍA DEL CORAZÓN'), isTrue);
      expect(contenidoEmpiezaConTitulo(c, 'Otra cosa'), isFalse);
    });

    test('línea normal o Markdown', () {
      final normal = jsonEncode([{'insert': 'Anatomía\ntexto\n'}]);
      expect(contenidoEmpiezaConTitulo(normal, 'Anatomía'), isFalse);
      final md = jsonEncode([{'insert': '# Anatomía\ntexto\n'}]);
      expect(contenidoEmpiezaConTitulo(md, 'Anatomía'), isTrue);
    });
  });
}
