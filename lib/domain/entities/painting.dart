class Painting {
  final String? id;
  final String prompt;
  final String? negativePrompt;
  final String? imageUrl;
  final int? width;
  final int? height;
  final String? style;
  final String? status;
  final DateTime? createdAt;

  const Painting({
    this.id,
    required this.prompt,
    this.negativePrompt,
    this.imageUrl,
    this.width,
    this.height,
    this.style,
    this.status,
    this.createdAt,
  });
}
