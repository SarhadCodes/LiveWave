import { Play } from 'lucide-react';
import type { Channel } from '../services/channels';

export const ChannelCard = ({ channel, onPlay }: { channel: Channel; onPlay: (c: Channel) => void }) => {
  return (
    <div
      onClick={() => onPlay(channel)}
      className="group relative rounded-xl overflow-hidden bg-surface shadow-lg transition-all duration-300 hover:scale-105 hover:shadow-[0_8px_32px_rgba(0,0,0,0.6)] hover:z-10 block aspect-video cursor-pointer border border-white/5"
    >
      {/* Logo Container */}
      <div className="absolute inset-0 bg-gradient-to-br from-white/[0.03] to-transparent">
        <img
          src={channel.logo}
          alt={channel.name}
          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
          loading="lazy"
        />
      </div>

      {/* Overlay on hover */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/95 via-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-end p-4">
        <div className="flex items-center justify-between items-end">
          <div className="min-w-0 flex-1">
            <h3 className="text-white font-bold text-sm md:text-base leading-tight mb-1 truncate">
              {channel.name}
            </h3>
            <div className="flex items-center gap-1.5">
              <div className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
              <span className="text-[10px] text-primary font-black uppercase tracking-widest">Live Now</span>
            </div>
          </div>
          
          <div className="w-9 h-9 rounded-full bg-primary flex items-center justify-center shadow-xl transform translate-y-2 group-hover:translate-y-0 transition-transform duration-300">
             <Play className="w-4 h-4 fill-current text-white ml-0.5" />
          </div>
        </div>
      </div>

      {/* Category Badge */}
      <div className="absolute top-2 left-2">
        <span className="text-[9px] uppercase font-bold tracking-widest bg-black/60 backdrop-blur-md text-gray-300 px-2.5 py-1 rounded-lg border border-white/10">
          {channel.category}
        </span>
      </div>
    </div>
  );
};
