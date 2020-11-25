#include <Trade/Trade.mqh> // biblioteca-padrão CTrade

//+------------------------------------------------------------------+
//|                                                  aroon_robot.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//GLOBALS
int ind_aroon;

input int lote = 1;
input int stop = 100;      // Stop loss
input int take = 50;     // Take profit
input int periodoAroon = 72;   // Periodo Aroon
input int periodoAlta = 2; // Periodo Media Alta
input int periodoBaixa = 2; // Periodo Media Baixa

double precoCorte = 0;       //teste variavel
double precoAsk = 0;         //teste variavel
double precoBid = 0;         //teste variavel
input double fechaCompraAroonSell = 100; //se estiver comprado e o aroon de venda > que o valor, fecha a posição. 100 = desabilitado
input double fechaCompraAroonBuy = 0; //se estiver comprado e o aroon de compra < que o valor, fecha a posição. 0 = desabilitado.

//Controle de horário de início/fim
MqlDateTime horaAtual;
input double toleranciaEntrada = -10; //tolerancia distancia da media de entrada em pontos
input int horaInicioAbertura = 9;
input int minutoInicioAbertura = 10;
input int horaFimAbertura = 16;
input int minutoFimAbertura = 45;
input int horaInicioFechamento = 17;
input int minutoInicioFechamento  = 0;

bool candleRompimentoCompra = false;
bool novoCandleCompra = false;

bool candleRompimentoVenda = false;
bool novoCandleVenda = false;

double aroonBuyValue[];
double aroonSellValue[];
bool novaEntrada = true;

// vetores de controle da média
double mediaAlta[];
double mediaBaixa[];
//indicadores de média móvel
int altaHandle = INVALID_HANDLE;
int baixaHandle = INVALID_HANDLE;

// Biblioteca responsável por compra e venda
CTrade trade;

int OnInit() {

   ind_aroon = iCustom(_Symbol, _Period, "aroon.ex5", periodoAroon, 0);
   
   TimeToStruct(TimeCurrent(), horaAtual);

   Comment("Hora Atual: ", horaAtual.hour, "\nMinuto Atual: ", horaAtual.min);
   
   //+-----INICIO HORA CONTROLE DE OPERAÇÕES --+
   if(horaInicioAbertura > horaFimAbertura || horaFimAbertura > horaInicioFechamento) {
      Alert("Inconsistência de horarios de negociação");
      return(INIT_FAILED);
   }
   if(horaInicioAbertura == horaFimAbertura && minutoInicioAbertura >= minutoFimAbertura) {
      Alert("Inconsistência de horarios de negociação");
      return(INIT_FAILED);
   }
   if(horaFimAbertura == horaInicioFechamento && minutoFimAbertura >= minutoInicioFechamento) {
      Alert("Inconsistência de horarios de negociação");
      return(INIT_FAILED);
   }
  
   if (ind_aroon > 0) {
      ChartIndicatorAdd(0, 0, ind_aroon);
   }
  
   ArraySetAsSeries(mediaAlta,true);
   ArraySetAsSeries(mediaBaixa,true);

   altaHandle = iMA(_Symbol, _Period, periodoAlta, 1, MODE_EMA, PRICE_HIGH);
   baixaHandle = iMA(_Symbol,_Period, periodoBaixa, 1, MODE_EMA, PRICE_LOW);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {

   bool posicionado = false;

   if(HoraNegociacao()) {
       Comment("Dentro do horario de negociação");
   } else {
       Comment("FORA do horario de negociação");
       
      if((posicionado) && (HoraFechamento())) {
         trade.PositionClose(_Symbol); //Fecha todas as operacoes compradas
         Comment("\nFechando todas as posições por horário");
      }
   }
//---
   ArraySetAsSeries(aroonBuyValue, true);
   ArraySetAsSeries(aroonSellValue, true);
   
   // Dados do Aroon
   CopyBuffer(ind_aroon, 0, 0, 3, aroonBuyValue);
   CopyBuffer(ind_aroon, 1, 0, 3, aroonSellValue);
   
   ArraySetAsSeries(mediaAlta, true);
   ArraySetAsSeries(mediaBaixa, true);
   
   // Dados da Média Móvel
   CopyBuffer(altaHandle,  0,0, 3, mediaAlta);
   CopyBuffer(baixaHandle, 0, 0,3, mediaBaixa);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   CopyRates(_Symbol, 0, 0, 100, rates);

   bool comprado = false;
   bool vendido = false;
   
   if(PositionSelect(_Symbol)) {
      if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ) {
         comprado = true;
      }

      if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ) {
         vendido = true;
      }
   }
   
   // COMPRA
   /////////////////////////////////////////////////// Adicionado por Ricardo
   bool cilada = false;
   if ((comprado) && (aroonBuyValue[0] < fechaCompraAroonBuy)) {
      cilada = true;
   }
   if ((comprado) && (aroonSellValue[0] > fechaCompraAroonSell)) {
      cilada = true;
   }
   
   if (cilada){
    trade.PositionClose(_Symbol); //Fecha todas as operacoes compradas
   }
   //////////////////////////////////////////////////////////////////////////////
   
   if (aroonBuyValue[0] <= 90 && !novaEntrada) {
      novaEntrada = true;
   }
   
   if (aroonBuyValue[0] >= 90) {
      if ( !candleRompimentoCompra) {
         candleRompimentoCompra = true;
      }
      
      if (candleRompimentoCompra && isNewBar()) {
         novoCandleCompra = true;
      }
      
      if ((!comprado) && (aroonBuyValue[0] >= 90) && (aroonSellValue[0] <= 90)) { //Alterado por Ricardo
         precoAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if ((novoCandleCompra) && (precoAsk <= (mediaBaixa[0])+toleranciaEntrada) && novaEntrada) {   //alterado por Ricardo.
            
               
            trade.Buy(lote, _Symbol, precoAsk, precoAsk - stop, precoAsk + take,"Compra a mercado"); // Stop e take de compra configurados. Onde configura a venda? Na venda substituir SYMBOL_ASK por SYMBOL_BID.
            comprado = true;
            novaEntrada = false;
         }      
      }
      
   } else {
      candleRompimentoCompra = false;
      novoCandleCompra = false;
   }
   
   
   // VENDA
 //  if (aroonSellValue[0] >= 90) {
  //    if ( !candleRompimentoVenda) {
 //        candleRompimentoVenda = true;
 //     }
      
  //    if (candleRompimentoVenda && isNewBar()) {
//         novoCandleVenda = true;
  //    }
      
   //   if(!vendido) {
   //      if ((novoCandleVenda) && (rates[0].high <= mediaAlta[0])) {
    //        precoBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               
     //       trade.Sell(lote, _Symbol, precoBid, precoBid + stop, precoBid - take,"Venda a mercado"); // Stop e take de compra configurados. Onde configura a venda? Na venda substituir SYMBOL_ASK por SYMBOL_BID.
     //       vendido = true;
     //    }
   //   }
  // } else {
   //   candleRompimentoVenda = false;
  //    novoCandleVenda = false;
   }
   
//}


bool isNewBar() {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_timeS=0;
//--- current time
   datetime lastbar_timeS= (datetime) SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
//--- if it is the first call of the function
   if(last_timeS==0) {
      //--- set the time and exit
      last_timeS=lastbar_timeS;
      return(false);
   }
//--- if the time differs
   if(last_timeS!=lastbar_timeS) {
      //--- memorize the time and return true
      last_timeS=lastbar_timeS;
      return(true);
   }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
}


bool HoraNegociacao() {
   TimeToStruct(TimeCurrent(), horaAtual);
   if(horaAtual.hour >= horaInicioAbertura && horaAtual.hour <= horaFimAbertura) {
      if(horaAtual.hour == horaInicioAbertura) {
         if(horaAtual.min >= minutoInicioAbertura) {
            return true;
         } else {
            return false;
         }
      }
      if (horaAtual.hour == horaFimAbertura) {
         if(horaAtual.min <= minutoFimAbertura) {
            return true;
         } else {
            return false;
         }
      }
      return true;
   }
   return false;
}

bool HoraFechamento() {
   TimeToStruct(TimeCurrent(), horaAtual);
   if(horaAtual.hour >= horaInicioFechamento && horaAtual.min >= minutoInicioFechamento) {
      return true;
   } else {
      return false;
   }
}
