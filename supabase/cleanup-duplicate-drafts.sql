-- GridFeed: Clean up duplicate drafts
-- Run in Supabase SQL Editor

-- Delete duplicates, keep oldest of each title
DELETE FROM content_drafts
WHERE id NOT IN (
  SELECT DISTINCT ON (title) id
  FROM content_drafts
  ORDER BY title, created_at ASC
)
AND title IN (
  SELECT title FROM content_drafts
  GROUP BY title HAVING count(*) > 1
);

-- Mark consumed topics as drafted
UPDATE content_topics SET status = 'drafted'
WHERE status IN ('pending', 'processing')
AND topic IN (SELECT title FROM content_drafts);

-- Verify no duplicates remain
SELECT title, count(*) as cnt FROM content_drafts
GROUP BY title HAVING count(*) > 1;
