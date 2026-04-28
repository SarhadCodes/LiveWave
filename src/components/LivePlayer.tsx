import { X, Maximize, Minimize } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';
import Hls from 'hls.js';

interface LivePlayerProps {
  url: string;
  title: string;
  onClose: () => void;
}

export const LivePlayer = ({ url, title, onClose }: LivePlayerProps) => {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const hlsRef = useRef<Hls | null>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    // Reset state
    setLoading(true);
    setError(null);

    if (Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 60,
        maxBufferLength: 30,
        manifestLoadingTimeOut: 10000,
        manifestLoadingMaxRetry: 3,
        levelLoadingTimeOut: 10000,
        levelLoadingMaxRetry: 3,
        xhrSetup: (xhr: any) => {
          xhr.withCredentials = false;
        }
      });

      hlsRef.current = hls;
      hls.loadSource(url);
      hls.attachMedia(video);

      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        setLoading(false);
        video.play().catch(e => {
          console.warn('Autoplay prevented:', e);
          // If autoplay fails, we still consider it "ready" but might need user click
        });
      });

      hls.on(Hls.Events.ERROR, (_event, data) => {
        if (data.fatal) {
          console.error('Fatal HLS Error:', data);
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              setError('Network error: Failed to fetch stream segments.');
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              setError('Media error: Decoder failed to process content.');
              hls.recoverMediaError();
              break;
            default:
              setError(`Playback error: ${data.details}`);
              hls.destroy();
              break;
          }
          setLoading(false);
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      // Native HLS support (Safari)
      video.src = url;
      video.addEventListener('loadedmetadata', () => {
        setLoading(false);
        video.play();
      });
    } else {
      setError('Your browser does not support HLS playback.');
      setLoading(false);
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy();
      }
    };
  }, [url]);

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/95 backdrop-blur-xl animate-fadeIn p-2 md:p-8 overflow-hidden">
      <div className={`relative w-full transition-all duration-500 ease-in-out bg-black shadow-2xl border border-white/10 flex flex-col items-center justify-center ${
        isFullscreen 
          ? 'fixed inset-0 z-[110] max-w-none h-screen rounded-none border-none' 
          : 'max-w-6xl aspect-video rounded-3xl overflow-hidden'
      }`}>
        
        {/* Header Controls */}
        <div className="absolute top-0 inset-x-0 h-24 bg-gradient-to-b from-black/90 via-black/40 to-transparent flex items-start justify-between px-6 md:px-8 pt-6 z-20 opacity-0 hover:opacity-100 transition-opacity duration-300">
          <div className="min-w-0">
            <div className="flex items-center gap-3 mb-1">
              <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
              <span className="text-primary font-black tracking-widest text-[10px] uppercase shrink-0">Live Broadcast</span>
            </div>
            <h2 className="text-white font-black truncate max-w-[60vw] drop-shadow-xl text-lg md:text-2xl">
              {title}
            </h2>
          </div>
          
          <div className="flex items-center gap-2 md:gap-3 shrink-0">
             <button 
              onClick={() => setIsFullscreen(!isFullscreen)}
              className="p-2.5 md:p-3 bg-white/10 hover:bg-white/20 text-white rounded-full transition-all backdrop-blur-md border border-white/10 cursor-pointer shadow-lg"
              title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}
            >
              {isFullscreen ? <Minimize className="w-5 h-5" /> : <Maximize className="w-5 h-5" />}
            </button>
            <button 
              onClick={onClose}
              className="group flex items-center gap-2 pl-4 md:pl-5 pr-3 md:pr-4 py-2 md:py-2.5 bg-primary hover:bg-primary-dark text-white rounded-full transition-all border border-white/10 shadow-[0_0_20px_rgba(229,9,20,0.4)] cursor-pointer"
              title="Close Player"
            >
              <span className="text-[10px] md:text-xs font-black uppercase tracking-widest hidden sm:inline">Close</span>
              <X className="w-5 h-5 md:w-6 md:h-6 group-hover:rotate-90 transition-transform duration-300" />
            </button>
          </div>
        </div>

        {/* Video Player Container */}
        <div className="w-full h-full relative bg-black flex items-center justify-center group">
          <video
            ref={videoRef}
            className="w-full h-full object-contain"
            controls
            playsInline
            autoPlay
            crossOrigin="anonymous"
          />

          {/* Loading Overlay */}
          {loading && !error && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-background/60 backdrop-blur-md z-10 space-y-4">
              <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin shadow-[0_0_20px_rgba(229,9,20,0.3)]" />
              <p className="text-white/60 font-bold tracking-widest uppercase text-[10px] animate-pulse">Connecting to Stream...</p>
            </div>
          )}

          {/* Error Overlay */}
          {error && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 backdrop-blur-xl z-20 p-8 text-center animate-fadeIn">
              <div className="w-20 h-20 bg-red-500/10 rounded-3xl flex items-center justify-center border border-red-500/20 mb-6">
                <X className="w-10 h-10 text-red-500" />
              </div>
              <div className="space-y-2 mb-8">
                <h3 className="text-2xl font-black text-white uppercase tracking-tight">Playback Failed</h3>
                <p className="text-gray-400 max-w-md font-medium">{error}</p>
              </div>
              <button 
                onClick={onClose} 
                className="px-10 py-4 bg-primary hover:bg-primary-dark text-white font-black rounded-full transition-all shadow-[0_0_32px_rgba(229,9,20,0.4)] hover:scale-105 cursor-pointer uppercase tracking-widest text-xs"
              >
                Go Back
              </button>
            </div>
          )}
        </div>

        {/* Bottom Info Overlay */}
        {!error && !loading && (
          <div className="absolute bottom-6 left-8 z-20 flex items-center gap-4 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
             <div className="flex items-center gap-2 bg-black/60 backdrop-blur-md px-4 py-2 rounded-full border border-white/10 border-l-2 border-l-primary shadow-2xl">
                <span className="text-[10px] font-black text-white uppercase tracking-[0.2em]">HLS ENGINE ACTIVE &bull; 1080P</span>
             </div>
          </div>
        )}
      </div>
    </div>
  );
};
