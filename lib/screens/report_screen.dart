import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/storage_service.dart';

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
  final StorageService storageService;

  const ReportScreen({
    super.key,
    required this.apiService,
    required this.storageService,
  });

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

  // Pencapaian State
  Map<String, dynamic>? _pencapaianData;
  bool _isLoadingPencapaian = false;
  String? _pencapaianError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _idController.addListener(_onIdChanged);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final savedId = await widget.storageService.getSavedEmployeeId();
    if (savedId != null && savedId.isNotEmpty && mounted) {
      _idController.text = savedId;
    }
    await _loadPromotorNames();
    _loadPencapaian();
  }

  Future<void> _loadPromotorNames({bool forceRefresh = false}) async {
    final names = await widget.apiService.fetchPromotorNames(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _promotorNames = names;
        _isLoadingNames = false;
        _onIdChanged();
      });
    }
  }

  Future<void> _loadPencapaian({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoadingPencapaian = true;
        _pencapaianError = null;
      });
    }

    final empId = _idController.text.trim();
    final data = await widget.apiService.fetchPencapaian(empId);

    if (mounted) {
      setState(() {
        _isLoadingPencapaian = false;
        if (data != null && data['status'] == 'success') {
          _pencapaianData = data;
          _pencapaianError = null;
        } else {
          _pencapaianError = data?['message'] ?? 'Belum dapat terhubung ke data pencapaian.';
        }
      });
    }
  }

  void _onIdChanged() {
    final id = _idController.text.trim();
    if (id.isNotEmpty) {
      widget.storageService.setSavedEmployeeId(id);
    }
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
        // Refresh data pencapaian setelah submit
        _loadPencapaian(showSpinner: false);
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

  String _formatRp(dynamic amount) {
    final num val = (amount is num) ? amount : (num.tryParse(amount.toString()) ?? 0);
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
  }

  Widget _buildPodiumPillar({
    required int rank,
    required String storeName,
    required double height,
    required Color accentColor,
    required List<Color> gradientColors,
    required String medalIcon,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Medali / Icon
          Text(
            medalIcon,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 4),
          // Nama Toko
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              storeName.isEmpty ? '-' : storeName,
              style: TextStyle(
                fontSize: rank == 1 ? 12 : 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          // Pilar Podium
          Container(
            height: height,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPencapaianTab() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoadingPencapaian && _pencapaianData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pencapaianData == null && _pencapaianError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _pencapaianError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadPencapaian(showSpinner: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final personal = _pencapaianData?['personal'] as Map<String, dynamic>?;
    final podiumList = (_pencapaianData?['podium'] as List<dynamic>?) ?? [];
    final leaderboardList = (_pencapaianData?['leaderboard'] as List<dynamic>?) ?? [];
    final periode = _pencapaianData?['periode']?.toString() ?? DateFormat('yyyy-MM').format(DateTime.now());

    // Cari podium data
    String firstStore = '';
    String secondStore = '';
    String thirdStore = '';

    for (var p in podiumList) {
      int r = p['rank'] ?? 0;
      String t = p['toko'] ?? '';
      if (r == 1) firstStore = t;
      if (r == 2) secondStore = t;
      if (r == 3) thirdStore = t;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadPromotorNames(forceRefresh: true);
        await _loadPencapaian(showSpinner: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KARTU IDENTITAS & TARGET PRIBADI TOKO
            if (personal != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
                        : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${personal['name'] ?? 'SPG'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.storefront, size: 16, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    personal['toko'] ?? '-',
                                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (personal['rank'] != null && personal['rank'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Rank #${personal['rank']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Toko', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                _formatRp(personal['target'] ?? 0),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Realisasi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                _formatRp(personal['actual'] ?? 0),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2 KARTU INDIKATOR (PENCAPAIAN & KEKURANGAN)
              Row(
                children: [
                  // Kartu Pencapaian
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'PENCAPAIAN',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                              Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 20),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(personal['percentage'] ?? personal['persentase'] ?? 0).toString()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Target tercapai',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Kartu Kekurangan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'KEKURANGAN',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                              Icon(Icons.trending_down_rounded, color: Color(0xFFEF4444), size: 20),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '- ${(personal['shortage'] ?? personal['kekurangan'] ?? 0).toString()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Menuju 100%',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Prompt jika ID belum ada
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Masukkan ID Anda di tab Penjualan untuk melihat target dan pencapaian pribadi toko Anda.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 2. PODIUM JUARA (TOP 3 TOKO)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'PODIUM TOKO',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          periode,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Podium Stepped Row
                  SizedBox(
                    height: 220,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // RANK 2 (Silver)
                        _buildPodiumPillar(
                          rank: 2,
                          storeName: secondStore,
                          height: 90,
                          accentColor: const Color(0xFF94A3B8),
                          gradientColors: [const Color(0xFF94A3B8), const Color(0xFF64748B)],
                          medalIcon: '🥈',
                        ),
                        // RANK 1 (Gold)
                        _buildPodiumPillar(
                          rank: 1,
                          storeName: firstStore,
                          height: 130,
                          accentColor: const Color(0xFFF59E0B),
                          gradientColors: [const Color(0xFFFBBF24), const Color(0xFFD97706)],
                          medalIcon: '🥇',
                        ),
                        // RANK 3 (Bronze)
                        _buildPodiumPillar(
                          rank: 3,
                          storeName: thirdStore,
                          height: 65,
                          accentColor: const Color(0xFFD97706),
                          gradientColors: [const Color(0xFFD97706), const Color(0xFFB45309)],
                          medalIcon: '🥉',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. LEADERBOARD (Peringkat 4 ke Bawah - Nama Toko Saja)
            if (leaderboardList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Peringkat Toko Lainnya',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ...leaderboardList.map((item) {
                final rank = item['rank'] ?? 0;
                final toko = item['toko'] ?? '-';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.storefront_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          toko,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ],
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
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: () {
                _loadPromotorNames();
                _loadPencapaian(showSpinner: true);
              },
            ),
          ],
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

            // TAB 2: PENCAPAIAN
            _buildPencapaianTab(),
          ],
        ),
      ),
    );
  }
}
