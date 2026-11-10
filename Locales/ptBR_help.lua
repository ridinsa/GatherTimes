-- ptBR_help.lua : texto em português do painel Ajuda (um bloco por tópico, veja UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.ptBR = GT.locales.ptBR or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.ptBR["Start"] = "Início"
GT.locales.ptBR["Panels"] = "Painéis"
GT.locales.ptBR["Tips"] = "Dicas"
GT.locales.ptBR["HUD"] = "HUD"
GT.locales.ptBR["Cmds"] = "Cmds"
GT.locales.ptBR["Credits"] = "Créditos"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD do minimapa" .. E .. [[

Transforma o minimapa real em um mapa grande e transparente que ocupa a tela, com anéis opcionais, letras da bússola, direção, indicadores que priorizam pontos prontos e progresso da rota. Seus marcadores de coleta continuam nele.

]] .. H .. "Ligar / desligar" .. E .. [[

- Clique com o botão esquerdo no botão HUD do minimapa na janela principal.
- Digite /gt hud (ou /gthud).
- Use uma tecla: Opções do HUD > aba Mapa > Tecla de atalho (clique no botão da tecla e pressione uma tecla; Esc cancela, Limpar remove). Também fica em Teclas de atalho > AddOns > GatherTimes.
- Opcional: ative para ligar automaticamente quando o rastreamento de coleta estiver ativo (Opções do HUD > Opções).

]] .. H .. "Opções do HUD (clique direito no botão HUD)" .. E .. [[

- Mapa: tamanho do HUD, opacidade do mapa (0% = o mapa fica em branco e só os marcadores aparecem; 100% = opaco; 10 níveis), zoom do minimapa, tecla de atalho.
- Anéis: raio do anel, segundo anel, espessura, suavidade, estilo do anel (linha, listras ou pontos: o botão alterna entre eles), densidade do anel, cores dos anéis (Cor do anel... abre o seletor: controles deslizantes para cada anel e um botão Cor aleatória para a aba do anel aberta), letras da bússola (N E S W), indicador de direção, indicador de coleta priorizando pontos prontos (ponto pronto mais próximo ou, se não houver, respawn mais próximo) e indicador de progresso da rota (etapa planejada atual). Cada indicador pode ser ligado ou desligado.
- Rastreamento: botão de rastreamento enquanto o HUD está ligado (tamanho de 20-80 px e posição) e o que ele faz quando o HUD está desligado (auto, own ou stock).
- Opções: girar o mapa com o jogador, seta do jogador, ocultar HUD enquanto estiver montado, ligar automaticamente com o rastreamento de coleta, restaurar o HUD após /reload ou login, ocultar skins de addons do minimapa, diagnósticos.
- Perfis: salve várias aparências, alterne entre elas ou exclua. Os perfis são compartilhados por todos os personagens; cada personagem guarda o próprio.
- Redefinir perfil restaura os padrões.]]

T.credits = H .. "GatherTimes 0.24.3" .. E .. [[

Autor: miRidinsa
Site: https://github.com/ridinsa/
Licença: GNU GPL v3 ou posterior (veja o arquivo LICENSE na pasta do addon).

]] .. H .. "Bibliotecas" .. E .. [[

- HereBeDragons-2.0 e HereBeDragons-Pins-2.0 por Nevcairiel: posições dos marcadores no minimapa e no mapa-múndi.
- LibStub e CallbackHandler-1.0 (bibliotecas WoW Ace): carregamento de bibliotecas e callbacks.

]] .. H .. "Nome aleatório" .. E .. [[

Uma cópia incorporada do módulo HideUnitNames (o addon independente com o mesmo nome também é compatível: quando ele é carregado, esta cópia dá lugar a ele).

]] .. H .. "Addons auxiliares" .. E .. [[

- HereBeDragons: necessário para os marcadores.
- GatherMate2: os dados de pontos dele podem ser importados.
- TomTom: waypoints para a seta e as rotas.

]] .. H .. "Traduções" .. E .. [[

Os arquivos de idioma na pasta Locales. Obrigado a todos que ajudaram com eles e a todos que enviaram um relatório de depuração.]]

T.start = H .. "Bem-vindo ao GatherTimes" .. E .. [[

Acompanha quando ervas e minérios reaparecem na zona em que você está, lembra onde os nós aparecem e mostra tudo na janela principal, no minimapa e no mapa-múndi.

]] .. H .. "Início rápido" .. E .. [[

1. Abra a janela com /gt.
2. Clique em Pontos (embaixo) e marque as ervas / minérios que você coleta.
3. Colete. Um timer começa assim que você pega o saque de um nó.
4. Acompanhe a tabela na janela principal. Quando um nó estiver pronto, você recebe um alerta na tela, um som e um sinal quando estiver perto.

]] .. H .. "A janela principal" .. E .. [[

- Lista suspensa (no topo): mostrar cada nó marcado, ou apenas um.
- As contagens do inventário aparecem alinhadas à direita na lista de itens aberta; a contagem fica oculta no item fechado e selecionado.
- Tabela: uma linha por grupo de nós próximos. G1, G2... são os números de grupo que você também vê no mapa.
- Status: Waiting = todos os nós ainda estão em contagem regressiva. 2/3 up = alguns já voltaram. Ready = todos voltaram. Idle = nenhum timer em andamento.
- Um nó fica Ready por um tempo depois de reaparecer e depois vira Idle (você escolhe quanto tempo em Opções > Geral > Status pronto dura).
- Os alertas são enviados só uma vez por timer. Use Opções > Geral para as distâncias mínima e máxima, e Pontos > Alert para ativar ou silenciar os alertas de cada recurso.
- Botão Minimap HUD On/Off: o clique esquerdo liga ou desliga o HUD, o clique direito abre as configurações do HUD. O texto fica verde quando o HUD está ligado e cinza quando está desligado.
- O rótulo do servidor e do modo de jogo aparece abaixo da tabela de timers.
- Os 5 botões de baixo abrem os painéis. Clique de novo no mesmo botão para fechar o painel.
- Arraste a barra de título para mover a janela. O título mostra a zona em que você está.
- O botão ? na barra de título abre esta ajuda.
- O botão - na barra de título minimiza a janela para uma barra fina ao longo do topo da tela. Clique direito para as opções de minimizar. Na barra: a lista de itens, um chip por grupo, o ouro da sessão e o botão "+", que devolve a janela. Dois cliques direitos no ouro para zerar a sessão (o resumo é impresso antes no chat).

]]

T.panels = H .. "Timers" .. E .. [[

Cada timer em andamento, os prontos primeiro (Grp, Nó, Tempo), além dos totais da sua sessão. Clear waypoint remove a seta. Show summary abre o resumo da sessão (itens, valor em ouro e ouro por hora) em uma caixa que você pode copiar. Reset session imprime primeiro o resumo, depois reinicia o cronômetro da sessão e zera as contagens.

]] .. H .. "Pontos" .. E .. [[

Escolha o que rastrear e como.
- On: marque para rastrear uma erva / minério.
- Min: tempo de reaparecimento em minutos. Digite um número novo e pressione Enter.
- Col: cor do nó no mapa e nas listas. Clique esquerdo = próxima cor, clique direito = cor anterior.
- Alert: ativa ou silencia os alertas de pronto deste recurso. A verificação não depende de o recurso estar exibido na lista principal.
- Sound: som do alerta. Clique = próximo (toca uma prévia), clique direito = anterior.
- Dropdown: Todos / Ervas / Minérios. List all: mostra todos os nós, não só os da zona atual.
- Nodes per group: quantos nós próximos formam um grupo (G1, G2...).
- Nodes up per group: quantos precisam ter voltado para o grupo contar como pronto.
- Select All, Select None, Reset (volta aos tempos padrão).
- A lista de itens aberta na janela principal também mostra quantos desse recurso estão na bolsa; o botão selecionado não mostra contagem.

]] .. H .. "Nav" .. E .. [[

- Rota: escolha uma erva / minério ativado ou todos os recursos ativados, e Build route traça um caminho pelos timers ativos. Next step avança para o próximo passo, Clear route remove a rota. As opções incluem apenas nós prontos, desenhar a rota no mapa, seta automática, número máximo de nós e janela de tempo. Priorize os recursos com estoque baixo para dar preferência aos que estão abaixo da meta de estoque (só na bolsa).
- Marcas: mostrar os pinos de aparecimento no mapa e no minimapa, os rótulos de grupo (G1, G2...), pontos para os outros itens, ocultar os nós coletados nesta sessão, clique direito em um nó para o menu do grupo, deslocamento de nó durante a coleta e Refresh pins. O filtro de nós coletados é zerado quando você reinicia a sessão.
- Seta: integração com TomTom, seta para o nó mais próximo, avanço automático para o próximo nó da rota, distância da seta, Waypoint to nearest. Precisa do addon TomTom.

]] .. H .. "Tempos" .. E .. [[

Por nó: Now = o tempo de reaparecimento em uso. Learned (n) = a faixa medida nas suas próprias visitas, o valor rápido típico (por exemplo 10.5-12.0), n = número de amostras (laranja abaixo de 5, amarelo 5-9, verde 10 ou mais; um tempo aprendido em verde significa que o valor típico é mais rápido que Now; * = valor do item inteiro, exibido no modo Per zone). Os reaparecimentos variam, então conte com um valor dentro dessa faixa. Apply / auto-apply usam o valor típico (o da direita). Taken = com que frequência um nó foi encontrado vazio.
- Learned times: Per item (um tempo aprendido por erva / minério, o padrão) ou Per zone (a zona em que você está, quando ela tem 5 amostras).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (mais curto ou mais longo, nunca mais que o dobro do tempo de fábrica). A chave de zona fica em Opções > Geral.
- Apply all faster copia os tempos aprendidos para Now. Reset learned timings os apaga.

]] .. H .. "Opções" .. E .. [[

- Geral: alerta na tela e Alert time, distância mínima e máxima para o alerta de pronto (0 desativa esse limite), alerta quando o chat anuncia manutenção (cor do piscar 1-7), aviso de vida baixa (Hardcore), Status pronto dura, e Mostrar só timers e pinos da zona em que estou.
- Exibição: tamanho do texto do mapa, tamanho da janela, semitransparente ao mover, manter janelas visíveis (ESC não as fecha), e dica do item ao passar o mouse. A lista de idioma fica em Look; ela vale depois de recarregar a interface (mostrado como "w/reload").
- Look: Idioma, Frame skin (temas de cor para janelas e dicas; Pastel Pink e Sakura usam texto escuro com contorno fino), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, ou Friends se o cliente tiver) e Font size (80% a 130%). Coreano, chinês, japonês e russo mantêm a própria fonte, então a escolha de fonte é substituída por uma nota para eles.
- Ferram.: estado do addon e dos auxiliares, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (compartilhar pontos com amigos), Copy debug report (um bloco de texto para um relatório de bug), Reset timers, Start a new session at login, e o registro de erros.

]] .. H .. "Inventário e resumo da sessão" .. E .. [[

A lista de itens aberta mostra a contagem na bolsa ao lado de cada item; o botão do item selecionado a oculta. O painel Timers mostra os totais da sessão. Show summary abre o mesmo resumo; Reset session o imprime primeiro e depois zera as contagens e reinicia o relógio da sessão. Só conta o saque de coleta reconhecido. Reset session também limpa o filtro de nós coletados, que vale só para a sessão.

]] .. H .. "Nome aleatório" .. E .. [[

Clique direito no botão Opções da janela principal para abri-lo (outro clique direito fecha). Ele oculta o seu próprio nome na tela, para transmissões ou capturas. Os outros jogadores continuam vendo o seu nome real.
- Disguise names: liga ou desliga o disfarce. Enquanto ele estiver ligado, os nomes dos outros jogadores também ficam ocultos (pelas configurações de nome do jogo, restauradas ao desligar).
- Hide party / raid names: oculta separadamente os rótulos de nome de grupo e de raide na sua tela.
- Fake player name / Fake pet name: os nomes exibidos no lugar. Digite um nome e pressione Enter ou Apply. Até 12 caracteres.
- Randomize Names: escolhe nomes aleatórios novos e um nível falso. O controle Random level range define o nível máximo. Opacity deixa o fundo da janela mais transparente, mantendo o texto legível.
- Exibido em: seus quadros de unidade (também quando você se seleciona ou seleciona seu pet), a dica da unidade, o título da janela de personagem e o chat. Com o disfarce ligado, os nomes de personagem correspondentes também ficam ocultos nas dicas de itens.
- Comandos: /hun (liga ou desliga o disfarce), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Se o addon independente HideUnitNames estiver carregado, o Nome aleatório daqui é desligado. Use esse addon.

]]

T.tips = H .. "Grupos" .. E .. [[

Nós próximos são tratados como um só grupo, então você vê quando o grupo inteiro voltou, em vez de cada nó separadamente. Com One shared timer per group (painel Tempos), o grupo tem um único timer.

]] .. H .. "Corrigir um nó (mapa-múndi)" .. E .. [[

Clique direito no texto de um timer ou em um pino de nó no mapa-múndi para abrir um pequeno menu (ative em Nav > Marcas):
- Este nó está vazio: outra pessoa pegou.
- Grupo pego por alguém: o grupo inteiro já tinha sido coletado.
- Mover este nó para grupo: coloque-o em outro grupo (1, 2, 3... ou New).
- Digite uma nota curta e clique em Save note para prender um lembrete a esse nó. Passe o mouse sobre o nó para ver a nota. As notas são salvas junto com o nó.
O minimapa nunca abre este menu. Você pode desativá-lo em Nav > Marcas.

]] .. H .. "Como os tempos de reaparecimento são aprendidos" .. E .. [[

Toda vez que um nó volta e você pega o saque dele, é guardado o tempo desde o saque do qual ele é o reaparecimento (em um grupo com vários nós voltando juntos, é o mais antigo dos saques recentes, não o mais novo). O addon ignora intervalos muito curtos e muito longos, e depois mostra em Tempos o valor do quarto mais rápido até a mediana (típica) das suas amostras, arredondado para 15 segundos. Apply e auto-apply usam a mediana. São necessárias 3 amostras para mostrar um valor e 5 para aplicá-lo automaticamente.

]] .. H .. "Compartilhar nós com amigos" .. E .. [[

Opções > Ferram. > Export my spots (ou /gt export) mostra os seus próprios nós como uma linha de texto. Clique na caixa, pressione Ctrl+C e envie para um amigo. Ele usa Import spots (ou /gt import), cola com Ctrl+V e clica em Import. Só o item, a zona e a posição são compartilhados, sem timers nem contagens. Nós que ele já tem ficam como estão, e um texto cortado no caminho é recusado em vez de importado pela metade.

]] .. H .. "Addons auxiliares" .. E .. [[

- HereBeDragons: necessário para os pinos no mapa e no minimapa. Instale.
- GatherMate2: Opções > Ferram. > Import GatherMate2 adiciona os locais de nós que ele conhece.
- TomTom: faz a seta e os waypoints das rotas aparecerem.

]] .. H .. "Algo errado?" .. E .. [[

- Sem pinos: instale HereBeDragons. Opções > Ferram. mostra o que foi encontrado.
- Os timers não começam: digite /gt debug e pegue o saque de um nó; o addon mostra o que está vendo.
- Os erros aparecem em Opções > Ferram. > Error log (clique, Ctrl+A, Ctrl+C para copiar).
- Para relatar um problema ou conflito com outro addon: Opções > Ferram. > Copy debug report (ou /gt report), copie o texto e cole no relatório.
- Nó ou grupo errado: clique direito nele no mapa-múndi.]]

T.cmds = H .. "Comandos slash" .. E .. [[

/gt - abre ou fecha a janela principal
/gt list - timers ativos no chat
/gt stats - totais da sessão no chat
/gt yield - rendimentos salvos por zona e item (top 10 zonas)
/gt yield current - totais de rendimento da zona atual
/gt debug - mensagens de detecção de saque ligadas / desligadas
/gt profile start | stop | report - perfila o laço dos timers
/gt hud - minimapa HUD (veja abaixo)
/gt min - minimiza para a barra, ou traz a janela de volta
/gt dock - a barra empurra para baixo os quadros superiores do jogo (ligado) ou só os cobre (desligado)
/gt export - mostra os seus próprios nós como texto para compartilhar
/gt import - importa nós do texto de um amigo
/gt report - relatório de depuração para copiar em um relatório de bug
/gthud - igual a /gt hud
/hun - Nome aleatório (veja Painéis > Opções > Nome aleatório)

]] .. H .. "Comandos do HUD" .. E .. [[

/gthud - liga ou desliga o HUD
/gthud on | off
/gthud config - abre as configurações do HUD
/gthud size 800 - tamanho do HUD (150 a 1400)
/gthud alpha 0.5 - opacidade do mapa (0 a 1)
/gthud zoom 3 - zoom do minimapa (0 a 5)
/gthud rotate - girar com o jogador ligado / desligado
/gthud ring 150 - raio do anel em px (0 = desligado)
/gthud ring2 300 - segundo anel
/gthud ringthick 2 - espessura do anel (1 a 10)
/gthud ringseg 96 - suavidade do anel (8 a 256)
/gthud ringstyle solid | stripes | dots - estilo do anel
/gthud ringdensity 24 - listras ou pontos ao redor do anel (4 a 128)
/gthud ringcolor 1 1 1 0.8 - vermelho verde azul opacidade
/gthud ringcolor2 1 1 1 0.8 - cor do segundo anel
/gthud dirs - letras da bússola ligadas / desligadas
/gthud heading - leitura de direção ligada / desligada
/gthud tracking - botão de rastreamento ligado / desligado
/gthud tracksize 50 - tamanho do botão de rastreamento (20 a 80)
/gthud trackpos 0 0 - deslocamento do botão de rastreamento para o estado atual do HUD
/gthud trackmode auto | own | stock - botão de rastreamento com o HUD desligado
/gthud arrow - seta do jogador ligada / desligada
/gthud addons - ocultar skins / botões de addons do minimapa ligado / desligado
/gthud scan - varredura profunda de addons do minimapa ligada / desligada
/gthud mountfade - ocultar o HUD montado ligado / desligado
/gthud autogather - ligar automaticamente com o rastreamento de coleta ligado / desligado
/gthud restore - restaurar o HUD após /reload ou login ligado / desligado
/gthud profile - lista perfis; /gthud profile <n> troca ou cria um
/gthud profile delete <n> - apaga um perfil (Default e o perfil ativo não podem ser apagados)
/gthud status | info | frames | debug - status, diagnóstico ou mensagens de depuração
/gthud reset - redefine o perfil atual
/gthud help - mostra a ajuda dos comandos]]

GT.helpText.ptBR = T
