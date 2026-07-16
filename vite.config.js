import { cpSync, existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';

function copyRuntimeAssets () {
  return {
    name: 'copy-runtime-assets',
    closeBundle () {
      const outputDirectory = resolve('dist');

      mkdirSync(outputDirectory, { recursive: true });

      for (const directory of ['assets']) {
        const source = resolve(directory);

        if (existsSync(source))
          cpSync(source, resolve(outputDirectory, directory), { recursive: true });
      }
    }
  };
}

export default defineConfig({
  build: {
    // Phaser 3.90 currently fails WebGL framebuffer initialization after
    // Vite's default JavaScript minification pass.
    minify: false,
    sourcemap: true
  },
  plugins: [
    copyRuntimeAssets()
  ],
  server: {
    port: 3000,
    strictPort: true
  },
  preview: {
    port: 3000,
    strictPort: true
  }
});
