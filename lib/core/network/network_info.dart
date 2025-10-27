/// Interfaz para verificar conectividad de red
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Implementación de NetworkInfo
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // Por ahora, siempre devuelve true
    // En una implementación real, usarías connectivity_plus o similar
    return Future.value(true);
  }
}
