import 'package:flutter/material.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

class TraceViewer extends StatelessWidget {
  final List<UcpPacketTrace> packetTraces;
  final String Function(UcpPacketTrace trace) formatTrace;

  const TraceViewer({
    super.key,
    required this.packetTraces,
    required this.formatTrace,
  });

  @override
  Widget build(BuildContext context) {
    if (packetTraces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No packets yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Packets will appear here during device communication',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: packetTraces.length,
      itemBuilder: (context, index) {
        final trace = packetTraces[index];
        return _buildTraceCard(context, trace);
      },
    );
  }

  Widget _buildTraceCard(BuildContext context, UcpPacketTrace trace) {
    final frame = trace.frame;
    final isTx = trace.direction == UcpPacketDirection.tx;
    final directionColor = isTx ? const Color(0xFF1565C0) : const Color(0xFF2E7D32);
    final directionLabel = isTx ? 'TX' : 'RX';
    final directionBg = isTx
        ? const Color(0xFF1565C0).withValues(alpha: 0.08)
        : const Color(0xFF2E7D32).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: directionBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: directionColor.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Direction badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: directionColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      directionLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Frame info
                  if (frame != null) ...[
                    Text(
                      'OP: 0x${frame.op.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CL: 0x${frame.commandClass.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CMD: 0x${frame.commandId.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SEQ: ${frame.sequence}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),

              // Decoded TLVs
              if (trace.decodedTlvs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: trace.decodedTlvs.map(
                      (tlv) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  tlv.typeName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SelectableText(
                                  tlv.displayValue,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey.shade800,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ],

              // Raw bytes
              const SizedBox(height: 6),
              SelectableText(
                EndianUtils.toHexString(trace.bytes),
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}