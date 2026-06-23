class ImageModel {
  final String id;
  final String name;
  final String provider;
  final String description;
  final bool isDefault;
  final List<String> supportedSizes;
  final List<String> supportedStyles;
  final Map<String, dynamic> config;

  const ImageModel({
    required this.id,
    required this.name,
    required this.provider,
    this.description = '',
    this.isDefault = false,
    this.supportedSizes = const ['1024x1024'],
    this.supportedStyles = const [],
    this.config = const {},
  });

  ImageModel copyWith({
    String? id,
    String? name,
    String? provider,
    String? description,
    bool? isDefault,
    List<String>? supportedSizes,
    List<String>? supportedStyles,
    Map<String, dynamic>? config,
  }) {
    return ImageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      supportedSizes: supportedSizes ?? this.supportedSizes,
      supportedStyles: supportedStyles ?? this.supportedStyles,
      config: config ?? this.config,
    );
  }
}
