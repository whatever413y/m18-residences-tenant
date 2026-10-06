import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The latest bill's payment and receipt: View buttons for both, and, until the owner attaches a receipt, an
/// optional "Upload payment" that picks a screenshot or photo, converts it in the browser and hands it to [onUpload].
///
/// Test ids: `tenant-upload-payment`, `tenant-payment-link`, `tenant-receipt-link`.
class PaymentSection extends StatefulWidget {
  final Bill bill;
  final String tenantName;
  final AuthApi authApi;
  final bool uploading;
  final bool uploaded;
  final String? uploadError;
  final ValueChanged<PreparedReceipt> onUpload;

  const PaymentSection({
    super.key,
    required this.bill,
    required this.tenantName,
    required this.authApi,
    required this.uploading,
    required this.uploaded,
    required this.uploadError,
    required this.onUpload,
  });

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  bool _preparing = false;
  String? _error;

  Future<void> _pick() async {
    final ({String name, Uint8List bytes})? file;
    try {
      file = await pickFile(receiptExtensions);
    } catch (e) {
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (file == null || !mounted) return;

    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final prepared = await prepareReceipt(file.name, file.bytes);
      if (mounted) widget.onUpload(prepared);
    } catch (e) {
      if (mounted) setState(() => _error = e is ReceiptException ? e.message : 'Could not read the file: $e');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final theme = Theme.of(context);
    final busy = _preparing || widget.uploading;
    final error = _error ?? widget.uploadError;
    final canUpload = bill.status != BillStatus.paid;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
            // Once a payment is under verification or paid, the status badge on the bill says it all.
            if (bill.status == BillStatus.unpaid) ...[const SizedBox(height: 8), const Text('Upload a photo of your payment for confirmation')],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canUpload)
                  Semantics(
                    container: true,
                    identifier: 'tenant-upload-payment',
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: busy ? null : _pick,
                      icon: busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload),
                      label: Text(bill.hasPayment ? 'Change payment' : 'Upload payment'),
                    ),
                  ),
                if (bill.hasPayment)
                  Semantics(
                    container: true,
                    identifier: 'tenant-payment-link',
                    child: BillFileButton(
                      kind: BillFileKind.payment,
                      tenantName: widget.tenantName,
                      fileUrl: bill.paymentUrl,
                      fetchSignedFile: widget.authApi.signedTenantPaymentUrl,
                    ),
                  ),
                if (bill.hasReceipt)
                  Semantics(
                    container: true,
                    identifier: 'tenant-receipt-link',
                    child: BillFileButton(
                      kind: BillFileKind.receipt,
                      tenantName: widget.tenantName,
                      fileUrl: bill.receiptUrl,
                      fetchSignedFile: widget.authApi.signedReceiptUrl,
                    ),
                  ),
              ],
            ),
            if (busy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_preparing ? 'Preparing the image...' : 'Uploading...', style: const TextStyle(fontStyle: FontStyle.italic)),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
              )
            else if (widget.uploaded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Payment uploaded.',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
