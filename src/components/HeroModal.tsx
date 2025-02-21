import React, { useEffect, useRef } from 'react';
import { X, Crown } from 'lucide-react';

interface HeroAttribute {
  trait_type: string;
  value: string | number;
}

interface HeroData {
  id: number;
  name: string;
  image_url: string;
  attributes: HeroAttribute[];
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

interface HeroModalProps {
  hero: HeroData | null;
  isOpen: boolean;
  onClose: () => void;
  traits: TraitsByCategory;
}

export const HeroModal: React.FC<HeroModalProps> = ({ hero, isOpen, onClose, traits }) => {
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (modalRef.current && !modalRef.current.contains(event.target as Node)) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      // Prevent body scroll when modal is open
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      // Restore body scroll when modal is closed
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  if (!isOpen || !hero) return null;

  const getRarityForTrait = (traitType: string, value: string | number): string => {
    // Handle "Season 1 Level" mapping to "Level"
    const categoryKey = traitType === "Season 1 Level" ? "Level" : 
                       traitType === "Name" ? "1/1" : 
                       traitType;
                       
    const categoryTraits = traits[categoryKey];
    if (!categoryTraits) return 'N/A';
    
    const trait = categoryTraits.find(t => t.value === value.toString());
    return trait ? trait.rarity : 'N/A';
  };

  const getTraitColor = (rarity: string): string => {
    if (rarity === 'N/A') return 'text-gray-300';
    const percentage = parseFloat(rarity.replace('%', ''));
    if (percentage <= 1) return 'text-purple-400';
    if (percentage <= 5) return 'text-blue-400';
    if (percentage <= 10) return 'text-green-400';
    return 'text-gray-300';
  };

  // Ensure attributes is always an array
  const attributes = Array.isArray(hero.attributes) ? hero.attributes : 
                    typeof hero.attributes === 'string' ? JSON.parse(hero.attributes) :
                    [];

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50 overflow-y-auto">
      <div 
        ref={modalRef}
        className="bg-blue-900 rounded-lg w-full max-w-2xl my-8 relative overflow-hidden border-2 border-yellow-400 max-h-[90vh] overflow-y-auto"
      >
        <button
          onClick={onClose}
          className="absolute right-4 top-4 text-gray-400 hover:text-white z-10"
        >
          <X size={24} />
        </button>
        
        <div className="p-6">
          <div className="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4 mb-6">
            <h2 className="font-pixel text-xl sm:text-2xl text-yellow-400">{hero.name}</h2>
            {hero.rarity_rank && (
              <div className="bg-blue-800/50 rounded-lg p-3 text-center shrink-0">
                <div className="flex items-center gap-2 justify-center mb-1">
                  <Crown className="text-yellow-400" size={20} />
                  <span className="text-sm text-gray-300">Rarity Rank</span>
                </div>
                <div className="font-pixel text-lg text-yellow-400">
                  #{hero.rarity_rank}
                </div>
                {hero.rarity_score && (
                  <div className="text-xs text-gray-400 mt-1">
                    Score: {hero.rarity_score.toFixed(4)}
                  </div>
                )}
              </div>
            )}
          </div>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="relative">
              <img
                src={hero.image_url}
                alt={hero.name}
                className="rounded-lg w-full"
                loading="lazy"
              />
            </div>
            
            <div className="space-y-4">
              <h3 className="font-pixel text-lg text-white mb-2">Traits</h3>
              {attributes.length > 0 ? (
                attributes.map((attr, index) => {
                  const rarity = getRarityForTrait(attr.trait_type, attr.value);
                  const colorClass = getTraitColor(rarity);
                  
                  return (
                    <div
                      key={`${attr.trait_type}-${index}`}
                      className="bg-blue-800/50 rounded-lg p-3"
                    >
                      <div className="text-sm text-gray-300 mb-1">
                        {attr.trait_type === "Season 1 Level" ? "Level" : attr.trait_type}
                      </div>
                      <div className="flex justify-between items-center">
                        <div className="font-medium">{attr.value}</div>
                        <div className={`font-bold ${colorClass}`}>{rarity}</div>
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="text-gray-400 text-center py-4">
                  No traits found for this hero
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};