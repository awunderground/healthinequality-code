* Set $root
return clear
capture project, doinfo
if (_rc==0 & !mi(r(pname))) global root `r(pdir)'  // using -project-
else {  // running directly
	if ("${mortality_root}"=="") do `"`c(sysdir_personal)'profile.do"'
	do "${mortality_root}/code/set_environment.do"
}

* Check for Julia configuration
project, original("${root}/code/set_julia.do")
confirm file "${root}/code/set_julia.do"

* Create required folders
cap mkdir "${root}/scratch/tests"
cap mkdir "${root}/scratch/tests/Julia Gompertz matches Stata Gompertz"

* Add ado files to project
project, original("${root}/code/ado/estimate_gompertz2.ado")
project, original("${root}/code/ado/mle_gomp_est.ado")
project, original("${root}/code/ado/fastregby_gompMLE_julia.ado")
project, original("${root}/code/ado/estimate_gompertz.jl")

/*** Test whether Gompertz estimates generated by Julia
	 match those generated in Stata.
***/


********************************************************************
**************  National Life Expectancy Estimates *****************
********************************************************************

*******
*** National, by Gender x Income Percentile
*******

* Load mortality rates
project, original("${root}/data/derived/Mortality Rates/mskd_national_mortratesBY_gnd_hhincpctile_age_year.dta")
use "${root}/data/derived/Mortality Rates/mskd_national_mortratesBY_gnd_hhincpctile_age_year.dta", clear
keep if age_at_d >= 40

* Calculate Gompertz parameters from mortality rates
foreach prog in Stata Julia {

	if ("`prog'"=="Stata") global juliapath ""
	else include "${root}/code/set_julia.do"

	foreach vce in oim "" {

		preserve

		estimate_gompertz2 gnd pctile, gnd(gnd) age(age_at_d) mort(mortrate) n(count) ///
			collapsefrom(gnd pctile age_at_d yod) type(mle) vce(`vce')

		save "${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - `prog' `vce'.dta", replace
		project, creates("${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - `prog' `vce'.dta")

		restore

	}

}


*** Perform comparisons

cap program drop compare_gompest
program define compare_gompest

	syntax, [vce_julia(name) vce_stata(name) acceptedreldif(string)]

	project, uses("${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - Julia `vce_julia'.dta")
	project, uses("${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - Stata `vce_stata'.dta")

	use "${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - Julia `vce_julia'.dta", clear

	rename gomp* Jgomp*
	rename A* JA*

	merge 1:1 gnd pctile using "${root}/scratch/tests/Julia Gompertz matches Stata Gompertz/national_gompBY_gnd_hhincpctile - Stata `vce_stata'.dta", ///
		assert(3) nogen

	foreach var of varlist gomp* A* {
		gen diff_`var' = reldif(J`var', `var')
		if ("`acceptedreldif'"!="") assert diff_`var'<`acceptedreldif'
	}
	sum diff*
	drop diff*

end

compare_gompest, vce_julia("") vce_stata("") acceptedreldif(1e-5)
compare_gompest, vce_julia("oim") vce_stata("oim") acceptedreldif(1e-5)
