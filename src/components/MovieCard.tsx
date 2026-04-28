import { Link } from 'react-router-dom';
import { Star, Heart } from 'lucide-react';
import type { Media } from '../types';
import { getImageUrl } from '../services/tmdb';
import { useStore } from '../store/useStore';

export const MovieCard = ({ media }: { media: Media }) => {
  const { addFavorite, removeFavorite, isFavorite } = useStore();
  const isFav = isFavorite(media.id);

  const handleFav = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    isFav ? removeFavorite(media.id) : addFavorite(media);
  };

  const year = media.release_date
    ? new Date(media.release_date).getFullYear()
    : media.first_air_date
    ? new Date(media.first_air_date).getFullYear()
    : null;

  return (
    <Link
      to={`/details/${media.media_type || 'movie'}/${media.id}`}
      className="group relative rounded-xl overflow-hidden bg-surface shadow-lg transition-all duration-300 hover:scale-105 hover:shadow-[0_8px_32px_rgba(0,0,0,0.6)] hover:z-10 block aspect-[2/3]"
    >
      {/* Poster */}
      <img
        src={getImageUrl(media.poster_path, 'w500')}
        alt={media.title || media.name}
        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
        loading="lazy"
      />

      {/* Overlay on hover */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/95 via-black/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-end p-3">
        <h3 className="text-white font-bold text-sm leading-tight mb-1 line-clamp-2">
          {media.title || media.name}
        </h3>
        <div className="flex items-center justify-between text-xs text-gray-300">
          <span className="flex items-center gap-1 text-yellow-400">
            <Star className="w-3.5 h-3.5 fill-current" />
            {media.vote_average.toFixed(1)}
          </span>
          {year && <span>{year}</span>}
        </div>
      </div>

      {/* Media type label */}
      <div className="absolute top-2 left-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
        <span className="text-[10px] uppercase font-bold tracking-widest bg-black/70 text-gray-300 px-2 py-0.5 rounded-md">
          {media.media_type === 'tv' ? 'TV' : 'Film'}
        </span>
      </div>

      {/* Fav button */}
      <button
        onClick={handleFav}
        className="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full bg-black/60 hover:bg-black/80 transition-all opacity-0 group-hover:opacity-100 hover:scale-110 cursor-pointer"
        title={isFav ? 'Remove from favorites' : 'Add to favorites'}
      >
        <Heart
          className={`w-4 h-4 transition-colors ${
            isFav ? 'fill-primary text-primary' : 'text-white'
          }`}
        />
      </button>
    </Link>
  );
};
