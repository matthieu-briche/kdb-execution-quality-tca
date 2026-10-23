/ tca.q - transaction cost analysis of desk fills against the NBBO
/ Sign convention: sgn = +1 for a buy, -1 for a sell.
/   slipBps > 0  -> we paid more than the mid (cost)
/   edge    > 0  -> we bought below / sold above the mid (cash gained)

\l src/mods.q

\d .tca

/ optional KDB-X selectk module (partial selection for topN), () on plain kdb+
sk:.mods.load`dot.selectk;

/ markout horizons: where did the mid go after the fill?
horizons:`mo1s`mo5s`mo1m`mo5m!0D00:00:01 0D00:00:05 0D00:01:00 0D00:05:00;

/ 1. market context: NBBO prevailing at each fill (as-of join), then cost metrics
context:{[t;q]
  c:aj[`sym`time;t;select sym,time,bid,ask from q];
  c:update mid:0.5*bid+ask,sgn:?[side=`B;1f;-1f],notional:px*qty from c;
  update slipBps:1e4*sgn*(px-mid)%mid,
         edge:sgn*(mid-px)*qty,
         exQuality:?[side=`B;px<=ask;px>=bid]
    from c
  };

/ 2. markout at horizon h: P&L of the fill marked to the mid h later (as-of join on time+h)
markout:{[c;q;h]
  f:aj[`sym`time;select sym,time:time+h from c;select sym,time,fmid:0.5*bid+ask from q];
  c[`sgn]*c[`qty]*f[`fmid]-c`px
  };

/ one markout column per horizon
withMarkouts:{[c;q] c,'flip markout[c;q] each horizons};

/ markout curve in bps of notional, grouped by column g (functional select)
markoutCurve:{[c;g]
  k:key horizons;
  ?[c;();(enlist g)!enlist g;k!{(*;1e4;(%;(sum;x);(sum;`notional)))} each k]
  };

/ 3. scorecard by any column (broker, venue, sym...): cost, best-ex rate, edge, alpha
scorecard:{[c;g]
  ?[c;();(enlist g)!enlist g;`trades`notional`slipBps`bestExRate`edge`mo1m!(
    (count;`i);(sum;`notional);(wavg;`notional;`slipBps);(avg;`exQuality);(sum;`edge);(sum;`mo1m))]
  };

/ 4. intraday buckets of m minutes (xbar)
bars:{[c;m]
  select trades:count i,qty:sum qty,notional:sum notional,edge:sum edge
    by minute:m xbar time.minute from c
  };

/ top or bottom n rows of t by column col, returned in ascending order of col.
/ With the selectk module: partial selection of the n row indices (Floyd-Rivest, O(N)),
/ then a sort of those n rows only. Otherwise: full sort of the column, O(N log N).
/ The module is skipped for column types it does not handle and for columns holding
/ nulls (a float null is NaN, which breaks the comparisons of the selection).
skTypes:4 5 6 7 8 9 10 12 13 14 15 16 17 18 19h;
topN:{[col;dir;n;t] t:0!t; v:t col; n:"j"$n;
  i:$[(count sk)&(n>0)&(type[v] in skTypes)&not any null v;
      sk[$[dir=`top;`ikmax;`ikmin]][n;v];
      n sublist $[dir=`top;idesc;iasc] v];
  col xasc t i};

/ 5. outliers (fby): size vs the symbol's median, slippage z-score within each broker
sizeOutliers:{[c;k] select from c where qty>k*(med;qty) fby sym};
slipOutliers:{[c;z] select from c where z<abs (slipBps-(avg;slipBps) fby broker)%(dev;slipBps) fby broker};

/ 6. correlation of edge with activity across buckets (edge itself -> 1)
edgeCor:{[b] d:exec edge,qty,trades,notional from 0!b; cor[d`edge] each d};

\d .
