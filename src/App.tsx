import React, { useState, useEffect } from 'react';
import { CategorySection } from './components/CategorySection';
import { HeroModal } from './components/HeroModal';
import { Gamepad2, Search, Clock } from 'lucide-react';
import { supabase } from './lib/supabase';

interface Trait {
  category: string;
  value: string;
  count: number;
  rarity: string;
}

interface HeroData {
  id: number;
  name: string;
  image_url: string;
  attributes: Array<{
    trait_type: string;
    value: string | number;
  }>;
  rarity_score?: number;
  rarity_rank?: number;
}

interface TraitsByCategory {
  [key: string]: Array<{
    value: string;
    count: number;
    rarity: string;
  }>;
}

function App() {
  const [selectedCategory, setSelectedCategory] = useState<string>("All");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set());
  const [heroId, setHeroId] = useState<string>("");
  const [heroData, setHeroData] = useState<HeroData | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [traits, setTraits] = useState<TraitsByCategory>({});
  const [lastUpdated, setLastUpdated] = useState<string>("");

  const categoryOrder = ["Type", "Level", "Top", "Head", "Eyes", "Weapon", "Bottom", "1/1"];

  useEffect(() => {
    async function fetchTraits() {
      const { data: traitsData, error } = await supabase
        .from('traits')
        .select('*')
        .order('category')
        .order('value');

      if (error) {
        console.error('Error fetching traits:', error);
        return;
      }

      const groupedTraits = traitsData.reduce((acc: TraitsByCategory, trait: Trait) => {
        const category = trait.category === "Season 1 Level" ? "Level" :
                        trait.category === "Name" ? "1/1" :
                        trait.category;
        if (!acc[category]) {
          acc[category] = [];
        }
        acc[category].push({
          value: trait.value,
          count: trait.count,
          rarity: `${trait.rarity.toFixed(2)}%`
        });
        return acc;
      }, {});

      setTraits(groupedTraits);

      const { data: latestHero } = await supabase
        .from('heroes')
        .select('created_at')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (latestHero) {
        const date = new Date(latestHero.created_at);
        setLastUpdated(date.toLocaleString('en-US', {
          month: '2-digit',
          day: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
          timeZone: 'America/New_York'
        }));
      }
    }

    fetchTraits();
  }, []);

  const fetchHeroData = async (id: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const { data: hero, error: heroError } = await supabase
        .from('heroes')
        .select('*')
        .eq('id', parseInt(id))
        .single();

      if (heroError) throw new Error('Hero not found');
      if (!hero) throw new Error('Hero not found');

      if (typeof hero.attributes === 'string') {
        hero.attributes = JSON.parse(hero.attributes);
      }

      setHeroData(hero);
      setIsModalOpen(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch hero data');
    } finally {
      setIsLoading(false);
    }
  };

  const handleHeroSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (heroId.trim()) {
      fetchHeroData(heroId.trim());
    }
  };

  useEffect(() => {
    if (searchQuery) {
      const matchingCategories = Object.entries(traits).reduce((acc, [category, categoryTraits]) => {
        if (categoryTraits.some(trait => 
          trait.value.toLowerCase().includes(searchQuery.toLowerCase())
        )) {
          acc.add(category);
        }
        return acc;
      }, new Set<string>());
      setExpandedCategories(matchingCategories);
    } else {
      if (selectedCategory !== "All") {
        setExpandedCategories(new Set([selectedCategory]));
      } else {
        setExpandedCategories(new Set());
      }
    }
  }, [searchQuery, selectedCategory, traits]);

  useEffect(() => {
    if (selectedCategory === "All") {
      setExpandedCategories(new Set());
    } else {
      setExpandedCategories(new Set([selectedCategory]));
    }
    setSearchQuery("");
  }, [selectedCategory]);

  const toggleCategory = (category: string) => {
    setExpandedCategories(prev => {
      const newSet = new Set(prev);
      if (newSet.has(category)) {
        newSet.delete(category);
      } else {
        newSet.add(category);
      }
      return newSet;
    });
  };

  const getFilteredTraits = () => {
    if (!searchQuery) {
      return traits;
    }

    const searchLower = searchQuery.toLowerCase();
    return Object.entries(traits).reduce((acc, [category, categoryTraits]) => {
      const filteredTraits = categoryTraits.filter(trait =>
        trait.value.toLowerCase().includes(searchLower)
      );
      
      if (filteredTraits.length > 0) {
        acc[category] = filteredTraits;
      }
      return acc;
    }, {} as TraitsByCategory);
  };

  const filteredTraits = getFilteredTraits();

  const getDisplayedCategories = () => {
    if (selectedCategory !== "All") {
      return [[selectedCategory, filteredTraits[selectedCategory]]].filter(([, traits]) => traits);
    }
    
    if (searchQuery) {
      return Object.entries(filteredTraits);
    }
    
    return categoryOrder
      .filter(category => traits[category])
      .map(category => [category, traits[category]]);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-900 via-blue-700 to-blue-900 text-white">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl md:text-6xl font-pixel mb-4 text-yellow-400 flex items-center justify-center gap-4">
            <Gamepad2 className="w-12 h-12" />
            OnChain Heroes Rarity
          </h1>
          <p className="text-lg opacity-90 mb-2">Discover the rarity of your hero's traits!</p>
          <p className="text-sm opacity-75">
            Built by <a href="https://x.com/dhigh_eth" target="_blank" rel="noopener noreferrer" className="text-yellow-400 hover:text-yellow-300 underline">DanielHigh</a>
          </p>
          <p className="text-xs text-gray-400 mt-2">
            Not affiliated with <a href="https://x.com/onchainheroes" target="_blank" rel="noopener noreferrer" className="text-yellow-400 hover:text-yellow-300">@onchainheroes</a>
          </p>
        </div>

        {/* Hero Checker */}
        <div className="max-w-md mx-auto mb-8">
          <form onSubmit={handleHeroSubmit} className="relative">
            <Gamepad2 className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="number"
              placeholder="Enter hero ID..."
              value={heroId}
              onChange={(e) => setHeroId(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-full bg-white/10 border border-white/20 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-yellow-400 focus:border-transparent"
              min="1"
            />
            <button
              type="submit"
              disabled={isLoading}
              className="absolute right-2 top-1/2 transform -translate-y-1/2 px-4 py-1 rounded-full bg-yellow-400 text-blue-900 font-medium hover:bg-yellow-300 transition-colors disabled:opacity-50"
            >
              {isLoading ? 'Loading...' : 'Check'}
            </button>
          </form>
          {error && (
            <p className="text-red-400 text-sm mt-2 text-center">{error}</p>
          )}
        </div>

        {/* Search Bar */}
        <div className="relative max-w-md mx-auto mb-4">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
          <input
            type="text"
            placeholder="Search for traits..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-full bg-white/10 border border-white/20 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-yellow-400 focus:border-transparent"
          />
        </div>

        {/* Data Timestamp */}
        <div className="flex items-center justify-center gap-2 text-sm text-gray-300 mb-8">
          <Clock size={16} />
          <span>Last updated: {lastUpdated} ET • Data refreshes every ~24 hours</span>
        </div>

        {/* Category Navigation */}
        {!searchQuery && (
          <div className="flex flex-wrap gap-2 justify-center mb-8">
            {["All", ...categoryOrder].map((category) => (
              traits[category] || category === "All" ? (
                <button
                  key={category}
                  onClick={() => setSelectedCategory(category)}
                  className={`px-4 py-2 rounded-full font-pixel transition-all
                    ${selectedCategory === category 
                      ? 'bg-yellow-400 text-blue-900' 
                      : 'bg-blue-800 hover:bg-blue-700'}`}
                >
                  {category}
                </button>
              ) : null
            ))}
          </div>
        )}

        {/* Trait Categories */}
        <div className="space-y-8">
          {getDisplayedCategories().map(([category, categoryTraits]) => {
            const isBasicCategory = category === "Type" || category === "Level";
            
            return isBasicCategory ? (
              <div key={category} className="bg-blue-800/50 rounded-lg p-4">
                <h2 className="font-pixel text-xl text-yellow-400 mb-4">{category}</h2>
                <CategorySection 
                  title={category}
                  traits={categoryTraits}
                  showTitle={false}
                />
              </div>
            ) : (
              <div key={category} className="bg-blue-800/50 rounded-lg overflow-hidden">
                <button
                  onClick={() => toggleCategory(category)}
                  className="w-full px-6 py-4 text-left font-pixel text-xl text-yellow-400 hover:bg-blue-700/50 transition-colors flex justify-between items-center"
                >
                  <span>{category}</span>
                  <span className="text-sm">{expandedCategories.has(category) ? '▼' : '▶'}</span>
                </button>
                {expandedCategories.has(category) && (
                  <div className="p-4">
                    <CategorySection 
                      title={category}
                      traits={categoryTraits}
                      showTitle={false}
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* FAQ Section */}
        <div className="mt-16 bg-blue-800/50 rounded-lg p-6">
          <h2 className="font-pixel text-2xl text-yellow-400 mb-6 text-center">FAQ</h2>
          <div className="space-y-6 max-w-2xl mx-auto">
            <div>
              <h3 className="text-lg font-semibold text-yellow-400 mb-2">Is this safe?</h3>
              <div className="text-gray-300">Yes, it is safe. You are not required to sign in or perform any actions with your wallet.</div>
            </div>
            <div>
              <h3 className="text-lg font-semibold text-yellow-400 mb-2">Can I see the code?</h3>
              <div className="text-gray-300">
                Yes, the code is on <a href="https://github.com/DanielHighETH/och-rarity" target="_blank" rel="noopener noreferrer" className="text-yellow-400 hover:text-yellow-300 underline">GitHub</a>.
              </div>
            </div>
            <div>
              <h3 className="text-lg font-semibold text-yellow-400 mb-2">Is the data real-time?</h3>
              <div className="text-gray-300">
                No, the data updates approximately every 24 hours. We avoid frequent requests to the OnChainHeroes API to prevent spamming.
              </div>
            </div>
            <div>
              <h3 className="text-lg font-semibold text-yellow-400 mb-2">What rarity formula are you using?</h3>
              <div className="text-gray-300 space-y-4">
                <div>
                  We use a statistical approach that considers both individual trait rarities and their combinations:
                </div>
                
                <div className="space-y-2">
                  <div className="font-semibold">Step 1: Calculate Individual Trait Rarity</div>
                  <code className="block bg-blue-900/50 px-3 py-2 rounded">
                    trait rarity = (number of heroes with this trait ÷ total heroes) × 100
                  </code>
                  <div className="text-sm italic">
                    Example: If 50 heroes out of 1000 have a trait, its rarity is (50 ÷ 1000) × 100 = 5%
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="font-semibold">Step 2: Calculate Hero's Overall Rarity</div>
                  <div className="space-y-1">
                    <div>• Multiply all trait rarities together</div>
                    <div>• Take the geometric mean (nth root where n is the number of traits)</div>
                  </div>
                  <div className="text-sm italic">
                    Example: A hero with traits of 5%, 10%, and 20% rarity would have:
                    <br />
                    Score = ∛(5 × 10 × 20) = 10.0
                  </div>
                </div>

                <div className="mt-4 bg-blue-900/50 p-3 rounded">
                  <div className="font-semibold text-yellow-400">What this means:</div>
                  <div className="mt-2 space-y-1">
                    <div>• Lower scores = rarer heroes</div>
                    <div>• Having multiple rare traits makes a hero even rarer</div>
                    <div>• Common traits balance out with rare ones</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Disclaimer */}
        <div className="mt-8 text-center text-sm text-gray-400">
          <p>Built by <a href="https://x.com/dhigh_eth" target="_blank" rel="noopener noreferrer" className="text-yellow-400 hover:text-yellow-300">DanielHigh</a></p>
          <p className="mt-1">Not affiliated with <a href="https://x.com/onchainheroes" target="_blank" rel="noopener noreferrer" className="text-yellow-400 hover:text-yellow-300">@onchainheroes</a></p>
          <p className="mt-1">Data might not be accurate</p>
        </div>
      </div>

      <HeroModal
        hero={heroData}
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        traits={traits}
      />
    </div>
  );
}

export default App;