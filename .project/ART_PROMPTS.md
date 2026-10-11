# ART PROMPTS — Meshy AI (ilhas, portos, props)

Prompts prontos pra colar no Meshy AI. Pipeline separado do `SPRITE_PIPELINE.md`
(que é o ComfyUI/SDXL local pros navios) — este aqui é o gerador usado pra tudo
que já chegou em `~/Downloads/Meshy_AI_*` neste projeto (ilhas, kit de
construções do porto, props náuticos, decalques de costa).

## Regra técnica que não pode faltar
Toda prancha de referência (tileset/kit) precisa ter cada peça **isolada sobre
fundo preto puro (#000000), sem sobreposição, com espaçamento limpo**. É assim
que as pranchas anteriores (`port_buildings_kit`, `nautical_props_kit`,
`pack_d_shoreline_decals`) saíram, e é o que permite recortar cada peça
automaticamente depois (extrator por componentes conectados, documentado no
checkpoint de 2026-10-09 do `STATE.md`). Uma prancha com fundo gradiente, textura
ou peças encostando uma na outra não dá pra recortar sem photoshop manual.

---

## Prompt A — Cenário base da cidade (fundo panorâmico de Tortuga)
Substitui `tortuga_hub.png` atual, que tem prédios pintados direto na
ilustração (bom pra ilha vista de longe no mar, ruim pra cena de cidade
jogável: não dá pra posicionar hotspots/prédios modulares livremente por cima
sem colidir com o que já está pintado).

```
Dark fantasy grimdark pirate port, panoramic 2D pixel art background, 16/32-bit
retro game style inspired by Diablo 2 and Path of Exile environment art.
Isometric 2:1 perspective, matching camera angle looking down at roughly 30-45
degrees.

Composition: 70% of the frame is solid ground -- a wide wooden pier in the
foreground leading into a dark cobblestone plaza in the midground, worn gothic
stone, scattered debris, torch-lit mooring posts along the edges. The remaining
30% is sea and sky in the background only: calm dark water, a full moon low on
the horizon, two or three distant ship silhouettes, faint fog.

Critical constraint: NO buildings, NO structures, NO shops in the composition.
Empty plaza and open pier only -- this is a bare stage so buildings and
interactive hotspots can be placed on top afterward in the game engine. Do not
paint any taverns, towers, stalls or walls into the scene.

Mood: gothic, weathered, lantern-lit warm oranges against cold blue-black
shadows, slight fog haze, grimdark pirate atmosphere, no characters, no UI, no
text, no watermark. Single cohesive scene, not a grid of separate tiles.
```

## Prompt B — Tileset de penhasco e costa (Coastline & Cliff Sheet)
Pros penhascos que vão cercar a ilha nova (ver diretiva de arquitetura do
checkpoint de 2026-10-09: massa de terra ampla com baía em C/U, navegável por
fora, usando `TileMapLayer_Islands`).

```
AAA-grade isometric tileset production sheet, gothic dark fantasy pixel art,
16/32-bit, same style as Diablo 4 environment kits. Every piece isolated and
fully separated on a pure solid black background (#000000), zero overlap
between pieces, generous clean spacing, small text label under each piece
naming it. Top-down/isometric hybrid, 2:1 tile ratio.

Include these groups, clearly separated on the sheet:
1) GROUND / TOP TILES: dark gothic stone slabs and weathered cobblestone,
   several variants, flat top faces only, seamlessly tileable.
2) CLIFF WALL TILES: tall dark rock cliff faces, vertical, repeatable
   top-to-bottom and side-to-side, jagged gothic silhouette, some with patches
   of dark moss.
3) TRANSITION & CORNER TILES: inner corners, outer corners, and water/beach
   edge transitions where cliff or ground meets the sea, with foam/surf detail
   at the waterline.
4) PROPS (isolated, standalone, one per label): a tall gothic lighthouse with
   lit torches and mounted skulls near the top; a wooden pier/dock module;
   hanging iron chains; wrought-iron lanterns on posts.

Mood: dark maritime, weathered stone, warm torchlight against cold shadows,
no characters, no text except the small item labels, no watermark, no gradient
background -- background must stay pure flat black everywhere outside the
pieces themselves.
```

---

## Depois de gerar
1. Salvar os PNGs em `~/Downloads/` (convenção já usada: `Meshy_AI_<nome>.png`).
2. Avisar a próxima sessão -- ela confere, importa pro projeto (mesma extração
   automática por componentes conectados usada pra `tortuga_kit`), e segue a
   diretiva de arquitetura (`TileMapLayer_Islands`, baía em C/U, farol na ponta
   da baía) documentada no `STATE.md`.
