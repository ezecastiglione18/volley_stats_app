import 'package:flutter/material.dart';

import '../models/rally_event.dart';

class GradeOption {
  final String code;
  final String label;
  final Color color;
  const GradeOption(this.code, this.label, this.color);
}

const serveAttackGrades = [
  GradeOption(Grade.pp, 'PP\nPunto', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nBueno', Color(0xFF64B5F6)),
  GradeOption(Grade.n, 'N\nNegativo', Color(0xFFFFB74D)),
  GradeOption(Grade.nn, 'NN\nError', Color(0xFFE64A3B)),
];

const attackCounterGrades = [
  GradeOption(Grade.pp, 'PP\nPunto', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nBueno', Color(0xFF64B5F6)),
  GradeOption(Grade.n, 'N\nNegativo', Color(0xFFFFB74D)),
  GradeOption(Grade.bloq, 'BLOQ\nBloqueado', Color(0xFFE64A3B)),
  GradeOption(Grade.nn, 'NN\nError', Color(0xFFB71C1C)),
];

const receptionGrades = [
  GradeOption(Grade.pp, 'PP\nPerfecta', Color(0xFF1E88E5)),
  GradeOption(Grade.p, 'P\nBuena', Color(0xFF64B5F6)),
  GradeOption(Grade.excl, '!\nEfectiva', Color(0xFF9CCC65)),
  GradeOption(Grade.n, 'N\nNegativa', Color(0xFFFFB74D)),
  GradeOption(Grade.vNeg, 'V-\nMuy neg.', Color(0xFFFF8A65)),
  GradeOption(Grade.nn, 'NN\nError', Color(0xFFE64A3B)),
];
