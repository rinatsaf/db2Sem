-- Decode raw heap tuple metadata for row id=1
-- pageinspect is required
WITH target AS (
    SELECT ctid
    FROM hw4.mvcc_lab
    WHERE id = 1
),
page_no AS (
    SELECT split_part(replace(replace(ctid::text, '(', ''), ')', ''), ',', 1)::int AS blk
    FROM target
),
line_no AS (
    SELECT split_part(replace(replace(ctid::text, '(', ''), ')', ''), ',', 2)::int AS lp
    FROM target
),
raw AS (
    SELECT h.*
    FROM page_no p
    JOIN line_no l ON TRUE
    JOIN LATERAL heap_page_items(get_raw_page('hw4.mvcc_lab', p.blk)) h ON h.lp = l.lp
)
SELECT
    raw.lp,
    raw.t_xmin,
    raw.t_xmax,
    raw.t_ctid,
    raw.t_infomask,
    raw.t_infomask2,
    flags.raw_flags,
    flags.combined_flags
FROM raw
CROSS JOIN LATERAL heap_tuple_infomask_flags(raw.t_infomask, raw.t_infomask2) AS flags;
