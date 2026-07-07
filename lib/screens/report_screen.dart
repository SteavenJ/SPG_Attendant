import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:spg_attendant/services/api_service.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    } else if (newValue.text.compareTo(oldValue.text) != 0) {
      String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (newText.isEmpty) {
        return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
      }
      
      final number = int.parse(newText);
      final newString = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(number);

      return TextEditingValue(
        text: newString,
        selection: TextSelection.collapsed(offset: newString.length),
      );
    }
    return newValue;
  }
}

class ReportScreen extends StatefulWidget {
  final ApiService apiService;

  const ReportScreen({Key? key, required this.apiService}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _lokasiController = TextEditingController();
  final _jamKerjaController = TextEditingController();
  final _produkController = TextEditingController();
  final _aktivitasController = TextEditingController();
  final _penjualanController = TextEditingController();
  final _totalTerjualController = TextEditingController();
  final _estimasiOmzetController = TextEditingController();
  final _stokAwalController = TextEditingController();
  final _terjualController = TextEditingController();
  final _stokAkhirController = TextEditingController();
  final _customerDitawarkanController = TextEditingController();
  final _orangTertarikController = TextEditingController();
  final _membeliController = TextEditingController();
  final _responCustomerController = TextEditingController();
  final _banyakCustomerCariController = TextEditingController();
  final _kendalaController = TextEditingController();
  final _kompetitorController = TextEditingController();
  final _saranController = TextEditingController();

  Map<String, String> _promotorNames = {};
  bool _isLoadingNames = true;
  bool _isSubmitting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('d-MMMM-yyyy').format(DateTime.now());
    _loadPromotorNames();

    _idController.addListener(_onIdChanged);
  }

  Future<void> _loadPromotorNames() async {
    final names = await widget.apiService.fetchPromotorNames();
    if (mounted) {
      setState(() {
        _promotorNames = names;
        _isLoadingNames = false;
        _onIdChanged();
      });
    }
  }

  void _onIdChanged() {
    final id = _idController.text.trim();
    if (_promotorNames.containsKey(id)) {
      _nameController.text = _promotorNames[id]!;
    } else {
      _nameController.text = '';
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _dateController.dispose();
    _lokasiController.dispose();
    _jamKerjaController.dispose();
    _produkController.dispose();
    _aktivitasController.dispose();
    _penjualanController.dispose();
    _totalTerjualController.dispose();
    _estimasiOmzetController.dispose();
    _stokAwalController.dispose();
    _terjualController.dispose();
    _stokAkhirController.dispose();
    _customerDitawarkanController.dispose();
    _orangTertarikController.dispose();
    _membeliController.dispose();
    _responCustomerController.dispose();
    _banyakCustomerCariController.dispose();
    _kendalaController.dispose();
    _kompetitorController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID tidak valid. Nama tidak ditemukan.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final reportData = {
      'timestamp': DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()),
      'id': _idController.text.trim(),
      'nama': _nameController.text.trim(),
      'tanggal': _dateController.text.trim(),
      'lokasi': _lokasiController.text.trim(),
      'jamKerja': _jamKerjaController.text.trim(),
      'produk': _produkController.text.trim(),
      'aktivitas': _aktivitasController.text.trim(),
      'penjualan': _penjualanController.text.trim(),
      'totalTerjual': _totalTerjualController.text.trim(),
      'estimasiOmzet': _estimasiOmzetController.text.trim(),
      'stokAwal': _stokAwalController.text.trim(),
      'terjual': _terjualController.text.trim(),
      'stokAkhir': _stokAkhirController.text.trim(),
      'customerDitawarkan': _customerDitawarkanController.text.trim(),
      'orangTertarik': _orangTertarikController.text.trim(),
      'membeli': _membeliController.text.trim(),
      'responCustomer': _responCustomerController.text.trim(),
      'banyakCustomerCari': _banyakCustomerCariController.text.trim(),
      'kendala': _kendalaController.text.trim(),
      'kompetitor': _kompetitorController.text.trim(),
      'saran': _saranController.text.trim(),
    };

    final success = await widget.apiService.submitDailyReport(reportData);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dikirim!')),
        );
        _formKey.currentState!.reset();
        _dateController.text = DateFormat('d-MMMM-yyyy').format(DateTime.now());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim laporan. Coba lagi.')),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.withOpacity(0.1) : null,
        ),
        validator: (value) {
          if (!readOnly && (value == null || value.trim().isEmpty)) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Harian SPG'),
        centerTitle: true,
      ),
      body: _isLoadingNames
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _idController,
                      label: 'ID SPG',
                      hintText: 'Masukkan ID Anda',
                      keyboardType: TextInputType.text,
                    ),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama SPG',
                      readOnly: true,
                    ),
                    _buildTextField(
                      controller: _dateController,
                      label: 'Tanggal',
                      readOnly: true,
                    ),
                    _buildTextField(
                      controller: _lokasiController,
                      label: 'Lokasi',
                      hintText: 'Contoh: GRAND MALL MAROS',
                    ),
                    _buildTextField(
                      controller: _jamKerjaController,
                      label: 'Jam Kerja',
                      hintText: 'Contoh: 8 jam/shift siang',
                    ),
                    _buildTextField(
                      controller: _produkController,
                      label: 'Produk',
                      hintText: 'Contoh: Superbed dan Lawrence',
                    ),
                    _buildTextField(
                      controller: _aktivitasController,
                      label: 'Aktivitas',
                      hintText: 'Contoh: Mempromosikan Brand Lawrance/Roon/Eco melalui Offline',
                      maxLines: 2,
                    ),
                    const Divider(height: 32),
                    Text('Data Penjualan', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(controller: _penjualanController, label: 'Penjualan (item)', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(
                          controller: _totalTerjualController, 
                          label: 'Total Terjual (Rp)', 
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                        )),
                      ],
                    ),
                    _buildTextField(
                      controller: _estimasiOmzetController,
                      label: 'Estimasi Omzet (Rp)',
                      hintText: 'Contoh: 3.000.000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(controller: _stokAwalController, label: 'Stok Awal', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(controller: _terjualController, label: 'Terjual', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(controller: _stokAkhirController, label: 'Stok Akhir', keyboardType: TextInputType.number)),
                      ],
                    ),
                    const Divider(height: 32),
                    Text('Data Customer', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(controller: _customerDitawarkanController, label: 'Ditawarkan', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(controller: _orangTertarikController, label: 'Tertarik', keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(controller: _membeliController, label: 'Membeli', keyboardType: TextInputType.number)),
                      ],
                    ),
                    _buildTextField(
                      controller: _responCustomerController,
                      label: 'Respon Customer',
                      hintText: 'Contoh: Baik, Customer tertarik',
                    ),
                    _buildTextField(
                      controller: _banyakCustomerCariController,
                      label: 'Banyak Customer Cari',
                      hintText: 'Contoh: matras under 2jtan',
                    ),
                    const Divider(height: 32),
                    Text('Lain-lain', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _kendalaController,
                      label: 'Kendala',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _kompetitorController,
                      label: 'Kompetitor',
                    ),
                    _buildTextField(
                      controller: _saranController,
                      label: 'Saran',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Kirim Laporan', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
