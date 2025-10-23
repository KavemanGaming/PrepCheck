num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) {
    final n = num.tryParse(v.trim());
    if (n != null) return n;
  }
  return 0;
}

num orderQtyNum(dynamic par, dynamic onHand) {
  final p = _toNum(par);
  final h = _toNum(onHand);
  final o = p - h;
  return o > 0 ? o : 0;
}

String orderQtyStr(dynamic par, dynamic onHand) {
  final o = orderQtyNum(par, onHand);
  if (o == o.roundToDouble()) return o.toInt().toString();
  return o.toStringAsFixed(2);
}
