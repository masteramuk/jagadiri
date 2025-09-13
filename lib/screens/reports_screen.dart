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
  double _currentPage = 0.0;

  final List<Map<String, dynamic>> reports = [
    {'icon': Icons.trending_up, 'label': 'Individual Health Trends'},
    {'icon': Icons.compare_arrows, 'label': 'Comparison and Summary'},
    {'icon': Icons.assessment, 'label': 'Risk Assessment'},
    {'icon': Icons.link, 'label': 'Correlation'},
    {'icon': Icons.track_changes, 'label': 'Body Composition & Goal Tracking'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Reports'),
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 350,
              height: 350,
              child: CustomPaint(
                painter: DonutChartPainter(itemCount: reports.length),
              ),
            ),
            SizedBox(
              height: 400, // Increased height for better spacing
              child: PageView.builder(
                controller: _pageController,
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final double scale = max(0.8, 1 - (_currentPage - index).abs() * 0.4);
                  return _buildCarouselItem(reports[index], scale);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> report, double scale) {
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(report['icon'], size: 60),
            onPressed: () => _showFormatDialog(context, report['label']),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              report['label'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFormatDialog(BuildContext context, String reportType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Format for $reportType'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReportViewScreen(
                        reportType: reportType,
                        format: 'PDF',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Excel'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReportViewScreen(
                        reportType: reportType,
                        format: 'Excel',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final int itemCount;
  final List<Color> colors = [
    Colors.blue[200]!,
    Colors.green[200]!,
    Colors.orange[200]!,
    Colors.purple[200]!,
    Colors.red[200]!,
  ];

  DonutChartPainter({required this.itemCount});

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
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i * sweepAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
