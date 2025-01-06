import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilterReminderScreen extends StatefulWidget {
  const FilterReminderScreen({super.key});

  @override
  State<FilterReminderScreen> createState() => _FilterReminderScreenState();
}

class _FilterReminderScreenState extends State<FilterReminderScreen> {
  static const String LAST_REPLACEMENT_KEY = 'last_replacement_date';
  static const String FILTER_DURATION_KEY = 'filter_duration_days';
  late DateTime lastReplacementDate;
  late Duration filterDuration;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReplacementMillis = prefs.getInt(LAST_REPLACEMENT_KEY);
    final durationDays =
        prefs.getInt(FILTER_DURATION_KEY) ?? 90; // Default 90 hari

    setState(() {
      if (lastReplacementMillis != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(lastReplacementMillis);
        // Mengatur waktu ke 00:00:00
        lastReplacementDate = DateTime(date.year, date.month, date.day);
      } else {
        final now = DateTime.now();
        lastReplacementDate = DateTime(now.year, now.month, now.day);
      }
      filterDuration = Duration(days: durationDays);
      isLoading = false;
    });
  }

  Future<void> _saveLastReplacementDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_REPLACEMENT_KEY, date.millisecondsSinceEpoch);
  }

  Future<void> _updateFilterDuration(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(FILTER_DURATION_KEY, days);
    setState(() {
      filterDuration = Duration(days: days);
    });
  }

  DateTime get nextReplacementDate => lastReplacementDate.add(filterDuration);

  bool get isReplacementDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return nextReplacementDate.difference(today).inDays <= 7;
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return nextReplacementDate.difference(today).inDays;
  }

  void updateFilterDate() async {
    // Mengambil tanggal hari ini dan mengatur waktu ke 00:00:00
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      lastReplacementDate = today;
    });
    await _saveLastReplacementDate(today);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal penggantian filter berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showDurationPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Durasi Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pilih durasi pergantian filter:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: filterDuration.inDays,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('1 Bulan (30 hari)')),
                DropdownMenuItem(value: 60, child: Text('2 Bulan (60 hari)')),
                DropdownMenuItem(value: 90, child: Text('3 Bulan (90 hari)')),
                DropdownMenuItem(value: 120, child: Text('4 Bulan (120 hari)')),
                DropdownMenuItem(value: 150, child: Text('5 Bulan (150 hari)')),
                DropdownMenuItem(value: 180, child: Text('6 Bulan (180 hari)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateFilterDuration(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengingat Filter',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: _showDurationPicker,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F9FF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 20),
              _buildDateInfoCard(),
              const SizedBox(height: 20),
              _buildMaintenanceCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildCircularProgress(),
              const SizedBox(height: 24),
              Text(
                isReplacementDue
                    ? 'Segera Ganti Filter!'
                    : 'Filter dalam Kondisi Baik',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isReplacementDue ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$daysRemaining hari sebelum penggantian berikutnya',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularProgress() {
    final double progress = daysRemaining / filterDuration.inDays;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0), // Memastikan nilai antara 0 dan 1
            strokeWidth: 12,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              isReplacementDue ? Colors.red : Colors.blue,
            ),
          ),
        ),
        Column(
          children: [
            Text(
              '$daysRemaining',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const Text(
              'Hari',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildDateRow(
                'Penggantian Terakhir',
                lastReplacementDate,
                Icons.history,
                Colors.blue,
              ),
              const Divider(height: 32),
              _buildDateRow(
                'Penggantian Berikutnya',
                nextReplacementDate,
                Icons.event,
                Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(
      String label, DateTime date, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              Text(
                DateFormat('dd MMMM yyyy').format(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pemeliharaan Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: updateFilterDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Perbarui Tanggal Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
