<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · **Português (Brasil)** · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Em caso de divergência com a versão em inglês, prevalece a versão em inglês.*

**Um fork do 7-Zip mais amigável para quem usa o Windows 11 hoje: menu do botão direito no primeiro nível, compactação zstd e tar.zst em uma única passada.**

[Baixar](https://github.com/7zStar/7-ZSTar/releases/latest) · [Site](https://www.7zstar.com) · [Histórico de alterações](../../CHANGELOG.md)

## Por que usar o 7-ZSTar

- **Chega de “Mostrar mais opções”.** No Windows 11, o 7-ZSTar fica logo no primeiro nível do menu do botão direito.
- **tar.zst em uma única etapa.** Compactar uma pasta em .tar.zst, ou extrair um, é uma única etapa, sem deixar nenhum .tar no disco. O 7-Zip oficial não cria .tar.zst e extrai um em duas etapas, passando por um .tar.
- **Cerca de 10× mais rápido que o 7z.** Em pastas de projeto reais, o tar.zst compactou de 10 a 18 vezes mais rápido.

## Velocidade

| Pasta | Arquivos | Original | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (binários grandes) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

O tar.zst ficou de 15 a 23% menor que o zip, e não foi mais lento. O 7z ainda gera os menores arquivos (o tar.zst ficou de 15 a 27% maior), mas levou muito mais tempo. A extração levou praticamente o mesmo tempo com os três.

Configurações padrão para os três; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, SSD NVMe, mediana de 3 execuções, 2026-11.

## Formatos

- **Compactar em uma etapa:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extrair em uma etapa:** todos esses, mais tar.lzma e tar.Z
- **Codecs adicionados:** zstd, brotli, lz4, lz5 e lizard (isolados ou dentro de um .7z), mais fast-lzma2, um codificador LZMA2 alternativo
- Todos os formatos que o 7-Zip oficial suporta continuam funcionando.

## Baixar

A maioria das pessoas quer o `.msi` x64 para todos os usuários, da página de [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` para todos os usuários | Só para você `-user.msi` | `.zip` portátil |
|---|---|---|---|
| Exige privilégios de administrador | Sim | Não | Não |
| Menu do botão direito | Primeiro nível no Windows 11 | Menu clássico (em “Mostrar mais opções” no Windows 11) | Nenhum |
| Atalho no Menu Iniciar | Sim | Sim | Não |

Cada um também está disponível para x86 e arm64; escolha o que corresponde ao seu Windows. No Windows de 64 bits, os pacotes x86 podem ficar sem o menu do botão direito, e os builds arm64 ainda não foram testados em hardware real. O 7-ZSTar se instala ao lado do 7-Zip oficial, sem afetá-lo.

**O Windows pode exibir um aviso na primeira vez.** Os arquivos não têm assinatura digital, então o SmartScreen pode bloqueá-los (“O Windows protegeu o computador”; talvez seja preciso expandir o aviso para ver *Executar assim mesmo*), e no Windows 11 com o Controle inteligente de aplicativos ativado o `.msi` é bloqueado de vez. Cada release traz um arquivo `SHA256SUMS` para conferir o seu download. O [guia de instalação](../install/INSTALL.pt-BR.md#pacotes-não-assinados-smartscreen-e-controle-inteligente-de-aplicativos) explica como fazer isso e o que fazer em relação ao Controle inteligente de aplicativos.

**Sobre o menu do primeiro nível:** no Windows 11, o `.msi` para todos os usuários adiciona um pequeno pacote assinado com um certificado autoassinado e passa a confiar nesse certificado; é isso que o Windows exige para o primeiro nível. A desinstalação remove os dois. Se você preferir não fazer isso, instale com `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. O pacote é registrado para a conta que executa o instalador; as outras contas o registram separadamente.

As associações de arquivos, a desinstalação e o pacote por usuário estão descritos no [guia de instalação](../install/INSTALL.pt-BR.md).

## Linha de comando

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

No PowerShell, coloque a opção entre aspas: `7z a "-ttar.zst" backup.tar.zst docs`. Sem as aspas, o PowerShell a divide em duas e você acaba com um arquivo chamado `.zst`. O Command Prompt (cmd), o prompt de comando do Windows, não precisa de aspas.

## Bom saber

- **Desmarcar “Integrar o 7-ZSTar ao menu de contexto do shell”** (gerenciador de arquivos, **Ferramentas > Opções > 7-ZSTar**) remove o item do menu do botão direito, como no 7-Zip oficial. Com o pacote para todos os usuários, para ativá-lo de novo basta abrir o gerenciador de arquivos com *Executar como administrador*. Com o pacote por usuário isso não é possível (“Acesso negado.”); execute o `.msi` de novo e escolha *Repair* (reparar a instalação).
- **Instalações silenciosas ou remotas no Windows 11** (por SSH, ou a partir de uma ferramenta de implantação) são concluídas com sucesso, mas o item do primeiro nível não é registrado, então o 7-ZSTar aparece apenas em “Mostrar mais opções”. [Mais detalhes no guia de instalação](../install/INSTALL.pt-BR.md#o-menu-do-botão-direito-do-windows-11).
- **Extrair tar.br, tar.lz4, tar.lz5, tar.liz ou tar.Z** continua sendo uma única etapa para você, mas passa por um arquivo temporário que é apagado depois.

## Requisitos de sistema

Windows 7 / Server 2008 R2 ou posterior (x64, x86), ou Windows 10 ou posterior no arm64. Não é preciso instalar mais nada. Testado no Windows 7 SP1 de 64 bits (com as atualizações posteriores instaladas), no Windows 10 e no Windows 11; [o que foi testado](../install/INSTALL.pt-BR.md#requisitos-de-sistema). No Linux há uma versão de linha de comando que você mesmo compila; o macOS não é suportado.

## Documentação

**Ajuda > Conteúdo** e F1 abrem o `7-zip.chm`, o arquivo de ajuda do 7-Zip oficial. Ele diz “7-Zip” do começo ao fim e não cobre o que o 7-ZSTar acrescenta; isso está nesta página e no [histórico de alterações](../../CHANGELOG.md). Se o arquivo de ajuda não for encontrado, as mesmas entradas abrem esta seção on-line.

Para compilar o 7-ZSTar por conta própria, veja [build/README.md](../../build/README.md); antes de incorporar uma nova versão do upstream, leia [MAINTAINING.md](../../MAINTAINING.md).

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

LGPL v3, veja [LICENSE](../../LICENSE). Algumas partes têm outros termos: a descompactação de RAR traz a restrição do unRAR, então um build com suporte a RAR não é puramente LGPL v3. A lista completa está em [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), e os avisos de direitos autorais estão em [NOTICE](../../NOTICE).

Obrigado a todos que dedicaram seu tempo ao 7-Zip, aos algoritmos de compactação e ao software de código aberto em geral. Sem vocês, o 7-ZSTar não existiria.
