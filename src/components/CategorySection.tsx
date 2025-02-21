import React from 'react';
import { Trait } from '../data/traits';
import { RarityCard } from './RarityCard';

interface CategorySectionProps {
  title: string;
  traits: Trait[];
  showTitle?: boolean;
}

export const CategorySection: React.FC<CategorySectionProps> = ({ title, traits, showTitle = true }) => {
  const sortedTraits = [...traits].sort((a, b) => 
    parseFloat(a.rarity.replace('%', '')) - parseFloat(b.rarity.replace('%', ''))
  );

  return (
    <div className="mb-8">
      {showTitle && (
        <h2 className="text-2xl font-pixel mb-4 text-yellow-400 drop-shadow-[0_2px_2px_rgba(0,0,0,0.5)]">
          {title}
        </h2>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {sortedTraits.map((trait, index) => (
          <RarityCard 
            key={`${title}-${trait.value}-${index}`} 
            trait={trait} 
            category={title} 
          />
        ))}
      </div>
    </div>
  );
}