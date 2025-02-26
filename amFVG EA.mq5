//+------------------------------------------------------------------+
//|                                                    amSBOB EA.mq4 |
//|                                     Copyright 2024,TradingCoders |
//|                                    https://www.tradingcoders.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024,TradingCoders"
#property link      "https://www.tradingcoders.com"
#property version   "1.00"
#property strict


//So option to trade with FVGs as primary signal with filter options, VWAP, Trend (3 EMAs), and QQE.
//Signal is a simple as Buy/Sell after Bullish/Bearish FVG candle/bar closes or/and Above or Below VWAP
//                                or/and Trend Filter (3 EMAs) or/and QQE (Blue = Buy, Orange = Sell)
//Would need optional Higher/Lower Time Frame Filter for each option (FVG, iFVG, [xxx VWAP xxx], EMAs, QQE)

class GapInfo 
{
   public: 
      double RearPrice;
      double FrontPrice;
      int OriginalDirection;
      bool IsInverted;
      datetime Time;
};

//#include <stderror.mqh>
#include <StdLibErr.mqh>
#include <Trade\Trade.mqh> // Get code from other places
//#include <mq4.mqh>

enum LotsMethods { Fixed, RiskPercent, SmartMoney };

enum StoplossMeasurements { 
SL_Pips,//Pips 
SL_ATRs, //ATRs
SL_StdDevs //StdDevs
};
enum TargetMeasurements { 
TP_Pips, //Pips
TP_ATRs, //ATRs
TP_StdDevs, //StdDevs
TP_RewardToRisk //RewardToRisk
};
//enum TrendFilterTypes { None, WithTrend, CounterTrend };

enum StoplossModes { Off, FromOpenPrice, FromFractal };


//--- input parameters
input bool Trade_FVGs = true;
input bool Trade_iFVGs = true;
input int  iFVGs_MaxBars = 10;

input LotsMethods Lots = Fixed;
input double   Lots_Fixed=0.01;
input double   Lots_RiskPct=2.0;
input double   Lots_SM_LotsPerCapital = 0.01;
input double   Lots_SM_CapitalAmount = 100;
input double   MinLot=0.01;
input double   MaxLot=1000.0;
input StoplossMeasurements StoplossMeasures = SL_Pips;
input StoplossModes    StopLoss_Enabled=FromOpenPrice;
input TargetMeasurements TargetMeasures = TP_RewardToRisk;
input double   StopLoss_LongPips=30.0;
input double   StopLoss_ShortPips=30.0;
input double   StopLoss_LongATRs=3.0;//StopLoss_Long ATRs/SDevs
input double   StopLoss_ShortATRs=3.0;//StopLoss_Short ATRs/SDevs
input bool     TakeProfit_Enabled=true;
input double   TakeProfit_LongPips=30.0;
input double   TakeProfit_ShortPips=30.0;
input double   TakeProfit_LongATRs=3.0;//TakeProfit_Long ATRs/SDevs
input double   TakeProfit_ShortATRs=3.0;//TakeProfit_Short ATRs/SDevs
input double   TakeProfit_LongRewardToRisk = 3.0;
input double   TakeProfit_ShortRewardToRisk = 3.0;
input double   BreakEven_LongTriggerPips=25;
input double   BreakEven_ShortTriggerPips=25;
input double   BreakEven_LongCapturePips=1;
input double   BreakEven_ShortCapturePips=1;
input double   BreakEven_LongTriggerATRs=2.0;
input double   BreakEven_ShortTriggerATRs=2.0;
input double   BreakEven_LongCaptureATRs=0.2;
input double   BreakEven_ShortCaptureATRs=0.2;

input double   SmartTrailingStop = 0.0;//Smart TrailingStop- values 0.0 (off) to 1.5ish

input int      MaxOrdersPerSymbol=3;
input bool     MaxDrawDown_Enabled=false;
input double   MaxDrawDown_Pct=25.0;
input int      MaxDrawDown_InitialCapital=5000;

//input int GMT_Offset = 4; // GMT Offset for New York Time
//input bool Auto_BrokerGMT_Offset = false;
//input int Manual_BrokerGMT_Offset = 1;

input bool     Use_TradeTimeFilter = true;
input int      TradeTimeStart_MT4 = 0; //TradeTimeStart MT5 (hhmm)
input int      TradeTimeEnd_MT4 = 0; //TradeTimeEnd MT5 (hhmm)
input bool     HoldOverWeekend=false;
input ENUM_DAY_OF_WEEK      WeekendExitDay = 5;
input int      WeekendExitTime = 1945;//WeekdayExitTime MT5 (hhmm)

		

//input int      ATR_Period = 20;

input bool     AddIndicatorsToChart = true;
input bool     UseWholePips = true;//WholePips False=5thDigit, True=4thDigit
input int      MagicNumber = 241021;
input int      MaxSlippage = 5;
input string   EA_ShortNameInOrderComments = "amFVG";

input bool     ChartDashboard = true;
input int      ChartDashboard_FontSize = 10;
input string   ChartDashboard_Font = "Tahoma";
input color    ChartDashboard_Color = clrGold;

//--- Define some MQL5 Structures we will use for our trade
   CTrade myTradingControlPanel;
   MqlTick latest_price;     // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
input    ENUM_ORDER_TYPE_FILLING OrderFill = ORDER_FILLING_FOK;
input    ENUM_ORDER_TYPE_TIME OrderTime = ORDER_TIME_GTC;


sinput string FVG_INDICATOR = "----->>";

//input 
  bool FairValueGaps = true;
input double   MinimumGapATRs=0.0;
input int      ATR_Period = 20;
input bool     VisualMarkings=true;
input color    BullishColor=clrDeepSkyBlue;
input color    BearishColor=clrGoldenrod;
input int      VisualWidth=10;
//input 
   int MajorStructurePeriod = 4;
input int      MaxVisualBars=1000;
//input 
   bool OrderBlocks = false;


sinput string TREND_INDICATORS = "----->>";
// 3 mov avgs
input bool MovAvgs = false;
input ENUM_TIMEFRAMES MovAvgs_TimeFrame = PERIOD_CURRENT;
input ENUM_MA_METHOD MovAvgs_Type = MODE_EMA;
input int MovAvg_Fast = 9;
input int MovAvg_Medium = 34;
input int MovAvg_Slow = 100;

// QQE
input bool QQE = true;
input ENUM_TIMEFRAMES QQE_TimeFrame = PERIOD_CURRENT;
input int                inpRsiPeriod          = 14;         //QQE RSI period
input int                inpRsiSmoothingFactor =  5;         //QQE RSI smoothing factor
input double             inpWPFast             = 2.618;      //QQE Fast period
input double             inpWPSlow             = 4.236;      //QQE Slow period
input ENUM_APPLIED_PRICE inpPrice=PRICE_CLOSE;              //QQE Price 

// VWAP
input bool VWAP = false;
input int VWAP_Period = 20;
input ENUM_APPLIED_PRICE VWAP_Price = PRICE_CLOSE;
input bool VWAP_UseRealVolume = false;
input bool VWAP_DeviationCorrection = false;
input double VWAP_Band1 = 0;
input double VWAP_Band2 = 0;
input double VWAP_Band3 = 0;

// internal variables
double Ask = 0, Bid = 0;
string short_name = "amFVG EA";
datetime latestBar = 0;
bool newBar = 0;
double PIP = 0;
double minDistance = 0;
bool developer = false;

datetime latestBuySignal = 0, latestSellSignal = 0;
int openLongs = 0, openShorts = 0;
double stoplossPrice = 0;
bool isWeekend = false;
double vATR_SL = 0, vATR_TP = 0;
bool inWindow = true;
int brokerToGMTOffset = 0;

datetime latestSignalBar = 0;
int latestRawSignal = 0;
int positionsThisSymbol = 0;

bool asSeries = true;
int qqeHandle= -1, atrHandle = -1, stddevHandle = -1;
double qqeSeries[], qqeSlowSeries[], atrSeries[], stddevSeries[];
string qqe_shortname;
int fastmaHandle = -1, mediummaHandle = -1, slowmaHandle = -1;
double fastmaSeries[], mediummaSeries[], slowmaSeries[];
string fastma_shortname, mediumma_shortname, slowma_shortname;
int fvgHandle = -1;
double fvgGapSeries[];
string fvg_shortname;
int vwapHandle = -1;
double vwapSeries[];
string vwap_shortname;

int fractalsHandle = -1;
double fractalsUpperSeries[], fractalsLowerSeries[];

int calculated = 0;

double close[],high[],low[];
datetime time[];

   int latestShortTicket = 0;
   int latestLongTicket = 0;
   double latestShortOpenPrice = -1;
   double latestLongOpenPrice = -1;
   
double accountHighWater = 0;
double entrySlippageOfLatestTrade = 0;


double entryHighPrice = 0, entryLowPrice = 0; // when a signal fires, values are copied in here.

int latestQQETrend = 0; // the latest trend found from the QQE indicator
int latestMovAvgTrend = 0;
int latestVWAPTrend = 0;

// a 'List' of GapInfo 
GapInfo gapInfos[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   
   //developer = StringFind(AccountInfoString(ACCOUNT_NAME),"Bilbo Baggins",0) >= 0;
   developer = AccountInfoInteger(ACCOUNT_LOGIN) == 5024984217;
   Print("Account '",AccountInfoString(ACCOUNT_NAME),", login ",AccountInfoInteger(ACCOUNT_LOGIN));
   Print("developer = ",developer);
   latestBuySignal = 0; latestSellSignal = 0;
   //EventSetTimer(1); // no point to it. Indicators only calculate when they receive a tick.
   
   TesterHideIndicators(!AddIndicatorsToChart);
      
   qqeHandle = -1; atrHandle = -1; stddevHandle = -1; fractalsHandle = -1;

   if (EA_ShortNameInOrderComments != "")
      short_name = EA_ShortNameInOrderComments;
	
   
   atrHandle = iATR(Symbol(),PERIOD_CURRENT,ATR_Period);
   ArraySetAsSeries(atrSeries,asSeries);
   
   stddevHandle = iStdDev(Symbol(),PERIOD_CURRENT,ATR_Period,0,MODE_SMA,PRICE_CLOSE);
   ArraySetAsSeries(stddevSeries,asSeries);
   
   fractalsHandle = iFractals(Symbol(),PERIOD_CURRENT);
   ArraySetAsSeries(fractalsUpperSeries,asSeries);
   ArraySetAsSeries(fractalsLowerSeries,asSeries);
   
   if (QQE)
   {
      //qqeHandle = iCustom(Symbol(), QQE_TimeFrame, "QQE",
      //            inpRsiPeriod,inpRsiSmoothingFactor,inpWPFast,inpWPSlow,inpPrice); 
      qqeHandle = iCustom(Symbol(), PERIOD_CURRENT, "qqe-mtf",
                  QQE_TimeFrame,inpRsiPeriod,inpRsiSmoothingFactor,inpWPFast,inpWPSlow,inpPrice,false);
      ArraySetAsSeries(qqeSeries,asSeries);
      ArraySetAsSeries(qqeSlowSeries,asSeries);
   }
   
   if (MovAvgs)
   {
      fastmaHandle = iMA(Symbol(),MovAvgs_TimeFrame,MovAvg_Fast,0,MovAvgs_Type,PRICE_CLOSE);
      mediummaHandle = iMA(Symbol(),MovAvgs_TimeFrame,MovAvg_Medium,0,MovAvgs_Type,PRICE_CLOSE);
      slowmaHandle = iMA(Symbol(),MovAvgs_TimeFrame,MovAvg_Slow,0,MovAvgs_Type,PRICE_CLOSE);
      ArraySetAsSeries(fastmaSeries,asSeries);
      ArraySetAsSeries(mediummaSeries,asSeries);
      ArraySetAsSeries(slowmaSeries,asSeries);
   }
   
   if (VWAP)
   {
      vwapHandle = iCustom(Symbol(),PERIOD_CURRENT,"vwap_bands",
            VWAP_Period,VWAP_Price,VWAP_UseRealVolume,VWAP_DeviationCorrection,VWAP_Band1,VWAP_Band2,VWAP_Band3);
      ArraySetAsSeries(vwapSeries,asSeries);
   }
   
   {
      fvgHandle = iCustom(Symbol(),PERIOD_CURRENT,"amFairValueGaps_and_OrderBlocks",
      //FairValueGaps = true;
      MinimumGapATRs,ATR_Period,VisualMarkings,BullishColor,BearishColor,VisualWidth,
        4,MaxVisualBars,
        false//OrderBlocks;
        );
      ArraySetAsSeries(fvgGapSeries,asSeries);
   }
   
   //
   
   if (AddIndicatorsToChart)
   {
      if (QQE)
      {
         ChartIndicatorAdd(ChartID(),1,qqeHandle);  
         Sleep(500);
         // Get the short name of the indicator
         qqe_shortname = ChartIndicatorName (0,1,ChartIndicatorsTotal(0,1)-1);
      }
      
      if (MovAvgs)
      {
         ChartIndicatorAdd(ChartID(),0,fastmaHandle);  
         Sleep(500);
         // Get the short name of the indicator
         fastma_shortname = ChartIndicatorName (0,0,ChartIndicatorsTotal(0,0)-1);
         
         ChartIndicatorAdd(ChartID(),0,mediummaHandle);  
         Sleep(500);
         // Get the short name of the indicator
         mediumma_shortname = ChartIndicatorName (0,0,ChartIndicatorsTotal(0,0)-1);
         
         ChartIndicatorAdd(ChartID(),0,slowmaHandle);  
         Sleep(500);
         // Get the short name of the indicator
         slowma_shortname = ChartIndicatorName (0,0,ChartIndicatorsTotal(0,0)-1);
      } 
      
      if (VWAP)
      {
         ChartIndicatorAdd(ChartID(),0,vwapHandle);  
         Sleep(500);
         // Get the short name of the indicator
         vwap_shortname = ChartIndicatorName (0,0,ChartIndicatorsTotal(0,0)-1);         
      }
      
      {
         ChartIndicatorAdd(ChartID(),0,fvgHandle);  
         Sleep(500);
         // Get the short name of the indicator
         fvg_shortname = ChartIndicatorName (0,0,ChartIndicatorsTotal(0,0)-1);
      }
      
   }
   
   
	
   PIP = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE); //MarketInfo(Symbol(),MODE_TICKSIZE);
   if (UseWholePips && (Digits() == 5 || (Digits() == 3 && (StringFind(Symbol(),"JPY",0) >=0 || StringFind(Symbol(),"XAU",0) >= 0))))
      PIP *= 10;
      
   accountHighWater = MathMax(MaxDrawDown_InitialCapital, AccountInfoDouble(ACCOUNT_BALANCE));
   
   Print("PIP for ",Symbol()," is ",DoubleToString(PIP,5)," InitialCapital(HighWater)=",DoubleToString(accountHighWater,2));
   
   ArraySetAsSeries(close,asSeries);
   ArraySetAsSeries(high,asSeries);
   ArraySetAsSeries(low,asSeries);
   ArraySetAsSeries(time,asSeries);
   
   Sleep(2000);
   calculated=BarsCalculated(qqeHandle); 
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
   if (qqeHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),qqe_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,qqe_shortname);
      Print("Deleted QQE indicator ",ok);
      
      IndicatorRelease(qqeHandle);
   }
   
   if (fastmaHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),fastma_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,fastma_shortname);
      Print("Deleted FastMA indicator ",ok);
      
      IndicatorRelease(fastmaHandle);
   }
   
   if (mediummaHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),mediumma_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,mediumma_shortname);
      Print("Deleted mediumMA indicator ",ok);
      
      IndicatorRelease(mediummaHandle);
   }
   
   if (slowmaHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),slowma_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,slowma_shortname);
      Print("Deleted slowMA indicator ",ok);
      
      IndicatorRelease(slowmaHandle);
   }
   
   if (fvgHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),fvg_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,fvg_shortname);
      Print("Deleted fvg indicator ",ok);
      
      IndicatorRelease(fvgHandle);
   }
   
   if (vwapHandle != INVALID_HANDLE)
   {
      int window=ChartWindowFind(ChartID(),vwap_shortname);
      bool ok=ChartIndicatorDelete(ChartID(),window,vwap_shortname);
      Print("Deleted vwap indicator ",ok);
      
      IndicatorRelease(vwapHandle);
   }
   
   
   if(atrHandle!=INVALID_HANDLE) 
      IndicatorRelease(atrHandle); 
      
   if(stddevHandle!=INVALID_HANDLE) 
      IndicatorRelease(stddevHandle); 
      
   if (fractalsHandle!=INVALID_HANDLE)
      IndicatorRelease(fractalsHandle);
      
      
      
   //EventKillTimer();
   Comment("");
   DoObjectsDeleteAll();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
      //Print("OnTick()");
      
      if (IsStopped())
      {
         //EventKillTimer();
         return;
      }
      if (iBars(Symbol(),PERIOD_CURRENT) < 10)
         return;
                  
      int maxLoadedBars = 1500;
      
      // copy standard data
      int copiedCount = CopyClose(Symbol(),PERIOD_CURRENT,0,MathMin(maxLoadedBars,iBars(Symbol(),PERIOD_CURRENT)),close);
      if (copiedCount <= 0)
         return;
      copiedCount = CopyHigh(Symbol(),PERIOD_CURRENT,0,MathMin(maxLoadedBars,iBars(Symbol(),PERIOD_CURRENT)),high);
      if (copiedCount <= 0)
         return;
      copiedCount = CopyLow(Symbol(),PERIOD_CURRENT,0,MathMin(maxLoadedBars,iBars(Symbol(),PERIOD_CURRENT)),low);
      if (copiedCount <= 0)
         return;
      copiedCount = CopyTime(Symbol(),PERIOD_CURRENT,0,MathMin(maxLoadedBars,iBars(Symbol(),PERIOD_CURRENT)),time);
      if (copiedCount <= 0)
         return;
      
               
      if (atrHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(atrHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() atrHandle returned %d, error code %d",calculated,GetLastError()); 
            //Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(atrSeries,atrHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail atrSeries FillArrayFromBuffer, calculated=",calculated);
            return; 
         }
      }
             
      if (stddevHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(stddevHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() stddevHandle returned %d, error code %d",calculated,GetLastError()); 
            //Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(stddevSeries,stddevHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail atrSeries FillArrayFromBuffer, calculated=",calculated);
            return; 
         }
      }
         
      if (fractalsHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(fractalsHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() fractalsHandle returned %d, error code %d",calculated,GetLastError()); 
            return; 
         }    
         if(!FillArrayFromBuffer(fractalsUpperSeries,fractalsHandle,MathMin(maxLoadedBars,calculated),UPPER_LINE)) 
         {
            Print("fail atrSeries FillArrayFromBuffer, calculated=",calculated);
            return; 
         }
         if(!FillArrayFromBuffer(fractalsLowerSeries,fractalsHandle,MathMin(maxLoadedBars,calculated),LOWER_LINE)) 
         {
            Print("fail atrSeries FillArrayFromBuffer, calculated=",calculated);
            return; 
         }
      }   
         
         
         
      if (qqeHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(qqeHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() QQE returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(qqeSeries,qqeHandle,MathMin(maxLoadedBars,calculated),2)) 
         {
            Print("fail QQE FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
         if(!FillArrayFromBuffer(qqeSlowSeries,qqeHandle,MathMin(maxLoadedBars,calculated),1)) 
         {
            Print("fail QQE FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }   
      
      if (fastmaHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(fastmaHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() fastmaHandle returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(fastmaSeries,fastmaHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail fastma FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }
      
      if (mediummaHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(mediummaHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() mediummaHandle returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(mediummaSeries,mediummaHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail mediumma FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }
      
      
      if (slowmaHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(slowmaHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() slowmaHandle returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(slowmaSeries,slowmaHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail slowma FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }
      
      if (fvgHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(fvgHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() fvgHandle returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(fvgGapSeries,fvgHandle,MathMin(maxLoadedBars,calculated),0)) 
         {
            Print("fail fvg FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }
      
      
      if (vwapHandle != INVALID_HANDLE)
      {
         calculated=BarsCalculated(vwapHandle); 
         if(calculated<=0) 
         { 
            PrintFormat("BarsCalculated() vwapHandle returned %d, error code %d",calculated,GetLastError()); 
            Sleep(100);
            return; 
         }    
         if(!FillArrayFromBuffer(vwapSeries,vwapHandle,MathMin(maxLoadedBars,calculated),3)) 
         {
            Print("fail vwap FillArrayFromBuffer, calculated=",calculated);
            Sleep(100);
            return; 
         }
      }
      
      // ------------
      
      
      //if (developer) Print(short_name+" OnTick()"); // checker
      
      newBar = latestBar > 0 && latestBar < time[0];
      //if (newBar) Print("New bar starting at ",TimeToString(time[0])," calculated = ",calculated); // CHEcKER
      
      latestBar = time[0];
      minDistance = SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*Point() + Point();
      PIP = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE); //MarketInfo(Symbol(),MODE_TICKSIZE);
      if (UseWholePips && (Digits() == 5 || (Digits() == 3 && (StringFind(Symbol(),"JPY",0) >=0 || StringFind(Symbol(),"XAU",0) >= 0))))
         PIP *= 10;
         
      Bid = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      Ask = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
   
      //TesterHideIndicators(false);
      vATR_SL = StoplossMeasures == SL_Pips ? PIP : (StoplossMeasures == SL_ATRs ? atrSeries[1] : stddevSeries[1]);
      vATR_TP = TargetMeasures == TP_Pips ? PIP : (TargetMeasures == TP_ATRs ? atrSeries[1] : stddevSeries[1]);
      //TesterHideIndicators(false);
         
    //if (Auto_BrokerGMT_Offset)
    //  brokerToGMTOffset = (int)((TimeCurrent() - TimeGMT())/60.0/60.0); // seconds div 60 to minutes div 60 to hours.
    //else 
    //  brokerToGMTOffset = Manual_BrokerGMT_Offset;
      
      // maxDrawDown
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if (balance > accountHighWater)
      {
         accountHighWater = MathMax(MaxDrawDown_InitialCapital, balance);
         Print("New highwater of account, to ",DoubleToString(accountHighWater,2));
      }
      if (  MaxDrawDown_Enabled && MaxDrawDown_InitialCapital > 0)
      {
         double ddPct = 100 * (accountHighWater - balance)/accountHighWater;
         if (ddPct > 0)
         {
            //if (developer) Print("InitialCapital $",MaxDrawDown_InitialCapital," Balance $",DoubleToString(balance,2)," dd = ",DoubleToString(ddPct,2),"%"); // developer checker
            if (ddPct > MaxDrawDown_Pct)
            {
               Print("Must Stop Trading due to MaxDrawDown. InitialCapital(HighWater) $",DoubleToString(accountHighWater,2)," Balance $",DoubleToString(balance,2)," dd = ",DoubleToString(ddPct,2),"%");
               CloseThis(POSITION_TYPE_BUY);
               CloseThis(POSITION_TYPE_SELL);
               ExpertRemove();
               return;
            }
         }
      }
         
      bool inWindowMem = inWindow;
      inWindow = !Use_TradeTimeFilter || CheckTime(TradeTimeStart_MT4,TradeTimeEnd_MT4);
      if (inWindow && !inWindowMem)
         Print(TimeToString(TimeCurrent())," (bar time) MT4 TradeTime session starts. GMT is ",TimeToString(TimeGMT())," local is ",TimeToString(TimeLocal()));
      if (!inWindow && inWindowMem)
         Print(TimeToString(TimeCurrent())," (bar time) MT4 TradeTime session ended. GMT is ",TimeToString(TimeGMT())," local is ",TimeToString(TimeLocal()));
      
      if (newBar) // find signals intrabar
      //if (latestSignalBar < time[1])
      {
         // collect knowledge of Fair Value Gaps
         CollectFVGs();
         // calculate the QQE trend (if in use)
         if (QQE)
            CalculateQQETrend();
         // calculate the MovAvg trend (if in use)
         if (MovAvgs)
            CalculateMovAvgTrend();
         if (VWAP)
            CalculateVWAPTrend();
         
         MqlDateTime time1Struct, time2Struct;
         TimeToStruct(time[1],time1Struct);
         TimeToStruct(time[2],time2Struct);
         
         bool newWeek = time1Struct.day_of_week < time2Struct.day_of_week;
         if (newWeek)
            isWeekend = false; // reset
            
         // this counts positions on this symbol, too
         openLongs = NumOpenLongs();
         openShorts = NumOpenShorts();
          
         MqlDateTime time0Struct;
         TimeToStruct(time[0],time0Struct);      
         
          int adjusted_hour = time0Struct.hour;
         // weekend exit
         if (  !HoldOverWeekend && (openLongs > 0 || openShorts > 0)
            && time0Struct.day_of_week == WeekendExitDay
            && adjusted_hour*100 + time0Struct.min >= WeekendExitTime
            )
         {
            Print("Weekend Exit at "+TimeToString(time[0],TIME_DATE|TIME_MINUTES)+" day=",time0Struct.day_of_week," which is "+EnumToString((ENUM_DAY_OF_WEEK)time0Struct.day_of_week));
            CloseThis(POSITION_TYPE_BUY);
            CloseThis(POSITION_TYPE_SELL);
            
            isWeekend = true;
            latestSignalBar = time[1]; // SET
            return;
         }
         
      
         int exitSignal = GetExitSignal();
         if (exitSignal < 0 && openLongs > 0)
         {
            Print("Long exit signal, closing ",openLongs," orders");
            CloseThis(POSITION_TYPE_BUY);
            openLongs = 0;
         }
         if (exitSignal > 0 && openShorts > 0)
         {
            Print("Short exit signal, closing ",openShorts," orders");
            CloseThis(POSITION_TYPE_SELL);
            openShorts = 0;
         }
         
         int entrySignal = GetEntrySignal();
         if (//developer && 
            (entrySignal != 0)
            ) 
            Print(TimeCurrent()," for bar ",time[1]," raw entry signal ",entrySignal); // CHECKER
         
         if (entrySignal != 0)
         {
            
            //// we only want FRESH signals
            bool isFresh = true;
            //if (latestRawSignal == entrySignal 
            //   && latestSignalBar == time[2] 
            //   )
            //   isFresh = false;
               
            latestSignalBar = time[1]; // SET
            latestRawSignal = entrySignal; // SET 
            
            if (!isFresh)
               entrySignal = 0;
         }
         
            
         if (entrySignal != 0
            && !isWeekend
            && inWindow
            )
         {         
            // entry signal! Just to be sure; let's close any opposite orders
            if (entrySignal < 0 && openLongs > 0)
            {
               Print("Short entry signal, closing ",openLongs," orders");
               CloseThis(POSITION_TYPE_BUY);
               openLongs = 0;
            }
            if (entrySignal > 0 && openShorts > 0)
            {
               Print("Long entry signal, closing ",openShorts," orders");
               CloseThis(POSITION_TYPE_SELL);
               openShorts = 0;
            }
         
            CountPositions(); // recount
            Print("For entrySignal ",entrySignal," positionsThisSymbol=",positionsThisSymbol); // CHECKER
            if (MaxOrdersPerSymbol > 0 && positionsThisSymbol >= MaxOrdersPerSymbol)
            {
               Print("entrySignal ",entrySignal," prevented by positionsThisSymbol=",positionsThisSymbol," when max allowed is ",MaxOrdersPerSymbol);
               entrySignal = 0;
            }
               
            // take the entry
            CancelPendingOrders();
            if (entrySignal > 0)
               OpenThis(ORDER_TYPE_BUY);
            else if (entrySignal < 0)
               OpenThis(ORDER_TYPE_SELL);
            
         }
      }
   
      ManageTrades(0);
      
      if (ChartDashboard)
         DoDashboard();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void ManageTrades(double providedSL)
{
   int total = PositionsTotal();                            // .GET  number of open positions
   
   for (  int i = total - 1; i >= 0; i-- )                              // .ITER  over all open positions
   {                     
       TradeThreadOK();
       
       //        .GET  params of the order:
       ulong  position_ticket  = PositionGetTicket(       i );                               //  - ticket of the position
       string position_symbol  = PositionGetString(       POSITION_SYMBOL );                 //  - symbol 
       int    digits           = (int) SymbolInfoInteger( position_symbol,       
                                                          SYMBOL_DIGITS      
                                                          );                                 //  - number of decimal places
       ulong  magic            = PositionGetInteger(      POSITION_MAGIC );                  //  - MagicNumber of the position
       double volume           = PositionGetDouble(       POSITION_VOLUME );                 //  - volume of the position
       double sl               = PositionGetDouble(       POSITION_SL );                  //  - volume of the position
       double tp               = PositionGetDouble(       POSITION_TP );                  //  - volume of the position
       ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger( POSITION_TYPE );   //  - type of the position
       double open             = PositionGetDouble(POSITION_PRICE_OPEN);
       datetime openTime       = (datetime)PositionGetInteger(POSITION_TIME); // this is open time
       string comment = PositionGetString(POSITION_COMMENT);
       
       if (  position_symbol == Symbol() && magic == MagicNumber)// && sl > 0)                               // .IF MATCH:
       {       
            int ticket = (int)position_ticket;
            bool doUpdate = false;
            
            if (type == POSITION_TYPE_BUY)
            {
               if (sl == 0 && (StoplossMeasures == SL_Pips ? StopLoss_LongPips : StopLoss_LongATRs) > 0 && StopLoss_Enabled != Off)
               {
                  sl = rnd(MathMin(Bid-minDistance,providedSL > 0 ? providedSL : 
                     (StopLoss_Enabled == FromFractal ? LastFractalLow() : open) - (StoplossMeasures == SL_Pips ? StopLoss_LongPips*PIP : StopLoss_LongATRs*vATR_SL)));
                  doUpdate = true; 
               }
               if (tp == 0 && ((TargetMeasures == TP_Pips ? TakeProfit_LongPips : TakeProfit_LongATRs) > 0) && TakeProfit_Enabled)
               {
                  tp = rnd(MathMax(Ask+minDistance,open + (TargetMeasures == TP_Pips ? PIP*TakeProfit_LongPips : vATR_TP*TakeProfit_LongATRs)));
                  doUpdate = true;
               }
               
               if (SmartTrailingStop > 0 && newBar
                  && close[1] > close[2] // advancing bar
                  && ((StoplossMeasures == SL_Pips ? BreakEven_LongTriggerPips : BreakEven_LongTriggerATRs)==0 || sl >= open) // not until breakeven has happened (if enabled) 
                  )
               {
                  double trail = (close[1] - close[2]) * SmartTrailingStop;
                  double newsl = rnd(MathMin(Bid - minDistance, sl + trail));     // original 
                  if (StoplossMeasures != SL_Pips)
                     newsl = rnd(MathMin(Bid - minDistance, close[0] - StopLoss_LongATRs*vATR_SL + trail));      // revised to be 'adaptive to market conditions'   CAN GO BACKWARDS
                  doUpdate = newsl != sl;
                  sl = newsl;
               }
               
               if ((StoplossMeasures == SL_Pips ? BreakEven_LongTriggerPips : BreakEven_LongTriggerATRs) > 0
                  && close[0] >= open + (StoplossMeasures == SL_Pips ? BreakEven_LongTriggerPips * PIP : BreakEven_LongTriggerATRs * vATR_SL)
                  )
               {
                  double be = rnd(open + (StoplossMeasures == SL_Pips ? BreakEven_LongCapturePips * PIP : BreakEven_LongCaptureATRs * vATR_SL));
                  be = rnd(MathMin(Bid-minDistance,be));
                  if (sl < be)
                  {
                     sl = be;
                     doUpdate = true;
                  }
               }
               
               if (doUpdate)
               {
                  Print("setting for ticket "+IntegerToString(ticket)+" SL="+DoubleToString(sl,Digits())+", TP="+DoubleToString(tp,Digits()));
                  
                  myTradingControlPanel.PositionModify(position_ticket,sl,tp);
                  //if (!OrderModify(ticket,OrderOpenPrice(),sl,tp,OrderExpiration(),clrDarkOrange))
                  //{
                  //   Print("Error setting stoploss and target: ",(GetLastError()));
                  //}
                  //TradeThreadOK();
                  //if (!OrderSelect(ticket,SELECT_BY_TICKET))
                  //   continue;
               }
               
            }
            else if (type == POSITION_TYPE_SELL)
            {            
               if (sl == 0 && (StoplossMeasures == SL_Pips ? StopLoss_ShortPips : StopLoss_ShortATRs) > 0 && StopLoss_Enabled != Off)
               {
                  sl = rnd(MathMax(Ask+minDistance,providedSL > 0 ? providedSL : 
                     (StopLoss_Enabled == FromFractal ? LastFractalHigh() : open) + (StoplossMeasures == SL_Pips ? StopLoss_ShortPips*PIP : StopLoss_ShortATRs*vATR_SL)));
                  doUpdate = true; 
               }
               if (tp == 0 && ((TargetMeasures == TP_Pips ? TakeProfit_ShortPips : TakeProfit_ShortATRs) > 0) && TakeProfit_Enabled)
               {
                  tp = rnd(MathMin(Bid-minDistance,open - (TargetMeasures == TP_Pips ? PIP*TakeProfit_ShortPips : vATR_TP*TakeProfit_ShortATRs)));
                  doUpdate = true;
               }
               
               if (SmartTrailingStop > 0 && newBar
                  && close[1] < close[2] // advancing bar
                  && ((StoplossMeasures == SL_Pips ? BreakEven_LongTriggerPips : BreakEven_LongTriggerATRs)==0 || sl <= open) // not until breakeven has happened (if enabled)
                  )
               {
                  double trail = (close[1] - close[2]) * SmartTrailingStop;
                  double newsl = rnd(MathMax(Ask + minDistance, sl + trail));     // original 
                  if (StoplossMeasures != SL_Pips)
                     newsl = rnd(MathMax(Ask + minDistance, close[0] + StopLoss_ShortATRs*vATR_SL - trail));      // revised to be 'adaptive to market conditions'   CAN GO BACKWARDS
                  doUpdate = newsl != sl;
                  sl = newsl;
               }
               
               if ((StoplossMeasures == SL_Pips ? BreakEven_ShortTriggerPips : BreakEven_ShortTriggerATRs) > 0
                  && close[0] <= open - (StoplossMeasures == SL_Pips ? BreakEven_ShortTriggerPips * PIP : BreakEven_ShortTriggerATRs * vATR_SL)
                  )
               {
                  double be = rnd(open - (StoplossMeasures == SL_Pips ? BreakEven_ShortCapturePips * PIP : BreakEven_ShortCaptureATRs * vATR_SL));
                  be = rnd(MathMax(Ask+minDistance,be));
                  if (sl > be)
                  {
                     sl = be;
                     doUpdate = true;
                  }
               }
               
               if (doUpdate)
               {
                  Print("setting for ticket "+IntegerToString(ticket)+" SL="+DoubleToString(sl,Digits())+", TP="+DoubleToString(tp,Digits()));
                  myTradingControlPanel.PositionModify(position_ticket,sl,tp);
                  //if (!OrderModify(ticket,OrderOpenPrice(),sl,tp,OrderExpiration(),clrDarkOrange))
                  //{
                  //   Print("Error setting stoploss and target: ",(GetLastError()));
                  //}
                  //TradeThreadOK();
                  //if (!OrderSelect(ticket,SELECT_BY_TICKET))
                  //   continue;
               }
            }
         }
       
   }
   
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


void CloseThis(ENUM_POSITION_TYPE typeToClose)
{

   MqlTradeRequest request;
   MqlTradeResult  result;

   int             total = PositionsTotal();                            // .GET  number of open positions
   for (  int i = total - 1; i >= 0; i-- )                              // .ITER  over all open positions
   {                     
          TradeThreadOK();
          
          //        .GET  params of the order:
          ulong  position_ticket  = PositionGetTicket(       i );                               //  - ticket of the position
          string position_symbol  = PositionGetString(       POSITION_SYMBOL );                 //  - symbol 
          int    digits           = (int) SymbolInfoInteger( position_symbol,       
                                                             SYMBOL_DIGITS      
                                                             );                                 //  - number of decimal places
          ulong  magic            = PositionGetInteger(      POSITION_MAGIC );                  //  - MagicNumber of the position
          double volume           = PositionGetDouble(       POSITION_VOLUME );                 //  - volume of the position
          ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger( POSITION_TYPE );   //  - type of the position

          PrintFormat( "Tkt[#%I64u] %s  %s  %.2f  %s MagNUM[%I64d]",    // .GUI:    print details about the position    
                       position_ticket,
                       position_symbol,
                       EnumToString(type),
                       volume,
                       DoubleToString( PositionGetDouble( POSITION_PRICE_OPEN ), digits ),
                       magic
                       );

          if (  position_symbol == Symbol() && magic == MagicNumber  && type==typeToClose)                               // .IF MATCH:
          {     ZeroMemory( request );                                  //     .CLR data
                ZeroMemory( result  );                                  //     .CLR data
                                                                        //     .SET:
                request.action    = TRADE_ACTION_DEAL;                  //          - type of trade operation
                request.position  = position_ticket;                    //          - ticket of the position
                request.symbol    = position_symbol;                    //          - symbol 
                request.volume    = volume;                             //          - volume of the position
                request.deviation = 5;                                  //          - allowed deviation from the price
                request.magic     = magic;                             //          - MagicNumber of the position
                  request.type_filling = OrderFill; //ORDER_FILLING_FOK;                          // Order execution type
                  request.type_time = OrderTime; //ORDER_TIME_GTC;
                  request.deviation=MaxSlippage*2;                                     // Deviation from current price
                  
                if (  type == POSITION_TYPE_BUY )
                {     request.price = SymbolInfoDouble( position_symbol, SYMBOL_BID );
                      request.type  = ORDER_TYPE_SELL;
                      }
                else
                {
                      request.price = SymbolInfoDouble( position_symbol, SYMBOL_ASK );
                      request.type  = ORDER_TYPE_BUY;
                      }

                PrintFormat(       "WILL TRY: Close Tkt[#%I64d] %s %s",                      position_ticket,
                                                                                             position_symbol,
                                                                                             EnumToString( type )
                                                                                             );
                if ( !OrderSend( request,result ) )
                      PrintFormat( "INF:  OrderSend(Tkt[#%I64d], ... ) call ret'd error %d", position_ticket,
                                                                                             GetLastError()
                                                                                             );
                PrintFormat(       "INF:            Tkt[#%I64d] retcode=%u  deal=%I64u  order=%I64u", position_ticket,
                                                                                                      result.retcode,
                                                                                                      result.deal,
                                                                                                      result.order
                                                                                                      );
                }
          }
      
}

// places a limit order. uses globals entryHighPrice, entryLowPrice
bool OpenThis(ENUM_ORDER_TYPE type)
{
   //if (direction == 0 || lots == 0)
   //   return false;
      
   ZeroMemory(mrequest);
   ZeroMemory(mresult);
   TradeThreadOK();
   
   double entryPrice = type == ORDER_TYPE_BUY?Ask:Bid;
   //double entryPrice = rnd(type == ORDER_TYPE_BUY ? entryHighPrice : entryLowPrice); 
   //entryPrice = rnd(type == ORDER_TYPE_BUY ? MathMin(Bid - minDistance, entryPrice) : MathMax(Ask + minDistance, entryPrice)); // make safe
   
   if (StopLoss_Enabled == FromFractal)
       stoplossPrice = type == ORDER_TYPE_BUY ? LastFractalLow() - (StoplossMeasures == SL_Pips ? StopLoss_LongPips*PIP : StopLoss_LongATRs*vATR_SL) 
                                          : LastFractalHigh() + (StoplossMeasures == SL_Pips ? StopLoss_ShortPips*PIP : StopLoss_ShortATRs*vATR_SL);
   else if (StopLoss_Enabled == FromOpenPrice)
       stoplossPrice = type == ORDER_TYPE_BUY ? entryPrice - (StoplossMeasures == SL_Pips ? StopLoss_LongPips*PIP : StopLoss_LongATRs*vATR_SL) 
                                             : entryPrice + (StoplossMeasures == SL_Pips ? StopLoss_ShortPips*PIP : StopLoss_ShortATRs*vATR_SL);
   
   stoplossPrice = rnd(stoplossPrice);
   
   double risk = MathAbs(entryPrice - stoplossPrice);
   double lots = GetLots(risk);
   double STP = stoplossPrice, TKP = 0;
   if (TakeProfit_Enabled == TP_ATRs || TakeProfit_Enabled == TP_StdDevs)
      TKP = rnd(type == ORDER_TYPE_BUY ? entryPrice + vATR_TP * TakeProfit_LongATRs : entryPrice - vATR_TP * TakeProfit_ShortATRs);
   else if (TakeProfit_Enabled == TP_Pips)
      TKP = rnd(type == ORDER_TYPE_BUY ? entryPrice + PIP * TakeProfit_LongPips : entryPrice - PIP * TakeProfit_ShortPips);
   else if (TakeProfit_Enabled == TP_RewardToRisk)
      TKP = rnd(type == ORDER_TYPE_BUY ? entryPrice + risk * TakeProfit_LongRewardToRisk : entryPrice - risk * TakeProfit_ShortRewardToRisk);
   
   if (type == ORDER_TYPE_BUY)
   {
      mrequest.action = TRADE_ACTION_DEAL;                                // immediate order execution
      mrequest.price = entryPrice; 
      mrequest.sl = STP;
      mrequest.tp = TKP;
      mrequest.symbol = Symbol();                                         // currency pair
      mrequest.volume = lots;                                            // number of lots to trade
      mrequest.magic = MagicNumber;                                        // Order Magic Number
      mrequest.type = ORDER_TYPE_BUY;                                     // Buy Order
      mrequest.type_filling = OrderFill; //ORDER_FILLING_FOK;                          // Order execution type
      mrequest.type_time = OrderTime; //ORDER_TIME_GTC;
      mrequest.deviation=MaxSlippage;                                     // Deviation from current price
      mrequest.comment = short_name;
      
      //--- send order
      Print(TimeToString(TimeCurrent())+" BUY ",DoubleToString(mrequest.price,Digits())," SL ",DoubleToString(mrequest.sl,Digits())
               ," TP ",DoubleToString(mrequest.tp,Digits())+", atr=",DoubleToString(atrSeries[1],Digits()));
               
      int tries = 0;
      while (tries++ < 5)
      {
         entryPrice = type == ORDER_TYPE_BUY?Ask:Bid;
         mrequest.price = entryPrice; 
      
         double perfectEntryPrice = mrequest.price;
         bool ok = OrderSend(mrequest,mresult);      
         if (!ok)
            Print("Problem opening order! Error=",(GetLastError()));
         else 
         {
            entrySlippageOfLatestTrade = NormalizeDouble(perfectEntryPrice - mresult.price,Digits());
            string info = TimeToString(TimeCurrent())+ " (MT4 time) "+TimeToString(TimeLocal())+ " (local): Trade opened; ticket "+IntegerToString(mresult.order)
                           +" BUY "+DoubleToString(mresult.volume,2)+" lots at "+DoubleToString(mresult.price,Digits())+" entry slippage "+DoubleToString(entrySlippageOfLatestTrade,Digits());
            Print(info);
            
            return ok;
         }
         Sleep(1000);
         TradeThreadOK();
      }
   }
   if (type == ORDER_TYPE_SELL)
   {
      mrequest.action = TRADE_ACTION_DEAL;                                // immediate order execution
      mrequest.price = entryPrice; 
      mrequest.sl = STP;
      mrequest.tp = TKP;
      mrequest.symbol = Symbol();                                         // currency pair
      mrequest.volume = lots;                                            // number of lots to trade
      mrequest.magic = MagicNumber;                                        // Order Magic Number
      mrequest.type = ORDER_TYPE_SELL;                                     // Buy Order
      mrequest.type_filling = OrderFill; //ORDER_FILLING_FOK;                          // Order execution type
      mrequest.type_time = OrderTime; //ORDER_TIME_GTC;
      mrequest.deviation=MaxSlippage;                                     // Deviation from current price
      mrequest.comment = short_name;
      
      //--- send order
      Print(TimeToString(TimeCurrent())+" SELL ",DoubleToString(mrequest.price,Digits())," SL ",DoubleToString(mrequest.sl,Digits())
               ," TP ",DoubleToString(mrequest.tp,Digits())+", atr=",DoubleToString(atrSeries[1],Digits()));
               
      int tries = 0;
      while (tries++ < 5)
      {
         entryPrice = type == ORDER_TYPE_BUY?Ask:Bid;
         mrequest.price = entryPrice; 
      
         double perfectEntryPrice = mrequest.price;
         bool ok = OrderSend(mrequest,mresult);
         if (!ok)
            Print("Problem opening order! Error=",(GetLastError()));
         else 
         {
            entrySlippageOfLatestTrade = NormalizeDouble(mresult.price - perfectEntryPrice,Digits());
            string info = TimeToString(TimeCurrent())+ " (MT4 time) "+TimeToString(TimeLocal())+ " (local): Trade opened; ticket "+IntegerToString(mresult.order)
                     +" SELL "+DoubleToString(mresult.volume,2)+" lots at "+DoubleToString(mresult.price,Digits())+" entry slippage "+DoubleToString(entrySlippageOfLatestTrade,Digits());
            Print(info);
            
            return ok;
         }
         Sleep(1000);
         TradeThreadOK();
      }
   }
   
   return false;
}

int NumOpenLongs()
{
   CountPositions();
   return openLongs;
}

int NumOpenShorts()
{
  CountPositions();
  return openShorts;
}


void CountPositions()
{
   int total = PositionsTotal();                            // .GET  number of open positions
   openLongs = 0; // init
   openShorts = 0;
   latestShortTicket = 0;
   latestLongTicket = 0;
   latestShortOpenPrice = -1;
   latestLongOpenPrice = -1;
   positionsThisSymbol = 0;
   //Print("CountPositions ",total);
   for (  int i = total - 1; i >= 0; i-- )                              // .ITER  over all open positions
   {                     
       TradeThreadOK();
       
       //        .GET  params of the order:
       ulong  position_ticket  = PositionGetTicket(       i );                               //  - ticket of the position
       string position_symbol  = PositionGetString(       POSITION_SYMBOL );                 //  - symbol 
       int    digits           = (int) SymbolInfoInteger( position_symbol,       
                                                          SYMBOL_DIGITS      
                                                          );                                 //  - number of decimal places
       ulong  magic            = PositionGetInteger(      POSITION_MAGIC );                  //  - MagicNumber of the position
       double volume           = PositionGetDouble(       POSITION_VOLUME );                 //  - volume of the position
       ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE) PositionGetInteger( POSITION_TYPE );   //  - type of the position
       double open             = PositionGetDouble(POSITION_PRICE_OPEN);
       
       if ( position_symbol == Symbol())
         positionsThisSymbol++;
         
       if (  position_symbol == Symbol() && magic == MagicNumber)                               // .IF MATCH:
       {
       
         if (type==POSITION_TYPE_BUY)
         {
            //Print("CountPosition Buy ",i," open ",open);
            openLongs++;
            if (latestLongTicket <= 0)
            {
               latestLongTicket = (int)position_ticket;
               latestLongOpenPrice = open;
               //Print("found long position ",position_ticket," at ",latestLongOpenPrice);
            }
         }
         else if (type==POSITION_TYPE_SELL)
         {
            //Print("CountPosition Sell ",i," open ",open);
            openShorts++;
            if (latestShortTicket <= 0)
            {
               latestShortTicket = (int)position_ticket;
               latestShortOpenPrice = open;
               //Print("found short position ",position_ticket," at ",latestShortOpenPrice);
            }
         }
      }
   }
}

void TradeThreadOK()
{

   int waitnum = 0;
   while( ((MQLInfoInteger(MQL_TRADE_ALLOWED)==false)  
         //|| MQLInfoInteger(MQL_SIGNALS_ALLOWED)==false
         )    
      && waitnum <30) 
   {                                                                          
      waitnum++;
      Sleep(200+waitnum*4);                                                    
   }
   SymbolInfoTick(Symbol(),latest_price); // RefreshRates() ish
   Ask = latest_price.ask;
   Bid = latest_price.bid;
}


void DoObjectsDeleteAll()
{
      // custom iteration deleting all possible (existent or not) objects generated by this script      
      // generic version based on short_name preface
      int    obj_total=ObjectsTotal(ChartID(),0);
      string name;
      int NameLength = StringLen(short_name);

      for (int x=obj_total-1; x>=0; x--)
      {
         name=ObjectName(ChartID(),x,0);
         //Print(x,"Object name for object #",x," is " + name);
         if (StringSubstr(name,0,NameLength) == short_name)
         {
            ObjectDelete(ChartID(),name);
            //x--;
         }         
      }
      Comment("");   // remove any comment as well.
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double rnd(double price)   // rounds to tick size, even if CFDs have odd sizes
{
   double ticksize = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
   return  NormalizeDouble(MathRound(price/ticksize)*ticksize,Digits()); // corrects for CFD tick sizes, e.g. of 0.10
}

// BASED ON RISK (STOPLOSS DISTANCE)
double GetLots(double riskPoints)
{
   double lots = 0, moneyAllowed = 0, dollarRisk = 0, ticksRisk = 0, tickValue = 0, step = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   
   if (Lots == Fixed)
	 lots = Lots_Fixed;
	else if (Lots == SmartMoney)
	{
	   double capital = AccountInfoDouble(ACCOUNT_BALANCE);
	   int capitalChunks = (int)MathFloor(capital / MathMax(1,Lots_SM_CapitalAmount));
	   lots = capitalChunks * Lots_SM_LotsPerCapital;
	}
   else if (Lots == RiskPercent)
   {
      tickValue = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE); //MarketInfo(Symbol(),MODE_TICKVALUE);
      ticksRisk = MathCeil(riskPoints/SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE));
      dollarRisk = ticksRisk * tickValue;
      moneyAllowed = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01 * Lots_RiskPct;
      lots = moneyAllowed / dollarRisk;
   }
   
   lots = NormalizeToValidLots(lots);   
   
   if (Lots == RiskPercent)
      Print("PositionSize (AccountPercent) calculated for allowed $"+DoubleToString(moneyAllowed,0)+" with "+DoubleToString(ticksRisk,0)+" ticks at risk is "+DoubleToString(lots,2)+ ", stepsize for "+Symbol()+" is "+DoubleToString(step,2));
   return lots;
}


double NormalizeToValidLots(double lots)
{
   double step = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP); //MarketInfo(Symbol(),MODE_LOTSTEP);
   lots = NormalizeDouble(MathFloor(lots/step)*step,2);
   double min = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   lots = MathMax(MathMax(MinLot,min),lots);
   lots = MathMin(MathMin(MaxLot,max),lots);   
   return NormalizeDouble(lots,2); 
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int GetEntrySignal()
{
   int signal = 0;
   string signalName = "";
   int currentTrend = 0;
   if (  (!QQE || latestQQETrend > 0)
      && (!MovAvgs || latestMovAvgTrend > 0)
      && (!VWAP || latestVWAPTrend > 0)
      )
      currentTrend = +1;
   else 
   if (  (!QQE || latestQQETrend < 0)
      && (!MovAvgs || latestMovAvgTrend < 0)
      && (!VWAP || latestVWAPTrend < 0)
      )
      currentTrend = -1;
   else 
   if (!QQE && !MovAvgs && !VWAP)
      currentTrend = INT_MIN;
   
   // find out which gaps can be declared Inverted (iFVG)
   if (Trade_iFVGs)
   {
      for (int a = 0; a < ArraySize(gapInfos); a++)
      {
         if (iBarShift(Symbol(),PERIOD_CURRENT,gapInfos[a].Time,true) > iFVGs_MaxBars+1)
            break;
         if (gapInfos[a].IsInverted)
            continue;
            
         if (gapInfos[a].OriginalDirection > 0 && iClose(Symbol(),PERIOD_CURRENT,1) < gapInfos[a].RearPrice)
         {
            gapInfos[a].IsInverted = true;
            // i guess this creates a short signal
            if (currentTrend == -1 || currentTrend == INT_MIN)
            {
               signal = -1;
               signalName = "iFVG";
            }
         }
         
         if (gapInfos[a].OriginalDirection < 0 && iClose(Symbol(),PERIOD_CURRENT,1) > gapInfos[a].RearPrice)
         {
            gapInfos[a].IsInverted = true;
            // i guess this creates a long signal
            if (currentTrend == +1 || currentTrend == INT_MIN)
            {
               signal = +1;
               signalName = "iFVG";
            }
         }
      }
   }
   
   if (Trade_FVGs)
   {
      // a new one found just now?
      if (ArraySize(gapInfos) > 0 && gapInfos[0].Time == iTime(Symbol(),PERIOD_CURRENT,2))
      {
         if (gapInfos[0].OriginalDirection > 0
            && (currentTrend == +1 || currentTrend == INT_MIN)
            )
            {
               signal = +1;
               signalName = "FVG";
            }
         else 
         if (gapInfos[0].OriginalDirection < 0
            && (currentTrend == -1 || currentTrend == INT_MIN)
            )
            {
               signal = -1;
               signalName = "FVG";
            }
      }
   }
   
   if (signal != 0)
      Print(iTime(Symbol(),PERIOD_CURRENT,1)," signal ",signalName," ",signal);
   return signal;
}

bool GetExitSignal()
{
   
    
   return false;
     
}

bool CancelPendingOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;

        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        
        if (type == ORDER_TYPE_BUY_LIMIT || 
            type == ORDER_TYPE_SELL_LIMIT ||
            type == ORDER_TYPE_BUY_STOP || 
            type == ORDER_TYPE_SELL_STOP ||
            type == ORDER_TYPE_BUY_STOP_LIMIT ||
            type == ORDER_TYPE_SELL_STOP_LIMIT)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = ticket;

            if (!OrderSend(request, result))
            {
                Print("Failed to delete order #", ticket, ". Error code: ", GetLastError());
                return false;
            }
        }
    }
    return true;
}

double LastFractalHigh()
{
   TesterHideIndicators(true);
   for (int i = 2; i < iBars(Symbol(),PERIOD_CURRENT); i++)
   {
      double frac = fractalsUpperSeries[i]; //iFractals(Symbol(),0,MODE_UPPER,i);
      if (frac > 0 && frac != EMPTY_VALUE)
         return frac;
   }
   TesterHideIndicators(false);
   
   return MathMax(high[1],high[2]); // fallthrough
}

double LastFractalLow()
{
   TesterHideIndicators(true);
   for (int i = 2; i < iBars(Symbol(),PERIOD_CURRENT); i++)
   {
      double frac = fractalsLowerSeries[i]; //iFractals(Symbol(),0,MODE_LOWER,i);
      if (frac > 0 && frac != EMPTY_VALUE)
         return frac;
   }
   TesterHideIndicators(false);
   
   return MathMin(low[1],low[2]); // fallthrough
}

// INPUTS ARE MT4 time
bool CheckTime(int begin, int end)
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(),timeStruct);
   
   int hour = timeStruct.hour;
   int minute = timeStruct.min;
   
    //  (NOT DONE HERE): Apply GMT offset and NY
    int adjusted_hour = hour; //(hour - GMT_Offset 
    //        - brokerToGMTOffset
    //        + 24) % 24;    // NOTE; here we are converting the bar time to NY. In the indicator we are converting NY times to bar times. This explains why we are using minus signs HERE but plus signs in the indicator.
   //Print("TimeCurrent ",TimeCurrent()," GMT_Offset (to NY) ",GMT_Offset," brokerToGMTOffset ",brokerToGMTOffset," auto=",Auto_BrokerGMT_Offset," hour ",hour," adjusted to ",adjusted_hour);// CHECKER         
   int t = adjusted_hour*100 + minute;
   if (t >= 2400)
      t -= 2400;
      
   if (begin == end)    // 24 hours per day
      return true;
   else if (begin < end)     // standard inside a day 
   {
      if (t >= begin && t < end)
         return true;   // in session
   }
   else if (begin > end)   // spanning midnight
   {
      if (t >= begin || t < end)
         return true;
   }
   
   return false; // out of session
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+ 
//| Filling indicator buffers from the indicator                | 
//+------------------------------------------------------------------+ 
bool FillArrayFromBuffer(double &values[],  // indicator buffer for ATR values 
                         int ind_handle,    // handle of the iATR indicator 
                         int amount,         // number of copied values
                         int buffer  
                         ) 
  { 
//--- reset error code 
   ResetLastError(); 
//--- fill a part of the iATRBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(ind_handle,buffer,0,amount,values)<0) 
     { 
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError()); 
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false); 
     } 
//--- everything is fine 
   return(true); 
  } 
  
  

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                    CHART DASHBOARD                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void DoDashboard()
{
   long id = ChartID();
   int lineHeight = (int)(ChartDashboard_FontSize * 2.0);
   int currentLine = 4;
   int yDistance = currentLine * lineHeight;
   
   string name = short_name + "_dashboard" + IntegerToString(currentLine);
   if (ObjectFind(id,name) < 0)
   {
      // create a text label in the bottom left of the chart, using ChartDashboard_Font and ChartDashboard_FontSize and ChartDashboard_Color. Text should be the TimeCurrent()
      
      // from Copilot (lol)
      // To create a text label in the bottom left of the chart using MQL5 language, you can use the `ObjectCreate` function to create a text label object, and then set its properties using the `ObjectSet` function. Here's an example:
      // 
      
      // Create the text label object
      int label = ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      if (label == -1)
      {
          Print("Failed to create label object!");
          return;
      }
      
      // Set the properties for the text label
      ObjectSetString(id, name, OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(id, name, OBJPROP_COLOR, ChartDashboard_Color);
      ObjectSetInteger(id, name, OBJPROP_FONTSIZE, ChartDashboard_FontSize);
      ObjectSetString(id, name, OBJPROP_FONT, ChartDashboard_Font);
      ObjectSetInteger(id, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(id, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(id, name, OBJPROP_YDISTANCE, yDistance);
      ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      // 
      // This code will create a text label object named "TextLabel" in the bottom left corner of the chart. The text of the label will be set to the current time using the `TimeCurrent()` function. The font, font size, and color of the label can be customized by changing the values of `ChartDashboard_Font`, `ChartDashboard_FontSize`, and `ChartDashboard_Color` respectively. The `OBJPROP_CORNER`, `OBJPROP_XDISTANCE`, and `OBJPROP_YDISTANCE` properties are used to position the label in the bottom left corner of the chart with a 10-pixel distance from the edges.
      // 

   }

   // now properly fil it with stuff
   
   
   string line = "Spread "+DoubleToString((Ask - Bid)/PIP,UseWholePips?1:0);
   //line += ", EntrySlippage "+DoubleToString(entrySlippageOfLatestTrade/PIP,UseWholePips?1:0);
   
   ObjectSetString(id, name, OBJPROP_TEXT, line);
   currentLine--; // ------------------------------------------------------------------------
   yDistance = currentLine * lineHeight;
   line = "";
   
   name = short_name + "_dashboard" + IntegerToString(currentLine);
   if (ObjectFind(id,name) < 0)
   {
      // Create the text label object
      int label = ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      if (label == -1)
      {
          Print("Failed to create label object!");
          return;
      }
      
      // Set the properties for the text label
      ObjectSetString(id, name, OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(id, name, OBJPROP_COLOR, ChartDashboard_Color);
      ObjectSetInteger(id, name, OBJPROP_FONTSIZE, ChartDashboard_FontSize);
      ObjectSetString(id, name, OBJPROP_FONT, ChartDashboard_Font);
      ObjectSetInteger(id, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(id, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(id, name, OBJPROP_YDISTANCE, yDistance);
      ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      // 
      // This code will create a text label object named "TextLabel" in the bottom left corner of the chart. The text of the label will be set to the current time using the `TimeCurrent()` function. The font, font size, and color of the label can be customized by changing the values of `ChartDashboard_Font`, `ChartDashboard_FontSize`, and `ChartDashboard_Color` respectively. The `OBJPROP_CORNER`, `OBJPROP_XDISTANCE`, and `OBJPROP_YDISTANCE` properties are used to position the label in the bottom left corner of the chart with a 10-pixel distance from the edges.
      // 

   }

   
   ObjectSetString(id, name, OBJPROP_TEXT, line);
   currentLine--; // ------------------------------------------------------------------------
   yDistance = currentLine * lineHeight;
   line = "";
   
   name = short_name + "_dashboard" + IntegerToString(currentLine);
   if (ObjectFind(id,name) < 0)
   {
      // Create the text label object
      int label = ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      if (label == -1)
      {
          Print("Failed to create label object!");
          return;
      }
      
      // Set the properties for the text label
      ObjectSetString(id, name, OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(id, name, OBJPROP_COLOR, ChartDashboard_Color);
      ObjectSetInteger(id, name, OBJPROP_FONTSIZE, ChartDashboard_FontSize);
      ObjectSetString(id, name, OBJPROP_FONT, ChartDashboard_Font);
      ObjectSetInteger(id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(id, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(id, name, OBJPROP_YDISTANCE, yDistance);
      ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      // 
      // This code will create a text label object named "TextLabel" in the bottom left corner of the chart. The text of the label will be set to the current time using the `TimeCurrent()` function. The font, font size, and color of the label can be customized by changing the values of `ChartDashboard_Font`, `ChartDashboard_FontSize`, and `ChartDashboard_Color` respectively. The `OBJPROP_CORNER`, `OBJPROP_XDISTANCE`, and `OBJPROP_YDISTANCE` properties are used to position the label in the bottom left corner of the chart with a 10-pixel distance from the edges.
      // 

   }


   double floatingDrawDown = MathMax(0,-(accountHighWater - AccountInfoDouble(ACCOUNT_EQUITY))) + DBL_EPSILON;
   double drawdown = MathMax(0,-(accountHighWater - AccountInfoDouble(ACCOUNT_BALANCE))) + DBL_EPSILON;
   long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);

   
   line = "Floating DD $"+DoubleToString(floatingDrawDown,2) + ", DD $"+DoubleToString(drawdown,2) + ", Leverage "+IntegerToString(leverage);
   
   
   ObjectSetString(id, name, OBJPROP_TEXT, line);
   currentLine--; // ------------------------------------------------------------------------
   yDistance = currentLine * lineHeight;
   line = "";
   
   
   name = short_name + "_dashboard" + IntegerToString(currentLine);
   if (ObjectFind(id,name) < 0)
   {
      // Create the text label object
      int label = ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      if (label == -1)
      {
          Print("Failed to create label object!");
          return;
      }
      
      // Set the properties for the text label
      ObjectSetString(id, name, OBJPROP_TEXT, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      ObjectSetInteger(id, name, OBJPROP_COLOR, ChartDashboard_Color);
      ObjectSetInteger(id, name, OBJPROP_FONTSIZE, ChartDashboard_FontSize);
      ObjectSetString(id, name, OBJPROP_FONT, ChartDashboard_Font);
      ObjectSetInteger(id, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(id, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(id, name, OBJPROP_YDISTANCE, yDistance);
      ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(id, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      // 
      // This code will create a text label object named "TextLabel" in the bottom left corner of the chart. The text of the label will be set to the current time using the `TimeCurrent()` function. The font, font size, and color of the label can be customized by changing the values of `ChartDashboard_Font`, `ChartDashboard_FontSize`, and `ChartDashboard_Color` respectively. The `OBJPROP_CORNER`, `OBJPROP_XDISTANCE`, and `OBJPROP_YDISTANCE` properties are used to position the label in the bottom left corner of the chart with a 10-pixel distance from the edges.
      // 

   }

   double marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginAvailable = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double floatingPnL = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
   
   line = "Margin used $"+DoubleToString(marginUsed,2)+" Free $"+DoubleToString(marginAvailable,2)+" FloatingPnL $"+DoubleToString(floatingPnL,2);
   

   
   ObjectSetString(id, name, OBJPROP_TEXT, line);
   currentLine--; // ------------------------------------------------------------------------
   yDistance = currentLine * lineHeight;
   line = "";
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                     SOURCE INDICATORS                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void CalculateQQETrend()
{
   double qqeValue = qqeSeries[1];
   double qqeSlowValue = qqeSlowSeries[1];
   //Print("QQE: ",qqeSeries[1]," versus ",qqeSlowSeries[1]);
   
   if (qqeValue > qqeSlowValue)
   {
      // uptrend
      if (latestQQETrend != +1)
      {
         //if (developer) 
            Print(iTime(Symbol(),PERIOD_CURRENT,1)," QQE trend UP: ",qqeSeries[1]," versus ",qqeSlowSeries[1]);
         latestQQETrend = +1;
      }
   }
   else if (qqeValue < qqeSlowValue)
   {
      // uptrend
      if (latestQQETrend != -1)
      {
         //if (developer) 
            Print(iTime(Symbol(),PERIOD_CURRENT,1)," QQE trend DOWN: ",qqeSeries[1]," versus ",qqeSlowSeries[1]);
         latestQQETrend = -1;
      }
   }
}

void CalculateMovAvgTrend()
{
   double fast = fastmaSeries[1], medium = mediummaSeries[1], slow = slowmaSeries[1];
   if (fast > medium && medium > slow)
   {
      if (latestMovAvgTrend != +1)
         Print(iTime(Symbol(),PERIOD_CURRENT,1), " MovAvgs trend UP: F=",fast," M=",medium," S=",slow);
      latestMovAvgTrend = +1;
   }
   else 
   if (fast < medium && medium < slow)
   {
      if (latestMovAvgTrend != -1)
         Print(iTime(Symbol(),PERIOD_CURRENT,1), " MovAvgs trend DOWN: F=",fast," M=",medium," S=",slow);
      latestMovAvgTrend = -1;
   }
   else 
   {
      if (latestMovAvgTrend != 0)
         Print(iTime(Symbol(),PERIOD_CURRENT,1), " MovAvgs trend n/a: F=",fast," M=",medium," S=",slow);
      latestMovAvgTrend = 0;
   }
}

void CalculateVWAPTrend()
{
   double c = iClose(Symbol(),PERIOD_CURRENT,1);
   double vwap = vwapSeries[1];
   if (c >= vwap)
   {
      if (latestVWAPTrend != +1)
         Print(iTime(Symbol(),PERIOD_CURRENT,1)," VWAP trend UP: c=",c," vwap=",vwap);
      latestVWAPTrend = +1;
   }
   else 
   {
      if (latestVWAPTrend != -1)
         Print(iTime(Symbol(),PERIOD_CURRENT,1)," VWAP trend DOWN: c=",c," vwap=",vwap);
      latestVWAPTrend = -1;
   }
}

void CollectFVGs()
{
   
   // gaps will be written a further bar behind 
   double gap = fvgGapSeries[2];
   bool newGap = false;
   if (gap > 0.1)
   {
      newGap = true;
      UpsizeSeriesArray(gapInfos);
      gapInfos[0].FrontPrice = iLow(Symbol(),PERIOD_CURRENT,1);
      gapInfos[0].RearPrice = iHigh(Symbol(),PERIOD_CURRENT,3);
      gapInfos[0].OriginalDirection = +1;
      gapInfos[0].IsInverted = false;
      gapInfos[0].Time = iTime(Symbol(),PERIOD_CURRENT,2);  
   }
   else if (gap < -0.1)
   {
      newGap = true;
      UpsizeSeriesArray(gapInfos);
      gapInfos[0].FrontPrice = iHigh(Symbol(),PERIOD_CURRENT,1);
      gapInfos[0].RearPrice = iLow(Symbol(),PERIOD_CURRENT,3);
      gapInfos[0].OriginalDirection = -1;
      gapInfos[0].IsInverted = false;
      gapInfos[0].Time = iTime(Symbol(),PERIOD_CURRENT,2);  
   }
   
   if (newGap)
      Print(gapInfos[0].Time," gap ",gapInfos[0].OriginalDirection," rear ",gapInfos[0].RearPrice," front ",gapInfos[0].FrontPrice);
}

//+X================================================================X+
//| UpsizeSeriesArray() function                               |
//+X================================================================X+
void UpsizeSeriesArray(GapInfo & array[])
//----+
  {
  // this function adds a new empty bucket on the newest end of a series array. (DataSeries c# style.)
    {
       ArraySetAsSeries(array, false);
       ArrayResize(array, ArraySize(array)+1);
       ArraySetAsSeries(array, true);
    }
  }
//----+
