/ sim.q - one simulated US equity session: NBBO quote stream + an execution desk's fills
/ Everything is synthetic and reproducible (seed set by the caller with \S).

\d .sim

syms:`AAPL`MSFT`NVDA`JPM`XOM;
px0:190 415 120 200 110f;                 / opening mid price
vol:0.25 0.22 0.45 0.20 0.28;             / annualised volatility
sbps:1.5 1.2 2.5 2.0 2.2;                 / typical quoted spread, bps
nq:40000 30000 60000 15000 12000;         / NBBO updates per symbol

t0:09:30:00.000000000;
t1:16:00:00.000000000;
yearNs:1e9*252*6.5*3600;                  / trading year in nanoseconds

/ execution routes: brokers and venues (MIC codes), with a built-in cost profile
brokers:`BRK_A`BRK_B`BRK_C`BRK_D`BRK_E;
brokerBias:0.0 0.3 -0.2 0.6 1.8;          / extra cost vs mid, bps
venues:`XNAS`XNYS`ARCX`BATS;
venueBias:0.0 0.1 0.2 -0.1;
impact:0.2;                               / extra bps per 1,000 shares

/ standard normal draws (Box-Muller)
nrm:{sqrt[-2*log 1-x?1f]*cos 2*acos[-1]*x?1f};

/ one symbol: geometric Brownian mid sampled at random times, spread around it
genQuotes:{[s;p0;v;sb;n]
  t:t0+asc n?"j"$t1-t0;
  dt:(deltas "j"$t-t0)%yearNs;
  mid:p0*exp sums (v*sqrt dt)*nrm[n]-0.5*v*sqrt dt;
  half:0.5*mid*sb*1e-4*1+n?2f;
  ([] sym:n#s; time:t;
      bid:0.01*floor 100*mid-half;
      ask:0.01*ceiling 100*mid+half;
      bsize:100*1+n?20; asize:100*1+n?20)
  };

/ full NBBO table, sorted by sym then time, parted on sym (what aj expects)
quotes:{update `p#sym from `sym`time xasc raze genQuotes'[syms;px0;vol;sbps;nq]};

/ desk fills priced off the prevailing mid:
/   cost (bps) = broker bias + venue bias + size impact + noise
/ BRK_C is "informed": 65% of its orders trade in the direction of the next minute's move,
/ so it is cheap at arrival AND earns positive markouts.
/ About 0.4% of orders get a fat-finger quantity (x25), for the outlier screens to find.
trades:{[q;n]
  t:([] time:t0+asc n?"j"$t1-t0; sym:n?syms; broker:n?brokers; venue:n?venues);
  qty:@[100*1+n?50;where 0.004>n?1f;*;25];
  m0:aj[`sym`time;t;select sym,time,mid:0.5*bid+ask from q];
  m1:aj[`sym`time;select sym,time:time+0D00:01:00 from t;select sym,time,fut:0.5*bid+ask from q];
  informed:(t[`broker]=`BRK_C)&0.65>n?1f;
  side:?[informed;?[m1[`fut]>m0`mid;`B;`S];n?`B`S];
  sgn:?[side=`B;1f;-1f];
  cost:brokerBias[brokers?t`broker]+venueBias[venues?t`venue]+(impact*qty%1000)+nrm n;
  px:0.0001*floor 0.5+1e4*m0[`mid]*1+sgn*cost*1e-4;
  ([] tradeId:1+til n; time:t`time; sym:t`sym; side; qty; px; broker:t`broker; venue:t`venue)
  };

\d .
