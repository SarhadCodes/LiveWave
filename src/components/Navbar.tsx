import { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Search, Heart, Film, Menu, X } from 'lucide-react';
import { clsx } from 'clsx';
import { useStore } from '../store/useStore';

export const Navbar = () => {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const favorites = useStore((s) => s.favorites);

  useEffect(() => {
    const handle = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', handle);
    return () => window.removeEventListener('scroll', handle);
  }, []);

  // Close mobile menu on route change
  useEffect(() => setMenuOpen(false), [location.pathname]);

  const isActive = (path: string) => location.pathname === path;

  const links = [
    { path: '/', label: 'Home' },
    { path: '/tv-shows', label: 'TV Shows' },
    { path: '/movies', label: 'Movies' },
    { path: '/live-tv', label: 'Live TV' },
    { path: '/search', label: 'Search', icon: <Search className="w-4 h-4" /> },
    {
      path: '/favorites',
      label: 'Favorites',
      icon: <Heart className="w-4 h-4" />,
      badge: favorites.length,
    },
  ];

  return (
    <>
      <nav
        className={clsx(
          'fixed top-0 inset-x-0 z-50 transition-all duration-300',
          scrolled ? 'bg-[#0f0f0f]/95 backdrop-blur-md border-b border-white/5 shadow-xl' : 'bg-transparent'
        )}
        /* allow electron drag on nav bar background */
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
      >
        <div
          className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-18"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2 group">
            <Film className="w-7 h-7 text-primary group-hover:scale-110 transition-transform" />
            <span className="text-xl font-black tracking-widest text-white">
              CINE<span className="text-primary">MA</span>
            </span>
          </Link>

          {/* Desktop links */}
          <div className="hidden sm:flex items-center gap-1">
            {links.map(({ path, label, icon, badge }) => (
              <Link
                key={path}
                to={path}
                className={clsx(
                  'relative flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all',
                  isActive(path)
                    ? 'text-white bg-white/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                )}
              >
                {icon}
                {label}
                {badge ? (
                  <span className="absolute -top-1 -right-1 w-5 h-5 text-[10px] font-bold flex items-center justify-center rounded-full bg-primary text-white">
                    {badge > 99 ? '99+' : badge}
                  </span>
                ) : null}
              </Link>
            ))}
          </div>

          {/* Mobile menu toggle */}
          <button
            className="sm:hidden p-2 text-gray-300 hover:text-white"
            onClick={() => setMenuOpen((o) => !o)}
          >
            {menuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </nav>

      {/* Mobile dropdown */}
      {menuOpen && (
        <div className="fixed top-18 inset-x-0 z-40 bg-[#0f0f0f]/95 backdrop-blur-md border-b border-white/10 sm:hidden">
          <div className="max-w-7xl mx-auto px-4 py-4 flex flex-col gap-1">
            {links.map(({ path, label, icon, badge }) => (
              <button
                key={path}
                onClick={() => navigate(path)}
                className={clsx(
                  'relative flex items-center gap-3 px-4 py-3 rounded-xl text-left text-sm font-medium transition-all w-full',
                  isActive(path)
                    ? 'text-white bg-white/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                )}
              >
                {icon}
                {label}
                {badge ? (
                  <span className="ml-auto w-5 h-5 text-[10px] font-bold flex items-center justify-center rounded-full bg-primary text-white">
                    {badge}
                  </span>
                ) : null}
              </button>
            ))}
          </div>
        </div>
      )}
    </>
  );
};
