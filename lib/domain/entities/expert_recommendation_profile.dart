class ExpertRecommendationProfile {
  const ExpertRecommendationProfile({required this.facilityId,required this.experienceScore,required this.uniquenessScore,required this.scarcityScore,required this.note,this.validFrom,this.validUntil});
  factory ExpertRecommendationProfile.fromJson(Map<String,dynamic> json)=>ExpertRecommendationProfile(facilityId:json['facilityId'] as String? ?? '',experienceScore:(json['experienceScore'] as num?)?.toInt() ?? 50,uniquenessScore:(json['uniquenessScore'] as num?)?.toInt() ?? 50,scarcityScore:(json['scarcityScore'] as num?)?.toInt() ?? 0,note:json['note'] as String? ?? '',validFrom:_parseDate(json['validFrom']),validUntil:_parseDate(json['validUntil']));
  final String facilityId; final int experienceScore; final int uniquenessScore; final int scarcityScore; final String note; final DateTime? validFrom; final DateTime? validUntil;
  bool appliesOn(DateTime date){final day=DateTime(date.year,date.month,date.day);if(validFrom!=null&&day.isBefore(validFrom!))return false;if(validUntil!=null&&day.isAfter(validUntil!))return false;return true;}
  static DateTime? _parseDate(dynamic raw){if(raw is! String||raw.trim().isEmpty)return null;final p=DateTime.tryParse(raw.trim());return p==null?null:DateTime(p.year,p.month,p.day);}
}
