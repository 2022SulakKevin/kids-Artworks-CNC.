import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(CNCControllerApp());

class CNCControllerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CoreXY CNC Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CNCControllerPage(),
    );
  }
}

class CNCControllerPage extends StatefulWidget {
  @override
  _CNCControllerPageState createState() => _CNCControllerPageState();
}

class _CNCControllerPageState extends State<CNCControllerPage> {
  WebSocketChannel? channel;
  bool isConnected = false;
  String receivedMessage = '';
  List<List<Offset>> shapes = [[]];
  double bedWidth = 50.0;
  double bedHeight = 50.0;
  double stepSize = 1.0;
  List<String> gcodeLines = [];
  int currentLineIndex = 0;
  bool isSending = false;
  final GlobalKey canvasKey = GlobalKey();

  void connectToMachine() {
    try {
      final newChannel = IOWebSocketChannel.connect('ws://192.168.4.1:81');
      newChannel.stream.listen(
        (message) {
          setState(() {
            receivedMessage = message;
            isConnected = true;
          });
          if (isSending && message.contains("ok")) {
            currentLineIndex++;
            if (currentLineIndex < gcodeLines.length) {
              sendNextLine();
            } else {
              isSending = false;
              sendGCode("G90\nM3 S120\nG4 P1.0\nG0 X0 Y0\nM3 S30\nG4 P1.0\nM5");
            }
          }
        },
        onDone: () {
          setState(() => isConnected = false);
        },
        onError: (error) {
          setState(() => isConnected = false);
        },
      );
      setState(() {
        channel = newChannel;
        isConnected = true;
      });
    } catch (_) {
      setState(() => isConnected = false);
    }
  }

  void sendGCode(String code) {
    if (channel != null) {
      channel!.sink.add(code);
    }
  }

  void sendNextLine() {
    if (currentLineIndex < gcodeLines.length) {
      String line = gcodeLines[currentLineIndex].trim();
      if (line.isNotEmpty) {
        sendGCode(line);
      } else {
        currentLineIndex++;
        sendNextLine();
      }
    }
  }

  void generateGCodeFromDrawing() {
    if (shapes.every((shape) => shape.isEmpty)) return;
    final RenderBox? box =
        canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final canvasSize = box.size;

    StringBuffer gcode = StringBuffer();
    gcode.writeln("G21"); // millimeters
    gcode.writeln("G90"); // absolute positioning
    gcode.writeln("M3 S120"); // Pen up
    gcode.writeln("G4 P0.5");

    for (final shape in shapes) {
      if (shape.length < 2) continue;

      final first = shape.first;
      double x0 = (first.dx * bedWidth / canvasSize.width);
      double y0 = (first.dy * bedHeight / canvasSize.height);

      gcode.writeln("G0 X${x0.toStringAsFixed(2)} Y${y0.toStringAsFixed(2)}");
      gcode.writeln("M3 S30"); // Pen down
      gcode.writeln("G4 P0.5");

      for (int i = 1; i < shape.length; i++) {
        final curr = shape[i];
        double x1 = (curr.dx * bedWidth / canvasSize.width);
        double y1 = (curr.dy * bedHeight / canvasSize.height);

        gcode.writeln(
          "G1 X${x1.toStringAsFixed(2)} Y${y1.toStringAsFixed(2)} F2000",
        );

        x0 = x1;
        y0 = y1;
      }

      gcode.writeln("M3 S120"); // Pen up
      gcode.writeln("G4 P0.5");
    }

    gcode.writeln("G0 X0 Y0");
    gcode.writeln("M5"); // Detach or end

    gcodeLines = gcode.toString().split('\n');
    currentLineIndex = 0;
    isSending = true;
    sendNextLine();
  }

  void clearDrawing() {
    setState(() => shapes = [[]]);
  }

  void showSettingsDialog() {
    TextEditingController widthController = TextEditingController(
      text: bedWidth.toString(),
    );
    TextEditingController heightController = TextEditingController(
      text: bedHeight.toString(),
    );
    TextEditingController stepController = TextEditingController(
      text: stepSize.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Settings"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widthController,
                  decoration: InputDecoration(labelText: 'Bed Width (mm)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: heightController,
                  decoration: InputDecoration(labelText: 'Bed Height (mm)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stepController,
                  decoration: InputDecoration(labelText: 'Step Size (mm)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => sendGCode("G0 X0 Y0"),
                  child: Text("Move to Origin (0,0)"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    bedWidth =
                        double.tryParse(widthController.text) ?? bedWidth;
                    bedHeight =
                        double.tryParse(heightController.text) ?? bedHeight;
                    stepSize = double.tryParse(stepController.text) ?? stepSize;
                  });
                  Navigator.pop(context);
                },
                child: Text("OK"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CoreXY CNC Controller"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: connectToMachine,
              icon: Icon(Icons.power_settings_new, color: Colors.white),
              label: Text(isConnected ? "Connected" : "Disconnected"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),
          IconButton(onPressed: showSettingsDialog, icon: Icon(Icons.settings)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              GestureDetector(
                onPanStart: (details) {
                  setState(() => shapes.add([details.localPosition]));
                },
                onPanUpdate: (details) {
                  setState(() => shapes.last.add(details.localPosition));
                },
                onPanEnd: (_) => setState(() => shapes.add([])),
                child: Container(
                  key: canvasKey,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: Colors.white,
                  child: CustomPaint(
                    painter: DrawingPainter(shapes, drawFrame: true),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 10,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => generateGCodeFromDrawing(),
                      child: Text("Send"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: clearDrawing,
                      child: Text("Clear"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset>> shapes;
  final bool drawFrame;
  DrawingPainter(this.shapes, {this.drawFrame = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.blue
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.0;
    for (var shape in shapes) {
      for (int i = 0; i < shape.length - 1; i++) {
        canvas.drawLine(shape[i], shape[i + 1], paint);
      }
    }

    if (drawFrame) {
      final borderPaint =
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
