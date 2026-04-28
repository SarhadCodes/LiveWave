import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Play, Heart, Star, Calendar, Clock, X, ChevronRight, List } from 'lucide-react';
import { getDetails, getImageUrl, getSeasonDetails } from '../services/tmdb';
import { useStore } from '../store/useStore';
import type { MediaDetails, Season } from '../types';
import { MediaGrid } from '../components/MediaGrid';
import { Player } from '../components/Player';

export const Details = () => {
  const { type, id } = useParams<{ type: string; id: string }>();
  const [details, setDetails] = useState<MediaDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [showTrailer, setShowTrailer] = useState(false);
  const [showPlayer, setShowPlayer] = useState(false);
  
  // TV specific state
  const [selectedSeason, setSelectedSeason] = useState(1);
  const [selectedEpisode, setSelectedEpisode] = useState(1);
  const [seasonData, setSeasonData] = useState<Season | null>(null);
  const [loadingSeason, setLoadingSeason] = useState(false);

  const { addFavorite, removeFavorite, isFavorite } = useStore();

  useEffect(() => {
    const fetchDetails = async () => {
      if (!id || !type) return;
      try {
        setLoading(true);
        const data = await getDetails(id, type);
        if (data.similar?.results) {
          data.similar.results = data.similar.results.map((item) => ({
            ...item,
            media_type: type as 'movie' | 'tv',
          }));
        }
        setDetails(data);
        
        // If TV, fetch first season data
        if (type === 'tv' && data.seasons && data.seasons.length > 0) {
          const firstSeasonNum = data.seasons[0].season_number || 1;
          setSelectedSeason(firstSeasonNum);
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchDetails();
    window.scrollTo(0, 0);
  }, [id, type]);

  useEffect(() => {
    if (type === 'tv' && id && selectedSeason) {
      const fetchSeason = async () => {
        setLoadingSeason(true);
        try {
          const data = await getSeasonDetails(id, selectedSeason);
          setSeasonData(data);
        } catch (err) {
          console.error(err);
        } finally {
          setLoadingSeason(false);
        }
      };
      fetchSeason();
    }
  }, [id, type, selectedSeason]);

  if (loading) {
    return (
      <div className="min-h-screen pt-24">
        <div className="h-[55vh] shimmer w-full" />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-8 flex gap-8">
          <div className="w-56 aspect-[2/3] shimmer rounded-xl flex-shrink-0" />
          <div className="flex-1 space-y-4 pt-4">
            <div className="h-10 shimmer rounded-lg w-3/4" />
            <div className="h-5 shimmer rounded w-1/2" />
            <div className="h-4 shimmer rounded w-full" />
          </div>
        </div>
      </div>
    );
  }

  if (!details) return null;

  const trailer = details.videos?.results.find(
    (v) => v.type === 'Trailer' && v.site === 'YouTube'
  ) || details.videos?.results.find((v) => v.site === 'YouTube');

  const isFav = isFavorite(details.id);
  const handleFav = () =>
    isFav
      ? removeFavorite(details.id)
      : addFavorite({ ...details, media_type: type as 'movie' | 'tv' });

  const runtime = details.runtime || details.episode_run_time?.[0];

  const handleWatchNow = () => {
    setShowPlayer(true);
  };

  const watchEpisode = (episodeNum: number) => {
    setSelectedEpisode(episodeNum);
    setShowPlayer(true);
  };

  return (
    <div className="min-h-screen pb-24 animate-fadeIn">
      {/* ── Backdrop ────────────────────────────────────────────── */}
      <div className="relative h-[65vh] w-full">
        <img
          src={getImageUrl(details.backdrop_path, 'original')}
          alt={details.title || details.name}
          className="absolute inset-0 w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f0f0f] via-[#0f0f0f]/80 to-transparent" />
        <div className="absolute inset-x-0 bottom-0 h-64 bg-gradient-to-t from-[#0f0f0f] to-transparent" />
      </div>

      {/* ── Poster + Info ────────────────────────────────────────── */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-64 relative z-10">
        <div className="flex flex-col md:flex-row gap-8 lg:gap-12">
          {/* Poster */}
          <div className="flex-shrink-0 mx-auto md:mx-0 w-48 md:w-64 lg:w-72 rounded-2xl overflow-hidden shadow-2xl border border-white/10 group">
            <img
              src={getImageUrl(details.poster_path, 'w500')}
              alt={details.title || details.name}
              className="w-full h-auto group-hover:scale-105 transition-transform duration-500"
            />
          </div>

          {/* Info */}
          <div className="flex-1 flex flex-col justify-end">
            {details.tagline && (
              <p className="text-primary uppercase tracking-widest text-xs font-black mb-2 px-1">
                {details.tagline}
              </p>
            )}

            <h1 className="text-4xl lg:text-7xl font-black text-white mb-6 leading-tight drop-shadow-xl">
              {details.title || details.name}
            </h1>

            {/* Meta badges */}
            <div className="flex flex-wrap items-center gap-3 mb-6">
              <span className="flex items-center gap-1.5 bg-yellow-500/15 text-yellow-400 px-4 py-1.5 rounded-full text-sm font-bold border border-yellow-500/20">
                <Star className="w-4 h-4 fill-current" />
                {details.vote_average.toFixed(1)}
              </span>
              {(details.release_date || details.first_air_date) && (
                <span className="flex items-center gap-1.5 bg-white/5 text-gray-300 px-4 py-1.5 rounded-full text-sm font-medium border border-white/10">
                  <Calendar className="w-4 h-4" />
                  {new Date(details.release_date || details.first_air_date || '').getFullYear()}
                </span>
              )}
              {runtime && (
                <span className="flex items-center gap-1.5 bg-white/5 text-gray-300 px-4 py-1.5 rounded-full text-sm font-medium border border-white/10">
                  <Clock className="w-4 h-4" />
                  {runtime} min
                </span>
              )}
              <span className="bg-primary/20 text-primary px-4 py-1.5 rounded-full text-xs uppercase tracking-widest font-black border border-primary/30">
                {details.status}
              </span>
            </div>

            {/* Overview */}
            <p className="text-base lg:text-lg text-gray-400 leading-relaxed max-w-3xl mb-8 line-clamp-4 hover:line-clamp-none transition-all">
              {details.overview}
            </p>

            {/* Actions */}
            <div className="flex flex-wrap items-center gap-4">
              <button
                onClick={handleWatchNow}
                className="flex items-center gap-2.5 px-10 py-4 bg-primary hover:bg-primary/90 text-white font-black rounded-full transition-all hover:scale-105 shadow-[0_0_32px_rgba(229,9,20,0.5)] cursor-pointer group"
              >
                <Play className="w-6 h-6 fill-current group-hover:scale-110 transition-transform" />
                Stream Now
              </button>

              {trailer && (
                <button
                  onClick={() => setShowTrailer(true)}
                  className="flex items-center gap-2.5 px-8 py-4 bg-white/10 hover:bg-white/20 text-white font-bold rounded-full transition-all border border-white/10 backdrop-blur-md cursor-pointer"
                >
                  <Play className="w-5 h-5" />
                  Trailer
                </button>
              )}

              <button
                onClick={handleFav}
                className={`w-14 h-14 flex items-center justify-center rounded-full border transition-all hover:scale-110 cursor-pointer ${
                  isFav ? 'bg-primary/20 border-primary/50' : 'bg-white/5 border-white/10 hover:bg-white/10'
                }`}
              >
                <Heart className={`w-6 h-6 ${isFav ? 'fill-primary text-primary' : 'text-gray-400'}`} />
              </button>
            </div>
          </div>
        </div>

        {/* ── TV Episodes Component ─────────────────────────────── */}
        {type === 'tv' && details.seasons && (
          <div className="mt-20 animate-fadeIn">
            <div className="flex items-center gap-3 mb-8">
              <List className="w-6 h-6 text-primary" />
              <h2 className="text-2xl font-black text-white">Episodes</h2>
              
              <select 
                value={selectedSeason} 
                onChange={(e) => setSelectedSeason(Number(e.target.value))}
                className="ml-auto bg-surface border border-white/10 text-white px-4 py-2 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50 text-sm font-bold"
              >
                {details.seasons
                  .filter(s => s.season_number > 0)
                  .map(s => (
                    <option key={s.id} value={s.season_number}>
                      Season {s.season_number}
                    </option>
                  ))
                }
              </select>
            </div>

            {loadingSeason ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {[1,2,3,4,5,6].map(i => <div key={i} className="h-40 shimmer rounded-2xl" />)}
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {seasonData?.episodes?.map((ep) => (
                  <button
                    key={ep.id}
                    onClick={() => watchEpisode(ep.episode_number)}
                    className="flex text-left gap-4 p-3 rounded-2xl bg-surface/50 border border-white/5 hover:bg-surface hover:border-primary/30 transition-all group overflow-hidden"
                  >
                    <div className="w-32 aspect-video bg-black/50 rounded-lg overflow-hidden flex-shrink-0 relative">
                      {ep.still_path ? (
                        <img 
                          src={getImageUrl(ep.still_path, 'w300')} 
                          className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500" 
                          alt={ep.name}
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-xs text-gray-600">No Image</div>
                      )}
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                        <Play className="w-6 h-6 text-white fill-current" />
                      </div>
                    </div>
                    <div className="flex flex-col justify-center min-w-0 pr-2">
                       <p className="text-xs font-black text-primary uppercase mb-1">
                         Episode {ep.episode_number}
                       </p>
                       <h3 className="text-sm font-bold text-white truncate mb-1">
                         {ep.name}
                       </h3>
                       <p className="text-[10px] text-gray-500 line-clamp-2 leading-relaxed">
                         {ep.overview || "No description available."}
                       </p>
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── Similar Titles ───────────────────────────────────────── */}
        {details.similar?.results?.length > 0 && (
          <div className="mt-20">
            <div className="flex items-center justify-between mb-8">
              <h2 className="text-2xl font-black text-white flex items-center gap-3">
                <ChevronRight className="w-6 h-6 text-primary" />
                More Like This
              </h2>
            </div>
            <MediaGrid items={details.similar.results.slice(0, 12)} />
          </div>
        )}
      </div>

      {/* ── YouTube Trailer Modal ─────────────────────────────────── */}
      {showTrailer && trailer && (
        <div
          className="fixed inset-0 z-100 flex items-center justify-center bg-black/95 backdrop-blur-md animate-fadeIn p-4 md:p-8"
          onClick={() => setShowTrailer(false)}
        >
          <div
            className="relative w-full max-w-5xl aspect-video rounded-2xl overflow-hidden shadow-2xl border border-white/10"
            onClick={(e) => e.stopPropagation()}
          >
            <iframe
              src={`https://www.youtube.com/embed/${trailer.key}?autoplay=1&rel=0`}
              title={trailer.name}
              allow="autoplay; encrypted-media; fullscreen"
              allowFullScreen
              className="w-full h-full border-none"
            />
            <button
              onClick={() => setShowTrailer(false)}
              className="absolute top-4 right-4 w-10 h-10 flex items-center justify-center rounded-full bg-black/80 hover:bg-black text-white transition-all cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>
      )}

      {/* ── Vidking Player Modal ─────────────────────────────────── */}
      {showPlayer && (
        <Player
          tmdbId={details.id}
          type={type as 'movie' | 'tv'}
          season={selectedSeason}
          episode={selectedEpisode}
          onClose={() => setShowPlayer(false)}
          title={details.title || details.name || ''}
        />
      )}
    </div>
  );
};
