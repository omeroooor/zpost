class PublicKeyEntry {
  final String id;
  final String publicKey;
  final String label;

  PublicKeyEntry({
    required this.id,
    required this.publicKey,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'publicKey': publicKey,
    'label': label,
  };

  factory PublicKeyEntry.fromJson(Map<String, dynamic> json) => PublicKeyEntry(
    id: json['id'],
    publicKey: json['publicKey'],
    label: json['label'],
  );
}
