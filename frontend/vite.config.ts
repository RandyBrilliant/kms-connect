import path from "path"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 3000,
  },
  preview: {
    port: 3001,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    // Target modern browsers for smaller bundles
    target: 'es2020',
    // Output directory
    outDir: 'dist',
    // Generate sourcemaps for production debugging (disable in production if needed)
    sourcemap: false,
    // Chunk size warning limit (500 KB)
    chunkSizeWarningLimit: 500,
    // Enable CSS code splitting
    cssCodeSplit: true,
    // Minification options
    minify: 'esbuild',
    // Rollup options for advanced bundling
    rollupOptions: {
      output: {
        // Manual chunk splitting for better caching
        manualChunks: (id) => {
          // Vendor chunk: node_modules dependencies
          if (id.includes('node_modules')) {
            // React ecosystem - be very specific to avoid breaking dependencies
            if (
              id.includes('/node_modules/react/') ||
              id.includes('/node_modules/react-dom/') ||
              id.includes('/node_modules/react-router-dom/') ||
              id.includes('/node_modules/react-router/') ||
              id.includes('/node_modules/scheduler/')
            ) {
              return 'react-vendor'
            }
            // TanStack ecosystem (Query, Table, Form)
            if (id.includes('@tanstack')) {
              return 'tanstack-vendor'
            }
            // UI libraries
            if (id.includes('@tabler/icons') || id.includes('lucide-react')) {
              return 'icons-vendor'
            }
            // Charts library
            if (id.includes('recharts') || id.includes('d3-')) {
              return 'charts-vendor'
            }
            // Form & validation
            if (id.includes('zod') || id.includes('@dnd-kit')) {
              return 'utils-vendor'
            }
            // Everything else from node_modules
            return 'vendor'
          }
          // API layer
          if (id.includes('/src/api/')) {
            return 'api'
          }
          // Component chunks
          if (id.includes('/src/components/ui/')) {
            return 'ui-components'
          }
        },
        // Naming pattern for chunks
        chunkFileNames: 'assets/js/[name]-[hash].js',
        entryFileNames: 'assets/js/[name]-[hash].js',
        assetFileNames: (assetInfo) => {
          // Organize assets by type
          const info = assetInfo.name || ''
          if (/\.(png|jpe?g|gif|svg|webp|avif)$/i.test(info)) {
            return 'assets/images/[name]-[hash][extname]'
          }
          if (/\.(woff2?|eot|ttf|otf)$/i.test(info)) {
            return 'assets/fonts/[name]-[hash][extname]'
          }
          if (/\.css$/i.test(info)) {
            return 'assets/css/[name]-[hash][extname]'
          }
          return 'assets/[name]-[hash][extname]'
        },
      },
      // External dependencies (if needed for CDN)
      // external: [],
    },
    // Reduce package size by removing unnecessary code
    reportCompressedSize: true,
    // Optimize dependencies
    commonjsOptions: {
      include: [/node_modules/],
      transformMixedEsModules: true,
    },
  },
  // Optimize dependency pre-bundling
  optimizeDeps: {
    include: [
      'react',
      'react-dom',
      'react-router-dom',
      '@tanstack/react-query',
      '@tanstack/react-table',
      'axios',
      'zod',
      'date-fns',
    ],
    exclude: ['@tabler/icons-react'],
  },
})
