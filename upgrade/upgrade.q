logger:`info`warning`error!({x enrichLogMsg[.z.z;y;z]} .)@/:((-1;"INFO");(-1;"WARNING");(-2;"ERROR"));
/ x - UTC datetime
/ y - logging level string: "INFO", "WARNING", "ERROR"
/ z - log message string
enrichLogMsg:{string[x]," ",y," ",z}

/// The entry point
/ x - the parameter dictionary
/ `dbdir - the database path
/ `logdir - dir for writing the log, also the location where the summary output table is
/ `targever - the target kdb+ major version number
/ `runflag - 0b: estimate only, do not write files; 1b: estimate and write files
/ `reuse - 0b: reuse existing upgraded files; 1b: overwrite existing upgraded files
/ `bd - begin date
/ `ed - end date
run:{[x]
    if[.z.K<>x`targetver;logger.error["The currently running KDB+ version ",.Q.f[1;.z.K]," does not match the target KDB+ version ",.Q.f[1;x`targetver],". Abort run."];:(::)];
    logger.info"The target KDB+ version for the upgrade is ",.Q.f[1;.z.K];
    / Call examineDb on the database path x to compile a list of action items, i.e., tables and columns to be upgraded.
    r:examineDb . x`dbdir`bd`ed;
    if[r~0b;:(::)];
    / The path to the summary output table.
    / N.B. this table preserve a record for changes made to the database, which is useful for rollback or resuming a partial change.
    o:` sv x[`logdir],`output;
    / If an output summary table exists, load it, and exclude the already upgraded tables and columns from the action list.
    if[o~key o;
       o1:select tabPath,c from o where processTime=(max;processTime)fby([]tabPath;c),not rolledback;
       r:{[x;y]select from x where not([]tabPath;c)in y}[;o1]each r;
       r:r where 0<count each r];
    if[not count r;logger.info"Nothing to do. Exiting..."];
    / Call the function estimate on the action list r and log the estimate.
    e:estimate r;logger.info"The estimated time is ",string[e 0]," across ",string[count r]," tables totaling ",string[e 1]," columns running a single-threaded process.";
    / If the flag is false, exit.
    if[not x`runflag;:(::)];
    / Go through the action list r by calling runForTab. Upsert the result into the summary output table upon success. Log the error if there is any.
    {r:@[runForTab[;z];y;{logger[`error;x];0b}];
     if[not r~0b;x upsert update rolledback:0b,cleanedup:0b,processTime:.z.p from select from r where impacted]
    }[o;;x`reuse]each r;
    logger.info"The result summary table is saved at ",1_string o;
    logger.info"The total database size increase, compared to the original, is ",string[countSizeIncrease o]," bytes"
 };

/ x - path to the summary outpout table
countSizeIncrease:{
    newFilesPaths:` sv/:(,'/)each flip value flip ungroup
                  ?[select from x where processTime=(max;processTime)fby([]tabPath;c);
                    ();0b;{x!x}`tabPath,`$"v",string[10*.z.K],"Files"];
    sum{last hcount[x],(-21!x)`compressedLength}each newFilesPaths
 };

/// Functions to examine the database to identify tables and columns that might need to be rewritten, and give a rough estimate of elapse
/ x - database path
/ y - begin date
/ z - end date
examineDb:{
    / Mount the database
    system"l ",1_string hsym x;
    / Limit the view
    dates:date where date within(^)[(min;max)@\:date;y,z];
    if[not count dates;logger.error"The specified date range is empty. Abort run.";:0b];
    .Q.view dates;
    logger.info"Started examining the database '",string[x],"' for dates within (",(";"sv string(min;max)@\:dates),")...";
    / Find partitioned and splayed tables
    tabs:tabs inds:where any each 01b~\:/:v:value each ".Q.qp ",/:string tabs:tables[];
    / Identify enum, guid, and compound columns
    r:findPotentialCols'[tabs;v inds];
    logger.info"Found the following tables and columns that may need an upgrade:\n",.Q.s r;
    buildTabPaths[;buildPartitionPaths x;x]each r
    }

/ x - tab symbol name
/ y - isPartitioned
/ z - database path
findPotentialCols:{(`tab`isPartitioned!(x;y)),exec c:c from meta x where(t in "sg")or(t in .Q.A)or null t,c<>.Q.pf}

/ x - databasepath
buildPartitionPaths:{`$(ssr[;"//";"/"]/)each string` sv/:({` sv $[":.."~3#x:string x;(-1_` vs y),`$3_x;":./"~3#x;y,`$3_x;`$x]}[;x]each .Q.pd),'`$string .Q.pv};

/ x - output from findPotentialCols
/ y - partition paths
/ z - database path
/ Build the table paths: use partition paths if it is a partitioned table; build the path directly if it is not a partitioned table, i.e., a splayed table.
buildTabPaths:{update tab:x`tab from`tabPath`c!/:$[x`isPartitioned;` sv/:y,\:x`tab;enlist` sv(z;x`tab)]cross x`c}

/ x - output from examineDb
/ Assume on average every column takes 0.01 second
estimate:{t:`timespan$1e9*0.01*c:sum count each x;:(t;c)}

/// Functions to examine each column identified from the above functions
/ x - output from buildTabPaths
/ y - reuse
runForTab:{
    logger.info"Started processing table '",string[x[0]`tab],"'...";
    / For each table path in paths, go through the identitfied columns to double check if it needs to be upgraded. Upgrade if so, i.e., impacted=1b.
    / Mask target ver files, and preserve original files by adding the "$" suffix, and then create a symlink pointing to the target ver files.
    (('[;]/)(symlinkCol;preserve;maskNewVerColFiles))each('[writeNewVerCol[;y];(examineCol .)@])peach exec(tabPath,'c)from x};

/ x - path to the splayed table
/ y - column name
examineCol:{
    / Load the column file.
    v:get` sv x,y;
    / Get the attribute
    a:attr v;
    / double-check if it needs to be upgraded
    r:$[(t within 21 76)|not t:type v;1b;(t=2)&a in`u`p`g;1b;0b];
    / Return a dictionary of the tablePath, column name c, type, type, attribute, impacted(1b - upgrade; 0b - do not upgrade), data(empty if not impacted), and the associated file paths.
    / N.B. if the column is a compound list, it might have more than one file.
    :`tabPath`c`typ`att`impacted`data`files!(x;y;t;a;r;$[r;v;()];$[r;findAssociatedFiles[x;y];`$()])}

/ x - path to the splayed table
/ y - column name
/ The max possible number of files for a column: 3 for ver>=3.6; 2 otherwise
findAssociatedFiles:{masked:"$"=last y:string y;k where any(k:key x)like/:(neg[masked]_y),/:(til[$[.z.K>=3.6;3;2]]#\:"#"),\:masked#"$"}


/// Functions to write the column using the KDB+ of the target version
/ x - output from examineCol
/ y - reuse
writeNewVerCol:{
    / If it is an unimpacted column, return x with conforming keys.
    ver:"v",string 10*.z.K;
    if[not x`impacted;x[(`$ver,"Files"),`symlink]:(`$();enlist"");:`data _ x];
    / The path to the column file of the target version, suffixed with ver.
    c:`$cstring:string[corig:` sv x`tabPath`c],ver;cmasked:`$cstring,"$";
    alreadyMasked:cmasked~key cmasked;
    / If either the unmask or the masked upgraded col file already exists, log a warning and return x with conforming keys, else write the column.
    logmsg:$[(c~key c)or alreadyMasked;
             $[y;
               (`warning;"'",cstring,"' already exists. Skip writing");
               (`warning;"'",cstring,"' already exists. Overwriting")
              ];
             [if[count cc:-21!corig;
                 c:c,cc`logicalBlockSize`algorithm`zipLevel];
              c set x`data;(`info;"Saved '",cstring,"'")]];
    / At last return the log message, the alreadyMasked boolean, and x with conforming keys.
    (logmsg;alreadyMasked;`data _ x)}

/ x - output from writeNewVerCol
maskNewVerColFiles:{
    / Write the log message from writeNewVerCol
    logger . x 0;
    alreadyMasked:x 1;
    x:x 2;
    / Find associated column files. N.B. if the column is a compound list, it might have more than one file.
    r:findAssociatedFiles[x`tabPath;`$string[x`c],"v",string[10*.z.K],alreadyMasked#"$"];
    / Insert the new file paths into x
    x[`$"v",string[10*.z.K],"Files"]:last each` vs/:(maskFile;::)[alreadyMasked]each` sv/:x[`tabPath],/:r;
    x
 }

/ x - file path
maskFile:{logger.info"Masked file: ",last system"mv -v ",s," ",r:(s:1_string x),"$";:hsym`$r}

/ x - output from examineCol
preserve:{
    / Add the "$" suffix to the original files
    x[`files]:$[x`impacted;
                [logger.info"Preserving '",(","sv string x`files),"' under '",string[x`tabPath],"'...";
                 last each` vs/:maskFile each` sv/:x[`tabPath],/:x`files];
                 `$()];
    x}

/ x - output from examineCol
/ Create symlinks pointing to the target ver files.
symlinkCol:{x[`symlink]:$[x`impacted;createSymlink[;x`tabPath;x`c] each x`$"v",(string 10*.z.K),"Files";enlist""];x}

/ x - masked file
/ y - tab path
/ z - column name
createSymlink:{target:"./",string x;link:ssr[;string[z],"v",string 10*.z.K;string z]1_-1_string` sv y,x;logger.info"Created the symlink: ",r:last system"ln -sfnv ",target," ",link;r}


/// Functions to check if the new data match the old data in values, attributes, and compression stats
/ x - the path to the result table from run
matchCheck:{update match:{p:` sv value x;r:(all/)(old:get pold:`$string[p],"$")=new:get p;r:r and(~/)attr@/:(old;new);:r and(~/){(-21!x)`logicalBlockSize`algorithm`zipLevel}each(pold;p)}each([]tabPath;c)from get x where impacted}


/// To roll back
/ Read in the summary output table from an upgrade, remove the symlinks according to it, and unmask the original files, i.e., remove the "$" suffix.
/ x - the path to the summary output table from an upgrade
rollback:{
    toRollback:select from x where processTime=(max;processTime)fby([]tabPath;c),not rolledback,not cleanedup;
    if[not count toRollback;logger.info"No upgrade to roll back.";:(::)];
    logger.info"Started rolling back...";
    r:{@[{removeSymlink each x`symlink;unmaskFile each` sv/:x[`tabPath],/:x`files;@[x;`rolledback;:;1b]};x;{logger[`error;x];y}[;x]]}each toRollback;
    x upsert update processTime:.z.p from r;
    logger.info 1_string[x]," is updated";}
removeSymlink:{hdel hsym`$-1_1_first " -> "vs x;logger.info"Symlink ",x," is removed"}
unmaskFile:{masked:1_string x;logger.info"Unmasked file: ",last system"mv -v ",masked," ",-1_masked}


/// To clean up
/ Remove the symlinks, remove the original files, and rename the upgrade files.
/ N.B. this function should only be called AFTER an upgrade is fully vetted and accepted by the users of the database. THERE IS NO GOING BACK AFTER THIS FUNCTION IS RUN.
/ x - the path to the summary output table from an upgrade
cleanUpAfterUpgrade:{
    toCleanUp:select from x where processTime=(max;processTime)fby([]tabPath;c),not rolledback,not cleanedup;
    if[not count toCleanUp;logger.info"No upgrade to clean up.";:(::)];
    logger.info"Started cleaning up after the upgrade...";
    r:{@[{hdel each` sv/:x[`tabPath],/:x`files;normalizeUpgradedFile[;x`tabPath]each x`symlink;@[x;`cleanedup;:;1b]};x;{logger[`error;x];y}[;x]]}each toCleanUp;
    x upsert update processTime:.z.p from r;
    logger.info 1_string[x]," is updated";}
normalizeUpgradedFile:{x:-1_/:1_/:" -> "vs x;logger.info last system"mv -v ",(1_string ` sv y,`$x 1)," ",x 0}

/ Remove the upgraded files
cleanUpAfterRollback:{
    toCleanUp:select from x where processTime=(max;processTime)fby([]tabPath;c),rolledback,not cleanedup;
    if[not count toCleanUp;logger.info"No rollback to clean up.";:(::)];
    logger.info"Started cleaning up after the rollback...";
    r:{@[{removeUpgradedFile[;x`tabPath]each x`symlink;@[x;`cleanedup;:;1b]};x;{logger[`error;x];y}[;x]]}each toCleanUp;
    x upsert update processTime:.z.p from r;
    logger.info 1_string[x]," is updated";}
removeUpgradedFile:{hdel x:` sv y,`$-1_1_last " -> "vs x;logger.info"The upgraded file ",(1_string x)," is removed"}


/// Run the script from command line
/ "q upgrade -dbdir DBDIR -logdir LOGDIR" for an estimate only
/ "q upgrade -dbdir DBDIR -logdir LOGDIR -runflag 1" for the actual run
/ Use "-targerver VERSION" to specify the version of KDB+, to which the files are to be upgraded. The default is 4.0.
/ Use "-reuse 0" to overwrite any existing upgraded files. The default is 1 - reuse rather than overwriting.
/ Use "-bd BEGINDATE" to specify the begin date. The default is null, which will be filled by the database's min date.
/ Use "-ed ENDDATE" to specify the end date. The default is null, which will be filled by the database's max date.
if[`upgrade.q~last` vs hsym .z.f;
   args:.Q.def[`dbdir`logdir`targetver`reuse`runflag`bd`ed!``,4.0,10b,2#0Nd].Q.opt .z.x;
   if[any null args`dbdir`logdir;-2"Must specify the database directiory as dbdir and the log directory as logdir.";exit 1];
   system@/:("1 ";"2 "),\:string[args`logdir],"/upgrade_",ssr[string .z.z;":";"_"],".log";
   @[run;@[args;`dbdir`logdir;hsym];logger.error];exit 0
  ];