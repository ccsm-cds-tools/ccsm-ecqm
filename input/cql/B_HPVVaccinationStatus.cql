library B_HPVVaccinationStatus version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include HospiceQICore4 version '2.0.000' called Hospice
//include PalliativeCareFHIR version '0.6.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include TopLevelScreeningLibrary version '1.0.0' called Entry
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash

codesystem "ObservationCategoryCodes": 'http://terminology.hl7.org/CodeSystem/observation-category'

valueset "Congenital or Acquired Absence of Cervix": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.111.12.1016'
valueset "Home Healthcare Services": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1016'
valueset "HPV Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.110.12.1059'
valueset "Hysterectomy with No Residual Cervix": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.12.1014'
valueset "Office Visit": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1001'
valueset "Online Assessments": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1089'
valueset "Pap Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.108.12.1017'
valueset "Preventive Care Services - Established Office Visit, 18 and Up": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1025'
valueset "Preventive Care Services-Initial Office Visit, 18 and Up": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1023'
valueset "Telephone Visits": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1080'

valueset "HPV Vaccines": 'http://cts.nlm.nih.gov/fhir/ValueSet/Vaccines' //placeholder for HPV Vaccine codes

code "laboratory": 'laboratory' from "ObservationCategoryCodes" display 'Laboratory'

parameter "Measurement Period" Interval<DateTime>
  default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

/*define "SDE Ethnicity":
  SDE."SDE Ethnicity"
define "SDE Payer":
  SDE."SDE Payer"
define "SDE Race":
  SDE."SDE Race"
define "SDE Sex":
  SDE."SDE Sex"*/

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[21, 45 + year from start of "Measurement Period" - 2019) //year from today() instead?
  and Entry.FemaleorTransgenderMale
  and exists "Qualifying Encounters"

define "Denominator 1":
  (Count("Two Vaccine Regimen") = 2
    and "Two Vaccine Regimen"[1].occurrence >= "Two Vaccine Regimen"[0].occurrence + 146 days)
  or
  (Count("Three Vaccine Regimen") = 3
    and "Dates Not Equal"("Three Vaccine Regimen"))

define function "Dates Not Equal"(immunizations List<FHIR.Immunization>): //Possibly could upgrade to use the aggregate CQL expression; this assumes 3 immunizations
  immunizations[0].occurrence as dateTime != immunizations[1].occurrence as dateTime
  and immunizations[1].occurrence as dateTime != immunizations[2].occurrence as dateTime
  and immunizations[2].occurrence as dateTime != immunizations[0].occurrence as dateTime

define "Two Vaccine Regimen":
  [Immunization: "HPV Vaccines"] Vaccines
  where Vaccines.occurrence.value in Interval[Patient.birthDate + 9 years, Patient.birthDate + 15 years + 146 days] //in base FHIR, occurrence[x] is datetime or string. Need to ensure it is a dateTime. For some reason adding ".value" here keeps 5 other errors away
  sort by (occurrence as dateTime)

define "Three Vaccine Regimen":
  [Immunization: "HPV Vaccines"] Vaccines
  where Vaccines.occurrence in Interval[Patient.birthDate + 15 years, Patient.birthDate + 45 years] //in base FHIR, occurrence[x] is datetime or string. Need to ensure it is a dateTime

define "Denominator 2":
  exists "Screening Tests in Last 10 Years"
  and not exists [Immunization: "HPV Vaccines"]

define "Screening Tests in Last 10 Years":
  (ManagementLibrary.SortedHpvReports union ManagementLibrary.SortedCytologyReports) ScreeningTests
    where ScreeningTests.date in Interval[start of "Measurement Period" - 10 years, end of "Measurement Period"]

define "Numerator 1":
  //(ManagementLibrary.HighGradePreCancerCervicalLesionDate is not null //Change to Dash.CervicalPrecancerDisorders, because as is it is only the most recent
  //or ManagementLibrary.CervicalCancerDiagnosisDate is not null
  //or ManagementLibrary.HasRecentAbnormalScreening) //This calls Dash.HasRecentAbnormalScreening, which is "HasRecentPositiveHpv or HasRecentAbnormalCytologyResults"
  //and
  (ManagementLibrary.HighGradePreCancerCervicalLesionDate.date > "Last HrHPV Immunization Date"
  or ManagementLibrary.CervicalCancerDiagnosisDate.date > "Last HrHPV Immunization Date"
  or AnyTrue((ManagementLibrary.SortedBiopsyReports D where D.riskTableInput in {'CIN1','CIN2','CIN3','AIS','Cancer'} return D sort by date) X return X.date > "Last HrHPV Immunization Date")
  or AnyTrue((ManagementLibrary.SortedHpvReports D where D.riskTableInput in {'HPV-positive','HPV16-, HPV18+','HPV16+'} return D sort by date) X return X.date > "Last HrHPV Immunization Date") // HpvDiagnosticReports isn't sorted, so here it uses a quick and dirty sort; it also is limited by a cutoff date, currently 10 years; should it be any after some cutoff
  or Last(Dash.RecentAbnormalCytologyResults D return D sort by effective).effective > "Last HrHPV Immunization Date")// RecentAbnormalCytologyResults isn't sorted, so here it uses a quick and dirty sort; it also is limited by a cutoff date, currently 8 years; or should it be any after some cutoff

define "Sorted HrHPV Immunizations":
  [Immunization: "HPV Vaccines"] Vaccines
  where Vaccines.occurrence in Interval[Patient.birthDate + 9 years, Patient.birthDate + 45 years]
  return Vaccines sort by (occurrence as dateTime)

define "Last HrHPV Immunization Date":
  Last("Sorted HrHPV Immunizations").occurrence//.value as DateTime

define "Numerator 2":
  ManagementLibrary.HighGradePreCancerCervicalLesionDate is not null //Change to Dash.CervicalPrecancerDisorders, because as is it is only the most recent
  or ManagementLibrary.CervicalCancerDiagnosisDate is not null //Same
  or exists Dash.RecentAbnormalCytologyResults
  or exists ManagementLibrary.SortedBiopsyReports D where D.riskTableInput in {'CIN1','CIN2','CIN3','AIS','Cancer'}//can combine with Numerator 1 clause in separate definition
  or exists ManagementLibrary.SortedHpvReports D where D.riskTableInput in {'HPV-positive','HPV16-, HPV18+','HPV16+'} //can combine with Numerator 1 clause in separate definition

define "Stratification 1":
  "Sorted HrHPV Immunizations"[0].occurrence in Interval[Patient.birthDate + 9 years, Patient.birthDate + 13 years)

define "Stratification 2":
  "Sorted HrHPV Immunizations"[0].occurrence in Interval[Patient.birthDate + 13 years, Patient.birthDate + 27 years)

define "Stratification 3":
  "Sorted HrHPV Immunizations"[0].occurrence in Interval[Patient.birthDate + 27 years, Patient.birthDate + 45 years]

//define "Denominator Exclusions": This is commented out becuase the single clause below isn't ready to be un-commented, and this can't be an otherwise empty definition
  //"Anaphylactic Reaction Due to Vaccination" //Value set not created; spreadsheet says "except patients with pregnancy and acute illness"; review column D for more thoughts

define "Absence of Cervix":
  (
    QICore.ProcedureCompleted NoCervixProcedure
      where NoCervixProcedure.code in "Hysterectomy with No Residual Cervix"
        and NoCervixProcedure.performed.toInterval() ends on or before end of "Measurement Period"
  )
    union (
      QICore.Condition NoCervixDiagnosis
        where NoCervixDiagnosis.code in "Congenital or Acquired Absence of Cervix"
          and NoCervixDiagnosis.prevalenceInterval() starts on or before end of "Measurement Period"
    )

define "Qualifying Encounters":
  ( [Encounter: "Office Visit"]
    union [Encounter: "Preventive Care Services - Established Office Visit, 18 and Up"]
    union [Encounter: "Preventive Care Services-Initial Office Visit, 18 and Up"]
    union [Encounter: "Home Healthcare Services"]
    union [Encounter: "Telephone Visits"]
    union [Encounter: "Online Assessments"] ) ValidEncounter
    where ValidEncounter.status = 'finished'
      and ValidEncounter.period during "Measurement Period"
