#include <Trade/Trade.mqh> // biblioteca-padrão CTrade
//+------------------------------------------------------------------+
//|                                                     robo_adx.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
MqlRates rates[];

int hAdx;
double adx[];
double adxMais[];
double adxMenos[];
input int adxPeriod = 2;
input int lote = 2;
input double preco = 100;
input int stop = 100;    // Stop loss
input int take = 50;     // Take profit
double precoAsk = 0;
double precoBid = 0;
bool comprado = false;
bool vendido = false;


//Controle de horário de início/fim
MqlDateTime horaAtual;
input double toleranciaEntrada = -10;
input int horaInicioAbertura = 9;
input int minutoInicioAbertura = 10;
input int horaFimAbertura = 16;
input int minutoFimAbertura = 45;
input int horaInicioFechamento = 17;
input int minutoInicioFechamento  = 30;

// Biblioteca responsável por compra e venda
CTrade trade;


int OnInit() {
//---
   hAdx = iADX(Symbol(), Period(), adxPeriod);
   
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(adxMais, true);
   ArraySetAsSeries(adxMenos, true);
   ArraySetAsSeries(rates, true);
   
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
   
//---
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
//---
   CopyBuffer(hAdx, 0, 0, 3, adx);
   CopyBuffer(hAdx, 1, 0, 3, adxMais);
   CopyBuffer(hAdx, 2, 0, 3, adxMenos);
   CopyRates(Symbol(), Period(), 0, 3, rates);
   
   if(PositionSelect(Symbol())) {
      if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ) {
         comprado = true;
      }

      if( PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL ) {
         vendido = true;
      }
   }
   
   if(HoraNegociacao()) {
   
      if(adxMais[0] > 40) {
         if((adxMenos[0] < 5) && (!comprado)) {
            precoAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            trade.Buy(lote, _Symbol, precoAsk, precoAsk - stop, precoAsk + take,"Compra a mercado");
            comprado = true;
         }
      }

      if((adxMenos[0] > 5) && (comprado)) {
         trade.PositionClose(PositionGetTicket(Symbol()));
         comprado = false;
      }

      if(adxMenos[0] > 40) {
         if ((adxMais[0] < 5) && (!vendido)) {
            precoBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            trade.Sell(lote, _Symbol, precoBid, precoBid + stop, precoBid - take,"Venda a mercado");
            vendido = true;
         }
      }

      if((adxMais[0] > 5) && (vendido)) {
         trade.PositionClose(PositionGetTicket(Symbol()));
         vendido = false;
      }
   }
}
//+------------------------------------------------------------------+

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