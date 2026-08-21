/// Calcula la edad en años cumplidos a partir de una fecha de nacimiento,
/// ajustando por si todavía no pasó el cumpleaños de este año.
int calculateAge(DateTime birthDate, [DateTime? asOf]) {
  final now = asOf ?? DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}
