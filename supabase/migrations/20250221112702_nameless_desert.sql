/*
  # Add Rarity Calculation Functions

  1. New Functions
    - `calculate_hero_rarity(hero_id integer)`: Calculates rarity score for a specific hero
    - `update_rarity_ranks()`: Updates rarity ranks for all heroes based on their scores

  2. Purpose
    - These functions enable automatic calculation of hero rarity scores
    - Provides ranking system based on trait rarity combinations
*/

-- Create function to calculate rarity score
CREATE OR REPLACE FUNCTION calculate_hero_rarity(hero_id integer)
RETURNS decimal AS $$
DECLARE
  rarity_score decimal;
BEGIN
  WITH trait_rarities AS (
    SELECT t.rarity
    FROM hero_traits ht
    JOIN traits t ON t.id = ht.trait_id
    WHERE ht.hero_id = hero_id
  )
  SELECT 
    -- Calculate statistical rarity score
    -- Using product of individual rarities and taking the geometric mean
    POWER(EXP(SUM(LN(rarity))), 1.0 / COUNT(*))
  INTO rarity_score
  FROM trait_rarities;
  
  RETURN rarity_score;
END;
$$ LANGUAGE plpgsql;

-- Create function to update rarity ranks
CREATE OR REPLACE FUNCTION update_rarity_ranks()
RETURNS void AS $$
BEGIN
  -- Update rarity scores for all heroes
  UPDATE heroes h
  SET rarity_score = calculate_hero_rarity(h.id)
  WHERE EXISTS (
    SELECT 1 FROM hero_traits WHERE hero_id = h.id
  );

  -- Update rarity ranks based on rarity scores
  WITH ranked_heroes AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY rarity_score ASC) as new_rank
    FROM heroes
    WHERE rarity_score IS NOT NULL
  )
  UPDATE heroes h
  SET rarity_rank = rh.new_rank
  FROM ranked_heroes rh
  WHERE h.id = rh.id;
END;
$$ LANGUAGE plpgsql;