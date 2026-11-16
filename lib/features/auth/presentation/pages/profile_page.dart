import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/data_backup_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../injection_container.dart';
import '../../../notes/presentation/widgets/importar_anotador_button.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../theme/presentation/bloc/theme_bloc.dart';
import '../../../theme/presentation/bloc/theme_event.dart';
import '../../../theme/presentation/bloc/theme_state.dart';
import '../bloc/auth_bloc.dart';

/// Página de perfil: identidad, sincronización con Supabase, datos locales
/// (copias de seguridad) y apariencia.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  /// Inicial para el avatar: del nombre si lo hay ("yubert" → "Y"); si no,
  /// del email.
  static String inicial(String? nombre, String email) {
    final base = (nombre?.trim().isNotEmpty ?? false) ? nombre!.trim() : email;
    if (base.isEmpty) return '?';
    return String.fromCharCode(base.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = state.user;
          final titulo = Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      child: Text(
                        inicial(user.name, user.email),
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      (user.name?.trim().isNotEmpty ?? false)
                          ? user.name!
                          : user.email,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text('Sincronización', style: titulo),
                  const SizedBox(height: 12),
                  const _TarjetaSincronizacion(),
                  const SizedBox(height: 24),

                  Text('Datos', style: titulo),
                  const SizedBox(height: 12),
                  _TarjetaDatos(userId: user.id),
                  const SizedBox(height: 24),

                  Text('Apariencia', style: titulo),
                  const SizedBox(height: 12),
                  Card(
                    child: BlocBuilder<ThemeBloc, ThemeState>(
                      builder: (context, themeState) {
                        final (etiqueta, icono) = switch (themeState.themeMode) {
                          ThemeMode.light => ('Claro', Icons.light_mode),
                          ThemeMode.dark => ('Oscuro', Icons.dark_mode),
                          ThemeMode.system => ('Sistema', Icons.brightness_auto),
                        };
                        return ListTile(
                          leading: Icon(icono),
                          title: const Text('Tema de la interfaz'),
                          subtitle: Text(etiqueta),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _mostrarDialogoTema(context, themeState.themeMode),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: () {
                      context.read<AuthBloc>().add(const LogoutRequested());
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoTema(
    BuildContext context,
    ThemeMode actual,
  ) async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seleccionar tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpcionTema(
              mode: ThemeMode.system,
              label: 'Automático (sistema)',
              subtitle: 'Sigue la configuración del dispositivo',
              icon: Icons.brightness_auto,
              isSelected: actual == ThemeMode.system,
            ),
            const Divider(),
            _OpcionTema(
              mode: ThemeMode.light,
              label: 'Claro',
              subtitle: 'Siempre usar tema claro',
              icon: Icons.light_mode,
              isSelected: actual == ThemeMode.light,
            ),
            const Divider(),
            _OpcionTema(
              mode: ThemeMode.dark,
              label: 'Oscuro',
              subtitle: 'Siempre usar tema oscuro',
              icon: Icons.dark_mode,
              isSelected: actual == ThemeMode.dark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (result != null && result != actual && context.mounted) {
      context.read<ThemeBloc>().add(ThemeChanged(result));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tema actualizado'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

String _fechaHora(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final hoy = DateTime.now();
  final mismoDia =
      d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
  final hora = '${dos(d.hour)}:${dos(d.minute)}';
  return mismoDia ? 'hoy a las $hora' : '${d.day}/${d.month}/${d.year} $hora';
}

// ---------------------------------------------------------------------------
// Sincronización
// ---------------------------------------------------------------------------

class _TarjetaSincronizacion extends StatelessWidget {
  const _TarjetaSincronizacion();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SyncBloc, SyncState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state is SyncSuccess) {
          recargarTrasImportar(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Sincronizado')));
        } else if (state is SyncFailure) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('No se pudo sincronizar: ${state.message}'),
              backgroundColor: Colors.red,
            ));
        } else if (state is SyncOffline) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Sin conexión')));
        }
      },
      builder: (context, state) {
        final info = SyncBloc.info();
        final esquema = Theme.of(context).colorScheme;
        final enCurso = state is SyncInProgress;

        final (IconData icono, Color color, String estado, String detalle) =
            !info.configurado
                ? (
                    Icons.cloud_off,
                    Colors.grey,
                    'Supabase no configurado',
                    'Tus datos se guardan solo en este equipo.',
                  )
                : !info.conSesion
                    ? (
                        Icons.cloud_off,
                        Colors.orange,
                        'Sin sesión en Supabase',
                        'Inicia sesión con una cuenta de Supabase para '
                            'sincronizar entre dispositivos.',
                      )
                    : state is SyncFailure
                        ? (
                            Icons.cloud_off,
                            esquema.error,
                            'Conectado, con errores',
                            info.emailSesion!,
                          )
                        : (
                            Icons.cloud_done,
                            Colors.green,
                            'Conectado',
                            info.emailSesion!,
                          );

        final ultimo = info.ultimoSync;
        final error = state is SyncFailure ? state.message : info.ultimoError;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(estado,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(detalle,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ultimo == null
                      ? 'Última sincronización: nunca'
                      : 'Última sincronización: ${_fechaHora(ultimo)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (state is SyncOffline)
                  Text('Sin conexión a internet',
                      style: TextStyle(color: esquema.error)),
                if (error != null && info.configurado) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Último error'
                    '${info.ultimoErrorEn != null ? ' (${_fechaHora(info.ultimoErrorEn!)})' : ''}'
                    ': $error',
                    style: TextStyle(color: esquema.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: enCurso || !info.configurado || !info.conSesion
                        ? null
                        : () =>
                            context.read<SyncBloc>().add(const SyncStarted()),
                    icon: enCurso
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(enCurso ? 'Sincronizando…' : 'Sincronizar ahora'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Datos locales y copias de seguridad
// ---------------------------------------------------------------------------

class _TarjetaDatos extends StatefulWidget {
  final String userId;

  const _TarjetaDatos({required this.userId});

  @override
  State<_TarjetaDatos> createState() => _TarjetaDatosState();
}

class _TarjetaDatosState extends State<_TarjetaDatos> {
  String? _rutaDatos;
  String? _rutaImagenes;
  bool _ocupado = false;

  static const _grupoJson = XTypeGroup(
    label: 'Copia de Sinapsis (JSON)',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  Future<void> _cargarRutas() async {
    try {
      final soporte = await getApplicationSupportDirectory();
      final docs = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      setState(() {
        _rutaDatos = p.join(soporte.path, 'shared_preferences.json');
        _rutaImagenes = p.join(docs.path, 'sinapsis_images');
      });
    } catch (e) {
      AppLogger.w('Perfil: no se pudo obtener la ruta de datos: $e');
    }
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: error ? Colors.red : null,
        duration: const Duration(seconds: 5),
      ));
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _exportar() async {
    final servicio = sl<DataBackupService>();
    final datos = servicio.exportData(widget.userId);
    final ok = await _confirmar(
      'Exportar copia de seguridad',
      'Se guardarán ${datos['coursesCount']} cursos y ${datos['notesCount']} '
          'notas en un fichero JSON que elijas. Las imágenes no se incluyen: '
          'copia también la carpeta de imágenes si quieres llevarlas a otro '
          'equipo.',
      'Elegir destino',
    );
    if (!ok || !mounted) return;

    final hoy = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final sugerido =
        'sinapsis_copia_${hoy.year}${dos(hoy.month)}${dos(hoy.day)}.json';

    setState(() => _ocupado = true);
    try {
      final destino = await FileSelectorPlatform.instance.getSaveLocation(
        acceptedTypeGroups: const [_grupoJson],
        options: SaveDialogOptions(
          suggestedName: sugerido,
          confirmButtonText: 'Guardar',
        ),
      );
      if (destino == null) return;
      var ruta = destino.path;
      if (p.extension(ruta).isEmpty) ruta = '$ruta.json';
      await servicio.exportToFile(widget.userId, ruta);
      _aviso('Copia guardada en $ruta');
    } catch (e, st) {
      AppLogger.e('Perfil: error exportando copia', e, st);
      _aviso('No se pudo exportar la copia: $e', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _importar() async {
    setState(() => _ocupado = true);
    try {
      final fichero = await FileSelectorPlatform.instance.openFile(
        acceptedTypeGroups: const [_grupoJson],
        confirmButtonText: 'Abrir',
      );
      if (fichero == null || !mounted) return;

      final ok = await _confirmar(
        'Importar copia',
        'Se fusionará «${p.basename(fichero.path)}» con tus datos actuales. '
            'No se borra nada: las notas duplicadas se omiten y las que ya '
            'existan solo se actualizan si la copia es más reciente.',
        'Importar',
      );
      if (!ok || !mounted) return;

      final resultado = await sl<DataBackupService>()
          .importFromFile(fichero.path, merge: true);
      if (!mounted) return;
      if (resultado.success) {
        recargarTrasImportar(context);
        _aviso(resultado.message);
      } else {
        _aviso(resultado.message, error: true);
      }
    } catch (e, st) {
      AppLogger.e('Perfil: error importando copia', e, st);
      _aviso('No se pudo importar la copia: $e', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pequeno = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_outlined),
                const SizedBox(width: 12),
                Text('Datos locales',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Notas y cursos:', style: pequeno),
            SelectableText(_rutaDatos ?? '…',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 6),
            Text('Imágenes:', style: pequeno),
            SelectableText(_rutaImagenes ?? '…',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _importar,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar copia'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _ocupado ? null : _exportar,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Exportar copia de seguridad'),
                ),
              ],
            ),
            if (Platform.isLinux)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No edites a mano el fichero de datos con la app abierta: '
                  'la app lo reescribe entero al guardar.',
                  style: pequeno,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OpcionTema extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _OpcionTema({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primario : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primario : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected ? Icon(Icons.check, color: primario) : null,
      onTap: () => Navigator.pop(context, mode),
    );
  }
}
