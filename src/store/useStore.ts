import { create } from 'zustand';;
import { persist } from 'zustand/middleware';;
import type { Media } from '../types';;

interface AppState {
  favorites: Media[];
  addFavorite: (media: Media) => void;
  removeFavorite: (id: number) => void;
  isFavorite: (id: number) => boolean;
}

export const useStore = create<AppState>()(
  persist(
    (set, get) => ({
      favorites: [],
      addFavorite: (media) =>
        set((state) => {
          if (state.favorites.some((f) => f.id === media.id)) {
            return state;
          }
          return { favorites: [...state.favorites, media] };
        }),
      removeFavorite: (id) =>
        set((state) => ({
          favorites: state.favorites.filter((f) => f.id !== id),
        })),
      isFavorite: (id) => get().favorites.some((f) => f.id === id),
    }),
    {
      name: 'cinama-favorites',
    }
  )
);
