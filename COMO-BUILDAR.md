# ✅ Como Buildar o OTClient - CORRIGIDO

## 🔧 Correções Aplicadas

- ✅ PlatformToolset alterado de `v145` para `v143` (Visual Studio 2022)
- ✅ C++ Standard alterado de C++23 para C++20 (melhor suporte no VS 2022)
- ✅ Cache do vcpkg limpo

## 🚀 Como Buildar Agora

### Opção 1: Visual Studio 2022 (MAIS FÁCIL)

1. **Abra o Visual Studio 2022**
2. **File → Open → Project/Solution**
3. Selecione: `C:\otclient\vc18\otclient.sln`
4. No topo, selecione a configuração:
   - **Debug | x64** (para desenvolvimento)
   - **OpenGL | x64** (para release)
5. **Build → Rebuild Solution** (Ctrl+Shift+B)

### Opção 2: Linha de Comando (MSBuild)

```powershell
cd C:\otclient\vc18
msbuild otclient.sln /p:Configuration=Debug /p:Platform=x64 /m
```

## ⏱️ Tempo Estimado

- **Primeira compilação**: 30-60 minutos
  - O vcpkg vai baixar e compilar ~40 dependências
  - Isso é normal!
  
- **Compilações seguintes**: 2-5 minutos

## 📁 Onde Encontrar o Executável

Após o build:
```
C:\otclient\vc18\x64\Debug\otclient_x64-dbg.exe
```
ou
```
C:\otclient\vc18\x64\OpenGL\otclient_gl_x64.exe
```

## ⚠️ Se Der Erro

### Erro: "v145 not found"
- ✅ JÁ CORRIGIDO! Agora usa v143

### Erro: "abseil build failed"
- ✅ JÁ CORRIGIDO! Cache limpo e toolset corrigido

### Erro: "CMake not found"
- Abra o **Visual Studio Installer**
- Modifique a instalação do VS 2022
- Certifique-se que **"C++ CMake tools for Windows"** está instalado

## 🎮 Depois do Build

1. Copie o executável para a raiz do projeto: `C:\otclient\`
2. Execute o jogo!

## 💡 Dicas

- Use **Debug** para desenvolvimento (mais fácil de debugar)
- Use **OpenGL** para distribuição (mais otimizado)
- A primeira compilação é LENTA, mas as seguintes são rápidas
- Se mudar configuração (Debug → Release), o vcpkg pode recompilar algumas libs

## 🆘 Problemas?

Se encontrar erros, copie a mensagem completa e me envie!
