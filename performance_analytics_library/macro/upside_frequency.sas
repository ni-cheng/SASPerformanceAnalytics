/*---------------------------------------------------------------
* NAME: upside_frequency.sas
*
* PURPOSE: Calculate upside frequency of retuns
*
* NOTES: Divide the length of subset of returns which are more than the target(MAR) by the total
*        number of returns
*
* MACRO OPTIONS:
* returns - Required. Data Set containing returns.
* MAR - Optional. Minimum Acceptable Return. Default=0
* dateColumn - Optional. Date column in Data Set. Default=DATE
* outData - Optional. output Data Set with upside frequency.  Default="UpsideFrequency"
*
* MODIFIED:
* 6/09/2016 � QY - Initial Creation
*
* Copyright (c) 2015 by The Financial Risk Group, Cary, NC, USA.
*-------------------------------------------------------------*/

%macro upside_frequency(returns, 
							MAR= 0, 
							dateColumn= DATE, 
							outData= UpsideFrequency);

%local n_full n_subset temp vars i;
%let n_full= %ranname();
%let n_subset= %ranname();
%let temp= %ranname();

%let vars= %get_number_column_names(_table= &returns, _exclude= &dateColumn &MAR);
%put VARS IN upside_frequency: (&vars);

%let i= %ranname();

data &temp(drop=&i &dateColumn);
	set &returns(firstobs=2);
	array ret[*] &vars;

	do &i= 1 to dim(ret);
		if ret[&i]<=&MAR then ret[&i]=.; 
	end;
run;


proc means data=&returns n noprint;
	output out=&n_full n=;
run;

proc means data=&temp n noprint;
	output out=&n_subset n=;
run;


data &outData(keep=_stat_ &vars);
	set &n_subset &n_full;
	array ret[*] &vars;

	do &i= 1 to dim(ret);
		ret[&i]=lag(ret[&i])/ret[&i];
	end;
run;

data &outData;
	format _STAT_ $32.;
	set &outData end=last;
	_STAT_= "Upside Frequency";
	if last;
run;

proc datasets lib= work nolist;
delete &n_full &n_subset &temp
run;
quit;							
%mend;
