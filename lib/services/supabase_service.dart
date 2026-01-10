import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // IMPORTANTE: Substitua pelos seus valores do Supabase
  static const String _supabaseUrl = 'https://lggatwiafdzbaycjteec.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZ2F0d2lhZmR6YmF5Y2p0ZWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExNTY0MTMsImV4cCI6MjA3NjczMjQxM30.P7Ird68WVOn89U3ukMja_pm8TsQ8ZSk3-63zrW03drk';
  
  // Inicializar Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }
  
  // Auth
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // Perfil do Usuário
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('usuarios_perfis')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }
  
  // Organização
  static Future<Map<String, dynamic>?> getOrganization(String orgId) async {
    final response = await client
        .from('organizacoes')
        .select()
        .eq('id', orgId)
        .maybeSingle();
    return response;
  }
  
  // Ativos
  static Future<List<Map<String, dynamic>>> getAssets(String orgId) async {
    final response = await client
        .from('ativos')
        .select()
        .eq('organizacao_id', orgId)
        .order('ultima_verificacao', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
  
  static Future<Map<String, dynamic>?> getAssetByCode(String codigo) async {
    final response = await client
        .from('ativos')
        .select()
        .eq('codigo', codigo)
        .maybeSingle();
    return response;
  }
  
  static Future<void> updateAsset(String codigo, Map<String, dynamic> data) async {
    await client
        .from('ativos')
        .update(data)
        .eq('codigo', codigo);
  }
  
  static Future<void> createAsset(Map<String, dynamic> data) async {
    await client.from('ativos').insert(data);
  }
  
  // Movimentações
  static Future<void> createMovement(Map<String, dynamic> data) async {
    await client.from('movimentacoes').insert(data);
  }
  
  static Future<List<Map<String, dynamic>>> getMovements(String orgId) async {
    final response = await client
        .from('movimentacoes')
        .select()
        .eq('organizacao_id', orgId)
        .order('data_movimentacao', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  }
  
  // Estatísticas
  static Future<Map<String, dynamic>> getStatistics(String orgId) async {
    final assets = await getAssets(orgId);
    
    int totalAtivos = assets.length;
    int ativos = assets.where((a) => a['status_ativo'] == 'Ativo').length;
    int manutencao = assets.where((a) => a['status_ativo'] == 'Manutenção').length;
    
    double valorTotal = assets.fold(0.0, (sum, asset) {
      double valor = (asset['valor'] ?? 0).toDouble();
      int quantidade = (asset['quantidade'] ?? 1);
      return sum + (valor * quantidade);
    });
    
    return {
      'totalAtivos': totalAtivos,
      'ativos': ativos,
      'manutencao': manutencao,
      'valorTotal': valorTotal,
    };
  }
}