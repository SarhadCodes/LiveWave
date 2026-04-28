import { useState } from 'react';
import { Tv, Search as SearchIcon, Globe, MapPin } from 'lucide-react';
import { CHANNELS, type Channel } from '../services/channels';
import { ChannelCard } from '../components/ChannelCard';
import { LivePlayer } from '../components/LivePlayer';
import { clsx } from 'clsx';

const CATEGORIES = ['All', 'News', 'Sports', 'Movies', 'Entertainment', 'documentary'];

export const LiveTV = () => {
  const [activeCategory, setActiveCategory] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedChannel, setSelectedChannel] = useState<Channel | null>(null);

  const filteredChannels = CHANNELS.filter(channel => {
    const matchesCategory = activeCategory === 'All' || channel.category.toLowerCase() === activeCategory.toLowerCase();
    const matchesSearch = channel.name.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  return (
    <div className="min-h-screen pb-20 pt-28">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-10">
        
        {/* Header Section */}
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 border-b border-white/5 pb-10">
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-primary/10 rounded-lg">
                <Tv className="w-5 h-5 text-primary" />
              </div>
              <span className="text-primary font-bold tracking-widest uppercase text-[10px]">Worldwide Broadcast</span>
            </div>
            <h1 className="text-4xl md:text-5xl font-black text-white tracking-tight">
              Live TV
            </h1>
            <p className="text-gray-400 max-w-xl text-lg font-medium">
              Watch live channels, news, and sports events from around the world in high definition.
            </p>
          </div>

          <div className="relative group min-w-[280px]">
            <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 transition-colors" />
            <input
              type="text"
              placeholder="Search channels..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="bg-surface border border-white/10 text-white pl-11 pr-4 py-3 rounded-xl w-full focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all"
            />
          </div>
        </div>

        {/* Categories Section */}
        <div className="flex items-center gap-2 overflow-x-auto pb-2 no-scrollbar">
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={clsx(
                'px-5 py-2 rounded-full text-xs font-bold tracking-wide transition-all whitespace-nowrap border cursor-pointer',
                activeCategory === cat
                  ? 'bg-white text-black border-white'
                  : 'bg-white/5 border-white/5 text-gray-400 hover:text-white hover:bg-white/10'
              )}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Stats Section */}
        <div className="flex flex-wrap gap-8 items-center text-gray-500 uppercase text-[10px] font-black tracking-[0.2em]">
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]" />
            <span>2,481 Online</span>
          </div>
          <div className="flex items-center gap-2">
            <Globe className="w-3.5 h-3.5" />
            <span>Global Coverage</span>
          </div>
          <div className="flex items-center gap-2">
            <MapPin className="w-3.5 h-3.5" />
            <span>Multi-Region</span>
          </div>
        </div>

        {/* Grid Section */}
        {filteredChannels.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 animate-fadeIn">
            {filteredChannels.map((channel) => (
              <ChannelCard 
                key={channel.id} 
                channel={channel} 
                onPlay={(c) => setSelectedChannel(c)} 
              />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-24 text-center">
             <div className="w-16 h-16 bg-white/5 rounded-2xl flex items-center justify-center mb-4">
                <SearchIcon className="w-8 h-8 text-gray-700" />
             </div>
             <h3 className="text-xl font-bold text-white mb-1">No channels found</h3>
             <p className="text-gray-500 text-sm mb-6">Try searching for something else or change category.</p>
             <button 
               onClick={() => { setActiveCategory('All'); setSearchQuery(''); }}
               className="text-primary text-xs font-black uppercase tracking-widest hover:underline"
             >
               Reset filters
             </button>
          </div>
        )}
      </div>

      {/* Live Player Modal */}
      {selectedChannel && (
        <LivePlayer 
          url={selectedChannel.url} 
          title={selectedChannel.name} 
          onClose={() => setSelectedChannel(null)} 
        />
      )}
    </div>
  );
};
