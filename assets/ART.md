# Arte do protótipo

As duas imagens desta pasta foram geradas com a ferramenta de imagens da OpenAI durante o desenvolvimento, a partir de descrições para este projeto. Não são recursos extraídos do Warspear Online. Os arquivos de origem foram copiados para o repositório sem edição destrutiva.

## Guardião (`guardian.png`)

Direção de arte: personagem original de RPG em pixel art, cabelo castanho, túnica e capa azul-petróleo, ombreiras de aço com bordas de bronze, botas de couro e espada curta. Fundo transparente. Folha quadrada de 4 colunas × 4 linhas, com corpo inteiro e quadros centrados. Linhas: sul, oeste, leste e norte; colunas: repouso, passo, repouso, passo alternado. O Godot usa regiões proporcionais da folha, sem exigir dimensões divisíveis por quatro. Ciclo de caminhada a 8 quadros por segundo, selecionado pelo deslocamento observado do estado do servidor.

## Vila (`village.png`)

Direção de arte: vila original vista de cima em pixel art, gramado vivo, água turquesa, caminhos antigos de pedra, chalé de telhado laranja, vegetação e flores nas bordas. Riacho na margem esquerda e clareira livre à direita para os combates. Praça vazia perto de 26% da largura e 50% da altura, onde o jogo desenha a fonte funcional. Sem personagens, inimigos, interface ou texto incorporados à imagem.

## Ações de classe (`class_actions.png`)

Folha com quatro colunas e três linhas: guerreiro, maga e patrulheira. Cada linha representa repouso, preparação, golpe/conjuração e recuperação. Gerada por IA com personagens originais e fundo transparente. O guerreiro usa a folha anterior para caminhar em quatro direções. As folhas `mage_walk.png` e `ranger_walk.png` agora acrescentam caminhada em quatro direções para as outras duas classes. Todas usam quatro colunas e quatro linhas, com quadros guiados pela distância percorrida.

## Inimigos (`enemies.png`)

Folha de quatro colunas e três linhas: limo de cristais, lobo cinzento e golem de pedra com musgo. As poses representam repouso, movimento, preparação e impacto. A primeira geração apresentou resíduos no fundo; a ferramenta de imagens foi usada novamente para limpar a transparência, preservando a composição. O arquivo integrado é a versão limpa.

O mapa permanece um fundo ilustrado, agora com máscaras de colisão alinhadas à casa, rio, rochas e massas de árvores. A ponte é transitável. As máscaras são aproximações das áreas sólidas, agora editáveis nos polígonos e camadas de `content/maps/*.tscn`; não são recortes por pixel. Há camadas nativas para terreno, decoração e primeiro plano, com uma paleta inicial de três recortes da nossa arte. Interiores e um TileSet completo ainda não existem.

Efeitos de corte, partículas, números, projéteis, áreas de aviso, escudos e cura são desenhados pelo Godot sobre as folhas, conforme o estado autoritativo do servidor. O NPC Lia e os itens interativos ainda usam desenhos simples por código. APK e desempenho em aparelhos Android reais ainda não foram validados.

## Expansão: mapas, chefes e habilidades

`forest.png` e `ruins.png` são mapas originais gerados por IA, integrados como regiões de 2304 × 1272 unidades, com câmera, máscaras de colisão aproximadas e objetos interativos definidos pelo jogo. As imagens de origem foram preservadas; não foram convertidas em um TileSet.

`bosses.png` contém três poses para a Matriarca dos Espinhos e três para o Arconte do Ocaso, em uma grade 3 × 2. A ferramenta de geração também foi usada para limpar o fundo, e a versão integrada possui transparência. `mage_walk.png` e `ranger_walk.png` mantêm as roupas das respectivas classes em dezesseis quadros por folha.

`skill_atlas.png` tem grade 5 × 4: três linhas de ícones das cinco habilidades de cada classe e uma linha com corte, fogo, gelo, raio e cura. Esses recursos são usados na barra, nos projéteis e nos efeitos de impacto. O Godot faz recortes proporcionais em tempo de renderização, sem editar destrutivamente as imagens.

Painéis e elementos interativos (baús, pilares, portais e santuários) são construídos por código. Ainda não há sprite de vestimenta individual para cada item equipado. A animação dos inimigos comuns combina poucas poses, espelhamento, deslocamento suavizado e patrulhas; ela ainda pode ser refinada.

## Recursos de animação e edição

Os atlas existentes agora são descritos pelos perfis de `content/animations/`: grade, quadros, duração, direção, espelhamento e ponto de apoio dos pés. A seleção entre repouso, caminhada, preparação, ataque, recuperação e morte pertence ao controlador de apresentação. O cálculo do combate continua no servidor.

As ilustrações não foram recortadas destrutivamente nem substituídas por novas imagens nesta migração. Os pincéis iniciais de terreno usam regiões do atlas de nossa própria vila; os mapas continuam com a ilustração de fundo e permitem conversão gradual para tiles pelo editor.
