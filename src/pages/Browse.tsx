import { useState, useEffect, useCallback, useRef } from 'react';
import { getTrending, discoverMovies, discoverTV, discoverByGenre } from '../services/tmdb';
import type { Media } from '../types';
import { Hero } from '../components/Hero';
import { MediaGrid } from '../components/MediaGrid';
import { CategoryFilter } from '../components/CategoryFilter';

interface BrowseProps {
  initialType?: 'movie' | 'tv' | 'all';
  title?: string;
  showHero?: boolean;
}

export const Browse = ({ initialType = 'all', title = 'Popular Now', showHero = true }: BrowseProps) => {
  const [hero, setHero] = useState<Media | null>(null);
  const [items, setItems] = useState<Media[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [category, setCategory] = useState(initialType);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const loaderRef = useRef<HTMLDivElement | null>(null);

  // When initialType changes (e.g. navigation between Movies and TV), reset state
  useEffect(() => {
    setCategory(initialType);
    setItems([]);
    setPage(1);
    setLoading(true);
  }, [initialType]);

  // Fetch hero from trending
  useEffect(() => {
    if (!showHero) return;
    getTrending().then((results) => {
      if (results.length) {
        if (initialType === 'all') {
          setHero(results[0]);
        } else {
          const filteredHero = results.find(item => item.media_type === initialType);
          setHero(filteredHero || results[0]);
        }
      }
    });
  }, [showHero, initialType]);

  const fetchItems = useCallback(async (cat: string, pg: number) => {
    try {
      let results: Media[] = [];
      let total = 1;

      if (cat === 'all') {
        const [movies, tv] = await Promise.all([discoverMovies(pg), discoverTV(pg)]);
        results = [...movies.results, ...tv.results].sort(
          (a, b) => b.vote_average - a.vote_average
        );
        total = Math.max(movies.total_pages, tv.total_pages);
      } else if (cat === 'movie') {
        const res = await discoverMovies(pg);
        results = res.results;
        total = res.total_pages;
      } else if (cat === 'tv') {
        const res = await discoverTV(pg);
        results = res.results;
        total = res.total_pages;
      } else {
        // Genre filter - if we are in a sub-section (Movies or TV), search only that type
        const typeToFetch = initialType === 'all' ? ['movie', 'tv'] : [initialType];
        
        const promises = typeToFetch.map(type => discoverByGenre(cat, type as 'movie' | 'tv', pg));
        const responses = await Promise.all(promises);
        
        results = responses.flatMap(res => res.results).sort(
          (a, b) => b.vote_average - a.vote_average
        );
        total = Math.max(...responses.map(res => res.total_pages));
      }

      return { results, total };
    } catch (err) {
      console.error('Error fetching items:', err);
      return { results: [], total: 1 };
    }
  }, [initialType]);

  // Initial load when category or initialType changes
  useEffect(() => {
    let isMounted = true;
    fetchItems(category, 1).then(({ results, total }) => {
      if (!isMounted) return;
      setItems(results);
      setTotalPages(total);
      setLoading(false);
    });
    return () => { isMounted = false; };
  }, [category, fetchItems]);

  // Infinite scroll
  useEffect(() => {
    if (page === 1) return;
    setLoadingMore(true);
    fetchItems(category, page).then(({ results }) => {
      setItems((prev) => [...prev, ...results]);
      setLoadingMore(false);
    });
  }, [page, category, fetchItems]);

  // Intersection Observer
  useEffect(() => {
    if (!loaderRef.current) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !loadingMore && page < totalPages) {
          setPage((p) => p + 1);
        }
      },
      { threshold: 0.1 }
    );
    observer.observe(loaderRef.current);
    return () => observer.disconnect();
  }, [loadingMore, page, totalPages]);

  return (
    <div className="min-h-screen pb-20">
      {showHero && hero && <Hero media={hero} />}

      <div className={`max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6 ${showHero ? 'mt-10' : 'pt-28'}`}>
        <CategoryFilter active={category} onChange={(c) => setCategory(c as any)} />

        <div className="flex items-center justify-between">
          <h2 className="text-3xl font-black text-white tracking-tight">
            {category === 'all' ? title : 
             category === 'movie' ? 'Movies' : 
             category === 'tv' ? 'TV Shows' : 'Results'}
          </h2>
          <span className="text-sm font-bold text-gray-500 bg-white/5 px-3 py-1 rounded-full border border-white/5">
            {!loading && `${items.length} titles`}
          </span>
        </div>

        <MediaGrid items={items} loading={loading} skeletonCount={18} />

        <div ref={loaderRef} className="h-20 flex items-center justify-center">
          {loadingMore && (
            <div className="flex gap-2">
              {[0, 1, 2].map((i) => (
                <div key={i} className="w-2.5 h-2.5 rounded-full bg-primary animate-bounce shadow-[0_0_10px_rgba(229,9,20,0.5)]" style={{ animationDelay: `${i * 0.15}s` }} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
