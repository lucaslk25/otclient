# Gerador de fontes bitmap (GIMP)

Script para o GIMP que gera fontes bitmap no formato OTClient (`.otfont` + `.png`).

## Uso no GIMP

1. Abra o GIMP.
2. Menu **File → Create → Generate OTC font**.
3. Parâmetros:
   - **Font:** Nome da fonte no sistema (ex.: "Verdana Bold", "Arial").
   - **Font size:** Tamanho em pixels (ex.: 8, 9, 11).
   - **Border size:** **0** = sem borda/stroke (recomendado para UI limpa). > 0 = contorno ao redor dos glifos.
   - **Antialias:** False para estilo pixelado (Tibia-like); True para suavizado.
   - **Output directory:** Pasta de saída, ex.: `data/fonts/otfont` (caminho absoluto ou relativo ao projeto).

## Convenção de nomes

- **Sem borda (Border = 0):** Saída `FontName-Sizepx` (ex.: `Verdana Bold-8px.otfont` e `.png`).
- **Com borda:** Sufixo `-bordered` (ex.: `Verdana Bold-8px-bordered`).
- **Com antialias:** Sufixo `-antialiased`.

Os arquivos gerados devem ser colocados em `data/fonts/otfont/` para o cliente carregá-los. O `.otfont` referencia a textura pelo mesmo nome (ex.: `texture: Verdana Bold-8px` → o cliente busca `Verdana Bold-8px.png` na mesma pasta ou em caminhos de recursos).

## Gerar fonte sem stroke (reutilizável)

Para qualquer fonte sem contorno preto:

1. **Border size = 0** (obrigatório).
2. Output folder = pasta `data/fonts/otfont` do projeto.
3. Após gerar, o `.otfont` já inclui `spacing: 0 0` para alinhar com outras fontes do projeto.

Para variantes com nome customizado (ex.: `verdana-8px-nostroke`), após gerar renomeie os arquivos e edite o `.otfont` (linhas `name:` e `texture:`) para o novo nome.

## Gerador standalone (sem GIMP)

O projeto inclui um script Python que gera fontes bitmap **sem borda** sem precisar do GIMP:

- **Script:** [tools/bitmap_font_generator.py](../bitmap_font_generator.py)
- **Dependência:** Pillow (`pip install -r requirements-tools.txt` na raiz do projeto)
- **Exemplo (fonte 8px sem stroke):**
  ```bash
  python tools/bitmap_font_generator.py "caminho/para/Verdana Bold.ttf" 8 --output-name "verdana-8px-nostroke" --output-dir data/fonts/otfont
  ```
- Os arquivos `.otfont` e `.png` são criados em `data/fonts/otfont/`. Use em OTUI: `font: verdana-8px-nostroke`.

Reutilizável para outros tamanhos (9, 10, 11...) ou outros nomes alterando `size` e `--output-name`.

**Primeira vez (fonte 8px sem stroke):** Os OTUI do cliente já usam `font: verdana-8px-nostroke`. Para criar os arquivos, execute uma vez (a partir da raiz do projeto, com Pillow instalado):

```bash
pip install -r requirements-tools.txt
python tools/bitmap_font_generator.py "C:\Windows\Fonts\verdanab.ttf" 8 --output-name "verdana-8px-nostroke" --output-dir "data/fonts/otfont"
```

(No Linux/macOS use o caminho do Verdana Bold no sistema, ex.: `/usr/share/fonts/truetype/msttcorefonts/Verdana_Bold.ttf`.)

