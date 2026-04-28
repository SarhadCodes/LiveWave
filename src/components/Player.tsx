import { X, Maximize, Minimize } from 'lucide-react';
import { useState, useEffect } from 'react';

interface PlayerProps {
  tmdbId: number;
  type: 'movie' | 'tv';
  season?: number;
  episode?: number;
  onClose: () => void;
  title: string;
}

export const Player = ({ tmdbId, type, season = 1, episode = 1, onClose, title }: PlayerProps) => {
  const [isFullscreen, setIsFullscreen] = useState(false);

  const getEmbedUrl = () => {
    if (type === 'movie') {
      return `https://www.vidking.net/embed/movie/${tmdbId}?autoplay=true`;
    }
    return `https://www.vidking.net/embed/tv/${tmdbId}/${season}/${episode}?autoplay=true`;
  };

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-100 flex items-center justify-center bg-black/95 backdrop-blur-md animate-fadeIn p-4 md:p-8 overflow-hidden">
      <div className={`relative w-full transition-all duration-500 ease-in-out bg-black shadow-2xl border border-white/10 flex flex-col items-center justify-center ${
        isFullscreen 
          ? 'fixed inset-0 z-110 max-w-none h-screen rounded-none border-none' 
          : 'max-w-6xl aspect-video rounded-3xl overflow-hidden'
      }`}>
        
        {/* Header Controls */}
        <div className="absolute top-0 inset-x-0 h-20 bg-gradient-to-b from-black/90 to-transparent flex items-start justify-between px-6 pt-4 z-20 pointer-events-none">
          <div className="pointer-events-auto">
            <h2 className="text-white font-black truncate max-w-[60vw] drop-shadow-xl text-lg lg:text-xl">
              {title} {type === 'tv' && <span className="text-primary ml-2 uppercase text-sm">S{season} : E{episode}</span>}
            </h2>
          </div>
          
          <div className="flex items-center gap-3 pointer-events-auto">
            <button 
              onClick={() => setIsFullscreen(!isFullscreen)}
              className="p-3 bg-black/40 hover:bg-black/60 text-white/80 hover:text-white rounded-full transition-all backdrop-blur-md border border-white/10 cursor-pointer shadow-lg"
              title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}
            >
              {isFullscreen ? <Minimize className="w-5 h-5" /> : <Maximize className="w-5 h-5" />}
            </button>
            
            <button 
              onClick={onClose}
              className="group flex items-center gap-2 pl-4 pr-3 py-2 bg-primary hover:bg-primary-dark text-white rounded-full transition-all border border-white/10 shadow-[0_0_20px_rgba(229,9,20,0.4)] cursor-pointer"
              title="Close Player"
            >
              <span className="text-sm font-black uppercase tracking-widest hidden sm:inline">Close</span>
              <X className="w-6 h-6 group-hover:rotate-90 transition-transform duration-300" />
            </button>
          </div>
        </div>

        {/* Iframe */}
        <iframe
          src={getEmbedUrl()}
          className="w-full h-full border-none shadow-2xl"
          allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
          allowFullScreen
          referrerPolicy="no-referrer"
          loading="lazy"
          title={title}
        />

        {/* Watermark/Brand Info (Optional) */}
        {!isFullscreen && (
          <div className="absolute bottom-4 left-4 text-white/30 text-[10px] pointer-events-none">
            Powered by Vidking Player
          </div>
        )}
      </div>
    </div>
  );
};
