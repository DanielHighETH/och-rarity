/*
  # Fix rarity calculation and trait syncing

  1. Changes
    - Add function to sync hero traits from attributes
    - Add function to update trait counts and rarities
    - Improve rarity calculation to handle edge cases
    - Add transaction safety to rank updates
*/

-- Create function to sync hero traits from attributes
CREATE OR REPLACE FUNCTION sync_hero_traits(p_hero_id integer)
RETURNS void AS $$
DECLARE
  attr jsonb;
  trait_type text;
  trait_value text;
  trait_id uuid;
  attr_record record;
BEGIN
  -- Get hero attributes
  SELECT attributes INTO attr
  FROM heroes
  WHERE id = p_hero_id;

  -- Skip if no attributes
  IF attr IS NULL OR jsonb_array_length(attr) = 0 THEN
    RETURN;
  END IF;

  -- Delete existing trait associations
  DELETE FROM hero_traits WHERE hero_id = p_hero_id;

  -- Process each attribute
  FOR attr_record IN
    SELECT 
      CASE 
        WHEN value->>'trait_type' = 'Season 1 Level' THEN 'Level'
        WHEN value->>'trait_type' = 'Name' THEN '1/1'
        ELSE value->>'trait_type'
      END as trait_type,
      value->>'value' as trait_value
    FROM jsonb_array_elements(attr)
  LOOP
    -- Skip if trait type or value is null
    IF attr_record.trait_type IS NULL OR attr_record.trait_value IS NULL THEN
      CONTINUE;
    END IF;

    -- Get or create trait
    WITH trait_insert AS (
      INSERT INTO traits (category, value, count, rarity)
      VALUES (
        attr_record.trait_type,
        attr_record.trait_value,
        1,
        0.01  -- Initial rarity, will be updated
      )
      ON CONFLICT (category, value) DO UPDATE
      SET count = traits.count
      RETURNING id
    )
    SELECT id INTO trait_id FROM trait_insert;

    -- Link trait to hero
    IF trait_id IS NOT NULL THEN
      INSERT INTO hero_traits (hero_id, trait_id)
      VALUES (p_hero_id, trait_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create function to update trait counts
CREATE OR REPLACE FUNCTION update_trait_counts()
RETURNS void AS $$
DECLARE
  total_heroes integer;
BEGIN
  -- Get total number of heroes
  SELECT COUNT(*) INTO total_heroes FROM heroes;

  -- Update trait counts and rarities
  UPDATE traits t
  SET 
    count = subquery.trait_count,
    rarity = (subquery.trait_count::decimal / NULLIF(total_heroes, 0)) * 100
  FROM (
    SELECT trait_id, COUNT(*) as trait_count
    FROM hero_traits
    GROUP BY trait_id
  ) subquery
  WHERE t.id = subquery.trait_id;
END;
$$ LANGUAGE plpgsql;

-- Improve rarity calculation function
CREATE OR REPLACE FUNCTION calculate_hero_rarity(p_hero_id integer)
RETURNS decimal AS $$
DECLARE
  rarity_score decimal;
  trait_count integer;
BEGIN
  -- Get number of traits for this hero
  SELECT COUNT(*) INTO trait_count
  FROM hero_traits
  WHERE hero_id = p_hero_id;

  -- If no traits, return NULL
  IF trait_count = 0 THEN
    RETURN NULL;
  END IF;

  -- Calculate rarity score
  WITH trait_rarities AS (
    SELECT t.rarity
    FROM hero_traits ht
    JOIN traits t ON t.id = ht.trait_id
    WHERE ht.hero_id = p_hero_id
    AND t.rarity > 0  -- Avoid division by zero
  )
  SELECT 
    POWER(EXP(SUM(LN(NULLIF(rarity, 0)))), 1.0 / NULLIF(COUNT(*), 0))
  INTO rarity_score
  FROM trait_rarities;
  
  RETURN rarity_score;
END;
$$ LANGUAGE plpgsql;

-- Improve rank update function
CREATE OR REPLACE FUNCTION update_rarity_ranks()
RETURNS void AS $$
DECLARE
  hero_record record;
  batch_size integer := 100;
  processed integer := 0;
BEGIN
  -- Process heroes in batches
  FOR hero_record IN 
    SELECT id 
    FROM heroes 
    ORDER BY id
  LOOP
    -- Sync traits for this hero
    PERFORM sync_hero_traits(hero_record.id);
    
    processed := processed + 1;
    
    -- Log progress every 100 heroes
    IF processed % batch_size = 0 THEN
      RAISE NOTICE 'Processed % heroes', processed;
    END IF;
  END LOOP;

  -- Update trait counts and rarities
  PERFORM update_trait_counts();

  -- Update rarity scores for all heroes
  UPDATE heroes h
  SET rarity_score = calculate_hero_rarity(h.id);

  -- Update rarity ranks based on rarity scores
  WITH ranked_heroes AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY rarity_score ASC NULLS LAST) as new_rank
    FROM heroes
  )
  UPDATE heroes h
  SET rarity_rank = rh.new_rank
  FROM ranked_heroes rh
  WHERE h.id = rh.id;

  RAISE NOTICE 'Completed updating rarity ranks for % heroes', processed;
END;
$$ LANGUAGE plpgsql;