// @ts-check
import { defineConfig } from 'astro/config';

// Build de produção (AWS S3 + CloudFront) usa a raiz do domínio.
// O preview no GitHub Pages roda em /wizard-resilience-aws/lp/, então o
// workflow de deploy do Pages seta GITHUB_PAGES=true antes do build.
const isGithubPagesPreview = process.env.GITHUB_PAGES === 'true';

// https://astro.build/config
export default defineConfig({
  base: isGithubPagesPreview ? '/wizard-resilience-aws/lp/' : '/',
});
