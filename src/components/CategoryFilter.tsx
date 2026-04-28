interface Category {
  id: string;
  label: string;
}

const CATEGORIES: Category[] = [
  { id: 'all',        label: 'All'         },
  { id: 'movie',     label: 'Movies'      },
  { id: 'tv',        label: 'TV Shows'    },
  { id: '28',        label: 'Action'      },
  { id: '35',        label: 'Comedy'      },
  { id: '18',        label: 'Drama'       },
  { id: '27',        label: 'Horror'      },
  { id: '10749',     label: 'Romance'     },
  { id: '878',       label: 'Sci-Fi'      },
  { id: '53',        label: 'Thriller'    },
  { id: '16',        label: 'Animation'   },
  { id: '99',        label: 'Documentary' },
];

interface CategoryFilterProps {
  active: string;
  onChange: (id: string) => void;
}

export const CategoryFilter = ({ active, onChange }: CategoryFilterProps) => (
  <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
    {CATEGORIES.map((cat) => (
      <button
        key={cat.id}
        onClick={() => onChange(cat.id)}
        className={`whitespace-nowrap px-5 py-2 rounded-full text-sm font-semibold transition-all duration-200
          ${active === cat.id
            ? 'bg-primary text-white shadow-[0_0_16px_rgba(229,9,20,0.45)]'
            : 'bg-surface text-gray-300 hover:bg-surface-light hover:text-white border border-white/10'
          }`}
      >
        {cat.label}
      </button>
    ))}
  </div>
);
