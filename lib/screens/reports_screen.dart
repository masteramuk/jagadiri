import 'package:flutter/material.dart';
import 'dart:math';
import 'package:jagadiri/screens/report_view_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.5, initialPage: 0);
  double _page = 0.0;
  int _currentPageIndex = 0;

  final List<Map<String, dynamic>> reports = [
    {
      'id': 'individual_trends',
      'icon': Icons.trending_up,
      'label': 'Individual Health Trends',
      'description': 'Track your health metrics over time. This report shows trends for blood sugar, blood pressure, and pulse, helping you understand your health trajectory.'
    },
    {
      'id': 'comparison_summary',
      'icon': Icons.compare_arrows,
      'label': 'Comparison and Summary',
      'description': 'Get a summary of your health data. This report provides an overview of your metrics, comparing them to previous periods and highlighting key changes.'
    },
    {
      'id': 'risk_assessment',
      'icon': Icons.assessment,
      'label': 'Risk Assessment',
      'description': 'Understand your health risks. This report analyzes your data to identify potential risks and provides recommendations for mitigation.'
    },
    {
      'id': 'correlation',
      'icon': Icons.link,
      'label': 'Correlation',
      'description': 'Discover how different health metrics are related. This report explores correlations between, for example, your diet and blood sugar levels.'
    },
    {
      'id': 'body_composition',
      'icon': Icons.track_changes,
      'label': 'Body Composition & Goal Tracking',
      'description': 'Monitor your body composition and track progress towards your goals. This report includes metrics like BMI and weight, helping you stay on track.'
    },
  ];

  final List<Color> colors = [
    Colors.blue[200]!,
    Colors.green[200]!,
    Colors.orange[200]!,
    Colors.purple[200]!,
    Colors.red[200]!,
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _page = _pageController.page!;
          _currentPageIndex = _page.round() % reports.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _currentPageIndex = _page.round() % reports.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Reports'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -(_page * 2 * pi / reports.length),
                child: SizedBox(
                  width: 350,
                  height: 350,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      itemCount: reports.length,
                      colors: colors,
                      selectedIndex: _currentPageIndex,
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -(_page * 2 * pi / reports.length),
                child: SizedBox(
                  width: 350,
                  height: 350,
                  child: Stack(
                    children: List.generate(reports.length, (index) {
                      final double angle = 2 * pi * index / reports.length;
                      final double radius = 145;
                      final double x = radius * cos(angle - pi / 2);
                      final double y = radius * sin(angle - pi / 2);
                      return Positioned(
                        left: 175 + x - 15,
                        top: 175 + y - 15,
                        child: Icon(
                          reports[index]['icon'],
                          color: _currentPageIndex == index ? Colors.black : Colors.grey[600],
                          size: 30,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: reports.length * 10,
                  itemBuilder: (context, index) {
                    final reportIndex = index % reports.length;
                    double scale = max(0.8, 1 - (_page - index).abs() * 0.4);
                    return _buildCarouselItem(reports[reportIndex], reportIndex, scale);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Swipe left or right to select a report',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            height: 150,
            child: Text(
              reports[_currentPageIndex]['description'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> report, int index, double scale) {
    bool isSelected = index == _currentPageIndex;
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              report['icon'],
              size: 60,
              color: isSelected ? colors[index] : Colors.black54,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReportViewScreen(
                    reportId: report['id'],
                    reportLabel: report['label'],
                    reportDescription: report['description'], // Pass description
                    reportIcon: report['icon'], // Pass icon
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              report['label'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final int itemCount;
  final List<Color> colors;
  final int selectedIndex;

  DonutChartPainter({required this.itemCount, required this.colors, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 60.0;

    final double radius = size.width / 2 - paint.strokeWidth / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double startAngle = -pi / 2;
    final double sweepAngle = 2 * pi / itemCount;

    for (int i = 0; i < itemCount; i++) {
      final bool isSelected = i == selectedIndex;
      paint.color = isSelected ? Color.lerp(colors[i], Colors.black, 0.2)! : colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i * sweepAngle,
        sweepAngle - 0.02,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}