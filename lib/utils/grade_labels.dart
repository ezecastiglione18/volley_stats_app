import 'package:flutter/material.dart';

import '../models/rally_event.dart';

class GradeOption {
  final String code;
  final String label;
  final Color color;
  const GradeOption(this.code, this.label, this.color);
}

const serveAttackGrades = [
  GradeOption(Grade.pp, 'PP\nPunto (Doble Positiva)', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nPositiva', Color(0xFF64B5F6)),
  GradeOption(Grade.n, 'N\nNegativa', Color(0xFFFFB74D)),
  GradeOption(Grade.nn, 'NN\nError (Doble Negativa)', Color(0xFFE64A3B)),
];

const attackCounterGrades = [
  GradeOption(Grade.pp, 'PP\nPunto (Doble Positiva)', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nPositiva', Color(0xFF64B5F6)),
  GradeOption(Grade.n, 'N\nNegativa', Color(0xFFFFB74D)),
  GradeOption(Grade.bloq, 'BLOQ\nBloqueado', Color(0xFFE64A3B)),
  GradeOption(Grade.nn, 'NN\nError (Doble Negativa)', Color(0xFFB71C1C)),
];

const receptionGrades = [
  GradeOption(Grade.pp, 'PP\nPerfecta (Doble Positiva)', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nPositiva', Color(0xFF64B5F6)),
  GradeOption(Grade.excl, '!\nExclamativa', Color(0xFF9CCC65)),
  GradeOption(Grade.n, 'N\nNegativa', Color(0xFFFFB74D)),
  GradeOption(Grade.vNeg, 'V/\nVendida', Color(0xFFFF8A65)),
  GradeOption(Grade.nn, 'NN\nError (Doble Negativa)', Color(0xFFE64A3B)),
];
