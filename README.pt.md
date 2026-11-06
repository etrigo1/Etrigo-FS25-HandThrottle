🇵🇹 Português | [🇺🇸 Read in English](README.md)

# 🚜 Acelerador de Mão (FS25_HandThrottle)
**Versão atual:** 1.7.0.2  |  **Farming Simulator 25**  |  **Multijogador:** suportado

Um acelerador de mão a sério para todos os tratores. Na caixa manual fixas o acelerador ou as RPM e só mexes nas mudanças; num CVT fixas a velocidade como na alavanca de condução dos tratores modernos; e em qualquer caixa podes limitar as RPM máximas do motor. Nunca trabalha ao mesmo tempo que o cruise control, por isso os dois podem partilhar os mesmos botões, e com o CVT Addon controla o acelerador de mão dele com botões.

---

## 🌟 Modos

A tecla de modo só percorre os modos que servem para a caixa do trator (e que estão ligados nas configurações):
- **Caixa manual:** sistema desligado → % → RPM → Limite → sistema desligado
- **CVT / caixa automática:** sistema desligado → km/h → Limite → sistema desligado
- **CVT com o [CVT Addon](https://github.com/SbSh-DNA-ModDing/FS25_CVT_Addon_Dev):** sistema desligado → % → km/h → Limite → sistema desligado

| Modo | Caixas | O que faz |
|---|---|---|
| **%** | Manual (CVT com o CVT Addon) | Fixa a **posição do acelerador** (0–100 %), como a alavanca de mão de um trator antigo. Em ponto morto acelera em seco; com mudança engatada é o mesmo que carregar no pedal. Numa subida, as RPM caem. Numa CVT com o CVT Addon passa a mexer no **acelerador de mão do CVT Addon** (ver abaixo). |
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

### Arrasto ao ralenti (manual com embraiagem)
Com a caixa do jogo em **"manual com embraiagem"**, uma mudança engatada e a embraiagem solta (ou a patinar), o trator **anda devagar ao ralenti sem acelerar**, como um trator real. O motor puxa com a força que tem ao ralenti, mas nunca passa do ralenti (a descer faz de travão-motor). Soltar a embraiagem de repente com carga continua a poder ir abaixo, como no jogo base.
- Não faz nada com a embraiagem carregada, em ponto morto, a meter a mudança, a travar, com o travão de mão, com o cruise control, com a IA ou sem ninguém a conduzir.
- A força cresce com o curso da embraiagem: quase nada mal a levantas, toda com ela solta (a curva afina-se com `clutchCurve`).
- Com o pé no acelerador ganha o maior dos dois, como num trator com regulador: carregar mais do que o arrasto = manda o pé.
- O acelerador de mão ganha: o % acima de 0 e o modo RPM funcionam como antes; com o limite de RPM vale o teto mais baixo.
- Vem ligado; desliga-se com `<idleCreep enabled="false"/>` no ficheiro de configurações. Desliga-se sozinho com o **More Realistic** carregado (que já faz o mesmo).

### Acelerador de mão do CVT Addon com botões
O [CVT Addon](https://github.com/SbSh-DNA-ModDing/FS25_CVT_Addon_Dev) tem o seu próprio acelerador de mão (mais rotações, ex.: hidráulica mais rápida em carregadoras e escavadoras), mas só num eixo analógico. Com o CVT Addon instalado, o modo **%** também aparece nos veículos CVT e mexe nesse acelerador de mão com os botões subir/descer, sem precisar de uma alavanca.
- Pausa, sistema desligado, desligar o motor ou sair do veículo põem-no outra vez a 0.
- Se também usares uma alavanca no eixo do CVT Addon, ganha a última que mexeu. Com o acelerador de mão desligado, este mod nunca mexe no valor da alavanca.
- Sem o CVT Addon nada muda: no jogo base a hidráulica não depende das rotações do motor.

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

## ⚙️ Configurações (`modSettings/HandThrottle.xml`)
Criado sozinho no primeiro arranque (um `Etrigo_HandThrottle.xml` antigo é aproveitado uma vez). Edita-se com o jogo fechado; valores em falta ou inválidos voltam ao valor por defeito. Cada jogador tem o seu.

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
    <idleCreep enabled="true" torque="1" clutchCurve="1"/>
    <debug enabled="false"/>
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
| `idleCreep enabled` | Liga/desliga o arrasto ao ralenti (manual com embraiagem) |
| `idleCreep torque` | Força do arrasto, 0.1–1 (1 = toda a força que o motor tem ao ralenti) |
| `idleCreep clutchCurve` | Como a força cresce ao largar a embraiagem, 0.3–3. `1` = a direito (a meio do curso, metade da força); abaixo de 1 morde mais cedo (ex.: `0.5`); acima de 1 é mais suave no início e só puxa a sério no fim (ex.: `2`) |
| `debug enabled` | Log de diagnóstico no `log.txt` do jogo (linhas que começam por `[HandThrottle DEBUG]`), para ajudar a encontrar problemas. Deixa desligado para jogar normalmente. Também se liga/desliga durante o jogo com o comando de consola `ethtDebug [on\|off]` |

---

## 🔧 Compatibilidade
- Funciona em todos os tipos de veículo com motor que se conduzem (jogo base, DLCs e mods), exceto locomotivas.
- Modo km/h em marcha-atrás precisa do inversor manual (definição de mudança de sentido do jogo); sem ele, o modo km/h é só para a frente.
- **Vehicle Inspector**: as teclas do cruise control dele ficam bloqueadas com o acelerador de mão ligado ou em pausa, tal como as do jogo.
- **CVT Addon**: o modo % controla o acelerador de mão dele nos veículos CVT (ver acima).
- **Advanced Damage System (ADS)**: com a embraiagem gasta pelo ADS, o arrasto patina em vez de ir abaixo; com a embraiagem avariada não faz nada. Quem manda na embraiagem é o ADS (o mod só lê).
- O **FS25_RPMResponsiveSpeeds** também mexe nas RPM. Podem estar os dois carregados, mas desativa um deles se quiseres testar o outro isolado.
- Não grava nada no savegame.

## 📦 Instalação
Descarrega o `FS25_HandThrottle.zip` na página de [Releases](../../releases) e põe-no na pasta `Documentos/My Games/FarmingSimulator2025/mods`. Não descompactes.

> Até à 1.7.0.1 o ficheiro chamava-se `Etrigo_HandThrottle.zip`: apaga-o da pasta mods, para o jogo não carregar o mod duas vezes. As tuas configurações mantêm-se.

## 📜 Histórico de versões
Ver [CHANGELOG.md](CHANGELOG.md).

---
**Autor:** Etrigo
