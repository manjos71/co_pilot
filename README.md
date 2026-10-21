# Co Pilot (ai.gcodeflow)

Assistente para motoristas de aplicativo. Lê as ofertas de corrida via serviço de
Acessibilidade e mostra um overlay neon com a recomendação **ACEITAR / AVALIAR / RECUSAR**.
Código 100% próprio, UI em Flutter (dark neon) e lado nativo em Kotlin.

## Como rodar

```bash
chmod +x setup.sh && ./setup.sh   # gera o scaffold Android (applicationId = ai.gcodeflow)
flutter run                       # com o aparelho conectado
```

No aparelho: abra o Co Pilot, toque em **ATIVAR** e habilite o serviço *Co Pilot* em
Configurações > Acessibilidade. Depois é só abrir o app de corridas.

## Arquitetura

| Camada | Arquivos | Responsabilidade |
| --- | --- | --- |
| Flutter | `lib/` | Painel, histórico, ajustes, tema neon |
| Ponte | `lib/bridge.dart` ↔ `MainActivity.kt` | MethodChannel `ai.gcodeflow/native` |
| Leitura | `OfferAccessibilityService.kt` | Coleta os textos da tela dos apps monitorados |
| Parser | `OfferParser.kt` | Extrai preço, km, minutos e nota (pt-BR) |
| Decisão | `DecisionEngine.kt` | Pontuação 0–100 nos modos Lucro / Equilibrado / Algoritmo |
| Overlay | `OverlayController.kt` | Cartão neon (`TYPE_ACCESSIBILITY_OVERLAY`) |
| Dados | `Store.kt` | Configurações e histórico locais (SharedPreferences) |

O Kotlin é o único dono do parsing, da pontuação e do overlay (funciona com o app
fechado). O Flutter só configura e exibe os resultados.

## Decisões de projeto

- **Sem permissões perigosas.** O overlay usa o contexto do serviço de acessibilidade,
  então não precisa de `SYSTEM_ALERT_WINDOW`, e o app nem declara `INTERNET` no release.
- **Escopo mínimo de leitura.** `accessibility_config.xml` restringe o serviço a
  `com.ubercab.driver` e `com.app99.driver`.
- **Só recomenda.** Não há clique automático nem aceite/recusa automática de corridas.
- **Pontuação:** atingir exatamente os mínimos configurados (R$/km e R$/h) vale 60 pontos;
  ≥ 60 = aceitar, ≥ 45 = avaliar, abaixo = recusar.

## Pontos a validar em aparelho real

1. Os nomes de pacote dos apps de motorista (`OfferAccessibilityService.SOURCES` e
   `accessibility_config.xml`) e o formato exato dos textos da oferta. Se algum app
   mostrar a oferta de outro jeito, ajuste só o `OfferParser.kt`.
2. O ícone do app (`@mipmap/ic_launcher`) é o padrão do Flutter até você colocar o seu.
3. Não tem teste automatizado ainda. O ideal é cobrir `OfferParser` e `DecisionEngine`
   com testes unitários usando textos reais capturados.
