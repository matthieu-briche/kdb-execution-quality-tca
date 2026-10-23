/ report.q - simulate one session, run the full TCA, print it and export CSVs to output/
/ usage, from the repository root:  q src/report.q

system "S 42";                                  / reproducible run
\l src/sim.q
\l src/tca.q

hdr:{-1 "\n=== ",x," ===";};
ms:{string[system "t ",x]," ms"};               / time an expression

/ --- data ----------------------------------------------------------------------
quote:.sim.quotes[];
trade:.sim.trades[quote;10000];
-1 "Simulated ",string[count quote]," NBBO updates and ",string[count trade]," desk fills.";

/ --- enrichment ----------------------------------------------------------------
ctx0:.tca.context[trade;quote];
ctx:.tca.withMarkouts[ctx0;quote];
-1 "aj market context : ",ms ".tca.context[trade;quote]";
-1 "4 markout horizons: ",ms ".tca.withMarkouts[ctx0;quote]";

/ --- analytics -----------------------------------------------------------------
brokerCard:.tca.scorecard[ctx;`broker];
venueCard:.tca.scorecard[ctx;`venue];
brokerMarkouts:.tca.markoutCurve[ctx;`broker];
bars15:.tca.bars[ctx;15];
top5Edge:.tca.topN[`edge;`top;5;bars15];
bottom5Qty:.tca.topN[`qty;`bottom;5;bars15];
edgeCor:.tca.edgeCor bars15;
bigOrders:.tca.sizeOutliers[ctx;10];
slipOut:.tca.slipOutliers[ctx;3];

hdr "Best execution";
-1 "Fills at or inside the NBBO: ",string[floor 0.5+100*avg ctx`exQuality],"%";
-1 "Desk slippage (notional-weighted): ",string[ctx[`notional] wavg ctx`slipBps]," bps";

hdr "Broker scorecard";            show brokerCard;
hdr "Broker markout curve (bps)";  show brokerMarkouts;
hdr "Venue scorecard";             show venueCard;
hdr "Best 15-min buckets by edge"; show top5Edge;
hdr "Quietest 15-min buckets";     show bottom5Qty;
hdr "Correlation with edge";       show edgeCor;
hdr "Size outliers (>10x median)"; show select tradeId,time,sym,side,qty,broker from bigOrders;
hdr "Slippage outliers (|z|>3)";   show count slipOut;

/ --- top-N: full sort vs partial selection -------------------------------------
hdr "Top 10 of 10M values";
v:10000000?1f;
-1 "full sort      10#idesc v           : ",ms "10#idesc v";
-1 "selectk module .tca.sk[`ikmax][10;v]: ",$[count .tca.sk; ms ".tca.sk[`ikmax][10;v]"; "not available (needs KDB-X)"];
delete v from `.;

/ --- export --------------------------------------------------------------------
system "mkdir -p output";
wcsv:{[name;t] (hsym `$"output/",name,".csv") 0: csv 0: 0!t};
wcsv'[("broker_scorecard";"broker_markouts";"venue_scorecard";"bars_15min";"size_outliers");
      (brokerCard;brokerMarkouts;venueCard;bars15;bigOrders)];
-1 "\nCSV files written to output/. Tables stay in memory: try  show 5#ctx";
