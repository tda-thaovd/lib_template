class SystemFeatures {
  SystemFeatures(this.hasBackCamera, this.hasFrontCamera);

  factory SystemFeatures.fromJson(Map<String, dynamic> features) =>
      SystemFeatures(features['hasBackCamera'] ?? false,
          features['hasFrontCamera'] ?? false);

  final bool hasFrontCamera;
  final bool hasBackCamera;
}
