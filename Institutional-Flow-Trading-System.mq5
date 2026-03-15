
#property strict
#property indicator_chart_window
#property indicator_plots 4
#property version   "15.10"
#property description "V15.1 Institutional Upgrade — Score/VHOCH/Structure/OF/VWAP fixes"

#property indicator_label1  "EMA Fast"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label2  "EMA SlowS
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_width2  2
#property indicator_label3  "EMA50 HTF"
#property indicator_type3   DRAW_LINE
#property indicator_color3  C'80,80,120'
#property indicator_width3  1
#property indicator_style3  STYLE_DOT
#property indicator_label4  "EMA200 HTF"
#property indicator_type4   DRAW_LINE
#property indicator_color4  C'120,80,80'
#property indicator_width4  1
#property indicator_style4  STYLE_DOT

enum ENUM_SESSION     {SESSION_ASIA=0,SESSION_LONDON=1,SESSION_NY=2,SESSION_OVERLAP=3,SESSION_OFF=4};
enum ENUM_BIAS        {BIAS_LONG=1,BIAS_SHORT=-1,BIAS_NEUTRAL=0};
enum ENUM_ZONE        {ZONE_PREMIUM=1,ZONE_DISCOUNT=-1,ZONE_FAIR=0};
enum ENUM_QUALITY     {Q_APLUS=3,Q_A=2,Q_B=1,Q_REJECT=0};
enum ENUM_REGIME      {REG_TREND=0,REG_RANGE=1,REG_CHOP=2};

input group "═══ PANEL ═══"
input int      InpPanelX=10;
input int      InpPanelY=25;
input int      InpPanelW=620;

input group "═══ V14 ENGINE ═══"
input int      InpEMA_Fast=8;
input int      InpEMA_Slow=21;
input int      InpRSI_Period=14;
input double   InpRSI_BuyBelow=45;
input double   InpRSI_SellAbove=55;
input int      InpATR_Period=14;
input double   InpSL_ATR=1.0;
input double   InpTP_ATR=1.5;

input group "═══ HTF ═══"
input ENUM_TIMEFRAMES InpHTF=PERIOD_H1;
input ENUM_TIMEFRAMES InpHTF2=PERIOD_H4;
input int      InpHTF_EMA_Fast=50;
input int      InpHTF_EMA_Slow=200;

input group "═══ SESSION ═══"
input int      InpLondonStart=7;
input int      InpLondonEnd=12;
input int      InpNYStart=13;
input int      InpNYEnd=18;

input group "═══ ICT DETECTION ═══"
input int      InpSwingLB=20;
input double   InpEQTol=0.003;
input double   InpFVGMinATR=0.3;
input double   InpOBDispATR=0.5;
input int      InpOBMaxAge=50;
input int      InpFVGMaxAge=40;
input int      InpPDLookback=50;

input group "═══ V13.8 LINK ═══"
input ENUM_TIMEFRAMES InpEATF=PERIOD_M15;
input string   InpSymOvr="";

input group "═══ COLORS ═══"
input color    InpClrBullOB=C'0,80,180';
input color    InpClrBearOB=C'180,40,40';
input color    InpClrBullFVG=C'0,150,60';
input color    InpClrBearFVG=C'160,90,0';
input color    InpClrSweep=clrYellow;
input color    InpClrDR=C'60,60,80';
input color    InpClrPanel=C'20,22,30';
input color    InpClrPanelBorder=C'50,55,75';
input color    InpClrTextNormal=C'180,185,200';
input color    InpClrTextBright=clrWhite;
input color    InpClrBull=C'0,200,100';
input color    InpClrBear=C'220,50,50';
input color    InpClrWarn=C'220,170,30';
input color    InpClrNeutral=C'120,125,140';

input group "═══ RISK ═══"
input double   InpAccBal=10000;
input double   InpBaseRisk=1.0;
input double   InpRiskAP=1.25;
input double   InpRiskA=1.00;
input double   InpRiskB=0.65;
input double   InpScoreAP=80;
input double   InpScoreA=65;
input double   InpScoreB=50;

// Buffers
double BufEF[],BufES[],BufH50[],BufH200[];

// Structures
struct OB {bool v;double h,l;int tp;datetime t;int age;bool touched;};
struct FVG{bool v;double h,l;int tp;datetime t;int age;double score;};
struct SW {bool v;double lev;int tp;datetime t;int str;};

struct V14Sig{
   ENUM_BIAS bias;double rsi;bool cx_bull,cx_bear,tr_bull,tr_bear;
   double ema_sp,atr;ENUM_SESSION ses;ENUM_BIAS htf1,htf2;
   ENUM_ZONE zone;double vol;ENUM_REGIME reg;
   int sig;double score;ENUM_QUALITY qual;
   double sl_d,tp_d,rr,lot;
};

struct V13D{
   bool conn;int state;
   bool sw_v;double sw_lev;int sw_tp,sw_str;
   int ob_cnt;OB obs[5];
   bool fvg_v;double fvg_h,fvg_l;int fvg_tp,fvg_age;double fvg_sc;
   int ses;double ctx_sc;int htf_str;
   int gov_st;double risk_m,daily_pnl;
   int trades,wins,losses;
   double sqs_t;int qual;int da_v;bool cd;
   double dr_h,dr_l;int dr_bias;bool dr_locked;
};

// Globals
int hEF,hES,hRSI,hATR,hH1F,hH1S,hH2F,hH2S;
string gp,gfp,gsym;
V14Sig g14;V13D g13;
OB gOBs[10];int gOBn;
FVG gFVGs[10];int gFVGn;
SW gSWs[5];int gSWn;
double gDR_h,gDR_l,gDR_eq,gDR_ih,gDR_il;bool gDR_lock;int gDR_bias;
int gTick;

// Order Flow globals
struct OrderFlow {
   double delta_cum;        // Cumulative delta (last N bars)
   double delta_pct;        // Delta % (-100 to +100)
   int    delta_bars;       // Bars analyzed
   bool   absorption;       // Absorption detected
   string absorb_type;      // "BULL_ABSORB" or "BEAR_ABSORB"
   double absorb_vol;       // Volume at absorption
   int    stacked_count;    // Consecutive dominant bars
   int    stacked_dir;      // 1=buyers, -1=sellers
   bool   exhaustion;       // Exhaustion signal
   string exhaust_type;     // "BULL_EXHAUST" or "BEAR_EXHAUST"
   int    flow_bias;        // Overall: 1=buyers, -1=sellers, 0=neutral
   string flow_label;       // "STRONG BUY FLOW" etc.
   double big_vol_ratio;    // Current vol vs avg (spike detection)
   // Proximity tracking (always show best values)
   double best_abs_vol;     // Highest vol ratio in last 3 bars
   double best_abs_body;    // Smallest body% in last 3 bars
   double best_wick_pct;    // Biggest wick% in bar[1]
   double best_exh_vol;     // Vol ratio of bar[1]
};
OrderFlow gOF;

// VWAP & POC
double gVWAP;           // Volume Weighted Average Price
double gVWAP_upper;     // VWAP + 1 std dev
double gVWAP_lower;     // VWAP - 1 std dev
double gPOC;            // Point of Control (highest volume price)
double gCumDelta;       // Running cumulative delta

// === REAL ORDER FLOW — CopyTicks based (uptick/downtick) ===
struct RealOrderFlow {
   double buy_volume;       // Uptick volume
   double sell_volume;      // Downtick volume
   double real_delta;       // buy_vol - sell_vol
   double real_delta_pct;   // % of total (-100 to +100)
   double cvd_current;      // Cumulative Volume Delta (today)
   double cvd_prev;         // CVD value at previous bar close
   bool   cvd_divergence;   // Price vs CVD divergence detected
   string cvd_div_type;     // "BULL_DIV" or "BEAR_DIV"
   int    large_trade_cnt;  // Count of large trades (>3x avg)
   int    large_trade_dir;  // +1=big buyers -1=big sellers 0=mixed
   double avg_volume;       // Avg tick volume for threshold calc
   bool   data_ok;          // CopyTicks returned valid data
};
RealOrderFlow gROF;

// Alert streak counter (PERSISTENT SIGNAL detection)
int    gAlertConsecDir;     // Last alert direction (+1 or -1)
int    gAlertConsecCount;   // Consecutive same-direction alerts

// MTF Confluence
struct MTFSignal { int m5_sig; int m15_sig; int h1_sig; int h4_sig; int confluence; double score; string label; };
MTFSignal gMTF;

// === MARKET STRUCTURE — BOS / CHoCH / Swing Points ===
struct SwingPoint {
   double price;
   datetime time;
   int type;        // 1=swing high, -1=swing low
   string label;    // "HH","HL","LH","LL"
   int bar_index;
};

struct StructureBreak {
   double level;
   datetime time;
   int type;        // 1=bullish, -1=bearish
   string kind;     // "BOS" or "CHoCH"
   bool valid;
};

SwingPoint gSwings[20]; int gSwingN;
StructureBreak gBOS[10]; int gBOSn;
int gStructureBias;     // 1=bullish structure, -1=bearish, 0=undefined
string gStructureLabel; // "BULLISH BOS" / "BEARISH CHoCH" etc.
string gSwingPattern;   // "HH-HL" / "LH-LL" etc.

// Alert control
datetime gLastAlert;
string gLastAlertMsg;

//+------------------------------------------------------------------+
//| INIT / DEINIT                                                     |
//+------------------------------------------------------------------+
int OnInit(){

   //+------------------------------------------------------------------+
   //|  🔒 DEMO SÜRE KONTROLÜ                                          |
   //+------------------------------------------------------------------+
   datetime expiry = D'2026.06.01';  // ✏️ Bitiş tarihini buradan değiştir

   if(TimeCurrent() > expiry) {
      Alert("❌ Demo süresi doldu. Tam sürüm için iletişime geçin.");
      Print("❌ DEMO SÜRESİ DOLDU | Bitiş: ", TimeToString(expiry, TIME_DATE));
      return INIT_FAILED;
   }
   Print("✅ Demo aktif | Bitiş: ", TimeToString(expiry, TIME_DATE));
   //+------------------------------------------------------------------+

   IndicatorSetString(INDICATOR_SHORTNAME,"V15 Signal Intelligence");
   SetIndexBuffer(0,BufEF,INDICATOR_DATA);
   SetIndexBuffer(1,BufES,INDICATOR_DATA);
   SetIndexBuffer(2,BufH50,INDICATOR_DATA);
   SetIndexBuffer(3,BufH200,INDICATOR_DATA);
   
   hEF=iMA(_Symbol,PERIOD_CURRENT,InpEMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   hES=iMA(_Symbol,PERIOD_CURRENT,InpEMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   hRSI=iRSI(_Symbol,PERIOD_CURRENT,InpRSI_Period,PRICE_CLOSE);
   hATR=iATR(_Symbol,PERIOD_CURRENT,InpATR_Period);
   hH1F=iMA(_Symbol,InpHTF,InpHTF_EMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   hH1S=iMA(_Symbol,InpHTF,InpHTF_EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   hH2F=iMA(_Symbol,InpHTF2,InpHTF_EMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   hH2S=iMA(_Symbol,InpHTF2,InpHTF_EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   if(hEF==INVALID_HANDLE||hES==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE||
      hH1F==INVALID_HANDLE||hH1S==INVALID_HANDLE||hH2F==INVALID_HANDLE||hH2S==INVALID_HANDLE)
      return INIT_FAILED;
   
   gsym=(InpSymOvr=="")?_Symbol:InpSymOvr;
   gp="EA_"+gsym+"_"+EnumToString(InpEATF);
   string tf_s="M15";
   switch(InpEATF){case PERIOD_M1:tf_s="M1";break;case PERIOD_M5:tf_s="M5";break;case PERIOD_M15:tf_s="M15";break;case PERIOD_M30:tf_s="M30";break;case PERIOD_H1:tf_s="H1";break;default:tf_s="M15";}
   gfp="EA_"+gsym+"_"+tf_s;
   gTick=0;
   gVWAP=0; gVWAP_upper=0; gVWAP_lower=0; gPOC=0; gCumDelta=0;
   gLastAlert=0; gLastAlertMsg="";
   gSwingN=0; gBOSn=0; gStructureBias=0; gStructureLabel="─ SCANNING"; gSwingPattern="";
   ZeroMemory(gROF); gROF.data_ok=false;
   gAlertConsecDir=0; gAlertConsecCount=0;
   
   CreatePanel();
   EventSetMillisecondTimer(3000); // 3 second update cycle
   // Force immediate update
   AnalyzeV14(); DetectICT(); ReadV13(); CalcRisk(); AnalyzeOrderFlow(); CalcVWAP(); CalcPOC(); CalcMTF(); DetectStructure(); UpdatePanel();
   ChartRedraw(0);
   Print("═══ V15 SIGNAL INTELLIGENCE ACTIVE ═══");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   EventKillTimer();
   ObjectsDeleteAll(0,"V15_");
   IndicatorRelease(hEF);IndicatorRelease(hES);IndicatorRelease(hRSI);IndicatorRelease(hATR);
   IndicatorRelease(hH1F);IndicatorRelease(hH1S);IndicatorRelease(hH2F);IndicatorRelease(hH2S);
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],const long &volume[],const int &spread[]){
   if(rates_total<2) return rates_total;
   ArraySetAsSeries(BufEF,true);ArraySetAsSeries(BufES,true);
   ArraySetAsSeries(BufH50,true);ArraySetAsSeries(BufH200,true);
   
   double ef[],es[],h1f[],h1s[];
   int n1=CopyBuffer(hEF,0,0,rates_total,ef);
   int n2=CopyBuffer(hES,0,0,rates_total,es);
   int n3=CopyBuffer(hH1F,0,0,rates_total,h1f);
   int n4=CopyBuffer(hH1S,0,0,rates_total,h1s);
   
   if(n1>0){ArraySetAsSeries(ef,true);ArrayCopy(BufEF,ef,0,0,MathMin(n1,rates_total));}
   if(n2>0){ArraySetAsSeries(es,true);ArrayCopy(BufES,es,0,0,MathMin(n2,rates_total));}
   if(n3>0){ArraySetAsSeries(h1f,true);ArrayCopy(BufH50,h1f,0,0,MathMin(n3,rates_total));}
   if(n4>0){ArraySetAsSeries(h1s,true);ArrayCopy(BufH200,h1s,0,0,MathMin(n4,rates_total));}
   return rates_total;
}

void OnTimer(){
   gTick++;
   // Full analysis every tick (3 sec interval now)
   AnalyzeV14();
   DetectICT();
   ReadV13();
   CalcRisk();
   AnalyzeOrderFlow();
   CalcRealOrderFlow();   // FIX: Real tick-based CVD
   if(gTick%10==0){ // Heavy calcs every 30 sec
      CalcVWAP();
      CalcPOC();
      CalcMTF();
      DetectStructure();
   }
   UpdatePanel();
   DrawChart();
   CheckAlerts();
   // FIX: Write VHOCH globals every 2 sec for EA interop
   static datetime last_vhoch_write=0;
   if(TimeCurrent()-last_vhoch_write>=2){
      WriteVHOCHGlobals();
      last_vhoch_write=TimeCurrent();
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                  |
//+------------------------------------------------------------------+
ENUM_SESSION DetectSession(){
   MqlDateTime dt;TimeCurrent(dt);int h=dt.hour;
   bool lo=(h>=InpLondonStart&&h<InpLondonEnd),ny=(h>=InpNYStart&&h<InpNYEnd);
   if(lo&&ny) return SESSION_OVERLAP;
   if(lo) return SESSION_LONDON; if(ny) return SESSION_NY;
   if(h<InpLondonStart) return SESSION_ASIA;
   return SESSION_OFF;
}

ENUM_BIAS GetHTFBias(int hf,int hs){
   // Try indicator handle first
   double f[],s[];ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);
   if(CopyBuffer(hf,0,0,1,f)>=1&&CopyBuffer(hs,0,0,1,s)>=1){
      double p=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(p>f[0]&&f[0]>s[0]) return BIAS_LONG;
      if(p<f[0]&&f[0]<s[0]) return BIAS_SHORT;
      return BIAS_NEUTRAL;
   }
   return BIAS_NEUTRAL;
}

ENUM_ZONE GetPriceZone(){
   MqlRates r[];ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpHTF,0,InpPDLookback,r)<InpPDLookback) return ZONE_FAIR;
   double hi=r[0].high,lo=r[0].low;
   for(int i=1;i<InpPDLookback;i++){if(r[i].high>hi)hi=r[i].high;if(r[i].low<lo)lo=r[i].low;}
   double rng=hi-lo;if(rng<=0)return ZONE_FAIR;
   double eq=(hi+lo)/2.0,p=SymbolInfoDouble(_Symbol,SYMBOL_BID),th=rng*0.1;
   if(p>eq+th) return ZONE_PREMIUM; if(p<eq-th) return ZONE_DISCOUNT;
   return ZONE_FAIR;
}

double GetVolRatio(){
   MqlRates mr[];ArraySetAsSeries(mr,true);
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,22,mr)<22) return 1.0;
   // Current bar TR
   double tr0=mr[0].high-mr[0].low;
   // Average TR last 20 bars
   double avg=0;
   for(int i=1;i<=20;i++){
      double tr=MathMax(mr[i].high-mr[i].low,MathMax(MathAbs(mr[i].high-mr[i+1].close),MathAbs(mr[i].low-mr[i+1].close)));
      avg+=tr;
   }
   avg/=20.0;
   return (avg>0)?tr0/avg:1.0;
}

ENUM_REGIME DetectRegime(){
   MqlRates r[];ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,50,r)<30) return REG_RANGE;
   // Check last 10 bars for EMA cross frequency
   double mf=2.0/(InpEMA_Fast+1), ms_m=2.0/(InpEMA_Slow+1);
   double ef[11],es[11];
   double ef_t=r[49].close, es_t=r[49].close;
   for(int i=48;i>=0;i--){
      ef_t=r[i].close*mf+ef_t*(1.0-mf);
      es_t=r[i].close*ms_m+es_t*(1.0-ms_m);
      if(i<11){ef[i]=ef_t;es[i]=es_t;}
   }
   int chg=0;
   for(int i=1;i<10;i++){if((ef[i+1]>es[i+1])!=(ef[i]>es[i]))chg++;}
   if(chg>=3) return REG_CHOP;
   if(MathAbs(ef[1]-es[1])>MathAbs(ef[5]-es[5])*1.2) return REG_TREND;
   return REG_RANGE;
}

string SesStr(ENUM_SESSION s){
   if(s==SESSION_LONDON) return "LONDON"; if(s==SESSION_NY) return "NEW YORK";
   if(s==SESSION_OVERLAP) return "LDN+NY"; if(s==SESSION_ASIA) return "ASIA";
   return "OFF";
}
string BiasStr(ENUM_BIAS b){return (b==BIAS_LONG)?"LONG ▲":(b==BIAS_SHORT)?"SHORT ▼":"NEUTRAL ─";}
string ZoneStr(ENUM_ZONE z){return (z==ZONE_PREMIUM)?"PREMIUM":(z==ZONE_DISCOUNT)?"DISCOUNT":"FAIR VALUE";}
string QualStr(ENUM_QUALITY q){return (q==Q_APLUS)?"A+":(q==Q_A)?"A":(q==Q_B)?"B":"REJECT";}
string RegStr(ENUM_REGIME r){return (r==REG_TREND)?"TRENDING":(r==REG_RANGE)?"RANGING":"CHOPPY";}
color BiasClr(ENUM_BIAS b){return (b==BIAS_LONG)?InpClrBull:(b==BIAS_SHORT)?InpClrBear:InpClrNeutral;}
color QualClr(ENUM_QUALITY q){return (q==Q_APLUS)?InpClrBull:(q==Q_A)?C'100,200,255':(q==Q_B)?InpClrWarn:InpClrBear;}

//+------------------------------------------------------------------+
//| V14 ANALYSIS                                                      |
//+------------------------------------------------------------------+
void AnalyzeV14(){
   MqlRates r[];ArraySetAsSeries(r,true);
   int bars=CopyRates(_Symbol,PERIOD_CURRENT,0,200,r);
   if(bars<50){
      if(gTick%20==0) Print("V15: Not enough bars: ",bars);
      return;
   }
   
   // === MANUAL EMA ===
   double ema_f=r[bars-1].close, ema_s=r[bars-1].close;
   double mf=2.0/(InpEMA_Fast+1), ms=2.0/(InpEMA_Slow+1);
   for(int i=bars-2;i>=0;i--){
      ema_f=r[i].close*mf+ema_f*(1.0-mf);
      ema_s=r[i].close*ms+ema_s*(1.0-ms);
   }
   double ema_f1=r[bars-1].close, ema_s1=r[bars-1].close;
   for(int i=bars-2;i>=1;i--){
      ema_f1=r[i].close*mf+ema_f1*(1.0-mf);
      ema_s1=r[i].close*ms+ema_s1*(1.0-ms);
   }
   double ema_f2=r[bars-1].close, ema_s2=r[bars-1].close;
   for(int i=bars-2;i>=2;i--){
      ema_f2=r[i].close*mf+ema_f2*(1.0-mf);
      ema_s2=r[i].close*ms+ema_s2*(1.0-ms);
   }
   
   g14.tr_bull=(ema_f1>ema_s1); g14.tr_bear=(ema_f1<ema_s1);
   g14.cx_bull=(ema_f1>ema_s1&&ema_f2<=ema_s2);
   g14.cx_bear=(ema_f1<ema_s1&&ema_f2>=ema_s2);
   g14.ema_sp=ema_f1-ema_s1;
   
   // === MANUAL RSI ===
   g14.rsi=50.0;
   if(bars>=InpRSI_Period+2){
      double gain=0,loss=0;
      for(int i=1;i<=InpRSI_Period;i++){
         double ch=r[i-1].close-r[i].close;
         if(ch>0) gain+=ch; else loss-=ch;
      }
      gain/=InpRSI_Period; loss/=InpRSI_Period;
      if(loss==0) g14.rsi=100.0;
      else g14.rsi=100.0-(100.0/(1.0+gain/loss));
   }
   
   // === MANUAL ATR ===
   g14.atr=0;
   if(bars>=InpATR_Period+2){
      double s=0;
      for(int i=1;i<=InpATR_Period;i++){
         double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-r[i+1].close),MathAbs(r[i].low-r[i+1].close)));
         s+=tr;
      }
      g14.atr=s/InpATR_Period;
   }
   
   // === VOLATILITY RATIO ===
   g14.vol=1.0;
   if(bars>=22&&g14.atr>0){
      double tr0=r[0].high-r[0].low;
      g14.vol=tr0/g14.atr;
   }
   
   // === SESSION / HTF / ZONE / REGIME ===
   g14.ses=DetectSession();
   g14.htf1=GetHTFBias(hH1F,hH1S); g14.htf2=GetHTFBias(hH2F,hH2S);
   g14.zone=GetPriceZone(); g14.reg=DetectRegime();
   g14.bias=(g14.tr_bull)?BIAS_LONG:(g14.tr_bear)?BIAS_SHORT:BIAS_NEUTRAL;
   
   // === SIGNAL ===
   g14.sig=0;
   if(g14.tr_bull&&g14.rsi<InpRSI_BuyBelow) g14.sig=1;
   else if(g14.tr_bear&&g14.rsi>InpRSI_SellAbove) g14.sig=-1;
   else if(g14.cx_bull) g14.sig=1;
   else if(g14.cx_bear) g14.sig=-1;
   
   // === SCORE ===
   ScoreV14();
   
   // Debug — once per minute only
   if(gTick%20==0) Print("V15: RSI=",DoubleToString(g14.rsi,1)," ATR=",DoubleToString(g14.atr,_Digits),
      " Vol=",DoubleToString(g14.vol,2)," Sig=",g14.sig);
}

void ScoreV14(){
   double s=0; int d=g14.sig;
   // Session 0-15
   if(g14.ses==SESSION_OVERLAP) s+=15; else if(g14.ses==SESSION_LONDON) s+=12;
   else if(g14.ses==SESSION_NY) s+=10; else if(g14.ses==SESSION_ASIA) s+=3;
   // HTF 0-20
   if((d==1&&g14.htf1==BIAS_LONG)||(d==-1&&g14.htf1==BIAS_SHORT)) s+=12;
   else if(g14.htf1==BIAS_NEUTRAL) s+=6;
   if((d==1&&g14.htf2==BIAS_LONG)||(d==-1&&g14.htf2==BIAS_SHORT)) s+=8;
   else if(g14.htf2==BIAS_NEUTRAL) s+=4;
   // Zone 0-15
   if((d==1&&g14.zone==ZONE_DISCOUNT)||(d==-1&&g14.zone==ZONE_PREMIUM)) s+=15;
   else if(g14.zone==ZONE_FAIR) s+=8;
   // Vol 0-10
   if(g14.vol>=1.0) s+=10; else if(g14.vol>=0.7) s+=7; else if(g14.vol>=0.5) s+=4;
   // RSI 0-15
   if(d==1) s+=MathMin(15,MathMax(0,(InpRSI_BuyBelow-g14.rsi)*0.5+8));
   else if(d==-1) s+=MathMin(15,MathMax(0,(g14.rsi-InpRSI_SellAbove)*0.5+8));
   else s+=5;
   // EMA 0-15
   if(g14.atr>0) s+=MathMin(15,MathAbs(g14.ema_sp)/g14.atr*30);
   // Regime 0-10
   if(g14.reg==REG_TREND) s+=10; else if(g14.reg==REG_RANGE) s+=5;
   // FIX: Normalize to 100 — max raw sum = 100 (15+12+8+15+10+15+15+10)
   double normalized = MathMin(100.0, (s / 100.0) * 100.0);
   // FIX: Structure bonus as +10% multiplier (not additive)
   double struct_bonus = 0.0;
   if((d==1 && gStructureBias==1)||(d==-1 && gStructureBias==-1)) struct_bonus=0.10;
   else if(gStructureBias==0) struct_bonus=0.03;
   normalized = MathMin(100.0, normalized*(1.0+struct_bonus));
   
   g14.score=normalized;
   if(g14.score>=InpScoreAP) g14.qual=Q_APLUS; else if(g14.score>=InpScoreA) g14.qual=Q_A;
   else if(g14.score>=InpScoreB) g14.qual=Q_B; else g14.qual=Q_REJECT;
}

void CalcRisk(){
   if(g14.atr<=0) return;
   double rm=InpRiskB;
   if(g14.qual==Q_APLUS) rm=InpRiskAP; else if(g14.qual==Q_A) rm=InpRiskA;
   double rp=InpBaseRisk*rm;
   g14.sl_d=g14.atr*InpSL_ATR; g14.tp_d=g14.atr*InpTP_ATR;
   g14.rr=(g14.sl_d>0)?g14.tp_d/g14.sl_d:0;
   double ra=InpAccBal*(rp/100.0);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(ts>0&&tv>0&&g14.sl_d>0){
      g14.lot=ra/((g14.sl_d/ts)*tv);
      double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      if(step>0) g14.lot=MathFloor(g14.lot/step)*step;
      g14.lot=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),g14.lot);
   }
}

//+------------------------------------------------------------------+
//| ICT DETECTION (Standalone)                                        |
//+------------------------------------------------------------------+
void DetectICT(){
   MqlRates r[];ArraySetAsSeries(r,true);
   double ab[];ArraySetAsSeries(ab,true);
   int bars=100;
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,bars,r)<bars) return;
   if(CopyBuffer(hATR,0,0,bars,ab)<bars) return;
   DetectSweeps(r,bars); DetectOBs(r,ab,bars); DetectFVGs(r,ab,bars); DetectDR(r,bars);
}

void DetectSweeps(const MqlRates &r[],int bars){
   gSWn=0;
   for(int i=2;i<MathMin(InpSwingLB,bars-2)&&gSWn<5;i++){
      if(r[i].high>r[i-1].high&&r[i].high>r[i+1].high){
         for(int j=i+1;j<MathMin(i+InpSwingLB,bars-1);j++){
            if(r[j].high>r[j-1].high&&r[j].high>r[j+1].high){
               if(MathAbs(r[i].high-r[j].high)/r[i].high<InpEQTol){
                  gSWs[gSWn].v=true;gSWs[gSWn].lev=MathMax(r[i].high,r[j].high);
                  gSWs[gSWn].tp=-1;gSWs[gSWn].t=r[i].time;gSWs[gSWn].str=2;gSWn++;break;
               }
            }
         }
      }
      if(r[i].low<r[i-1].low&&r[i].low<r[i+1].low){
         for(int j=i+1;j<MathMin(i+InpSwingLB,bars-1);j++){
            if(r[j].low<r[j-1].low&&r[j].low<r[j+1].low){
               if(MathAbs(r[i].low-r[j].low)/r[i].low<InpEQTol){
                  gSWs[gSWn].v=true;gSWs[gSWn].lev=MathMin(r[i].low,r[j].low);
                  gSWs[gSWn].tp=1;gSWs[gSWn].t=r[i].time;gSWs[gSWn].str=2;gSWn++;break;
               }
            }
         }
      }
   }
}

void DetectOBs(const MqlRates &r[],const double &atr[],int bars){
   gOBn=0;
   for(int i=1;i<MathMin(InpOBMaxAge,bars-2)&&gOBn<10;i++){
      double disp=MathAbs(r[i].close-r[i].open);
      if(atr[i]<=0||disp<atr[i]*InpOBDispATR) continue;
      if(disp/((r[i].high-r[i].low)+0.000001)<0.30) continue;
      if(r[i].close>r[i].open&&i+1<bars&&r[i+1].close<r[i+1].open){ // Bullish OB
         gOBs[gOBn].v=true;gOBs[gOBn].h=r[i+1].high;gOBs[gOBn].l=r[i+1].low;
         gOBs[gOBn].tp=1;gOBs[gOBn].t=r[i+1].time;gOBs[gOBn].age=i+1;
         gOBs[gOBn].touched=(r[0].low<=r[i+1].high);gOBn++;
      }
      if(r[i].close<r[i].open&&i+1<bars&&r[i+1].close>r[i+1].open){ // Bearish OB
         gOBs[gOBn].v=true;gOBs[gOBn].h=r[i+1].high;gOBs[gOBn].l=r[i+1].low;
         gOBs[gOBn].tp=-1;gOBs[gOBn].t=r[i+1].time;gOBs[gOBn].age=i+1;
         gOBs[gOBn].touched=(r[0].high>=r[i+1].low);gOBn++;
      }
   }
}

void DetectFVGs(const MqlRates &r[],const double &atr[],int bars){
   gFVGn=0;
   for(int i=1;i<MathMin(InpFVGMaxAge,bars-2)&&gFVGn<10;i++){
      if(r[i-1].low>r[i+1].high){ // Bullish FVG
         double gap=r[i-1].low-r[i+1].high;
         if(atr[i]>0&&gap>=atr[i]*InpFVGMinATR){
            gFVGs[gFVGn].v=true;gFVGs[gFVGn].h=r[i-1].low;gFVGs[gFVGn].l=r[i+1].high;
            gFVGs[gFVGn].tp=1;gFVGs[gFVGn].t=r[i].time;gFVGs[gFVGn].age=i;
            gFVGs[gFVGn].score=MathMax(0,100-(i*2));gFVGn++;
         }
      }
      if(r[i+1].low>r[i-1].high){ // Bearish FVG
         double gap=r[i+1].low-r[i-1].high;
         if(atr[i]>0&&gap>=atr[i]*InpFVGMinATR){
            gFVGs[gFVGn].v=true;gFVGs[gFVGn].h=r[i+1].low;gFVGs[gFVGn].l=r[i-1].high;
            gFVGs[gFVGn].tp=-1;gFVGs[gFVGn].t=r[i].time;gFVGs[gFVGn].age=i;
            gFVGs[gFVGn].score=MathMax(0,100-(i*2));gFVGn++;
         }
      }
   }
}

void DetectDR(const MqlRates &r[],int bars){
   MqlDateTime dt;TimeCurrent(dt);
   datetime ds=TimeCurrent()-(dt.hour*3600+dt.min*60+dt.sec);
   datetime de=ds+9*3600+30*60;
   gDR_h=0;gDR_l=999999;gDR_lock=false;
   for(int i=0;i<bars;i++){
      if(r[i].time>=ds&&r[i].time<=de){
         if(r[i].high>gDR_h) gDR_h=r[i].high;
         if(r[i].low<gDR_l) gDR_l=r[i].low;
         gDR_lock=true;
      }
   }
   if(gDR_lock&&gDR_h>0){
      double rng=gDR_h-gDR_l;
      gDR_eq=(gDR_h+gDR_l)/2.0;
      gDR_ih=gDR_eq+rng*0.25; gDR_il=gDR_eq-rng*0.25;
      gDR_bias=(SymbolInfoDouble(_Symbol,SYMBOL_BID)>gDR_eq)?1:-1;
   }
}

//+------------------------------------------------------------------+
//| READ V13.8 EA DATA via GlobalVariables                            |
//+------------------------------------------------------------------+
void ReadV13(){
   g13.conn=false;
   if(!GlobalVariableCheck(gp+"_STATE")) return;
   if(TimeCurrent()-GlobalVariableTime(gp+"_STATE")>60) return;
   g13.conn=true;
   g13.state=(int)GVG(gp+"_STATE");
   g13.sw_v=(GVG(gp+"_SWEEP_VALID")>0);
   if(g13.sw_v){g13.sw_lev=GVG(gp+"_SWEEP_LEVEL");g13.sw_tp=(int)GVG(gp+"_SWEEP_TYPE");g13.sw_str=(int)GVG(gp+"_SWEEP_STRENGTH");}
   g13.ob_cnt=(int)GVG(gp+"_OB_COUNT");
   for(int i=0;i<5;i++){
      string idx=IntegerToString(i);
      g13.obs[i].v=(GVG(gp+"_OB_"+idx+"_VALID")>0);
      if(g13.obs[i].v){g13.obs[i].h=GVG(gp+"_OB_"+idx+"_HIGH");g13.obs[i].l=GVG(gp+"_OB_"+idx+"_LOW");
      g13.obs[i].tp=(int)GVG(gp+"_OB_"+idx+"_TYPE");g13.obs[i].touched=(GVG(gp+"_OB_"+idx+"_TOUCHED")>0);}
   }
   g13.fvg_v=(GVG(gfp+"_FVG_VALID")>0);
   if(g13.fvg_v){g13.fvg_h=GVG(gfp+"_FVG_HIGH");g13.fvg_l=GVG(gfp+"_FVG_LOW");g13.fvg_tp=(int)GVG(gfp+"_FVG_TYPE");g13.fvg_age=(int)GVG(gfp+"_FVG_AGE");g13.fvg_sc=GVG(gfp+"_FVG_SCORE");}
   g13.ses=(int)GVG(gp+"_SESSION"); g13.ctx_sc=GVG(gp+"_CONTEXT_SCORE"); g13.htf_str=(int)GVG(gp+"_HTF_STRUCTURE");
   g13.gov_st=(int)GVG(gp+"_GOVERNOR_STATE"); g13.risk_m=GVG(gp+"_GOVERNOR_RISK_MULT");
   g13.daily_pnl=GVG(gp+"_GOVERNOR_PNL"); g13.trades=(int)GVG(gp+"_GOVERNOR_TRADES");
   g13.wins=(int)GVG(gp+"_GOVERNOR_WINS"); g13.losses=(int)GVG(gp+"_GOVERNOR_LOSSES");
   g13.sqs_t=GVG(gp+"_SQS_TOTAL"); g13.qual=(int)GVG(gp+"_QUALITY_CLASS"); g13.da_v=(int)GVG(gp+"_DA_VERDICT");
   g13.cd=(GVG(gp+"_COOLDOWN")>0);
   // DR
   if(GlobalVariableCheck(gp+"_DR_HIGH")){g13.dr_h=GVG(gp+"_DR_HIGH");g13.dr_l=GVG(gp+"_DR_LOW");g13.dr_bias=(int)GVG(gp+"_DR_BIAS");g13.dr_locked=(GVG(gp+"_DR_LOCKED")>0);}
}

double GVG(string key){
   if(GlobalVariableCheck(key)) return GlobalVariableGet(key);
   return 0;
}

//+------------------------------------------------------------------+
//| PANEL CREATION & UPDATE                                           |
//+------------------------------------------------------------------+
void CreatePanel(){
   int y=InpPanelY;
   // Background
   CreateRect("V15_BG",InpPanelX,y,InpPanelW,780,InpClrPanel,InpClrPanelBorder);
   // Title bar
   CreateRect("V15_TITLE_BG",InpPanelX,y,InpPanelW,28,C'30,35,55',InpClrPanelBorder);
   CreateLabel("V15_TITLE",InpPanelX+10,y+4,"ICT SNIPER V15 — SIGNAL INTELLIGENCE",InpClrTextBright,10,true);
   CreateLabel("V15_SUBTITLE",InpPanelX+InpPanelW-200,y+7,"",InpClrNeutral,8,false);
   y+=32;
   
   // === LEFT: V13.8 EA ===
   int lx=InpPanelX+8,rx=InpPanelX+InpPanelW/2+8;
   CreateLabel("V15_L_HDR",lx,y,"[ V13.8 TURBO EA ]",InpClrWarn,9,true);
   CreateLabel("V15_R_HDR",rx,y,"[ V14 SIGNAL ENGINE ]",C'100,200,255',9,true);
   y+=18;
   // Separator
   CreateRect("V15_SEP1",InpPanelX+4,y,InpPanelW-8,1,InpClrPanelBorder,InpClrPanelBorder);
   y+=4;
   
   // V13 rows (left)
   string v13rows[]={"CONN","STATE","SWEEP","OB","FVG","TOUCH","MICRO","QUAL","GOV","PNL"};
   for(int i=0;i<10;i++){
      CreateLabel("V15_L13_"+v13rows[i]+"_K",lx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_L13_"+v13rows[i]+"_V",lx+110,y+i*17,"",InpClrTextNormal,8,false);
   }
   // V14 rows (right)
   string v14rows[]={"BIAS","EMA","RSI","CROSS","SIG","SCORE","QUAL","MOM","SES","HTF"};
   for(int i=0;i<10;i++){
      CreateLabel("V15_R14_"+v14rows[i]+"_K",rx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_R14_"+v14rows[i]+"_V",rx+110,y+i*17,"",InpClrTextNormal,8,false);
   }
   y+=178;
   
   // === MARKET CONTEXT ===
   CreateRect("V15_SEP2",InpPanelX+4,y,InpPanelW-8,1,InpClrPanelBorder,InpClrPanelBorder);y+=4;
   CreateLabel("V15_CTX_HDR",lx,y,"MARKET CONTEXT",InpClrTextBright,9,true);y+=18;
   string ctxrows[]={"TREND_H1","TREND_H4","ZONE","VOL","SESSION","REGIME","DR_BIAS","STRUCT"};
   for(int i=0;i<8;i++){
      int cx=(i<4)?lx:rx;int cy=y+(i%4)*17;
      CreateLabel("V15_CTX_"+ctxrows[i]+"_K",cx,cy,"",InpClrNeutral,8,false);
      CreateLabel("V15_CTX_"+ctxrows[i]+"_V",cx+100,cy,"",InpClrTextNormal,8,false);
   }
   y+=75;
   
   // === INSTITUTIONAL LEVELS ===
   CreateRect("V15_SEP2B",InpPanelX+4,y,InpPanelW-8,1,InpClrPanelBorder,InpClrPanelBorder);y+=4;
   CreateLabel("V15_INST_HDR",lx,y,"INSTITUTIONAL",C'200,170,255',9,true);
   CreateLabel("V15_MTF_HDR",rx,y,"MTF CONFLUENCE",C'200,170,255',9,true);
   y+=18;
   string instrows[]={"VWAP","VWAP_BAND","POC","CUMDELTA"};
   for(int i=0;i<4;i++){
      CreateLabel("V15_INST_"+instrows[i]+"_K",lx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_INST_"+instrows[i]+"_V",lx+100,y+i*17,"",InpClrTextNormal,8,false);
   }
   string mtfrows[]={"H4","H1","M15","M5","CONF"};
   for(int i=0;i<5;i++){
      CreateLabel("V15_MTF_"+mtfrows[i]+"_K",rx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_MTF_"+mtfrows[i]+"_V",rx+100,y+i*17,"",InpClrTextNormal,8,false);
   }
   y+=90;
   
   // === RISK GUIDANCE (left) ===
   CreateRect("V15_SEP3",InpPanelX+4,y,InpPanelW-8,1,InpClrPanelBorder,InpClrPanelBorder);y+=4;
   CreateLabel("V15_RISK_HDR",lx,y,"RISK GUIDANCE",InpClrTextBright,9,true);
   CreateLabel("V15_OF_HDR",rx,y,"ORDER FLOW",C'255,180,50',9,true);
   y+=18;
   string riskrows[]={"DIR","SL","TP","RR","LOT","RISK","REASON"};
   for(int i=0;i<7;i++){
      CreateLabel("V15_RISK_"+riskrows[i]+"_K",lx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_RISK_"+riskrows[i]+"_V",lx+100,y+i*17,"",InpClrTextNormal,8,false);
   }
   // Order Flow rows (right side)
   string ofrows[]={"DELTA","DELTA_BAR","ABSORB","STACKED","EXHAUST","FLOW","BIGVOL"};
   for(int i=0;i<7;i++){
      CreateLabel("V15_OF_"+ofrows[i]+"_K",rx,y+i*17,"",InpClrNeutral,8,false);
      CreateLabel("V15_OF_"+ofrows[i]+"_V",rx+100,y+i*17,"",InpClrTextNormal,8,false);
   }
   y+=127;
   
   // === CHECKLIST ===
   CreateRect("V15_SEP4",InpPanelX+4,y,InpPanelW-8,1,InpClrPanelBorder,InpClrPanelBorder);y+=4;
   CreateLabel("V15_CHK_HDR",lx,y,"ENTRY CHECKLIST",InpClrTextBright,9,true);y+=18;
   string chkrows[]={"CHK1","CHK2","CHK3","CHK4","CHK5","CHK6","CHK7","CHK8","CHK9","CHK10"};
   for(int i=0;i<10;i++){
      int cx=(i<5)?lx:rx;int cy=y+(i%5)*16;
      CreateLabel("V15_"+chkrows[i],cx,cy,"",InpClrNeutral,8,false);
   }
   y+=88;
   CreateLabel("V15_BLOCKER",lx,y,"",InpClrWarn,8,true);
   y+=18;
   CreateLabel("V15_VHOCH",lx,y,"",C'255,220,100',8,true);
}

void CreateLabel(string name,int x,int y,string text,color clr,int size,bool bold){
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetString(0,name,OBJPROP_TEXT,(text=="")?"-":text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetString(0,name,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void CreateRect(string name,int x,int y,int w,int h,color bg,color border){
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

//+------------------------------------------------------------------+
//| PANEL UPDATE                                                      |
//+------------------------------------------------------------------+
void UpdatePanel(){
   // Subtitle
   string sym=_Symbol;
   string tf=EnumToString(Period());
   MqlDateTime dt;TimeCurrent(dt);
   string ts=StringFormat("%02d:%02d:%02d",dt.hour,dt.min,dt.sec);
   // Dominant TF for analysis
   string dom_tf="M15";
   string dom_dir="─";
   if(gMTF.h4_sig!=0){dom_tf="H4";dom_dir=(gMTF.h4_sig==1)?"LONG":"SHORT";}
   else if(gMTF.h1_sig!=0){dom_tf="H1";dom_dir=(gMTF.h1_sig==1)?"LONG":"SHORT";}
   else if(gMTF.m15_sig!=0){dom_tf="M15";dom_dir=(gMTF.m15_sig==1)?"LONG":"SHORT";}
   ObjectSetString(0,"V15_SUBTITLE",OBJPROP_TEXT,sym+" | "+tf+" | "+SesStr(g14.ses)+" | "+ts+" | Dom:"+dom_tf+" "+dom_dir);
   
   // === V13.8 LEFT PANEL ===
   SetLbl("V15_L13_CONN_K","Connection:"); SetLbl("V15_L13_STATE_K","State:");
   SetLbl("V15_L13_SWEEP_K","Sweep:"); SetLbl("V15_L13_OB_K","Order Block:");
   SetLbl("V15_L13_FVG_K","FVG:"); SetLbl("V15_L13_TOUCH_K","OB Touch:");
   SetLbl("V15_L13_MICRO_K","Micro Conf:"); SetLbl("V15_L13_QUAL_K","Quality:");
   SetLbl("V15_L13_GOV_K","Governor:"); SetLbl("V15_L13_PNL_K","Daily PnL:");
   
   if(!g13.conn){
      SetLblC("V15_L13_CONN_V","OFFLINE ⚫",InpClrBear);
      SetLblC("V15_L13_STATE_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_SWEEP_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_OB_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_FVG_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_TOUCH_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_MICRO_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_QUAL_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_GOV_V","N/A",InpClrNeutral);
      SetLblC("V15_L13_PNL_V","N/A",InpClrNeutral);
   } else {
      SetLblC("V15_L13_CONN_V","ONLINE 🟢",InpClrBull);
      string states[]={"IDLE","SCANNING","SWEEP_DET","OB_SEARCH","OB_FORM","OB_TOUCH","MICRO_WAIT","ARMED","EXEC","COOLDOWN"};
      string st_str=(g13.state>=0&&g13.state<10)?states[g13.state]:"UNKNOWN";
      color st_clr=(g13.state>=7)?InpClrBull:(g13.state>=3)?InpClrWarn:InpClrNeutral;
      SetLblC("V15_L13_STATE_V",st_str,st_clr);
      
      if(g13.sw_v) SetLblC("V15_L13_SWEEP_V","✅ "+(g13.sw_tp==1?"EQL ":"EQH ")+DoubleToString(g13.sw_lev,_Digits),InpClrBull);
      else SetLblC("V15_L13_SWEEP_V","⏳ Searching...",InpClrNeutral);
      
      if(g13.ob_cnt>0){
         string ob_info=""; int vcount=0;
         for(int i=0;i<5;i++) if(g13.obs[i].v){ob_info=(g13.obs[i].tp==1)?"Bull ":"Bear ";ob_info+=DoubleToString(g13.obs[i].l,_Digits)+"-"+DoubleToString(g13.obs[i].h,_Digits);vcount++;break;}
         SetLblC("V15_L13_OB_V","✅ "+ob_info+" ("+IntegerToString(vcount)+")",(vcount>0)?InpClrBull:InpClrNeutral);
      } else SetLblC("V15_L13_OB_V","⏳ None",InpClrNeutral);
      
      if(g13.fvg_v) SetLblC("V15_L13_FVG_V","✅ "+DoubleToString(g13.fvg_l,_Digits)+"-"+DoubleToString(g13.fvg_h,_Digits)+" Sc:"+DoubleToString(g13.fvg_sc,0),InpClrBull);
      else SetLblC("V15_L13_FVG_V","⏳ None",InpClrNeutral);
      
      bool any_touch=false;for(int i=0;i<5;i++) if(g13.obs[i].v&&g13.obs[i].touched) any_touch=true;
      SetLblC("V15_L13_TOUCH_V",any_touch?"✅ Touched":((g13.ob_cnt>0)?"⏳ Waiting":"─"),any_touch?InpClrBull:InpClrNeutral);
      SetLblC("V15_L13_MICRO_V",(g13.state>=6)?"✅ Confirmed":"⏳ Waiting",(g13.state>=6)?InpClrBull:InpClrNeutral);
      
      string quals[]={"REJECT","B","A","A+"};
      color qclr=(g13.qual>=3)?InpClrBull:(g13.qual>=2)?C'100,200,255':(g13.qual>=1)?InpClrWarn:InpClrBear;
      SetLblC("V15_L13_QUAL_V",(g13.qual>=0&&g13.qual<4)?quals[g13.qual]+"|Sc:"+DoubleToString(g13.sqs_t,0):"?",qclr);
      
      string govs[]={"NORMAL","REDUCED","DEFENSIVE","HALT"};
      color gclr=(g13.gov_st==0)?InpClrBull:(g13.gov_st==1)?InpClrWarn:(g13.gov_st==2)?InpClrBear:InpClrBear;
      SetLblC("V15_L13_GOV_V",(g13.gov_st>=0&&g13.gov_st<4)?govs[g13.gov_st]:"?",gclr);
      
      color pclr=(g13.daily_pnl>=0)?InpClrBull:InpClrBear;
      SetLblC("V15_L13_PNL_V","$"+DoubleToString(g13.daily_pnl,2)+" W:"+IntegerToString(g13.wins)+" L:"+IntegerToString(g13.losses),pclr);
   }
   
   // === V14 RIGHT PANEL ===
   SetLbl("V15_R14_BIAS_K","Bias:"); SetLbl("V15_R14_EMA_K","EMA "+IntegerToString(InpEMA_Fast)+"/"+IntegerToString(InpEMA_Slow)+":");
   SetLbl("V15_R14_RSI_K","RSI("+IntegerToString(InpRSI_Period)+"):"); SetLbl("V15_R14_CROSS_K","Crossover:");
   SetLbl("V15_R14_SIG_K","Signal:"); SetLbl("V15_R14_SCORE_K","Score:");
   SetLbl("V15_R14_QUAL_K","Quality:"); SetLbl("V15_R14_MOM_K","Momentum:");
   SetLbl("V15_R14_SES_K","Session:"); SetLbl("V15_R14_HTF_K","HTF Align:");
   
   SetLblC("V15_R14_BIAS_V",BiasStr(g14.bias),BiasClr(g14.bias));
   SetLblC("V15_R14_EMA_V",g14.tr_bull?"BULLISH ▲":g14.tr_bear?"BEARISH ▼":"FLAT",g14.tr_bull?InpClrBull:g14.tr_bear?InpClrBear:InpClrNeutral);
   
   color rsi_clr=(g14.rsi<InpRSI_BuyBelow)?InpClrBull:(g14.rsi>InpRSI_SellAbove)?InpClrBear:InpClrNeutral;
   string rsi_tag=(g14.rsi<30)?" OVERSOLD":(g14.rsi>70)?" OVERBOUGHT":(g14.rsi<InpRSI_BuyBelow)?" Dip ✅":(g14.rsi>InpRSI_SellAbove)?" Rally ✅":"";
   SetLblC("V15_R14_RSI_V",DoubleToString(g14.rsi,1)+rsi_tag,rsi_clr);
   
   if(g14.cx_bull) SetLblC("V15_R14_CROSS_V","🔥 FRESH BULL ▲",InpClrBull);
   else if(g14.cx_bear) SetLblC("V15_R14_CROSS_V","🔥 FRESH BEAR ▼",InpClrBear);
   else SetLblC("V15_R14_CROSS_V","─ None",InpClrNeutral);
   
   if(g14.sig==1) SetLblC("V15_R14_SIG_V","🟢 BUY",InpClrBull);
   else if(g14.sig==-1) SetLblC("V15_R14_SIG_V","🔴 SELL",InpClrBear);
   else SetLblC("V15_R14_SIG_V","─ No Signal",InpClrNeutral);
   
   SetLblC("V15_R14_SCORE_V",DoubleToString(g14.score,0)+"/100",QualClr(g14.qual));
   SetLblC("V15_R14_QUAL_V",QualStr(g14.qual),QualClr(g14.qual));
   
   double mom=MathAbs(g14.ema_sp);string momtag=(g14.atr>0&&mom/g14.atr>0.5)?"STRONG":(g14.atr>0&&mom/g14.atr>0.2)?"MODERATE":"WEAK";
   SetLblC("V15_R14_MOM_V",momtag,(momtag=="STRONG")?InpClrBull:(momtag=="MODERATE")?InpClrWarn:InpClrNeutral);
   
   bool ses_ok=(g14.ses==SESSION_LONDON||g14.ses==SESSION_NY||g14.ses==SESSION_OVERLAP);
   SetLblC("V15_R14_SES_V",SesStr(g14.ses)+(ses_ok?" ✅":" ⚠"),ses_ok?InpClrBull:InpClrWarn);
   
   bool htf_aligned=((g14.sig==1&&(g14.htf1==BIAS_LONG||g14.htf2==BIAS_LONG))||(g14.sig==-1&&(g14.htf1==BIAS_SHORT||g14.htf2==BIAS_SHORT)));
   SetLblC("V15_R14_HTF_V","H1:"+BiasStr(g14.htf1)+" H4:"+BiasStr(g14.htf2),htf_aligned?InpClrBull:InpClrNeutral);
   
   // === MARKET CONTEXT ===
   SetLbl("V15_CTX_TREND_H1_K","Trend H1:");SetLblC("V15_CTX_TREND_H1_V",BiasStr(g14.htf1),BiasClr(g14.htf1));
   SetLbl("V15_CTX_TREND_H4_K","Trend H4:");SetLblC("V15_CTX_TREND_H4_V",BiasStr(g14.htf2),BiasClr(g14.htf2));
   SetLbl("V15_CTX_ZONE_K","Zone:");SetLblC("V15_CTX_ZONE_V",ZoneStr(g14.zone),(g14.zone==ZONE_DISCOUNT)?InpClrBull:(g14.zone==ZONE_PREMIUM)?InpClrBear:InpClrNeutral);
   SetLbl("V15_CTX_VOL_K","Volatility:");
   string vol_tag=(g14.vol>=1.2)?"HIGH":(g14.vol>=0.7)?"NORMAL":"LOW";
   SetLblC("V15_CTX_VOL_V",DoubleToString(g14.vol,2)+" ("+vol_tag+")",(vol_tag=="LOW")?InpClrBear:(vol_tag=="HIGH")?InpClrWarn:InpClrBull);
   SetLbl("V15_CTX_SESSION_K","Session:");SetLblC("V15_CTX_SESSION_V",SesStr(g14.ses),ses_ok?InpClrBull:InpClrNeutral);
   SetLbl("V15_CTX_STRUCT_K","Structure:");
   color struct_clr=(gStructureBias==1)?InpClrBull:(gStructureBias==-1)?InpClrBear:InpClrNeutral;
   SetLblC("V15_CTX_STRUCT_V",gStructureLabel,struct_clr);
   SetLbl("V15_CTX_REGIME_K","Regime:");
   color regclr=(g14.reg==REG_TREND)?InpClrBull:(g14.reg==REG_RANGE)?InpClrWarn:InpClrBear;
   SetLblC("V15_CTX_REGIME_V",RegStr(g14.reg),regclr);
   SetLbl("V15_CTX_DR_BIAS_K","DR Bias:");
   if(gDR_lock) SetLblC("V15_CTX_DR_BIAS_V",(gDR_bias==1)?"LONG ▲":"SHORT ▼",(gDR_bias==1)?InpClrBull:InpClrBear);
   else SetLblC("V15_CTX_DR_BIAS_V","Not locked",InpClrNeutral);
   SetLbl("V15_CTX_STRUCT_K","Structure:");
   string struct_info2=gStructureLabel;
   if(gSwingPattern!="") struct_info2+=" ["+gSwingPattern+"]";
   color struct_clr2=(gStructureBias==1)?InpClrBull:(gStructureBias==-1)?InpClrBear:InpClrNeutral;
   SetLblC("V15_CTX_STRUCT_V",struct_info2,struct_clr2);
   
   // === INSTITUTIONAL LEVELS ===
   SetLbl("V15_INST_VWAP_K","VWAP:");
   SetLbl("V15_INST_VWAP_BAND_K","VWAP Band:");
   SetLbl("V15_INST_POC_K","POC:");
   SetLbl("V15_INST_CUMDELTA_K","Cum Delta:");
   
   double p_inst=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(gVWAP>0){
      color vwap_clr=(p_inst>gVWAP)?InpClrBull:InpClrBear;
      string vwap_pos=(p_inst>gVWAP)?"Above ▲":"Below ▼";
      SetLblC("V15_INST_VWAP_V",DoubleToString(gVWAP,_Digits)+" ("+vwap_pos+")",vwap_clr);
      // Band
      string band_pos="INSIDE";color band_clr=InpClrBull;
      if(p_inst>gVWAP_upper){band_pos="ABOVE +1σ (Overbought)";band_clr=InpClrBear;}
      else if(p_inst<gVWAP_lower){band_pos="BELOW -1σ (Oversold)";band_clr=InpClrBull;}
      else{band_pos="INSIDE σ (Fair)";band_clr=InpClrNeutral;}
      SetLblC("V15_INST_VWAP_BAND_V",band_pos,band_clr);
   } else {
      SetLblC("V15_INST_VWAP_V","Calculating...",InpClrNeutral);
      SetLblC("V15_INST_VWAP_BAND_V","─",InpClrNeutral);
   }
   
   if(gPOC>0){
      color poc_clr=(p_inst>gPOC)?InpClrBull:InpClrBear;
      double poc_dist=MathAbs(p_inst-gPOC);
      SetLblC("V15_INST_POC_V",DoubleToString(gPOC,_Digits)+" Dist:"+DoubleToString(poc_dist,_Digits),poc_clr);
   } else SetLblC("V15_INST_POC_V","─",InpClrNeutral);
   
   color cd_clr=(gOF.delta_cum>0)?InpClrBull:(gOF.delta_cum<0)?InpClrBear:InpClrNeutral;
   SetLblC("V15_INST_CUMDELTA_V",DoubleToString(gOF.delta_cum,0)+(gOF.delta_cum>0?" ▲ BUYERS":" ▼ SELLERS"),cd_clr);
   
   // MTF Confluence (H4 > H1 > M15 > M5 priority)
   SetLbl("V15_MTF_H4_K","H4 ★★★:");
   SetLbl("V15_MTF_H1_K","H1 ★★:");
   SetLbl("V15_MTF_M15_K","M15 ★:");
   SetLbl("V15_MTF_M5_K","M5:");
   SetLbl("V15_MTF_CONF_K","Confluence:");
   
   // Can't use nested functions in MQL5, inline it:
   SetLblC("V15_MTF_H4_V",(gMTF.h4_sig==1)?"▲ LONG":(gMTF.h4_sig==-1)?"▼ SHORT":"─ FLAT",(gMTF.h4_sig==1)?InpClrBull:(gMTF.h4_sig==-1)?InpClrBear:InpClrNeutral);
   SetLblC("V15_MTF_H1_V",(gMTF.h1_sig==1)?"▲ LONG":(gMTF.h1_sig==-1)?"▼ SHORT":"─ FLAT",(gMTF.h1_sig==1)?InpClrBull:(gMTF.h1_sig==-1)?InpClrBear:InpClrNeutral);
   SetLblC("V15_MTF_M15_V",(gMTF.m15_sig==1)?"▲ LONG":(gMTF.m15_sig==-1)?"▼ SHORT":"─ FLAT",(gMTF.m15_sig==1)?InpClrBull:(gMTF.m15_sig==-1)?InpClrBear:InpClrNeutral);
   SetLblC("V15_MTF_M5_V",(gMTF.m5_sig==1)?"▲ LONG":(gMTF.m5_sig==-1)?"▼ SHORT":"─ FLAT",(gMTF.m5_sig==1)?InpClrBull:(gMTF.m5_sig==-1)?InpClrBear:InpClrNeutral);
   color conf_clr=(gMTF.confluence>=3)?InpClrBull:(gMTF.confluence<=-3)?InpClrBear:(MathAbs(gMTF.confluence)>=2)?InpClrWarn:InpClrNeutral;
   SetLblC("V15_MTF_CONF_V",gMTF.label,conf_clr);
   
   // === RISK GUIDANCE ===
   SetLbl("V15_RISK_DIR_K","Direction:");
   SetLbl("V15_RISK_SL_K","Stop Loss:");
   SetLbl("V15_RISK_TP_K","Take Profit:");
   SetLbl("V15_RISK_RR_K","Risk:Reward:");
   SetLbl("V15_RISK_LOT_K","Lot Size:");
   SetLbl("V15_RISK_RISK_K","Risk %:");
   SetLbl("V15_RISK_REASON_K","Reason:");
   
   double p=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(g14.sig!=0){
      // === ACTIVE SIGNAL — full colors ===
      SetLblC("V15_RISK_DIR_V",(g14.sig==1)?"🟢 BUY":"🔴 SELL",(g14.sig==1)?InpClrBull:InpClrBear);
      double sl_price=(g14.sig==1)?(p-g14.sl_d):(p+g14.sl_d);
      double tp_price=(g14.sig==1)?(p+g14.tp_d):(p-g14.tp_d);
      SetLblC("V15_RISK_SL_V",DoubleToString(sl_price,_Digits)+" ("+DoubleToString(g14.sl_d,_Digits)+")",InpClrBear);
      SetLblC("V15_RISK_TP_V",DoubleToString(tp_price,_Digits)+" ("+DoubleToString(g14.tp_d,_Digits)+")",InpClrBull);
      SetLblC("V15_RISK_RR_V","1 : "+DoubleToString(g14.rr,2),(g14.rr>=1.5)?InpClrBull:InpClrWarn);
      SetLblC("V15_RISK_LOT_V",DoubleToString(g14.lot,2)+" (Bal:$"+DoubleToString(InpAccBal,0)+")",InpClrTextBright);
      double rp=InpBaseRisk*((g14.qual==Q_APLUS)?InpRiskAP:(g14.qual==Q_A)?InpRiskA:InpRiskB);
      SetLblC("V15_RISK_RISK_V",DoubleToString(rp,2)+"% ($"+DoubleToString(InpAccBal*rp/100,2)+")",(rp>1.0)?InpClrWarn:InpClrBull);
      string reason="";
      if(g14.cx_bull||g14.cx_bear) reason+="Fresh Cross ";
      if(g14.rsi<InpRSI_BuyBelow&&g14.sig==1) reason+="RSI Dip ";
      if(g14.rsi>InpRSI_SellAbove&&g14.sig==-1) reason+="RSI Rally ";
      if(htf_aligned) reason+="HTF✅ ";
      if((g14.sig==1&&g14.zone==ZONE_DISCOUNT)||(g14.sig==-1&&g14.zone==ZONE_PREMIUM)) reason+="Zone✅ ";
      // Estimated duration: TP distance / ATR per bar ≈ how many bars to reach TP
      int est_bars=0; string est_time="";
      if(g14.atr>0){
         est_bars=(int)MathCeil(g14.tp_d/g14.atr);
         int period_min=PeriodSeconds()/60;
         int total_min=est_bars*period_min;
         if(total_min>=60) est_time=IntegerToString(total_min/60)+"h"+IntegerToString(total_min%60)+"m";
         else est_time=IntegerToString(total_min)+"m";
      }
      reason+="~"+est_time;
      SetLblC("V15_RISK_REASON_V",reason,InpClrTextNormal);
   } else {
      // === NO SIGNAL — show REFERENCE values in dim color ===
      color refClr=C'90,90,100'; // Dim gray = reference only
      // Direction from bias/MTF
      int ref_dir=0;
      if(g14.tr_bull) ref_dir=1; else if(g14.tr_bear) ref_dir=-1;
      if(ref_dir==0 && gMTF.confluence>=2) ref_dir=1;
      if(ref_dir==0 && gMTF.confluence<=-2) ref_dir=-1;
      
      if(ref_dir!=0 && g14.atr>0){
         string dir_tag=(ref_dir==1)?"~ BUY (ref)":"~ SELL (ref)";
         SetLblC("V15_RISK_DIR_V",dir_tag,refClr);
         double sl_d=g14.atr*InpSL_ATR; double tp_d=g14.atr*InpTP_ATR;
         double sl_p=(ref_dir==1)?(p-sl_d):(p+sl_d);
         double tp_p=(ref_dir==1)?(p+tp_d):(p-tp_d);
         double rr=(sl_d>0)?tp_d/sl_d:0;
         SetLblC("V15_RISK_SL_V","~ "+DoubleToString(sl_p,_Digits)+" ("+DoubleToString(sl_d,_Digits)+")",refClr);
         SetLblC("V15_RISK_TP_V","~ "+DoubleToString(tp_p,_Digits)+" ("+DoubleToString(tp_d,_Digits)+")",refClr);
         SetLblC("V15_RISK_RR_V","~ 1 : "+DoubleToString(rr,2),refClr);
         // Lot calc
         double rp=InpBaseRisk*InpRiskB; // B quality default
         double ra=InpAccBal*(rp/100.0);
         double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
         double lot=0;
         if(ts>0&&tv>0&&sl_d>0){
            lot=ra/((sl_d/ts)*tv);
            double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
            if(step>0) lot=MathFloor(lot/step)*step;
            lot=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),lot);
         }
         SetLblC("V15_RISK_LOT_V","~ "+DoubleToString(lot,2)+" (Bal:$"+DoubleToString(InpAccBal,0)+")",refClr);
         SetLblC("V15_RISK_RISK_V","~ "+DoubleToString(rp,2)+"% ($"+DoubleToString(InpAccBal*rp/100,2)+")",refClr);
         // Reason — why no signal + estimated duration
         string blockers="";
         bool ses_ok2=(g14.ses==SESSION_LONDON||g14.ses==SESSION_NY||g14.ses==SESSION_OVERLAP);
         if(!ses_ok2) blockers+="SesOFF ";
         if(g14.reg==REG_CHOP) blockers+="Choppy ";
         if(g14.vol<0.5) blockers+="LowVol ";
         if(!g14.cx_bull&&!g14.cx_bear&&g14.rsi>InpRSI_BuyBelow&&g14.rsi<InpRSI_SellAbove) blockers+="NoTrig ";
         // Estimated duration
         int est_bars2=(int)MathCeil(tp_d/g14.atr);
         int period_min2=PeriodSeconds()/60;
         int total_min2=est_bars2*period_min2;
         string est_t2="";
         if(total_min2>=60) est_t2=IntegerToString(total_min2/60)+"h"+IntegerToString(total_min2%60)+"m";
         else est_t2=IntegerToString(total_min2)+"m";
         SetLblC("V15_RISK_REASON_V","REF: "+blockers+"~"+est_t2,refClr);
      } else {
         SetLblC("V15_RISK_DIR_V","─ No bias",refClr);
         SetLblC("V15_RISK_SL_V","─",refClr);SetLblC("V15_RISK_TP_V","─",refClr);
         SetLblC("V15_RISK_RR_V","─",refClr);SetLblC("V15_RISK_LOT_V","─",refClr);
         SetLblC("V15_RISK_RISK_V","─",refClr);SetLblC("V15_RISK_REASON_V","No direction bias",refClr);
      }
   }
   
   // === ORDER FLOW (right side of Risk Guidance) ===
   SetLbl("V15_OF_DELTA_K","Delta:");
   SetLbl("V15_OF_DELTA_BAR_K","Delta Bar:");
   SetLbl("V15_OF_ABSORB_K","Absorption:");
   SetLbl("V15_OF_STACKED_K","Stacked:");
   SetLbl("V15_OF_EXHAUST_K","Exhaustion:");
   SetLbl("V15_OF_FLOW_K","Flow Bias:");
   SetLbl("V15_OF_BIGVOL_K","Vol Spike:");
   
   // Delta
   color delta_clr=(gOF.delta_pct>10)?InpClrBull:(gOF.delta_pct<-10)?InpClrBear:InpClrNeutral;
   string delta_dir=(gOF.delta_pct>5)?"▲ BUYERS":(gOF.delta_pct<-5)?"▼ SELLERS":"─ BALANCED";
   SetLblC("V15_OF_DELTA_V",DoubleToString(gOF.delta_pct,1)+"% "+delta_dir,delta_clr);
   
   // Delta bar visual
   string delta_bar="";
   int bar_len=(int)MathMin(15,MathAbs(gOF.delta_pct)/5);
   for(int i=0;i<bar_len;i++) delta_bar+="█";
   if(bar_len==0) delta_bar="─";
   SetLblC("V15_OF_DELTA_BAR_V",(gOF.delta_pct>=0?"+ ":"- ")+delta_bar,delta_clr);
   
   // Absorption
   if(gOF.absorption){
      color abs_clr=(gOF.absorb_type=="BULL ABSORB")?InpClrBull:InpClrBear;
      SetLblC("V15_OF_ABSORB_V","⚡ "+gOF.absorb_type+" ("+DoubleToString(gOF.absorb_vol,1)+"x)",abs_clr);
   } else {
      // Show proximity: vol Xx / body X%
      string prox="Vol:"+DoubleToString(gOF.best_abs_vol,1)+"x Body:"+DoubleToString(gOF.best_abs_body*100,0)+"%";
      color prox_clr=(gOF.best_abs_vol>1.0)?InpClrWarn:InpClrNeutral;
      SetLblC("V15_OF_ABSORB_V",prox,prox_clr);
   }
   
   // Stacked Imbalance
   if(gOF.stacked_count>=3){
      color stk_clr=(gOF.stacked_dir==1)?InpClrBull:InpClrBear;
      string stk_str=(gOF.stacked_dir==1)?"▲ BUY x":"▼ SELL x";
      SetLblC("V15_OF_STACKED_V","🔥 "+stk_str+IntegerToString(gOF.stacked_count),stk_clr);
   } else if(gOF.stacked_count>=2){
      color stk_clr=(gOF.stacked_dir==1)?InpClrBull:InpClrBear;
      SetLblC("V15_OF_STACKED_V",(gOF.stacked_dir==1?"▲ ":"▼ ")+IntegerToString(gOF.stacked_count)+" bars",stk_clr);
   } else {
      SetLblC("V15_OF_STACKED_V",IntegerToString(gOF.stacked_count)+" bar streak",InpClrNeutral);
   }
   
   // Exhaustion
   if(gOF.exhaustion){
      color exh_clr=(gOF.exhaust_type=="BUY EXHAUST")?InpClrBear:InpClrBull;
      SetLblC("V15_OF_EXHAUST_V","⚠ "+gOF.exhaust_type,exh_clr);
   } else {
      // Show proximity: wick% / vol ratio
      string eprox="Wick:"+DoubleToString(gOF.best_wick_pct*100,0)+"% Vol:"+DoubleToString(gOF.best_exh_vol,1)+"x";
      color eprox_clr=(gOF.best_wick_pct>0.3)?InpClrWarn:InpClrNeutral;
      SetLblC("V15_OF_EXHAUST_V",eprox,eprox_clr);
   }
   
   // Overall Flow Bias
   color flow_clr=(gOF.flow_bias==1)?InpClrBull:(gOF.flow_bias==-1)?InpClrBear:InpClrNeutral;
   SetLblC("V15_OF_FLOW_V",gOF.flow_label,flow_clr);
   
   // Big Volume
   color bv_clr=(gOF.big_vol_ratio>2.0)?C'255,100,100':(gOF.big_vol_ratio>1.5)?InpClrWarn:(gOF.big_vol_ratio>1.0)?InpClrBull:InpClrNeutral;
   string bv_tag=(gOF.big_vol_ratio>2.0)?" SPIKE!":(gOF.big_vol_ratio>1.5)?" HIGH":(gOF.big_vol_ratio>1.0)?" ABOVE AVG":"";
   SetLblC("V15_OF_BIGVOL_V",DoubleToString(gOF.big_vol_ratio,2)+"x"+bv_tag,bv_clr);
   
   // === REAL ORDER FLOW — CVD rows (appended below OF section) ===
   // CVD line label
   if(ObjectFind(0,"V15_OF_CVD_K")<0){ // Create once if missing
      int rx2=InpPanelX+InpPanelW/2+8;
      int oy=InpPanelY+25+178+75+90+18+7*17;
      CreateLabel("V15_OF_CVD_K",    rx2, oy,   "", InpClrNeutral,8,false);
      CreateLabel("V15_OF_CVD_V",    rx2+100,oy, "", InpClrTextNormal,8,false);
      CreateLabel("V15_OF_RDELTA_K", rx2, oy+17, "", InpClrNeutral,8,false);
      CreateLabel("V15_OF_RDELTA_V", rx2+100,oy+17,"",InpClrTextNormal,8,false);
      CreateLabel("V15_OF_CVDDIV_K", rx2, oy+34, "", InpClrNeutral,8,false);
      CreateLabel("V15_OF_CVDDIV_V", rx2+100,oy+34,"",InpClrTextNormal,8,false);
      CreateLabel("V15_OF_BIGTRD_K", rx2, oy+51, "", InpClrNeutral,8,false);
      CreateLabel("V15_OF_BIGTRD_V", rx2+100,oy+51,"",InpClrTextNormal,8,false);
   }
   SetLbl("V15_OF_CVD_K","CVD Today:");
   SetLbl("V15_OF_RDELTA_K","Real Delta:");
   SetLbl("V15_OF_CVDDIV_K","CVD Diverg:");
   SetLbl("V15_OF_BIGTRD_K","Big Trades:");
   
   if(gROF.data_ok){
      color cvd_clr=(gROF.cvd_current>0)?InpClrBull:(gROF.cvd_current<0)?InpClrBear:InpClrNeutral;
      SetLblC("V15_OF_CVD_V",DoubleToString(gROF.cvd_current,0)+(gROF.cvd_current>=0?" ▲":" ▼"),cvd_clr);
      color rd_clr=(gROF.real_delta_pct>5)?InpClrBull:(gROF.real_delta_pct<-5)?InpClrBear:InpClrNeutral;
      SetLblC("V15_OF_RDELTA_V",DoubleToString(gROF.real_delta_pct,1)+"%"+(gROF.real_delta_pct>=0?" BUY":" SELL"),rd_clr);
      if(gROF.cvd_divergence){
         color div_clr=(gROF.cvd_div_type=="BEAR_DIV")?InpClrBear:InpClrBull;
         string div_lbl=(gROF.cvd_div_type=="BEAR_DIV")?"⚠ BEAR DIV (Fake Rally)":"⚠ BULL DIV (Fake Drop)";
         SetLblC("V15_OF_CVDDIV_V",div_lbl,div_clr);
      } else SetLblC("V15_OF_CVDDIV_V","NONE",InpClrNeutral);
      string big_dir=(gROF.large_trade_dir==1)?"▲ BUYERS":(gROF.large_trade_dir==-1)?"▼ SELLERS":"MIXED";
      color big_clr=(gROF.large_trade_dir==1)?InpClrBull:(gROF.large_trade_dir==-1)?InpClrBear:InpClrNeutral;
      SetLblC("V15_OF_BIGTRD_V",IntegerToString(gROF.large_trade_cnt)+" "+big_dir,big_clr);
   } else {
      SetLblC("V15_OF_CVD_V","No Tick Data",InpClrNeutral);
      SetLblC("V15_OF_RDELTA_V","─",InpClrNeutral);
      SetLblC("V15_OF_CVDDIV_V","─",InpClrNeutral);
      SetLblC("V15_OF_BIGTRD_V","─",InpClrNeutral);
   }
   
   // === CHECKLIST ===
   UpdateChecklist();
}

void UpdateChecklist(){
   bool ses_ok=(g14.ses==SESSION_LONDON||g14.ses==SESSION_NY||g14.ses==SESSION_OVERLAP);
   bool htf_ok=((g14.sig==1&&g14.htf1==BIAS_LONG)||(g14.sig==-1&&g14.htf1==BIAS_SHORT)||g14.htf1==BIAS_NEUTRAL);
   bool zone_ok=((g14.sig==1&&g14.zone!=ZONE_PREMIUM)||(g14.sig==-1&&g14.zone!=ZONE_DISCOUNT));
   bool vol_ok=(g14.vol>=0.5); bool rsi_ok=(g14.sig!=0);
   bool regime_ok=(g14.reg!=REG_CHOP);
   bool ob_found=(gOBn>0); bool fvg_found=(gFVGn>0); bool sweep_found=(gSWn>0);
   bool ob_touch=false;for(int i=0;i<gOBn;i++)if(gOBs[i].touched)ob_touch=true;
   
   SetLblC("V15_CHK1",(ses_ok?"[✅] ":"[⏳] ")+"Session: "+SesStr(g14.ses),ses_ok?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK2",(htf_ok?"[✅] ":"[⏳] ")+"HTF Aligned",htf_ok?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK3",(zone_ok?"[✅] ":"[⏳] ")+"Price Zone OK",zone_ok?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK4",(vol_ok?"[✅] ":"[⏳] ")+"Volatility OK",vol_ok?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK5",(regime_ok?"[✅] ":"[⏳] ")+"Regime: "+RegStr(g14.reg),regime_ok?InpClrBull:InpClrBear);
   SetLblC("V15_CHK6",(sweep_found?"[✅] ":"[⏳] ")+"Sweep Detected ("+IntegerToString(gSWn)+")",sweep_found?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK7",(ob_found?"[✅] ":"[⏳] ")+"OB Found ("+IntegerToString(gOBn)+")",ob_found?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK8",(ob_touch?"[✅] ":"[⏳] ")+"OB Touched",ob_touch?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK9",(fvg_found?"[✅] ":"[⏳] ")+"FVG Present ("+IntegerToString(gFVGn)+")",fvg_found?InpClrBull:InpClrNeutral);
   SetLblC("V15_CHK10",(rsi_ok?"[✅] ":"[⏳] ")+"RSI Signal Active",rsi_ok?InpClrBull:InpClrNeutral);
   
   // Blocker
   string blocker="";
   if(!ses_ok) blocker+="Session OFF | ";
   if(g14.reg==REG_CHOP) blocker+="CHOPPY MKT | ";
   if(!vol_ok) blocker+="LOW VOL | ";
   if(g14.sig==0) blocker+="No signal | ";
   if(blocker=="") blocker="ALL CLEAR — Ready to trade";
   bool all_clear=(blocker=="ALL CLEAR — Ready to trade");
   if(!all_clear) blocker="BLOCKERS: "+blocker;
   SetLblC("V15_BLOCKER",blocker,all_clear?InpClrBull:InpClrWarn);
   
   // === VHOCH — Validation of Higher Order Confluence Hypothesis ===
   // Confirmed when: HTF Structure + Order Flow + MTF Alignment all agree
   bool v_struct=(gStructureBias!=0); // Structure has direction
   bool v_of=(gOF.flow_bias!=0);     // Order flow has direction
   bool v_mtf=(MathAbs(gMTF.confluence)>=2); // MTF aligned
   bool v_agree=false;
   string v_reasons="";
   
   if(v_struct && v_of && v_mtf){
      // Check all same direction
      bool all_bull=(gStructureBias==1 && gOF.flow_bias==1 && gMTF.confluence>=2);
      bool all_bear=(gStructureBias==-1 && gOF.flow_bias==-1 && gMTF.confluence<=-2);
      if(all_bull || all_bear){
         v_agree=true;
         v_reasons="Struct+OF+MTF";
         if(gOF.absorption) v_reasons+="+Absorb";
         if(gBOSn>0) v_reasons+="+"+gBOS[0].kind;
      }
   }
   
   if(v_agree){
      string v_dir=(gStructureBias==1)?"BUY":"SELL";
      SetLblC("V15_VHOCH","VHOCH: ✅ CONFIRMED "+v_dir+" | "+v_reasons,InpClrBull);
   } else {
      // Show what's missing
      string missing="";
      if(!v_struct) missing+="Structure ";
      if(!v_of) missing+="OrderFlow ";
      if(!v_mtf) missing+="MTF ";
      if(v_struct && v_of && v_mtf) missing="Direction mismatch";
      SetLblC("V15_VHOCH","VHOCH: ❌ NOT CONFIRMED | Missing: "+missing,C'120,80,80');
   }
}

void SetLbl(string name,string text){ObjectSetString(0,name,OBJPROP_TEXT,text);}
void SetLblC(string name,string text,color clr){ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_COLOR,clr);}

//+------------------------------------------------------------------+
//| VWAP CALCULATION (Intraday)                                       |
//+------------------------------------------------------------------+
void CalcVWAP(){
   MqlRates r[];ArraySetAsSeries(r,true);
   long tv[];ArraySetAsSeries(tv,true);
   MqlDateTime dt;TimeCurrent(dt);
   datetime day_start=TimeCurrent()-(dt.hour*3600+dt.min*60+dt.sec);
   // FIX: Always M15 — stable across all chart TFs (H4 = only 6 bars/day)
   int bars=(int)((TimeCurrent()-day_start)/900)+5; // 900 = M15 seconds
   bars=MathMin(MathMax(bars,5),300);
   if(CopyRates(_Symbol,PERIOD_M15,0,bars,r)<bars) return;
   if(CopyTickVolume(_Symbol,PERIOD_M15,0,bars,tv)<bars) return;
   
   double cum_pv=0, cum_v=0, cum_pv2=0;
   for(int i=0;i<bars;i++){
      if(r[i].time<day_start) continue;
      double typical=(r[i].high+r[i].low+r[i].close)/3.0;
      double vol=(double)tv[i];
      cum_pv+=typical*vol;
      cum_pv2+=typical*typical*vol;
      cum_v+=vol;
   }
   if(cum_v>0){
      gVWAP=cum_pv/cum_v;
      double variance=(cum_pv2/cum_v)-(gVWAP*gVWAP);
      double stddev=(variance>0)?MathSqrt(variance):0;
      gVWAP_upper=gVWAP+stddev;
      gVWAP_lower=gVWAP-stddev;
   }
}

//+------------------------------------------------------------------+
//| POC — Point of Control (highest volume price level)               |
//+------------------------------------------------------------------+
void CalcPOC(){
   MqlRates r[];ArraySetAsSeries(r,true);
   long tv[];ArraySetAsSeries(tv,true);
   int bars=96; // FIX: M15 always, 96 bars = 24h full day
   if(CopyRates(_Symbol,PERIOD_M15,0,bars,r)<bars) return;
   if(CopyTickVolume(_Symbol,PERIOD_M15,0,bars,tv)<bars) return;
   
   // Find price range
   double hi=r[0].high, lo=r[0].low;
   for(int i=1;i<bars;i++){if(r[i].high>hi) hi=r[i].high; if(r[i].low<lo) lo=r[i].low;}
   double range=hi-lo;
   if(range<=0) return;
   
   // Divide into 20 levels, accumulate volume
   int levels=20;
   double level_size=range/levels;
   double vol_profile[];ArrayResize(vol_profile,levels);ArrayInitialize(vol_profile,0);
   
   for(int i=0;i<bars;i++){
      double mid=(r[i].high+r[i].low)/2.0;
      int lvl=(int)((mid-lo)/level_size);
      if(lvl>=levels) lvl=levels-1; if(lvl<0) lvl=0;
      vol_profile[lvl]+=(double)tv[i];
   }
   
   // Find max volume level = POC
   double max_vol=0; int poc_lvl=0;
   for(int i=0;i<levels;i++){
      if(vol_profile[i]>max_vol){max_vol=vol_profile[i]; poc_lvl=i;}
   }
   gPOC=lo+(poc_lvl+0.5)*level_size;
}

//+------------------------------------------------------------------+
//| MTF CONFLUENCE — M5 + M15 + H1 signal agreement                  |
//+------------------------------------------------------------------+
void CalcMTF(){
   gMTF.m5_sig=GetTFSignal(PERIOD_M5);
   gMTF.m15_sig=GetTFSignal(PERIOD_M15);
   gMTF.h1_sig=GetTFSignal(PERIOD_H1);
   gMTF.h4_sig=GetTFSignal(PERIOD_H4);
   
   // Weighted: H4=3, H1=2, M15=1.5, M5=0.5 (H4 is king)
   double score=0;
   score+=gMTF.h4_sig*3.0;   // H4 en önemli
   score+=gMTF.h1_sig*2.0;   // H1 ikinci
   score+=gMTF.m15_sig*1.5;  // M15 üçüncü
   score+=gMTF.m5_sig*0.5;   // M5 en az ağırlık
   
   // Count aligned TFs
   int aligned=0;
   if(gMTF.h4_sig==1) aligned++; if(gMTF.h4_sig==-1) aligned--;
   if(gMTF.h1_sig==1) aligned++; if(gMTF.h1_sig==-1) aligned--;
   if(gMTF.m15_sig==1) aligned++; if(gMTF.m15_sig==-1) aligned--;
   if(gMTF.m5_sig==1) aligned++; if(gMTF.m5_sig==-1) aligned--;
   gMTF.confluence=aligned;
   gMTF.score=score;
   
   // Separate display: Alignment (X/4) + Context Score (+X.X)
   string dir_str=(score>0)?"BUY":"SELL";
   if(score==0) dir_str="NEUTRAL";
   string align_str=dir_str+" ("+IntegerToString(MathAbs(aligned))+"/4)";
   if(MathAbs(score)>=5) gMTF.label="STRONG "+align_str+" | Sc:"+DoubleToString(score,1);
   else if(MathAbs(score)>=2) gMTF.label=align_str+" | Sc:"+DoubleToString(score,1);
   else if(MathAbs(score)>0) gMTF.label="WEAK "+align_str;
   else gMTF.label="MIXED (0/4)";
}

int GetTFSignal(ENUM_TIMEFRAMES tf){
   MqlRates r[];ArraySetAsSeries(r,true);
   int cnt=CopyRates(_Symbol,tf,0,200,r);
   if(cnt<50) return 0;
   // Manual EMA fast/slow
   double ef=r[cnt-1].close, es=r[cnt-1].close;
   double mf=2.0/(InpEMA_Fast+1), ms_m=2.0/(InpEMA_Slow+1);
   for(int i=cnt-2;i>=0;i--){
      ef=r[i].close*mf+ef*(1.0-mf);
      es=r[i].close*ms_m+es*(1.0-ms_m);
   }
   if(ef>es) return 1;
   if(ef<es) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE — BOS / CHoCH / Swing Points (Professional)      |
//| Algorithm: Fractal-based swing detection + closed-bar BOS/CHoCH  |
//+------------------------------------------------------------------+
void DetectStructure(){
   MqlRates r[];ArraySetAsSeries(r,true);
   int bars=CopyRates(_Symbol,PERIOD_CURRENT,0,100,r);
   if(bars<30) return;
   
   // Adaptive fractal length: smaller for higher TFs
   int fractal_len=3; // Default 7-bar window
   int period_sec=PeriodSeconds();
   if(period_sec>=14400) fractal_len=2; // H4+ use 5-bar window (more swing points)
   else if(period_sec>=3600) fractal_len=2; // H1 use 5-bar window
   
   // === STEP 1: Detect Swing Highs and Swing Lows (fractal pivots) ===
   gSwingN=0;
   for(int i=fractal_len;i<bars-fractal_len && gSwingN<20;i++){
      // Swing High: bar[i].high >= all bars in window
      bool is_sh=true;
      for(int j=i-fractal_len;j<=i+fractal_len;j++){
         if(j==i) continue;
         if(r[j].high>r[i].high){is_sh=false;break;}
      }
      // Swing Low: bar[i].low <= all bars in window
      bool is_sl=true;
      for(int j=i-fractal_len;j<=i+fractal_len;j++){
         if(j==i) continue;
         if(r[j].low<r[i].low){is_sl=false;break;}
      }
      if(is_sh){
         gSwings[gSwingN].price=r[i].high;
         gSwings[gSwingN].time=r[i].time;
         gSwings[gSwingN].type=1;
         gSwings[gSwingN].bar_index=i;
         gSwings[gSwingN].label="";
         gSwingN++;
      }
      if(is_sl && gSwingN<20){
         gSwings[gSwingN].price=r[i].low;
         gSwings[gSwingN].time=r[i].time;
         gSwings[gSwingN].type=-1;
         gSwings[gSwingN].bar_index=i;
         gSwings[gSwingN].label="";
         gSwingN++;
      }
   }
   
   if(gTick%20==0) Print("V15 STRUCT: swings=",gSwingN," fractal=",fractal_len," bars=",bars);
   
   // === STEP 2: Label Swing Points — HH, HL, LH, LL ===
   double last_sh=0, last_sl=0;
   for(int i=gSwingN-1;i>=0;i--){
      if(gSwings[i].type==1){ // Swing High
         if(last_sh==0){gSwings[i].label="SH"; last_sh=gSwings[i].price; continue;}
         if(gSwings[i].price>last_sh) gSwings[i].label="HH";
         else gSwings[i].label="LH";
         last_sh=gSwings[i].price;
      } else { // Swing Low
         if(last_sl==0){gSwings[i].label="SL"; last_sl=gSwings[i].price; continue;}
         if(gSwings[i].price>last_sl) gSwings[i].label="HL";
         else gSwings[i].label="LL";
         last_sl=gSwings[i].price;
      }
   }
   
   // FIX: Pattern from last 6 swings (more reliable)
   gSwingPattern="";
   int cnt=0;
   for(int i=0;i<gSwingN && cnt<6;i++){
      if(gSwings[i].label!="" && gSwings[i].label!="SH" && gSwings[i].label!="SL"){
         if(cnt>0) gSwingPattern+="-";
         gSwingPattern+=gSwings[i].label;
         cnt++;
      }
   }
   
   // === STEP 3: Detect BOS and CHoCH ===
   gBOSn=0;
   gStructureBias=0;
   gStructureLabel="─ UNDEFINED";
   
   // *** INSTITUTIONAL SEQUENCE LOGIC (per doc spec) ***
   // Trend = sequence, NOT single point
   // Bullish: HH → HL → HH (3+ bullish swings, 0 bearish)
   // Bearish: LL → LH → LL (3+ bearish swings, 0 bullish)
   int bull_count=0, bear_count=0;
   int swing_checked=0;
   for(int i=0;i<gSwingN && swing_checked<6;i++){
      string lb=gSwings[i].label;
      if(lb=="SH" || lb=="SL" || lb=="") continue;
      if(lb=="HH" || lb=="HL") bull_count++;
      if(lb=="LH" || lb=="LL") bear_count++;
      swing_checked++;
   }
   
   // FIX: Realistic trend — bull>=2x bear AND at least 2 bull swings
   bool uptrend   = (bull_count >= MathMax(2, bear_count*2) && bull_count >= 2);
   bool downtrend = (bear_count >= MathMax(2, bull_count*2) && bear_count >= 2);
   
   // Find last significant swing high and swing low (closed-bar only)
   double prev_sh=0, prev_sl=0;
   datetime prev_sh_t=0, prev_sl_t=0;
   for(int i=0;i<gSwingN;i++){
      if(gSwings[i].type==1 && prev_sh==0){prev_sh=gSwings[i].price; prev_sh_t=gSwings[i].time;}
      if(gSwings[i].type==-1 && prev_sl==0){prev_sl=gSwings[i].price; prev_sl_t=gSwings[i].time;}
      if(prev_sh>0 && prev_sl>0) break;
   }
   
   double close1=r[1].close; // Last CLOSED bar (no repaint)
   
   // Get chart TF label for structure events
   string tf_label="";
   int psec=PeriodSeconds();
   if(psec>=14400) tf_label=" H4"; else if(psec>=3600) tf_label=" H1";
   else if(psec>=900) tf_label=" M15"; else if(psec>=300) tf_label=" M5";
   else tf_label=" M1";
   
   // BOS: close[1] breaks prior swing IN direction of trend
   // CHoCH: close[1] breaks prior swing AGAINST the trend
   // RULE: Only close counts, wicks do NOT count
   if(prev_sh>0 && close1>prev_sh){
      if(gBOSn<10){
         gBOS[gBOSn].level=prev_sh;
         gBOS[gBOSn].time=r[1].time;
         gBOS[gBOSn].valid=true;
         if(downtrend){
            gBOS[gBOSn].type=1;
            gBOS[gBOSn].kind="CHoCH"+tf_label;
            gStructureBias=1;
            gStructureLabel="▲ BULLISH CHoCH"+tf_label;
         } else if(uptrend){
            gBOS[gBOSn].type=1;
            gBOS[gBOSn].kind="BOS"+tf_label;
            gStructureBias=1;
            gStructureLabel="▲ BULLISH BOS"+tf_label;
         } else {
            // Mixed/ranging — minor break, less significant
            gBOS[gBOSn].type=1;
            gBOS[gBOSn].kind="BOS"+tf_label;
            gStructureBias=1;
            gStructureLabel="▲ BREAK UP"+tf_label+" (weak)";
         }
         gBOSn++;
      }
   }
   if(prev_sl>0 && close1<prev_sl){
      if(gBOSn<10){
         gBOS[gBOSn].level=prev_sl;
         gBOS[gBOSn].time=r[1].time;
         gBOS[gBOSn].valid=true;
         if(uptrend){
            gBOS[gBOSn].type=-1;
            gBOS[gBOSn].kind="CHoCH"+tf_label;
            gStructureBias=-1;
            gStructureLabel="▼ BEARISH CHoCH"+tf_label;
         } else if(downtrend){
            gBOS[gBOSn].type=-1;
            gBOS[gBOSn].kind="BOS"+tf_label;
            gStructureBias=-1;
            gStructureLabel="▼ BEARISH BOS"+tf_label;
         } else {
            gBOS[gBOSn].type=-1;
            gBOS[gBOSn].kind="BOS"+tf_label;
            gStructureBias=-1;
            gStructureLabel="▼ BREAK DN"+tf_label+" (weak)";
         }
         gBOSn++;
      }
   }
   
   // If no break detected, show current structure state
   if(gStructureBias==0){
      if(uptrend){gStructureBias=1; gStructureLabel="▲ UPTREND (HH-HL)";}
      else if(downtrend){gStructureBias=-1; gStructureLabel="▼ DOWNTREND (LH-LL)";}
      else gStructureLabel="◆ RANGING (mixed)";
   }
   
   if(gTick%20==0) Print("V15 STRUCT: bias=",gStructureBias," bull=",bull_count," bear=",bear_count,
      " up=",uptrend," dn=",downtrend," bos=",gBOSn," pat=",gSwingPattern);
}

//+------------------------------------------------------------------+
//| REAL ORDER FLOW — CopyTicks uptick/downtick classification       |
//| CVD = Cumulative Volume Delta (buyer - seller pressure)          |
//+------------------------------------------------------------------+
void CalcRealOrderFlow(){
   MqlTick ticks[];
   int copied=CopyTicks(_Symbol,ticks,COPY_TICKS_ALL,0,1000);
   if(copied<=0){ gROF.data_ok=false; return; }
   
   double buy_v=0, sell_v=0, prev_price=0;
   double big_buy=0, big_sell=0;
   // Estimate avg tick volume for large trade detection
   double sum_v=0;
   for(int i=0;i<copied;i++) sum_v+=ticks[i].volume;
   double avg_tv=(copied>0)?sum_v/copied:1.0;
   double big_thresh=avg_tv*3.0; // 3x avg = large trade
   gROF.avg_volume=avg_tv;
   
   for(int i=0;i<copied;i++){
      double price=ticks[i].last;
      if(price<=0) continue;
      if(prev_price<=0){ prev_price=price; continue; }
      double vol=(double)ticks[i].volume;
      if(price>prev_price){
         buy_v+=vol;
         if(vol>=big_thresh) big_buy+=vol;
      } else if(price<prev_price){
         sell_v+=vol;
         if(vol>=big_thresh) big_sell+=vol;
      }
      prev_price=price;
   }
   
   gROF.buy_volume=buy_v;
   gROF.sell_volume=sell_v;
   gROF.real_delta=buy_v-sell_v;
   double total=buy_v+sell_v;
   gROF.real_delta_pct=(total>0)?(gROF.real_delta/total)*100.0:0.0;
   
   // CVD tracking — reset at day open
   MqlDateTime dt; TimeCurrent(dt);
   bool is_new_day=(dt.hour==0 && dt.min<5);
   if(is_new_day){ gROF.cvd_current=0; gROF.cvd_prev=0; }
   gROF.cvd_prev=gROF.cvd_current;
   gROF.cvd_current+=gROF.real_delta;
   
   // CVD divergence detection
   gROF.cvd_divergence=false; gROF.cvd_div_type="";
   MqlRates r[];ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,3,r)>=3){
      double price_chg=r[0].close-r[2].close;
      double cvd_chg=gROF.cvd_current-gROF.cvd_prev;
      // Bearish divergence: price up but CVD down = fake rally
      if(price_chg>0 && cvd_chg<0){ gROF.cvd_divergence=true; gROF.cvd_div_type="BEAR_DIV"; }
      // Bullish divergence: price down but CVD up = fake drop
      else if(price_chg<0 && cvd_chg>0){ gROF.cvd_divergence=true; gROF.cvd_div_type="BULL_DIV"; }
   }
   
   // Large trade direction
   gROF.large_trade_cnt=(int)((big_buy+big_sell)/big_thresh);
   if(big_buy>big_sell*1.5) gROF.large_trade_dir=1;
   else if(big_sell>big_buy*1.5) gROF.large_trade_dir=-1;
   else gROF.large_trade_dir=0;
   
   gROF.data_ok=true;
   if(gTick%20==0) Print("V15 REAL_OF: delta_pct=",DoubleToString(gROF.real_delta_pct,1),
      " CVD=",DoubleToString(gROF.cvd_current,0)," div=",gROF.cvd_div_type);
}

//+------------------------------------------------------------------+
//| VHOCH GLOBALS — Write to GlobalVariables for EA interop          |
//+------------------------------------------------------------------+
void WriteVHOCHGlobals(){
   string pfx="V15_"+_Symbol;
   bool all_bull=(gStructureBias==1 && gOF.flow_bias==1 && gMTF.confluence>=2);
   bool all_bear=(gStructureBias==-1 && gOF.flow_bias==-1 && gMTF.confluence<=-2);
   bool v_agree=(all_bull || all_bear);
   int  v_dir=all_bull?1:(all_bear?-1:0);
   GlobalVariableSet(pfx+"_VHOCH_CONF",    v_agree?1.0:0.0);
   GlobalVariableSet(pfx+"_VHOCH_DIR",     (double)v_dir);
   GlobalVariableSet(pfx+"_STRUCT_BIAS",   (double)gStructureBias);
   GlobalVariableSet(pfx+"_OF_BIAS",       (double)gOF.flow_bias);
   GlobalVariableSet(pfx+"_MTF_CONF",      (double)gMTF.confluence);
   GlobalVariableSet(pfx+"_SCORE",         g14.score);
   GlobalVariableSet(pfx+"_SIGNAL",        (double)g14.sig);
   GlobalVariableSet(pfx+"_CHOCH_DET",     (gBOSn>0)?1.0:0.0);
   GlobalVariableSet(pfx+"_CHOCH_DIR",     (gBOSn>0)?(double)gBOS[0].type:0.0);
   // Real OF
   GlobalVariableSet(pfx+"_CVD",           gROF.cvd_current);
   GlobalVariableSet(pfx+"_REAL_DELTA_PCT",gROF.real_delta_pct);
   GlobalVariableSet(pfx+"_CVD_DIV",       gROF.cvd_divergence?1.0:0.0);
   GlobalVariableSet(pfx+"_HEARTBEAT",     (double)TimeCurrent());
}

//+------------------------------------------------------------------+
//| ALERT SYSTEM                                                      |
//+------------------------------------------------------------------+
void CheckAlerts(){
   if(TimeCurrent()-gLastAlert<300) return; // FIX: 300 sec cooldown (was 60)
   string msg="";
   string ses_tag=SesStr(g14.ses);
   string sc_tag="Sc:"+DoubleToString(g14.score,0);
   
   // A+ setup ready
   if(g14.qual==Q_APLUS && g14.sig!=0){
      msg="A+ SETUP! "+(g14.sig==1?"BUY":"SELL")+" "+sc_tag+" | "+ses_tag;
   }
   // Strong confluence
   else if(MathAbs(gMTF.confluence)>=3 && g14.sig!=0){
      msg="MTF CONFLUENCE! "+(g14.sig==1?"BUY":"SELL")+" "+gMTF.label+" | "+ses_tag;
   }
   // Order flow + signal agreement
   else if(gOF.flow_bias==g14.sig && g14.sig!=0 && gOF.flow_bias!=0){
      msg="FLOW CONFIRMS! "+(g14.sig==1?"BUY":"SELL")+" "+gOF.flow_label+" | "+sc_tag;
   }
   // Absorption at key level
   else if(gOF.absorption){
      msg="ABSORPTION! "+gOF.absorb_type+" Vol:"+DoubleToString(gOF.absorb_vol,1)+"x";
   }
   // Exhaustion warning
   else if(gOF.exhaustion){
      msg="EXHAUSTION! "+gOF.exhaust_type+" — Possible reversal";
   }
   // BOS/CHoCH alert
   else if(gBOSn>0){
      msg=gBOS[0].kind+" "+(gBOS[0].type==1?"BULLISH":"BEARISH")+" at "+DoubleToString(gBOS[0].level,_Digits);
   }
   
   if(msg!="" && msg!=gLastAlertMsg){
      // FIX: PERSISTENT SIGNAL — 3x consecutive same direction
      int cur_dir=g14.sig;
      if(cur_dir!=0){
         if(cur_dir==gAlertConsecDir) gAlertConsecCount++;
         else { gAlertConsecDir=cur_dir; gAlertConsecCount=1; }
      }
      string persist_tag=(gAlertConsecCount>=3)?" ⚡PERSISTENT":"";
      Alert("V15: "+msg+persist_tag);
      gLastAlert=TimeCurrent();
      gLastAlertMsg=msg;
      Print("🔔 ALERT: ",msg,persist_tag);
   }
}

//+------------------------------------------------------------------+
//| ORDER FLOW ANALYSIS                                               |
//+------------------------------------------------------------------+
void AnalyzeOrderFlow(){
   MqlRates r[];ArraySetAsSeries(r,true);
   long tv[];ArraySetAsSeries(tv,true);
   
   // FIX: Dynamic TF — sub-chart timeframe for relevant OF granularity
   ENUM_TIMEFRAMES of_tf;
   int psec_of=PeriodSeconds();
   if(psec_of>=14400)     of_tf=PERIOD_H1;    // H4+ chart -> H1 OF
   else if(psec_of>=3600) of_tf=PERIOD_M15;   // H1 chart  -> M15 OF
   else if(psec_of>=900)  of_tf=PERIOD_M5;    // M15 chart -> M5 OF
   else                   of_tf=PERIOD_M1;    // M5- chart -> M1 OF
   int bars=30;
   if(CopyRates(_Symbol,of_tf,0,bars,r)<bars){
      // Fallback to current TF
      if(CopyRates(_Symbol,PERIOD_CURRENT,0,bars,r)<bars) return;
      if(CopyTickVolume(_Symbol,PERIOD_CURRENT,0,bars,tv)<bars) return;
   } else {
      if(CopyTickVolume(_Symbol,of_tf,0,bars,tv)<bars) return;
   }
   
   ZeroMemory(gOF);
   gOF.delta_bars=20;
   
   // === 1. DELTA VOLUME ===
   // Estimate: close>open = buyer volume, close<open = seller volume
   // Delta = buyer_vol - seller_vol
   double cum_delta=0; double total_vol=0;
   for(int i=1;i<=20;i++){
      double body=r[i].close-r[i].open;
      double range=r[i].high-r[i].low;
      if(range<=0) continue;
      // Body ratio: how much of bar was directional
      double body_ratio=body/range; // -1 to +1
      double bar_delta=(double)tv[i]*body_ratio;
      cum_delta+=bar_delta;
      total_vol+=(double)tv[i];
   }
   gOF.delta_cum=cum_delta;
   gOF.delta_pct=(total_vol>0)?(cum_delta/total_vol)*100.0:0;
   
   // === 2. ABSORPTION DETECTION ===
   // Big volume + small body = large player absorbing
   gOF.absorption=false;
   double avg_vol=0;for(int i=1;i<=20;i++) avg_vol+=(double)tv[i];avg_vol/=20.0;
   double avg_range=0;for(int i=1;i<=20;i++) avg_range+=(r[i].high-r[i].low);avg_range/=20.0;
   
   for(int i=1;i<=3;i++){
      double vol_ratio=(avg_vol>0)?(double)tv[i]/avg_vol:0;
      double body_size=MathAbs(r[i].close-r[i].open);
      double range=r[i].high-r[i].low;
      double body_pct=(range>0)?body_size/range:0;
      
      // Track best absorption candidate
      if(vol_ratio>gOF.best_abs_vol) gOF.best_abs_vol=vol_ratio;
      if(i==1 || body_pct<gOF.best_abs_body) gOF.best_abs_body=body_pct;
      
      // High volume (>1.2x avg) + small body (<35% of range) = absorption
      if(vol_ratio>1.2 && body_pct<0.35){
         gOF.absorption=true;
         gOF.absorb_vol=vol_ratio;
         // Wick analysis: long lower wick after drop = bull absorb
         double upper_wick=r[i].high-MathMax(r[i].open,r[i].close);
         double lower_wick=MathMin(r[i].open,r[i].close)-r[i].low;
         if(lower_wick>upper_wick) gOF.absorb_type="BULL ABSORB";
         else gOF.absorb_type="BEAR ABSORB";
         break;
      }
   }
   
   // === 3. STACKED IMBALANCE ===
   // Count consecutive same-direction dominant bars
   gOF.stacked_count=0; gOF.stacked_dir=0;
   int streak=0; int streak_dir=0;
   for(int i=1;i<=10;i++){
      int bar_dir=(r[i].close>r[i].open)?1:-1;
      double body_pct=MathAbs(r[i].close-r[i].open)/((r[i].high-r[i].low)+0.000001);
      if(body_pct<0.3) break; // Not dominant enough
      if(i==1){streak_dir=bar_dir;streak=1;continue;}
      if(bar_dir==streak_dir) streak++;
      else break;
   }
   gOF.stacked_count=streak;
   gOF.stacked_dir=streak_dir;
   
   // === 4. EXHAUSTION DETECTION ===
   // Volume spike + growing wicks + shrinking bodies = exhaustion
   gOF.exhaustion=false;
   if(avg_vol>0 && avg_range>0){
      double vol_r=(double)tv[1]/avg_vol;
      double body1=MathAbs(r[1].close-r[1].open);
      double range1=r[1].high-r[1].low;
      double body_pct1=(range1>0)?body1/range1:0;
      double wick_upper=r[1].high-MathMax(r[1].open,r[1].close);
      double wick_lower=MathMin(r[1].open,r[1].close)-r[1].low;
      double max_wick=MathMax(wick_upper,wick_lower);
      double wick_pct=(range1>0)?max_wick/range1:0;
      
      // High vol + big wick (>40%) + small body (<40%) = exhaustion
      if(vol_r>1.3 && wick_pct>0.40 && body_pct1<0.40){
         gOF.exhaustion=true;
         if(wick_upper>wick_lower) gOF.exhaust_type="SELL EXHAUST";
         else gOF.exhaust_type="BUY EXHAUST";
      }
      gOF.best_wick_pct=wick_pct;
      gOF.best_exh_vol=vol_r;
   }
   
   // === 5. BIG VOLUME RATIO ===
   gOF.big_vol_ratio=(avg_vol>0)?(double)tv[1]/avg_vol:0;
   
   // === 6. OVERALL FLOW BIAS ===
   int flow_score=0;
   if(gOF.delta_pct>15) flow_score+=2; else if(gOF.delta_pct>5) flow_score+=1;
   if(gOF.delta_pct<-15) flow_score-=2; else if(gOF.delta_pct<-5) flow_score-=1;
   if(gOF.stacked_count>=3) flow_score+=(gOF.stacked_dir*2);
   if(gOF.absorption){if(gOF.absorb_type=="BULL ABSORB") flow_score+=2; else flow_score-=2;}
   if(gOF.exhaustion){if(gOF.exhaust_type=="BUY EXHAUST") flow_score-=1; else flow_score+=1;}
   
   if(flow_score>=3){gOF.flow_bias=1;gOF.flow_label="STRONG BUY FLOW";}
   else if(flow_score>=1){gOF.flow_bias=1;gOF.flow_label="BUY FLOW";}
   else if(flow_score<=-3){gOF.flow_bias=-1;gOF.flow_label="STRONG SELL FLOW";}
   else if(flow_score<=-1){gOF.flow_bias=-1;gOF.flow_label="SELL FLOW";}
   else{gOF.flow_bias=0;gOF.flow_label="NEUTRAL";}
   
   if(gTick%20==0) Print("V15 OF: d=",DoubleToString(gOF.delta_pct,1)," abs=",gOF.absorption," flow=",gOF.flow_label);
}

//+------------------------------------------------------------------+
//| CHART DRAWING                                                     |
//+------------------------------------------------------------------+
void DrawChart(){
   // Clear old structures
   ObjectsDeleteAll(0,"V15_OB_");
   ObjectsDeleteAll(0,"V15_FVG_");
   ObjectsDeleteAll(0,"V15_SW_");
   ObjectsDeleteAll(0,"V15_DR_");
   ObjectsDeleteAll(0,"V15_ENT_");
   ObjectsDeleteAll(0,"V15_SP_");
   ObjectsDeleteAll(0,"V15_BOS_");
   
   // === SWING POINTS — HH, HL, LH, LL labels on chart ===
   int sp_max=MathMin(gSwingN,8); // Show last 8 swing points
   for(int i=0;i<sp_max;i++){
      if(gSwings[i].label=="" || gSwings[i].label=="SH" || gSwings[i].label=="SL") continue;
      string name="V15_SP_"+IntegerToString(i);
      double offset=(gSwings[i].type==1)?g14.atr*0.3:-g14.atr*0.3;
      double price=gSwings[i].price+offset;
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,gSwings[i].time,price);
      ObjectSetString(0,name,OBJPROP_TEXT,gSwings[i].label);
      ObjectSetDouble(0,name,OBJPROP_PRICE,price);
      ObjectSetInteger(0,name,OBJPROP_TIME,0,gSwings[i].time);
      // Color: HH/HL = green, LH/LL = red
      bool bullish_sp=(gSwings[i].label=="HH" || gSwings[i].label=="HL");
      ObjectSetInteger(0,name,OBJPROP_COLOR,bullish_sp?C'0,180,80':C'200,40,40');
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   }
   
   // === BOS / CHoCH lines on chart ===
   for(int i=0;i<gBOSn && i<3;i++){
      string name="V15_BOS_"+IntegerToString(i);
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,
         gBOS[i].time,gBOS[i].level,TimeCurrent(),gBOS[i].level);
      ObjectSetDouble(0,name,OBJPROP_PRICE,0,gBOS[i].level);
      ObjectSetDouble(0,name,OBJPROP_PRICE,1,gBOS[i].level);
      bool is_choch=(gBOS[i].kind=="CHoCH");
      color bos_clr=(gBOS[i].type==1)?C'0,200,120':C'220,50,50';
      if(is_choch) bos_clr=(gBOS[i].type==1)?C'0,255,200':C'255,100,50';
      ObjectSetInteger(0,name,OBJPROP_COLOR,bos_clr);
      ObjectSetInteger(0,name,OBJPROP_STYLE,is_choch?STYLE_DASH:STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,is_choch?2:1);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      // Label on the line
      string lbl=name+"_L";
      if(ObjectFind(0,lbl)<0) ObjectCreate(0,lbl,OBJ_TEXT,0,gBOS[i].time,gBOS[i].level+(g14.atr*0.15));
      ObjectSetString(0,lbl,OBJPROP_TEXT,gBOS[i].kind+(gBOS[i].type==1?" ▲":" ▼"));
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,bos_clr);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,lbl,OBJPROP_FONT,"Arial Bold");
      ObjectSetDouble(0,lbl,OBJPROP_PRICE,gBOS[i].level+(g14.atr*0.15));
      ObjectSetInteger(0,lbl,OBJPROP_TIME,0,gBOS[i].time);
   }
   
   // Draw Order Blocks — MAX 3 most recent, clean style + labels
   int ob_max=MathMin(gOBn,3);
   for(int i=0;i<ob_max;i++){
      string name="V15_OB_"+IntegerToString(i);
      datetime t2=TimeCurrent()+PeriodSeconds()*10;
      color clr=(gOBs[i].tp==1)?C'30,80,130':C'130,30,30';
      DrawBox(name,gOBs[i].t,t2,gOBs[i].h,gOBs[i].l,clr,gOBs[i].touched?STYLE_DOT:STYLE_SOLID);
      string lbl=name+"_L";
      if(ObjectFind(0,lbl)<0) ObjectCreate(0,lbl,OBJ_TEXT,0,gOBs[i].t,(gOBs[i].h+gOBs[i].l)/2);
      ObjectSetString(0,lbl,OBJPROP_TEXT,(gOBs[i].tp==1)?"Bull OB":"Bear OB");
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,7);
      ObjectSetString(0,lbl,OBJPROP_FONT,"Arial");
      ObjectSetDouble(0,lbl,OBJPROP_PRICE,(gOBs[i].h+gOBs[i].l)/2);
      ObjectSetInteger(0,lbl,OBJPROP_TIME,0,gOBs[i].t);
   }
   
   // Draw FVGs — MAX 2 most recent + labels
   int fvg_max=MathMin(gFVGn,2);
   for(int i=0;i<fvg_max;i++){
      string name="V15_FVG_"+IntegerToString(i);
      datetime t2=TimeCurrent()+PeriodSeconds()*8;
      color clr=(gFVGs[i].tp==1)?C'20,100,60':C'140,80,20';
      DrawBox(name,gFVGs[i].t,t2,gFVGs[i].h,gFVGs[i].l,clr,STYLE_DASH);
      string lbl=name+"_L";
      if(ObjectFind(0,lbl)<0) ObjectCreate(0,lbl,OBJ_TEXT,0,gFVGs[i].t,(gFVGs[i].h+gFVGs[i].l)/2);
      ObjectSetString(0,lbl,OBJPROP_TEXT,"FVG");
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,7);
      ObjectSetString(0,lbl,OBJPROP_FONT,"Arial");
      ObjectSetDouble(0,lbl,OBJPROP_PRICE,(gFVGs[i].h+gFVGs[i].l)/2);
      ObjectSetInteger(0,lbl,OBJPROP_TIME,0,gFVGs[i].t);
   }
   
   // Draw Sweep levels — MAX 2
   int sw_max=MathMin(gSWn,2);
   for(int i=0;i<sw_max;i++){
      string name="V15_SW_"+IntegerToString(i);
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,gSWs[i].t,gSWs[i].lev,TimeCurrent(),gSWs[i].lev);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpClrSweep);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASHDOT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      // Arrow
      string arr=name+"_A";
      if(ObjectFind(0,arr)<0) ObjectCreate(0,arr,OBJ_ARROW,0,gSWs[i].t,gSWs[i].lev);
      ObjectSetInteger(0,arr,OBJPROP_ARROWCODE,(gSWs[i].tp==1)?233:234);
      ObjectSetInteger(0,arr,OBJPROP_COLOR,InpClrSweep);
   }
   
   // Draw DR/IDR
   if(gDR_lock){
      DrawBox("V15_DR_BOX",TimeCurrent()-PeriodSeconds()*20,TimeCurrent()+PeriodSeconds()*5,gDR_h,gDR_l,InpClrDR,STYLE_DOT);
      // EQ line
      string eq_name="V15_DR_EQ";
      if(ObjectFind(0,eq_name)<0) ObjectCreate(0,eq_name,OBJ_TREND,0,TimeCurrent()-PeriodSeconds()*20,gDR_eq,TimeCurrent(),gDR_eq);
      ObjectSetInteger(0,eq_name,OBJPROP_COLOR,InpClrDR);
      ObjectSetInteger(0,eq_name,OBJPROP_STYLE,STYLE_DASHDOTDOT);
      ObjectSetInteger(0,eq_name,OBJPROP_WIDTH,1);
      ObjectSetDouble(0,eq_name,OBJPROP_PRICE,0,gDR_eq);
      ObjectSetDouble(0,eq_name,OBJPROP_PRICE,1,gDR_eq);
   }
   
   // === ORDER FLOW CHART MARKERS ===
   ObjectsDeleteAll(0,"V15_OFC_");
   ObjectsDeleteAll(0,"V15_VWAP_");
   ObjectsDeleteAll(0,"V15_POC_");
   DrawOrderFlowOnChart();
   
   // Draw VWAP — subtle
   if(gVWAP>0){
      DrawHLine("V15_VWAP_MID",gVWAP,C'100,70,160',STYLE_DOT,1,"VWAP");
      DrawHLine("V15_VWAP_UP",gVWAP_upper,C'70,50,120',STYLE_DOT,1,"+1σ");
      DrawHLine("V15_VWAP_DN",gVWAP_lower,C'70,50,120',STYLE_DOT,1,"-1σ");
   }
   // Draw POC — subtle
   if(gPOC>0){
      DrawHLine("V15_POC_LINE",gPOC,C'180,150,30',STYLE_DASHDOT,1,"POC");
   }
   
   // Entry zone (if signal)
   if(g14.sig!=0&&g14.atr>0){
      double p=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl_p=(g14.sig==1)?(p-g14.sl_d):(p+g14.sl_d);
      double tp_p=(g14.sig==1)?(p+g14.tp_d):(p-g14.tp_d);
      
      // SL line
      string sl_name="V15_ENT_SL";
      if(ObjectFind(0,sl_name)<0) ObjectCreate(0,sl_name,OBJ_HLINE,0,0,sl_p);
      ObjectSetDouble(0,sl_name,OBJPROP_PRICE,sl_p);
      ObjectSetInteger(0,sl_name,OBJPROP_COLOR,InpClrBear);
      ObjectSetInteger(0,sl_name,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,sl_name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,sl_name,OBJPROP_BACK,true);
      
      // TP line
      string tp_name="V15_ENT_TP";
      if(ObjectFind(0,tp_name)<0) ObjectCreate(0,tp_name,OBJ_HLINE,0,0,tp_p);
      ObjectSetDouble(0,tp_name,OBJPROP_PRICE,tp_p);
      ObjectSetInteger(0,tp_name,OBJPROP_COLOR,InpClrBull);
      ObjectSetInteger(0,tp_name,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,tp_name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,tp_name,OBJPROP_BACK,true);
      
      // Entry arrow
      string arr_name="V15_ENT_ARR";
      if(ObjectFind(0,arr_name)<0) ObjectCreate(0,arr_name,OBJ_ARROW,0,TimeCurrent(),p);
      ObjectSetDouble(0,arr_name,OBJPROP_PRICE,p);
      ObjectSetInteger(0,arr_name,OBJPROP_TIME,TimeCurrent());
      ObjectSetInteger(0,arr_name,OBJPROP_ARROWCODE,(g14.sig==1)?241:242);
      ObjectSetInteger(0,arr_name,OBJPROP_COLOR,(g14.sig==1)?InpClrBull:InpClrBear);
      ObjectSetInteger(0,arr_name,OBJPROP_WIDTH,2);
   }
}

void DrawHLine(string name,double price,color clr,ENUM_LINE_STYLE style,int width,string tooltip){
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip+": "+DoubleToString(price,_Digits));
}

void DrawBox(string name,datetime t1,datetime t2,double p1,double p2,color clr,ENUM_LINE_STYLE style){
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,p1,t2,p2);
   ObjectSetDouble(0,name,OBJPROP_PRICE,0,p1);
   ObjectSetDouble(0,name,OBJPROP_PRICE,1,p2);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_FILL,false);   // Border only
   ObjectSetInteger(0,name,OBJPROP_BACK,true);     // Behind candles
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);        // Thin
}

void DrawOrderFlowOnChart(){
   MqlRates r[];ArraySetAsSeries(r,true);
   long tv[];ArraySetAsSeries(tv,true);
   int bars=20;
   // FIX: Same dynamic TF as AnalyzeOrderFlow
   ENUM_TIMEFRAMES ofc_tf;
   int psec_ofc=PeriodSeconds();
   if(psec_ofc>=14400)      ofc_tf=PERIOD_H1;
   else if(psec_ofc>=3600)  ofc_tf=PERIOD_M15;
   else if(psec_ofc>=900)   ofc_tf=PERIOD_M5;
   else                     ofc_tf=PERIOD_M1;
   if(CopyRates(_Symbol,ofc_tf,0,bars,r)<bars) return;
   if(CopyTickVolume(_Symbol,ofc_tf,0,bars,tv)<bars) return;
   
   double avg_vol=0;for(int i=1;i<=20&&i<bars;i++) avg_vol+=(double)tv[i];avg_vol/=MathMin(20,bars-1);
   double avg_range=0;for(int i=1;i<=20&&i<bars;i++) avg_range+=(r[i].high-r[i].low);avg_range/=MathMin(20,bars-1);
   
   for(int i=1;i<MathMin(10,bars);i++){
      double vol_r=(avg_vol>0)?(double)tv[i]/avg_vol:0;
      double body=MathAbs(r[i].close-r[i].open);
      double range=r[i].high-r[i].low;
      double body_pct=(range>0)?body/range:0;
      bool is_bull=(r[i].close>r[i].open);
      
      // Absorption marker only (diamond) — most important
      if(vol_r>1.2 && body_pct<0.35){
         string name="V15_OFC_ABS_"+IntegerToString(i);
         double price=(r[i].high+r[i].low)/2.0;
         if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,r[i].time,price);
         ObjectSetInteger(0,name,OBJPROP_ARROWCODE,115);
         ObjectSetInteger(0,name,OBJPROP_COLOR,C'255,180,50');
         ObjectSetDouble(0,name,OBJPROP_PRICE,price);
         ObjectSetInteger(0,name,OBJPROP_TIME,r[i].time);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,"ABSORB "+DoubleToString(vol_r,1)+"x");
      }
      
      // Volume spike only >1.8x (really big)
      if(vol_r>1.8){
         string name="V15_OFC_VOL_"+IntegerToString(i);
         double price=is_bull?r[i].high+(avg_range*0.15):r[i].low-(avg_range*0.15);
         if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,r[i].time,price);
         ObjectSetInteger(0,name,OBJPROP_ARROWCODE,72);
         ObjectSetInteger(0,name,OBJPROP_COLOR,is_bull?C'0,180,80':C'200,40,40');
         ObjectSetDouble(0,name,OBJPROP_PRICE,price);
         ObjectSetInteger(0,name,OBJPROP_TIME,r[i].time);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,"VOL "+DoubleToString(vol_r,1)+"x");
      }
      
      // Exhaustion (rare — important)
      double wick_up=r[i].high-MathMax(r[i].open,r[i].close);
      double wick_dn=MathMin(r[i].open,r[i].close)-r[i].low;
      double max_wick=MathMax(wick_up,wick_dn);
      double wick_pct=(range>0)?max_wick/range:0;
      if(vol_r>1.3 && wick_pct>0.40 && body_pct<0.40){
         string name="V15_OFC_EXH_"+IntegerToString(i);
         double price=(wick_up>wick_dn)?r[i].high+(avg_range*0.2):r[i].low-(avg_range*0.2);
         if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,r[i].time,price);
         ObjectSetInteger(0,name,OBJPROP_ARROWCODE,251);
         ObjectSetInteger(0,name,OBJPROP_COLOR,C'255,50,50');
         ObjectSetDouble(0,name,OBJPROP_PRICE,price);
         ObjectSetInteger(0,name,OBJPROP_TIME,r[i].time);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,"EXHAUSTION");
      }
   }
}

void DeleteAllObjects(){
   ObjectsDeleteAll(0,"V15_");
}
//+------------------------------------------------------------------+
