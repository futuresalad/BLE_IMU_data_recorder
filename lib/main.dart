import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'ble_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: StreamDataPage(),
  ));
}

class StreamDataPage extends StatefulWidget {
  const StreamDataPage({super.key});

  @override
  State<StreamDataPage> createState() => _StreamDataPageState();
}

class _StreamDataPageState extends State<StreamDataPage> {
  final BleHandler _bleHandler = BleHandler(); // Use the singleton instance
  final List<List<double>> _parsedData = [];
  final TextEditingController _directoryController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    _bleHandler.dataStream.listen((data) {
      if (data.length > 110) {
        // Everything else is just info data
        List<double> parsedData = _parseData(data);
        if (parsedData.isNotEmpty) {
          setState(() {
            _parsedData.add(parsedData);
          });
        }
      }
    });
  }

  List<double> _parseData(String data) {
    List<String> parts = data.split(',');
    if (parts.length != 16) {
      return [];
    }

    List<double> numbers =
        parts.map((part) => double.tryParse(part) ?? 0.0).toList();
    return numbers; // Include the timestamp
  }

  void _clearData() {
    setState(() {
      _parsedData.clear();
    });
  }

  Future<void> _connectToDevice() async {
    int status = await _bleHandler.connectToDevice();
    if (status == 0) {
      setState(() {
        _isConnected = true;
      });
      developer.log('Connected to device');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to device')),
      );
    }
  }

  Future<void> _exportToCsv() async {
    List<List<String>> csvData = [
      // Add headers
      [
        't',
        'x_0',
        'y_0',
        'z_0',
        'x_1',
        'y_1',
        'z_1',
        'x_2',
        'y_2',
        'z_2',
        'x_3',
        'y_3',
        'z_3',
        'x_4',
        'y_4',
        'z_4'
      ],
      // Add data
      ..._parsedData
          .map((data) => data.map((value) => value.toString()).toList()),
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    final directory = _directoryController.text.isNotEmpty
        ? Directory(_directoryController.text)
        : await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/${_fileNameController.text.isNotEmpty ? _fileNameController.text : 'sensor_data'}.csv';
    final file = File(path);

    await file.writeAsString(csv);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Data exported to $path')));
    }
  }

  void _sendStartCommand() {
    if (_isConnected) {
      developer.log('Sending start command to device');
      _bleHandler.sendValue(Uint8List.fromList([ascii.encode('1')[0]]));
    } else {
      developer.log('Device not connected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected')),
      );
    }
  }

  void _testPrint() {
    developer.log('Test print');
  }

  @override
  void dispose() {
    _directoryController.dispose();
    _fileNameController.dispose();
    _bleHandler.dispose();
    super.dispose();
  }

  List<FlSpot> _generateSpots(int sensorIndex, int axisIndex) {
    return _parsedData.asMap().entries.map((entry) {
      int idx = entry.key;
      List<double> values = entry.value;
      return FlSpot(idx.toDouble(),
          values[sensorIndex * 3 + axisIndex + 1]); // Skip the timestamp
    }).toList();
  }

  Widget _buildChart(int sensorIndex) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        children: [
          Text(
            '${sensorIndex + 1}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: -2,
                maxY: 2,
                minX: 0,
                maxX: _parsedData.length.toDouble(),
                lineTouchData: const LineTouchData(enabled: false),
                clipData: const FlClipData.all(),
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateSpots(sensorIndex, 0),
                    isCurved: true,
                    color: Colors.blue[100],
                    barWidth: 1.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                    shadow:
                        const Shadow(color: Colors.blueGrey, blurRadius: .5),
                  ),
                  LineChartBarData(
                    spots: _generateSpots(sensorIndex, 1),
                    isCurved: true,
                    color: Colors.blue[400],
                    barWidth: 1.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                    shadow:
                        const Shadow(color: Colors.blueGrey, blurRadius: .5),
                  ),
                  LineChartBarData(
                    spots: _generateSpots(sensorIndex, 2),
                    isCurved: true,
                    color: Colors.blue[900],
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                    shadow:
                        const Shadow(color: Colors.blueGrey, blurRadius: .5),
                  ),
                ],
                titlesData: const FlTitlesData(
                  show: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Speaksense Sample recorder',
          style: TextStyle(color: Colors.white, fontFamily: 'OpenSans'),
        ),
        backgroundColor: Colors.blue[400],
      ),
      body: Center(
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _parsedData.isNotEmpty
                    ? Column(
                        children: [
                          Expanded(child: _buildChart(0)),
                          Expanded(child: _buildChart(1)),
                          Expanded(child: _buildChart(2)),
                          Expanded(child: _buildChart(3)),
                          Expanded(child: _buildChart(4)),
                        ],
                      )
                    : const Center(child: Text('No data available')),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding:
                    const EdgeInsets.all(8.0), // Add padding around the column
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Connect to device',
                        iconSize: 50,
                        padding: const EdgeInsets.all(40),
                        onPressed: () {
                          _connectToDevice();
                        },
                        icon: _isConnected
                            ? const Icon(
                                Icons.bluetooth_rounded,
                                shadows: [
                                  Shadow(blurRadius: 35, color: Colors.blue)
                                ],
                              )
                            : const Icon(Icons.bluetooth_disabled_rounded,
                                color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _directoryController,
                        decoration: const InputDecoration(
                          labelText: 'Directory',
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _fileNameController,
                        decoration: const InputDecoration(
                          labelText: 'File Name',
                        ),
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        onPressed: () {
                          _clearData();
                          _sendStartCommand();
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        iconSize: 50,
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        onPressed: _clearData,
                        icon: const Icon(Icons.clear),
                        iconSize: 50,
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        onPressed: _exportToCsv,
                        icon: const Icon(Icons.save_alt),
                        iconSize: 50,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
