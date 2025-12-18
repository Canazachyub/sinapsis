import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:sinapsis/features/pomodoro/presentation/bloc/pomodoro_bloc.dart';
import 'package:sinapsis/features/pomodoro/presentation/widgets/floating_pomodoro_widget.dart';
import 'package:sinapsis/features/pomodoro/domain/entities/pomodoro_session.dart';

class MockPomodoroBloc extends MockBloc<PomodoroEvent, PomodoroBlockState>
    implements PomodoroBloc {}

void main() {
  late MockPomodoroBloc mockBloc;

  setUp(() {
    mockBloc = MockPomodoroBloc();
  });

  Widget createWidgetUnderTest({Size size = const Size(800, 600)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: Stack(
            children: [
              BlocProvider<PomodoroBloc>.value(
                value: mockBloc,
                child: const FloatingPomodoroWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('FloatingPomodoroWidget', () {
    testWidgets('no debe mostrarse cuando estado es PomodoroInitial',
        (tester) async {
      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([const PomodoroInitial()]),
        initialState: const PomodoroInitial(),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(FloatingPomodoroWidget), findsOneWidget);
      // Debe retornar SizedBox.shrink cuando es Initial, sin Material visible
      expect(find.byType(Material), findsOneWidget); // Solo el Scaffold Material
    });

    testWidgets('debe mostrarse cuando hay un Pomodoro corriendo',
        (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Debe mostrar el tiempo
      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('debe mostrar tiempo formateado correctamente', (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 754, // 12:34
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('12:34'), findsOneWidget);
    });

    testWidgets('debe mostrar icono de trabajo cuando está trabajando',
        (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.work_outline), findsOneWidget);
    });

    testWidgets('debe mostrar icono de café durante descanso', (tester) async {
      final breakState = PomodoroRunning(
        currentState: PomodoroState.breakTime,
        remainingSeconds: 300,
        totalSeconds: 300,
        completedPomodoros: 1,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([breakState]),
        initialState: breakState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    });

    testWidgets('debe mostrar icono de pausa cuando está pausado',
        (tester) async {
      final pausedState = PomodoroPaused(
        previousState: PomodoroState.working,
        remainingSeconds: 1200,
        totalSeconds: 1500,
        completedPomodoros: 1,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([pausedState]),
        initialState: pausedState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('debe mostrar tiempo correcto cuando pausado', (tester) async {
      final pausedState = PomodoroPaused(
        previousState: PomodoroState.working,
        remainingSeconds: 1200, // 20:00
        totalSeconds: 1500,
        completedPomodoros: 1,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([pausedState]),
        initialState: pausedState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('widget usa Positioned para posicionamiento absoluto',
        (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Buscar Positioned que contiene el FloatingPomodoroWidget
      final positionedWidgets = tester.widgetList<Positioned>(find.byType(Positioned));
      // Debe haber al menos uno con left/top definidos (el del widget flotante)
      final hasPositionedWidget = positionedWidgets.any((p) => p.left != null && p.top != null);
      expect(hasPositionedWidget, isTrue);
    });

    testWidgets('widget responde a gestos de arrastre', (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Encontrar el Positioned principal del widget flotante (el que tiene top > 100)
      final positionedFinder = find.byWidgetPredicate(
        (widget) => widget is Positioned &&
            widget.left != null &&
            widget.top != null &&
            widget.top! > 100, // El widget flotante estará más abajo
      );
      expect(positionedFinder, findsOneWidget);

      // Obtener posicion inicial
      final initialWidget = tester.widget<Positioned>(positionedFinder);
      final initialLeft = initialWidget.left!;

      // Realizar drag usando el Material que contiene el widget
      final materialFinder = find.descendant(
        of: positionedFinder,
        matching: find.byType(Material),
      );

      await tester.drag(materialFinder.first, const Offset(-100, 0));
      await tester.pump();

      // Verificar que la posicion cambio
      final updatedWidget = tester.widget<Positioned>(positionedFinder);
      expect(updatedWidget.left, isNot(equals(initialLeft)));
    });

    testWidgets('widget tiene AnimatedContainer para transiciones suaves',
        (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('widget tiene InkWell para expansión', (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('widget muestra indicador de arrastre (barra)', (tester) async {
      final runningState = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 1500,
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      whenListen(
        mockBloc,
        Stream<PomodoroBlockState>.fromIterable([runningState]),
        initialState: runningState,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Buscar Container con ancho de 30 (la barra de arrastre)
      final dragBarFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.constraints?.maxWidth == 30 &&
            widget.constraints?.maxHeight == 4,
      );
      expect(dragBarFinder, findsOneWidget);
    });
  });

  group('PomodoroBlockState formateo de tiempo', () {
    test('PomodoroRunning formatea tiempo correctamente', () {
      final state = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 754, // 12:34
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      expect(state.formattedTime, '12:34');
    });

    test('PomodoroRunning formatea tiempo con segundos menores a 10', () {
      final state = PomodoroRunning(
        currentState: PomodoroState.working,
        remainingSeconds: 605, // 10:05
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      expect(state.formattedTime, '10:05');
    });

    test('PomodoroPaused formatea tiempo correctamente', () {
      final state = PomodoroPaused(
        previousState: PomodoroState.working,
        remainingSeconds: 1200, // 20:00
        totalSeconds: 1500,
        completedPomodoros: 0,
        startedAt: DateTime.now(),
      );

      expect(state.formattedTime, '20:00');
    });
  });
}
