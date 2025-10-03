import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';

/// Main Audit Dashboard with all advanced features
class AuditDashboard extends ConsumerStatefulWidget {
  const AuditDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<AuditDashboard> createState() => _AuditDashboardState();
}

class _AuditDashboardState extends ConsumerState<AuditDashboard> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  bool _isAuditing = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade900,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LiveAuditTab(isAuditing: _isAuditing),
                    const _CompareTab(),
                    const _TrendAnalysisTab(),
                    const _ReportsTab(),
                    const _ConfigurationTab(),
                    const _HistoryTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.speed,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AuditMySite Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Professional Website Auditing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => _showNotifications(),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettings(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(icon: Icon(Icons.play_circle), text: 'Live Audit'),
          Tab(icon: Icon(Icons.compare_arrows), text: 'Compare'),
          Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
          Tab(icon: Icon(Icons.description), text: 'Reports'),
          Tab(icon: Icon(Icons.tune), text: 'Config'),
          Tab(icon: Icon(Icons.history), text: 'History'),
        ],
      ),
    );
  }
  
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _startNewAudit,
      backgroundColor: Colors.deepPurple,
      icon: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _isAuditing ? _animationController.value * 2 * 3.14159 : 0,
            child: Icon(_isAuditing ? Icons.sync : Icons.play_arrow),
          );
        },
      ),
      label: Text(_isAuditing ? 'Auditing...' : 'Start Audit'),
    );
  }
  
  void _startNewAudit() {
    setState(() {
      _isAuditing = !_isAuditing;
    });
    
    if (_isAuditing) {
      // Simulate audit
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isAuditing = false;
          });
        }
      });
    }
  }
  
  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }
  
  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

/// Live Audit Tab with real-time preview
class _LiveAuditTab extends StatefulWidget {
  final bool isAuditing;
  
  const _LiveAuditTab({Key? key, required this.isAuditing}) : super(key: key);
  
  @override
  State<_LiveAuditTab> createState() => _LiveAuditTabState();
}

class _LiveAuditTabState extends State<_LiveAuditTab> {
  final _urlController = TextEditingController();
  String _currentUrl = '';
  Map<String, dynamic> _liveData = {};
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _startLiveUpdates();
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    _urlController.dispose();
    super.dispose();
  }
  
  void _startLiveUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (widget.isAuditing && mounted) {
        setState(() {
          _liveData = _generateMockLiveData();
        });
      }
    });
  }
  
  Map<String, dynamic> _generateMockLiveData() {
    return {
      'performance': 75 + (DateTime.now().millisecond % 25),
      'accessibility': 85 + (DateTime.now().millisecond % 15),
      'seo': 80 + (DateTime.now().millisecond % 20),
      'pwa': 65 + (DateTime.now().millisecond % 35),
      'metrics': {
        'lcp': 2000 + (DateTime.now().millisecond % 1000),
        'fid': 50 + (DateTime.now().millisecond % 100),
        'cls': 0.05 + (DateTime.now().millisecond % 10) / 100,
      },
    };
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // URL Input Bar
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.link, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'Enter URL to audit...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _currentUrl = value;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => _scanQRCode(),
              ),
            ],
          ),
        ),
        
        // Live Preview and Metrics
        Expanded(
          child: Row(
            children: [
              // Website Preview
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.only(left: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _currentUrl.isEmpty 
                                    ? 'https://example.com' 
                                    : _currentUrl,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: widget.isAuditing
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _currentUrl.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.web,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Enter a URL to preview',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Text('Website Preview'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Live Metrics
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: Column(
                    children: [
                      _buildMetricCard(
                        'Performance',
                        _liveData['performance']?.toDouble() ?? 0,
                        Colors.green,
                        Icons.speed,
                      ),
                      const SizedBox(height: 15),
                      _buildMetricCard(
                        'Accessibility',
                        _liveData['accessibility']?.toDouble() ?? 0,
                        Colors.blue,
                        Icons.accessibility,
                      ),
                      const SizedBox(height: 15),
                      _buildMetricCard(
                        'SEO',
                        _liveData['seo']?.toDouble() ?? 0,
                        Colors.orange,
                        Icons.search,
                      ),
                      const SizedBox(height: 15),
                      _buildMetricCard(
                        'PWA',
                        _liveData['pwa']?.toDouble() ?? 0,
                        Colors.purple,
                        Icons.phone_android,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Live Console Output
        Container(
          height: 150,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListView(
            children: [
              _buildConsoleLog('[INFO] Audit started...', Colors.white),
              if (widget.isAuditing) ...[
                _buildConsoleLog('[AUDIT] Analyzing performance metrics...', Colors.blue),
                _buildConsoleLog('[AUDIT] Checking accessibility...', Colors.green),
                _buildConsoleLog('[AUDIT] Running SEO checks...', Colors.orange),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 8,
              ),
              Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildConsoleLog(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
  
  void _scanQRCode() {
    // QR code scanning functionality
  }
}

/// Compare Tab for comparing multiple websites
class _CompareTab extends StatefulWidget {
  const _CompareTab({Key? key}) : super(key: key);
  
  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  final List<String> _compareUrls = [];
  final _urlController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add URLs Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add URLs to Compare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Enter URL...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.link),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _addUrl,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    children: _compareUrls.map((url) {
                      return Chip(
                        label: Text(url),
                        onDeleted: () {
                          setState(() {
                            _compareUrls.remove(url);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Comparison Results
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comparison Results',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _compareUrls.length >= 2 ? _runComparison : null,
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('Compare'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_compareUrls.length < 2)
                      const Center(
                        child: Text(
                          'Add at least 2 URLs to compare',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Expanded(
                        child: _buildComparisonChart(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const categories = ['Performance', 'A11y', 'SEO', 'PWA'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    categories[value.toInt()],
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _generateComparisonData(),
      ),
    );
  }
  
  List<BarChartGroupData> _generateComparisonData() {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    return List.generate(4, (index) {
      return BarChartGroupData(
        x: index,
        barRods: _compareUrls.asMap().entries.map((entry) {
          return BarChartRodData(
            toY: 60 + (entry.key * 10) + (index * 5).toDouble(),
            color: colors[entry.key % colors.length],
            width: 20,
          );
        }).toList(),
      );
    });
  }
  
  void _addUrl() {
    if (_urlController.text.isNotEmpty) {
      setState(() {
        _compareUrls.add(_urlController.text);
        _urlController.clear();
      });
    }
  }
  
  void _runComparison() {
    // Run comparison logic
  }
}

/// Trend Analysis Tab
class _TrendAnalysisTab extends StatelessWidget {
  const _TrendAnalysisTab({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Date Range Selector
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  const Text(
                    'Date Range:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 20),
                  ChoiceChip(
                    label: const Text('7 Days'),
                    selected: true,
                    onSelected: (selected) {},
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('30 Days'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('90 Days'),
                    selected: false,
                    onSelected: (selected) {},
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Trend Chart
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 20,
                      verticalInterval: 1,
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    minX: 0,
                    maxX: 7,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _generateTrendData(),
                        isCurved: true,
                        color: Colors.deepPurple,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.deepPurple.withOpacity(0.1),
                        ),
                      ),
                      LineChartBarData(
                        spots: _generateTrendData2(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Insights
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trend Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInsight(
                    Icons.trending_up,
                    'Performance improved by 15% this week',
                    Colors.green,
                  ),
                  _buildInsight(
                    Icons.warning,
                    'SEO score dropped on Tuesday',
                    Colors.orange,
                  ),
                  _buildInsight(
                    Icons.check_circle,
                    'Accessibility consistently above 90%',
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<FlSpot> _generateTrendData() {
    return const [
      FlSpot(0, 75),
      FlSpot(1, 78),
      FlSpot(2, 72),
      FlSpot(3, 80),
      FlSpot(4, 85),
      FlSpot(5, 82),
      FlSpot(6, 88),
      FlSpot(7, 90),
    ];
  }
  
  List<FlSpot> _generateTrendData2() {
    return const [
      FlSpot(0, 85),
      FlSpot(1, 82),
      FlSpot(2, 88),
      FlSpot(3, 85),
      FlSpot(4, 90),
      FlSpot(5, 92),
      FlSpot(6, 90),
      FlSpot(7, 94),
    ];
  }
  
  Widget _buildInsight(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports Tab
class _ReportsTab extends StatelessWidget {
  const _ReportsTab({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Export Options
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildExportButton(Icons.html, 'HTML', Colors.orange),
                      _buildExportButton(Icons.picture_as_pdf, 'PDF', Colors.red),
                      _buildExportButton(Icons.table_chart, 'CSV', Colors.green),
                      _buildExportButton(Icons.code, 'JSON', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Recent Reports
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 10,
                        itemBuilder: (context, index) {
                          return _buildReportItem(
                            'https://example.com',
                            DateTime.now().subtract(Duration(days: index)),
                            85 - index * 2,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExportButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
  
  Widget _buildReportItem(String url, DateTime date, int score) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getScoreColor(score),
        child: Text(
          score.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(url),
      subtitle: Text(
        '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}',
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {},
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

/// Configuration Tab
class _ConfigurationTab extends StatefulWidget {
  const _ConfigurationTab({Key? key}) : super(key: key);
  
  @override
  State<_ConfigurationTab> createState() => _ConfigurationTabState();
}

class _ConfigurationTabState extends State<_ConfigurationTab> {
  String _device = 'Desktop';
  String _throttling = 'No Throttling';
  bool _screenshots = false;
  bool _notifications = true;
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audit Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Device Selection
                const Text('Device'),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Desktop', label: Text('Desktop')),
                    ButtonSegment(value: 'Mobile', label: Text('Mobile')),
                    ButtonSegment(value: 'Tablet', label: Text('Tablet')),
                  ],
                  selected: {_device},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _device = selection.first;
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Network Throttling
                const Text('Network Throttling'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _throttling,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'No Throttling',
                      child: Text('No Throttling'),
                    ),
                    DropdownMenuItem(
                      value: 'Fast 3G',
                      child: Text('Fast 3G'),
                    ),
                    DropdownMenuItem(
                      value: 'Slow 3G',
                      child: Text('Slow 3G'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _throttling = value!;
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Toggles
                SwitchListTile(
                  title: const Text('Capture Screenshots'),
                  subtitle: const Text('Save screenshots during audit'),
                  value: _screenshots,
                  onChanged: (value) {
                    setState(() {
                      _screenshots = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Get notified when audits complete'),
                  value: _notifications,
                  onChanged: (value) {
                    setState(() {
                      _notifications = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// History Tab
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 20,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.withOpacity(0.1),
              child: const Icon(Icons.history, color: Colors.deepPurple),
            ),
            title: Text('https://example.com/page-$index'),
            subtitle: Text(
              DateTime.now().subtract(Duration(hours: index)).toString(),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text('${85 - index}'),
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}

/// Notifications Dialog
class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notifications'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            _buildNotification(
              Icons.check_circle,
              'Audit completed successfully',
              '2 minutes ago',
              Colors.green,
            ),
            _buildNotification(
              Icons.warning,
              'Performance score dropped below 80',
              '1 hour ago',
              Colors.orange,
            ),
            _buildNotification(
              Icons.info,
              'New version available',
              '1 day ago',
              Colors.blue,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
  
  Widget _buildNotification(
    IconData icon,
    String title,
    String time,
    Color color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(time),
    );
  }
}

/// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Account'),
            subtitle: const Text('Manage your account'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Configure notifications'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            subtitle: const Text('Manage cache and data'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            subtitle: const Text('Get help and support'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('Version 2.0.0'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}