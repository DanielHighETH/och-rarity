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
DO $$ 
DECLARE
  total_heroes integer;
BEGIN
  -- Get total number of heroes for rarity calculation
  SELECT COUNT(*) INTO total_heroes FROM heroes;

  -- First, handle the Level category renaming and merge counts
  UPDATE traits t1
  SET 
    count = t1.count + COALESCE(t2.count, 0),
    category = 'Level'
  FROM (
    SELECT id, count
    FROM traits 
    WHERE category = 'Season 1 Level'
  ) t2
  WHERE t1.category = 'Level' 
  AND t1.value = t2.value;

  -- Delete the old Season 1 Level traits
  DELETE FROM traits
  WHERE category = 'Season 1 Level';

  -- Update hero_traits to point to the correct Level traits
  WITH level_traits AS (
    SELECT id, value
    FROM traits
    WHERE category = 'Level'
  )
  UPDATE hero_traits ht
  SET trait_id = lt.id
  FROM level_traits lt
  WHERE ht.trait_id IN (
    SELECT id FROM traits WHERE category = 'Season 1 Level'
  )
  AND EXISTS (
    SELECT 1 
    FROM traits t 
    WHERE t.id = ht.trait_id 
    AND t.value = lt.value
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
  SET count = COALESCE(tc.actual_count, 0)
  FROM trait_counts tc
  WHERE t.id = tc.trait_id;

  -- Update trait rarities based on total heroes
  IF total_heroes > 0 THEN
    UPDATE traits
    SET rarity = (count::decimal / total_heroes) * 100
    WHERE count > 0;
  END IF;

  -- Clean up any orphaned traits
  DELETE FROM traits t
  WHERE NOT EXISTS (
    SELECT 1 
    FROM hero_traits ht 
    WHERE ht.trait_id = t.id
  );

  -- Recalculate rarity scores and ranks
  PERFORM update_rarity_ranks();
END $$;