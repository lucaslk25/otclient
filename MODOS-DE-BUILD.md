# 🎮 Modos de Build - OTClient

## 📊 Diferenças entre os Modos

| Modo | Console | Otimização | Debug Info | Uso |
|------|---------|------------|------------|-----|
| **Debug** | ✅ SIM | ❌ Nenhuma | ✅ Completo | Desenvolvimento |
| **OpenGL** | ❌ NÃO | ✅ Máxima | ⚠️ Mínimo | Produção (OpenGL) |
| **DirectX** | ❌ NÃO | ✅ Máxima | ⚠️ Mínimo | Produção (DirectX) |

## 🔍 O que Mudou?

### Configuração Aplicada:

Adicionei as seguintes configurações ao `otclient.vcxproj`:

#### Debug (Win32 e x64):
```xml
<SubSystem>Console</SubSystem>
```
- ✅ Abre janela de console com logs
- ✅ Mostra mensagens de debug em tempo real
- ✅ Útil para desenvolvimento

#### Release (OpenGL e DirectX):
```xml
<SubSystem>Windows</SubSystem>
<EntryPointSymbol>mainCRTStartup</EntryPointSymbol>
```
- ❌ Sem console
- ✅ Interface limpa para usuário final
- ✅ Menor uso de recursos

## 🚀 Como Usar

### Modo Desenvolvimento (com console):

```cmd
cd C:\otclient
build-debug.bat
```

**Resultado:**
- Executável: `vc18\x64\Debug\otclient_x64-dbg.exe`
- Console aparece automaticamente
- Logs em tempo real: `[INFO]`, `[WARNING]`, `[ERROR]`

### Modo Produção (sem console):

```cmd
cd C:\otclient
build-release.bat
```

**Resultado:**
- Executável: `vc18\x64\OpenGL\otclient_gl_x64.exe`
- Apenas a janela do jogo
- Performance otimizada

## 📝 Logs no Console (Modo Debug)

Quando você roda em modo Debug, verá logs como:

```
[INFO] Loading config file: config.otml
[INFO] Initializing graphics...
[INFO] OpenGL 4.6 detected
[INFO] Loading modules...
[INFO] Module 'client' loaded
[WARNING] Sprite 1234 not found
[ERROR] Failed to connect to server
```

## 🔧 Customizar Logs

Para adicionar seus próprios logs no código C++:

```cpp
#include "framework/core/logger.h"

// Informação
g_logger.info("Minha mensagem");

// Aviso
g_logger.warning("Algo pode estar errado");

// Erro
g_logger.error("Erro crítico!");

// Debug (só aparece em modo Debug)
g_logger.debug("Valor da variável: %d", valor);
```

## 💡 Dicas

### 1. Desenvolvimento Ativo
Use **Debug** durante desenvolvimento:
- Veja erros imediatamente
- Acompanhe o fluxo do programa
- Identifique problemas rapidamente

### 2. Testes de Performance
Use **OpenGL** para testar performance:
- Código otimizado
- FPS real
- Comportamento em produção

### 3. Distribuição
Use **OpenGL** ou **DirectX** para distribuir:
- Experiência limpa para usuários
- Sem informações técnicas expostas
- Melhor performance

## 🐛 Debugging Avançado

### No Visual Studio:

1. Abra `C:\otclient\vc18\otclient.sln`
2. Selecione **Debug | x64**
3. Pressione **F5** para iniciar com debugger
4. Coloque breakpoints (F9) no código
5. Inspecione variáveis em tempo real

### Atalhos Úteis:

- **F5**: Continuar execução
- **F9**: Toggle breakpoint
- **F10**: Step Over (pula função)
- **F11**: Step Into (entra na função)
- **Shift+F5**: Parar debugging

## 📊 Comparação de Tamanho

Exemplo típico:

- **Debug**: ~150 MB (com símbolos de debug)
- **Release**: ~30 MB (otimizado e compactado)

## ⚙️ Configurações Técnicas

### Debug:
- Compilador: `/Od` (sem otimização)
- Runtime: `/MTd` (Multi-threaded Debug)
- Símbolos: `/Z7` (debug info completo)
- SubSystem: **Console**

### Release:
- Compilador: `/O2` (otimização máxima)
- Runtime: `/MT` (Multi-threaded)
- Símbolos: `/Z7` (mínimo)
- SubSystem: **Windows**

## 🎯 Recomendação

**Para você (desenvolvedor):**
- Use **Debug** 90% do tempo
- Use **Release** apenas para testar performance final

**Para distribuir:**
- Sempre use **OpenGL** ou **DirectX**
- Nunca distribua versão Debug
