<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalando o 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [简体中文](INSTALL.zh-Hans.md) · [Deutsch](INSTALL.de.md) · [Français](INSTALL.fr.md) · [Español](INSTALL.es.md) · **Português (Brasil)** · [日本語](INSTALL.ja.md) · [Tiếng Việt](INSTALL.vi.md) · [Русский](INSTALL.ru.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md) · [Esperanto](INSTALL.eo.md)

*Em caso de divergência com a versão em inglês, prevalece a versão em inglês.*

Esta página traz os detalhes por trás da versão curta do [README](../readme/README.pt-BR.md): requisitos de sistema, o aviso do SmartScreen, o Controle inteligente de aplicativos e como verificar um download, os três pacotes, o menu do botão direito do Windows 11, as associações de arquivos e a desinstalação.

## Requisitos de sistema

**Windows 7 ou Windows Server 2008 R2, x64 ou x86. No arm64, Windows 10.**
Não é preciso mais nada: o runtime C é vinculado estaticamente (`-MT`), então os binários não importam nada além das próprias DLLs do Windows: sem redistribuível, sem .NET.

Esse piso é *derivado* do que os pacotes exigem, e foi testado no Windows 7 SP1 com as atualizações posteriores instaladas (incluindo o PowerShell 5.1), no Windows 10 22H2 e no Windows 11, todos de 64 bits. No Windows 7 e no 10, isso cobriu a instalação e a desinstalação do `.msi` x64 para todos os usuários e por usuário, o assistente de instalação, o `.zip` x64, todos os codecs adicionados e todos os formatos tar de uma etapa, o menu do botão direito, as associações de arquivos e o arquivo de ajuda, além do `.msi` e do `.zip` x86 em execução no Windows de 64 bits. Nada além disso foi testado no Windows: nem o Windows 8 ou 8.1, nem o Windows Server, nem o Windows de 32 bits, nem hardware arm64, nem o Windows 7 sem essas atualizações. O piso também é mais alto que o do 7-Zip upstream, cujos binários ainda carregam no Windows XP. Três coisas o colocam nesse nível, e a segunda é a que nenhuma configuração de compilação consegue desfazer:

- O `.msi` declara `InstallerVersion="500"`, e o Windows Installer 5.0 foi distribuído "with Windows Server 2008 R2 and later and Windows 7 and later" (ou seja, com o Windows Server 2008 R2 e posteriores e com o Windows 7 e posteriores) ([Microsoft][msi-versions]). O `.zip` portátil não passa pelo Windows Installer, mas veja os dois pontos seguintes.
- **O zstd e o fast-lzma2 usam uma sincronização que só existe a partir do Vista.** Ambos forçam `_WIN32_WINNT 0x0600` nos próprios cabeçalhos e chamam `InitializeConditionVariable` / `SleepConditionVariableCS` diretamente, então `7z.dll` e `7za.exe`, os dois binários com os codecs compilados dentro, importam quatro funções que o Windows XP e o Server 2003 não têm. O `7z.dll` do upstream não importa nenhuma delas.
- A cadeia de ferramentas: eles são compilados com o Visual Studio 2022, cuja lista de destinos compatíveis é Windows 7 e posteriores; Vista e Server 2008 são "No" ([Microsoft][vs-targeting]). A versão do subsistema vinculada é 6.0 em x64 e x86 e 6.2 em arm64, e o Windows em arm64 começa no Windows 10 de qualquer forma.

O Windows Vista e o Server 2008 ficam no meio do caminho: os binários carregariam, mas a cadeia de ferramentas não os suporta, o instalador não roda ali e o 7-ZSTar não é testado neles.

**O Linux é suportado apenas como build de linha de comando; o macOS não é suportado.**
O fork compila um `7zz` nativo (o programa de console `Alone2`) com o gcc, por meio de um makefile próprio que inclui os do upstream e não modifica nenhum deles:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Ele foi compilado e testado apenas no Ubuntu 24.04 com gcc 13.3 (x86-64): a compilação não gera avisos com as flags do upstream, o smoke test de 77 verificações passa, e os 25 vetores de interoperabilidade criados no Windows e os 37 criados no Linux dão os mesmos resultados que no Windows. Os dois arquivos do fork que o port alterou continuam compilando sem mudanças no Windows (build x64 limpo, smoke tests e releitura de interoperabilidade passam todos). Não há GUI. Os outros alvos Linux do upstream (`7za`, `7zr`, `7z.so`) não são suportados: as listas de objetos do gcc deles não têm o que as mudanças do fork nos handlers do upstream exigem, então espera-se que falhem na vinculação. Outras arquiteturas, distribuições e compiladores não foram verificados, e o macOS nunca foi compilado, portanto nenhum `MACOSX_DEPLOYMENT_TARGET` pode ser informado. Os passos de compilação, os testes e os limites conhecidos estão em `build/linux/README.md`; a interoperabilidade com ferramentas Linux está em `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Pacotes não assinados, SmartScreen e Controle inteligente de aplicativos

**Os instaladores e os programas de uma release do 7-ZSTar não são assinados digitalmente por uma autoridade de certificação**, e este projeto não possui nenhum certificado de assinatura de código. Por isso o Windows não consegue saber quem publicou o arquivo, e quando você executa o `.msi`, ou um programa do `.zip`, pela primeira vez, o Microsoft defender SmartScreen pode bloqueá-lo com um aviso. A documentação para desenvolvedores da Microsoft lista "No signature" (sem assinatura) como um dos casos que mostram um aviso com o título "O Windows protegeu o computador" ("Windows protected your PC" no texto da Microsoft), em que o usuário precisa escolher "Executar assim mesmo" ("Run anyway" no texto da Microsoft) antes que o app seja executado ([Microsoft][smartscreen-rep]). A política corporativa pode remover essa opção por completo; em um PC assim, fale com quem o administra.

A única coisa de uma release que *é* assinada é o pequeno pacote que coloca o 7-ZSTar no primeiro nível do menu do botão direito do Windows 11, dentro do `.msi` para todos os usuários. O certificado dele é autoassinado e gerado durante a compilação desse único pacote, portanto não é a assinatura de uma autoridade de certificação e não diz nada sobre quem compilou o pacote; veja [o menu do botão direito do Windows 11](#o-menu-do-botão-direito-do-windows-11) para saber o que ele faz e como recusá-lo.

O aviso não prova que um arquivo seja ruim, e a ausência dele não provaria que um arquivo seja bom. O que você mesmo pode verificar é se a sua cópia é exatamente a publicada na página da release. Toda release traz um arquivo chamado `SHA256SUMS`: uma linha por pacote, com um hash SHA-256 seguido do nome do arquivo.

1. Baixe o pacote e o `SHA256SUMS` da mesma página da release, para a mesma pasta.
2. Abra o PowerShell nessa pasta e compare. Troque o nome pelo do arquivo que você baixou:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` significa que os hashes são idênticos. Para vê-los você mesmo, execute em vez disso
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` e procure o mesmo
   nome de arquivo em `SHA256SUMS`; a comparação ignora maiúsculas e minúsculas.
3. Se você receber `False`, ou o nome do arquivo não estiver em `SHA256SUMS`, não o execute: exclua o arquivo e baixe-o de novo. Se ainda assim não corresponder, relate o problema como descrito em [SECURITY.md](../../SECURITY.md).

O `SHA256SUMS` cobre apenas os arquivos enviados para aquela release. Compilar você mesmo a mesma tag gera hashes diferentes (o pacote do menu do botão direito é assinado com um certificado novo a cada compilação), e o código-fonte é publicado com toda release, caso você prefira compilá-lo: veja [build/README.md](../../build/README.md).

Quando os hashes coincidirem e você estiver satisfeito com a origem do arquivo:

- **`.msi`**: inicie-o normalmente. Se o SmartScreen o bloquear, escolha a opção para executá-lo assim mesmo ("Run anyway" em um Windows em inglês, "Executar assim mesmo" em um Windows em português do Brasil). Pode ser necessário expandir primeiro a janela do aviso: no computador com Windows 10 testado, ela oferecia apenas um botão para não executar o arquivo até que o link abaixo da mensagem fosse clicado. O `.msi` para todos os usuários então pede aprovação de administrador, como qualquer outro instalador.
- **`.zip`**: extraia-o e inicie `7zFM.exe` ou `7z.exe` a partir da pasta. Os programas que estão dentro dele também não são assinados, então o Windows pode mostrar o mesmo aviso na primeira vez que você iniciar cada um.

O SmartScreen avisa de acordo com o quanto um arquivo é conhecido, e não apenas pelas assinaturas; um arquivo baixado por poucas pessoas pode disparar o aviso mesmo estando assinado. Nada do que está aqui muda isso, e nenhum dos passos acima desativa o SmartScreen.

### Controle inteligente de aplicativos no Windows 11

Alguns PCs com Windows 11 têm ativada uma proteção mais rígida chamada **Controle inteligente de aplicativos**. Quando ela está ativada, o Windows bloqueia arquivos não assinados, a menos que o serviço de nuvem da Microsoft possa atestar por eles, e uma release nova normalmente não tem esse registro ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Ao contrário do aviso do SmartScreen, o bloqueio não tem a opção de executar o arquivo assim mesmo, e as perguntas frequentes da Microsoft dizem que não há como contornar o Controle inteligente de aplicativos para um app individual.

O que aconteceu quando o 7-ZSTar 26.05.1 foi testado no Windows 11 Pro 25H2 (build 26200.8037) com o Controle inteligente de aplicativos ativado:

- **Os instaladores `.msi` foram bloqueados**, tanto o de todos os usuários quanto o por usuário. Em um Windows em chinês tradicional, o Windows Installer exibiu 「系統禁用此安裝。請連絡系統管理員。」, e uma notificação da Segurança do Windows disse que o Controle inteligente de aplicativos havia bloqueado o arquivo porque o Windows não conseguia saber quem o publicou e ele não é um app que o Windows conhece. Não havia opção para continuar, e `msiexec /i ... /qn` retornou o erro 1625. Essa mensagem é a string 1625 do Windows Installer; em um Windows em inglês a mesma string diz "The system administrator has set policies to prevent this installation." (lida nos recursos em inglês do Windows Installer, não vista na tela).
- **Um programa do `.zip` foi executado.** O `7zFM.exe`, extraído do `.zip` portátil, iniciou normalmente no mesmo teste. Se o Windows deixa um programa não assinado ser executado é um julgamento dele sobre aquele arquivo, então isso pode ser diferente no seu PC.
- Logo depois que o Controle inteligente de aplicativos foi ativado, o `.msi` foi instalado durante alguns minutos antes de começar a ser bloqueado. A causa não foi encontrada, então uma instalação bem-sucedida logo após a ativação não significa que o instalador seja permitido.

Portanto, em um PC em que o Controle inteligente de aplicativos está ativado, **os instaladores não podem ser instalados**, e verificar o `SHA256SUMS` não muda isso. O que muda é desativar o Controle inteligente de aplicativos em Configurações do controle inteligente de aplicativos, no app Segurança do Windows (no Windows em chinês tradicional testado: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). No teste, escolher a opção Desativado teve efeito imediato, sem reinicialização, e os instaladores passaram então a ser instalados. Essa é uma configuração do PC inteiro e nada aqui pede que você a altere: a decisão é sua, ou do seu administrador em um PC gerenciado.

Também vale saber antes se é possível reativá-lo. As perguntas frequentes da Microsoft dizem que as atualizações recentes do Windows permitem reativar o Controle inteligente de aplicativos sem uma instalação limpa do Windows, então, em uma versão sem elas, desativá-lo pode ser permanente. Na build testada aqui, a opção para ativá-lo ainda era oferecida depois de desativá-lo; isso é um resultado de teste, não uma promessa sobre a sua versão.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalação

Três pacotes, todos gerados por `installer\Build-Package.ps1` (o por usuário com `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Instala para | todas as contas | a conta que instala | - |
| Menu do botão direito do Explorador de Arquivos | sim | sim, apenas o menu clássico ([abaixo](#o-pacote-por-usuário)) | não |
| Item no *Menu Iniciar* | sim | sim | não |
| Precisa de administrador | sim | não | não |
| Remoção | *Aplicativos instalados* em Configurações | *Aplicativos instalados* em Configurações | excluir a pasta |

*Aplicativos instalados* é o nome no Windows 11. O Windows 10 chama a mesma página de *Apps e Recursos*, e no Windows 7 ela é *Programas e Recursos* no Painel de Controle.

Use os pacotes que correspondem ao próprio Windows: x86 no Windows de 32 bits, x64 no Windows de 64 bits, arm64 no Windows em Arm (os pacotes arm64 são gerados, mas nunca foram executados). A extensão de shell x86 é de 32 bits e o Explorador de Arquivos de 64 bits não consegue carregá-la, então no Windows de 64 bits o `-user.msi` x86 não tem nenhum menu do botão direito, e o `.msi` x86 só tem um no Windows 11 e apenas para as contas que registraram o pacote dele para Windows 11 (a que instalou, ou uma que executou `-Register`, veja abaixo).

O MSI é instalado em `Program Files\7-ZSTar`, sempre: ao contrário do pacote por usuário, ele não oferece escolha de pasta e ignora `INSTALLFOLDER` na linha de comando, porque essa pasta guarda um script que o instalador executa como SYSTEM e uma DLL que o Explorador de Arquivos de todo usuário carrega, e uma pasta criada em outro lugar (em `C:\`, por exemplo) é gravável por todos os usuários. Ele registra o próprio CLSID de extensão de shell e o próprio hive de registro `Software\7-ZSTar`, e dá o nome `7-ZSTar` a toda chave de menu de contexto: assim, ele não colide com as do 7-Zip oficial nem as remove. Veja [installer/GUIDS.md](../../installer/GUIDS.md).

Ele executa um assistente de instalação normal (welcome, licence, setup type, optional feature tree, finish: boas-vindas, licença, tipo de instalação, árvore de recursos opcionais, conclusão) e a instalação silenciosa continua funcionando sem mudanças (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), porque o msiexec pula toda a sequência de interface no modo silencioso. O assistente está apenas em inglês, mesmo em um Windows configurado para outro idioma (visto no Windows 10 em chinês tradicional; o `.msi` é compilado sem nenhum outro idioma), e na página final *Launch 7-ZSTar File Manager* vem marcado por padrão.

### O menu do botão direito do Windows 11

No Windows 11, o item fica no menu de primeiro nível, e não escondido em *Mostrar mais opções*, onde o 7-Zip oficial e o WinRAR ainda ficam. O Windows 11 só lista ali uma extensão de shell quando ela vem com identidade de pacote, então o MSI inclui, ao lado do programa, um pequeno pacote MSIX apenas de identidade e o registra durante a instalação. O registro clássico também é mantido. É ele que coloca o item no menu do botão direito no Windows 10 e no Windows 7, cujo menu tem um único nível e nenhum *Mostrar mais opções*, e é ele que mantém tudo funcionando para quem restaurou o menu de contexto antigo.

Esse pacote é assinado com um **certificado autoassinado**, e o instalador o coloca em `LocalMachine\TrustedPeople`: o Windows não implanta um pacote cuja assinatura ele não consegue encadear até algo confiável. A desinstalação remove o certificado junto com o pacote. No Windows 10 e no Windows 7, o instalador não faz nenhuma das duas coisas: não adiciona certificado e não registra pacote, e só o registro clássico fornece o menu.

Se você preferir não confiar em um certificado autoassinado, recuse apenas essa parte e mantenha todo o resto:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Você então fica só com o menu clássico, de modo que, no Windows 11, o item do 7-ZSTar fica no menu do botão direito, em *Mostrar mais opções*. Para ativar o item de primeiro nível depois, ou para desfazê-lo após uma instalação normal:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Confiar nesse certificado significa que o Windows também aceitará, sem aviso, **qualquer outro** pacote assinado com a mesma chave. Ele só é usado para esse único pacote, e a desinstalação o retira de novo, mas é isso que você está aceitando: o `SPARSE=0` acima é a maneira de recusá-lo.

O registro do pacote é por usuário, e o instalador só o executa para quem instalou. Duas consequências:

- Uma segunda conta no mesmo computador fica apenas com o menu clássico, até executar esse mesmo script com `-Register`.
- A desinstalação só cancela o registro de quem desinstala. Se outra pessoa o registrou, o registro dela sobrevive à desinstalação e aponta para uma pasta que não existe mais; essa conta o remove com `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Limitação conhecida: o menu de primeiro nível só é registrado quando a instalação é executada em uma sessão interativa com login feito.** Instalar o `.msi` para todos os usuários a partir de uma sessão remota ou não interativa (por SSH, ou uma implantação silenciosa feita por uma ferramenta de gerenciamento) continua informando sucesso, mas o pacote do Windows 11 não é registrado, então só aparece o menu clássico em *Mostrar mais opções*. No teste, `msiexec /i ... /qn` em uma sessão SSH (sessão 0) terminou com 0, enquanto o `Setup-ShellIntegration.ps1` informou `registration failed: 0x80070005` (acesso negado); o mesmo `.msi` instalado a partir da sessão de console de um administrador foi registrado normalmente.

`-Status` mostra o que está e o que não está no lugar.

### O pacote por usuário

`7-ZSTar-<version>-<arch>-user.msi` é instalado apenas para a conta atual, em `%LOCALAPPDATA%\Programs\7-ZSTar`, sem solicitação do Controle de Conta de Usuário (UAC). Tudo o que ele registra vai em `HKCU`; o pacote não grava nada em `HKLM` (exceto o controle interno do próprio Windows Installer). O que ele não faz do jeito que o pacote por computador faz:

- **Sem o menu de primeiro nível do Windows 11.** No Windows 11, o 7-ZSTar fica no menu do botão direito, em *Mostrar mais opções*. O item de primeiro nível exige que o certificado autoassinado seja confiável em todo o computador, o que requer um administrador: medido no Windows 11, um certificado em `CurrentUser\TrustedPeople` não basta para o Windows implantar o pacote. Por isso o pacote por usuário o deixa de fora.
- **Um dos dois por computador.** Cada pacote se recusa a instalar enquanto o outro estiver instalado; desinstale um antes de instalar o outro. O pacote por computador só enxerga a cópia por usuário da conta que o executa, então a instalação por usuário de outra conta não é detectada.
- **A Política de Grupo pode ocultar o menu dele.** Onde `EnforceShellExtensionSecurity` está definido, o Explorador de Arquivos carrega apenas as extensões de shell listadas na chave *Approved* de todo o computador, que uma instalação por usuário não consegue gravar, então o menu do botão direito não aparece. Use ali o pacote por computador.
- **Limpar um formato em Ferramentas > Opções > Sistema também remove a oferta do 7-ZSTar para ele.** Quando você limpa um formato ali (clique na célula dele até ficar vazia, depois OK), o gerenciador de arquivos exclui por inteiro as chaves `HKCU\Software\Classes\.<ext>` e `7-ZSTar.<ext>`, e, em uma instalação por usuário, essas chaves também guardam o que o pacote registrou para Configurações > Aplicativos > Aplicativos padrão e para a lista *Abrir com*. O 7-ZSTar então some de *Abrir com* para esse formato, e Aplicativos padrão mostra uma entrada em branco para ele. Reparar a instalação o traz de volta (execute o `.msi` de novo e escolha *Repair*, que significa reparar). Melhor ainda: atribua os tipos de arquivo em Aplicativos padrão, e não no gerenciador de arquivos. O pacote por computador tem o mesmo ponto fraco em um lugar, descrito abaixo, em associações de arquivos.

### Associações de arquivos e o que a desinstalação faz com elas

**Defina-as em Configurações > Aplicativos > Aplicativos padrão.** No Windows 11, digite 7-ZSTar ali e todos os formatos que ele pode abrir são listados para atribuição. No Windows 10, o 7-ZSTar aparece em *Set defaults by app* (definir padrões por aplicativo) nessa página, onde *Manage* (gerenciar) mostra os formatos dele. O Windows 7 não tem o app Configurações: o 7-ZSTar aparece no Painel de Controle > Programas Padrão > *Definir os programas padrão*, que é o que *Aplicativos padrão* representa neste guia ali. Atribuir formatos a partir dessas duas páginas não foi testado. O instalador registra o 7-ZSTar como um aplicativo de Programas Padrão: um ProgID por formato com o ícone dele e o comando de abertura, uma entrada na lista *Abrir com* de cada extensão e o bloco Capabilities que o Windows lê, mas de propósito não reivindica nenhum tipo de arquivo: qual programa abre os seus arquivos compactados é decisão sua, e é isso que mantém o 7-ZSTar e o 7-Zip oficial fora do caminho um do outro. O Windows ainda pode enviar um formato ao 7-ZSTar por conta própria quando nenhum outro programa se oferece para abri-lo: nos computadores com Windows 10 e Windows 7 testados, em que nada mais havia registrado `.7z`, um arquivo `.7z` mostrava o ícone do 7-ZSTar e abria nele com um clique duplo, sem que o Windows perguntasse qual programa usar.

**Ferramentas > Opções > Sistema no gerenciador de arquivos, na maior parte, não funciona no Windows 11**, e isso é uma regra do Windows, não um bug daqui. Ele grava um ProgID `7-ZSTar.<ext>` em `HKCU\Software\Classes`, e para qualquer extensão que o computador já conheça (todo formato de arquivo compactado conhece) o Windows 11 o ignora: `AssocQueryString` responde `Unknown` e o Explorador de Arquivos desenha o ícone genérico em branco. O que ele respeita em vez disso é uma chave `UserChoice` carimbada com um hash que só o Windows consegue calcular, e é por isso que a interface de Configurações é o único caminho ali. Nenhum aplicativo consegue gravar uma: nem o 7-ZSTar, nem o 7-Zip, nem qualquer instalador. O Windows 10 e o Windows 7 se comportaram de modo diferente nos testes: depois que `.7z` e `.zst` foram definidos no gerenciador de arquivos, sem nenhum outro programa escolhido para eles, `AssocQueryString` retornou `7zFM.exe` para ambos.

**Limpar um formato na coluna *Todos os usuários* dela remove o registro próprio do pacote por computador para ele.** Essa coluna grava em `HKLM\Software\Classes`, onde o pacote por computador mantém os ProgIDs e as entradas de *Abrir com* que ele anuncia, e limpar um formato ali (o que exige o gerenciador de arquivos aberto com *Executar como administrador*) exclui essas chaves por inteiro, para todas as contas. Reparar restaurou as mesmas chaves no pacote por usuário; para este, isso não foi medido.

**Um ícone que continua em branco depois de mudar qualquer coisa** também pode ser o cache de ícones do Explorador de Arquivos, que não percebe que uma DLL que ele já colocou em cache foi substituída; `ie4uinit.exe -show` não o limpa de forma confiável. Feche o Explorador de Arquivos, exclua `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` e inicie-o de novo.

**A desinstalação remove as associações que consegue alcançar**: os ProgIDs `7-ZSTar.*` de quem está desinstalando, e apenas os tipos de arquivo que ainda apontam para eles, de modo que um formato entregue a outro programa nesse meio-tempo é deixado em paz. A desinstalação do pacote por computador também deixa em paz um ProgID que abre uma cópia do 7-ZSTar que ainda existe em outro lugar, uma cópia portátil do `.zip`, configurada com o próprio **Ferramentas > Opções > Sistema** dela. O pacote por usuário não consegue: os ProgIDs dele são justamente essas mesmas chaves de `HKCU` (veja *O pacote por usuário* acima), e desinstalá-lo as remove, não importa quem as gravou por último. Deixá-las para trás faria esses tipos apontarem para um ProgID cujo ícone e comando são um executável excluído, ou seja, um ícone em branco e um erro ao dar clique duplo. As associações de outras contas estão fora de alcance; elas podem limpar as próprias com `Setup-ShellIntegration.ps1 -RemoveAssociations` antes de o programa ser removido. `msiexec /x ... KEEPASSOC=1` pula essa etapa, e uma atualização nunca a executa.

**Limitação conhecida: as outras contas mantêm as associações que elas mesmas definiram.** A desinstalação do pacote por computador limpa apenas o que a conta que executa a desinstalação definiu na própria coluna (com o nome da conta no cabeçalho) em **Ferramentas > Opções > Sistema** no gerenciador de arquivos. Qualquer outra conta que tenha definido associações ali as mantém, apontando para o programa removido, de modo que, ao dar clique duplo em um arquivo `.7z`, o Windows pergunta qual programa usar. Cada conta deve limpar as suas **antes** da desinstalação, com

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

que remove apenas as entradas do 7-ZSTar, ou atribuir os tipos de novo depois, em Configurações > Aplicativos > Aplicativos padrão. Fazer isso no gerenciador de arquivos significa clicar em cada célula da própria coluna que mostra o 7-ZSTar até ficar vazia, depois OK; não selecione todas as linhas e pressione "+", que aplica um único estado a todas as linhas selecionadas e, portanto, também limpa formatos que pertencem a outro programa, como o 7-Zip oficial.

As associações definidas na coluna **Todos os usuários** não são tocadas de forma alguma pela limpeza da desinstalação e deixam todas as contas apontando para o programa removido. Um administrador que tenha definido alguma deve limpar essas células, em um gerenciador de arquivos aberto com *Executar como administrador*, depois OK, antes de desinstalar; `-RemoveAssociations` não alcança essa coluna. Limpá-la logo antes de uma desinstalação é inofensivo, mesmo que isso exclua ali o registro próprio do pacote (acima), já que a desinstalação o remove de qualquer forma. O pacote por usuário não tem o problema das outras contas, e o 7-Zip oficial se comporta do mesmo jeito.

## Idiomas

Todo pacote traz as traduções do upstream, pouco mais de 90 idiomas. Escolha um em **Ferramentas > Opções > Idioma**; o MSI também permite deixá-los de fora na instalação *Custom*. O 7-ZSTar tenta seguir o idioma do sistema na primeira execução, mas essa detecção desiste e permanece em inglês quando a configuração "Idioma para programas não-Unicode" do Windows e a configuração "Formato regional" não coincidem: escolher um idioma manualmente sempre funciona.

As strings que o próprio 7-ZSTar adicionou, ou seja, os campos de nível e de dicionário do zstd e os nomes dos novos formatos de arquivo compactado, não têm tradução no upstream e permanecem em inglês. A exceção são os botões **Doar** e **Site** da caixa de diálogo Sobre o 7-ZSTar: 67 dos 92 idiomas têm uma palavra para cada um, e os outros 25 mostram inglês (`Lang/UPSTREAM.md` os lista).
As traduções são incorporadas como vêm do upstream, não escritas aqui: veja [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
