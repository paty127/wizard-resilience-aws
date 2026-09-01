// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  // Origem do CloudFront é o S3 via OAC (API REST), não o website endpoint.
  // Nesse modo o S3 não resolve index.html de subpasta e o CloudFront só trata
  // a raiz (default_root_object). Com format 'file' as páginas viram
  // exemplo.html / dossie.html e funcionam sem tocar na distribuição.
  build: {
    format: 'file',
  },
});
