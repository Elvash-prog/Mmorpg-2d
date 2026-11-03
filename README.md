# Aurora — Fronteira Viva

Primeiro protótipo de um RPG 2D para PC e Android, inspirado no gênero dos MMORPGs clássicos, com mundo e visual próprios. Arte provisória gerada pelo código; nenhum recurso do Warspear é usado.

## Jogar no computador

1. Instale o **Godot 4.6.3 padrão** (não precisa da versão .NET).
2. No Godot, clique em **Importar** e selecione `project.godot` desta pasta.
3. Aperte **F6** com a cena `scenes/world.tscn` aberta, ou **F5** para iniciar o projeto.
4. Mova com **WASD ou setas** e ataque segurando **Espaço**, **1** ou o primeiro botão da barra de habilidades. A fonte recupera sua vida. Derrote cinco limos para completar a missão.

Os botões direcionais e de ataque também aceitam toque simultâneo. Os controles do jogo usam teclas físicas, sem capturar o texto digitado no campo de IP.

## Jogar com outra pessoa

Abra **REDE**, no canto inferior direito, e clique em **Hospedar**. Na outra instância, abra **REDE**, informe o IP do computador anfitrião e clique em **Conectar**. Para testar duas janelas no mesmo PC, use `127.0.0.1`. Em uma rede Wi-Fi, use o IP local do anfitrião. Autorize **UDP 24567** no firewall do anfitrião. O servidor calcula movimento, combate, vida e experiência; clientes enviam comandos.

Esta versão é um teste em rede local para até oito convidados. Conexão pela internet exige servidor acessível e configuração de rede. Não há contas, salvamento, servidor público, criptografia ou proteção completa contra abuso. O progresso é temporário e reinicia ao trocar de sessão. O mundo tem tamanho fixo e os jogadores são distinguidos por cor e contorno.

## Interface

A interface usa painéis escuros com bordas douradas, vida e experiência no canto superior esquerdo, um minimapa com posições reais à direita, objetivo da missão, mensagens locais do sistema e barra inferior. O primeiro espaço executa o ataque; os espaços 2–5 estão explicitamente bloqueados e reservados. **MENU** abre o guia; **REDE** abre as opções de multiplayer. A barra azul representa experiência, não mana. O cenário tem arte provisória original, desenhada pelo código; casas, água e árvores são decorativas, sem colisões nesta versão.

![Interface no PC](docs/interface-pc.png)

No modo de toque, um direcional aparece sobre o mapa e aceita movimento e ataque simultâneos. Para conferir esse layout no PC, execute `godot --path . -- --touch-ui`. A proporção da tela é preservada para evitar cortes; aparelhos mais largos podem mostrar barras laterais. O toque ainda precisa ser validado em um aparelho Android real.

## Android

O projeto usa renderização Compatibility, orientação horizontal e controles de toque. Para gerar APK no seu computador, instale os templates de exportação correspondentes ao Godot 4.6.3 e configure o SDK Android e Java 17 conforme a documentação oficial do Godot. Em **Projeto → Exportar**, adicione Android e habilite a permissão **Internet** para o multiplayer. Exporte um APK de depuração e instale em um aparelho de teste. APK e execução em aparelho ainda não foram validados neste ambiente.

## Desenvolvimento e validação

```sh
godot --path .
godot --headless --path . --script tests/combat_test.gd
godot --headless --path . --script tests/ui_test.gd
godot --headless --path . -- --server
```

Teste de rede automatizado: inicie `godot --headless --path . -- --server --smoke-host`; em outro terminal, execute `godot --headless --path . -- --smoke-client`. O cliente deve imprimir `NETWORK_CLIENT_PASS` e encerrar com código 0; o servidor imprime `NETWORK_HOST_PASS` ao receber ataque remoto. Encerre o servidor após o teste.

Em ambientes restritos, use diretórios XDG graváveis para os dados locais do Godot, por exemplo `XDG_DATA_HOME=/tmp/aurora-data XDG_CONFIG_HOME=/tmp/aurora-config XDG_CACHE_HOME=/tmp/aurora-cache`. A rede local pode exigir execução fora do sandbox.

Próximas etapas: validar o combate com jogadores, melhorar a arte e o mapa, adicionar classes e inventário e planejar persistência e um servidor dedicado. Este protótipo ainda não é um MMORPG completo.
