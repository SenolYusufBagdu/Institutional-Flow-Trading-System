# Institutional Flow Trading System

### Real-Time Market Intelligence Panel for MetaTrader 5

![Version](https://img.shields.io/badge/version-15.10-blue)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange)
![Language](https://img.shields.io/badge/language-MQL5-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Overview

**Institutional Flow Trading System (IFTS)** is a professional-grade market analysis and signal intelligence panel built for MetaTrader 5. It combines multi-timeframe confluence analysis, real-time market structure detection, order flow tracking, and institutional-level risk management into a single live dashboard.

Built entirely from scratch in MQL5. Zero auto-trading — pure analysis and decision support.

> _"Analyze like an institution. Decide like a trader."_

---

## Features

### Signal Intelligence Engine

- Real-time signal generation based on EMA cross and RSI confirmation
- Dynamic scoring system (0–100) across 7 weighted criteria
- Quality classification: **A+ / A / B / REJECT**
- Adaptive risk sizing per signal quality

### Multi-Timeframe Confluence (MTF)

- Simultaneous analysis across **M5, M15, H1, H4**
- Weighted confluence scoring (H4 × 3.0 → M5 × 0.5)
- Strong / Aligned / Partial / Weak / Mixed classification

### Market Structure Detection

- Break of Structure (**BOS**) detection
- Change of Character (**CHoCH**) detection
- Swing point labeling: HH, HL, LH, LL
- Zero repaint — closed bar confirmation only

### Order Flow Analysis

- Cumulative Volume Delta (**CVD**) tracking
- Real tick-based delta classification (uptick/downtick)
- CVD divergence detection (fake rallies / fake drops)
- Absorption detection (high volume + small body)
- Exhaustion detection (large wick + volume spike)
- Stacked imbalance detection

### Institutional Levels

- Intraday **VWAP** with ±1 standard deviation bands
- **Point of Control (POC)** — highest volume price level
- Premium / Discount / Fair Value zone classification
- Dealing Range (DR) bias

### Risk Management

- Automatic lot size calculation
- ATR-based SL/TP placement (SL × 1.0 / TP × 1.5)
- Quality-adjusted risk: A+ = 1.25× / A = 1.00× / B = 0.65×
- Real-time risk % and dollar exposure display

### VHOCH Confirmation System

- **V**alidation of **H**igher **O**rder **C**onfluence **H**ypothesis
- Confirms when Market Structure + Order Flow + MTF all agree
- Strongest entry signal in the system

### Entry Checklist

- 10-point pre-trade checklist
- Automatic blocker detection
- ALL CLEAR signal when all conditions met

---

## Panel Layout

```
┌─────────────────────────────────────────────────┐
│  INSTITUTIONAL FLOW TRADING SYSTEM              │
├──────────────────────┬──────────────────────────┤
│  EA STATUS           │  SIGNAL ENGINE           │
│  Connection          │  Bias / EMA / RSI        │
│  State / Sweep       │  Signal / Score / Quality│
│  OB / FVG / Governor │  Session / HTF Align     │
├──────────────────────┴──────────────────────────┤
│  MARKET CONTEXT                                 │
│  Trend H1/H4 │ Zone │ Volatility │ Session      │
│  Regime │ DR Bias │ Market Structure            │
├──────────────────────┬──────────────────────────┤
│  INSTITUTIONAL       │  MTF CONFLUENCE          │
│  VWAP / Bands / POC  │  H4 / H1 / M15 / M5     │
│  Cumulative Delta    │  Score / Label           │
├──────────────────────┬──────────────────────────┤
│  RISK GUIDANCE       │  ORDER FLOW              │
│  Direction / SL / TP │  Delta / Absorption      │
│  RR / Lot / Risk %   │  CVD / Big Trades        │
├──────────────────────┴──────────────────────────┤
│  ENTRY CHECKLIST  +  VHOCH CONFIRMATION         │
└─────────────────────────────────────────────────┘
```

---

## How It Works

### Scoring System

Each signal is scored across 7 criteria:

| Criteria        | Max Points | Best Condition                     |
| --------------- | ---------- | ---------------------------------- |
| Session         | 15         | London + NY overlap                |
| HTF H1 Bias     | 12         | H1 aligned with signal             |
| HTF H4 Bias     | 8          | H4 aligned with signal             |
| Price Zone      | 15         | BUY in Discount / SELL in Premium  |
| Volatility      | 10         | ATR ratio ≥ 1.0                    |
| RSI             | 15         | Favorable RSI for signal direction |
| EMA Spread      | 15         | Wide EMA gap relative to ATR       |
| Regime          | 10         | Trending market                    |
| Structure Bonus | +10%       | BOS/CHoCH confirms direction       |

### Quality Classes

| Class  | Score | Risk Multiplier |
| ------ | ----- | --------------- |
| A+     | ≥ 80  | 1.25× base risk |
| A      | ≥ 65  | 1.00× base risk |
| B      | ≥ 50  | 0.65× base risk |
| REJECT | < 50  | Do not trade    |

### VHOCH Logic

```
IF Market Structure bias == signal direction
AND Order Flow bias == signal direction
AND MTF Confluence >= 2/4
→ VHOCH CONFIRMED ✅

ELSE
→ VHOCH NOT CONFIRMED ❌ (shows missing criteria)
```

---

## Installation

1. Copy `Institutional_Flow_Trading_System.mq5` to:

   ```
   MT5 → MQL5 → Indicators
   ```

2. Copy `dashboard-server.js` to your project folder

3. In MetaEditor, compile the `.mq5` file

4. Attach to any MT5 chart

5. Configure parameters in the Inputs tab

---

## Configuration

| Parameter       | Default | Description                         |
| --------------- | ------- | ----------------------------------- |
| `InpAccBal`     | 10000   | Account balance for lot calculation |
| `InpBaseRisk`   | 1.0     | Base risk percentage                |
| `InpRiskAP`     | 1.25    | A+ quality risk multiplier          |
| `InpRiskA`      | 1.00    | A quality risk multiplier           |
| `InpRiskB`      | 0.65    | B quality risk multiplier           |
| `InpScoreAP`    | 80      | A+ score threshold                  |
| `InpScoreA`     | 65      | A score threshold                   |
| `InpScoreB`     | 50      | B score threshold                   |
| `InpEMA_Fast`   | 8       | Fast EMA period                     |
| `InpEMA_Slow`   | 21      | Slow EMA period                     |
| `InpATR_Period` | 14      | ATR period                          |
| `InpSL_ATR`     | 1.0     | Stop loss ATR multiplier            |
| `InpTP_ATR`     | 1.5     | Take profit ATR multiplier          |
| `InpHTF`        | H1      | Primary higher timeframe            |
| `InpHTF2`       | H4      | Secondary higher timeframe          |

---

## Technical Stack

| Component        | Technology                                   |
| ---------------- | -------------------------------------------- |
| Core Engine      | MQL5                                         |
| Platform         | MetaTrader 5                                 |
| Dashboard Server | Node.js                                      |
| Web Dashboard    | HTML / CSS / JavaScript                      |
| Data Exchange    | MT5 Global Variables                         |
| Indicators       | EMA, RSI, ATR (manual calculation, zero lag) |

---

## Architecture

```
MT5 Chart
    │
    ├── IFTS Indicator (MQL5)
    │       ├── Signal Engine (V14)
    │       ├── ICT Detection (Sweeps, OB, FVG, DR)
    │       ├── Structure Detection (BOS, CHoCH)
    │       ├── Order Flow (CVD, Absorption, Exhaustion)
    │       ├── MTF Confluence
    │       ├── VWAP / POC
    │       └── Risk Calculator
    │
    ├── EA Engine (V13.8) — Optional
    │       └── Reads IFTS signals via GlobalVariables
    │
    └── Web Dashboard
            ├── Node.js Server
            └── Real-time HTML Panel
```

---

## Performance

Tested on FTMO $100,000 simulated account (Free Trial).

| Metric         | Result            |
| -------------- | ----------------- |
| Win Rate       | 90.91%            |
| Profit Factor  | 61.92             |
| Sharpe Ratio   | 1.11              |
| Average RRR    | 1 : 6.19          |
| Expectancy     | $227.66 per trade |
| Max Drawdown   | 0.3%              |
| Max Daily Loss | 0.6%              |
| Profit Target  | 5% — ✅ PASSED    |
| Total Trades   | 22                |
| Account Size   | $100,000          |

![alt text](image.png)

> _Results from FTMO Free Trial — simulated environment._
> _All trades executed algorithmically. Zero manual intervention._

---

## Screenshots

> _Add your screenshots here_

---

## Roadmap

- [ ] Python integration for backtesting
- [ ] Statistical edge validation
- [ ] Machine learning signal filter
- [ ] Multi-symbol dashboard
- [ ] Performance analytics module

---

## License

MIT License — free to use, modify and distribute.

---

## Author

Built by a trader learning to think like a quant.  
Currently expanding into Python, statistics, and quantitative finance.

---

---

## Türkçe Açıklama

**Institutional Flow Trading System (IFTS)**, MetaTrader 5 platformu için MQL5 ile geliştirilmiş profesyonel bir piyasa analiz ve sinyal paneldir.

### Ne Yapar

- Gerçek zamanlı çoklu zaman dilimi analizi (M5, M15, H1, H4)
- Market structure tespiti — BOS ve CHoCH (kapanmış bar, repaint yok)
- Order flow analizi — CVD, absorption, exhaustion, stacked imbalance
- Otomatik sinyal skorlama (0–100) ve kalite sınıflandırması
- VWAP, POC ve premium/discount zone tespiti
- Risk yönetimi — otomatik lot hesabı, ATR bazlı SL/TP
- VHOCH sistemi — yapı + order flow + MTF üçü uyuşunca konfirmasyon
- 10 maddelik entry checklist ve blocker tespiti

### Kurulum

1. `.mq5` dosyasını `MT5 → MQL5 → Indicators` klasörüne kopyala
2. MetaEditor'da derle
3. İstediğin grafiğe ekle
4. Input parametrelerini ayarla

### Notlar

- Otomatik işlem açmaz — sadece analiz ve karar desteği sağlar
- Her 3 saniyede güncellenir
- Birden fazla paritede aynı anda kullanılabilir
- EA ile birlikte çalışabilir (GlobalVariables üzerinden veri alışverişi)
