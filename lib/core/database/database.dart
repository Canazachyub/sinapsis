import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Tabla de usuarios
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de cursos
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de notas
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get courseId => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()(); // flashcard, cloze, image_occlusion, code, multimedia
  TextColumn get frontContent => text()();
  TextColumn get backContent => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON array de strings
  IntColumn get difficulty => integer().withDefault(const Constant(0))(); // 0: nuevo, 1: fácil, 2: medio, 3: difícil
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get nextReview => dateTime().nullable()();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  IntColumn get interval => integer().withDefault(const Constant(0))(); // Intervalo actual en días
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))(); // Factor de facilidad (SM-2)
  IntColumn get consecutiveCorrect => integer().withDefault(const Constant(0))(); // Respuestas correctas consecutivas
  TextColumn get srsState => text().withDefault(const Constant('new'))(); // new, learning, review, relearning
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de sesiones de estudio
class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get courseId => text()();
  IntColumn get cardsReviewed => integer()();
  IntColumn get cardsCorrect => integer()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get sessionType => text().withDefault(const Constant('review'))(); // review, pomodoro, practice
  TextColumn get noteId => text().nullable()(); // Nota específica si aplica

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de sesiones de Pomodoro
class PomodoroSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get courseId => text().nullable()();
  TextColumn get noteId => text().nullable()();
  IntColumn get workDuration => integer().withDefault(const Constant(1500))(); // 25 minutos en segundos
  IntColumn get breakDuration => integer().withDefault(const Constant(300))(); // 5 minutos en segundos
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get wasInterrupted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Courses, Notes, StudySessions, PomodoroSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migración de v1 a v2: agregar nuevas columnas y tabla
          await customStatement(
            'ALTER TABLE study_sessions ADD COLUMN session_type TEXT NOT NULL DEFAULT \'review\''
          );
          await customStatement(
            'ALTER TABLE study_sessions ADD COLUMN note_id TEXT'
          );

          // Crear tabla de sesiones Pomodoro
          await customStatement(
            '''CREATE TABLE IF NOT EXISTS pomodoro_sessions (
              id TEXT PRIMARY KEY NOT NULL,
              user_id TEXT NOT NULL,
              course_id TEXT,
              note_id TEXT,
              work_duration INTEGER NOT NULL DEFAULT 1500,
              break_duration INTEGER NOT NULL DEFAULT 300,
              is_completed INTEGER NOT NULL DEFAULT 0,
              was_interrupted INTEGER NOT NULL DEFAULT 0,
              started_at INTEGER NOT NULL,
              completed_at INTEGER
            )'''
          );
        }

        if (from < 3) {
          // Migración de v2 a v3: agregar campos SRS a la tabla Notes
          await customStatement(
            'ALTER TABLE notes ADD COLUMN interval INTEGER NOT NULL DEFAULT 0'
          );
          await customStatement(
            'ALTER TABLE notes ADD COLUMN ease_factor REAL NOT NULL DEFAULT 2.5'
          );
          await customStatement(
            'ALTER TABLE notes ADD COLUMN consecutive_correct INTEGER NOT NULL DEFAULT 0'
          );
          await customStatement(
            'ALTER TABLE notes ADD COLUMN srs_state TEXT NOT NULL DEFAULT \'new\''
          );
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sinapsis.db'));
    return NativeDatabase(file);
  });
}
