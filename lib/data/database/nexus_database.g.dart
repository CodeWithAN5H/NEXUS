// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nexus_database.dart';

// ignore_for_file: type=lint
class $LibraryEntriesTable extends LibraryEntries
    with TableInfo<$LibraryEntriesTable, LibraryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<int> animeId = GeneratedColumn<int>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverImageMeta = const VerificationMeta(
    'coverImage',
  );
  @override
  late final GeneratedColumn<String> coverImage = GeneratedColumn<String>(
    'cover_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerImageMeta = const VerificationMeta(
    'bannerImage',
  );
  @override
  late final GeneratedColumn<String> bannerImage = GeneratedColumn<String>(
    'banner_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('watching'),
  );
  static const VerificationMeta _watchedEpisodesMeta = const VerificationMeta(
    'watchedEpisodes',
  );
  @override
  late final GeneratedColumn<int> watchedEpisodes = GeneratedColumn<int>(
    'watched_episodes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'total_episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _animeScoreMeta = const VerificationMeta(
    'animeScore',
  );
  @override
  late final GeneratedColumn<int> animeScore = GeneratedColumn<int>(
    'anime_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userScoreMeta = const VerificationMeta(
    'userScore',
  );
  @override
  late final GeneratedColumn<int> userScore = GeneratedColumn<int>(
    'user_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonYearMeta = const VerificationMeta(
    'seasonYear',
  );
  @override
  late final GeneratedColumn<int> seasonYear = GeneratedColumn<int>(
    'season_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    animeId,
    title,
    coverImage,
    bannerImage,
    status,
    watchedEpisodes,
    totalEpisodes,
    animeScore,
    userScore,
    format,
    seasonYear,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_image')) {
      context.handle(
        _coverImageMeta,
        coverImage.isAcceptableOrUnknown(data['cover_image']!, _coverImageMeta),
      );
    }
    if (data.containsKey('banner_image')) {
      context.handle(
        _bannerImageMeta,
        bannerImage.isAcceptableOrUnknown(
          data['banner_image']!,
          _bannerImageMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('watched_episodes')) {
      context.handle(
        _watchedEpisodesMeta,
        watchedEpisodes.isAcceptableOrUnknown(
          data['watched_episodes']!,
          _watchedEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['total_episodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('anime_score')) {
      context.handle(
        _animeScoreMeta,
        animeScore.isAcceptableOrUnknown(data['anime_score']!, _animeScoreMeta),
      );
    }
    if (data.containsKey('user_score')) {
      context.handle(
        _userScoreMeta,
        userScore.isAcceptableOrUnknown(data['user_score']!, _userScoreMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('season_year')) {
      context.handle(
        _seasonYearMeta,
        seasonYear.isAcceptableOrUnknown(data['season_year']!, _seasonYearMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {animeId};
  @override
  LibraryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryRow(
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anime_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      coverImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image'],
      ),
      bannerImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_image'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      watchedEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watched_episodes'],
      )!,
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_episodes'],
      ),
      animeScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anime_score'],
      ),
      userScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_score'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      seasonYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_year'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LibraryEntriesTable createAlias(String alias) {
    return $LibraryEntriesTable(attachedDatabase, alias);
  }
}

class LibraryRow extends DataClass implements Insertable<LibraryRow> {
  final int animeId;
  final String title;
  final String? coverImage;
  final String? bannerImage;
  final String status;
  final int watchedEpisodes;
  final int? totalEpisodes;
  final int? animeScore;
  final int? userScore;
  final String? format;
  final int? seasonYear;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LibraryRow({
    required this.animeId,
    required this.title,
    this.coverImage,
    this.bannerImage,
    required this.status,
    required this.watchedEpisodes,
    this.totalEpisodes,
    this.animeScore,
    this.userScore,
    this.format,
    this.seasonYear,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anime_id'] = Variable<int>(animeId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || coverImage != null) {
      map['cover_image'] = Variable<String>(coverImage);
    }
    if (!nullToAbsent || bannerImage != null) {
      map['banner_image'] = Variable<String>(bannerImage);
    }
    map['status'] = Variable<String>(status);
    map['watched_episodes'] = Variable<int>(watchedEpisodes);
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    if (!nullToAbsent || animeScore != null) {
      map['anime_score'] = Variable<int>(animeScore);
    }
    if (!nullToAbsent || userScore != null) {
      map['user_score'] = Variable<int>(userScore);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || seasonYear != null) {
      map['season_year'] = Variable<int>(seasonYear);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LibraryEntriesCompanion toCompanion(bool nullToAbsent) {
    return LibraryEntriesCompanion(
      animeId: Value(animeId),
      title: Value(title),
      coverImage: coverImage == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImage),
      bannerImage: bannerImage == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerImage),
      status: Value(status),
      watchedEpisodes: Value(watchedEpisodes),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      animeScore: animeScore == null && nullToAbsent
          ? const Value.absent()
          : Value(animeScore),
      userScore: userScore == null && nullToAbsent
          ? const Value.absent()
          : Value(userScore),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      seasonYear: seasonYear == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonYear),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LibraryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryRow(
      animeId: serializer.fromJson<int>(json['animeId']),
      title: serializer.fromJson<String>(json['title']),
      coverImage: serializer.fromJson<String?>(json['coverImage']),
      bannerImage: serializer.fromJson<String?>(json['bannerImage']),
      status: serializer.fromJson<String>(json['status']),
      watchedEpisodes: serializer.fromJson<int>(json['watchedEpisodes']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      animeScore: serializer.fromJson<int?>(json['animeScore']),
      userScore: serializer.fromJson<int?>(json['userScore']),
      format: serializer.fromJson<String?>(json['format']),
      seasonYear: serializer.fromJson<int?>(json['seasonYear']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'animeId': serializer.toJson<int>(animeId),
      'title': serializer.toJson<String>(title),
      'coverImage': serializer.toJson<String?>(coverImage),
      'bannerImage': serializer.toJson<String?>(bannerImage),
      'status': serializer.toJson<String>(status),
      'watchedEpisodes': serializer.toJson<int>(watchedEpisodes),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'animeScore': serializer.toJson<int?>(animeScore),
      'userScore': serializer.toJson<int?>(userScore),
      'format': serializer.toJson<String?>(format),
      'seasonYear': serializer.toJson<int?>(seasonYear),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LibraryRow copyWith({
    int? animeId,
    String? title,
    Value<String?> coverImage = const Value.absent(),
    Value<String?> bannerImage = const Value.absent(),
    String? status,
    int? watchedEpisodes,
    Value<int?> totalEpisodes = const Value.absent(),
    Value<int?> animeScore = const Value.absent(),
    Value<int?> userScore = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<int?> seasonYear = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LibraryRow(
    animeId: animeId ?? this.animeId,
    title: title ?? this.title,
    coverImage: coverImage.present ? coverImage.value : this.coverImage,
    bannerImage: bannerImage.present ? bannerImage.value : this.bannerImage,
    status: status ?? this.status,
    watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    animeScore: animeScore.present ? animeScore.value : this.animeScore,
    userScore: userScore.present ? userScore.value : this.userScore,
    format: format.present ? format.value : this.format,
    seasonYear: seasonYear.present ? seasonYear.value : this.seasonYear,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LibraryRow copyWithCompanion(LibraryEntriesCompanion data) {
    return LibraryRow(
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      title: data.title.present ? data.title.value : this.title,
      coverImage: data.coverImage.present
          ? data.coverImage.value
          : this.coverImage,
      bannerImage: data.bannerImage.present
          ? data.bannerImage.value
          : this.bannerImage,
      status: data.status.present ? data.status.value : this.status,
      watchedEpisodes: data.watchedEpisodes.present
          ? data.watchedEpisodes.value
          : this.watchedEpisodes,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      animeScore: data.animeScore.present
          ? data.animeScore.value
          : this.animeScore,
      userScore: data.userScore.present ? data.userScore.value : this.userScore,
      format: data.format.present ? data.format.value : this.format,
      seasonYear: data.seasonYear.present
          ? data.seasonYear.value
          : this.seasonYear,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRow(')
          ..write('animeId: $animeId, ')
          ..write('title: $title, ')
          ..write('coverImage: $coverImage, ')
          ..write('bannerImage: $bannerImage, ')
          ..write('status: $status, ')
          ..write('watchedEpisodes: $watchedEpisodes, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('animeScore: $animeScore, ')
          ..write('userScore: $userScore, ')
          ..write('format: $format, ')
          ..write('seasonYear: $seasonYear, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    animeId,
    title,
    coverImage,
    bannerImage,
    status,
    watchedEpisodes,
    totalEpisodes,
    animeScore,
    userScore,
    format,
    seasonYear,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryRow &&
          other.animeId == this.animeId &&
          other.title == this.title &&
          other.coverImage == this.coverImage &&
          other.bannerImage == this.bannerImage &&
          other.status == this.status &&
          other.watchedEpisodes == this.watchedEpisodes &&
          other.totalEpisodes == this.totalEpisodes &&
          other.animeScore == this.animeScore &&
          other.userScore == this.userScore &&
          other.format == this.format &&
          other.seasonYear == this.seasonYear &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LibraryEntriesCompanion extends UpdateCompanion<LibraryRow> {
  final Value<int> animeId;
  final Value<String> title;
  final Value<String?> coverImage;
  final Value<String?> bannerImage;
  final Value<String> status;
  final Value<int> watchedEpisodes;
  final Value<int?> totalEpisodes;
  final Value<int?> animeScore;
  final Value<int?> userScore;
  final Value<String?> format;
  final Value<int?> seasonYear;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LibraryEntriesCompanion({
    this.animeId = const Value.absent(),
    this.title = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.bannerImage = const Value.absent(),
    this.status = const Value.absent(),
    this.watchedEpisodes = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.animeScore = const Value.absent(),
    this.userScore = const Value.absent(),
    this.format = const Value.absent(),
    this.seasonYear = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LibraryEntriesCompanion.insert({
    this.animeId = const Value.absent(),
    required String title,
    this.coverImage = const Value.absent(),
    this.bannerImage = const Value.absent(),
    this.status = const Value.absent(),
    this.watchedEpisodes = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.animeScore = const Value.absent(),
    this.userScore = const Value.absent(),
    this.format = const Value.absent(),
    this.seasonYear = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<LibraryRow> custom({
    Expression<int>? animeId,
    Expression<String>? title,
    Expression<String>? coverImage,
    Expression<String>? bannerImage,
    Expression<String>? status,
    Expression<int>? watchedEpisodes,
    Expression<int>? totalEpisodes,
    Expression<int>? animeScore,
    Expression<int>? userScore,
    Expression<String>? format,
    Expression<int>? seasonYear,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (animeId != null) 'anime_id': animeId,
      if (title != null) 'title': title,
      if (coverImage != null) 'cover_image': coverImage,
      if (bannerImage != null) 'banner_image': bannerImage,
      if (status != null) 'status': status,
      if (watchedEpisodes != null) 'watched_episodes': watchedEpisodes,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (animeScore != null) 'anime_score': animeScore,
      if (userScore != null) 'user_score': userScore,
      if (format != null) 'format': format,
      if (seasonYear != null) 'season_year': seasonYear,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LibraryEntriesCompanion copyWith({
    Value<int>? animeId,
    Value<String>? title,
    Value<String?>? coverImage,
    Value<String?>? bannerImage,
    Value<String>? status,
    Value<int>? watchedEpisodes,
    Value<int?>? totalEpisodes,
    Value<int?>? animeScore,
    Value<int?>? userScore,
    Value<String?>? format,
    Value<int?>? seasonYear,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LibraryEntriesCompanion(
      animeId: animeId ?? this.animeId,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      bannerImage: bannerImage ?? this.bannerImage,
      status: status ?? this.status,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      animeScore: animeScore ?? this.animeScore,
      userScore: userScore ?? this.userScore,
      format: format ?? this.format,
      seasonYear: seasonYear ?? this.seasonYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (animeId.present) {
      map['anime_id'] = Variable<int>(animeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverImage.present) {
      map['cover_image'] = Variable<String>(coverImage.value);
    }
    if (bannerImage.present) {
      map['banner_image'] = Variable<String>(bannerImage.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (watchedEpisodes.present) {
      map['watched_episodes'] = Variable<int>(watchedEpisodes.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (animeScore.present) {
      map['anime_score'] = Variable<int>(animeScore.value);
    }
    if (userScore.present) {
      map['user_score'] = Variable<int>(userScore.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (seasonYear.present) {
      map['season_year'] = Variable<int>(seasonYear.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntriesCompanion(')
          ..write('animeId: $animeId, ')
          ..write('title: $title, ')
          ..write('coverImage: $coverImage, ')
          ..write('bannerImage: $bannerImage, ')
          ..write('status: $status, ')
          ..write('watchedEpisodes: $watchedEpisodes, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('animeScore: $animeScore, ')
          ..write('userScore: $userScore, ')
          ..write('format: $format, ')
          ..write('seasonYear: $seasonYear, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ProgressEntriesTable extends ProgressEntries
    with TableInfo<$ProgressEntriesTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<int> animeId = GeneratedColumn<int>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeTitleMeta = const VerificationMeta(
    'episodeTitle',
  );
  @override
  late final GeneratedColumn<String> episodeTitle = GeneratedColumn<String>(
    'episode_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImageMeta = const VerificationMeta(
    'coverImage',
  );
  @override
  late final GeneratedColumn<String> coverImage = GeneratedColumn<String>(
    'cover_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerImageMeta = const VerificationMeta(
    'bannerImage',
  );
  @override
  late final GeneratedColumn<String> bannerImage = GeneratedColumn<String>(
    'banner_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'total_episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    animeId,
    episodeNumber,
    title,
    episodeTitle,
    coverImage,
    bannerImage,
    totalEpisodes,
    providerId,
    seriesId,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animeIdMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('episode_title')) {
      context.handle(
        _episodeTitleMeta,
        episodeTitle.isAcceptableOrUnknown(
          data['episode_title']!,
          _episodeTitleMeta,
        ),
      );
    }
    if (data.containsKey('cover_image')) {
      context.handle(
        _coverImageMeta,
        coverImage.isAcceptableOrUnknown(data['cover_image']!, _coverImageMeta),
      );
    }
    if (data.containsKey('banner_image')) {
      context.handle(
        _bannerImageMeta,
        bannerImage.isAcceptableOrUnknown(
          data['banner_image']!,
          _bannerImageMeta,
        ),
      );
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['total_episodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {animeId, episodeNumber};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anime_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      episodeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_title'],
      ),
      coverImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image'],
      ),
      bannerImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_image'],
      ),
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_episodes'],
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProgressEntriesTable createAlias(String alias) {
    return $ProgressEntriesTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final int animeId;
  final int episodeNumber;
  final String title;
  final String? episodeTitle;
  final String? coverImage;
  final String? bannerImage;
  final int? totalEpisodes;
  final String? providerId;
  final String? seriesId;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  const ProgressRow({
    required this.animeId,
    required this.episodeNumber,
    required this.title,
    this.episodeTitle,
    this.coverImage,
    this.bannerImage,
    this.totalEpisodes,
    this.providerId,
    this.seriesId,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anime_id'] = Variable<int>(animeId);
    map['episode_number'] = Variable<int>(episodeNumber);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || episodeTitle != null) {
      map['episode_title'] = Variable<String>(episodeTitle);
    }
    if (!nullToAbsent || coverImage != null) {
      map['cover_image'] = Variable<String>(coverImage);
    }
    if (!nullToAbsent || bannerImage != null) {
      map['banner_image'] = Variable<String>(bannerImage);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProgressEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProgressEntriesCompanion(
      animeId: Value(animeId),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      episodeTitle: episodeTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeTitle),
      coverImage: coverImage == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImage),
      bannerImage: bannerImage == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerImage),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      animeId: serializer.fromJson<int>(json['animeId']),
      episodeNumber: serializer.fromJson<int>(json['episodeNumber']),
      title: serializer.fromJson<String>(json['title']),
      episodeTitle: serializer.fromJson<String?>(json['episodeTitle']),
      coverImage: serializer.fromJson<String?>(json['coverImage']),
      bannerImage: serializer.fromJson<String?>(json['bannerImage']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'animeId': serializer.toJson<int>(animeId),
      'episodeNumber': serializer.toJson<int>(episodeNumber),
      'title': serializer.toJson<String>(title),
      'episodeTitle': serializer.toJson<String?>(episodeTitle),
      'coverImage': serializer.toJson<String?>(coverImage),
      'bannerImage': serializer.toJson<String?>(bannerImage),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'providerId': serializer.toJson<String?>(providerId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProgressRow copyWith({
    int? animeId,
    int? episodeNumber,
    String? title,
    Value<String?> episodeTitle = const Value.absent(),
    Value<String?> coverImage = const Value.absent(),
    Value<String?> bannerImage = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    Value<String?> providerId = const Value.absent(),
    Value<String?> seriesId = const Value.absent(),
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
  }) => ProgressRow(
    animeId: animeId ?? this.animeId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    title: title ?? this.title,
    episodeTitle: episodeTitle.present ? episodeTitle.value : this.episodeTitle,
    coverImage: coverImage.present ? coverImage.value : this.coverImage,
    bannerImage: bannerImage.present ? bannerImage.value : this.bannerImage,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    providerId: providerId.present ? providerId.value : this.providerId,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProgressRow copyWithCompanion(ProgressEntriesCompanion data) {
    return ProgressRow(
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      title: data.title.present ? data.title.value : this.title,
      episodeTitle: data.episodeTitle.present
          ? data.episodeTitle.value
          : this.episodeTitle,
      coverImage: data.coverImage.present
          ? data.coverImage.value
          : this.coverImage,
      bannerImage: data.bannerImage.present
          ? data.bannerImage.value
          : this.bannerImage,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('animeId: $animeId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('coverImage: $coverImage, ')
          ..write('bannerImage: $bannerImage, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    animeId,
    episodeNumber,
    title,
    episodeTitle,
    coverImage,
    bannerImage,
    totalEpisodes,
    providerId,
    seriesId,
    positionMs,
    durationMs,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.animeId == this.animeId &&
          other.episodeNumber == this.episodeNumber &&
          other.title == this.title &&
          other.episodeTitle == this.episodeTitle &&
          other.coverImage == this.coverImage &&
          other.bannerImage == this.bannerImage &&
          other.totalEpisodes == this.totalEpisodes &&
          other.providerId == this.providerId &&
          other.seriesId == this.seriesId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class ProgressEntriesCompanion extends UpdateCompanion<ProgressRow> {
  final Value<int> animeId;
  final Value<int> episodeNumber;
  final Value<String> title;
  final Value<String?> episodeTitle;
  final Value<String?> coverImage;
  final Value<String?> bannerImage;
  final Value<int?> totalEpisodes;
  final Value<String?> providerId;
  final Value<String?> seriesId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProgressEntriesCompanion({
    this.animeId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.bannerImage = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.providerId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressEntriesCompanion.insert({
    required int animeId,
    required int episodeNumber,
    required String title,
    this.episodeTitle = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.bannerImage = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.providerId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : animeId = Value(animeId),
       episodeNumber = Value(episodeNumber),
       title = Value(title);
  static Insertable<ProgressRow> custom({
    Expression<int>? animeId,
    Expression<int>? episodeNumber,
    Expression<String>? title,
    Expression<String>? episodeTitle,
    Expression<String>? coverImage,
    Expression<String>? bannerImage,
    Expression<int>? totalEpisodes,
    Expression<String>? providerId,
    Expression<String>? seriesId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (animeId != null) 'anime_id': animeId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (coverImage != null) 'cover_image': coverImage,
      if (bannerImage != null) 'banner_image': bannerImage,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (providerId != null) 'provider_id': providerId,
      if (seriesId != null) 'series_id': seriesId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressEntriesCompanion copyWith({
    Value<int>? animeId,
    Value<int>? episodeNumber,
    Value<String>? title,
    Value<String?>? episodeTitle,
    Value<String?>? coverImage,
    Value<String?>? bannerImage,
    Value<int?>? totalEpisodes,
    Value<String?>? providerId,
    Value<String?>? seriesId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProgressEntriesCompanion(
      animeId: animeId ?? this.animeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      coverImage: coverImage ?? this.coverImage,
      bannerImage: bannerImage ?? this.bannerImage,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      providerId: providerId ?? this.providerId,
      seriesId: seriesId ?? this.seriesId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (animeId.present) {
      map['anime_id'] = Variable<int>(animeId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (episodeTitle.present) {
      map['episode_title'] = Variable<String>(episodeTitle.value);
    }
    if (coverImage.present) {
      map['cover_image'] = Variable<String>(coverImage.value);
    }
    if (bannerImage.present) {
      map['banner_image'] = Variable<String>(bannerImage.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressEntriesCompanion(')
          ..write('animeId: $animeId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('coverImage: $coverImage, ')
          ..write('bannerImage: $bannerImage, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentSearchesTable extends RecentSearches
    with TableInfo<$RecentSearchesTable, SearchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentSearchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [query, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_searches';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  SearchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchRow(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $RecentSearchesTable createAlias(String alias) {
    return $RecentSearchesTable(attachedDatabase, alias);
  }
}

class SearchRow extends DataClass implements Insertable<SearchRow> {
  final String query;
  final DateTime searchedAt;
  const SearchRow({required this.query, required this.searchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  RecentSearchesCompanion toCompanion(bool nullToAbsent) {
    return RecentSearchesCompanion(
      query: Value(query),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchRow(
      query: serializer.fromJson<String>(json['query']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchRow copyWith({String? query, DateTime? searchedAt}) => SearchRow(
    query: query ?? this.query,
    searchedAt: searchedAt ?? this.searchedAt,
  );
  SearchRow copyWithCompanion(RecentSearchesCompanion data) {
    return SearchRow(
      query: data.query.present ? data.query.value : this.query,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchRow(')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchRow &&
          other.query == this.query &&
          other.searchedAt == this.searchedAt);
}

class RecentSearchesCompanion extends UpdateCompanion<SearchRow> {
  final Value<String> query;
  final Value<DateTime> searchedAt;
  final Value<int> rowid;
  const RecentSearchesCompanion({
    this.query = const Value.absent(),
    this.searchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentSearchesCompanion.insert({
    required String query,
    this.searchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : query = Value(query);
  static Insertable<SearchRow> custom({
    Expression<String>? query,
    Expression<DateTime>? searchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (searchedAt != null) 'searched_at': searchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentSearchesCompanion copyWith({
    Value<String>? query,
    Value<DateTime>? searchedAt,
    Value<int>? rowid,
  }) {
    return RecentSearchesCompanion(
      query: query ?? this.query,
      searchedAt: searchedAt ?? this.searchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearchesCompanion(')
          ..write('query: $query, ')
          ..write('searchedAt: $searchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferenceEntriesTable extends PreferenceEntries
    with TableInfo<$PreferenceEntriesTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferenceEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preference_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PreferenceEntriesTable createAlias(String alias) {
    return $PreferenceEntriesTable(attachedDatabase, alias);
  }
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const PreferenceRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PreferenceEntriesCompanion toCompanion(bool nullToAbsent) {
    return PreferenceEntriesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PreferenceRow copyWith({String? key, String? value, DateTime? updatedAt}) =>
      PreferenceRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PreferenceRow copyWithCompanion(PreferenceEntriesCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class PreferenceEntriesCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PreferenceEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferenceEntriesCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferenceEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PreferenceEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderEntriesTable extends ProviderEntries
    with TableInfo<$ProviderEntriesTable, ProviderEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('builtIn'),
  );
  static const VerificationMeta _manifestVersionMeta = const VerificationMeta(
    'manifestVersion',
  );
  @override
  late final GeneratedColumn<String> manifestVersion = GeneratedColumn<String>(
    'manifest_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contractVersionMeta = const VerificationMeta(
    'contractVersion',
  );
  @override
  late final GeneratedColumn<int> contractVersion = GeneratedColumn<int>(
    'contract_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    providerId,
    origin,
    manifestVersion,
    contractVersion,
    enabled,
    priority,
    configJson,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('manifest_version')) {
      context.handle(
        _manifestVersionMeta,
        manifestVersion.isAcceptableOrUnknown(
          data['manifest_version']!,
          _manifestVersionMeta,
        ),
      );
    }
    if (data.containsKey('contract_version')) {
      context.handle(
        _contractVersionMeta,
        contractVersion.isAcceptableOrUnknown(
          data['contract_version']!,
          _contractVersionMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {providerId};
  @override
  ProviderEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderEntryRow(
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      manifestVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_version'],
      ),
      contractVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contract_version'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $ProviderEntriesTable createAlias(String alias) {
    return $ProviderEntriesTable(attachedDatabase, alias);
  }
}

class ProviderEntryRow extends DataClass
    implements Insertable<ProviderEntryRow> {
  final String providerId;
  final String origin;
  final String? manifestVersion;
  final int? contractVersion;
  final bool enabled;
  final int priority;
  final String configJson;
  final DateTime installedAt;
  const ProviderEntryRow({
    required this.providerId,
    required this.origin,
    this.manifestVersion,
    this.contractVersion,
    required this.enabled,
    required this.priority,
    required this.configJson,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_id'] = Variable<String>(providerId);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || manifestVersion != null) {
      map['manifest_version'] = Variable<String>(manifestVersion);
    }
    if (!nullToAbsent || contractVersion != null) {
      map['contract_version'] = Variable<int>(contractVersion);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    map['config_json'] = Variable<String>(configJson);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  ProviderEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProviderEntriesCompanion(
      providerId: Value(providerId),
      origin: Value(origin),
      manifestVersion: manifestVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestVersion),
      contractVersion: contractVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(contractVersion),
      enabled: Value(enabled),
      priority: Value(priority),
      configJson: Value(configJson),
      installedAt: Value(installedAt),
    );
  }

  factory ProviderEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderEntryRow(
      providerId: serializer.fromJson<String>(json['providerId']),
      origin: serializer.fromJson<String>(json['origin']),
      manifestVersion: serializer.fromJson<String?>(json['manifestVersion']),
      contractVersion: serializer.fromJson<int?>(json['contractVersion']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
      configJson: serializer.fromJson<String>(json['configJson']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'providerId': serializer.toJson<String>(providerId),
      'origin': serializer.toJson<String>(origin),
      'manifestVersion': serializer.toJson<String?>(manifestVersion),
      'contractVersion': serializer.toJson<int?>(contractVersion),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
      'configJson': serializer.toJson<String>(configJson),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  ProviderEntryRow copyWith({
    String? providerId,
    String? origin,
    Value<String?> manifestVersion = const Value.absent(),
    Value<int?> contractVersion = const Value.absent(),
    bool? enabled,
    int? priority,
    String? configJson,
    DateTime? installedAt,
  }) => ProviderEntryRow(
    providerId: providerId ?? this.providerId,
    origin: origin ?? this.origin,
    manifestVersion: manifestVersion.present
        ? manifestVersion.value
        : this.manifestVersion,
    contractVersion: contractVersion.present
        ? contractVersion.value
        : this.contractVersion,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    configJson: configJson ?? this.configJson,
    installedAt: installedAt ?? this.installedAt,
  );
  ProviderEntryRow copyWithCompanion(ProviderEntriesCompanion data) {
    return ProviderEntryRow(
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      origin: data.origin.present ? data.origin.value : this.origin,
      manifestVersion: data.manifestVersion.present
          ? data.manifestVersion.value
          : this.manifestVersion,
      contractVersion: data.contractVersion.present
          ? data.contractVersion.value
          : this.contractVersion,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntryRow(')
          ..write('providerId: $providerId, ')
          ..write('origin: $origin, ')
          ..write('manifestVersion: $manifestVersion, ')
          ..write('contractVersion: $contractVersion, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('configJson: $configJson, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    providerId,
    origin,
    manifestVersion,
    contractVersion,
    enabled,
    priority,
    configJson,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderEntryRow &&
          other.providerId == this.providerId &&
          other.origin == this.origin &&
          other.manifestVersion == this.manifestVersion &&
          other.contractVersion == this.contractVersion &&
          other.enabled == this.enabled &&
          other.priority == this.priority &&
          other.configJson == this.configJson &&
          other.installedAt == this.installedAt);
}

class ProviderEntriesCompanion extends UpdateCompanion<ProviderEntryRow> {
  final Value<String> providerId;
  final Value<String> origin;
  final Value<String?> manifestVersion;
  final Value<int?> contractVersion;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<String> configJson;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const ProviderEntriesCompanion({
    this.providerId = const Value.absent(),
    this.origin = const Value.absent(),
    this.manifestVersion = const Value.absent(),
    this.contractVersion = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.configJson = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderEntriesCompanion.insert({
    required String providerId,
    this.origin = const Value.absent(),
    this.manifestVersion = const Value.absent(),
    this.contractVersion = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.configJson = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : providerId = Value(providerId);
  static Insertable<ProviderEntryRow> custom({
    Expression<String>? providerId,
    Expression<String>? origin,
    Expression<String>? manifestVersion,
    Expression<int>? contractVersion,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<String>? configJson,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerId != null) 'provider_id': providerId,
      if (origin != null) 'origin': origin,
      if (manifestVersion != null) 'manifest_version': manifestVersion,
      if (contractVersion != null) 'contract_version': contractVersion,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (configJson != null) 'config_json': configJson,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderEntriesCompanion copyWith({
    Value<String>? providerId,
    Value<String>? origin,
    Value<String?>? manifestVersion,
    Value<int?>? contractVersion,
    Value<bool>? enabled,
    Value<int>? priority,
    Value<String>? configJson,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return ProviderEntriesCompanion(
      providerId: providerId ?? this.providerId,
      origin: origin ?? this.origin,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      contractVersion: contractVersion ?? this.contractVersion,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      configJson: configJson ?? this.configJson,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (manifestVersion.present) {
      map['manifest_version'] = Variable<String>(manifestVersion.value);
    }
    if (contractVersion.present) {
      map['contract_version'] = Variable<int>(contractVersion.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntriesCompanion(')
          ..write('providerId: $providerId, ')
          ..write('origin: $origin, ')
          ..write('manifestVersion: $manifestVersion, ')
          ..write('contractVersion: $contractVersion, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('configJson: $configJson, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderTitlePrefsTable extends ProviderTitlePrefs
    with TableInfo<$ProviderTitlePrefsTable, ProviderTitlePrefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderTitlePrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<int> animeId = GeneratedColumn<int>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [animeId, providerId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_title_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderTitlePrefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animeIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {animeId, providerId};
  @override
  ProviderTitlePrefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderTitlePrefRow(
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anime_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderTitlePrefsTable createAlias(String alias) {
    return $ProviderTitlePrefsTable(attachedDatabase, alias);
  }
}

class ProviderTitlePrefRow extends DataClass
    implements Insertable<ProviderTitlePrefRow> {
  final int animeId;
  final String providerId;
  final DateTime updatedAt;
  const ProviderTitlePrefRow({
    required this.animeId,
    required this.providerId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anime_id'] = Variable<int>(animeId);
    map['provider_id'] = Variable<String>(providerId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderTitlePrefsCompanion toCompanion(bool nullToAbsent) {
    return ProviderTitlePrefsCompanion(
      animeId: Value(animeId),
      providerId: Value(providerId),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderTitlePrefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderTitlePrefRow(
      animeId: serializer.fromJson<int>(json['animeId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'animeId': serializer.toJson<int>(animeId),
      'providerId': serializer.toJson<String>(providerId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderTitlePrefRow copyWith({
    int? animeId,
    String? providerId,
    DateTime? updatedAt,
  }) => ProviderTitlePrefRow(
    animeId: animeId ?? this.animeId,
    providerId: providerId ?? this.providerId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderTitlePrefRow copyWithCompanion(ProviderTitlePrefsCompanion data) {
    return ProviderTitlePrefRow(
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderTitlePrefRow(')
          ..write('animeId: $animeId, ')
          ..write('providerId: $providerId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(animeId, providerId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderTitlePrefRow &&
          other.animeId == this.animeId &&
          other.providerId == this.providerId &&
          other.updatedAt == this.updatedAt);
}

class ProviderTitlePrefsCompanion
    extends UpdateCompanion<ProviderTitlePrefRow> {
  final Value<int> animeId;
  final Value<String> providerId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderTitlePrefsCompanion({
    this.animeId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderTitlePrefsCompanion.insert({
    required int animeId,
    required String providerId,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : animeId = Value(animeId),
       providerId = Value(providerId);
  static Insertable<ProviderTitlePrefRow> custom({
    Expression<int>? animeId,
    Expression<String>? providerId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (animeId != null) 'anime_id': animeId,
      if (providerId != null) 'provider_id': providerId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderTitlePrefsCompanion copyWith({
    Value<int>? animeId,
    Value<String>? providerId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderTitlePrefsCompanion(
      animeId: animeId ?? this.animeId,
      providerId: providerId ?? this.providerId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (animeId.present) {
      map['anime_id'] = Variable<int>(animeId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderTitlePrefsCompanion(')
          ..write('animeId: $animeId, ')
          ..write('providerId: $providerId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderManifestsTable extends ProviderManifests
    with TableInfo<$ProviderManifestsTable, ProviderManifestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  @override
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    providerId,
    manifestJson,
    sourceUrl,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderManifestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestJsonMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {providerId};
  @override
  ProviderManifestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderManifestRow(
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $ProviderManifestsTable createAlias(String alias) {
    return $ProviderManifestsTable(attachedDatabase, alias);
  }
}

class ProviderManifestRow extends DataClass
    implements Insertable<ProviderManifestRow> {
  final String providerId;
  final String manifestJson;
  final String? sourceUrl;
  final DateTime installedAt;
  const ProviderManifestRow({
    required this.providerId,
    required this.manifestJson,
    this.sourceUrl,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_id'] = Variable<String>(providerId);
    map['manifest_json'] = Variable<String>(manifestJson);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  ProviderManifestsCompanion toCompanion(bool nullToAbsent) {
    return ProviderManifestsCompanion(
      providerId: Value(providerId),
      manifestJson: Value(manifestJson),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      installedAt: Value(installedAt),
    );
  }

  factory ProviderManifestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderManifestRow(
      providerId: serializer.fromJson<String>(json['providerId']),
      manifestJson: serializer.fromJson<String>(json['manifestJson']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'providerId': serializer.toJson<String>(providerId),
      'manifestJson': serializer.toJson<String>(manifestJson),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  ProviderManifestRow copyWith({
    String? providerId,
    String? manifestJson,
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? installedAt,
  }) => ProviderManifestRow(
    providerId: providerId ?? this.providerId,
    manifestJson: manifestJson ?? this.manifestJson,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    installedAt: installedAt ?? this.installedAt,
  );
  ProviderManifestRow copyWithCompanion(ProviderManifestsCompanion data) {
    return ProviderManifestRow(
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderManifestRow(')
          ..write('providerId: $providerId, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(providerId, manifestJson, sourceUrl, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderManifestRow &&
          other.providerId == this.providerId &&
          other.manifestJson == this.manifestJson &&
          other.sourceUrl == this.sourceUrl &&
          other.installedAt == this.installedAt);
}

class ProviderManifestsCompanion extends UpdateCompanion<ProviderManifestRow> {
  final Value<String> providerId;
  final Value<String> manifestJson;
  final Value<String?> sourceUrl;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const ProviderManifestsCompanion({
    this.providerId = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderManifestsCompanion.insert({
    required String providerId,
    required String manifestJson,
    this.sourceUrl = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : providerId = Value(providerId),
       manifestJson = Value(manifestJson);
  static Insertable<ProviderManifestRow> custom({
    Expression<String>? providerId,
    Expression<String>? manifestJson,
    Expression<String>? sourceUrl,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerId != null) 'provider_id': providerId,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderManifestsCompanion copyWith({
    Value<String>? providerId,
    Value<String>? manifestJson,
    Value<String?>? sourceUrl,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return ProviderManifestsCompanion(
      providerId: providerId ?? this.providerId,
      manifestJson: manifestJson ?? this.manifestJson,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderManifestsCompanion(')
          ..write('providerId: $providerId, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NexusDatabase extends GeneratedDatabase {
  _$NexusDatabase(QueryExecutor e) : super(e);
  $NexusDatabaseManager get managers => $NexusDatabaseManager(this);
  late final $LibraryEntriesTable libraryEntries = $LibraryEntriesTable(this);
  late final $ProgressEntriesTable progressEntries = $ProgressEntriesTable(
    this,
  );
  late final $RecentSearchesTable recentSearches = $RecentSearchesTable(this);
  late final $PreferenceEntriesTable preferenceEntries =
      $PreferenceEntriesTable(this);
  late final $ProviderEntriesTable providerEntries = $ProviderEntriesTable(
    this,
  );
  late final $ProviderTitlePrefsTable providerTitlePrefs =
      $ProviderTitlePrefsTable(this);
  late final $ProviderManifestsTable providerManifests =
      $ProviderManifestsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryEntries,
    progressEntries,
    recentSearches,
    preferenceEntries,
    providerEntries,
    providerTitlePrefs,
    providerManifests,
  ];
}

typedef $$LibraryEntriesTableCreateCompanionBuilder =
    LibraryEntriesCompanion Function({
      Value<int> animeId,
      required String title,
      Value<String?> coverImage,
      Value<String?> bannerImage,
      Value<String> status,
      Value<int> watchedEpisodes,
      Value<int?> totalEpisodes,
      Value<int?> animeScore,
      Value<int?> userScore,
      Value<String?> format,
      Value<int?> seasonYear,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$LibraryEntriesTableUpdateCompanionBuilder =
    LibraryEntriesCompanion Function({
      Value<int> animeId,
      Value<String> title,
      Value<String?> coverImage,
      Value<String?> bannerImage,
      Value<String> status,
      Value<int> watchedEpisodes,
      Value<int?> totalEpisodes,
      Value<int?> animeScore,
      Value<int?> userScore,
      Value<String?> format,
      Value<int?> seasonYear,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$LibraryEntriesTableFilterComposer
    extends Composer<_$NexusDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchedEpisodes => $composableBuilder(
    column: $table.watchedEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get animeScore => $composableBuilder(
    column: $table.animeScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userScore => $composableBuilder(
    column: $table.userScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonYear => $composableBuilder(
    column: $table.seasonYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryEntriesTableOrderingComposer
    extends Composer<_$NexusDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchedEpisodes => $composableBuilder(
    column: $table.watchedEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get animeScore => $composableBuilder(
    column: $table.animeScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userScore => $composableBuilder(
    column: $table.userScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonYear => $composableBuilder(
    column: $table.seasonYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryEntriesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get watchedEpisodes => $composableBuilder(
    column: $table.watchedEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get animeScore => $composableBuilder(
    column: $table.animeScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userScore =>
      $composableBuilder(column: $table.userScore, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get seasonYear => $composableBuilder(
    column: $table.seasonYear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LibraryEntriesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $LibraryEntriesTable,
          LibraryRow,
          $$LibraryEntriesTableFilterComposer,
          $$LibraryEntriesTableOrderingComposer,
          $$LibraryEntriesTableAnnotationComposer,
          $$LibraryEntriesTableCreateCompanionBuilder,
          $$LibraryEntriesTableUpdateCompanionBuilder,
          (
            LibraryRow,
            BaseReferences<_$NexusDatabase, $LibraryEntriesTable, LibraryRow>,
          ),
          LibraryRow,
          PrefetchHooks Function()
        > {
  $$LibraryEntriesTableTableManager(
    _$NexusDatabase db,
    $LibraryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> animeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> coverImage = const Value.absent(),
                Value<String?> bannerImage = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> watchedEpisodes = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> animeScore = const Value.absent(),
                Value<int?> userScore = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> seasonYear = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LibraryEntriesCompanion(
                animeId: animeId,
                title: title,
                coverImage: coverImage,
                bannerImage: bannerImage,
                status: status,
                watchedEpisodes: watchedEpisodes,
                totalEpisodes: totalEpisodes,
                animeScore: animeScore,
                userScore: userScore,
                format: format,
                seasonYear: seasonYear,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> animeId = const Value.absent(),
                required String title,
                Value<String?> coverImage = const Value.absent(),
                Value<String?> bannerImage = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> watchedEpisodes = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> animeScore = const Value.absent(),
                Value<int?> userScore = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> seasonYear = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LibraryEntriesCompanion.insert(
                animeId: animeId,
                title: title,
                coverImage: coverImage,
                bannerImage: bannerImage,
                status: status,
                watchedEpisodes: watchedEpisodes,
                totalEpisodes: totalEpisodes,
                animeScore: animeScore,
                userScore: userScore,
                format: format,
                seasonYear: seasonYear,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryEntriesTable, LibraryRow>(table),
                  BaseReferences<
                    _$NexusDatabase,
                    $LibraryEntriesTable,
                    LibraryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $LibraryEntriesTable,
      LibraryRow,
      $$LibraryEntriesTableFilterComposer,
      $$LibraryEntriesTableOrderingComposer,
      $$LibraryEntriesTableAnnotationComposer,
      $$LibraryEntriesTableCreateCompanionBuilder,
      $$LibraryEntriesTableUpdateCompanionBuilder,
      (
        LibraryRow,
        BaseReferences<_$NexusDatabase, $LibraryEntriesTable, LibraryRow>,
      ),
      LibraryRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressEntriesTableCreateCompanionBuilder =
    ProgressEntriesCompanion Function({
      required int animeId,
      required int episodeNumber,
      required String title,
      Value<String?> episodeTitle,
      Value<String?> coverImage,
      Value<String?> bannerImage,
      Value<int?> totalEpisodes,
      Value<String?> providerId,
      Value<String?> seriesId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ProgressEntriesTableUpdateCompanionBuilder =
    ProgressEntriesCompanion Function({
      Value<int> animeId,
      Value<int> episodeNumber,
      Value<String> title,
      Value<String?> episodeTitle,
      Value<String?> coverImage,
      Value<String?> bannerImage,
      Value<int?> totalEpisodes,
      Value<String?> providerId,
      Value<String?> seriesId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProgressEntriesTableFilterComposer
    extends Composer<_$NexusDatabase, $ProgressEntriesTable> {
  $$ProgressEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressEntriesTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProgressEntriesTable> {
  $$ProgressEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressEntriesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProgressEntriesTable> {
  $$ProgressEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverImage => $composableBuilder(
    column: $table.coverImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bannerImage => $composableBuilder(
    column: $table.bannerImage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProgressEntriesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProgressEntriesTable,
          ProgressRow,
          $$ProgressEntriesTableFilterComposer,
          $$ProgressEntriesTableOrderingComposer,
          $$ProgressEntriesTableAnnotationComposer,
          $$ProgressEntriesTableCreateCompanionBuilder,
          $$ProgressEntriesTableUpdateCompanionBuilder,
          (
            ProgressRow,
            BaseReferences<_$NexusDatabase, $ProgressEntriesTable, ProgressRow>,
          ),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $$ProgressEntriesTableTableManager(
    _$NexusDatabase db,
    $ProgressEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> animeId = const Value.absent(),
                Value<int> episodeNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> episodeTitle = const Value.absent(),
                Value<String?> coverImage = const Value.absent(),
                Value<String?> bannerImage = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressEntriesCompanion(
                animeId: animeId,
                episodeNumber: episodeNumber,
                title: title,
                episodeTitle: episodeTitle,
                coverImage: coverImage,
                bannerImage: bannerImage,
                totalEpisodes: totalEpisodes,
                providerId: providerId,
                seriesId: seriesId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int animeId,
                required int episodeNumber,
                required String title,
                Value<String?> episodeTitle = const Value.absent(),
                Value<String?> coverImage = const Value.absent(),
                Value<String?> bannerImage = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressEntriesCompanion.insert(
                animeId: animeId,
                episodeNumber: episodeNumber,
                title: title,
                episodeTitle: episodeTitle,
                coverImage: coverImage,
                bannerImage: bannerImage,
                totalEpisodes: totalEpisodes,
                providerId: providerId,
                seriesId: seriesId,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressEntriesTable, ProgressRow>(table),
                  BaseReferences<
                    _$NexusDatabase,
                    $ProgressEntriesTable,
                    ProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProgressEntriesTable,
      ProgressRow,
      $$ProgressEntriesTableFilterComposer,
      $$ProgressEntriesTableOrderingComposer,
      $$ProgressEntriesTableAnnotationComposer,
      $$ProgressEntriesTableCreateCompanionBuilder,
      $$ProgressEntriesTableUpdateCompanionBuilder,
      (
        ProgressRow,
        BaseReferences<_$NexusDatabase, $ProgressEntriesTable, ProgressRow>,
      ),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $$RecentSearchesTableCreateCompanionBuilder =
    RecentSearchesCompanion Function({
      required String query,
      Value<DateTime> searchedAt,
      Value<int> rowid,
    });
typedef $$RecentSearchesTableUpdateCompanionBuilder =
    RecentSearchesCompanion Function({
      Value<String> query,
      Value<DateTime> searchedAt,
      Value<int> rowid,
    });

class $$RecentSearchesTableFilterComposer
    extends Composer<_$NexusDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentSearchesTableOrderingComposer
    extends Composer<_$NexusDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentSearchesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$RecentSearchesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $RecentSearchesTable,
          SearchRow,
          $$RecentSearchesTableFilterComposer,
          $$RecentSearchesTableOrderingComposer,
          $$RecentSearchesTableAnnotationComposer,
          $$RecentSearchesTableCreateCompanionBuilder,
          $$RecentSearchesTableUpdateCompanionBuilder,
          (
            SearchRow,
            BaseReferences<_$NexusDatabase, $RecentSearchesTable, SearchRow>,
          ),
          SearchRow,
          PrefetchHooks Function()
        > {
  $$RecentSearchesTableTableManager(
    _$NexusDatabase db,
    $RecentSearchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentSearchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentSearchesCompanion(
                query: query,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                Value<DateTime> searchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentSearchesCompanion.insert(
                query: query,
                searchedAt: searchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentSearchesTable, SearchRow>(table),
                  BaseReferences<
                    _$NexusDatabase,
                    $RecentSearchesTable,
                    SearchRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentSearchesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $RecentSearchesTable,
      SearchRow,
      $$RecentSearchesTableFilterComposer,
      $$RecentSearchesTableOrderingComposer,
      $$RecentSearchesTableAnnotationComposer,
      $$RecentSearchesTableCreateCompanionBuilder,
      $$RecentSearchesTableUpdateCompanionBuilder,
      (
        SearchRow,
        BaseReferences<_$NexusDatabase, $RecentSearchesTable, SearchRow>,
      ),
      SearchRow,
      PrefetchHooks Function()
    >;
typedef $$PreferenceEntriesTableCreateCompanionBuilder =
    PreferenceEntriesCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PreferenceEntriesTableUpdateCompanionBuilder =
    PreferenceEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PreferenceEntriesTableFilterComposer
    extends Composer<_$NexusDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferenceEntriesTableOrderingComposer
    extends Composer<_$NexusDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferenceEntriesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $PreferenceEntriesTable> {
  $$PreferenceEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PreferenceEntriesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $PreferenceEntriesTable,
          PreferenceRow,
          $$PreferenceEntriesTableFilterComposer,
          $$PreferenceEntriesTableOrderingComposer,
          $$PreferenceEntriesTableAnnotationComposer,
          $$PreferenceEntriesTableCreateCompanionBuilder,
          $$PreferenceEntriesTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<
              _$NexusDatabase,
              $PreferenceEntriesTable,
              PreferenceRow
            >,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferenceEntriesTableTableManager(
    _$NexusDatabase db,
    $PreferenceEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferenceEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferenceEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferenceEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferenceEntriesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferenceEntriesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferenceEntriesTable, PreferenceRow>(table),
                  BaseReferences<
                    _$NexusDatabase,
                    $PreferenceEntriesTable,
                    PreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferenceEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $PreferenceEntriesTable,
      PreferenceRow,
      $$PreferenceEntriesTableFilterComposer,
      $$PreferenceEntriesTableOrderingComposer,
      $$PreferenceEntriesTableAnnotationComposer,
      $$PreferenceEntriesTableCreateCompanionBuilder,
      $$PreferenceEntriesTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$NexusDatabase, $PreferenceEntriesTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderEntriesTableCreateCompanionBuilder =
    ProviderEntriesCompanion Function({
      required String providerId,
      Value<String> origin,
      Value<String?> manifestVersion,
      Value<int?> contractVersion,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> configJson,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });
typedef $$ProviderEntriesTableUpdateCompanionBuilder =
    ProviderEntriesCompanion Function({
      Value<String> providerId,
      Value<String> origin,
      Value<String?> manifestVersion,
      Value<int?> contractVersion,
      Value<bool> enabled,
      Value<int> priority,
      Value<String> configJson,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$ProviderEntriesTableFilterComposer
    extends Composer<_$NexusDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contractVersion => $composableBuilder(
    column: $table.contractVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderEntriesTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contractVersion => $composableBuilder(
    column: $table.contractVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderEntriesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contractVersion => $composableBuilder(
    column: $table.contractVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$ProviderEntriesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProviderEntriesTable,
          ProviderEntryRow,
          $$ProviderEntriesTableFilterComposer,
          $$ProviderEntriesTableOrderingComposer,
          $$ProviderEntriesTableAnnotationComposer,
          $$ProviderEntriesTableCreateCompanionBuilder,
          $$ProviderEntriesTableUpdateCompanionBuilder,
          (
            ProviderEntryRow,
            BaseReferences<
              _$NexusDatabase,
              $ProviderEntriesTable,
              ProviderEntryRow
            >,
          ),
          ProviderEntryRow,
          PrefetchHooks Function()
        > {
  $$ProviderEntriesTableTableManager(
    _$NexusDatabase db,
    $ProviderEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> providerId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> manifestVersion = const Value.absent(),
                Value<int?> contractVersion = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion(
                providerId: providerId,
                origin: origin,
                manifestVersion: manifestVersion,
                contractVersion: contractVersion,
                enabled: enabled,
                priority: priority,
                configJson: configJson,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerId,
                Value<String> origin = const Value.absent(),
                Value<String?> manifestVersion = const Value.absent(),
                Value<int?> contractVersion = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion.insert(
                providerId: providerId,
                origin: origin,
                manifestVersion: manifestVersion,
                contractVersion: contractVersion,
                enabled: enabled,
                priority: priority,
                configJson: configJson,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderEntriesTable, ProviderEntryRow>(table),
                  BaseReferences<
                    _$NexusDatabase,
                    $ProviderEntriesTable,
                    ProviderEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProviderEntriesTable,
      ProviderEntryRow,
      $$ProviderEntriesTableFilterComposer,
      $$ProviderEntriesTableOrderingComposer,
      $$ProviderEntriesTableAnnotationComposer,
      $$ProviderEntriesTableCreateCompanionBuilder,
      $$ProviderEntriesTableUpdateCompanionBuilder,
      (
        ProviderEntryRow,
        BaseReferences<
          _$NexusDatabase,
          $ProviderEntriesTable,
          ProviderEntryRow
        >,
      ),
      ProviderEntryRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderTitlePrefsTableCreateCompanionBuilder =
    ProviderTitlePrefsCompanion Function({
      required int animeId,
      required String providerId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderTitlePrefsTableUpdateCompanionBuilder =
    ProviderTitlePrefsCompanion Function({
      Value<int> animeId,
      Value<String> providerId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderTitlePrefsTableFilterComposer
    extends Composer<_$NexusDatabase, $ProviderTitlePrefsTable> {
  $$ProviderTitlePrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderTitlePrefsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProviderTitlePrefsTable> {
  $$ProviderTitlePrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get animeId => $composableBuilder(
    column: $table.animeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderTitlePrefsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProviderTitlePrefsTable> {
  $$ProviderTitlePrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get animeId =>
      $composableBuilder(column: $table.animeId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderTitlePrefsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProviderTitlePrefsTable,
          ProviderTitlePrefRow,
          $$ProviderTitlePrefsTableFilterComposer,
          $$ProviderTitlePrefsTableOrderingComposer,
          $$ProviderTitlePrefsTableAnnotationComposer,
          $$ProviderTitlePrefsTableCreateCompanionBuilder,
          $$ProviderTitlePrefsTableUpdateCompanionBuilder,
          (
            ProviderTitlePrefRow,
            BaseReferences<
              _$NexusDatabase,
              $ProviderTitlePrefsTable,
              ProviderTitlePrefRow
            >,
          ),
          ProviderTitlePrefRow,
          PrefetchHooks Function()
        > {
  $$ProviderTitlePrefsTableTableManager(
    _$NexusDatabase db,
    $ProviderTitlePrefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderTitlePrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderTitlePrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderTitlePrefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> animeId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderTitlePrefsCompanion(
                animeId: animeId,
                providerId: providerId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int animeId,
                required String providerId,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderTitlePrefsCompanion.insert(
                animeId: animeId,
                providerId: providerId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderTitlePrefsTable, ProviderTitlePrefRow>(
                    table,
                  ),
                  BaseReferences<
                    _$NexusDatabase,
                    $ProviderTitlePrefsTable,
                    ProviderTitlePrefRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderTitlePrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProviderTitlePrefsTable,
      ProviderTitlePrefRow,
      $$ProviderTitlePrefsTableFilterComposer,
      $$ProviderTitlePrefsTableOrderingComposer,
      $$ProviderTitlePrefsTableAnnotationComposer,
      $$ProviderTitlePrefsTableCreateCompanionBuilder,
      $$ProviderTitlePrefsTableUpdateCompanionBuilder,
      (
        ProviderTitlePrefRow,
        BaseReferences<
          _$NexusDatabase,
          $ProviderTitlePrefsTable,
          ProviderTitlePrefRow
        >,
      ),
      ProviderTitlePrefRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderManifestsTableCreateCompanionBuilder =
    ProviderManifestsCompanion Function({
      required String providerId,
      required String manifestJson,
      Value<String?> sourceUrl,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });
typedef $$ProviderManifestsTableUpdateCompanionBuilder =
    ProviderManifestsCompanion Function({
      Value<String> providerId,
      Value<String> manifestJson,
      Value<String?> sourceUrl,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$ProviderManifestsTableFilterComposer
    extends Composer<_$NexusDatabase, $ProviderManifestsTable> {
  $$ProviderManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderManifestsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProviderManifestsTable> {
  $$ProviderManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderManifestsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProviderManifestsTable> {
  $$ProviderManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$ProviderManifestsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProviderManifestsTable,
          ProviderManifestRow,
          $$ProviderManifestsTableFilterComposer,
          $$ProviderManifestsTableOrderingComposer,
          $$ProviderManifestsTableAnnotationComposer,
          $$ProviderManifestsTableCreateCompanionBuilder,
          $$ProviderManifestsTableUpdateCompanionBuilder,
          (
            ProviderManifestRow,
            BaseReferences<
              _$NexusDatabase,
              $ProviderManifestsTable,
              ProviderManifestRow
            >,
          ),
          ProviderManifestRow,
          PrefetchHooks Function()
        > {
  $$ProviderManifestsTableTableManager(
    _$NexusDatabase db,
    $ProviderManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderManifestsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> providerId = const Value.absent(),
                Value<String> manifestJson = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderManifestsCompanion(
                providerId: providerId,
                manifestJson: manifestJson,
                sourceUrl: sourceUrl,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerId,
                required String manifestJson,
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderManifestsCompanion.insert(
                providerId: providerId,
                manifestJson: manifestJson,
                sourceUrl: sourceUrl,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderManifestsTable, ProviderManifestRow>(
                    table,
                  ),
                  BaseReferences<
                    _$NexusDatabase,
                    $ProviderManifestsTable,
                    ProviderManifestRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProviderManifestsTable,
      ProviderManifestRow,
      $$ProviderManifestsTableFilterComposer,
      $$ProviderManifestsTableOrderingComposer,
      $$ProviderManifestsTableAnnotationComposer,
      $$ProviderManifestsTableCreateCompanionBuilder,
      $$ProviderManifestsTableUpdateCompanionBuilder,
      (
        ProviderManifestRow,
        BaseReferences<
          _$NexusDatabase,
          $ProviderManifestsTable,
          ProviderManifestRow
        >,
      ),
      ProviderManifestRow,
      PrefetchHooks Function()
    >;

class $NexusDatabaseManager {
  final _$NexusDatabase _db;
  $NexusDatabaseManager(this._db);
  $$LibraryEntriesTableTableManager get libraryEntries =>
      $$LibraryEntriesTableTableManager(_db, _db.libraryEntries);
  $$ProgressEntriesTableTableManager get progressEntries =>
      $$ProgressEntriesTableTableManager(_db, _db.progressEntries);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(_db, _db.recentSearches);
  $$PreferenceEntriesTableTableManager get preferenceEntries =>
      $$PreferenceEntriesTableTableManager(_db, _db.preferenceEntries);
  $$ProviderEntriesTableTableManager get providerEntries =>
      $$ProviderEntriesTableTableManager(_db, _db.providerEntries);
  $$ProviderTitlePrefsTableTableManager get providerTitlePrefs =>
      $$ProviderTitlePrefsTableTableManager(_db, _db.providerTitlePrefs);
  $$ProviderManifestsTableTableManager get providerManifests =>
      $$ProviderManifestsTableTableManager(_db, _db.providerManifests);
}
