# Arte do protótipo

As duas imagens desta pasta foram geradas com a ferramenta de imagens da OpenAI durante o desenvolvimento, a partir de descrições para este projeto. Não são recursos extraídos do Warspear Online. Os arquivos de origem foram copiados para o repositório sem edição destrutiva.

## Guardião (`guardian.png`)

Direção de arte: personagem original de RPG em pixel art, cabelo castanho, túnica e capa azul-petróleo, ombreiras de aço com bordas de bronze, botas de couro e espada curta. Fundo transparente. Folha quadrada de 4 colunas × 4 linhas, com corpo inteiro e quadros centrados. Linhas: sul, oeste, leste e norte; colunas: repouso, passo, repouso, passo alternado. O Godot usa regiões proporcionais da folha, sem exigir dimensões divisíveis por quatro. Ciclo de caminhada a 8 quadros por segundo, selecionado pelo deslocamento observado do estado do servidor.

## Vila (`village.png`)

Direção de arte: vila original vista de cima em pixel art, gramado vivo, água turquesa, caminhos antigos de pedra, chalé de telhado laranja, vegetação e flores nas bordas. Riacho na margem esquerda e clareira livre à direita para os combates. Praça vazia perto de 26% da largura e 50% da altura, onde o jogo desenha a fonte funcional. Sem personagens, inimigos, interface ou texto incorporados à imagem.

O mapa é um fundo estático ilustrado. Não há tiles individuais, camadas de oclusão, interiores ou colisões de cenário nesta entrega. O personagem ainda pode andar sobre elementos decorativos; a arena limita somente as bordas externas. O ataque mantém um efeito desenhado por código e os limos mantêm a arte geométrica anterior. APK e desempenho em aparelhos Android reais não foram validados.
