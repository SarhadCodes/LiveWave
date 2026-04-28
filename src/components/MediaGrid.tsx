import type { Media } from '../types';
import { MovieCard } from './MovieCard';
import { SkeletonCard } from './SkeletonCard';

interface MediaGridProps {
  items: Media[];
  loading?: boolean;
  skeletonCount?: number;
}

export const MediaGrid = ({ items, loading = false, skeletonCount = 12 }: MediaGridProps) => {
  if (loading) {
    return (
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
        {Array.from({ length: skeletonCount }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4 animate-fadeIn">
      {items.map((item) => (
        <MovieCard key={`${item.media_type}-${item.id}`} media={item} />
      ))}
    </div>
  );
};
