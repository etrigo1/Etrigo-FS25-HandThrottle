🇵🇹 Português | [🇺🇸 Read in English](README.md)

# 🚜 Acelerador de Mão (Etrigo_HandThrottle)
**Versão atual:** 1.4.0.0  |  **Farming Simulator 25**  |  **Multijogador:** suportado

Um acelerador de mão a sério para todos os tratores. Na caixa manual fixas o acelerador ou as RPM e só mexes nas mudanças; num CVT fixas a velocidade como na alavanca de condução dos tratores modernos; e em qualquer caixa podes limitar as RPM máximas do motor.

---

## 🌟 Modos

A tecla de modo só percorre os modos que servem para a caixa do trator (e que estão ligados nas configurações):
- **Caixa manual:** sistema desligado → % → RPM → Limite → sistema desligado
- **CVT / caixa automática:** sistema desligado → km/h → Limite → sistema desligado

| Modo | Caixas | O que faz |
|---|---|---|
| **%** | Manual | Fixa a **posição do acelerador** (0–100 %), como a alavanca de mão de um trator antigo. Em ponto morto acelera em seco; com mudança engatada é o mesmo que carregar no pedal. Numa subida, as RPM caem. |
| **RPM** | Manual | Fixa as **RPM alvo** (ex.: 1800). O acelerador é ajustado sozinho para as manter a subir e a descer, até ao limite de potência do motor. Se nem a fundo chegar, reduz-se a mudança. |
| **km/h** | CVT / automática | Como a alavanca de condução dos CVT modernos: ao ligar **fica na velocidade atual** (parado: 1 km/h) e subir/descer mudam-na 1 km/h de cada vez. **Memória separada para a frente e para trás** (com o inversor manual). Não mexe na velocidade memorizada do cruise control do jogo. |
| **Limite** | Todas | O "corte" do motor: podes acelerar a fundo, mas as RPM **nunca passam** do valor definido. Começa nas RPM máximas e vais baixando. |

### Regras de condução
- **O pedal ganha sempre**: se carregares mais do que o acelerador de mão, conta o pé. No modo km/h, se passares o alvo em **5 km/h** com o pé, o modo fica em pausa.
- **Travar**: nos modos %, RPM e Limite o travão só suspende a mão enquanto travas; no modo km/h põe em pausa. Configurável por modo.

### Acelerador de mão ou cruise control, nunca os dois
Como o cruise control e o limitador de velocidade de um carro, que partilham os mesmos botões:

| Estado | HUD | Cruise control |
|---|---|---|
| **Sistema desligado** | não aparece | funciona normalmente |
| **Pausa** | `… OFF` | bloqueado |
| **Modo ligado** | aparece | bloqueado |

- Ligar um modo desliga o cruise control. Com o acelerador de mão ligado ou em pausa, as teclas do cruise control ficam desativadas e, se outra coisa o ligar, é desligado logo.
- Assim podes **pôr os mesmos botões** (ligar/desligar, subir, descer) no cruise control e no acelerador de mão: a tecla de modo decide quem eles controlam. Só a tecla de modo tem de ficar num botão só dela.
- Funciona com o cruise control do jogo e com o **Vehicle Inspector**.

### Ligar/desligar sem perder o valor
- A tecla **ligar/desligar** põe em pausa e guarda o modo e o valor (útil nas cabeceiras). Carrega outra vez e retoma: os modos %, RPM e Limite voltam ao mesmo valor; o modo km/h fica na **velocidade a que vais nesse momento**.
- **Memória por trator**: sair do trator ou desligar o motor põe em pausa e memoriza o que tinhas *nesse* trator. Nunca retoma sozinho (o trator não arranca por si). Dura enquanto o jogo estiver aberto.

### HUD que se pode mover
- Uma linha pequena no ecrã, ex.: `Acel. mão: 1800 RPM`, `Acel. mão: 12 km/h R` (R = marcha-atrás), `Acel. mão: máx 1600 RPM`.
- Tecla **mover HUD**: aparece o rato, arrasta-se com o botão esquerdo, botão direito repõe a posição de origem, carregar outra vez grava.

---

## 🎮 Controlos (todos alteráveis em Opções → Controlos)
| Ação | Tecla por defeito |
|---|---|
| Mudar modo | `Ctrl esq. + H` |
| Ligar/desligar (guarda modo e valor) | `Ctrl dir. + . do teclado numérico` |
| Subir (5 % / 50 RPM / 1 km/h / 50 RPM) | `Ctrl esq. + Page Up` |
| Descer | `Ctrl esq. + Page Down` |
| Mover HUD | `Ctrl dir. + 0 do teclado numérico` |

Subir/descer aceitam teclas, botões **ou um eixo analógico**: com um eixo, empurrar mais = muda mais depressa, centro = mantém.

> ⚠️ Atribui as ações de modo e de ligar/desligar a **botões**, não a um eixo analógico. Um eixo a passar pelo centro dispara-as repetidamente.

---

## ⚙️ Configurações (`modSettings/Etrigo_HandThrottle.xml`)
Criado sozinho no primeiro arranque. Edita-se com o jogo fechado; valores em falta ou inválidos voltam ao valor por defeito. Cada jogador tem o seu.

```xml
<handThrottle>
    <hud x="0.985" y="0.30" textSize="0.013"/>
    <modes>
        <percent  enabled="true" brakeOff="false" step="5"/>
        <rpm      enabled="true" brakeOff="false" step="50"/>
        <rpmLimit enabled="true" brakeOff="false" step="50"/>
        <speed    enabled="true" brakeOff="true"  step="1" pedalOffDifference="5"/>
    </modes>
    <general rememberPerVehicle="true" keyRepeatDelay="400" keyRepeatInterval="100"/>
</handThrottle>
```

| Opção | O que faz |
|---|---|
| `enabled` | Liga/desliga o modo (desligado não aparece na tecla de modo) |
| `brakeOff` | Travar põe esse modo em pausa (em vez de só o suspender enquanto travas) |
| `step` | Quanto sobe/desce por toque |
| `pedalOffDifference` | km/h acima do alvo, com o pé, que põem o modo km/h em pausa |
| `textSize` | Tamanho da letra do HUD |
| `rememberPerVehicle` | Memória por trator ao sair/desligar o motor |
| `keyRepeatDelay` / `keyRepeatInterval` | Tecla carregada: ms até repetir / ms entre repetições |

---

## 🔧 Compatibilidade
- Funciona em todos os tipos de veículo com motor que se conduzem (jogo base, DLCs e mods), exceto locomotivas.
- Modo km/h em marcha-atrás precisa do inversor manual (definição de mudança de sentido do jogo); sem ele, o modo km/h é só para a frente.
- O **FS25_RPMResponsiveSpeeds** também mexe nas RPM. Podem estar os dois carregados, mas desativa um deles se quiseres testar o outro isolado.
- Não grava nada no savegame.

## 📦 Instalação
Descarrega o `Etrigo_HandThrottle.zip` na página de [Releases](../../releases) e põe-no na pasta `Documentos/My Games/FarmingSimulator2025/mods`. Não descompactes.

## 📜 Histórico de versões
Ver [CHANGELOG.md](CHANGELOG.md).

---
**Autor:** Etrigo
