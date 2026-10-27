import 'package:flutter/material.dart';

enum PedalCategory {
  distortion('Distortion'),
  overdrive('Overdrive'),
  fuzz('Fuzz'),
  delay('Delay'),
  reverb('Reverb'),
  chorus('Chorus'),
  phaser('Phaser'),
  compressor('Compressor'),
  tuner('Tuner'),
  pitch('Pitch Shifter'),
  wah('Wah / Volume'),
  multi('Multi Effects');

  const PedalCategory(this.label);
  final String label;
}

class Pedal {
  const Pedal({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    this.controls = const ['1', '2', '3'],
    this.widthMm = 70,
    this.depthMm = 125,
    this.isCustom = false,
    this.brand = '',
    this.searchAliases = '',
    this.sourceUrl = '',
    this.artwork = 'stomp',
  });
  final String id, name;
  final String brand, searchAliases, sourceUrl, artwork;
  String get searchText =>
      '$brand $name $searchAliases ${category.label} $widthMm $depthMm'
          .toLowerCase();
  final PedalCategory category;
  final Color color;
  final List<String> controls;
  final double widthMm, depthMm;
  final bool isCustom;
  Map<String, dynamic> toJson() => {
    'brand': brand,
    'searchAliases': searchAliases,
    'sourceUrl': sourceUrl,
    'artwork': artwork,
    'id': id,
    'name': name,
    'category': category.name,
    'color': color.toARGB32(),
    'controls': controls,
    'widthMm': widthMm,
    'depthMm': depthMm,
    'isCustom': isCustom,
  };
  factory Pedal.fromJson(Map<String, dynamic> j) => Pedal(
    brand: j['brand'] as String? ?? '',
    searchAliases: j['searchAliases'] as String? ?? '',
    sourceUrl: j['sourceUrl'] as String? ?? '',
    artwork: j['artwork'] as String? ?? 'stomp',
    id: j['id'] as String,
    name: j['name'] as String,
    category: PedalCategory.values.byName(j['category'] as String),
    color: Color(j['color'] as int),
    controls: List<String>.from(j['controls'] as List),
    widthMm: (j['widthMm'] as num).toDouble(),
    depthMm: (j['depthMm'] as num).toDouble(),
    isCustom: j['isCustom'] as bool? ?? false,
  );
}
