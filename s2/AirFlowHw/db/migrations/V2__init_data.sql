ALTER TABLE flow
    ADD COLUMN tags         TEXT[],
    ADD COLUMN metadata     JSONB,
    ADD COLUMN active_range daterange,
    ADD COLUMN description  TEXT;

ALTER TABLE "user"
    ADD COLUMN bio           TEXT,
    ADD COLUMN interests     TEXT[],
    ADD COLUMN profile       JSONB,
    ADD COLUMN active_period tstzrange,
    ADD COLUMN home_location point;

ALTER TABLE lesson
    ADD COLUMN materials JSONB,
    ADD COLUMN topics    TEXT[],
    ADD COLUMN time_slot tstzrange;

ALTER TABLE enrollment
    ADD COLUMN progress         JSONB,
    ADD COLUMN attendance_range numrange;
