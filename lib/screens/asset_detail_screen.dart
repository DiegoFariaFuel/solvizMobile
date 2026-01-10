import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class AssetDetailScreen extends StatefulWidget {
  final Map<String, dynamic> asset;

  const AssetDetailScreen({super.key, required this.asset});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Map<String, dynamic> _asset;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _asset = Map.from(widget.asset);
  }

  // ==================== ATUALIZAR LOCALIZAÇÃO ====================
  Future<void> _updateAssetLocation() async {
    final controller = TextEditingController(text: _asset['localizacao']);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualizar Localização'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nova localização',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == _asset['localizacao']) return;

    setState(() => _isUpdating = true);

    try {
      final user = SupabaseService.currentUser;
      final profile = await SupabaseService.getUserProfile(user!.id);
      final orgId = profile?['organizacao_atual_id'];

      // Registrar movimentação
      await SupabaseService.createMovement({
        'codigo_ativo': _asset['codigo'],
        'localizacao_atual': _asset['localizacao'],
        'nova_localizacao': result,
        'quantidade': _asset['quantidade'] ?? 1,
        'motivo': 'Movimentação via app móvel',
        'data_movimentacao': DateTime.now().toIso8601String().split('T')[0],
        'organizacao_id': orgId,
      });

      // Atualizar ativo
      await SupabaseService.updateAsset(_asset['codigo'], {
        'localizacao': result,
        'ultima_verificacao': DateTime.now().toIso8601String().split('T')[0],
      });

      setState(() => _asset['localizacao'] = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Localização atualizada!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ==================== ATUALIZAR STATUS ====================
  Future<void> _updateAssetStatus() async {
    final statuses = ['Ativo', 'Manutenção', 'Em Uso', 'Inativo'];
    String? selected = _asset['status_ativo'];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Status do Ativo'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) {
              return RadioListTile<String>(
                title: Text(status),
                value: status,
                // ignore: deprecated_member_use
                groupValue: selected,
                activeColor: _getStatusColor(status),
                // ignore: deprecated_member_use
                onChanged: (value) {
                  setStateDialog(() => selected = value);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result == null || result == _asset['status_ativo']) return;

    setState(() => _isUpdating = true);

    try {
      await SupabaseService.updateAsset(_asset['codigo'], {
        'status_ativo': result,
        'ultima_verificacao': DateTime.now().toIso8601String().split('T')[0],
      });

      setState(() => _asset['status_ativo'] = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status atualizado com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ==================== MOSTRAR QR CODE ====================
  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('QR Code do Ativo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              QrImageView(
                data: _asset['codigo'],
                size: 280,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              const SizedBox(height: 16),
              SelectableText(
                _asset['codigo'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Ativo'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _showQRCode),
        ],
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Card Principal
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            _asset['icone'] ?? 'Box',
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _asset['nome'] ?? 'Ativo sem nome',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_asset['status_ativo']).withAlpha(28),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _asset['status_ativo'] ?? 'Ativo',
                          style: TextStyle(
                            color: _getStatusColor(_asset['status_ativo']),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Informações Gerais
              Card(
                child: ListTileTheme(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Informações Gerais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        _infoRow('Código', _asset['codigo'] ?? '-', Icons.tag),
                        const Divider(height: 1),
                        _infoRow('Categoria', _asset['categoria'] ?? '-', Icons.category_outlined),
                        const Divider(height: 1),
                        _infoRow('Valor', 'R\$ ${_formatCurrency(_asset['valor'])}', Icons.attach_money),
                        const Divider(height: 1),
                        _infoRow('Quantidade', '${_asset['quantidade'] ?? 1}', Icons.inventory_2_outlined),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Localização
              Card(
                child: ListTileTheme(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Localização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Row(
                          children: [
                            Expanded(child: _infoRow('Local Atual', _asset['localizacao'] ?? '-', Icons.location_on_outlined)),
                            IconButton(
                              icon: const Icon(Icons.edit_location_alt_outlined, color: Color(0xFF3B82F6)),
                              onPressed: _updateAssetLocation,
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        _infoRow('Responsável', _asset['responsavel'] ?? '-', Icons.person_outline),
                        const Divider(height: 1),
                        _infoRow('Última Verificação', _formatDate(_asset['ultima_verificacao']), Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Ações
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Ações Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync_alt),
                        label: const Text('Alterar Status'),
                        onPressed: _updateAssetStatus,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.transfer_within_a_station),
                        label: const Text('Movimentar Ativo'),
                        onPressed: _updateAssetLocation,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ]),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF64748B)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    return switch (status) {
      'Ativo' || 'Em Uso' => const Color(0xFF10B981),
      'Manutenção' => const Color(0xFFF59E0B),
      'Inativo' => const Color(0xFFEF4444),
      _ => const Color(0xFF64748B),
    };
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0,00';
    final number = value is String ? double.tryParse(value) ?? 0.0 : (value is num ? value.toDouble() : 0.0);
    return NumberFormat.currency(locale: 'pt_BR', symbol: '').format(number).trim();
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }
}