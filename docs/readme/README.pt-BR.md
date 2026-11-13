<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · **Português (Brasil)** · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

**Um fork do 7-Zip mais amigável para quem usa o Windows 11 hoje: menu do botão direito no primeiro nível, compactação zstd e tar.zst em uma única passada.**

[Download](https://github.com/7zStar/7-ZSTar/releases/latest) · [Site](https://www.7zstar.com/pt-br/) · [Histórico de alterações](../../CHANGELOG.md)

## Por que o 7-ZSTar

- **Pule o “Mostrar mais opções”.** Com o MSI para todos os usuários, o 7-ZSTar aparece no primeiro nível do menu do botão direito do Windows 11.
- **Uma passada. Nenhum .tar no disco.** Compactar para tar.zst e extrair um tar.zst são, cada um, uma única etapa, e nenhum .tar é gravado em nenhum dos sentidos. O 7-Zip oficial não cria .tar.zst e extrai um em duas etapas, passando por um .tar.
- **10× mais rápido que o 7z.** Em pastas de projeto reais, o tar.zst compactou de 10 a 18 vezes mais rápido que o 7z.

## Velocidade

| Pasta | Arquivos | Tamanho original | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13.371 | 207 MB | 4,1 s / 76,7 MB | 38,4 s / 51,8 MB | **3,8 s** / 59,7 MB |
| Python `.venv` | 9.795 | 346 MB | 6,6 s / 107,8 MB | 54,8 s / 65,7 MB | **3,6 s** / 83,4 MB |
| Python `.venv` (binários grandes) | 11.654 | 671 MB | 25,5 s / 249,5 MB | 100,8 s / 167,2 MB | **5,6 s** / 210,9 MB |

O tar.zst ficou entre 15% e 23% menor que o zip, sem ser mais lento. Em relação ao 7z, porém, ele é entre 15% e 27% maior; então, se o menor tamanho possível é o que mais importa, o 7z continua sendo a melhor escolha. Esses números são de compactação; na extração, os três levaram praticamente o mesmo tempo.

zip, 7z e tar.zst, todos com as configurações padrão. 7-ZSTar 26.05.1 x64 (7z.exe), uma máquina (Intel Core Ultra 7 155H, SSD NVMe), três pastas de projeto reais, mediana de 3 execuções, 2026-11.

## Formatos

- **Compactação em uma etapa (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extração em uma etapa (10):** esses 8, mais tar.lzma e tar.Z
- **Codecs adicionados:** zstd, brotli, lz4, lz5 e lizard, cada um como formato independente e como método dentro do .7z; além do fast-lzma2 como codificador LZMA2 alternativo.
- Todos os formatos que o 7-Zip já suporta continuam aqui.

Extrair tar.br, tar.lz4, tar.lz5, tar.liz ou tar.Z continua sendo uma única etapa para você, mas o 7-ZSTar primeiro decodifica para um arquivo intermediário e o apaga em seguida.

## Linha de comando

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

No PowerShell, coloque a opção de formato entre aspas, como em `7z a "-ttar.zst" backup.tar.zst docs`. Sem elas, o PowerShell divide `-ttar.zst` em dois e o 7z cria um arquivo chamado `.zst`. O Prompt de Comando (cmd) não precisa de aspas.

## Download e instalação

| | Todos os usuários `.msi` | Só você `-user.msi` | Portátil `.zip` |
|---|---|---|---|
| Instala para | Todas as contas do PC | A conta atual | Não precisa instalar |
| Exige privilégios de administrador | Sim | Não | Não |
| Menu do botão direito | Windows 11: primeiro nível | Em “Mostrar mais opções” | Nenhum |
| Atalho no menu Iniciar | Sim | Sim | Não |

Cada um vem em x64, x86 e arm64; escolha o que corresponde ao seu Windows: no Windows de 64 bits, os pacotes x86 podem ficar sem o menu do botão direito. Os builds arm64 ainda não foram executados em hardware real. O 7-ZSTar se instala ao lado do 7-Zip oficial, e um não afeta o outro.

**O Windows pode exibir um aviso nesses downloads.** Os instaladores e programas não são assinados por uma autoridade certificadora, então o Microsoft Defender SmartScreen pode bloqueá-los com um aviso na primeira vez que você executar um, e em um PC com Windows 11 com o Smart App Control ativado os instaladores `.msi` são bloqueados de vez, sem opção de continuar. Isso não quer dizer que o arquivo seja ruim: cada release acompanha um arquivo `SHA256SUMS`, e com ele você pode conferir se o seu download é igual ao que foi publicado. Como conferir, o que o Smart App Control significa para você e como seguir em frente depois que tudo bater está em [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**Sobre o menu do primeiro nível:** o Windows 11 só deixa chegar ao primeiro nível os programas com identidade de pacote; por isso o MSI para todos os usuários instala um pequeno pacote MSIX assinado com um certificado autoassinado e passa a confiar nesse certificado. A desinstalação remove os dois. Se você prefere não confiar nele, instale com `msiexec /i 7-ZSTar-<versão>-<arquitetura>.msi SPARSE=0` e o menu continua em “Mostrar mais opções”. O pacote é registrado apenas para a conta que executa o instalador; as outras contas o registram separadamente.

Os detalhes completos, incluindo associações de arquivos e desinstalação, estão em [docs/INSTALL.md](../INSTALL.md) (por enquanto só em inglês).

## Limitações conhecidas

- **Desmarcar a caixa de integração com o shell remove o registro do menu do botão direito.** No gerenciador de arquivos (`7zFM`), em **Ferramentas > Opções > 7-ZSTar** há uma caixa chamada “Integrar o 7-ZSTar ao menu de contexto do shell”. Como no 7-Zip oficial, desmarcá-la apaga o registro da extensão de shell (a chave `CLSID`) que o instalador criou, e o item do 7-ZSTar some do menu do botão direito. Com o pacote para todos os usuários, você pode marcar a caixa de novo se o gerenciador de arquivos estiver sendo executado como administrador. Com o pacote por usuário, não dá: marcar de novo mostra “Acesso negado” e o item continua ausente. Para recuperá-lo, execute de novo o `.msi` original e escolha *Reparar*.
- **O menu do primeiro nível só é registrado quando a instalação roda em uma sessão interativa, com um usuário conectado.** Instalar o `.msi` para todos os usuários a partir de uma sessão remota ou não interativa (por SSH, ou em uma implantação silenciosa feita por uma ferramenta de gerenciamento) ainda informa sucesso, mas o pacote do Windows 11 não é registrado, então só aparece o menu clássico em “Mostrar mais opções”. Os detalhes estão em [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu).

## Requisitos do sistema

Windows 7 ou Windows Server 2008 R2 e posteriores (x64, x86); no arm64, Windows 10 e posteriores. Não é preciso instalar mais nada. Esse é o requisito mínimo imposto pelos pacotes; versões anteriores ao Windows 11 não foram testadas. Para Linux há uma versão de linha de comando que você mesmo compila; o macOS não é suportado.

## Sobre este projeto

O 7-ZSTar é um fork do 7-Zip mais amigável para quem usa o Windows 11 hoje. O núcleo do 7-Zip é excelente, mas algumas partes não acompanharam a forma como as pessoas trabalham agora: o Windows 11 o esconde em “Mostrar mais opções”, e ele também não compacta em zstd. O 7-ZSTar preenche essas lacunas e deixa todo o resto como você já conhece.

## Documentação

Todo pacote inclui o `7-zip.chm`, o arquivo de ajuda do 7-Zip oficial, sem modificações: **Ajuda > Conteúdo** e F1 o abrem. Ele diz “7-Zip” do começo ao fim e não cobre o que o 7-ZSTar acrescenta; para isso, veja esta página e o [CHANGELOG.md](../../CHANGELOG.md).

Se o arquivo de ajuda não estiver ao lado do executável, essas mesmas entradas abrem esta seção on-line (em inglês).

## Compilação

Veja [build/README.md](../../build/README.md). Resumo: VS2022 Build Tools (MSVC v143) e depois `pwsh build\Build.ps1`. Antes de incorporar uma nova versão do upstream, leia o [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Doar

O 7-ZSTar é de uso gratuito, você contribuindo ou não. Se ele economizou algum tempo seu e você quer agradecer, pode enviar criptomoedas para o endereço abaixo. O valor vai para mim, DraftingDreamer, para cobrir meus próprios custos de desenvolvimento, e não compra novas funcionalidades, suporte nem qualquer promessa sobre o que vem a seguir.

Qualquer token nas redes Ethereum ou Polygon é bem-vindo: ETH, POL, USDT, USDC ou outro. O endereço é o mesmo nas duas redes.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR code do endereço de doação">

- Só são aceitas transferências nas redes Ethereum (ERC20) e Polygon. Se você puder usar qualquer uma das duas, a Polygon costuma ter taxas menores.
- Este é o único endereço oficial, e eu nunca vou pedir que você envie para outro.
- Transferências em blockchain não podem ser revertidas, então não há reembolso.

Dar uma estrela ao 7-ZSTar no GitHub ou indicá-lo a um amigo também ajuda.

## Licença

LGPL v3, veja [LICENSE](../../LICENSE). Algumas partes têm outros termos: a descompactação de RAR, por exemplo, traz a restrição do unRAR, então um build com suporte a RAR não é puramente LGPL v3. A lista completa está em [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), e os avisos de direitos autorais de todos os componentes estão em [NOTICE](../../NOTICE).

## Agradecimentos

O 7-ZSTar se apoia nos ombros de muita gente. Obrigado a todos que dedicaram seu tempo ao 7-Zip, aos algoritmos de compactação e ao software de código aberto em geral. Sem vocês, este software não existiria.
