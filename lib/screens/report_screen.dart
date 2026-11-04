import 'dart:async';
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

enum SalesViewMode { input, list }

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

class _ReportScreenState extends State<ReportScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  Timer? _debounceTimer;

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

  // View Mode Penjualan (Input Form atau Daftar Penjualan)
  SalesViewMode _salesViewMode = SalesViewMode.input;

  // Daftar Penjualan State
  List<dynamic> _salesHistory = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  int _historyTotalAmount = 0;
  int _historyTotalTransactions = 0;
  List<String> _availableStores = [];
  String? _selectedFilterStore;
  String? _selectedFilterDate;
  bool _isAdminHistory = false;

  // Pencapaian State
  Map<String, dynamic>? _pencapaianData;
  bool _isLoadingPencapaian = false;
  String? _pencapaianError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _idController.addListener(_onIdChanged);
    _loadInitialData();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && mounted) {
      _loadPencapaian(showSpinner: _pencapaianData == null);
    } else if (_tabController.index == 0 && _salesViewMode == SalesViewMode.list && mounted) {
      _loadSalesHistory(showSpinner: _salesHistory.isEmpty);
    }
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

  Future<void> _loadSalesHistory({bool showSpinner = true}) async {
    final empId = _idController.text.trim();
    if (empId.isEmpty) {
      if (mounted) {
        setState(() {
          _salesHistory = [];
          _historyTotalAmount = 0;
          _historyTotalTransactions = 0;
          _historyError = 'Silakan masukkan ID terlebih dahulu di form Penjualan.';
        });
      }
      return;
    }

    if (showSpinner && mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
      });
    }

    final data = await widget.apiService.fetchSalesHistory(
      employeeId: empId,
      toko: _selectedFilterStore,
      tanggal: _selectedFilterDate,
    );

    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (data != null && data['status'] == 'success') {
          _salesHistory = data['data'] as List<dynamic>? ?? [];
          _historyTotalAmount = (data['totalAmount'] as num?)?.toInt() ?? 0;
          _historyTotalTransactions = (data['totalCount'] as num?)?.toInt() ?? _salesHistory.length;
          _isAdminHistory = data['isAdmin'] == true || empId == '101';
          if (data['stores'] != null) {
            _availableStores = List<String>.from(data['stores']);
          }
          _historyError = null;
        } else {
          _historyError = data?['message'] ?? 'Gagal memuat riwayat penjualan.';
        }
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(value).trim();
  }

  String _formatIndonesianDate(String rawDate) {
    try {
      DateTime dt;
      if (rawDate.contains('T')) {
        dt = DateTime.parse(rawDate);
      } else if (rawDate.contains(' ')) {
        final parts = rawDate.split(' ')[0].split('-');
        dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } else {
        final parts = rawDate.split('-');
        dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }

      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];

      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
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

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _loadPencapaian(showSpinner: false);
        if (_salesViewMode == SalesViewMode.list) {
          _loadSalesHistory(showSpinner: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: const Text('Laporan Penjualan berhasil dicatat!'),
            action: SnackBarAction(
              label: 'Lihat Daftar',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _salesViewMode = SalesViewMode.list;
                });
                _loadSalesHistory();
              },
            ),
          ),
        );
        _resetFormFields();
        // Refresh data pencapaian dan riwayat setelah submit
        _loadPencapaian(showSpinner: false);
        _loadSalesHistory(showSpinner: false);
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
    num? percentage,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (percentage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${percentage.toString()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ],
              ],
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

    final bool isAdmin = _pencapaianData?['isAdmin'] == true || personal?['isAdmin'] == true;

    // Cari podium data
    String firstStore = '';
    num? firstPct;
    String secondStore = '';
    num? secondPct;
    String thirdStore = '';
    num? thirdPct;

    for (var p in podiumList) {
      int r = p['rank'] ?? 0;
      String t = p['toko'] ?? '';
      num? pct = (p['percentage'] ?? p['persentase']) as num?;
      if (r == 1) {
        firstStore = t;
        firstPct = pct;
      }
      if (r == 2) {
        secondStore = t;
        secondPct = pct;
      }
      if (r == 3) {
        thirdStore = t;
        thirdPct = pct;
      }
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
                              if (isAdmin) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.admin_panel_settings, size: 14, color: Colors.black87),
                                      SizedBox(width: 4),
                                      Text(
                                        'MODE ADMIN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Text(
                                'Halo, ${personal['name'] ?? (isAdmin ? 'Admin' : 'SPG')}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(isAdmin ? Icons.analytics_outlined : Icons.storefront, size: 16, color: Colors.white70),
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
                        if (!isAdmin && personal['rank'] != null && personal['rank'] > 0)
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
                              Text(
                                isAdmin ? 'Total Target Semua Toko' : 'Target Toko',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
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
                              Text(
                                isAdmin ? 'Total Realisasi Semua Toko' : 'Total Realisasi',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
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
                          percentage: secondPct,
                          height: 90,
                          accentColor: const Color(0xFF94A3B8),
                          gradientColors: [const Color(0xFF94A3B8), const Color(0xFF64748B)],
                          medalIcon: '🥈',
                        ),
                        // RANK 1 (Gold)
                        _buildPodiumPillar(
                          rank: 1,
                          storeName: firstStore,
                          percentage: firstPct,
                          height: 130,
                          accentColor: const Color(0xFFF59E0B),
                          gradientColors: [const Color(0xFFFBBF24), const Color(0xFFD97706)],
                          medalIcon: '🥇',
                        ),
                        // RANK 3 (Bronze)
                        _buildPodiumPillar(
                          rank: 3,
                          storeName: thirdStore,
                          percentage: thirdPct,
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
                      if (isAdmin && (item['percentage'] != null || item['persentase'] != null)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(item['percentage'] ?? item['persentase']).toString()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDetailItem({
    required String title,
    required int value,
    required List<String> details,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasData = value > 0 || details.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasData
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: hasData ? null : Colors.grey,
                ),
              ),
              Text(
                'Rp ${_formatCurrency(value)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: value > 0 ? const Color(0xFF10B981) : Colors.grey,
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: details.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showSaleDetailBottomSheet(Map<String, dynamic> item) {
    final rawName = item['nama']?.toString().toUpperCase() ?? 'SPG';
    final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
    final formattedDate = _formatIndonesianDate(rawDate);
    final timestamp = item['timestamp']?.toString() ?? '';
    final tokoName = item['toko']?.toString() ?? '';
    final totalVal = (item['total'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rawName,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (tokoName.isNotEmpty)
                            Text(
                              'Toko: $tokoName',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total: Rp ${_formatCurrency(totalVal)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate + (timestamp.isNotEmpty ? ' • $timestamp' : ''),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Rincian Produk Terjual',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  // Lawrence
                  _buildDetailItem(
                    title: '🛏️ Lawrence',
                    value: (item['lawValue'] as num?)?.toInt() ?? 0,
                    details: [
                      if (((item['lawQtyOs'] as num?)?.toInt() ?? 0) > 0)
                        'Qty OS: ${item['lawQtyOs']}',
                      if (((item['lawQtyNh'] as num?)?.toInt() ?? 0) > 0)
                        'Qty NH: ${item['lawQtyNh']}',
                      if ((item['lawNoSo']?.toString().trim().isNotEmpty ?? false))
                        'No SO: ${item['lawNoSo']}',
                    ],
                  ),

                  // Superbed
                  _buildDetailItem(
                    title: '⭐ Superbed',
                    value: (item['sbValue'] as num?)?.toInt() ?? 0,
                    details: [
                      if ((item['sbNoSo']?.toString().trim().isNotEmpty ?? false))
                        'No SO: ${item['sbNoSo']}',
                    ],
                  ),

                  // Sofa
                  _buildDetailItem(
                    title: '🛋️ Sofa',
                    value: (item['sofaValue'] as num?)?.toInt() ?? 0,
                    details: [
                      if (((item['sofaQty'] as num?)?.toInt() ?? 0) > 0)
                        'Qty: ${item['sofaQty']}',
                      if ((item['sofaNoSo']?.toString().trim().isNotEmpty ?? false))
                        'No SO: ${item['sofaNoSo']}',
                    ],
                  ),

                  // Bedding / Busa
                  _buildDetailItem(
                    title: '🛏️ Bedding / Busa',
                    value: (item['bedValue'] as num?)?.toInt() ?? 0,
                    details: [
                      if ((item['bedNoSo']?.toString().trim().isNotEmpty ?? false))
                        'No SO: ${item['bedNoSo']}',
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar() {
    final empId = _idController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (empId == '101' ? 'ADMINISTRATOR' : 'SPG Attendant');
    final isAdmin = empId == '101';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: isAdmin ? Colors.amber : const Color(0xFF10B981),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white,
                size: 36,
              ),
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Row(
              children: [
                Text(
                  empId.isNotEmpty ? 'ID: $empId' : 'Belum input ID',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
            title: const Text('Input Penjualan', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Form laporan penjualan baru'),
            selected: _tabController.index == 0 && _salesViewMode == SalesViewMode.input,
            selectedTileColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _salesViewMode = SalesViewMode.input;
                _tabController.animateTo(0);
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF3B82F6)),
            title: const Text('Daftar Penjualan', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Riwayat transaksi penjualan'),
            selected: _tabController.index == 0 && _salesViewMode == SalesViewMode.list,
            selectedTileColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _salesViewMode = SalesViewMode.list;
                _tabController.animateTo(0);
              });
              _loadSalesHistory();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
            title: const Text('Pencapaian Toko', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Podium & Peringkat Toko'),
            selected: _tabController.index == 1,
            selectedTileColor: Colors.amber.withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _tabController.animateTo(1);
              });
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'SPG Attendant v1.1 • Beta',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesListTab() {
    if (_idController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Masukkan ID Anda Terlebih Dahulu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ID diperlukan untuk memuat riwayat penjualan Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _salesViewMode = SalesViewMode.input;
                  });
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Buka Form Input Penjualan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text('Memuat riwayat penjualan...'),
          ],
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                _historyError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadSalesHistory(showSpinner: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => _loadSalesHistory(showSpinner: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // HEADER BAR: "DATA PENJUALAN" dengan tombol "+ Add" (Identik Data Penjualan.jpeg)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'DATA PENJUALAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _salesViewMode = SalesViewMode.input;
                    });
                  },
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF1D4ED8)),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FILTER ADMIN (Hanya Tampil Jika ID 101)
          if (_isAdminHistory)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Filter Admin',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                      ),
                      const Spacer(),
                      if (_selectedFilterStore != null || _selectedFilterDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFilterStore = null;
                              _selectedFilterDate = null;
                            });
                            _loadSalesHistory(showSpinner: true);
                          },
                          child: Text(
                            'Reset Filter',
                            style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Filter Toko Dropdown
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilterStore,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Toko',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Semua Toko', style: TextStyle(fontSize: 12)),
                            ),
                            ..._availableStores.map((store) {
                              return DropdownMenuItem<String>(
                                value: store,
                                child: Text(store, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedFilterStore = val;
                            });
                            _loadSalesHistory(showSpinner: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Tanggal Button
                      Expanded(
                        flex: 5,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedFilterDate != null
                                  ? DateTime.tryParse(_selectedFilterDate!) ?? now
                                  : now,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedFilterDate = DateFormat('yyyy-MM-dd').format(picked);
                              });
                              _loadSalesHistory(showSpinner: true);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(
                            _selectedFilterDate ?? 'Semua Tgl',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // SUMMARY STATS (Total Transaksi & Total Nilai)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_historyTotalTransactions Transaksi',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Total: Rp ${_formatCurrency(_historyTotalAmount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // LIST DATA
          if (_salesHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak ada transaksi penjualan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada data yang tercatat sesuai filter.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._salesHistory.map((item) {
              final itemMap = Map<String, dynamic>.from(item as Map);
              final rawName = itemMap['nama']?.toString().toUpperCase() ?? 'SPG';
              final rawDate = itemMap['tanggal']?.toString() ?? itemMap['timestamp']?.toString() ?? '';
              final formattedDate = _formatIndonesianDate(rawDate);
              final totalVal = (itemMap['total'] as num?)?.toInt() ?? 0;
              final formattedAmount = _formatCurrency(totalVal);
              final tokoName = itemMap['toko']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showSaleDetailBottomSheet(itemMap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NAMA SPG (Indigo / Blue font sesuai Data Penjualan.jpeg)
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      rawName,
                                      style: const TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_isAdminHistory && tokoName.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tokoName,
                                        style: const TextStyle(
                                          color: Color(0xFF3B82F6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              // TANGGAL (Indonesian style: Sabtu, 26 Juli 2025)
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // TOTAL NILAI (Tanpa Rp / Berformat titik sesuai Data Penjualan.jpeg)
                              Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Trailing '...' icon
                        IconButton(
                          icon: const Icon(Icons.more_horiz, color: Colors.grey),
                          tooltip: 'Detail Penjualan',
                          onPressed: () => _showSaleDetailBottomSheet(itemMap),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    if (_salesViewMode == SalesViewMode.list) {
      return _buildSalesListTab();
    }
    if (_isLoadingNames) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SHORTCUT BANNER TO DAFTAR PENJUALAN
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF3B82F6), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Riwayat Penjualan',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _salesViewMode = SalesViewMode.list;
                      });
                      _loadSalesHistory();
                    },
                    child: const Row(
                      children: [
                        Text(
                          'Buka Daftar Penjualan',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF3B82F6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                  );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      drawer: _buildSidebar(),
      appBar: AppBar(
        title: Text(
          _tabController.index == 1
              ? 'Pencapaian Toko'
              : (_salesViewMode == SalesViewMode.list ? 'DATA PENJUALAN' : 'Laporan Penjualan'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_tabController.index == 0 && _salesViewMode == SalesViewMode.list)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _salesViewMode = SalesViewMode.input;
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () {
              if (_tabController.index == 1) {
                _loadPencapaian(showSpinner: true);
              } else if (_salesViewMode == SalesViewMode.list) {
                _loadSalesHistory(showSpinner: true);
              } else {
                _loadPromotorNames(forceRefresh: true);
                _loadPencapaian(showSpinner: true);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.grey,
          tabs: const [
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
        controller: _tabController,
        children: [
          // TAB 1: PENJUALAN
          _buildSalesTab(),

          // TAB 2: PENCAPAIAN
          _buildPencapaianTab(),
        ],
      ),
    );
  }
}
