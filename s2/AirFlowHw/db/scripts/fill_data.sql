-- Clear existing data first if needed
TRUNCATE TABLE enrollment, lesson, flow, "user", unit RESTART IDENTITY CASCADE;

-- 100 units
INSERT INTO unit(name, type, status)
SELECT 'Unit ' || i,
       'faculty',
       'active'
FROM generate_series(1, 100) i;

-- 250k users
WITH bio_strings AS (SELECT ARRAY [
                                'Working on distributed systems and scalable databases.',
                                'Interested in machine learning and neural networks.',
                                'Researching algorithms and performance optimization.',
                                'Building cloud infrastructure and microservices.',
                                'Exploring physics simulations and numerical methods.',
                                'Developing secure network protocols.'
                                ] strings)
INSERT
INTO "user" (full_name,
             email,
             phone,
             unit_id,
             student_number,
             status,
             bio,
             interests,
             profile,
             active_period,
             home_location)
SELECT 'N' || i,
       'user' || i || '@mail.com',
       CASE
           WHEN random() < 0.15 THEN NULL
           ELSE '+123' || i
           END,

       -- 70% belong to 10 units (skew)
       CASE
           WHEN random() < 0.7 THEN floor(random() * 10) + 1
           ELSE floor(random() * 90) + 11
           END,

       'SN' || i,

       (ARRAY ['active','inactive','blocked','pending'])
           [floor(random() * 4) + 1],

       (SELECT (strings)[floor(random() * 6) + 1] || ' ' ||
               (strings)[floor(random() * 6) + 1] || ' ' ||
               (strings)[floor(random() * 6) + 1] || ' ' || i
        FROM bio_strings),

       (ARRAY [
           'math','cs','physics','art','history','music','movies','football','cars','trains','cooking','politics'
           ])[floor(random() * 6) + 1:floor(random() * 6) + 7],

       jsonb_build_object(
               'rating', floor(random() * 100), -- 0-99 instead of 0-4
               'verified', random() < 0.3,
               'premium_tier', (ARRAY ['free','basic','pro','enterprise'])[floor(random() * 4) + 1],
               'preferences', jsonb_build_object(
                       'theme', (ARRAY ['light','dark','auto'])[floor(random() * 3) + 1],
                       'notifications', jsonb_build_object(
                               'email', random() < 0.7,
                               'push', random() < 0.5,
                               'sms', random() < 0.2
                                        ),
                       'language', (ARRAY ['en','es','fr','de','zh','ja','ru'])[floor(random() * 7) + 1]
                              ),
               'tags', (SELECT jsonb_agg(tag)
                        FROM (SELECT unnest(ARRAY ['early_adopter','power_user','mobile','desktop','api_user','beta_tester','referral']) AS tag
                              ORDER BY random()
                              LIMIT floor(random() * 4) -- 0-3 tags per user
                             ) sub)
       ),

       tstzrange(
               now() - (random() * 365) * interval '1 day',
               now()
       ),

       point(random() * 100, random() * 100)
FROM generate_series(1, 250000) i;


-- 250k flows
INSERT INTO flow (code,
                  title,
                  unit_id,
                  credits,
                  cohort_year,
                  modality,
                  start_date,
                  end_date,
                  status,
                  tags,
                  metadata,
                  active_range,
                  description)
SELECT 'FL' || i,
       'Flow ' || i,

       CASE
           WHEN random() < 0.7 THEN floor(random() * 10) + 1
           ELSE floor(random() * 90) + 11
           END,

       round((random() * 5 + 1)::numeric, 1),
       2015 + floor(random() * 10),

       (ARRAY ['online','offline','hybrid'])
           [floor(random() * 3) + 1],

       current_date - floor(random() * 1000)::int,
       current_date + floor(random() * 1000)::int,

       (ARRAY ['active','archived','draft'])
           [floor(random() * 3) + 1],

       ARRAY ['tag1','tag2','tag3'],

       jsonb_build_object(
               'difficulty', floor(random() * 10), -- 0-9
               'has_exam', random() < 0.8,
               'prerequisites', (SELECT jsonb_agg('FL' || fid)
                                 FROM (SELECT floor(random() * 250000) + 1 AS fid
                                       FROM generate_series(1, floor(random() * 3)::int) -- 0-2 prereqs
                                      ) sub),
               'skills', (SELECT jsonb_agg(skill)
                          FROM (SELECT unnest(ARRAY ['sql','python','docker','k8s','aws','gcp','ml','stats','writing','design']) AS skill
                                ORDER BY random()
                                LIMIT floor(random() * 5) + 1 -- 1-5 skills
                               ) sub),
               'instructor_notes', CASE
                                       WHEN random() < 0.2 THEN jsonb_build_object('internal', true, 'reviewed_by',
                                                                                   'admin_' || floor(random() * 50))
                                       ELSE NULL
                   END
       ),

       daterange(
                       current_date - floor(random() * 100)::int,
                       current_date + floor(random() * 100)::int
       ),

       'Detailed description of flow ' || i

FROM generate_series(1, 250000) i;

-- 250k lessons
INSERT INTO lesson (flow_id,
                    type,
                    topic,
                    start_at,
                    end_at,
                    teacher_id,
                    attendance_required,
                    status,
                    materials,
                    topics,
                    time_slot)
SELECT CASE
           WHEN random() < 0.7 THEN floor(random() * 10000) + 1
           ELSE floor(random() * 240000) + 10001
           END,

       (ARRAY ['lecture','seminar','lab'])
           [floor(random() * 3) + 1],

       'Topic ' || i,

       now() - (random() * 365) * interval '1 day',
       now(),

       floor(random() * 250000) + 1,

       random() < 0.8,

       (ARRAY ['scheduled','done','cancelled'])
           [floor(random() * 3) + 1],

       CASE
           WHEN random() < 0.1 THEN
               jsonb_build_object(
                       'slides', random() < 0.9,
                       'recorded', random() < 0.6,
                       'resources', (SELECT jsonb_agg(res)
                                     FROM (SELECT unnest(ARRAY [
                                         jsonb_build_object('type', 'pdf', 'size_mb',
                                                            round((random() * 20)::numeric, 1)),
                                         jsonb_build_object('type', 'video', 'duration_min', floor(random() * 120)),
                                         jsonb_build_object('type', 'code_repo', 'stars', floor(random() * 1000)),
                                         jsonb_build_object('type', 'dataset', 'rows', floor(random() * 100000))
                                         ]) AS res
                                           ORDER BY random()
                                           LIMIT floor(random() * 4) + 1) sub),
                       'access_level', (ARRAY ['public','enrolled','premium','staff'])[floor(random() * 4) + 1]
               )
           ELSE jsonb_build_object(
                   'slides', random() < 0.9,
                   'recorded', random() < 0.6,
                   'access_level', (ARRAY ['public','enrolled','premium','staff'])[floor(random() * 4) + 1]
                )
           END,

       ARRAY ['topic1','topic2','topic3'],

       tstzrange(
               now() - interval '2 hours',
               now()
       )
FROM generate_series(1, 250000) i;


-- 250k enrollments
INSERT INTO enrollment (user_id,
                        flow_id,
                        enrolled_at,
                        dropped_at,
                        attendance_pct,
                        current_score,
                        status,
                        progress,
                        attendance_range)
SELECT i,
       floor(random() * 250000) + 1,
       now() - (random() * 200) * interval '1 day',

       CASE
           WHEN random() < 0.1
               THEN now()
           ELSE NULL
           END,

       round((random() * 100)::numeric, 2),
       round((random() * 100)::numeric, 2),

       (ARRAY ['active','completed','dropped'])
           [floor(random() * 3) + 1],

       -- Replace enrollment progress with:
       jsonb_build_object(
               'completed', floor(random() * 10),
               'total', 10,
               'last_activity', now() - (random() * 30) * interval '1 day',
               'quiz_scores', (SELECT jsonb_agg(score)
                               FROM (SELECT round((random() * 100)::numeric, 1) AS score
                                     FROM generate_series(1, floor(random() * 5)::int + 1) -- 1-5 quizzes
                                    ) sub),
               'badges_earned', (SELECT jsonb_agg(badge)
                                 FROM (SELECT unnest(ARRAY ['first_lesson','perfect_score','early_bird','helper','streak_7', 'badge' || i]) AS badge
                                       ORDER BY random()
                                       LIMIT floor(random() * 3) -- 0-2 badges
                                      ) sub)
       ),

       numrange((random() * 50)::numeric, (random() * 50 + 50)::numeric)
FROM generate_series(1, 250000) i;
