/ test.q - unit tests on a hand-checked micro dataset
/ usage, from the repository root:  q tests/test.q

\l src/tca.q

.test.n:0; .test.fail:0;
check:{[name;ok] .test.n+:1; if[not ok;.test.fail+:1]; -1 $[ok;"PASS  ";"FAIL  "],name;};
near:{all 1e-9>abs x-y};

/ three NBBO updates and two fills on one symbol
q:([] sym:`A`A`A;
      time:09:30:00.000000000 09:30:01.000000000 09:30:10.000000000;
      bid:10.00 10.10 10.20; ask:10.02 10.12 10.22);
t:([] tradeId:1 2;
      time:09:30:00.500000000 09:30:05.000000000;
      sym:`A`A; side:`B`S; qty:100 200; px:10.01 10.09;
      broker:`X`Y; venue:`V`V);

c:.tca.context[t;q];
check["aj picks the prevailing quote";c[`bid]~10.00 10.10];
check["mid at fill time";near[c`mid;10.01 10.11]];
check["best-ex flag: buy at mid ok, sell below bid not ok";c[`exQuality]~10b];
check["edge: 0 at mid, -4 when selling 2c under mid";near[c`edge;0 -4f]];
check["slippage is a positive cost for the bad sell";near[c[`slipBps]1;1e4*0.02%10.11]];

m:.tca.markout[c;q;0D00:00:05];
check["5s markout uses the quote as of fill time + 5s";near[m;10 -24f]];

w:.tca.withMarkouts[c;q];
check["one column per horizon";all key[.tca.horizons] in cols w];

b:.tca.bars[w;15];
check["xbar puts both fills in the 09:30 bucket";(1=count b)&2=first exec trades from 0!b];

s:.tca.scorecard[w;`broker];
check["scorecard keyed by broker";`X`Y~exec broker from 0!s];

tt:([] sym:`A`A`A`A`B; qty:100 100 100 5000 100);
check["fby size outlier vs symbol median";5000~exec qty from .tca.sizeOutliers[tt;10]];

tb:([] k:1 2 3 4; v:5 1 9 3);
check["topN returns the top rows in ascending order";5 9~exec v from .tca.topN[`v;`top;2;tb]];
check["topN bottom";1 3~exec v from .tca.topN[`v;`bottom;2;tb]];

ec:.tca.edgeCor ([] edge:1 2 3f; qty:2 4 6; trades:3 2 1; notional:1 2 3f);
check["edge correlates 1 with itself, -1 with a reversed series";near[ec`edge`qty`trades;1 1 -1f]];

-1 "\n",string[.test.n]," tests, ",string[.test.fail]," failed";
exit $[.test.fail;1;0];
