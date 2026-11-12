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

enum MainView { penjualan, pencapaian }

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

  // Navigasi Utama Sidebar: Penjualan atau Pencapaian Toko
  MainView _currentView = MainView.penjualan;

  // Daftar Penjualan State
  List<dynamic> _rawSalesHistory = [];
  List<dynamic> _salesHistory = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  int _historyTotalAmount = 0;
  int _historyTotalTransactions = 0;
  int _historyFilteredProductUnits = 0;
  List<String> _availableStores = [];
  String? _selectedFilterStore;
  String? _selectedFilterDate;
  String? _selectedFilterPeriod;
  String? _selectedFilterProduct;
  List<String> _availablePeriods = [];
  bool _isAdminHistory = false;

  static const List<Map<String, dynamic>> _productFilterOptions = [
    {'key': null, 'label': 'Semua Barang', 'shortLabel': 'Semua', 'color': Color(0xFF3B82F6)},
    {'key': 'lawrence', 'label': 'Lawrence (OS & NH)', 'shortLabel': 'Lawrence', 'color': Color(0xFFF59E0B)},
    {'key': 'superbed', 'label': 'Superbed', 'shortLabel': 'Superbed', 'color': Color(0xFFEA580C)},
    {'key': 'sofa', 'label': 'Sofa', 'shortLabel': 'Sofa', 'color': Color(0xFF3B82F6)},
    {'key': 'bedding', 'label': 'Bedding', 'shortLabel': 'Bedding', 'color': Color(0xFF8B5CF6)},
  ];

  // Pencapaian State
  Map<String, dynamic>? _pencapaianData;
  bool _isLoadingPencapaian = false;
  String? _pencapaianError;
  int _prevRealizationAmount = 0;
  Map<String, int> _monthlyQtySummary = {
    'lawOs': 0,
    'lawNh': 0,
    'superbed': 0,
    'sofa': 0,
    'bedding': 0,
    'total': 0,
    'amount': 0,
    'txCount': 0,
  };
  Map<String, int> _prevMonthMetrics = {
    'lawOs': 0,
    'lawNh': 0,
    'superbed': 0,
    'sofa': 0,
    'bedding': 0,
    'total': 0,
    'amount': 0,
    'txCount': 0,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedFilterPeriod = DateFormat('yyyy-MM').format(DateTime.now());
    _availablePeriods = [_selectedFilterPeriod!];
    _idController.addListener(_onIdChanged);
    _loadInitialData();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
      if (_tabController.index == 1) {
        _loadSalesHistory(showSpinner: _salesHistory.isEmpty);
      }
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

  /// Menghitung jumlah unit berdasarkan nomor SO (1 SO = 1 unit).
  int _countSoUnits(String? rawNoSo) {
    if (rawNoSo == null) return 0;
    final trimmed = rawNoSo.trim();
    if (trimmed.isEmpty || trimmed == '-' || trimmed == '0' || trimmed.toLowerCase() == 'null') {
      return 0;
    }
    final parts = trimmed
        .split(RegExp(r'[,;\n&]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != '-' && s != '0' && s.toLowerCase() != 'null')
        .toList();
    return parts.length;
  }

  /// Menghitung seluruh metrik performa (unit per produk, total omset, jumlah transaksi) untuk bulan tertentu.
  Map<String, int> _calculatePeriodMetrics(
    List<dynamic> rawList, {
    required String empId,
    required String targetMonth,
    required bool isAdmin,
  }) {
    int lawOs = 0;
    int lawNh = 0;
    int superbed = 0;
    int sofa = 0;
    int bedding = 0;
    int totalAmount = 0;
    int txCount = 0;

    for (var item in rawList) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      final itemId = itemMap['id']?.toString().trim() ?? '';
      final itemPeriode = itemMap['periode']?.toString().trim() ?? '';
      final rawDate = itemMap['tanggal']?.toString() ?? itemMap['timestamp']?.toString() ?? '';
      final bool inPeriod = itemPeriode.isNotEmpty
          ? itemPeriode == targetMonth
          : rawDate.startsWith(targetMonth);

      if (inPeriod && (isAdmin || itemId == empId)) {
        txCount++;
        lawOs += (itemMap['lawQtyOs'] as num?)?.toInt() ?? 0;
        lawNh += (itemMap['lawQtyNh'] as num?)?.toInt() ?? 0;
        superbed += _countSoUnits(itemMap['sbNoSo']?.toString());
        sofa += (itemMap['sofaQty'] as num?)?.toInt() ?? 0;
        bedding += _countSoUnits(itemMap['bedNoSo']?.toString());

        final txTotal = (itemMap['total'] as num?)?.toInt() ??
            (((itemMap['lawValue'] as num?)?.toInt() ?? 0) +
                ((itemMap['sbValue'] as num?)?.toInt() ?? 0) +
                ((itemMap['sofaValue'] as num?)?.toInt() ?? 0) +
                ((itemMap['bedValue'] as num?)?.toInt() ?? 0));
        totalAmount += txTotal;
      }
    }

    return {
      'lawOs': lawOs,
      'lawNh': lawNh,
      'superbed': superbed,
      'sofa': sofa,
      'bedding': bedding,
      'total': lawOs + lawNh + superbed + sofa + bedding,
      'amount': totalAmount,
      'txCount': txCount,
    };
  }

  Future<void> _loadPencapaian({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoadingPencapaian = true;
        _pencapaianError = null;
      });
    }

    final empId = _idController.text.trim();
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);
    final prevMonth = DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1, 1));
    final bool isAdmin = empId == '101';

    final pencapaianFuture = widget.apiService.fetchPencapaian(empId);
    final prevPencapaianFuture = widget.apiService.fetchPencapaian(empId, periode: prevMonth);
    final historyFuture = empId.isNotEmpty
        ? widget.apiService.fetchSalesHistory(employeeId: empId, periode: currentMonth)
        : Future<Map<String, dynamic>?>.value(null);
    final prevHistoryFuture = empId.isNotEmpty
        ? widget.apiService.fetchSalesHistory(employeeId: empId, periode: prevMonth)
        : Future<Map<String, dynamic>?>.value(null);

    final results = await Future.wait([
      pencapaianFuture,
      prevPencapaianFuture,
      historyFuture,
      prevHistoryFuture,
    ]);
    final data = results[0];
    final prevPencapaianData = results[1];
    final historyData = results[2];
    final prevHistoryData = results[3];

    if (mounted) {
      setState(() {
        _isLoadingPencapaian = false;
        if (data != null && data['status'] == 'success') {
          _pencapaianData = data;
          _pencapaianError = null;

          final currRawList = (historyData != null && historyData['status'] == 'success')
              ? (historyData['data'] as List<dynamic>? ?? [])
              : <dynamic>[];
          final currFromHistory = _calculatePeriodMetrics(
            currRawList,
            empId: empId,
            targetMonth: currentMonth,
            isAdmin: isAdmin,
          );

          if (data['qtySummary'] != null && data['qtySummary'] is Map) {
            final qMap = Map<String, dynamic>.from(data['qtySummary'] as Map);
            _monthlyQtySummary = {
              'lawOs': (qMap['lawOs'] as num?)?.toInt() ?? 0,
              'lawNh': (qMap['lawNh'] as num?)?.toInt() ?? 0,
              'superbed': (qMap['superbed'] as num?)?.toInt() ?? 0,
              'sofa': (qMap['sofa'] as num?)?.toInt() ?? 0,
              'bedding': (qMap['bedding'] as num?)?.toInt() ?? 0,
              'total': (qMap['total'] as num?)?.toInt() ?? 0,
              'amount': currFromHistory['amount'] ?? 0,
              'txCount': currFromHistory['txCount'] ?? 0,
            };
          } else {
            _monthlyQtySummary = currFromHistory;
          }

          if (isAdmin && (_monthlyQtySummary['amount'] ?? 0) == 0) {
            final adminActual = (data['totalActual'] as num?)?.toInt() ?? 0;
            if (adminActual > 0) {
              _monthlyQtySummary['amount'] = adminActual;
            }
          }

          final prevRawList = (prevHistoryData != null && prevHistoryData['status'] == 'success')
              ? (prevHistoryData['data'] as List<dynamic>? ?? [])
              : currRawList;
          _prevMonthMetrics = _calculatePeriodMetrics(
            prevRawList,
            empId: empId,
            targetMonth: prevMonth,
            isAdmin: isAdmin,
          );

          if (prevPencapaianData != null &&
              prevPencapaianData['status'] == 'success' &&
              prevPencapaianData['periode']?.toString() == prevMonth) {
            final prevPersonal = prevPencapaianData['personal'] as Map?;
            _prevRealizationAmount = (prevPersonal?['actual'] as num?)?.toInt() ??
                (prevPencapaianData['totalActual'] as num?)?.toInt() ??
                (_prevMonthMetrics['amount'] ?? 0);
          } else {
            _prevRealizationAmount = _prevMonthMetrics['amount'] ?? 0;
          }
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
          _rawSalesHistory = [];
          _salesHistory = [];
          _historyTotalAmount = 0;
          _historyTotalTransactions = 0;
          _historyFilteredProductUnits = 0;
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
      periode: _selectedFilterPeriod,
    );

    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (data != null && data['status'] == 'success') {
          final rawList = data['data'] as List<dynamic>? ?? [];

          // Kumpulkan periode yang tersedia
          final Set<String> periodsFound = {};
          final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
          periodsFound.add(currentMonth);
          if (_selectedFilterPeriod != null && _selectedFilterPeriod != 'all') {
            periodsFound.add(_selectedFilterPeriod!);
          }

          if (data['periods'] != null) {
            for (var p in data['periods']) {
              if (p != null && p.toString().isNotEmpty) {
                periodsFound.add(p.toString());
              }
            }
          }

          for (var item in rawList) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            final p = itemMap['periode']?.toString();
            if (p != null && p.isNotEmpty) {
              periodsFound.add(p);
            } else {
              final rawDate = itemMap['tanggal']?.toString() ?? itemMap['timestamp']?.toString() ?? '';
              if (rawDate.length >= 7) {
                periodsFound.add(rawDate.substring(0, 7));
              }
            }
          }

          _availablePeriods = periodsFound.toList()..sort((a, b) => b.compareTo(a));

          // Filter client-side jika backend mengembalikan data tanpa filter periode
          List<dynamic> filteredList = rawList;
          if (_selectedFilterPeriod != null &&
              _selectedFilterPeriod != 'all' &&
              _selectedFilterPeriod!.isNotEmpty) {
            filteredList = rawList.where((item) {
              final itemMap = Map<String, dynamic>.from(item as Map);
              final p = itemMap['periode']?.toString();
              if (p != null && p.isNotEmpty) {
                return p == _selectedFilterPeriod;
              }
              final rawDate = itemMap['tanggal']?.toString() ?? itemMap['timestamp']?.toString() ?? '';
              return rawDate.startsWith(_selectedFilterPeriod!);
            }).toList();
          }

          // Filter tanggal client-side jika dipilih
          if (_selectedFilterDate != null && _selectedFilterDate!.isNotEmpty) {
            filteredList = filteredList.where((item) {
              final itemMap = Map<String, dynamic>.from(item as Map);
              final tgl = itemMap['tanggal']?.toString() ?? '';
              return tgl == _selectedFilterDate;
            }).toList();
          }

          _rawSalesHistory = filteredList;
          _isAdminHistory = data['isAdmin'] == true || empId == '101';
          final nowDt = DateTime.now();
          final prevMonth = DateFormat('yyyy-MM').format(DateTime(nowDt.year, nowDt.month - 1, 1));
          if ((_selectedFilterStore == null || _selectedFilterStore!.isEmpty) &&
              (_selectedFilterDate == null || _selectedFilterDate!.isEmpty)) {
            if (_selectedFilterPeriod == currentMonth) {
              _monthlyQtySummary = _calculatePeriodMetrics(
                _rawSalesHistory,
                empId: empId,
                targetMonth: currentMonth,
                isAdmin: _isAdminHistory,
              );
            } else if (_selectedFilterPeriod == prevMonth) {
              _prevMonthMetrics = _calculatePeriodMetrics(
                _rawSalesHistory,
                empId: empId,
                targetMonth: prevMonth,
                isAdmin: _isAdminHistory,
              );
            }
          }
          _applyLocalProductFilter();
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

  bool _matchesProductFilter(Map<String, dynamic> itemMap, String? productKey) {
    if (productKey == null || productKey == 'all') return true;
    switch (productKey) {
      case 'lawrence':
        final os = (itemMap['lawQtyOs'] as num?)?.toInt() ?? 0;
        final nh = (itemMap['lawQtyNh'] as num?)?.toInt() ?? 0;
        final val = (itemMap['lawValue'] as num?)?.toInt() ?? 0;
        final so = itemMap['lawNoSo']?.toString().trim() ?? '';
        return os > 0 || nh > 0 || val > 0 || so.isNotEmpty;
      case 'superbed':
        final val = (itemMap['sbValue'] as num?)?.toInt() ?? 0;
        final so = itemMap['sbNoSo']?.toString().trim() ?? '';
        return val > 0 || so.isNotEmpty;
      case 'sofa':
        final qty = (itemMap['sofaQty'] as num?)?.toInt() ?? 0;
        final val = (itemMap['sofaValue'] as num?)?.toInt() ?? 0;
        final so = itemMap['sofaNoSo']?.toString().trim() ?? '';
        return qty > 0 || val > 0 || so.isNotEmpty;
      case 'bedding':
        final val = (itemMap['bedValue'] as num?)?.toInt() ?? 0;
        final so = itemMap['bedNoSo']?.toString().trim() ?? '';
        return val > 0 || so.isNotEmpty;
      default:
        return true;
    }
  }

  int _getProductFilteredValue(Map<String, dynamic> itemMap, String? productKey) {
    if (productKey == null || productKey == 'all') {
      return (itemMap['total'] as num?)?.toInt() ?? 0;
    }
    switch (productKey) {
      case 'lawrence':
        return (itemMap['lawValue'] as num?)?.toInt() ?? 0;
      case 'superbed':
        return (itemMap['sbValue'] as num?)?.toInt() ?? 0;
      case 'sofa':
        return (itemMap['sofaValue'] as num?)?.toInt() ?? 0;
      case 'bedding':
        return (itemMap['bedValue'] as num?)?.toInt() ?? 0;
      default:
        return (itemMap['total'] as num?)?.toInt() ?? 0;
    }
  }

  int _getProductFilteredUnitCount(Map<String, dynamic> itemMap, String? productKey) {
    switch (productKey) {
      case 'lawrence':
        final os = (itemMap['lawQtyOs'] as num?)?.toInt() ?? 0;
        final nh = (itemMap['lawQtyNh'] as num?)?.toInt() ?? 0;
        return os + nh;
      case 'superbed':
        return _countSoUnits(itemMap['sbNoSo']?.toString());
      case 'sofa':
        return (itemMap['sofaQty'] as num?)?.toInt() ?? 0;
      case 'bedding':
        return _countSoUnits(itemMap['bedNoSo']?.toString());
      default:
        return 0;
    }
  }

  Map<String, dynamic> _getSelectedProductMeta() {
    return _productFilterOptions.firstWhere(
      (opt) => opt['key'] == _selectedFilterProduct,
      orElse: () => _productFilterOptions.first,
    );
  }

  String _getProductCardBreakdown(Map<String, dynamic> itemMap, String? productKey) {
    switch (productKey) {
      case 'lawrence':
        final os = (itemMap['lawQtyOs'] as num?)?.toInt() ?? 0;
        final nh = (itemMap['lawQtyNh'] as num?)?.toInt() ?? 0;
        final so = itemMap['lawNoSo']?.toString().trim() ?? '';
        final parts = <String>[
          if (os > 0) 'OS: $os',
          if (nh > 0) 'NH: $nh',
          if (so.isNotEmpty) 'SO: $so',
        ];
        return parts.isEmpty ? 'Lawrence' : 'Lawrence (${parts.join(' • ')})';
      case 'superbed':
        final so = itemMap['sbNoSo']?.toString().trim() ?? '';
        return so.isNotEmpty ? 'Superbed • SO: $so' : 'Superbed';
      case 'sofa':
        final qty = (itemMap['sofaQty'] as num?)?.toInt() ?? 0;
        final so = itemMap['sofaNoSo']?.toString().trim() ?? '';
        final parts = <String>[
          if (qty > 0) 'Qty: $qty',
          if (so.isNotEmpty) 'SO: $so',
        ];
        return parts.isEmpty ? 'Sofa' : 'Sofa (${parts.join(' • ')})';
      case 'bedding':
        final so = itemMap['bedNoSo']?.toString().trim() ?? '';
        return so.isNotEmpty ? 'Bedding • SO: $so' : 'Bedding';
      default:
        return '';
    }
  }

  void _applyLocalProductFilter() {
    final filtered = _rawSalesHistory.where((item) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      return _matchesProductFilter(itemMap, _selectedFilterProduct);
    }).toList();

    int calculatedTotal = 0;
    int calculatedUnits = 0;
    for (var item in filtered) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      calculatedTotal += _getProductFilteredValue(itemMap, _selectedFilterProduct);
      if (_selectedFilterProduct != null) {
        calculatedUnits += _getProductFilteredUnitCount(itemMap, _selectedFilterProduct);
      }
    }

    _salesHistory = filtered;
    _historyTotalAmount = calculatedTotal;
    _historyTotalTransactions = filtered.length;
    _historyFilteredProductUnits = calculatedUnits;
  }

  bool get _isFilterActive {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return (_selectedFilterPeriod != null && _selectedFilterPeriod != currentMonth) ||
        _selectedFilterStore != null ||
        _selectedFilterDate != null ||
        _selectedFilterProduct != null;
  }

  String _formatIndonesianPeriod(String period) {
    if (period == 'all' || period.isEmpty) return 'Semua Periode';
    try {
      final parts = period.split('-');
      if (parts.length == 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        const months = [
          'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
          'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
        ];
        if (m >= 1 && m <= 12) {
          return '${months[m - 1]} $y';
        }
      }
    } catch (_) {}
    return period;
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
        if (_currentView == MainView.penjualan && _tabController.index == 1) {
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
      'action': 'submit_penjualan',
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
              label: 'Lihat Data',
              textColor: Colors.white,
              onPressed: () {
                _tabController.animateTo(1);
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
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
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

  String _formatShortMonthPeriod(String period) {
    try {
      final parts = period.split('-');
      if (parts.length == 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        if (m >= 1 && m <= 12) return '${months[m - 1]} $y';
      }
    } catch (_) {}
    return period;
  }

  /// Badge tren kompak (naik hijau / turun merah) untuk ditempel di samping nominal & qty.
  Widget _buildInlineTrendBadge({
    required int current,
    required int previous,
    bool showPercentage = false,
    String? compareLabel,
    bool onHeroCard = false,
  }) {
    if (current == 0 && previous == 0) {
      return const SizedBox.shrink();
    }

    final int diff = current - previous;
    final bool isUp = diff > 0;
    final bool isDown = diff < 0;

    Color fgColor;
    Color bgColor;
    Color borderColor;
    IconData icon;

    if (onHeroCard) {
      fgColor = isUp
          ? const Color(0xFF6EE7B7)
          : (isDown ? const Color(0xFFFCA5A5) : Colors.white70);
      bgColor = isUp
          ? const Color(0xFF065F46).withValues(alpha: 0.65)
          : (isDown ? const Color(0xFF7F1D1D).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.15));
      borderColor = fgColor.withValues(alpha: 0.45);
    } else {
      fgColor = isUp
          ? const Color(0xFF10B981)
          : (isDown ? const Color(0xFFEF4444) : Colors.grey);
      bgColor = fgColor.withValues(alpha: 0.14);
      borderColor = fgColor.withValues(alpha: 0.35);
    }

    icon = isUp
        ? Icons.arrow_drop_up_rounded
        : (isDown ? Icons.arrow_drop_down_rounded : Icons.drag_handle_rounded);
    final bool showIcon = isUp || isDown || showPercentage;

    String text;
    if (showPercentage) {
      if (previous == 0 && current > 0) {
        text = compareLabel != null ? 'Baru ($compareLabel)' : 'Baru (+$current)';
      } else {
        final pct = ((current - previous) / previous) * 100;
        final sign = pct > 0 ? '+' : (pct < 0 ? '-' : '');
        text = '$sign${pct.abs().toStringAsFixed(1)}%';
        if (!onHeroCard) {
          final diffStr = diff > 0 ? '+$diff' : '$diff';
          text = '$text ($diffStr)';
        } else if (compareLabel != null) {
          text = '$text $compareLabel';
        }
      }
    } else if (diff == 0) {
      text = '=0';
    } else {
      final sign = diff > 0 ? '+' : '';
      text = '$sign$diff';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showIcon ? 5 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) Icon(icon, size: 15, color: fgColor),
          Text(
            text,
            style: TextStyle(
              color: fgColor,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Angka unit & badge tren kompak berdampingan (auto-wrap pada layar ekstra sempit).
  Widget _buildUnitWithTrend({
    required int count,
    required int prevCount,
    required Color accentColor,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 3,
      children: [
        Text(
          count > 0 ? '$count Unit' : '- Unit',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: count > 0 ? accentColor : Colors.grey,
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
          ),
        ),
        if (count > 0 || prevCount > 0)
          _buildInlineTrendBadge(current: count, previous: prevCount),
      ],
    );
  }

  Widget _buildSingleBrandQtyBox({
    required String title,
    required int count,
    required int prevCount,
    required Color accentColor,
    required bool isDark,
  }) {
    final innerCardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: innerCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12.5)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.25), width: 1),
              ),
            ),
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: _buildUnitWithTrend(
                  count: count,
                  prevCount: prevCount,
                  accentColor: accentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawrenceSubColumn({
    required String label,
    required int count,
    required int prevCount,
    required Color accentColor,
    required bool isDark,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _buildUnitWithTrend(
              count: count,
              prevCount: prevCount,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLawrenceQtyBox({
    required int osCount,
    required int prevOsCount,
    required int nhCount,
    required int prevNhCount,
    required bool isDark,
  }) {
    const accentColor = Color(0xFFF59E0B);
    final innerCardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: innerCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12.5)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.25), width: 1),
              ),
            ),
            child: Text(
              'LAWRENCE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.4,
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLawrenceSubColumn(
                  label: 'Ortho Support',
                  count: osCount,
                  prevCount: prevOsCount,
                  accentColor: accentColor,
                  isDark: isDark,
                ),
                Container(
                  width: 1,
                  color: accentColor.withValues(alpha: 0.2),
                ),
                _buildLawrenceSubColumn(
                  label: 'Natural Hybrid',
                  count: nhCount,
                  prevCount: prevNhCount,
                  accentColor: accentColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyQtyCard({
    required bool isDark,
    required bool isAdmin,
    required String periode,
  }) {
    final lawOs = _monthlyQtySummary['lawOs'] ?? 0;
    final lawNh = _monthlyQtySummary['lawNh'] ?? 0;
    final sbCount = _monthlyQtySummary['superbed'] ?? 0;
    final sofaCount = _monthlyQtySummary['sofa'] ?? 0;
    final bedCount = _monthlyQtySummary['bedding'] ?? 0;
    final totalCount = _monthlyQtySummary['total'] ?? 0;

    final prevLawOs = _prevMonthMetrics['lawOs'] ?? 0;
    final prevLawNh = _prevMonthMetrics['lawNh'] ?? 0;
    final prevSb = _prevMonthMetrics['superbed'] ?? 0;
    final prevSofa = _prevMonthMetrics['sofa'] ?? 0;
    final prevBed = _prevMonthMetrics['bedding'] ?? 0;
    final prevTotal = _prevMonthMetrics['total'] ?? 0;

    final now = DateTime.now();
    final prevPeriod = DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1, 1));
    final prevShort = _formatShortMonthPeriod(prevPeriod);
    final currShort = _formatShortMonthPeriod(periode);

    final cardColor = Theme.of(context).cardColor;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bergaya Kartu Atas (Blue Gradient Header Strip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A), const Color(0xFF172554)]
                    : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isAdmin ? 'UNIT TERJUAL (SEMUA TOKO)' : 'UNIT TERJUAL BULAN INI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$currShort vs $prevShort',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body bergaya Kartu Tengah (4 Kartu dengan Colored Borders & Tren Komparasi)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 520) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildLawrenceQtyBox(
                                osCount: lawOs,
                                prevOsCount: prevLawOs,
                                nhCount: lawNh,
                                prevNhCount: prevLawNh,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: _buildSingleBrandQtyBox(
                                title: 'Superbed',
                                count: sbCount,
                                prevCount: prevSb,
                                accentColor: const Color(0xFFEA580C),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: _buildSingleBrandQtyBox(
                                title: 'Sofa',
                                count: sofaCount,
                                prevCount: prevSofa,
                                accentColor: const Color(0xFF3B82F6),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: _buildSingleBrandQtyBox(
                                title: 'Bedding',
                                count: bedCount,
                                prevCount: prevBed,
                                accentColor: const Color(0xFF8B5CF6),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Column(
                        children: [
                          _buildLawrenceQtyBox(
                            osCount: lawOs,
                            prevOsCount: prevLawOs,
                            nhCount: lawNh,
                            prevNhCount: prevLawNh,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildSingleBrandQtyBox(
                                    title: 'Superbed',
                                    count: sbCount,
                                    prevCount: prevSb,
                                    accentColor: const Color(0xFFEA580C),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSingleBrandQtyBox(
                                    title: 'Sofa',
                                    count: sofaCount,
                                    prevCount: prevSofa,
                                    accentColor: const Color(0xFF3B82F6),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSingleBrandQtyBox(
                                    title: 'Bedding',
                                    count: bedCount,
                                    prevCount: prevBed,
                                    accentColor: const Color(0xFF8B5CF6),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Footer Ringkasan Total Unit beserta Tren Naik/Turun
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.14 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.summarize_outlined,
                            size: 17,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total Unit Terjual Bulan Ini:',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInlineTrendBadge(
                            current: totalCount,
                            previous: prevTotal,
                            showPercentage: true,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '$totalCount Unit',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

    final empId = _idController.text.trim();
    final bool isAdmin = empId == '101' || _pencapaianData?['isAdmin'] == true;
    Map<String, dynamic>? personal = _pencapaianData?['personal'] != null
        ? Map<String, dynamic>.from(_pencapaianData!['personal'] as Map)
        : null;

    final podiumList = (_pencapaianData?['podium'] as List<dynamic>?) ?? [];
    final leaderboardList = (_pencapaianData?['leaderboard'] as List<dynamic>?) ?? [];
    final periode = _pencapaianData?['periode']?.toString() ?? DateFormat('yyyy-MM').format(DateTime.now());

    // Otomatis buat data ringkasan konsolidasi untuk Mode Admin jika backend belum menyediakannya
    if (isAdmin && personal == null) {
      final totalStores = podiumList.length + leaderboardList.length;
      final double totalTarget = (_pencapaianData?['totalTarget'] as num?)?.toDouble() ?? 0.0;
      final double totalActual = (_pencapaianData?['totalActual'] as num?)?.toDouble() ?? 0.0;
      final double totalPct = (_pencapaianData?['totalPercentage'] as num?)?.toDouble() ??
          (totalTarget > 0 ? (totalActual / totalTarget * 100) : 0.0);
      final double totalShortage = (_pencapaianData?['totalShortage'] as num?)?.toDouble() ??
          (100.0 - totalPct).clamp(0.0, 100.0);

      personal = {
        'id': '101',
        'name': 'Administrator',
        'toko': 'Monitoring Seluruh Toko ($totalStores Toko)',
        'isAdmin': true,
        'rank': 0,
        'target': totalTarget.toInt(),
        'actual': totalActual.toInt(),
        'percentage': double.parse(totalPct.toStringAsFixed(1)),
        'persentase': double.parse(totalPct.toStringAsFixed(1)),
        'shortage': double.parse(totalShortage.toStringAsFixed(1)),
        'kekurangan': double.parse(totalShortage.toStringAsFixed(1)),
      };
    }

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
                              const SizedBox(height: 3),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    _formatRp(personal['actual'] ?? 0),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  _buildInlineTrendBadge(
                                    current: (personal['actual'] as num?)?.toInt() ?? 0,
                                    previous: _prevRealizationAmount,
                                    showPercentage: true,
                                    compareLabel: 'vs ${_formatShortMonthPeriod(DateFormat('yyyy-MM').format(DateTime(DateTime.now().year, DateTime.now().month - 1, 1)))}',
                                    onHeroCard: true,
                                  ),
                                ],
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
              const SizedBox(height: 16),

              // KARTU QUANTITY PRODUK TERJUAL BULAN BERJALAN
              _buildMonthlyQtyCard(
                isDark: isDark,
                isAdmin: isAdmin,
                periode: periode,
              ),
              const SizedBox(height: 24),
            ] else if (!isAdmin) ...[
              // Prompt jika ID belum ada (Hanya untuk SPG)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
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

  bool _canEditTransaction(Map<String, dynamic> item) {
    final empId = _idController.text.trim();
    final bool isAdmin = empId == '101' || _isAdminHistory;
    if (isAdmin) return true; // Admin memiliki hak akses penuh

    try {
      final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
      if (rawDate.isEmpty) return false;

      DateTime txDate;
      if (rawDate.contains('T')) {
        txDate = DateTime.parse(rawDate);
      } else if (rawDate.contains(' ')) {
        final p = rawDate.split(' ')[0].split('-');
        txDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      } else {
        final p = rawDate.split('-');
        txDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }

      final now = DateTime.now();
      // 1. Cek bulan berjalan
      if (txDate.year != now.year || txDate.month != now.month) {
        return false;
      }

      // 2. Cek batas maksimal 7 hari terakhir (seminggu terakhir)
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final txMidnight = DateTime(txDate.year, txDate.month, txDate.day);
      final diffDays = todayMidnight.difference(txMidnight).inDays;

      return diffDays >= 0 && diffDays <= 7;
    } catch (_) {
      return false;
    }
  }

  void _showTransactionActionsModal(Map<String, dynamic> item) {
    final rawName = item['nama']?.toString().toUpperCase() ?? 'SPG';
    final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
    final formattedDate = _formatIndonesianDate(rawDate);
    final totalVal = (item['total'] as num?)?.toInt() ?? 0;
    final tokoName = item['toko']?.toString().trim() ?? '';
    final isEdited = item['isEdited'] == true ||
        (item['editedLabel']?.toString().trim().isNotEmpty ?? false);
    final canEdit = _canEditTransaction(item);
    final empId = _idController.text.trim();
    final bool isAdmin = empId == '101' || _isAdminHistory;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      rawName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3B82F6)),
                    ),
                    if (isAdmin && tokoName.isNotEmpty)
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
                    if (isEdited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, size: 12, color: Color(0xFFD97706)),
                            SizedBox(width: 3),
                            Text(
                              'Edited',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$formattedDate • Total: Rp ${_formatCurrency(totalVal)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF3B82F6)),
                  title: const Text('Lihat Rincian Penjualan', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Detail produk Lawrence, Superbed, Sofa, Busa', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSaleDetailBottomSheet(item);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_note,
                    color: canEdit ? const Color(0xFF10B981) : Colors.grey,
                  ),
                  title: Text(
                    'Edit Transaksi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: canEdit ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    canEdit
                        ? 'Ubah nominal, Qty produk, atau nomor SO'
                        : 'Terkunci (Maksimal 7 hari di bulan berjalan)',
                    style: TextStyle(
                      fontSize: 12,
                      color: canEdit ? null : Colors.red.shade400,
                    ),
                  ),
                  enabled: canEdit,
                  onTap: canEdit
                      ? () {
                          Navigator.pop(ctx);
                          _showEditSaleBottomSheet(item);
                        }
                      : null,
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: canEdit ? Colors.red.shade600 : Colors.grey,
                  ),
                  title: Text(
                    'Hapus Transaksi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: canEdit ? Colors.red.shade600 : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    canEdit
                        ? 'Hapus data penjualan ini secara permanen'
                        : 'Terkunci (Maksimal 7 hari di bulan berjalan)',
                    style: TextStyle(
                      fontSize: 12,
                      color: canEdit ? Colors.grey.shade600 : Colors.red.shade400,
                    ),
                  ),
                  enabled: canEdit,
                  onTap: canEdit
                      ? () {
                          Navigator.pop(ctx);
                          _showDeleteConfirmationDialog(item);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> item) {
    final rawName = item['nama']?.toString().toUpperCase() ?? 'SPG';
    final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
    final formattedDate = _formatIndonesianDate(rawDate);
    final totalVal = (item['total'] as num?)?.toInt() ?? 0;
    final timestamp = item['timestamp']?.toString().trim() ?? '';
    final empId = item['id']?.toString().trim() ?? _idController.text.trim();
    final rowIndex = item['rowIndex'];

    final lawNoSo = item['lawNoSo']?.toString().trim() ?? '';
    final lawVal = (item['lawValue'] as num?)?.toInt() ?? 0;
    final sbNoSo = item['sbNoSo']?.toString().trim() ?? '';
    final sbVal = (item['sbValue'] as num?)?.toInt() ?? 0;
    final sofaNoSo = item['sofaNoSo']?.toString().trim() ?? '';
    final sofaVal = (item['sofaValue'] as num?)?.toInt() ?? 0;
    final bedNoSo = item['bedNoSo']?.toString().trim() ?? '';
    final bedVal = (item['bedValue'] as num?)?.toInt() ?? 0;

    final List<Map<String, dynamic>> soItems = [
      if (lawNoSo.isNotEmpty || lawVal > 0)
        {'product': '🛏️ Lawrence', 'noSo': lawNoSo.isNotEmpty ? lawNoSo : '-', 'val': lawVal},
      if (sbNoSo.isNotEmpty || sbVal > 0)
        {'product': '✨ Superbed', 'noSo': sbNoSo.isNotEmpty ? sbNoSo : '-', 'val': sbVal},
      if (sofaNoSo.isNotEmpty || sofaVal > 0)
        {'product': '🛋️ Sofa', 'noSo': sofaNoSo.isNotEmpty ? sofaNoSo : '-', 'val': sofaVal},
      if (bedNoSo.isNotEmpty || bedVal > 0)
        {'product': '💤 Bedding / Busa', 'noSo': bedNoSo.isNotEmpty ? bedNoSo : '-', 'val': bedVal},
    ];

    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hapus Data Penjualan?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apakah Anda yakin ingin menghapus data penjualan ini? Tindakan ini permanen dan tidak dapat dibatalkan.',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // KARTU RINCIAN NO SO & VALUE UNTUK MEMASTIKAN
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rawName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3B82F6)),
                              ),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          if (soItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Tidak ada rincian No SO',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                              ),
                            )
                          else
                            ...soItems.map((sItem) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sItem['product'] as String,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                          Text(
                                            'No SO: ${sItem['noSo']}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: (sItem['noSo'] != '-') ? const Color(0xFFD97706) : Colors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_formatCurrency(sItem['val'] as int)}',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Transaksi:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Rp ${_formatCurrency(totalVal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                OutlinedButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          final nav = Navigator.of(dialogCtx);
                          final messenger = ScaffoldMessenger.of(context);

                          final deleteData = {
                            'id': empId,
                            'timestamp': timestamp,
                            'tanggal': rawDate,
                            if (rowIndex != null) 'rowIndex': rowIndex!,
                          };

                          final result = await widget.apiService.deleteSalesReport(deleteData);

                          if (!mounted) return;

                          setDialogState(() {
                            isDeleting = false;
                          });

                          nav.pop();

                          if (result['status'] == 'success') {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Data transaksi berhasil dihapus.'),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _loadSalesHistory(showSpinner: false);
                            _loadPencapaian(showSpinner: false);
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Gagal menghapus transaksi.'),
                                backgroundColor: Colors.black87,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever, size: 18),
                  label: Text(
                    isDeleting ? 'Menghapus...' : 'Ya, Hapus Data',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaleDetailBottomSheet(Map<String, dynamic> item) {
    final rawName = item['nama']?.toString().toUpperCase() ?? 'SPG';
    final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
    final formattedDate = _formatIndonesianDate(rawDate);
    final timestamp = item['timestamp']?.toString() ?? '';
    final tokoName = item['toko']?.toString().trim() ?? '';
    final totalVal = (item['total'] as num?)?.toInt() ?? 0;
    final isEdited = item['isEdited'] == true ||
        (item['editedLabel']?.toString().trim().isNotEmpty ?? false);
    final editedLabel = item['editedLabel']?.toString().trim() ?? '';
    final canEdit = _canEditTransaction(item);
    final empId = _idController.text.trim();
    final bool isAdmin = empId == '101' || _isAdminHistory;

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  rawName,
                                  style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isAdmin && tokoName.isNotEmpty)
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
                                if (isEdited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_note, size: 12, color: Color(0xFFD97706)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Edited',
                                          style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (isAdmin && tokoName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Toko: $tokoName',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ),
                          ],
                        ),
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
                  if (isEdited) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              editedLabel.isNotEmpty
                                  ? 'Transaksi ini telah diperbarui ($editedLabel).'
                                  : 'Transaksi ini telah diperbarui (Edited).',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

                  if (!canEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Transaksi terkunci dari pengeditan (maksimal 7 hari di bulan berjalan).',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      if (canEdit) ...[
                        Expanded(
                          flex: 5,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditSaleBottomSheet(item);
                            },
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showDeleteConfirmationDialog(item);
                            },
                            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                            label: Text('Hapus', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        flex: canEdit ? 3 : 10,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSaleBottomSheet(Map<String, dynamic> item) {
    final rawDate = item['tanggal']?.toString() ?? item['timestamp']?.toString() ?? '';
    final timestamp = item['timestamp']?.toString() ?? '';
    final empId = item['id']?.toString() ?? _idController.text.trim();
    final rawName = item['nama']?.toString().toUpperCase() ?? _nameController.text.trim();
    final rowIndex = item['rowIndex'];

    final String fixedDate = rawDate.isNotEmpty
        ? rawDate
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Controller dan Inisialisasi data
    final lawQtyOsController = TextEditingController(
      text: (item['lawQtyOs'] ?? 0).toString() == '0' ? '' : (item['lawQtyOs'] ?? '').toString(),
    );
    final lawQtyNhController = TextEditingController(
      text: (item['lawQtyNh'] ?? 0).toString() == '0' ? '' : (item['lawQtyNh'] ?? '').toString(),
    );
    final lawValController = TextEditingController(
      text: ((item['lawValue'] as num?)?.toInt() ?? 0) > 0 ? _formatCurrency(item['lawValue']) : '',
    );
    final lawNoSoController = TextEditingController(text: item['lawNoSo']?.toString() ?? '');

    final sbValController = TextEditingController(
      text: ((item['sbValue'] as num?)?.toInt() ?? 0) > 0 ? _formatCurrency(item['sbValue']) : '',
    );
    final sbNoSoController = TextEditingController(text: item['sbNoSo']?.toString() ?? '');

    final sofaQtyController = TextEditingController(
      text: (item['sofaQty'] ?? 0).toString() == '0' ? '' : (item['sofaQty'] ?? '').toString(),
    );
    final sofaValController = TextEditingController(
      text: ((item['sofaValue'] as num?)?.toInt() ?? 0) > 0 ? _formatCurrency(item['sofaValue']) : '',
    );
    final sofaNoSoController = TextEditingController(text: item['sofaNoSo']?.toString() ?? '');

    final bedValController = TextEditingController(
      text: ((item['bedValue'] as num?)?.toInt() ?? 0) > 0 ? _formatCurrency(item['bedValue']) : '',
    );
    final bedNoSoController = TextEditingController(text: item['bedNoSo']?.toString() ?? '');

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int parseVal(TextEditingController c) {
              return int.tryParse(c.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0;
            }

            final currentTotal = parseVal(lawValController) +
                parseVal(sbValController) +
                parseVal(sofaValController) +
                parseVal(bedValController);

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note, color: Color(0xFF3B82F6), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Edit Transaksi Penjualan',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '$rawName • ${timestamp.isNotEmpty ? timestamp : rawDate}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // INFO TANGGAL TRANSAKSI (Read-Only / Tidak Dapat Diubah)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tanggal Penjualan (Terkunci)',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    Text(
                                      _formatIndonesianDate(fixedDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),

                        // 1. BRAND: LAWRENCE
                        _buildBrandCard(
                          brandTitle: 'LAWRENCE',
                          accentColor: const Color(0xFFF59E0B),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField(
                                    controller: lawQtyOsController,
                                    label: 'QTY OS',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildField(
                                    controller: lawQtyNhController,
                                    label: 'QTY NH',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                              ],
                            ),
                            _buildField(
                              controller: lawValController,
                              label: 'Value Penjualan',
                              prefixText: 'Rp ',
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              onChanged: (_) => setModalState(() {}),
                            ),
                            _buildField(
                              controller: lawNoSoController,
                              label: 'Nomor SO',
                              hintText: 'Contoh: SO-12345',
                            ),
                          ],
                        ),

                        // 2. BRAND: SUPERBED
                        _buildBrandCard(
                          brandTitle: 'SUPERBED',
                          accentColor: const Color(0xFFEA580C),
                          children: [
                            _buildField(
                              controller: sbValController,
                              label: 'Value Penjualan',
                              prefixText: 'Rp ',
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              onChanged: (_) => setModalState(() {}),
                            ),
                            _buildField(
                              controller: sbNoSoController,
                              label: 'Nomor SO',
                              hintText: 'Contoh: SO-67890',
                            ),
                          ],
                        ),

                        // 3. BRAND: SOFA
                        _buildBrandCard(
                          brandTitle: 'SOFA',
                          accentColor: const Color(0xFF10B981),
                          children: [
                            _buildField(
                              controller: sofaQtyController,
                              label: 'QTY SOFA',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            _buildField(
                              controller: sofaValController,
                              label: 'Value Penjualan',
                              prefixText: 'Rp ',
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              onChanged: (_) => setModalState(() {}),
                            ),
                            _buildField(
                              controller: sofaNoSoController,
                              label: 'Nomor SO',
                              hintText: 'Contoh: SO-54321',
                            ),
                          ],
                        ),

                        // 4. BRAND: BEDDING / BUSA
                        _buildBrandCard(
                          brandTitle: 'BEDDING / BUSA',
                          accentColor: const Color(0xFF6366F1),
                          children: [
                            _buildField(
                              controller: bedValController,
                              label: 'Value Penjualan',
                              prefixText: 'Rp ',
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              onChanged: (_) => setModalState(() {}),
                            ),
                            _buildField(
                              controller: bedNoSoController,
                              label: 'Nomor SO',
                              hintText: 'Contoh: SO-98765',
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // TOTAL REAL-TIME CARD
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Nilai Baru:',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                'Rp ${_formatCurrency(currentTotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ACTION BUTTONS: BATAL & SIMPAN
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: OutlinedButton(
                                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Batal'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSubmitting = true;
                                        });

                                        final updateData = {
                                          'id': empId,
                                          'employeeId': empId,
                                          'timestamp': timestamp,
                                          'tanggal': fixedDate,
                                          'lawQtyOs': int.tryParse(lawQtyOsController.text.trim()) ?? 0,
                                          'lawQtyNh': int.tryParse(lawQtyNhController.text.trim()) ?? 0,
                                          'lawValue': parseVal(lawValController),
                                          'lawNoSo': lawNoSoController.text.trim(),
                                          'sbValue': parseVal(sbValController),
                                          'sbNoSo': sbNoSoController.text.trim(),
                                          'sofaQty': int.tryParse(sofaQtyController.text.trim()) ?? 0,
                                          'sofaValue': parseVal(sofaValController),
                                          'sofaNoSo': sofaNoSoController.text.trim(),
                                          'bedValue': parseVal(bedValController),
                                          'bedNoSo': bedNoSoController.text.trim(),
                                          if (rowIndex != null) 'rowIndex': rowIndex!,
                                        };

                                        final nav = Navigator.of(ctx);
                                        final messenger = ScaffoldMessenger.of(context);
                                        final result = await widget.apiService.editSalesReport(updateData);

                                        if (!mounted) return;

                                        setModalState(() {
                                          isSubmitting = false;
                                        });

                                        if (result['status'] == 'success') {
                                          nav.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(result['message'] ?? 'Data transaksi berhasil diperbarui.'),
                                              backgroundColor: const Color(0xFF10B981),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          _loadSalesHistory(showSpinner: false);
                                          _loadPencapaian(showSpinner: false);
                                        } else {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(result['message'] ?? 'Gagal memperbarui transaksi.'),
                                              backgroundColor: Colors.red.shade600,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
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
            leading: const Icon(Icons.point_of_sale, color: Color(0xFF10B981)),
            title: const Text('Penjualan', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Input & Data Penjualan'),
            selected: _currentView == MainView.penjualan,
            selectedTileColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentView = MainView.penjualan;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ListTile(
              leading: const Icon(Icons.edit_note, size: 22, color: Color(0xFF10B981)),
              title: const Text('Input Penjualan', style: TextStyle(fontSize: 14)),
              selected: _currentView == MainView.penjualan && _tabController.index == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentView = MainView.penjualan;
                  _tabController.animateTo(0);
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, size: 22, color: Color(0xFF3B82F6)),
              title: const Text('Data Penjualan', style: TextStyle(fontSize: 14)),
              selected: _currentView == MainView.penjualan && _tabController.index == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentView = MainView.penjualan;
                  _tabController.animateTo(1);
                });
                _loadSalesHistory();
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
            title: const Text('Pencapaian Toko', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Podium & Peringkat Toko'),
            selected: _currentView == MainView.pencapaian,
            selectedTileColor: Colors.amber.withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentView = MainView.pencapaian;
              });
              _loadPencapaian();
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
                  _tabController.animateTo(0);
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
                    _tabController.animateTo(0);
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

          // BADGE STATUS IDENTITAS & MODE AKSES
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isAdminHistory
                  ? Colors.amber.withValues(alpha: 0.12)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isAdminHistory
                    ? Colors.amber.withValues(alpha: 0.35)
                    : const Color(0xFF3B82F6).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isAdminHistory ? Icons.admin_panel_settings : Icons.person_pin,
                  size: 18,
                  color: _isAdminHistory ? Colors.amber.shade700 : const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isAdminHistory
                        ? 'Mode Admin (ID: ${_idController.text.trim()}) • Menampilkan seluruh data SPG'
                        : 'Mode SPG (ID: ${_idController.text.trim()}${_nameController.text.trim().isNotEmpty ? " - ${_nameController.text.trim()}" : ""}) • Riwayat pribadi Anda',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isAdminHistory
                          ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                          : (isDark ? Colors.blue.shade300 : Colors.blue.shade900),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FILTER & PERIODE CONTAINER (Tampil untuk SPG & Admin)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isAdminHistory
                    ? Colors.amber.withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAdminHistory ? Icons.admin_panel_settings : Icons.calendar_month,
                      color: _isAdminHistory ? Colors.amber : const Color(0xFF3B82F6),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAdminHistory ? 'Filter & Periode Admin' : 'Filter Periode & Tanggal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isAdminHistory ? Colors.amber : const Color(0xFF3B82F6),
                      ),
                    ),
                    const Spacer(),
                    if (_isFilterActive)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedFilterPeriod = DateFormat('yyyy-MM').format(DateTime.now());
                            _selectedFilterStore = null;
                            _selectedFilterDate = null;
                            _selectedFilterProduct = null;
                          });
                          _loadSalesHistory(showSpinner: true);
                        },
                        child: Text(
                          'Reset Filter',
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isAdminHistory) ...[
                  // Row 1 Admin: Periode & Toko
                  Row(
                    children: [
                      // Periode Dropdown
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilterPeriod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Periode Bulan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            ..._availablePeriods.map((period) {
                              final isCurrent = period == DateFormat('yyyy-MM').format(DateTime.now());
                              return DropdownMenuItem<String>(
                                value: period,
                                child: Text(
                                  '${_formatIndonesianPeriod(period)}${isCurrent ? " (Bulan Ini)" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: 'all',
                              child: Text('Semua Periode (All-Time)', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedFilterPeriod = val;
                              _selectedFilterDate = null;
                            });
                            _loadSalesHistory(showSpinner: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2 Admin: Tanggal Picker
                  OutlinedButton.icon(
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
                      _selectedFilterDate != null ? 'Tanggal: $_selectedFilterDate' : 'Semua Tanggal (Sesuai Periode)',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else ...[
                  // SPG Mode: Periode Dropdown & Tanggal Picker Berdampingan
                  Row(
                    children: [
                      // Periode Dropdown
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilterPeriod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Periode Bulan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            ..._availablePeriods.map((period) {
                              final isCurrent = period == DateFormat('yyyy-MM').format(DateTime.now());
                              return DropdownMenuItem<String>(
                                value: period,
                                child: Text(
                                  '${_formatIndonesianPeriod(period)}${isCurrent ? " (Bulan Ini)" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: 'all',
                              child: Text('Semua Periode (All-Time)', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedFilterPeriod = val;
                              _selectedFilterDate = null;
                            });
                            _loadSalesHistory(showSpinner: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Tanggal
                      Expanded(
                        flex: 4,
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
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 15,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Jenis Barang:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _productFilterOptions.map((opt) {
                    final String? key = opt['key'] as String?;
                    final String label = opt['label'] as String;
                    final Color accent = opt['color'] as Color;
                    final bool isSelected = _selectedFilterProduct == key;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilterProduct = key;
                          _applyLocalProductFilter();
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: isDark ? 0.25 : 0.14)
                              : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? accent
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // SUMMARY STATS (Total Transaksi & Total Nilai)
          Builder(
            builder: (context) {
              final selectedMeta = _getSelectedProductMeta();
              final productShort = selectedMeta['shortLabel'] as String;
              final productColor = selectedMeta['color'] as Color;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_historyTotalTransactions Transaksi',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                _selectedFilterPeriod == 'all'
                                    ? 'Seluruh Periode (All-Time)'
                                    : 'Periode ${_formatIndonesianPeriod(_selectedFilterPeriod ?? "")}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (_selectedFilterProduct != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: productColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$productShort: $_historyFilteredProductUnits Unit',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: productColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total: Rp ${_formatCurrency(_historyTotalAmount)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
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
              final displayVal = _getProductFilteredValue(itemMap, _selectedFilterProduct);
              final formattedAmount = _formatCurrency(displayVal);
              final tokoName = itemMap['toko']?.toString().trim() ?? '';
              final bool isEdited = itemMap['isEdited'] == true ||
                  (itemMap['editedLabel']?.toString().trim().isNotEmpty ?? false);
              final selectedMeta = _getSelectedProductMeta();
              final productColor = selectedMeta['color'] as Color;
              final productBreakdown = _selectedFilterProduct != null
                  ? _getProductCardBreakdown(itemMap, _selectedFilterProduct)
                  : '';

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
                              // NAMA SPG, NAMA TOKO, & BADGE EDITED
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    rawName,
                                    style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (_isAdminHistory && tokoName.isNotEmpty)
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
                                  if (isEdited)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_note, size: 13, color: Color(0xFFD97706)),
                                          SizedBox(width: 3),
                                          Text(
                                            'Edited',
                                            style: TextStyle(
                                              color: Color(0xFFD97706),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                              // TOTAL NILAI (Sesuai filter jenis barang atau total keseluruhan)
                              Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                ),
                              ),
                              if (productBreakdown.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: productColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: productColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    productBreakdown,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: productColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Trailing '...' icon
                        IconButton(
                          icon: const Icon(Icons.more_horiz, color: Colors.grey),
                          tooltip: 'Pilihan Transaksi',
                          onPressed: () => _showTransactionActionsModal(itemMap),
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

  Widget _buildSalesInputTab() {
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
            // SHORTCUT BANNER TO DATA PENJUALAN
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
                      _tabController.animateTo(1);
                      _loadSalesHistory();
                    },
                    child: const Row(
                      children: [
                        Text(
                          'Buka Data Penjualan',
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

    final isPenjualan = _currentView == MainView.penjualan;

    return Scaffold(
      drawer: _buildSidebar(),
      appBar: AppBar(
        title: Text(
          isPenjualan
              ? (_tabController.index == 0 ? 'Penjualan' : 'Data Penjualan')
              : 'Pencapaian Toko',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isPenjualan && _tabController.index == 1)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  _tabController.animateTo(0);
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
              if (!isPenjualan) {
                _loadPencapaian(showSpinner: true);
              } else if (_tabController.index == 1) {
                _loadSalesHistory(showSpinner: true);
              } else {
                _loadPromotorNames(forceRefresh: true);
                _loadPencapaian(showSpinner: true);
              }
            },
          ),
        ],
        bottom: isPenjualan
            ? TabBar(
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
                    icon: Icon(Icons.receipt_long),
                    text: 'Data Penjualan',
                  ),
                ],
              )
            : null,
      ),
      body: isPenjualan
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildSalesInputTab(),
                _buildSalesListTab(),
              ],
            )
          : _buildPencapaianTab(),
    );
  }
}
