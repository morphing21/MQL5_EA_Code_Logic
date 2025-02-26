//+------------------------------------------------------------------+
//|                                              amFairValueGaps.mq5 |
//|                                Copyright 2024, TradingCoders.com |
//|                                    https://www.tradingcoders.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, TradingCoders.com"
#property link      "https://www.tradingcoders.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   9
//--- plot FVG_Score
#property indicator_label1  "FVG_Score"
#property indicator_type1   DRAW_NONE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_color1  clrNONE
// add two more plots for the Order Blocks, price rear and price front (if rear is lower than front, it is bullish OB, if rear is higher than front, it is bearish OB)
#property indicator_label2 "OB_RearPrice"
#property indicator_type2   DRAW_NONE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
#property indicator_color2  clrNONE 

#property indicator_label3 "OB_FrontPrice"
#property indicator_type3   DRAW_NONE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
#property indicator_color3  clrNONE

#property indicator_label4 "Major High"
#property indicator_type4   DRAW_ARROW
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3
#property indicator_color4  clrLime

#property indicator_label5 "Major Low"
#property indicator_type5   DRAW_ARROW
#property indicator_style5  STYLE_SOLID
#property indicator_width5  3
#property indicator_color5  clrMagenta

#property indicator_label6 "Minor High"
#property indicator_type6   DRAW_ARROW
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1
#property indicator_color6  clrLime

#property indicator_label7 "Minor Low"
#property indicator_type7   DRAW_ARROW
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1
#property indicator_color7  clrMagenta

#property indicator_label8 "OB Bull Mitigation"
#property indicator_type8   DRAW_ARROW
#property indicator_style8  STYLE_SOLID
#property indicator_width8  4
#property indicator_color8  clrDodgerBlue

#property indicator_label9 "OB Bear Mitigation"
#property indicator_type9   DRAW_ARROW
#property indicator_style9  STYLE_SOLID
#property indicator_width9  4
#property indicator_color9  clrCrimson 





//--- input parameters
//input 
  bool FairValueGaps = true;
input double   MinimumGapATRs=0.0;
input int      ATR_Period = 20;
input bool     VisualMarkings=true;
input color    BullishColor=clrDeepSkyBlue;
input color    BearishColor=clrGoldenrod;
input int      VisualWidth=15;

input int MajorStructurePeriod = 4;

input int      MaxVisualBars=1000;

input bool OrderBlocks = true;
  
//--- indicator buffers
double         FVG_ScoreBuffer[], OB_RearPriceBuffer[], OB_FrontPriceBuffer[], MajorHighBuffer[], MajorLowBuffer[], MinorHighBuffer[], MinorLowBuffer[],
               OBBullMitigationBuffer[], OBBearMitigationBuffer[];

// INTERNAL VARIABLES:
string short_name = "amFVGOB";
int atrHandle;
double atrBuffer[];

datetime latestMajorHighTime = 0, latestMajorLowTime = 0;
double latestMajorHigh = 0, latestMajorLow = 0;
datetime latestMinorHighTime = 0, latestMinorLowTime = 0;
double latestMinorHigh = 0, latestMinorLow = 0;

class OBData 
{
  public:
    double High;
    double Low;
    bool IsBullish;
    datetime Time;
    bool IsMitigated;
    string tag;
};
OBData obData[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
    SetIndexBuffer(0,FVG_ScoreBuffer,INDICATOR_DATA);
    SetIndexBuffer(1,OB_RearPriceBuffer,INDICATOR_DATA);
    SetIndexBuffer(2,OB_FrontPriceBuffer,INDICATOR_DATA);
    SetIndexBuffer(3,MajorHighBuffer,INDICATOR_DATA);
    SetIndexBuffer(4,MajorLowBuffer,INDICATOR_DATA);
    SetIndexBuffer(5,MinorHighBuffer,INDICATOR_DATA);
    SetIndexBuffer(6,MinorLowBuffer,INDICATOR_DATA);
    SetIndexBuffer(7,OBBullMitigationBuffer,INDICATOR_DATA);
    SetIndexBuffer(8,OBBearMitigationBuffer,INDICATOR_DATA);

    // set the arrow characters to a dot
    PlotIndexSetInteger(3, PLOT_ARROW, 119);
    PlotIndexSetInteger(4, PLOT_ARROW, 119);
    PlotIndexSetInteger(5, PLOT_ARROW, 167);
    PlotIndexSetInteger(6, PLOT_ARROW, 167);
    // and arrows
    PlotIndexSetInteger(7, PLOT_ARROW, 233);
    PlotIndexSetInteger(8, PLOT_ARROW, 234);
   
   atrHandle = iATR(_Symbol, _Period, MathMax(2,ATR_Period));
    if (atrHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR handle. Error code: ", GetLastError());
        return(INIT_FAILED);
    }

    ArraySetAsSeries(obData,true);
//---
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
{
   DoDeleteAllObjects();
   if (atrHandle != INVALID_HANDLE)
   {
       IndicatorRelease(atrHandle);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
  ArraySetAsSeries(open, true);
  ArraySetAsSeries(high, true);
  ArraySetAsSeries(low, true);
  ArraySetAsSeries(close, true);
  ArraySetAsSeries(time, true);
  ArraySetAsSeries(FVG_ScoreBuffer, true);
  ArraySetAsSeries(OB_RearPriceBuffer, true);
  ArraySetAsSeries(OB_FrontPriceBuffer, true);
  ArraySetAsSeries(MajorHighBuffer, true);
  ArraySetAsSeries(MajorLowBuffer, true);
  ArraySetAsSeries(MinorHighBuffer, true);
  ArraySetAsSeries(MinorLowBuffer, true);
  ArraySetAsSeries(OBBullMitigationBuffer, true);
  ArraySetAsSeries(OBBearMitigationBuffer, true);

  if (prev_calculated == 0)
  {
    // reset variables
    latestMajorHigh = 0;
    latestMajorLow = 0;
    latestMinorHigh = 0;
    latestMinorLow = 0;
    latestMajorHighTime = 0;
    latestMajorLowTime = 0;
    latestMinorHighTime = 0;
    latestMinorLowTime = 0;
    
   DoDeleteAllObjects();
  }

   int limit = rates_total - prev_calculated;
   limit = MathMin(limit, rates_total -10);
   

  // fill the atrSeries with the requirement amount of bars we need for this 'limit' amount of bars
  int calculated = CopyBuffer(atrHandle, 0, 0, limit+3, atrBuffer);
  if (calculated < 0)
  {
      Print("Failed to copy ATR buffer. Error code: ", GetLastError());
      return (0);
  }
   //Print("OnCalculate");
   for (int shift = limit; shift >= 1; shift--)
   {
         // empty things
        FVG_ScoreBuffer[shift] = EMPTY_VALUE;
        OB_RearPriceBuffer[shift] = EMPTY_VALUE;
        OB_FrontPriceBuffer[shift] = EMPTY_VALUE;
        MajorHighBuffer[shift] = EMPTY_VALUE;
        MajorLowBuffer[shift] = EMPTY_VALUE;
        MinorHighBuffer[shift] = EMPTY_VALUE;
        MinorLowBuffer[shift] = EMPTY_VALUE;
        OBBullMitigationBuffer[shift] = EMPTY_VALUE;
        OBBearMitigationBuffer[shift] = EMPTY_VALUE;
        
       int score = 0;
       
       if (FairValueGaps)
       { 
          //Print("shift: ",shift, " rates_total ",rates_total," prev_calculated ",prev_calculated); // CHECKER
          double current_open = open[shift];
          double current_close = close[shift];
          double current_high = high[shift];
          double current_low = low[shift];
          
          double prev_open = open[shift + 2];
          double prev_close = close[shift + 2];
          double prev_high = high[shift + 2];
          double prev_low = low[shift + 2];
          
          // Bullish FVG: Current candle's low is higher than previous candle's high
          if (current_low > prev_high       
            // and the gap is at least the minimum ATRs
            && (current_low - prev_high) > atrBuffer[shift+2] * MinimumGapATRs
            )
          {
              score = 1;  // Bullish FVG           
          }
          // Bearish FVG: Current candle's high is lower than previous candle's low
          else if (current_high < prev_low       
            // and the gap is at least the minimum ATRs
            && (prev_low - current_high) > atrBuffer[shift+2] * MinimumGapATRs
            )
          {
              score = -1;  // Bearish FVG
          }
          else
          {
              // No FVG detected
          }
          
          FVG_ScoreBuffer[shift+1] = score;
          if (score != 0) 
            Print(time[shift+1]," Fair Value Gap ",(score > 0 ? "Bullish":"Bearish"));
          
          if (VisualMarkings && shift <= MaxVisualBars && score != 0)
          {
            CreateVisualMarker(shift+1, time[shift+1], score > 0 ? current_low : prev_low, score > 0 ? prev_high : current_high, score);
          }
       }

       if (OrderBlocks)
       {
          CalculateOrderBlocks(shift);
          ContinueAndMitigateOrderBlocks(shift);
       }
   }
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }

void CalculateOrderBlocks(int shift)
{
  // MAJOR swing levels
  if (shift - MajorStructurePeriod > 0)
  {
    if (IsHighestHigh(shift, MajorStructurePeriod))
    {
      MajorHighBuffer[shift] = iHigh(Symbol(), PERIOD_CURRENT, shift);
      if (iTime(Symbol(), PERIOD_CURRENT, shift) > latestMajorHighTime)
      {
        latestMajorHigh = MajorHighBuffer[shift];
        latestMajorHighTime = iTime(Symbol(), PERIOD_CURRENT, shift);


      }
    }
    if (IsLowestLow(shift, MajorStructurePeriod))
    {
      MajorLowBuffer[shift] = iLow(Symbol(), PERIOD_CURRENT, shift);
      if (iTime(Symbol(), PERIOD_CURRENT, shift) > latestMajorLowTime)
      {
        latestMajorLow = MajorLowBuffer[shift];
        latestMajorLowTime = iTime(Symbol(), PERIOD_CURRENT, shift);


      }
    }
  }

  // MINOR swing levels
  if (shift - 1 > 0)
  {
    if (IsHighestHigh(shift, 1))
    {
      MinorHighBuffer[shift] = iHigh(Symbol(), PERIOD_CURRENT, shift);
      if (iTime(Symbol(), PERIOD_CURRENT, shift) > latestMinorHighTime)
      {
        latestMinorHigh = MinorHighBuffer[shift];
        latestMinorHighTime = iTime(Symbol(), PERIOD_CURRENT, shift);


      }
    }
    if (IsLowestLow(shift, 1))
    {
      MinorLowBuffer[shift] = iLow(Symbol(), PERIOD_CURRENT, shift);
      if (iTime(Symbol(), PERIOD_CURRENT, shift) > latestMinorLowTime)
      {
        latestMinorLow = MinorLowBuffer[shift];
        latestMinorLowTime = iTime(Symbol(), PERIOD_CURRENT, shift);


      }
    }
  }
  
  // =====================================================================================================================

  // Order Blocks
  // BULLISH: determine if this bar has a higher close than the prior bar and it closes above the latest MajorHigh
  if (iClose(Symbol(),0,shift) > iClose(Symbol(), 0, shift+1)
    && latestMajorHigh > 0 && iClose(Symbol(),0,shift) > latestMajorHigh
    && latestMajorHigh >= iClose(Symbol(),0,shift+1)
  )
  {
    Print(iTime(Symbol(),0,shift), " Close above latest Major HIGH at ",latestMajorHigh," from bar time ",latestMajorHighTime);
    // more...
    // find the lowest bar since shift
    int barsAgoOfBOS = iBarShift(Symbol(),0,latestMajorHighTime);
    int candidateBar = shift;
    double candidatePrice = iLow(Symbol(),0,candidateBar);
    bool bosIsAlreadyBroken = false;
    for (int i = shift; i <= barsAgoOfBOS; i++)
    {
      if (candidatePrice > iLow(Symbol(),0,i))
      {
        candidateBar = i;
        candidatePrice = iLow(Symbol(),0,i);
      }
      if (i > shift && iClose(Symbol(),0,i) > latestMajorHigh)
      {
        bosIsAlreadyBroken = true;
        break;
      }
    }
    if (bosIsAlreadyBroken)
      return;

    bool candidateOK = false, candidateWorking = candidatePrice < iLow(Symbol(),0,candidateBar+1);
    double obHigh = iHigh(Symbol(),0,candidateBar), obLow = iLow(Symbol(),0,candidateBar);

    Print("   Candidate bar Low is at ",iTime(Symbol(),0,candidateBar)," at ",candidatePrice," candidateWorking (low ok) = ",candidateWorking); // checker

    // we can scan forward for a bullish fair-value-gap
    for (int x = candidateBar; x >= shift; x--)
    {
        // try to find an FVG for a candidate bar
        if (FVG_ScoreBuffer[x] != EMPTY_VALUE && FVG_ScoreBuffer[x] > 0 // a bullish fair value gap
          && candidateWorking 
          && !candidateOK 
        )
        {
          Print("   Found FVG for candidate bar ",iTime(Symbol(),0,candidateBar)," at bar ",iTime(Symbol(),0,x));
          candidateOK = true;
          candidateWorking = false;
          // obHigh = iHigh(Symbol(),0,x);
          // obLow = iLow(Symbol(),0,x);
          x--; // skip the next bar as we already know it helped create this FVG
          continue;
        }
        
        // if we have an OB, try to find mitigations on our way forward to the BOS bar (at 'shift')
        if (candidateOK 
            && !candidateWorking 
            && iLow(Symbol(),0,x) <= obHigh
            )
        {
          Print("   candidate OB mitigated at bar ",iTime(Symbol(),0,x));
          candidateOK = false;
          candidateWorking = false;
        }

        if (!candidateWorking 
           && !candidateOK 
           && iLow(Symbol(),0,x) < iLow(Symbol(),0,x+1) // took out prior low
          )
        {
          Print("   Found alternate candidate bar to work with at ",iTime(Symbol(),0,x));
          candidateWorking = true;
          candidateBar = x;
          obHigh = iHigh(Symbol(),0,x);
          obLow = iLow(Symbol(),0,x);
        }
    }

  
    // when done
    Print("   ** Result of search for bullish OB ",candidateOK," candidateBar ",iTime(Symbol(),0,candidateBar)," obHigh ",obHigh," obLow ",obLow); // CHECKER 
    if (candidateOK)
    {
      OB_FrontPriceBuffer[candidateBar] = obHigh;
      OB_RearPriceBuffer[candidateBar] = obLow;

      // create a class in the array and draw graphics
      UpsizeSeriesArray(obData);
      obData[0].High = obHigh;
      obData[0].Low = obLow;
      obData[0].Time = iTime(Symbol(),0,candidateBar);
      obData[0].IsBullish = true;
      obData[0].IsMitigated = false;
      obData[0].tag = short_name + " BullOB " + TimeToString(obData[0].Time);

      // Draw rectangle from candidate bar to bar [shift] at the obData[0] High and Low
      if (VisualMarkings)
      {
        long id = ChartID();
        string name = obData[0].tag;
        ObjectCreate(id,name,OBJ_RECTANGLE,0, obData[0].Time,obData[0].High, iTime(Symbol(),0,shift),obData[0].Low);
        ObjectSetInteger(id,name,OBJPROP_COLOR,BullishColor);
        ObjectSetInteger(id,name,OBJPROP_BACK,true);
        ObjectSetInteger(id,name,OBJPROP_BGCOLOR,BullishColor);
        ObjectSetInteger(id,name,OBJPROP_FILL, false);
        ObjectSetInteger(id,name,OBJPROP_WIDTH,3);
        ObjectSetInteger(id,name,OBJPROP_SELECTABLE,false);
      }
    }
  }

      // BEARISH: determine if this bar has a lower close than the prior bar and it closes below the latest MajorLow
    if (iClose(Symbol(),0,shift) < iClose(Symbol(), 0, shift+1)
      && latestMajorLow > 0 && iClose(Symbol(),0,shift) < latestMajorLow
      && latestMajorLow <= iClose(Symbol(),0,shift+1)
    )
    {
      Print(iTime(Symbol(),0,shift), " Close below latest Major LOW at ",latestMajorLow," from bar time ",latestMajorLowTime);
      // more...
      // find the highest bar since shift
      int barsAgoOfBOS = iBarShift(Symbol(),0,latestMajorLowTime);
      int candidateBar = shift;
      double candidatePrice = iHigh(Symbol(),0,candidateBar);
      bool bosIsAlreadyBroken = false;
      for (int i = shift; i <= barsAgoOfBOS; i++)
      {
        if (candidatePrice < iHigh(Symbol(),0,i))
        {
          candidateBar = i;
          candidatePrice = iHigh(Symbol(),0,i);
        }
        if (i > shift && iClose(Symbol(),0,i) < latestMajorLow)
        {
          bosIsAlreadyBroken = true;
          break;
        }
      }
      if (bosIsAlreadyBroken)
        return;

      bool candidateOK = false, candidateWorking = candidatePrice > iHigh(Symbol(),0,candidateBar+1);
      double obLow = iLow(Symbol(),0,candidateBar), obHigh = iHigh(Symbol(),0,candidateBar);

      Print("   Candidate bar High is at ",iTime(Symbol(),0,candidateBar)," at ",candidatePrice," candidateWorking (high ok) = ",candidateWorking); // checker

      // we can scan forward for a bearish fair-value-gap
      for (int x = candidateBar; x >= shift; x--)
      {
          // try to find an FVG for a candidate bar
          if (FVG_ScoreBuffer[x] != EMPTY_VALUE && FVG_ScoreBuffer[x] < 0 // a bearish fair value gap
            && candidateWorking 
            && !candidateOK 
          )
          {
            Print("   Found FVG for candidate bar ",iTime(Symbol(),0,candidateBar)," at bar ",iTime(Symbol(),0,x));
            candidateOK = true;
            candidateWorking = false;
            // obLow = iLow(Symbol(),0,x);
            // obHigh = iHigh(Symbol(),0,x);
            x--; // skip the next bar as we already know it helped create this FVG
            continue;
          }
          
          // if we have an OB, try to find mitigations on our way forward to the BOS bar (at 'shift')
          if (candidateOK 
              && !candidateWorking 
              && iHigh(Symbol(),0,x) >= obLow
              )
          {
            Print("   candidate OB mitigated at bar ",iTime(Symbol(),0,x));
            candidateOK = false;
            candidateWorking = false;
          }

          if (!candidateWorking 
            && !candidateOK 
            && iHigh(Symbol(),0,x) > iHigh(Symbol(),0,x+1) // took out prior high
            )
          {
            Print("   Found alternate candidate bar to work with at ",iTime(Symbol(),0,x));
            candidateWorking = true;
            candidateBar = x;
            obLow = iLow(Symbol(),0,x);
            obHigh = iHigh(Symbol(),0,x);
          }
      }

      // when done
      Print("   ** Result of search for bearish OB ",candidateOK," candidateBar ",iTime(Symbol(),0,candidateBar)," obLow ",obLow," obHigh ",obHigh); // CHECKER 
      if (candidateOK)
      {
        OB_FrontPriceBuffer[candidateBar] = obLow;
        OB_RearPriceBuffer[candidateBar] = obHigh;
          
        // create a class in the array and draw graphics
        UpsizeSeriesArray(obData);
        obData[0].High = obHigh;
        obData[0].Low = obLow;
        obData[0].Time = iTime(Symbol(),0,candidateBar);
        obData[0].IsBullish = false;
        obData[0].IsMitigated = false;
        obData[0].tag = short_name + " BearOB " + TimeToString(obData[0].Time);

        // Draw rectangle from candidate bar to bar [shift] at the obData[0] High and Low
        if (VisualMarkings)
        {
          long id = ChartID();
          string name = obData[0].tag;
          ObjectCreate(id,name,OBJ_RECTANGLE,0, obData[0].Time,obData[0].High, iTime(Symbol(),0,shift),obData[0].Low);
          ObjectSetInteger(id,name,OBJPROP_COLOR,BearishColor);
          ObjectSetInteger(id,name,OBJPROP_BACK,true);
          ObjectSetInteger(id,name,OBJPROP_BGCOLOR,BearishColor);
          ObjectSetInteger(id,name,OBJPROP_FILL, false);
          ObjectSetInteger(id,name,OBJPROP_WIDTH,3);
          ObjectSetInteger(id,name,OBJPROP_SELECTABLE,false);
        }
      }
    }
  }

/*
Notes:
lowest bar has to take out the Low of the prior bar. this lowest bar can be red or green
there must be a gap on the next bar. If so, the lowest bar is the order block.
If there is no gap on that bar, but there IS a gap on the bar after that, then the bar after the lowest bar is the order block.You can keep going, too.

If, between the ob bar and the bar that created the BOS, the ob is mitigated, we move forward to find any other bar that can qualify as taking out its prior bar's Low. 
We test that the same way using the same rules, including being able to move forward a bar.
*/

bool IsHighestHigh(int n, int bars)
{
    // Ensure n is within the valid range
    if (n < bars || n >= iBars(Symbol(),PERIOD_CURRENT) - bars)
        return false;

    double highN = iHigh(NULL, 0, n);

    // Check bars before n
    for (int i = 1; i <= bars; i++)
    {
        if (iHigh(NULL, 0, n + i) > highN || iHigh(NULL, 0, n - i) > highN)
            return false;
    }

    return true;
}

bool IsLowestLow(int n, int bars)
{
    // Ensure n is within the valid range
    if (n < bars || n >= iBars(Symbol(),PERIOD_CURRENT) - bars)
        return false;

    double lowN = iLow(NULL, 0, n);

    // Check bars before n
    for (int i = 1; i <= bars; i++)
    {
        if (iLow(NULL, 0, n + i) < lowN || iLow(NULL, 0, n - i) < lowN)
            return false;
    }

    return true;
}

void ContinueAndMitigateOrderBlocks(int shift)
{
  // extend graphics of order blocks until mitigated, and then fire a signal
  for (int i = 0; i < ArraySize(obData); i++)
  {
      if (obData[i].IsMitigated)
        continue;

      if (VisualMarkings && shift == 1)
        ObjectMove(ChartID(),obData[i].tag, 1, iTime(Symbol(),0,shift), obData[i].Low);   // only do if realtime, to hasten historical bars

      if (obData[i].IsBullish && iLow(Symbol(),0,shift) < obData[i].High)
      {
          Print(iTime(Symbol(),0,shift)," Bull OB mitigated and triggering. Dates from ",obData[i].Time);
          if (VisualMarkings)
            ObjectMove(ChartID(),obData[i].tag, 1, iTime(Symbol(),0,shift), obData[i].Low); 
          obData[i].IsMitigated = true;
          OBBullMitigationBuffer[shift] = iLow(Symbol(),0,shift) - atrBuffer[shift+1]/5;
          continue;
      }

      if (!obData[i].IsBullish && iHigh(Symbol(),0,shift) > obData[i].Low)
      {
          Print(iTime(Symbol(),0,shift)," Bear OB mitigated and triggering. Dates from ",obData[i].Time);
          if (VisualMarkings)
            ObjectMove(ChartID(),obData[i].tag, 1, iTime(Symbol(),0,shift), obData[i].Low); 
          obData[i].IsMitigated = true;
          OBBearMitigationBuffer[shift] = iHigh(Symbol(),0,shift) + atrBuffer[shift+1]/5;
          continue;
      }
  }
}

//+------------------------------------------------------------------+
// MISC
//+------------------------------------------------------------------+


// Function to create a visual marker for Fair Value Gaps
void CreateVisualMarker(int shift, datetime timeValue, double highPrice, double lowPrice, int score)
{
    if (score == 0) return;  // No FVG, no need to draw
    
    string name = short_name + "FVG_" + TimeToString(timeValue);
    color lineColor = (score == 1) ? BullishColor : BearishColor;  
    
    double lineStart = highPrice, lineEnd = lowPrice;
    
    
    // Create the object
    ObjectCreate(0, name, OBJ_TREND, 0, timeValue, lineStart, timeValue, lineEnd);
    
    // Set object properties
    ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, VisualWidth);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DoDeleteAllObjects()
{
      // custom iteration deleting all possible (existent or not) objects generated by this script
      // generic version based on short_name preface
      int    obj_total=ObjectsTotal(ChartID(),-1,-1);
      string name;
      int NameLength = StringLen(short_name);

      for (int x=obj_total-1; x>=0; x--)
      {
         name=ObjectName(ChartID(),x,-1,-1);
         //Print(x,"Object name for object #",x," is " + name);
         if (StringSubstr(name,0,NameLength) == short_name)
         {
            ObjectDelete(ChartID(),name);         }
         
      }
      
      Comment("");   // remove any comment as well.
}

//+X================================================================X+
//| UpsizeSeriesArray() function                               |
//+X================================================================X+
void UpsizeSeriesArray(OBData & array[])
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

