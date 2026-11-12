import Combine
import Foundation

/// O idioma da interface, e o dicionário.
///
/// Mesmo desenho do motor-web (`TEXTOS` + `t()` em biblioteca.html) e do app
/// Android (`lib/models/idioma.dart`): o dicionário mora no código. A chave de
/// preferência é a MESMA das outras duas — `biblioteca-idioma` — para que as
/// três implementações se leiam como uma só.
///
///     t("chave")              texto simples
///     t("chave", [x, y])      troca ${0} e ${1}
///
/// POR QUE NÃO UM STRING CATALOG (.xcstrings), que é o jeito da casa: ele
/// segue o idioma do SISTEMA, e o que o usuário pediu foi um SELETOR dentro do
/// app, que mande mais que o aparelho. Em cima do catálogo isso exigiria
/// trocar o `Bundle` em tempo de execução — mais maquinaria do que o
/// dicionário inteiro, e divergindo das outras duas plataformas.
///
/// O PORTUGUÊS É A LÍNGUA-FONTE, e por isso também o padrão da variável.
/// Duas consequências, de propósito:
///
///   1. chave que falte em `en` cai no `pt` em vez de sumir da tela;
///   2. em teste, que não chama `Idioma.carregar()`, a interface fica em
///      português. Sem isso os testes que já existiam passariam a ler inglês
///      e reprovariam. É o mesmo motivo do `locale: "pt-BR"` em
///      motor-web/testes/playwright.config.js.
let chaveIdiomaPref = "biblioteca-idioma"

private var idiomaGlobal = "pt"

/// Sobreposição POR TAREFA, só para os testes.
///
/// O Swift Testing roda os testes em PARALELO dentro do mesmo processo. Um
/// teste que trocasse a variável global para "en" seria lido pelos outros que
/// estivessem correndo ao mesmo tempo — e foi o que aconteceu: a primeira
/// versão destes testes derrubou 6 testes alheios (`PaisesTests`,
/// `GruposTests`, `FiltroPesquisaTests`) e 2 dos meus. `.serialized` não
/// resolve: ele ordena dentro de UMA suíte, e a contaminação era entre suítes.
///
/// Um valor de tarefa é isolado: vale só dentro do bloco, na tarefa que o
/// abriu, e não vaza para nenhuma outra. Em produção ninguém abre esse bloco,
/// então aqui é sempre `nil` e vale a variável global.
@TaskLocal
private var idiomaDaTarefa: String?

/// O idioma em vigor: `"pt"` ou `"en"`.
var idiomaAtual: String { idiomaDaTarefa ?? idiomaGlobal }

/// A regra da escolha automática: português só quando o aparelho está em
/// português; o resto do mundo vê inglês. Igual ao `/^pt\b/i` do motor-web.
///
/// Recebe o identificador (`"pt-BR"`, `"en-US"`) e compara só a LÍNGUA: a
/// região não importa, e `pt-PT` tem de valer tanto quanto `pt-BR`.
func idiomaDoAparelho(_ identificador: String) -> String {
    let lingua = identificador.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? ""
    return lingua.lowercased() == "pt" ? "pt" : "en"
}

/// O texto da chave no idioma em vigor, com `${0}`, `${1}`… substituídos.
///
/// Chave desconhecida volta como ela mesma, em vez de vazia: um texto faltando
/// tem de APARECER na tela para alguém notar — sumir calado esconderia o
/// defeito. Mesma decisão de `Paises.nome`, que devolve o código ISO.
func t(_ chave: String, _ valores: [CustomStringConvertible] = []) -> String {
    guard let texto = TEXTOS[idiomaAtual]?[chave] ?? TEXTOS["pt"]?[chave] else {
        return chave
    }
    var saida = texto
    for (i, v) in valores.enumerated() {
        saida = saida.replacingOccurrences(of: "${\(i)}", with: v.description)
    }
    // Marcador sem valor sai vazio, nunca como "${2}" na tela.
    saida = saida.replacingOccurrences(of: "\\$\\{[0-9]+\\}", with: "",
                                       options: .regularExpression)
    return saida
}

/// Troca o idioma e redesenha a árvore inteira.
///
/// Vive acima do `ContentView` em Biblioteca_AppApp, e a tela é reconstruída
/// com `.id(idioma.atual)`: trocar o `id` destrói e recria a subárvore, o que
/// alcança TODAS as telas de uma vez. Observar só o objeto não bastaria —
/// uma `View` que não o declara não seria redesenhada.
final class Idioma: ObservableObject {
    @Published private(set) var atual: String = idiomaGlobal

    /// Lê a escolha guardada; na falta dela, segue o idioma do aparelho.
    func carregar() {
        let salvo = UserDefaults.standard.string(forKey: chaveIdiomaPref)
        let novo = (salvo == "pt" || salvo == "en")
            ? salvo!
            : idiomaDoAparelho(Locale.preferredLanguages.first ?? "en")
        if novo != idiomaGlobal {
            idiomaGlobal = novo
            atual = novo
        }
    }

    func trocar(_ novo: String) {
        guard novo == "pt" || novo == "en", novo != idiomaGlobal else { return }
        idiomaGlobal = novo
        atual = novo
        UserDefaults.standard.set(novo, forKey: chaveIdiomaPref)
    }
}

/// Roda o bloco com o idioma pedido, SEM tocar no que vale fora dele.
///
/// É o que os testes usam no lugar de uma troca global — ver `idiomaDaTarefa`
/// acima para o defeito que isso evita.
func comIdiomaNoTeste<R>(_ id: String, _ corpo: () throws -> R) rethrows -> R {
    try $idiomaDaTarefa.withValue(id, operation: corpo)
}

// =====================================================================
// O DICIONÁRIO
// =====================================================================
// Uma entrada por chave, nos dois idiomas, na ordem das telas — a inicial
// primeiro, como quem abre o app.
//
// O texto em português é o que já estava no código, palavra por palavra. O
// inglês foi copiado do motor-web e do app Android onde a mesma ideia já
// tinha tradução, para as três plataformas não dizerem a mesma coisa de três
// jeitos.
let TEXTOS: [String: [String: String]] = [
    "pt": [
        // --- tela inicial ---
        "idiomaDica": "Idioma / Language",
        "subtituloApp": "Cadastro, pesquisa e sincronização da sua base de livros.",
        "livrosCarregados": "${0} livros carregados",
        "escanearLivro": "Escanear livro",
        "menuCadastro": "Cadastro",
        "menuPaises": "Países",
        "menuPesquisa": "Pesquisa",
        "menuSincronizacao": "Sincronização",
        "arquivo": "Arquivo",
        "nenhumArquivoVinculado": "Nenhum arquivo vinculado",
        "selecionado": "Selecionado",
        "livros": "Livros",
        "recarregado": "Recarregado",
        "salvo": "Salvo",
        "caminhoCompleto": "Caminho completo",
        "salvasAutomaticamente": "As alterações são salvas automaticamente no arquivo. Você pode fechar o app com segurança deslizando de baixo para cima.",
        "erro": "Erro",

        // --- cadastro ---
        "editarLivro": "Editar livro",
        "novoLivro": "Novo livro",
        "salvar": "Salvar",
        "cancelar": "Cancelar",
        "buscarPorIsbn": "Buscar por ISBN",
        "digitarIsbn": "Digitar ISBN",
        "isbnDica": "ISBN (10 ou 13 dígitos)",
        "fotoDaCapa": "Foto da capa",
        "dadosDoLivro": "Dados do livro",
        "titulo": "Título",
        "anoDePublicacao": "Ano de publicação",
        "localDoExemplar": "Local do exemplar",
        "autores": "Autor(es)",
        "nomeDoAutor": "Nome do autor",
        "adicionarAutor": "+ Adicionar autor",
        "temasRotulo": "Tema(s)",
        "tema": "Tema",
        "adicionarTema": "+ Adicionar tema",
        "gruposDeLiteratura": "Grupos de literatura",
        "extras": "Extras",
        "emprestado": "Emprestado",
        "comentarios": "Comentários",
        "trocar": "Trocar",
        "remover": "Remover",
        "fotografarCapa": "Fotografar capa",
        "semPais": "— sem país —",
        "foraDaTabela": "${0} (fora da tabela)",
        "pais": "País",
        "preenchidoComSucesso": "Preenchido com sucesso.",
        "isbnNaoEncontrado": "ISBN não encontrado, mas o número foi guardado.",
        "isbnInvalido": "ISBN inválido (deve ter 10 ou 13 dígitos).",
        "erroAoBuscar": "Erro ao buscar. Verifique a internet.",

        // --- câmera da capa ---
        "proporcaoRetrato": "Livro padrão",
        "proporcaoQuadrado": "Arte / catálogo",
        "proporcaoLargo": "Álbum / atlas",
        "enquadreACapa": "Enquadre a capa com uma folga nas bordas",
        "reajustarProporcao": "Reajustar proporção",
        "detectandoBordas": "Detectando bordas…",
        "bordaDetectada": "Borda detectada automaticamente",
        "recortePeloGuia": "Recorte pelo guia",
        "refazer": "Refazer",
        "usarCapa": "Usar capa",

        // --- detalhe do livro ---
        "editar": "Editar",
        "identificacao": "Identificação",
        "ano": "Ano",
        "local": "Local",
        "status": "Status",
        "sim": "Sim",
        "nao": "Não",
        "grupoDeLiteratura": "Grupo de literatura",
        "semFotoDaCapa": "Sem foto da capa",
        "tituloCopiado": "Título copiado — cole na busca do Kindle.",
        "appKindle": "app Kindle",

        // --- filtros ---
        "filtros": "Filtros",
        "limpar": "Limpar",
        "grupo": "Grupo",
        "todosOsLivros": "Todos os livros",
        "qualquerGrupo": "Qualquer grupo",
        "soLivrosComFoto": "Só livros com foto",
        "pronto": "Pronto",
        "statusTodos": "Todos",
        "statusDisponiveis": "Disponíveis",
        "statusEmprestados": "Emprestados",
        "comFoto": "Com foto",

        // --- grupos de literatura ---
        "grupoDeLiteraturaNome": "Grupo de Literatura",
        "grupoNumero": "Grupo ${0}",

        // --- países ---
        "paises": "Países",
        "umLivro": "livro",
        "variosLivros": "livros",
        "umPais": "país",
        "variosPaises": "países",
        "acervoEmPaises": "${0} ${1} em ${2} ${3}",
        "aindaSemPais": " · ${0} ainda sem país",
        "paisVemDoTema": "O país vem do tema do livro ou do ISBN. ",
        "leiaCodigoParaComecar": "Leia o código de barras de um livro para começar.",

        // --- pesquisa ---
        "pesquisa": "Pesquisa",
        "buscarPlaceholder": "Buscar por título, autor, tema, local ou ano",
        "umLivroEncontrado": "1 livro encontrado",
        "variosLivrosEncontrados": "${0} livros encontrados",
        "umLivroContagem": "1 livro",
        "variosLivrosContagem": "${0} livros",
        "carregandoBiblioteca": "Carregando a biblioteca…",
        "nenhumResultado": "Nenhum resultado",
        "nenhumLivroCadastrado": "Nenhum livro cadastrado",

        // --- permissão de câmera e scanner ---
        "permissaoScanner": "Para escanear o código de barras, permita o acesso à câmera nas configurações do dispositivo.",
        "permissaoFoto": "Para fotografar a capa, permita o acesso à câmera nas configurações do dispositivo.",
        "cameraBloqueada": "O acesso à câmera está bloqueado neste dispositivo.",
        "acessoCameraNegado": "Acesso à câmera negado",
        "abrirConfiguracoes": "Abrir Configurações",
        "aponteParaCodigo": "Aponte para o código de barras do livro",
        "cameraNaoDisponivel": "Câmera não disponível",
        "semCameraNoDispositivo": "Este dispositivo não tem câmera (por exemplo, o simulador). Digite o ISBN manualmente.",

        // --- selecionar pasta ---
        "selecionarPasta": "Selecionar pasta",
        "selecionarPastaDica": "Onde o seu biblioteca.txt está — ou vai ficar",
        "achouBiblioteca": "Encontrei uma biblioteca nesta pasta",
        "achouBibliotecaCorpo": "A pasta \"${0}\" já tem um biblioteca.txt com ${1} livro(s).",
        "usarEstaBiblioteca": "Usar esta biblioteca",
        "escolherOutraPasta": "Escolher outra pasta",
        "criouArquivo": "Criei o biblioteca.txt em \"${0}\". Pode começar a cadastrar.",
        "naoConsegueLerTitulo": "Não consegui ler esta biblioteca",
        "naoConsegueLer": "Há um biblioteca.txt nesta pasta, mas não consegui lê-lo: ${0}",
        "pastaVaziaComLivros": "Esta pasta está vazia. O que fazer com os ${0} livros que estão abertos?",
        "comecarVazia": "Criar uma biblioteca nova e vazia",
        "levarParaPasta": "Levar os ${0} para esta pasta",

        // --- sincronização ---
        "sincronizacao": "Sincronização",
        "livrosCarregadosRotulo": "Livros carregados",
        "selecionarPastaBiblioteca": "Selecionar pasta Biblioteca",
        "trocarPasta": "Trocar pasta",
        "recarregarDoICloud": "Recarregar do iCloud",
        "arquivoEFotosRecarregados": "Arquivo e fotos recarregados do iCloud.",
        "gravandoFotos": "Gravando fotos no iCloud…",
        "textoEFotosGravados": "Texto e fotos gravados no iCloud.",
        "gravarNoICloud": "Gravar no iCloud",
        "comoSincronizarComMac": "Como sincronizar com o Mac",
        "passoMac1": "No Mac, coloque o biblioteca.txt no iCloud Drive e abra o app do Mac.",
        "passoMac2": "Aqui no iPhone, toque em Selecionar e escolha a pasta Biblioteca no iCloud Drive (não o arquivo).",
        "passoMac3": "Antes de editar aqui, toque em Recarregar do iCloud se você alterou a base no Mac.",
        "avisoEdicaoSimultanea": "Evite editar no Mac e no iPhone ao mesmo tempo. Como a base é um arquivo compartilhado, pode valer a última gravação.",

        // --- erros do arquivo e das fotos ---
        "erroAoVincularPasta": "Erro ao vincular pasta: ${0}",
        "erroAoCarregar": "Erro ao carregar: ${0}",
        "erroAoSalvar": "Erro ao salvar: ${0}",
        "pastaICloudNaoVinculada": "Pasta do iCloud não vinculada.",
        "urlDatNaoDefinida": "URL do dat não definida.",
        "nenhumaFotoLocal": "Nenhuma foto local para gravar.",
        "erroAoGravarFotos": "Erro ao gravar fotos: ${0}",
        "falhaDesconhecida": "falha desconhecida",
    ],
    "en": [
        // --- tela inicial ---
        "idiomaDica": "Idioma / Language",
        "subtituloApp": "Add, search and sync your book collection.",
        "livrosCarregados": "${0} books loaded",
        "escanearLivro": "Scan a book",
        "menuCadastro": "Add a book",
        "menuPaises": "Countries",
        "menuPesquisa": "Search",
        "menuSincronizacao": "Sync",
        "arquivo": "File",
        "nenhumArquivoVinculado": "No file linked",
        "selecionado": "Selected",
        "livros": "Books",
        "recarregado": "Reloaded",
        "salvo": "Saved",
        "caminhoCompleto": "Full path",
        "salvasAutomaticamente": "Changes are saved to the file automatically. You can close the app safely by swiping up from the bottom.",
        "erro": "Error",

        // --- cadastro ---
        "editarLivro": "Edit book",
        "novoLivro": "New book",
        "salvar": "Save",
        "cancelar": "Cancel",
        "buscarPorIsbn": "Look up by ISBN",
        "digitarIsbn": "Enter ISBN",
        "isbnDica": "ISBN (10 or 13 digits)",
        "fotoDaCapa": "Cover photo",
        "dadosDoLivro": "Book details",
        "titulo": "Title",
        "anoDePublicacao": "Year of publication",
        "localDoExemplar": "Where the copy is",
        "autores": "Author(s)",
        "nomeDoAutor": "Author name",
        "adicionarAutor": "+ Add author",
        "temasRotulo": "Subject(s)",
        "tema": "Subject",
        "adicionarTema": "+ Add subject",
        "gruposDeLiteratura": "Reading groups",
        "extras": "Extras",
        "emprestado": "On loan",
        "comentarios": "Notes",
        "trocar": "Change",
        "remover": "Remove",
        "fotografarCapa": "Photograph the cover",
        "semPais": "— no country —",
        "foraDaTabela": "${0} (not in the table)",
        "pais": "Country",
        "preenchidoComSucesso": "Filled in successfully.",
        "isbnNaoEncontrado": "ISBN not found, but the number was kept.",
        "isbnInvalido": "Invalid ISBN (it must have 10 or 13 digits).",
        "erroAoBuscar": "Lookup failed. Check your internet connection.",

        // --- câmera da capa ---
        "proporcaoRetrato": "Standard book",
        "proporcaoQuadrado": "Art / catalogue",
        "proporcaoLargo": "Album / atlas",
        "enquadreACapa": "Frame the cover leaving a margin at the edges",
        "reajustarProporcao": "Adjust the ratio again",
        "detectandoBordas": "Detecting edges…",
        "bordaDetectada": "Edge detected automatically",
        "recortePeloGuia": "Cropped by the guide",
        "refazer": "Retake",
        "usarCapa": "Use cover",

        // --- detalhe do livro ---
        "editar": "Edit",
        "identificacao": "Identification",
        "ano": "Year",
        "local": "Location",
        "status": "Status",
        "sim": "Yes",
        "nao": "No",
        "grupoDeLiteratura": "Reading group",
        "semFotoDaCapa": "No cover photo",
        "tituloCopiado": "Title copied — paste it into the Kindle search.",
        "appKindle": "Kindle app",

        // --- filtros ---
        "filtros": "Filters",
        "limpar": "Clear",
        "grupo": "Group",
        "todosOsLivros": "All books",
        "qualquerGrupo": "Any group",
        "soLivrosComFoto": "Only books with a photo",
        "pronto": "Done",
        "statusTodos": "All",
        "statusDisponiveis": "Available",
        "statusEmprestados": "On loan",
        "comFoto": "With photo",

        // --- grupos de literatura ---
        "grupoDeLiteraturaNome": "Reading Group",
        "grupoNumero": "Group ${0}",

        // --- países ---
        "paises": "Countries",
        "umLivro": "book",
        "variosLivros": "books",
        "umPais": "country",
        "variosPaises": "countries",
        "acervoEmPaises": "${0} ${1} from ${2} ${3}",
        "aindaSemPais": " · ${0} still without a country",
        "paisVemDoTema": "The country comes from the book's subject or ISBN. ",
        "leiaCodigoParaComecar": "Scan a book's barcode to get started.",

        // --- pesquisa ---
        "pesquisa": "Search",
        "buscarPlaceholder": "Search by title, author, subject, location or year",
        "umLivroEncontrado": "1 book found",
        "variosLivrosEncontrados": "${0} books found",
        "umLivroContagem": "1 book",
        "variosLivrosContagem": "${0} books",
        "carregandoBiblioteca": "Loading the library…",
        "nenhumResultado": "No results",
        "nenhumLivroCadastrado": "No books yet",

        // --- permissão de câmera e scanner ---
        "permissaoScanner": "To scan the barcode, allow camera access in the device settings.",
        "permissaoFoto": "To photograph the cover, allow camera access in the device settings.",
        "cameraBloqueada": "Camera access is blocked on this device.",
        "acessoCameraNegado": "Camera access denied",
        "abrirConfiguracoes": "Open Settings",
        "aponteParaCodigo": "Point at the book's barcode",
        "cameraNaoDisponivel": "Camera unavailable",
        "semCameraNoDispositivo": "This device has no camera (the simulator, for example). Type the ISBN by hand.",

        // --- selecionar pasta ---
        "selecionarPasta": "Choose folder",
        "selecionarPastaDica": "Where your biblioteca.txt is — or will be",
        "achouBiblioteca": "Found a library in this folder",
        "achouBibliotecaCorpo": "The folder \"${0}\" already has a biblioteca.txt with ${1} book(s).",
        "usarEstaBiblioteca": "Use this library",
        "escolherOutraPasta": "Choose another folder",
        "criouArquivo": "Created biblioteca.txt in \"${0}\". You can start adding books.",
        "naoConsegueLerTitulo": "This library could not be read",
        "naoConsegueLer": "There is a biblioteca.txt in this folder, but it could not be read: ${0}",
        "pastaVaziaComLivros": "This folder is empty. What should happen to the ${0} books you have open?",
        "comecarVazia": "Start a new, empty library",
        "levarParaPasta": "Move the ${0} here",

        // --- sincronização ---
        "sincronizacao": "Sync",
        "livrosCarregadosRotulo": "Books loaded",
        "selecionarPastaBiblioteca": "Select the Biblioteca folder",
        "trocarPasta": "Change folder",
        "recarregarDoICloud": "Reload from iCloud",
        "arquivoEFotosRecarregados": "File and photos reloaded from iCloud.",
        "gravandoFotos": "Writing photos to iCloud…",
        "textoEFotosGravados": "Text and photos written to iCloud.",
        "gravarNoICloud": "Write to iCloud",
        "comoSincronizarComMac": "How to sync with the Mac",
        "passoMac1": "On the Mac, put biblioteca.txt in iCloud Drive and open the Mac app.",
        "passoMac2": "Here on the iPhone, tap Select and choose the Biblioteca folder in iCloud Drive (not the file).",
        "passoMac3": "Before editing here, tap Reload from iCloud if you changed the data on the Mac.",
        "avisoEdicaoSimultanea": "Avoid editing on the Mac and on the iPhone at the same time. The data is one shared file, so the last write may win.",

        // --- erros do arquivo e das fotos ---
        "erroAoVincularPasta": "Could not link the folder: ${0}",
        "erroAoCarregar": "Could not load: ${0}",
        "erroAoSalvar": "Could not save: ${0}",
        "pastaICloudNaoVinculada": "The iCloud folder is not linked.",
        "urlDatNaoDefinida": "The .dat URL is not set.",
        "nenhumaFotoLocal": "No local photo to write.",
        "erroAoGravarFotos": "Could not write the photos: ${0}",
        "falhaDesconhecida": "unknown failure",
    ],
]
