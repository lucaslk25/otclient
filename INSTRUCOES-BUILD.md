# Instruções para Buildar o OTClient no Windows

## ✅ Pré-requisitos Instalados

- [x] Visual Studio 2022
- [x] vcpkg (em C:\vcpkg)
- [x] CMake 4.2.3

## 🚀 Como Buildar

### Passo 1: Abrir um NOVO terminal PowerShell
**IMPORTANTE:** Feche o terminal atual e abra um novo para que o CMake seja reconhecido.

### Passo 2: Configurar variável de ambiente (se ainda não fez)
```powershell
$env:VCPKG_ROOT = "C:\vcpkg"
```

### Passo 3: Navegar até o projeto
```powershell
cd "C:\Users\lucas\OneDrive\Documentos\GitHub\otclient"
```

### Passo 4: Executar o script de build
```powershell
.\build-windows.bat
```

## 🔧 Alternativa: Build Manual

Se o script não funcionar, você pode fazer manualmente:

```powershell
# Configurar
cmake --preset windows-release

# Buildar
cmake --build build\windows-release --config RelWithDebInfo -j 4
```

## 🎮 Alternativa: Usar o Visual Studio

1. Abra o Visual Studio 2022
2. File → Open → Folder
3. Selecione a pasta: `C:\Users\lucas\OneDrive\Documentos\GitHub\otclient`
4. Aguarde o CMake configurar automaticamente
5. Selecione o preset "windows-release" no topo
6. Build → Build All (Ctrl+Shift+B)

## ⚠️ Problemas Comuns

### "cmake não é reconhecido"
- Feche e abra um novo terminal
- Ou adicione manualmente ao PATH: `C:\Program Files\CMake\bin`

### "VCPKG_ROOT não definido"
```powershell
[System.Environment]::SetEnvironmentVariable('VCPKG_ROOT', 'C:\vcpkg', 'User')
```
Depois feche e abra um novo terminal.

### Build do abseil falha
Isso acontece por causa dos overlay-ports. O script já limpa o cache automaticamente.

## 📁 Onde encontrar o executável

Após o build bem-sucedido:
```
build\windows-release\src\RelWithDebInfo\otclient.exe
```

## ⏱️ Tempo Estimado

- Primeira vez: 30-60 minutos (baixa e compila todas as dependências)
- Builds subsequentes: 5-10 minutos

## 🆘 Precisa de Ajuda?

Se encontrar erros, copie a mensagem de erro completa e me envie!
