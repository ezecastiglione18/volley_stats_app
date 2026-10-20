// Panel de temporada (issue #49): SeasonEngine suma partido por partido lo que
// ya calcula StatsEngine. Los partidos se simulan (resultado al azar), así que
// los tests comparan contra StatsEngine.compute() de cada partido en vez de
// fijar números: lo que se prueba es la agregación, los filtros y que los
// porcentajes salgan de conteos sumados.

import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/stat_line.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/services/season_engine.dart';
import 'package:rally_stats/services/stats_engine.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/match_controller.dart';

Player _p(String id, int number, PlayerPosition pos) =>
    Player(id: id, firstName: id, lastName: 'Test', number: number, position: pos);

final _roster = [
  _p('A1', 1, PlayerPosition.armador),
  _p('P1', 2, PlayerPosition.puntaReceptor),
  _p('C1', 3, PlayerPosition.central),
  _p('O1', 4, PlayerPosition.opuesto),
  _p('P2', 5, PlayerPosition.puntaReceptor),
  _p('C2', 6, PlayerPosition.central),
];

/// Partido de un set simulado hasta el final. [finished] false lo deja
/// "en curso" (como un partido que todavía no se terminó de cargar).
VolleyMatch _match(
  String id,
  DateTime date, {
  String tournament = 'Liga',
  String? sourceId = 'team-1',
  String teamName = 'Propio',
  List<Player>? roster,
  bool finished = true,
}) {
  final players = roster ?? _roster;
  final match = VolleyMatch(
    id: id,
    date: date,
    tournament: tournament,
    ownTeamName: teamName,
    ownTeamSourceId: sourceId,
    ownRoster: players,
    rivalTeamName: 'Los Andes',
    config: MatchConfig(),
  );
  final c = MatchController(match)
    ..startSet(
      setNumber: 1,
      startingOrderOwn: [for (final p in players.take(6)) p.id],
      startingServer: TeamSide.own,
      trackHitZones: false,
    );
  c.simulateRestOfSet();
  match.status = finished ? MatchStatus.finished : MatchStatus.inProgress;
  return match;
}

int _sum(Iterable<MatchStats> all, int Function(MatchStats) f) => all.fold(0, (acc, s) => acc + f(s));

void main() {
  late VolleyMatch m1, m2, m3, inProgress, otherTeam;
  late List<VolleyMatch> all;

  // MatchController guarda en Hive cada acción que simula, así que hay que
  // abrir el almacenamiento (con path_provider simulado) ANTES de armar los
  // partidos: por eso se crean acá y no al declararlos.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_season_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();

    // 3 terminados de 'team-1' (2 de la Liga, 1 de la Copa), 1 en curso del
    // mismo equipo y 1 terminado de otro equipo.
    m1 = _match('m1', DateTime(2026, 3, 10));
    m2 = _match('m2', DateTime(2026, 4, 14));
    m3 = _match('m3', DateTime(2026, 5, 20), tournament: 'Copa');
    inProgress = _match('m4', DateTime(2026, 6, 1), finished: false);
    otherTeam = _match('m5', DateTime(2026, 4, 1), sourceId: 'team-2', teamName: 'Otro');
    all = [m1, m2, m3, inProgress, otherTeam];
  });

  group('SeasonEngine.buildSeason', () {
    test('solo cuenta partidos terminados del equipo pedido', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      expect(r.matchesCount, 3);
      expect(r.matches.map((m) => m.id), ['m3', 'm2', 'm1'], reason: 'del más nuevo al más viejo');
    });

    test('un partido en curso queda afuera', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      expect(r.matches.any((m) => m.id == 'm4'), isFalse);
    });

    test('la fila de equipo es la suma de las filas de equipo de cada partido', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      final stats = [m1, m2, m3].map(StatsEngine.compute).toList();

      expect(r.total.saque.pp, _sum(stats, (s) => s.team.saque.pp));
      expect(r.total.ataque.total, _sum(stats, (s) => s.team.ataque.total));
      expect(r.total.recepcion.total, _sum(stats, (s) => s.team.recepcion.total));
      expect(r.total.bloqueoPts, _sum(stats, (s) => s.team.bloqueoPts));
      expect(r.total.errGen, _sum(stats, (s) => s.team.errGen));
    });

    test('suma por jugador (mismo Player.id en varios partidos)', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      final stats = [m1, m2, m3].map(StatsEngine.compute).toList();

      for (final row in r.rows) {
        expect(
          row.ataque.total,
          _sum(stats, (s) => s.byPlayer[row.playerId]?.ataque.total ?? 0),
          reason: row.playerId,
        );
        expect(
          row.saque.pp,
          _sum(stats, (s) => s.byPlayer[row.playerId]?.saque.pp ?? 0),
          reason: row.playerId,
        );
      }
      // Las filas por jugador suman lo mismo que la fila de equipo.
      expect(r.rows.fold(0, (a, row) => a + row.ataque.total), r.total.ataque.total);
    });

    test('PJ: en cuántos partidos figura cada jugador', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      final stats = [m1, m2, m3].map(StatsEngine.compute).toList();

      for (final row in r.rows) {
        expect(
          r.matchesPlayed[row.playerId],
          stats.where((s) => s.byPlayer.containsKey(row.playerId)).length,
          reason: row.playerId,
        );
        expect(r.matchesPlayed[row.playerId], inInclusiveRange(1, 3));
      }
    });

    test('ganados, perdidos y sets salen de los partidos', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      final ms = [m1, m2, m3];
      expect(r.setsFor, ms.fold(0, (a, m) => a + m.ownSetsWon));
      expect(r.setsAgainst, ms.fold(0, (a, m) => a + m.rivalSetsWon));
      expect(r.matchesWon, ms.where((m) => m.ownSetsWon > m.rivalSetsWon).length);
      expect(r.matchesLost, ms.where((m) => m.rivalSetsWon > m.ownSetsWon).length);
    });

    test('filtro por torneo', () {
      final liga = SeasonEngine.buildSeason(all, teamKey: 'team-1', tournament: 'Liga');
      final copa = SeasonEngine.buildSeason(all, teamKey: 'team-1', tournament: 'Copa');
      expect(liga.matches.map((m) => m.id).toSet(), {'m1', 'm2'});
      expect(copa.matches.map((m) => m.id), ['m3']);
    });

    test('filtro por rango de fechas (inclusive, por día)', () {
      final r = SeasonEngine.buildSeason(
        all,
        teamKey: 'team-1',
        range: DateTimeRange(start: DateTime(2026, 4, 14), end: DateTime(2026, 5, 20)),
      );
      expect(r.matches.map((m) => m.id).toSet(), {'m2', 'm3'});
    });

    test('torneo y rango se combinan', () {
      final r = SeasonEngine.buildSeason(
        all,
        teamKey: 'team-1',
        tournament: 'Liga',
        range: DateTimeRange(start: DateTime(2026, 4, 1), end: DateTime(2026, 12, 31)),
      );
      expect(r.matches.map((m) => m.id), ['m2']);
    });

    test('los porcentajes salen de los conteos sumados, no de promediar porcentajes', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1');
      final stats = [m1, m2, m3].map(StatsEngine.compute).toList();
      final good = _sum(stats, (s) => s.team.recepcion.pp + s.team.recepcion.p);
      final total = _sum(stats, (s) => s.team.recepcion.total);

      expect(total, greaterThan(0));
      expect(r.total.recepcion.efficiency, closeTo(good / total, 1e-12));
    });

    test('sin partidos que cumplan el filtro: reporte vacío', () {
      final r = SeasonEngine.buildSeason(all, teamKey: 'team-1', tournament: 'No existe');
      expect(r.isEmpty, isTrue);
      expect(r.rows, isEmpty);
      expect(r.matchesWon + r.matchesLost, 0);
    });

    test('un partido sin ownTeamSourceId se agrupa por nombre', () {
      final manual = _match('m6', DateTime(2026, 2, 2), sourceId: null, teamName: 'Mi Club');
      final r = SeasonEngine.buildSeason([manual], teamKey: 'name:Mi Club');
      expect(SeasonEngine.teamKeyOf(manual), 'name:Mi Club');
      expect(r.matchesCount, 1);
    });

    test('nombre y dorsal salen del partido más reciente del jugador', () {
      // El partido viejo tiene a todos con otro dorsal (+10): el dorsal que
      // sale es el del nuevo para quien jugó en el nuevo.
      final oldRoster = [for (final p in _roster) _p(p.id, p.number + 10, p.position)];
      final older = _match('old', DateTime(2026, 1, 5), roster: oldRoster);
      final newer = _match('new', DateTime(2026, 2, 5));
      final r = SeasonEngine.buildSeason([older, newer], teamKey: 'team-1');
      final inNewer = StatsEngine.compute(newer).byPlayer;

      for (final row in r.rows
          .where((x) => x.playerId != unassignedId && inNewer.containsKey(x.playerId))) {
        expect(row.number, inNewer[row.playerId]!.number, reason: row.playerId);
        expect(row.number, lessThan(10));
      }
    });
  });

  group('SeasonEngine opciones de filtro', () {
    test('equipos: uno por clave, solo con partidos terminados, ordenados por nombre', () {
      final opts = SeasonEngine.teamOptions(all);
      expect(opts.map((o) => o.label).toList(), ['Otro', 'Propio']);
      expect(opts.map((o) => o.key).toList(), ['team-2', 'team-1']);
    });

    test('torneos: sin repetir ni vacíos, solo del equipo y terminados', () {
      expect(SeasonEngine.tournaments(all, teamKey: 'team-1'), ['Copa', 'Liga']);
      final noTournament = _match('m7', DateTime(2026, 7, 7), tournament: '');
      expect(SeasonEngine.tournaments([noTournament], teamKey: 'team-1'), isEmpty);
    });
  });

  group('addFrom (stat_line.dart)', () {
    test('TouchStats y ReceptionStats suman todos sus conteos', () {
      final t = TouchStats()
        ..pp = 1
        ..p = 2
        ..n = 3
        ..nn = 4
        ..bloq = 5;
      final acc = TouchStats()..addFrom(t)..addFrom(t);
      expect((acc.pp, acc.p, acc.n, acc.nn, acc.bloq), (2, 4, 6, 8, 10));

      final r = ReceptionStats()
        ..pp = 1
        ..p = 2
        ..excl = 3
        ..n = 4
        ..vNeg = 5
        ..nn = 6;
      final accR = ReceptionStats()..addFrom(r)..addFrom(r);
      expect((accR.pp, accR.p, accR.excl, accR.n, accR.vNeg, accR.nn), (2, 4, 6, 8, 10, 12));
    });
  });
}
