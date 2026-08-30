#!/usr/bin/env node
// Gera lp/src/data/units-sp.json a partir da API pública (não documentada) da Wizard
// (wp-json/pearson/v1/units). Roda no deploy, no máximo 1x por dia — ver
// .github/workflows/deploy-pages.yml — pra não sobrecarregar/arriscar bloqueio
// no endpoint deles. Escopo: só unidades de São Paulo (evento é em SP).
//
// Duas passadas:
//   1) Lista completa via `state=SP` (modo "html", sem lat/long, mas cobre 100%
//      das unidades) — vira a base do autocomplete do formulário.
//   2) Um conjunto de pontos-âncora espalhados por SP, consultados no modo
//      lat/long (que devolve JSON estruturado com coordenadas, mas só das
//      unidades "por perto" de cada ponto) — usado pra anexar lat/long a
//      quantas unidades da lista base a gente conseguir casar por slug.
//
// Unidades sem lat/long ficam de fora do cálculo de "mais próxima", mas
// continuam disponíveis no autocomplete por nome/cidade.

import { writeFile, mkdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_PATH = path.join(__dirname, "../public/data/units-sp.json");
const BASE = "https://www.wizard.com.br/wp-json/pearson/v1/units";

// Pontos espalhados pelo estado de SP (capital + polos regionais) pra tentar
// cobrir o máximo de unidades no modo lat/long, que só devolve resultados
// dentro de um raio pequeno por consulta.
const ANCHOR_POINTS = [
  { name: "São Paulo (capital)", lat: -23.5613, lng: -46.6565 },
  { name: "Santos", lat: -23.9608, lng: -46.3339 },
  { name: "Campinas", lat: -22.9099, lng: -47.0626 },
  { name: "Sorocaba", lat: -23.5015, lng: -47.4526 },
  { name: "São José dos Campos", lat: -23.2237, lng: -45.9009 },
  { name: "Ribeirão Preto", lat: -21.1775, lng: -47.8103 },
  { name: "São José do Rio Preto", lat: -20.8113, lng: -49.3758 },
  { name: "Bauru", lat: -22.3246, lng: -49.0871 },
  { name: "Presidente Prudente", lat: -22.1256, lng: -51.3889 },
  { name: "Marília", lat: -22.2171, lng: -49.9455 },
  { name: "Piracicaba", lat: -22.7253, lng: -47.6492 },
  { name: "Franca", lat: -20.5386, lng: -47.4008 },
  { name: "Araraquara", lat: -21.7845, lng: -48.1781 },
  { name: "Jundiaí", lat: -23.1857, lng: -46.8978 },
  { name: "Guarulhos", lat: -23.4628, lng: -46.5333 },
];

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} em ${url}`);
  return res.json();
}

function parseCards(html) {
  return html
    .split('<div class="p-[40px] rounded-[25px] unit-card">')
    .slice(1)
    .map((chunk) => {
      const name = chunk.match(/<h3[^>]*>([^<]+)<\/h3>/)?.[1]?.trim();
      const address = chunk.match(/Endereço<\/h4>\s*<p[^>]*>([^<]+)<\/p>/)?.[1]?.trim();
      const phone = chunk.match(/Whatsapp<\/h4>\s*<p[^>]*>([^<]+)<\/p>/)?.[1]?.trim();
      const slug = chunk.match(/href="https:\/\/www\.wizard\.com\.br\/escolas\/([a-z0-9-]+)"/i)?.[1];
      if (!name || !address) return null;

      const lastComma = address.lastIndexOf(",");
      const cityUf = lastComma >= 0 ? address.slice(lastComma + 1).trim() : "";
      const [city, uf] = cityUf.split(" - ").map((s) => s?.trim());

      return { slug: slug || null, name, address, city: city || null, uf: uf || "SP", phone: phone || null };
    })
    .filter(Boolean);
}

async function fetchAllSPUnitsList() {
  const first = await fetchJSON(`${BASE}?status=ATIVA&state=SP&page=1`);
  const units = parseCards(first.html);
  for (let p = 2; p <= first.pages; p++) {
    const data = await fetchJSON(`${BASE}?status=ATIVA&state=SP&page=${p}`);
    units.push(...parseCards(data.html));
    await new Promise((r) => setTimeout(r, 120));
  }
  return units;
}

async function fetchAnchorUnits(lat, lng) {
  const first = await fetchJSON(`${BASE}?status=ATIVA&state=SP&latitude=${lat}&longitude=${lng}&page=1`);
  const units = [...(first.units || [])];
  for (let p = 2; p <= (first.pages || 1); p++) {
    const data = await fetchJSON(`${BASE}?status=ATIVA&state=SP&latitude=${lat}&longitude=${lng}&page=${p}`);
    units.push(...(data.units || []));
    await new Promise((r) => setTimeout(r, 120));
  }
  return units;
}

async function fetchLatLngBySlug() {
  const bySlug = new Map();
  for (const point of ANCHOR_POINTS) {
    console.log(`  · varrendo perto de ${point.name}...`);
    const units = await fetchAnchorUnits(point.lat, point.lng);
    for (const u of units) {
      if (u.slug && !bySlug.has(u.slug)) {
        bySlug.set(u.slug, { lat: Number(u.latitude), lng: Number(u.longitude) });
      }
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  return bySlug;
}

async function alreadyRefreshedToday() {
  try {
    const raw = await readFile(OUT_PATH, "utf-8");
    const json = JSON.parse(raw);
    return json.generatedAt === new Date().toISOString().slice(0, 10);
  } catch {
    return false;
  }
}

async function main() {
  if (await alreadyRefreshedToday()) {
    console.log("units-sp.json já foi atualizado hoje — pulando chamadas à API da Wizard.");
    return;
  }

  console.log("Buscando lista completa de unidades de SP...");
  const list = await fetchAllSPUnitsList();
  console.log(`  · ${list.length} unidades encontradas (state=SP).`);

  console.log("Varrendo pontos-âncora pra anexar lat/long...");
  const coordsBySlug = await fetchLatLngBySlug();
  console.log(`  · coordenadas encontradas para ${coordsBySlug.size} unidades.`);

  const units = list.map((u) => {
    const coords = u.slug ? coordsBySlug.get(u.slug) : null;
    return { ...u, lat: coords?.lat ?? null, lng: coords?.lng ?? null };
  });

  const withCoords = units.filter((u) => u.lat != null).length;
  console.log(`  · ${withCoords}/${units.length} unidades com coordenadas no arquivo final.`);

  const out = {
    generatedAt: new Date().toISOString().slice(0, 10),
    state: "SP",
    total: units.length,
    units,
  };

  await mkdir(path.dirname(OUT_PATH), { recursive: true });
  await writeFile(OUT_PATH, JSON.stringify(out, null, 2) + "\n", "utf-8");
  console.log(`Gravado em ${OUT_PATH}`);
}

main().catch((err) => {
  console.error("Falha ao atualizar units-sp.json:", err);
  process.exit(1);
});
