import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Navbar } from './components/Navbar';
import { Home } from './pages/Home';
import { Movies } from './pages/Movies';
import { TVShows } from './pages/TVShows';
import { Search } from './pages/Search';
import { Details } from './pages/Details';
import { Favorites } from './pages/Favorites';
import { LiveTV } from './pages/LiveTV';

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-background">
        <Navbar />
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/movies" element={<Movies />} />
            <Route path="/tv-shows" element={<TVShows />} />
            <Route path="/search" element={<Search />} />
            <Route path="/details/:type/:id" element={<Details />} />
            <Route path="/favorites" element={<Favorites />} />
            <Route path="/live-tv" element={<LiveTV />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
