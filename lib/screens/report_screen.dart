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

  // Identitas & Tanggal
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();

  // Lawrence
  final _lawQtyOsController = TextEditingController();
  final _lawQtyNhController = TextEditingController();
  final _lawValueController = TextEditingController();
  final _lawNoSoController = TextEditingController();

  // Superbed
  final _sbValueController = TextEditingController();
  final _sbNoSoController = TextEditingController();

  // Sofa
  final _sofaQtyController = TextEditingController();
  final _sofaValueController = TextEditingController();
  final _sofaNoSoController = TextEditingController();

  // Bedding / Busa
  final _bedValueController = TextEditingController();
  final _bedNoSoController = TextEditingController();

  Map<String, String> _promotorNames = {};
  bool _isLoadingNames = true;
  bool _isSubmitting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

    _lawQtyOsController.dispose();
    _lawQtyNhController.dispose();
    _lawValueController.dispose();
    _lawNoSoController.dispose();

    _sbValueController.dispose();
    _sbNoSoController.dispose();

    _sofaQtyController.dispose();
    _sofaValueController.dispose();
    _sofaNoSoController.dispose();

    _bedValueController.dispose();
    _bedNoSoController.dispose();

    super.dispose();
  }

  int _parseNumber(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.isEmpty ? 0 : int.parse(clean);
  }

  void _resetFormFields() {
    _formKey.currentState?.reset();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _lawQtyOsController.clear();
    _lawQtyNhController.clear();
    _lawValueController.clear();
    _lawNoSoController.clear();

    _sbValueController.clear();
    _sbNoSoController.clear();

    _sofaQtyController.clear();
    _sofaValueController.clear();
    _sofaNoSoController.clear();

    _bedValueController.clear();
    _bedNoSoController.clear();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID SPG tidak valid atau nama tidak ditemukan!')),
      );
      return;
    }

    final lawQtyOs = _parseNumber(_lawQtyOsController.text);
    final lawQtyNh = _parseNumber(_lawQtyNhController.text);
    final lawValue = _parseNumber(_lawValueController.text);
    final lawNoSo = _lawNoSoController.text.trim();

    final sbValue = _parseNumber(_sbValueController.text);
    final sbNoSo = _sbNoSoController.text.trim();

    final sofaQty = _parseNumber(_sofaQtyController.text);
    final sofaValue = _parseNumber(_sofaValueController.text);
    final sofaNoSo = _sofaNoSoController.text.trim();

    final bedValue = _parseNumber(_bedValueController.text);
    final bedNoSo = _bedNoSoController.text.trim();

    final totalValue = lawValue + sbValue + sofaValue + bedValue;
    final totalQty = lawQtyOs + lawQtyNh + sofaQty;

    if (totalValue == 0 && totalQty == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap masukkan minimal satu data penjualan (Qty / Nilai Penjualan)!')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final salesData = {
      'id': _idController.text.trim(),
      'nama': _nameController.text.trim(),
      'lawQtyOs': lawQtyOs,
      'lawQtyNh': lawQtyNh,
      'lawValue': lawValue,
      'lawNoSo': lawNoSo,
      'sbValue': sbValue,
      'sbNoSo': sbNoSo,
      'sofaQty': sofaQty,
      'sofaValue': sofaValue,
      'sofaNoSo': sofaNoSo,
      'bedValue': bedValue,
      'bedNoSo': bedNoSo,
    };

    final success = await widget.apiService.submitSalesReport(salesData);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Laporan Penjualan berhasil dicatat!'),
          ),
        );
        _resetFormFields();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Gagal mengirim laporan penjualan. Coba lagi.'),
          ),
        );
      }
    }
  }

  Widget _buildBrandCard({
    required String brandTitle,
    required Color accentColor,
    required List<Widget> children,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            brandTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    String? prefixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixText: prefixText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.withOpacity(0.08) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan & Pencapaian'),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: Color(0xFF10B981),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                icon: Icon(Icons.point_of_sale),
                text: 'Penjualan',
              ),
              Tab(
                icon: Icon(Icons.emoji_events_outlined),
                text: 'Pencapaian',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: PENJUALAN
            _isLoadingNames
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // IDENTITAS
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Identitas SPG & Tanggal',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _idController,
                                  label: 'ID SPG',
                                  hintText: 'Masukkan ID Anda',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                                _buildField(
                                  controller: _nameController,
                                  label: 'Nama SPG',
                                  readOnly: true,
                                ),
                                _buildField(
                                  controller: _dateController,
                                  label: 'Tanggal (Hari Ini)',
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),

                          // BRAND 1: LAWRENCE (Yellow/Orange)
                          _buildBrandCard(
                            brandTitle: 'LAWRENCE',
                            accentColor: const Color(0xFFF59E0B),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildField(
                                      controller: _lawQtyOsController,
                                      label: 'QTY OS',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildField(
                                      controller: _lawQtyNhController,
                                      label: 'QTY NH',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                ],
                              ),
                              _buildField(
                                controller: _lawValueController,
                                label: 'Value Penjualan',
                                prefixText: 'Rp ',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                              ),
                              _buildField(
                                controller: _lawNoSoController,
                                label: 'Nomor SO',
                                hintText: 'Contoh: SO-12345',
                              ),
                            ],
                          ),

                          // BRAND 2: SUPERBED (Coral/Red-Orange)
                          _buildBrandCard(
                            brandTitle: 'SUPERBED',
                            accentColor: const Color(0xFFEA580C),
                            children: [
                              _buildField(
                                controller: _sbValueController,
                                label: 'Value Penjualan',
                                prefixText: 'Rp ',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                              ),
                              _buildField(
                                controller: _sbNoSoController,
                                label: 'Nomor SO',
                                hintText: 'Contoh: SO-67890',
                              ),
                            ],
                          ),

                          // BRAND 3: SOFA (Slate/Grey)
                          _buildBrandCard(
                            brandTitle: 'SOFA',
                            accentColor: const Color(0xFF64748B),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: _buildField(
                                      controller: _sofaQtyController,
                                      label: 'QTY',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: _buildField(
                                      controller: _sofaValueController,
                                      label: 'Value Penjualan',
                                      prefixText: 'Rp ',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
                                    ),
                                  ),
                                ],
                              ),
                              _buildField(
                                controller: _sofaNoSoController,
                                label: 'Nomor SO',
                                hintText: 'Contoh: SO-11223',
                              ),
                            ],
                          ),

                          // BRAND 4: BEDDING / BUSA (Purple)
                          _buildBrandCard(
                            brandTitle: 'BEDDING / BUSA',
                            accentColor: const Color(0xFF8B5CF6),
                            children: [
                              _buildField(
                                controller: _bedValueController,
                                label: 'Value Penjualan',
                                prefixText: 'Rp ',
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                              ),
                              _buildField(
                                controller: _bedNoSoController,
                                label: 'Nomor SO',
                                hintText: 'Contoh: SO-44556',
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _isSubmitting ? null : _submitForm,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.white),
                              label: Text(
                                _isSubmitting ? 'Mengirim Data...' : 'Kirim Laporan Penjualan',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

            // TAB 2: PENCAPAIAN (Placeholder)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 64,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pencapaian Target SPG',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sub-halaman Pencapaian sedang dalam proses pembangunan dan akan segera hadir.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
