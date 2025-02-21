/*
  # Initial Schema for OnChain Heroes

  1. New Tables
    - `traits`
      - `id` (uuid, primary key)
      - `category` (text) - e.g., "Head", "Eyes", etc.
      - `value` (text) - the trait value
      - `count` (integer) - number of heroes with this trait
      - `rarity` (decimal) - rarity percentage
      - `created_at` (timestamp)

    - `heroes`
      - `id` (integer, primary key) - the hero ID
      - `name` (text)
      - `image_url` (text)
      - `rarity_score` (decimal) - calculated overall rarity score
      - `rarity_rank` (integer) - hero's rank based on rarity
      - `created_at` (timestamp)

    - `hero_traits`
      - `id` (uuid, primary key)
      - `hero_id` (integer, references heroes)
      - `trait_id` (uuid, references traits)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for public read access
*/

-- Create traits table
CREATE TABLE traits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  value text NOT NULL,
  count integer NOT NULL,
  rarity decimal NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(category, value)
);

-- Create heroes table
CREATE TABLE heroes (
  id integer PRIMARY KEY,
  name text NOT NULL,
  image_url text,
  rarity_score decimal,
  rarity_rank integer,
  created_at timestamptz DEFAULT now()
);

-- Create hero_traits junction table
CREATE TABLE hero_traits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hero_id integer REFERENCES heroes(id) ON DELETE CASCADE,
  trait_id uuid REFERENCES traits(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(hero_id, trait_id)
);

-- Enable RLS
ALTER TABLE traits ENABLE ROW LEVEL SECURITY;
ALTER TABLE heroes ENABLE ROW LEVEL SECURITY;
ALTER TABLE hero_traits ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Allow public read access on traits"
  ON traits FOR SELECT TO public
  USING (true);

CREATE POLICY "Allow public read access on heroes"
  ON heroes FOR SELECT TO public
  USING (true);

CREATE POLICY "Allow public read access on hero_traits"
  ON hero_traits FOR SELECT TO public
  USING (true);

-- Create indexes for better query performance
CREATE INDEX traits_category_idx ON traits(category);
CREATE INDEX traits_rarity_idx ON traits(rarity);
CREATE INDEX heroes_rarity_rank_idx ON heroes(rarity_rank);
CREATE INDEX hero_traits_hero_id_idx ON hero_traits(hero_id);
CREATE INDEX hero_traits_trait_id_idx ON hero_traits(trait_id);

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