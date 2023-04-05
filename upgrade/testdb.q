t:{syms:raze(3?10000)#'3?`4;([]sym:syms;id:count[syms]?0Ng;l1:count[syms]#(1;"12";`a`b);l2:count[syms]#(1 2;"12";`a`b);price:count[syms]?100)}
save_to_partition:{[x;y;z;tabname]y:`$string y;(p:` sv x,y,tabname,`)set 0#data:.Q.en[z;t[]];p upsert data;{x set`p#get x}(` sv p,`sym);{x set`u#get x}(` sv p,`id)}

/ q35 testdb -targetdir TARGETDIR
if[`testdb.q~last` vs hsym .z.f;
    {key[x]set'value x}.Q.def[enlist[`targetdir]!enlist`].Q.opt .z.x;
    if[null targetdir;-2"Must specify the path where the test database is to be created.";exit 1];
    if[count key targetdir:hsym targetdir;-2 string[targetdir]," is not empty.";exit 2];
    dbdir:` sv targetdir,`db;
    / par.txt file
    0:[` sv dbdir,`par.txt;("../1";"../2";"../3")];
    / The small lookup table saved as one file
    (` sv dbdir,`lookup)set([sym:`a`b`c]v:1 2 3);
    / A slayed but not partitioned table
    .z.zd:17 2 9;
    (` sv dbdir,`tickers`)set .Q.en[dbdir;]([]ticker:`A`B`A;time:10:00 11:00 11:00;hype:3 4 7f);
    .z.zd:17 2 6;
    segs:` sv/:targetdir,/:`1`2`3;dtes:.z.d+neg til 2;
    (save_to_partition[;;dbdir;] .)@/:(segs cross dtes)cross`t1`t2;
    exit 0;
   ];
