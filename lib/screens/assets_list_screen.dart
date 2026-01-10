import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import 'asset_detail_screen.dart';

class AssetsListScreen extends StatefulWidget {
  const AssetsListScreen({super.key});

  @override
  State<AssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends State<AssetsListScreen> {
  List<Map<String, dynamic>> _allAssets = [];
  List<Map<String, dynamic>> _filteredAssets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedStatus = 'Todos';

  final List<String> _categories = [
    'Todos',
    'Tecnologia',
    'Mobiliário',
    'Climatização',
    'Utilidades',
    'Equipamentos'
  ];

  final List<String> _statuses = [
    'Todos',
    'Ativo',
    'Manutenção',
    'Em Uso',
    'Inativo'
  ];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.getUserProfile(user.id);
      final orgId = profile?['organizacao_atual_id'];

      if (orgId != null) {
        final assets = await SupabaseService.getAssets(orgId);
        setState(() {
          _allAssets = assets;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ativos: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAssets = _allAssets.where((asset) {
        final matchesSearch = _searchQuery.isEmpty ||
            asset['nome']
                ?.toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ==
                true ||
            asset['localizacao']
                ?.toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ==
                true ||
            asset['responsavel']
                ?.toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ==
                true;

        final matchesCategory = _selectedCategory == 'Todos' ||
            asset['categoria'] == _selectedCategory;

        final matchesStatus =
            _selectedStatus == 'Todos' || asset['status_ativo'] == _selectedStatus;

        return matchesSearch && matchesCategory && matchesStatus;
      }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categoria
            const Text(
              'Categoria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  // ignore: deprecated_member_use
                  selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF3B82F6),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Status
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _statuses.map((status) {
                final isSelected = _selectedStatus == status;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatus = status;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  // ignore: deprecated_member_use
                  selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF3B82F6),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'Todos';
                  _selectedStatus = 'Todos';
                  _applyFilters();
                });
                Navigator.pop(context);
              },
              child: const Text('Limpar Filtros'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ativos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nome, local ou responsável...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // Contador de Resultados
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Mostrando ${_filteredAssets.length} de ${_allAssets.length} ativos',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  if (_selectedCategory != 'Todos' ||
                      _selectedStatus != 'Todos') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Filtrado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Lista de Ativos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAssets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _allAssets.isEmpty
                                  ? 'Nenhum ativo cadastrado'
                                  : 'Nenhum ativo encontrado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_allAssets.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'Todos';
                                    _selectedStatus = 'Todos';
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAssets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAssets.length,
                          itemBuilder: (context, index) {
                            final asset = _filteredAssets[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF2563EB)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      asset['icone'] ?? '📦',
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  asset['nome'] ?? 'Sem nome',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${asset['categoria']} • ${asset['localizacao']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'R\$ ${_formatCurrency(asset['valor'])}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(asset['status_ativo'])
                                        // ignore: deprecated_member_use
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    asset['status_ativo'] ?? 'Ativo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _getStatusColor(asset['status_ativo']),
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AssetDetailScreen(asset: asset),
                                    ),
                                  ).then((_) => _loadAssets());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Ativo':
      case 'Em Uso':
        return const Color(0xFF10B981);
      case 'Manutenção':
        return const Color(0xFFF59E0B);
      case 'Inativo':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0,00';
    final number =
        value is String ? double.tryParse(value) ?? 0 : value.toDouble();
    return NumberFormat('#,##0.00', 'pt_BR').format(number);
  }
}