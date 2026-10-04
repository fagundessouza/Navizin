# SPRITE PIPELINE — Navizin

Pipeline de geração de sprites pixel art com ComfyUI local (SDXL).

## Configuração validada
- **Checkpoint:** `pixel-art-xl.safetensors` (SDXL, fp16 no disco).
- **Execução:** `--lowvram --use-split-cross-attention --fp8_e4m3fn-unet --fp32-vae`.
  - UNet em fp8 reduz a VRAM usada pelo modelo para ~2,4 GB.
  - VAE em fp32 evita a decodificação em fp16, que travou a GPU RX 6600 em 1024 px.
- **Resolução de geração:** 768×768 (1024 px travou a GPU na RX 6600; 512 px funciona, mas perde detalhe).
- **Sampler:** `dpmpp_2m`, `karras`, 28 steps, CFG 6.5, seed fixa (42).

## Prompt base
- Positivo: `pixel art, 16-bit retro game sprite, <descrição>, side view, sharp pixel edges, flat colors, solid flat pure green background #00ff00, centered, game asset`
- Negativo: `grid, graph paper, checkered background, lines, blurry, realistic, photo, 3d render, gradient, smooth shading, watermark, text, anti-aliasing, noise, extra limbs, deformed`

## Animação (img2img)
1. Partir de um frame base que já foi aprovado.
2. Trocar o fundo do frame base por verde puro (`#00ff00`) antes do img2img. Sem isso, o fundo cinza se mantém.
3. Gerar N frames com `denoise` entre **0.45 e 0.55** (0.48 foi o ponto de equilíbrio testado: movimento visível sem perder a identidade do navio).
4. Pixelizar cada frame: 768 → 192 → 768 (vizinho mais próximo).
5. Remover o verde por chroma key (G alto, R e B baixos).
6. Recortar uma caixa comum a todos os frames e reduzir para **160×160** com vizinho mais próximo, alinhando a base do navio embaixo.
7. Montar o spritesheet horizontal (`N × 160` de largura, 160 de altura).

## Convenções de arquivo
- Frames finais: `client/assets/sprites/ships/<nome>/<nome>_<n>.png` (160×160, RGBA).
- Spritesheet: `client/assets/sprites/ships/<nome>/<nome>_sheet.png`.
- Nome do navio em minúsculas e sem acento, por exemplo `holandes_voador`.

## Direções (implementado para o Holandês Voador)
- São 7 vistas, geradas e revisadas à mão. A vista "Fundo" foi removida.
- Arquivos finais em `client/assets/sprites/ships/<nome>/dirs/`, todos no mesmo canvas de 176×178 com o pivô no centro: `front`, `back`, `left` (proa à direita), `right` (proa à esquerda), `top` (proa para cima), `top_left` e `top_right` (diagonais de cima).
- A fonte é `<nome>_directions.png`, uma folha 4×2 com rótulos de texto. Os recortes são feitos por caixa de alfa, fora das faixas de rótulo.
- O rumo escolhe a vista (`ship_base.gd`, `SECTORS`): as diagonais de cima usam o mesmo sprite, espelhado nos dois eixos para a outra metade do círculo.
- Nas diagonais de cima, o sprite fica com opacidade 0.5 para o convés não ficar coberto.
