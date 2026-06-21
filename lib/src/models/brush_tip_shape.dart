enum BrushTipShape {
  round,
  square;

  String toJson() => name;

  static BrushTipShape fromJson(Object? json) {
    switch (json) {
      case 'round':
        return BrushTipShape.round;
      case 'square':
        return BrushTipShape.square;
      default:
        throw FormatException('Unknown BrushTipShape: $json');
    }
  }
}
