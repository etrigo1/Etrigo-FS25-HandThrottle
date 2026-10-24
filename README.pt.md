🇵🇹 Português | [🇺🇸 Read in English](README.md)

# 🚜 Acelerador de Mão (Etrigo_HandThrottle)
**Versão atual:** 1.3.0.0  |  **Farming Simulator 25**  |  **Multijogador:** suportado

Um acelerador de mão a sério para tratores de **caixa manual**. Acabou-se levar o pé sempre no pedal numa subida longa e pesada: fixa-se o acelerador ou as RPM uma vez e só se mexe na caixa.

---

## 🌟 Funcionalidades

### Dois modos
| Modo | O que simula | Como se comporta |
|---|---|---|
| **%** | Alavanca de mão de um trator antigo, ligada ao pedal | Fixa a **posição do acelerador** (0–100 %). Em ponto morto acelera em seco; com mudança engatada é o mesmo que carregar no pedal. Numa subida, as RPM caem. |
| **RPM** | Motor com regulador de rotação | Fixa as **RPM alvo** (ex.: 1800). O acelerador é ajustado sozinho para as manter a subir e a descer, até ao limite de potência do motor. Se nem a fundo chegar, reduz-se a mudança. |

### Regras de condução
- **O pedal ganha sempre**: se carregares mais do que o acelerador de mão, conta o valor mais alto. Quando largas, volta o valor da mão.
- **Travar suspende** o acelerador de mão enquanto travas.
- **Cruise control ligado** → o acelerador de mão não atua.
- Só atua com **passagem de caixa manual** (caixa com mudanças e passagem manual). CVT e caixas automáticas ficam a cargo do jogo; o HUD mostra `OFF` e aparece um aviso.

### Ligar/desligar sem perder o valor
- A tecla **ligar/desligar** põe em pausa e guarda o modo e o valor (útil nas cabeceiras). Carrega outra vez e retoma exatamente onde estava.
- **Memória por trator**: sair do trator ou desligar o motor põe em pausa e memoriza o que tinhas *nesse* trator. Ao voltar, o HUD mostra `OFF`; carregas em ligar/desligar e retoma. Nunca retoma sozinho, para o trator não arrancar por si. A memória dura enquanto o jogo estiver aberto.

### HUD que se pode mover
- Uma linha pequena no ecrã, ex.: `Acel. mão: 1800 RPM`.
- Tecla **mover HUD**: aparece o rato, arrasta-se o HUD com o botão esquerdo, botão direito em cima repõe a posição de origem, e carregar outra vez grava.
- A posição fica gravada por jogador em `modSettings/Etrigo_HandThrottle.xml`.

---

## 🎮 Controlos (todos alteráveis em Opções → Controlos)
| Ação | Tecla por defeito |
|---|---|
| Mudar modo (OFF → % → RPM → OFF) | `Ctrl esq. + H` |
| Ligar/desligar (guarda modo e valor) | `Ctrl dir. + . do teclado numérico` |
| Subir (5 % / 50 RPM) | `Ctrl esq. + Page Up` |
| Descer (5 % / 50 RPM) | `Ctrl esq. + Page Down` |
| Mover HUD | `Ctrl dir. + 0 do teclado numérico` |

Com subir/descer carregado, o passo repete.

> ⚠️ Atribui as ações de modo e de ligar/desligar a **botões**, não a um eixo analógico. Um eixo a passar pelo centro dispara-as repetidamente.

---

## 🔧 Compatibilidade
- Funciona em todos os tipos de veículo com motor que se conduzem (jogo base, DLCs e mods), exceto locomotivas.
- O **FS25_RPMResponsiveSpeeds** também mexe no comportamento das RPM. Podem estar os dois carregados, mas desativa um deles se quiseres testar o outro isolado.
- Não grava nada no savegame.

## 📦 Instalação
Descarrega o `Etrigo_HandThrottle.zip` na página de [Releases](../../releases) e põe-no na pasta `Documentos/My Games/FarmingSimulator2025/mods`. Não descompactes.

## 📜 Histórico de versões
Ver [CHANGELOG.md](CHANGELOG.md).

---
**Autor:** Etrigo
