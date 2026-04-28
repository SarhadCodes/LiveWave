import { Heart, Trash2 } from 'lucide-react';
import { useStore } from '../store/useStore';
import { MediaGrid } from '../components/MediaGrid';

export const Favorites = () => {
  const { favorites, removeFavorite } = useStore();

  return (
    <div className="min-h-screen pt-24 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <Heart className="w-7 h-7 text-primary fill-primary" />
          <h1 className="text-3xl md:text-4xl font-black text-white">My Favorites</h1>
        </div>
        {favorites.length > 0 && (
          <span className="text-sm text-gray-400">
            {favorites.length} title{favorites.length !== 1 ? 's' : ''}
          </span>
        )}
      </div>

      {/* Empty state */}
      {favorites.length === 0 ? (
        <div className="flex flex-col items-center justify-center h-[55vh] text-center select-none">
          <div className="w-24 h-24 rounded-full bg-surface flex items-center justify-center mb-6">
            <Heart className="w-12 h-12 text-gray-600" />
          </div>
          <h2 className="text-xl font-bold text-gray-400 mb-2">No favorites yet</h2>
          <p className="text-gray-600 text-sm max-w-xs">
            Browse movies and TV shows, then tap the&nbsp;
            <Heart className="inline w-3.5 h-3.5 text-primary" /> icon to save them here.
          </p>
        </div>
      ) : (
        <>
          <MediaGrid items={favorites} />

          {/* Clear all */}
          <div className="mt-10 flex justify-center">
            <button
              onClick={() => favorites.forEach((f) => removeFavorite(f.id))}
              className="flex items-center gap-2 px-6 py-3 bg-surface border border-white/10 text-gray-400 hover:text-primary hover:border-primary/40 rounded-full text-sm font-medium transition-all cursor-pointer"
            >
              <Trash2 className="w-4 h-4" />
              Clear all favorites
            </button>
          </div>
        </>
      )}
    </div>
  );
};
