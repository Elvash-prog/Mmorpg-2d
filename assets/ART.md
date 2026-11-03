# Arte do protótipo

As duas imagens desta pasta foram geradas com a ferramenta de imagens da OpenAI durante o desenvolvimento, a partir de descrições para este projeto. Não são recursos extraídos do Warspear Online. Os arquivos de origem foram copiados para o repositório sem edição destrutiva.

## Guardião (`guardian.png`)

Direção de arte: personagem original de RPG em pixel art, cabelo castanho, túnica e capa azul-petróleo, ombreiras de aço com bordas de bronze, botas de couro e espada curta. Fundo transparente. Folha quadrada de 4 colunas × 4 linhas, com corpo inteiro e quadros centrados. Linhas: sul, oeste, leste e norte; colunas: repouso, passo, repouso, passo alternado. O Godot usa regiões proporcionais da folha, sem exigir dimensões divisíveis por quatro. Ciclo de caminhada a 8 quadros por segundo, selecionado pelo deslocamento observado do estado do servidor.

## Vila (`village.png`)

Direção de arte: vila original vista de cima em pixel art, gramado vivo, água turquesa, caminhos antigos de pedra, chalé de telhado laranja, vegetação e flores nas bordas. Riacho na margem esquerda e clareira livre à direita para os combates. Praça vazia perto de 26% da largura e 50% da altura, onde o jogo desenha a fonte funcional. Sem personagens, inimigos, interface ou texto incorporados à imagem.

## Ações de classe (`class_actions.png`)

Folha com quatro colunas e três linhas: guerreiro, maga e patrulheira. Cada linha representa repouso, preparação, golpe/conjuração e recuperação. Gerada por IA com personagens originais e fundo transparente. O guerreiro usa a folha anterior para caminhar em quatro direções. Maga e patrulheira têm pose própria, espelhamento horizontal e oscilação de caminhada; ainda precisam de folhas completas em quatro direções.

## Inimigos (`enemies.png`)

Folha de quatro colunas e três linhas: limo de cristais, lobo cinzento e golem de pedra com musgo. As poses representam repouso, movimento, preparação e impacto. A primeira geração apresentou resíduos no fundo; a ferramenta de imagens foi usada novamente para limpar a transparência, preservando a composição. O arquivo integrado é a versão limpa.

O mapa permanece um fundo ilustrado, agora com máscaras de colisão alinhadas à casa, rio, rochas e massas de árvores. A ponte é transitável. As máscaras definidas em `scripts/map_rules.gd` são aproximações das áreas sólidas; não são recortes por pixel. Não há tiles individuais, interiores ou oclusão por camadas.

Efeitos de corte, partículas, números, projéteis, áreas de aviso, escudos e cura são desenhados pelo Godot sobre as folhas, conforme o estado autoritativo do servidor. O NPC Lia e os itens interativos ainda usam desenhos simples por código. APK e desempenho em aparelhos Android reais ainda não foram validados.
