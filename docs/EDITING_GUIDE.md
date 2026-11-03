# Editar conteúdo e mapas sem mudar as regras do jogo

Abra `project.godot` no **Godot 4.6.3 padrão**. O jogo continua sendo iniciado por F5. Faça uma cópia ou um commit antes de alterar conteúdo.

## Ajustar uma habilidade ou um equipamento

1. No painel de arquivos, abra `content/game_catalog.tres`.
2. No Inspector, expanda `Entries` e selecione o recurso pelo seu `Id`, por exemplo `skill.mage.fireball`.
3. Expanda `Data` e ajuste os valores existentes: `cost`, `cd`, `power`, `range` e `desc`.
4. Para itens, use os campos de vida, energia, defesa, velocidade, poder e crítico. `class_id` vazio significa item comum às classes.
5. Salve e inicie uma nova partida com F5. O catálogo é validado antes do jogo.

Preserve os IDs e índices dos registros existentes. Alterar o nome de exibição é diferente de renomear o ID. Referências como `quest.boss_ruins` e `class.mage` precisam continuar apontando para registros válidos. Novos tipos de habilidade e novas mecânicas exigem código; o catálogo não inventa o comportamento.

## Pintar terreno

1. Abra `content/maps/vale.tscn`, `forest.tscn` ou `citadel.tscn` em 2D.
2. Selecione o nó `Terrain` e abra o editor de TileMap.
3. A paleta inicial usa três recortes de nossa arte: grama (célula de atlas 27,17), pedra (13,18) e água (2,5).
4. Pinte dentro dos limites da região. Os tiles têm 32 unidades; a navegação usa células de 16.
5. Salve a cena e inicie o projeto por F5.

A água possui o dado `blocked = true` e bloqueia movimento e projéteis quando pintada em `Terrain`. Grama e pedra são transitáveis. A paleta é uma base funcional para edição, não um TileSet completo com todas as bordas e transições. O fundo ilustrado continua visível sob as células que você não pintar.

## Separar decoração, primeiro plano e colisão

- `Decoration`: pintura visual, sem bloquear movimento.
- `Foreground`: pintura visual acima dos personagens.
- `CollisionTiles`: toda célula pintada bloqueia. Essa camada tem alpha zero para não exibir a textura no jogo; você pode aumentar temporariamente o alpha de Modulate durante a edição e voltar a zero antes de salvar.
- `Collision`: contém corpos com `CollisionPolygon2D`. Selecione `Shape` e use as ferramentas de edição do polígono no editor 2D para mover seus vértices.

O servidor usa os polígonos e as células dessas mesmas cenas. Não edite uma segunda lista de retângulos em scripts. Para visualizar a geometria durante o jogo, inicie com `--debug-collisions`.

Mantenha rotação zero e escala um no nó raiz da região. Filhos e polígonos podem ser transformados. A propriedade `Dimensions` da região ajusta a escala da imagem de fundo; ajuste também `Walk Rect` quando mudar os limites navegáveis.

## Mover baús, NPCs, portais e inimigos

1. Expanda `Objects` na cena do mapa.
2. Selecione um marcador e mova-o com o gizmo do editor.
3. Preserve seu `Object Id`. Baús e inimigos usam `Definition Id`, como `item.travel_coat` ou `enemy.wolf`.
4. Portais usam `Properties → target_id`, que aponta para outro marcador de portal, e `arrival_offset`, a distância de chegada em relação a ele.
5. Salve e reinicie a partida.

Mover o marcador de destino de um portal também move seu ponto de chegada. Os pontos de objetos precisam ser transitáveis. Não duplique IDs ao duplicar marcadores. O jogo atual ainda associa parte do progresso de coleta aos índices existentes; adicionar novos objetos exige conferir as regras da missão correspondente.

Em ferramentas e testes, `world.reload_map_geometry()` atualiza geometria, índices, referências e navegação. Para jogar após editar cenas, o fluxo recomendado é reiniciar a partida; não há um editor de mundo multiplayer em runtime.

## Ajustar as animações

Abra um perfil em `content/animations/`, como `hero_mage.tres`. Cada clip tem um estado, textura, grade, linha, quadros e durações. O ponto de apoio dos pés (`Foot Anchor`) é proporcional à imagem, não um deslocamento no mapa. Preserve-o para evitar que o personagem pareça saltar entre poses.

`walk` usa `distance_per_frame`, enquanto clips de tempo usam `durations`. Os seis estados obrigatórios são repouso, caminhada, preparação, ataque, recuperação e morte. Mudanças visuais não mudam automaticamente o instante em que o servidor calcula o dano.

## Alterar as janelas

Abra as cenas de `content/ui/` e edite posições, tamanhos, textos fixos e estilos no Godot. Preserve os nomes dos nós usados pelo controlador, como `Close`, `MageCard`, `QuestScroll`, `Stats` e `Equip`. Os conteúdos variáveis (atributos, missões, inventário e nomes das habilidades) são preenchidos pelo jogo.

## Verificar antes de entregar

Na pasta do projeto:

```sh
godot --headless --editor --import --path . --quit
python3 tests/run_checks.py
# Inclui dois processos de rede local:
python3 tests/run_checks.py --network
```

Os testes verificam que pintar colisões muda a navegação, que mover marcadores muda a configuração usada pelo jogo e que sinais das janelas continuam acionando as regras. Eles não substituem conferir visualmente o mapa e experimentar sua jogabilidade.
