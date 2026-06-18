import 'package:kinder_world/core/models/public_content.dart';

class LegalContentPayload {
  const LegalContentPayload({
    this.body,
    this.bodyAr,
    this.content,
    this.item,
  });

  final String? body;
  final String? bodyAr;
  final String? content;
  final PublicContentItem? item;

  String get resolvedBody {
    final directBody = (body ?? '').trim();
    if (directBody.isNotEmpty) return directBody;
    final fallbackContent = (content ?? '').trim();
    if (fallbackContent.isNotEmpty) return fallbackContent;
    final itemBodyEn = (item?.bodyEn ?? '').trim();
    if (itemBodyEn.isNotEmpty) return itemBodyEn;
    final itemBodyAr = (item?.bodyAr ?? '').trim();
    if (itemBodyAr.isNotEmpty) return itemBodyAr;
    return '';
  }

  String resolvedBodyForLanguageCode(String languageCode) {
    final isAr = languageCode.toLowerCase().startsWith('ar');

    // 1. Localized direct body field
    final directLocalized = isAr ? (bodyAr ?? '').trim() : (body ?? '').trim();
    if (directLocalized.isNotEmpty) return directLocalized;

    // 2. Item body for language
    final itemLocalized = isAr
        ? (item?.bodyAr ?? '').trim()
        : (item?.bodyEn ?? '').trim();
    if (itemLocalized.isNotEmpty) return itemLocalized;

    // 3. Alternate language fallback
    final itemAlternate = isAr
        ? (item?.bodyEn ?? '').trim()
        : (item?.bodyAr ?? '').trim();
    if (itemAlternate.isNotEmpty) return itemAlternate;

    return resolvedBody;
  }

  factory LegalContentPayload.fromJson(Map<String, dynamic> json) {
    final rawItem = json['item'];
    return LegalContentPayload(
      body: json['body']?.toString(),
      bodyAr: json['body_ar']?.toString(),
      content: json['content']?.toString(),
      item: rawItem is Map<String, dynamic>
          ? PublicContentItem.fromJson(rawItem)
          : rawItem is Map
              ? PublicContentItem.fromJson(Map<String, dynamic>.from(rawItem))
              : null,
    );
  }
}
