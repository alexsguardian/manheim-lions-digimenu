// @ts-check
import { defineConfig } from 'astro/config';

import mcp from 'astro-mcp';

import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  integrations: [mcp()],

  vite: {
    plugins: [tailwindcss()]
  }
});