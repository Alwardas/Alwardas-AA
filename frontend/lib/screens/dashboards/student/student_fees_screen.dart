import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/api_config.dart';

class StudentFeesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentFeesScreen({super.key, required this.userData});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _ledger;

  @override
  void initState() {
    super.initState();
    _fetchFeeSummary();
  }

  Future<void> _fetchFeeSummary() async {
    setState(() => _isLoading = true);
    final userId = widget.userData['id']?.toString() ?? widget.userData['login_id']?.toString() ?? '';
    try {
      final result = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/finance/student-summary?userId=$userId',
      );
      if (result.success && result.data != null) {
        setState(() {
          _ledger = result.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching student fees summary: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _paySimulated() async {
    final studentId = widget.userData['login_id']?.toString() ?? '';
    final pendingAmount = _ledger?['pendingAmount'] ?? 0.0;
    if (pendingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fees are already cleared!")),
      );
      return;
    }

    // Ask amount to pay
    double payAmount = pendingAmount;
    final controller = TextEditingController(text: payAmount.toString());

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Simulate Payment Gateway"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter amount to checkout:"),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This will simulate UPI/NetBanking card processor authorization.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Authorise & Pay")),
        ],
      ),
    );

    if (confirm != true) return;

    final inputAmt = double.tryParse(controller.text) ?? 0.0;
    if (inputAmt <= 0 || inputAmt > pendingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/finance/pay-simulated'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'studentId': studentId,
          'amount': inputAmt,
          'paymentMode': 'UPI / NetBanking',
          'remarks': 'Simulated app student checkout'
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Simulated payment successful! Receipt generated.")),
        );
        _fetchFeeSummary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment failed: ${data['message'] ?? ''}")),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Simulated pay error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Simulated gateway error")),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showWhyMyFeeDialog() {
    if (_ledger == null) return;
    
    final breakdown = List<dynamic>.from(_ledger!['breakdown'] ?? []);
    final double tuition = breakdown.firstWhere((e) => e['category'] == 'Tuition Fee', orElse: () => {'amount': 0.0})['amount'] ?? 0.0;
    final double lab = breakdown.firstWhere((e) => e['category'] == 'Lab Fee', orElse: () => {'amount': 0.0})['amount'] ?? 0.0;
    final double exam = breakdown.firstWhere((e) => e['category'] == 'Exam Fee', orElse: () => {'amount': 0.0})['amount'] ?? 0.0;
    final double transport = breakdown.firstWhere((e) => e['category'] == 'Transport Fee', orElse: () => {'amount': 0.0})['amount'] ?? 0.0;
    final double scholarship = _ledger!['scholarshipAmount'] ?? 0.0;
    final double finalAmount = _ledger!['totalFee'] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Why Is My Fee This Amount?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWhyRow("Tuition Fee", tuition),
            _buildWhyRow("Lab Fee", lab),
            _buildWhyRow("Exam Fee", exam),
            _buildWhyRow("Transport Fee", transport),
            const Divider(),
            _buildWhyRow("Scholarship Reduction", -scholarship, isScholarship: true),
            const Divider(thickness: 1.5),
            _buildWhyRow("Final Total Demand", finalAmount, isTotal: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyRow(String label, double val, {bool isScholarship = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            isScholarship ? "-₹${val.abs().toStringAsFixed(0)}" : "₹${val.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isScholarship ? Colors.indigoAccent : (isTotal ? Colors.cyan : Colors.white)
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _fetchFeeSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    if (_ledger == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Fees Portal")),
        body: RefreshIndicator(
          onRefresh: _fetchFeeSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: const Center(child: Text("Fee details not configured. Contact accounts department.")),
            ),
          ),
        ),
      );
    }

    final double totalFee = _ledger!['totalFee'] ?? 0.0;
    final double paidAmount = _ledger!['paidAmount'] ?? 0.0;
    final double pendingAmount = _ledger!['pendingAmount'] ?? 0.0;
    
    // Progress calculation
    final progress = totalFee > 0 ? (paidAmount / totalFee) : 0.0;

    final breakdown = List<dynamic>.from(_ledger!['breakdown'] ?? []);
    final payments = List<dynamic>.from(_ledger!['paymentHistory'] ?? []);
    final changes = List<dynamic>.from(_ledger!['changeHistory'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text("College Fee Transparency"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeeSummary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Current Fee Ledger Summary", style: TextStyle(color: isDark ? Colors.cyan : Colors.blue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text("Total Demand: ₹${totalFee.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
                    Text("Paid Coverage: ₹${paidAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: Colors.green)),
                    Text("Pending Balance: ₹${pendingAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("${(progress * 100).toStringAsFixed(0)}% Fee Cleared", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _paySimulated,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Pay Now", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _showWhyMyFeeDialog,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.cyan),
                            ),
                            child: const Text("Why this amount?"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            Text("Breakdown Categories", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // Detailed breakdowns list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: breakdown.length,
              itemBuilder: (context, index) {
                final b = breakdown[index];
                return ListTile(
                  title: Text(b['category']),
                  subtitle: Text(b['remarks'] ?? 'Base Setup'),
                  trailing: Text("₹${(b['amount'] as num).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),

            const SizedBox(height: 24),
            Text("Receipts Payment History", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            payments.isEmpty
                ? const Text("No transactions recorded yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final p = payments[index];
                      final DateTime date = DateTime.parse(p['transactionDate']);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: Colors.green),
                          title: Text(p['receiptNumber']),
                          subtitle: Text("${p['paymentMode']} • ${DateFormat('dd-MMM-yyyy').format(date)}"),
                          trailing: Text("₹${(p['amount'] as num).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 24),
            Text("Fee Modifications History", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            changes.isEmpty
                ? const Text("No adjustments made to your base structures.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: changes.length,
                    itemBuilder: (context, index) {
                      final c = changes[index];
                      final DateTime date = DateTime.parse(c['updatedAt']);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c['category'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(DateFormat('dd-MMM-yyyy').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text("₹${c['previousAmount'].toStringAsFixed(0)} ➔ ₹${c['newAmount'].toStringAsFixed(0)}", style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Reason: ${c['reason']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              Text("Updated By: ${c['updatedByName']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 60),
          ],
        ),
      ),
      ),
    );
  }
}
