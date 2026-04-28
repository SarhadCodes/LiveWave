import { Link } from 'react-router-dom';
import { Play, Info } from 'lucide-react';
import type { Media } from '../types';
import { getImageUrl } from '../services/tmdb';

export const Hero = ({ media }: { media: Media }) => (
  <div className="relative h-[80vh] w-full overflow-hidden">
    {/* Background image */}
    <img
      src={getImageUrl(media.backdrop_path, 'original')}
      alt={media.title || media.name}
      className="absolute inset-0 w-full h-full object-cover scale-105 animate-[heroZoom_8s_ease_forwards]"
    />

    {/* Gradients */}
    <div className="absolute inset-0 bg-gradient-to-r from-[#0f0f0f] via-[#0f0f0f]/60 to-transparent" />
    <div className="absolute inset-x-0 bottom-0 h-48 bg-gradient-to-t from-[#0f0f0f] to-transparent" />

    {/* Content */}
    <div className="relative h-full flex items-end pb-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div className="max-w-xl animate-fadeIn">
        {/* Media type badge */}
        <span className="inline-block bg-primary/90 text-white text-xs font-bold uppercase tracking-widest px-3 py-1 rounded-full mb-4">
          {media.media_type === 'tv' ? 'TV Show' : 'Movie'} &bull; Trending
        </span>

        <h1 className="text-5xl md:text-7xl font-black text-white leading-tight mb-4 drop-shadow-2xl">
          {media.title || media.name}
        </h1>

        <p className="text-gray-300 text-base md:text-lg leading-relaxed line-clamp-3 mb-8 drop-shadow-lg">
          {media.overview}
        </p>

        <div className="flex flex-wrap gap-4">
          <Link
            to={`/details/${media.media_type}/${media.id}`}
            className="flex items-center gap-2.5 px-8 py-3.5 bg-white text-black font-bold rounded-full hover:bg-gray-100 transition-all hover:scale-105 shadow-xl"
          >
            <Play className="w-5 h-5 fill-black" />
            Watch Now
          </Link>
          <Link
            to={`/details/${media.media_type}/${media.id}`}
            className="flex items-center gap-2.5 px-8 py-3.5 glass text-white font-semibold rounded-full hover:bg-white/15 transition-all"
          >
            <Info className="w-5 h-5" />
            More Info
          </Link>
        </div>
      </div>
    </div>
  </div>
);
