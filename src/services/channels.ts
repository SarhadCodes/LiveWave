export interface Channel {
  id: string;
  name: string;
  logo: string;
  url: string;
  category: 'News' | 'Sports' | 'Entertainment' | 'Movies' | 'documentary';
  description?: string;
}

export const CHANNELS: Channel[] = [
  {
    id: 'rudaw',
    name: 'Rudaw TV',
    logo: 'https://photos.smugmug.com/Rudaw-logo/i-7WVWZvk/0/KpP92MzbzGV2SX3ftc2J6RdbjN27V7GGc6hhgG2FZ/L/unnamed-L.png',
    url: 'https://shls-rudaw-live.akamaized.net/out/v1/70868f08effa440cab9e5040ffc5a706/index.m3u8',
    category: 'News',
    description: 'Kurdish news channel based in Erbil.'
  },
  {
    id: 'k24',
    name: 'Kurdistan 24',
    logo: 'https://d2wqffb2bc8st5.cloudfront.net/images/Feb-2024/1708947763k24_logo_default.jpg',
    url: 'https://k24-live.akamaized.net/out/v1/4b901582236d4f409403f7e6f36306c5/index.m3u8',
    category: 'News',
    description: '24-hour news and information channel.'
  },
  {
    id: 'waartv',
    name: 'WAAR TV',
    logo: 'https://waartv.net/wp-content/uploads/2021/04/waar-logo.png',
    url: 'https://waartv-live.akamaized.net/out/v1/9e8b6b0c2e3d4b1a8d0f1e2c3d4b5a6/index.m3u8',
    category: 'Entertainment',
    description: 'Kurdish entertainment channel.'
  },
  {
    id: 'aljazeera',
    name: 'Al Jazeera (English)',
    logo: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Aljazeera_eng.svg/1200px-Aljazeera_eng.svg.png',
    url: 'https://live-hls-web-aje.akamaized.net/out/v1/fce17b54d8934c32bc6e3f60877b5f5e/index.m3u8',
    category: 'News',
    description: 'International news from a Middle Eastern perspective.'
  },
  {
    id: 'trworld',
    name: 'TRT World',
    logo: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/TRT_World_logo.svg/1024px-TRT_World_logo.svg.png',
    url: 'https://tv-trtworld.medyahub.com/index.m3u8',
    category: 'News',
    description: 'Turkish international news channel.'
  },
  {
    id: 'skynews',
    name: 'Sky News',
    logo: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Sky_News_2020.svg/1200px-Sky_News_2020.svg.png',
    url: 'https://skynews-live.akamaized.net/out/v1/6763a890479e49639556942095cc1a9e/index.m3u8',
    category: 'News',
    description: 'UK based 24 hour news channel.'
  }
];
