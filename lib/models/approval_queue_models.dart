class RefundRequest {
  final int id;
  final String patientName;
  final double amount;
  final String requestDate;
  final String reason;
  final String status;
  final String priority;
  final String requestedBy;
  final String department;
  final String patientType;
  final String? refundNote;
  final String? approvalNote;

  RefundRequest({
    required this.id,
    required this.patientName,
    required this.amount,
    required this.requestDate,
    required this.reason,
    required this.status,
    required this.priority,
    required this.requestedBy,
    required this.department,
    required this.patientType,
    this.refundNote,
    this.approvalNote,
  });

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id: json['id'] ?? json['refundId'] ?? 0,
      patientName: json['patientName'] ?? json['patient'] ?? 'Unknown Patient',
      amount: (json['amount'] ?? json['refundAmount'] ?? 0.0).toDouble(),
      requestDate: json['requestDate'] ?? json['date'] ?? '',
      reason: json['reason'] ?? json['refundReason'] ?? '',
      status: json['status'] ?? 'Pending',
      priority: json['priority'] ?? 'Medium',
      requestedBy: json['requestedBy'] ?? json['requested_by'] ?? '',
      department: json['department'] ?? json['dept'] ?? '',
      patientType: json['patientType'] ?? json['patient_type'] ?? '',
      refundNote: json['refundNote'] ?? json['note'] ?? '',
      approvalNote: json['approvalNote'] ?? json['approval_note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'amount': amount,
      'requestDate': requestDate,
      'reason': reason,
      'status': status,
      'priority': priority,
      'requestedBy': requestedBy,
      'department': department,
      'patientType': patientType,
      'refundNote': refundNote,
      'approvalNote': approvalNote,
    };
  }
}

class DiscountRequest {
  final int id;
  final String patientName;
  final double originalAmount;
  final double discountedAmount;
  final int discountPercent;
  final String requestDate;
  final String reason;
  final String status;
  final String requestedBy;
  final String approvedBy;

  DiscountRequest({
    required this.id,
    required this.patientName,
    required this.originalAmount,
    required this.discountedAmount,
    required this.discountPercent,
    required this.requestDate,
    required this.reason,
    required this.status,
    required this.requestedBy,
    required this.approvedBy,
  });

  factory DiscountRequest.fromJson(Map<String, dynamic> json) {
    final original = (json['originalAmount'] ?? json['total_amount'] ?? 0.0).toDouble();
    final discounted = (json['discountedAmount'] ?? json['amount'] ?? 0.0).toDouble();
    final percent = (json['discountPercent'] ?? json['discount_percent'] ?? 0).toInt();

    return DiscountRequest(
      id: json['id'] ?? json['discountId'] ?? 0,
      patientName: json['patientName'] ?? json['patient'] ?? 'Unknown Patient',
      originalAmount: original,
      discountedAmount: discounted,
      discountPercent: percent,
      requestDate: json['requestDate'] ?? json['date'] ?? '',
      reason: json['reason'] ?? json['discountReason'] ?? '',
      status: json['status'] ?? 'Pending',
      requestedBy: json['requestedBy'] ?? json['requested_by'] ?? '',
      approvedBy: json['approvedBy'] ?? json['approved_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'originalAmount': originalAmount,
      'discountedAmount': discountedAmount,
      'discountPercent': discountPercent,
      'requestDate': requestDate,
      'reason': reason,
      'status': status,
      'requestedBy': requestedBy,
      'approvedBy': approvedBy,
    };
  }
}