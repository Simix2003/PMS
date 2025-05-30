class StationModel {
  final int id;
  final int lineId;
  final String name;
  final String displayName;
  final String type;
  final Map<String, dynamic>? config;
  final DateTime createdAt;

  StationModel({
    required this.id,
    required this.lineId,
    required this.name,
    required this.displayName,
    required this.type,
    required this.createdAt,
    this.config,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'],
      lineId: json['line_id'],
      name: json['name'],
      displayName: json['display_name'],
      type: json['type'],
      config: json['config'] != null
          ? Map<String, dynamic>.from(json['config'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'line_id': lineId,
      'name': name,
      'display_name': displayName,
      'type': type,
      'config': config,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
