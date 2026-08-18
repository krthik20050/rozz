import 'package:rozz/features/insights/domain/entities/sender_label.dart';

class SenderLabelModel extends SenderLabel {
  const SenderLabelModel({required super.key, required super.label});

  factory SenderLabelModel.fromMap(Map<String, dynamic> map) {
    return SenderLabelModel(
      key: map['key'] as String,
      label: map['label'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
    };
  }
}
