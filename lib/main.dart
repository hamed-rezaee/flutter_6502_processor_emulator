import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_6502_processor_emulator/emulator/bus.dart';
import 'package:flutter_6502_processor_emulator/emulator/cpu.dart';
import 'package:flutter_6502_processor_emulator/emulator/disassemble.dart';
import 'package:flutter_6502_processor_emulator/emulator/ram.dart';
import 'package:flutter_6502_processor_emulator/extensions.dart';
import 'package:google_fonts/google_fonts.dart';

const int offset = 0x8000;

// 6502 test program, calculates 3 * 10 :)
const String code =
    'A2 0A 8E 00 00 A2 03 8E 01 00 AC 00 00 A9 00 18 6D 01 00 88 D0 FA 8D 02 00 EA EA EA';

void main() => runApp(const MainApp());

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final Cpu cpu = Cpu(Bus(Ram()));

  late final Map<int, String> result;

  @override
  void initState() {
    super.initState();

    cpu.pc = offset;

    final List<int> listCode =
        code.split(' ').map((String hex) => int.parse(hex, radix: 16)).toList();

    for (int i = offset; i < offset + listCode.length; i++) {
      cpu.write(i, listCode[i - offset]);
    }

    result = disassemble(cpu, 0x0000, cpu.bus.ram.size);
  }

  @override
  Widget build(BuildContext context) => RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleKeyEvent,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            textTheme:
                GoogleFonts.pressStart2pTextTheme(Theme.of(context).textTheme),
          ),
          home: Scaffold(
            backgroundColor: Colors.blue.shade900,
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 450,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildRam(0x0000, 16, 16),
                            _buildRam(0x8000, 16, 16),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 250,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildFlags(),
                            const SizedBox(height: 4),
                            _buildRegisters(),
                            const SizedBox(height: 4),
                            _buildDisassembler(result),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'SPACE = Step Instruction    R = RESET    I = IRQ    N = NMI',
                    style: TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildFlags() => Row(
        children: <Widget>[
          const Text(
            'STATUS: ',
            style: TextStyle(fontSize: 8, color: Colors.white),
          ),
          _buildFlag(cpu.flags.n, 'N'),
          _buildFlag(cpu.flags.v, 'V'),
          _buildFlag(false, '-'),
          _buildFlag(cpu.flags.b, 'B'),
          _buildFlag(cpu.flags.d, 'D'),
          _buildFlag(cpu.flags.i, 'I'),
          _buildFlag(cpu.flags.z, 'Z'),
          _buildFlag(cpu.flags.c, 'C'),
        ],
      );

  Widget _buildFlag(bool value, String label) => Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: value ? Colors.green : Colors.red,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 8)
        ],
      );

  Widget _buildRegisters() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildRegister(cpu.a, 'A ', precision: 2, showDecimal: true),
          _buildRegister(cpu.x, 'X ', precision: 2, showDecimal: true),
          _buildRegister(cpu.y, 'Y ', precision: 2, showDecimal: true),
          const SizedBox(height: 2),
          _buildRegister(cpu.pc, 'PC'),
          _buildRegister(cpu.sp, 'SP', precision: 2),
        ],
      );

  Widget _buildRegister(
    int value,
    String label, {
    int precision = 4,
    bool showDecimal = false,
  }) =>
      Text(
        '$label: ${value.printHex(precision: precision)}${showDecimal ? '   [$value]' : ''} ',
        style: const TextStyle(fontSize: 8, color: Colors.white, height: 1.2),
      );

  Widget _buildRam(int address, int rows, int columns) {
    final StringBuffer offset = StringBuffer();
    int currentAddress = address;

    for (int row = 0; row < rows; row++) {
      offset.write('${currentAddress.printHex()}:');

      for (int column = 0; column < columns; column++) {
        offset.write(
          '${cpu.read(currentAddress).printHex(precision: 2, prefix: ' ')}',
        );

        currentAddress += 1;
      }

      offset.write('\n');
    }

    return Text(
      '$offset',
      style: const TextStyle(fontSize: 8, color: Colors.white, height: 1.2),
    );
  }

  Widget _buildDisassembler(Map<int, String> result) {
    const int instructionLenght = 26;
    const int halfInstructionLenght = instructionLenght ~/ 2;

    return ListView.builder(
      shrinkWrap: true,
      itemCount: instructionLenght,
      itemBuilder: (BuildContext context, int index) {
        final int actualIndex =
            ((index - halfInstructionLenght) + (cpu.pc ~/ 2)) % result.length;

        return Text(
          result.entries.elementAt(actualIndex).value,
          style: TextStyle(
            fontSize: 8,
            height: 1.2,
            color: cpu.pc == result.entries.elementAt(actualIndex).key
                ? Colors.cyan
                : Colors.white,
          ),
        );
      },
    );
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.space)) {
      do {
        cpu.clock();
      } while (!cpu.complete());
    }

    if (event.isKeyPressed(LogicalKeyboardKey.keyR)) {
      cpu.reset();
    }

    if (event.isKeyPressed(LogicalKeyboardKey.keyI)) {
      cpu.irq();
    }

    if (event.isKeyPressed(LogicalKeyboardKey.keyN)) {
      cpu.nmi();
    }

    setState(() {});
  }
}
