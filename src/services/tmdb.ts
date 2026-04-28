import axios from 'axios';
import type { Media, MediaDetails, Season } from '../types';

const API_KEY = import.meta.env.VITE_TMDB_API_KEY;
const BASE_URL = 'https://api.themoviedb.org/3';

const tmdbApi = axios.create({
  baseURL: BASE_URL,
  params: { 
    api_key: API_KEY,
    include_adult: false,
    language: 'en-US'
  },
});

// ─── Trending ───────────────────────────────────────────────────────────────
export const getTrending = async (): Promise<Media[]> => {
  const res = await tmdbApi.get('/trending/all/week');
  return res.data.results;
};

// ─── Search ─────────────────────────────────────────────────────────────────
export const searchMedia = async (query: string): Promise<Media[]> => {
  if (!query) return [];
  const res = await tmdbApi.get('/search/multi', { params: { query } });
  return res.data.results.filter(
    (item: Media) => item.media_type === 'movie' || item.media_type === 'tv'
  );
};

// ─── Details (with videos appended) ─────────────────────────────────────────
export const getDetails = async (
  id: string | number,
  type: string
): Promise<MediaDetails> => {
  const res = await tmdbApi.get(`/${type}/${id}`, {
    params: { append_to_response: 'videos,similar' },
  });
  return res.data;
};

// ─── Discover by genre ───────────────────────────────────────────────────────
export const discoverByGenre = async (
  genreId: string,
  mediaType: 'movie' | 'tv' = 'movie',
  page = 1
): Promise<{ results: Media[]; total_pages: number }> => {
  const res = await tmdbApi.get(`/discover/${mediaType}`, {
    params: { with_genres: genreId, page, sort_by: 'popularity.desc' },
  });
  return res.data;
};

// ─── Discover movies (no genre filter) ──────────────────────────────────────
export const discoverMovies = async (page = 1): Promise<{ results: Media[]; total_pages: number }> => {
  const res = await tmdbApi.get('/discover/movie', {
    params: { page, sort_by: 'popularity.desc' },
  });
  const results = res.data.results.map((item: Media) => ({
    ...item,
    media_type: 'movie',
  }));
  return { results, total_pages: res.data.total_pages };
};

// ─── Discover TV shows ───────────────────────────────────────────────────────
export const discoverTV = async (page = 1): Promise<{ results: Media[]; total_pages: number }> => {
  const res = await tmdbApi.get('/discover/tv', {
    params: { page, sort_by: 'popularity.desc' },
  });
  const results = res.data.results.map((item: Media) => ({
    ...item,
    media_type: 'tv',
  }));
  return { results, total_pages: res.data.total_pages };
};

// ─── TV Season Details ───────────────────────────────────────────────────────
export const getSeasonDetails = async (
  tvId: string | number,
  seasonNumber: number
): Promise<Season> => {
  const res = await tmdbApi.get(`/tv/${tvId}/season/${seasonNumber}`);
  return res.data;
};

// ─── Image helper ────────────────────────────────────────────────────────────
export const getImageUrl = (
  path: string | null | undefined,
  size: 'w200' | 'w300' | 'w500' | 'w780' | 'original' = 'original'
): string => {
  if (!path) return `https://placehold.co/500x750/1a1a1a/555?text=No+Image`;
  return `https://image.tmdb.org/t/p/${size}${path}`;
};
