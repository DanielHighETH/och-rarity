/*
  # Fix duplicate traits and data inconsistencies

  1. Changes
    - Clean up duplicate traits by merging them
    - Fix Level category naming
    - Update trait counts and rarities
    - Resync all hero traits
    - Recalculate rarity scores and ranks

  2. Process
    - Create temporary tables for processing
    - Merge duplicate traits while preserving associations
    - Update all statistics
*/

-- Create temporary tables for processing
CREATE TEMP TABLE trait_mapping (
  old_id uuid,
  new_id uuid,
  category text,
  value text
);

-- First, identify the canonical trait IDs (keeping the first one for each category/value pair)
INSERT INTO trait_mapping (old_id, new_id, category, value)
SELECT 
  t.id as old_id,
  FIRST_VALUE(t.id) OVER (
    PARTITION BY 
      CASE WHEN t.category = 'Season 1 Level' THEN 'Level' ELSE t.category END,
      t.value 
    ORDER BY t.id
  ) as new_id,
  CASE WHEN t.category = 'Season 1 Level' THEN 'Level' ELSE t.category END as category,
  t.value
FROM traits t;

-- Update hero_traits to point to the canonical trait IDs
UPDATE hero_traits ht
SET trait_id = tm.new_id
FROM trait_mapping tm
WHERE ht.trait_id = tm.old_id
AND tm.old_id != tm.new_id;

-- Update the category for Level traits
UPDATE traits
SET category = 'Level'
WHERE category = 'Season 1 Level';

-- Delete duplicate traits (keeping the canonical ones)
DELETE FROM traits t
WHERE EXISTS (
  SELECT 1 
  FROM trait_mapping tm 
  WHERE tm.old_id = t.id 
  AND tm.old_id != tm.new_id
);

-- Update trait counts based on actual associations
WITH trait_counts AS (
  SELECT 
    trait_id,
    COUNT(*) as actual_count
  FROM hero_traits
  GROUP BY trait_id
)
UPDATE traits t
SET count = tc.actual_count
FROM trait_counts tc
WHERE t.id = tc.trait_id;

-- Update trait rarities based on total heroes
WITH total_heroes AS (
  SELECT COUNT(*) as count FROM heroes
)
UPDATE traits t
SET rarity = (t.count::decimal / th.count) * 100
FROM total_heroes th
WHERE th.count > 0;

-- Drop temporary table
DROP TABLE trait_mapping;

-- Update rarity scores and ranks
SELECT update_rarity_ranks();