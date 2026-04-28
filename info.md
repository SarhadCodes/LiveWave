# 🎬 CINEMA App - Manual Creation Guide

Follow these steps to recreate this project from scratch in a new folder.

## 🚀 Step 1: Initialize the Project
Create a new folder for your project, open it in your terminal, and run:
```bash
npx -y create-vite@latest ./ --template react-ts
```

## 📦 Step 2: Install Dependencies
Run these commands to install everything the app needs to function.

### 1. Core App Dependencies
```bash
npm install axios zustand react-router-dom lucide-react clsx tailwind-merge
```

### 2. Development & Electron Dependencies
```bash
npm install -D electron electron-builder concurrently wait-on cross-env tailwindcss postcss autoprefixer
```

### 3. Tailwind CSS Vite Plugin
```bash
npm install -D @tailwindcss/vite@latest
```

## ⚙️ Step 3: Configure `package.json`
Open your `package.json` and update it with these settings to support Electron:

1. Add `"main": "electron/main.cjs"` (usually after "version").
2. Add `"productName": "Cinema"`.
3. Update the `"scripts"` section:
```json
"scripts": {
  "dev": "vite",
  "electron": "wait-on tcp:5173 && cross-env NODE_ENV=development electron .",
  "desktop": "concurrently \"npm run dev\" \"npm run electron\"",
  "build:web": "tsc -b && vite build",
  "build": "npm run build:web && electron-builder",
  "build:win": "npm run build:web && electron-builder --win",
  "lint": "eslint .",
  "preview": "vite preview"
}
```

## 📂 Step 4: Create Folder Structure
Create these folders manually if they don't exist:
- `electron/` (for `main.cjs` and `preload.cjs`)
- `src/components/`
- `src/pages/`
- `src/services/`
- `src/store/`
- `src/types/`
- `public/`

## 🎨 Step 5: Configure Tailwind CSS
1. Update `vite.config.ts`:
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
})
```
2. In `src/index.css`, delete everything and keep only:
```css
@import "tailwindcss";
```

## 🎥 Step 6: Streaming Engine (Vidking)
The app uses the **Vidking Player** for streaming. Here are the URL patterns you'll use in your code:
- **Movies:** `https://www.vidking.net/embed/movie/{id}`
- **TV Shows:** `https://www.vidking.net/embed/tv/{id}/{season}/{episode}`

## 💻 Running the App
- **Development Mode:** `npm run desktop`
- **Build Installer:** `npm run build`

