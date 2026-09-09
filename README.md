# Biblioteca para iPhone

![Plataforma](https://img.shields.io/badge/plataforma-iOS-000000?logo=apple&logoColor=white)
![Versão](https://img.shields.io/badge/versão-1.8.2-blue)
![Distribuição](https://img.shields.io/badge/distribuição-via%20Xcode-lightgrey)

App iOS nativo em SwiftUI para gerenciar sua coleção de livros pessoais. Sincroniza automaticamente via iCloud e usa o framework Vision da Apple para reconhecer capas de livros pela câmera. Compartilha os mesmos dados com o app Android e com o [Biblioteca Web](https://github.com/ruggierow/biblioteca-web).

---

## Pré-requisitos

- Mac com **Xcode 16** ou superior instalado
- iPhone com **iOS 17** ou superior
- Conta Apple ID (gratuita serve para instalar no próprio aparelho)
- iCloud ativado no iPhone (para sincronização)

---

## Instalação via Xcode

O app não está na App Store — ele é instalado diretamente pelo Xcode.

### Passo a passo

1. **Clone o repositório:**
   ```
   git clone https://github.com/ruggierow/biblioteca-ios.git
   cd biblioteca-ios
   ```

2. **Abra o projeto no Xcode:**
   ```
   open Biblioteca-iPhone.xcodeproj
   ```

3. **Conecte seu iPhone** ao Mac via cabo USB (ou use Wi-Fi se já tiver pareado antes).

4. No Xcode, selecione seu iPhone no seletor de destino (barra superior).

5. Em **Signing & Capabilities**, selecione seu Apple ID como Team. O Xcode cria o perfil de provisionamento automaticamente.

6. Pressione **⌘R** (ou clique no botão Play) para compilar e instalar.

7. Na primeira vez, o iPhone pedirá que você confie no desenvolvedor:
   - Acesse *Configurações → Geral → VPN e Gerenciamento de Dispositivo*
   - Toque no seu Apple ID e confirme a confiança.

> O app instalado pelo Xcode gratuito expira em 7 dias. Para reinstalar, repita o passo 6. Seus dados ficam preservados.

---

## Funcionalidades

| Funcionalidade | Descrição |
|---|---|
| Catálogo de livros | Lista todos os seus livros com capa, título e autor |
| Cadastro completo | Título, autor, editora, ano, ISBN, gênero, estante e notas |
| Reconhecimento de capa | Aponte a câmera para a capa do livro — o Vision framework identifica e salva automaticamente |
| Fotos de capa | Capture pela câmera ou escolha da galeria de fotos |
| Busca e filtros | Encontre livros por título, autor, gênero, estante ou por ter foto |
| Sincronização automática | O `biblioteca.txt` e o `biblioteca.dat` ficam no iCloud Drive e sincronizam entre dispositivos sem configuração manual |

---

## Sincronização via iCloud

O app usa o iCloud Drive como backend de sincronização. Os arquivos ficam em:

```
iCloud Drive → Biblioteca → biblioteca.txt
                           biblioteca.dat
```

Você pode acessar esses arquivos pelo app **Arquivos** do iPhone ou pelo **Finder** no Mac (em iCloud Drive). Isso significa que seus dados também ficam acessíveis — e editáveis — pelo [Biblioteca Web](https://github.com/ruggierow/biblioteca-web) no Mac.

### Sincronização de fotos de capa

As fotos ficam no `biblioteca.dat` (formato JSON). Quando o app detecta uma versão mais nova do `.dat` no iCloud, ele faz o merge automaticamente — sem apagar capas cadastradas em outros dispositivos.

---

## Formato dos dados

Os dados são armazenados em formato aberto, compatível com todos os outros apps do sistema:

- **`biblioteca.txt`** — arquivo TSV (valores separados por tabulação) com 8 colunas: `id`, `titulo`, `autor`, `editora`, `ano`, `isbn`, `genero`, `estante` e `notas`.
- **`biblioteca.dat`** — arquivo JSON com as fotos de capa em Base64.

---

## Compatibilidade com outros apps

| App | Plataforma | Repositório |
|---|---|---|
| Biblioteca Web | Mac e Windows | [biblioteca-web](https://github.com/ruggierow/biblioteca-web) |
| Biblioteca Android | Android | [biblioteca-flutter](https://github.com/ruggierow/biblioteca-flutter) |

O app iOS e o Biblioteca Web no Mac leem o mesmo `biblioteca.txt` do iCloud Drive — qualquer livro cadastrado em um aparece no outro automaticamente.
