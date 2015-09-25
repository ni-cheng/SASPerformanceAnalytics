/*---------------------------------------------------------------
* NAME: Adjusted_SharpeRatio.sas
*
* PURPOSE: Adjusts the Sharpe Ratio for skewness and kurtosis by incorporating a penalty factor 
*		   for negative skewness and excess kurtosis. 
*
* MACRO OPTIONS:
* returns - required.  Data Set containing returns.
* method- {GEOMETRIC, ARITHMETIC}. Specifies calculating returns using geometric or arithmetic chaining.
* Rf- the value or variable representing the risk free rate of return.
* scale - required.  Number of periods per year used in the calculation.
* dateColumn - Date column in Data Set. Default=DATE
* outAdjSharpe - output Data Set with adjusted Sharpe Ratios.  Default="adjusted_SharpeRatio". 
*
* MODIFIED:
* 7/22/2015 � CJ - Initial Creation
* 9/17/2015 - CJ - Replaced temporary variable and data set names with random names.
*				   Defined all local variables.
*				   Replaced Proc SQL statement with %get_number_column_names().
*				   Renamed column statistic "_STAT_" to be consistent with SAS results.
*				   Replaced code returning geometric chained returns with %return_annualized
*				   Inserted parameter method= to allow user to choose arithmetic or geometricaly chained returns.
*
* Copyright (c) 2015 by The Financial Risk Group, Cary, NC, USA.
*-------------------------------------------------------------*/

%macro Adjusted_SharpeRatio(returns,
								method= GEOMETRIC, 
								Rf=0, 
								scale= 1,
								dateColumn= DATE, 
								outAdjSharpe= adjusted_SharpeRatio);


%local ret nv i j k Skew_Kurt_Table Chained_Ex_Ret Ann_StD SR;
/*Find all variable names excluding the date column and risk free variable*/
%let ret= %get_number_column_names(_table= &returns, _exclude= &dateColumn &Rf);
%put RET IN Adjusted_SharpeRatio: (&ret);
/*Find number of columns in the data set*/
%let nv = %sysfunc(countw(&ret));
/*Define counters for array operations*/
%let i= %ranname();
%let j= %ranname();
%let k= %ranname();
/*Define temporary data set names with random names*/
%let Skew_Kurt_Table= %ranname();
%let Chained_Ex_Ret= %ranname();
%let Ann_StD= %ranname();
%let SR= %ranname();

proc transpose data=&returns out=&Skew_Kurt_Table;
by &dateColumn;
var &ret;
run;

proc sort data=&Skew_Kurt_Table;
by _name_;
run;

proc univariate data=&Skew_Kurt_Table noprint vardef=N;
var COL1;
by _NAME_;
output out=&Skew_Kurt_Table
	SKEW=Skewness
	KURT=Kurtosis;
run;

proc transpose data=&Skew_Kurt_Table out=&Skew_Kurt_Table(drop=_label_ rename=(_name_=_stat_));
id _name_;
run;

data &Skew_Kurt_Table(drop=&i so);
format _stat_ $32. &ret;
set &Skew_Kurt_Table;
array vars[*] &ret;
so = 10 + _n_;
if _stat_ = "Kurtosis" then do;
	do &i=1 to dim(vars);
		vars[&i] = vars[&i] + 3;
	end;	
	output;
	so = so + 1;
	_stat_ = Excess_kurtosis;
	do &i=1 to dim(vars);
		vars[&i] = vars[&i] - 3;
	end;	
end;
output;
run;

proc transpose data= &Skew_Kurt_Table out= &Skew_Kurt_Table;
id _stat_;
run;

data &Skew_Kurt_Table;
set &Skew_Kurt_Table;
adjSkew= Skewness/6;
adjKurt= (Kurtosis-3)/24;
drop Skewness Excess_kurtosis Kurtosis;
run;

proc transpose data= &Skew_Kurt_Table out= &Skew_Kurt_Table;
id _name_;
run;

/*proc sql noprint;*/
/*select name*/
/*into :ret separated by ' '*/
/*     from sashelp.vcolumn*/
/*where libname = upcase("&lib")*/
/* and memname = upcase("&ds")*/
/* and type = "num"*/
/* and upcase(name) ^= upcase("&dateColumn")*/
/*and upcase(name) ^= upcase("&Rf");*/
/*quit;*/

/*data &af(drop=&ae) &ag(drop=&ae);*/
/*set &returns end=last nobs=nobs;*/
/**/
/*array ret[&nv] &ret1;*/
/*array prod[&nv] _temporary_;*/
/**/
/*if _n_ = 1 then do;*/
/*	do &j=1 to &nv;*/
/*		prod[&j] = 1;*/
/**/
/*	end;*/
/*	delete;*/
/*end;*/
/**/
/*do &j=1 to &nv;*/
/*	prod[&j] = prod[&j] * (1+(ret[&j]/100))**(&scale);*/
/*end;*/
/*output &af;*/
/**/
/*if last then do;*/
/*	do &j=1 to &nv;*/
/**/
/*		ret[&j] =100*((prod[&j])**(1/(nobs-1)) - 1);*/
/*	end;*/
/*	output &Chained_Ex_Ret;*/
/*end;*/
/*run;*/
%return_annualized(&returns, scale= &scale, method= &method, outReturnAnnualized= &Chained_Ex_Ret);
%return_excess(&Chained_Ex_Ret, Rf= &Rf, dateColumn= &dateColumn, outReturn= &Chained_Ex_Ret);

%Standard_Deviation(&returns, 
							annualized= TRUE, 
							scale= &scale,
							dateColumn= &dateColumn,
							outStdDev= &Ann_StD);

data &SR (drop= &j);
set &Chained_Ex_Ret &Ann_StD (in=s);
drop Date;
array minRf[&nv] &ret;

do &j=1 to &nv;
	minRf[&j] = lag(minRf[&j])/minRf[&j];
end;

if s;
run;

quit;


data &outAdjSharpe(drop= &k rename= (_name_= _STAT_));
keep &ret;
format _NAME_ $char16.;
set &Skew_Kurt_Table &SR;
array vars[*] &ret;
do &k= 1 to &nv;
vars[&k]= vars[&k]*(1+((lag2(vars[&k]))*vars[&k])-((lag(vars[&k]))*(vars[&k]**2)));
end;

if _NAME_= 'adjSkew' then delete;
if _NAME_= 'adjKurt' then delete;
_NAME_= '_Adj_SharpeRatio';
run;

proc datasets lib=work nolist;
delete &Skew_Kurt_Table &SR &Ann_StD &Chained_Ex_Ret;
run;
quit;

%mend;
