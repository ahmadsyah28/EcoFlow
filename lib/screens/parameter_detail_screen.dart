import 'package:flutter/material.dart';

class ParameterDetailScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> waterParameters;
  final DateTime lastUpdatedTime;

  const ParameterDetailScreen({
    Key? key,
    required this.waterParameters,
    required this.lastUpdatedTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Parameter',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F9FF)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: waterParameters.length,
          itemBuilder: (context, index) {
            final parameter = waterParameters.entries.elementAt(index);
            final isNormal = parameter.value['value'] >= parameter.value['minRange'] &&
                parameter.value['value'] <= parameter.value['maxRange'];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNormal ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isNormal 
                                ? Colors.green.withOpacity(0.1) 
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            parameter.value['icon'],
                            color: isNormal ? Colors.green : Colors.red,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parameter.key,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isNormal ? 'Status: Normal' : 'Status: Perlu Perhatian',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isNormal ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      'Nilai Saat Ini',
                      '${parameter.value['value']}${parameter.value['unit']}',
                      isNormal ? Colors.green : Colors.red,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      'Batas Minimum',
                      '${parameter.value['minRange']}${parameter.value['unit']}',
                      Colors.grey[700]!,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Batas Maksimum',
                      '${parameter.value['maxRange']}${parameter.value['unit']}',
                      Colors.grey[700]!,
                    ),
                    const SizedBox(height: 16),
                    _buildParameterDescription(parameter.key),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildParameterDescription(String parameter) {
    String description = '';
    switch (parameter) {
      case 'pH':
        description = 'pH mengukur tingkat keasaman air. Air minum yang baik memiliki pH netral antara 6.5-7.5.';
        break;
      case 'TDS':
        description = 'Total Dissolved Solids (TDS) mengukur jumlah total mineral, garam, dan logam terlarut dalam air.';
        break;
      case 'Turbidity':
        description = 'Kekeruhan (Turbidity) mengukur tingkat kejernihan air. Semakin rendah nilai NTU, semakin jernih airnya.';
        break;
      case 'Temperature':
        description = 'Suhu air mempengaruhi rasa dan kualitas air secara keseluruhan.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        description,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ),
    );
  }
}