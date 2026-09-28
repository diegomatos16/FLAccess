CREATE TABLE assets (
    id INTEGER PRIMARY KEY,
    sha1 TEXT UNIQUE,
    text TEXT NOT NULL,
    normalized TEXT NOT NULL,
    role TEXT NOT NULL,
    confidence REAL NOT NULL
);

CREATE TABLE occurrences (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL REFERENCES assets(id),
    source_file TEXT NOT NULL,
    archive_member TEXT,
    byte_offset INTEGER,
    encoding TEXT NOT NULL,
    locale TEXT,
    extraction TEXT NOT NULL,
    UNIQUE (asset_id, source_file, archive_member, byte_offset, encoding, extraction)
);

CREATE TABLE files (
    path TEXT PRIMARY KEY,
    size INTEGER NOT NULL,
    extension TEXT,
    status TEXT NOT NULL,
    detail TEXT
);

CREATE TABLE archive_members (
    archive TEXT NOT NULL,
    member TEXT NOT NULL,
    size INTEGER NOT NULL,
    compressed_size INTEGER NOT NULL,
    status TEXT NOT NULL,
    PRIMARY KEY (archive, member)
);

CREATE INDEX occurrence_asset ON occurrences(asset_id);
CREATE INDEX occurrence_source ON occurrences(source_file);
CREATE INDEX occurrence_member ON occurrences(archive_member);
CREATE INDEX occurrence_locale ON occurrences(locale);
CREATE INDEX asset_role ON assets(role);
CREATE INDEX asset_normalized ON assets(normalized);
