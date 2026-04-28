import { useState, useEffect } from 'react';
import { Search as SearchIcon } from 'lucide-react';
import { searchMedia } from '../services/tmdb';
import type { Media } from '../types';
import { MediaGrid } from '../components/MediaGrid';

export const Search = () => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Media[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      setSearched(false);
      return;
    }

    const timer = setTimeout(async () => {
      setLoading(true);
      setSearched(true);
      try {
        const data = await searchMedia(query);
        setResults(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [query]);

  return (
    <div className="min-h-screen pt-24 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Search Input */}
      <div className="relative max-w-2xl mx-auto mb-12">
        <SearchIcon className="absolute left-5 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 pointer-events-none" />
        <input
          id="search-input"
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search movies, TV shows, people…"
          autoFocus
          className="w-full pl-14 pr-5 py-4 rounded-2xl bg-surface border border-white/10 text-white placeholder-gray-500 text-lg focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all shadow-xl"
        />
      </div>

      {/* States */}
      {!query && (
        <div className="flex flex-col items-center justify-center py-24 text-gray-600 select-none">
          <SearchIcon className="w-16 h-16 mb-4 opacity-30" />
          <p className="text-xl font-medium">Start typing to search</p>
          <p className="text-sm mt-1">Find your favorite movies and TV shows</p>
        </div>
      )}

      {searched && !loading && results.length === 0 && (
        <div className="text-center py-24 text-gray-500">
          <p className="text-xl font-semibold mb-2">No results for "{query}"</p>
          <p className="text-sm">Try a different title or check the spelling</p>
        </div>
      )}

      {(loading || results.length > 0) && (
        <>
          {!loading && (
            <p className="text-gray-400 text-sm mb-4">
              {results.length} result{results.length !== 1 ? 's' : ''} for &ldquo;{query}&rdquo;
            </p>
          )}
          <MediaGrid items={results} loading={loading} skeletonCount={12} />
        </>
      )}
    </div>
  );
};
