library A_Screening65yo version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include HospiceQICore4 version '2.0.000' called Hospice
//include PalliativeCareFHIR version '0.6.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary

codesystem "ObservationCategoryCodes": 'http://terminology.hl7.org/CodeSystem/observation-category'
codesystem "PlaceHolderCodeSystem": 'http://terminology.hl7.org/CodeSystem/PlaceHolderCodeSystem'
codesystem "SNOMED-CT": 'http://snomed.info/sct'

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

//valueset "HPV Positive": 'http://cts.nlm.nih.gov/fhir/ValueSet/HPV.positive'

valueset "PlaceHolderValueSet": 'http://cts.nlm.nih.gov/fhir/ValueSet/PlaceHolder'

code "NILM": '373887005' from "SNOMED-CT" display 'Negative for intraepithelial lesion or malignancy (finding)'


code "PlaceHolderCode": 'laboratory' from "PlaceHolderCodeSystem" display 'PlaceHolderCode'

code "laboratory": 'laboratory' from "ObservationCategoryCodes" display 'Laboratory'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)
parameter CytologyReportLookbackStart DateTime default @2020-01-01T00:00:00.0
parameter GradeDAdequatePriorScreeningLookback default 11 //years

context Patient

/*define "SDE Ethnicity":
  SDE."SDE Ethnicity"
define "SDE Payer":
  SDE."SDE Payer"
define "SDE Race":
  SDE."SDE Race"
define "SDE Sex":
  SDE."SDE Sex"*/

define "Adequate Screening Start Date":
  Date(year from Today() - (AgeInYears() - 65 ) - GradeDAdequatePriorScreeningLookback, month from Today(), day from Today()) //this calculated date ends up tied to Today(). Should it be from start/end of MP?

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") >= 65 //Start of measurement period for age calculation?
    and TLSL.FemaleorTransgenderMale
    //and exists "Qualifying Encounters" //Do we need a qualifing encounter during the measurement period?

define "Qualifying Encounters":
  ( [Encounter: "Office Visit"]
    union [Encounter: "Preventive Care Services - Established Office Visit, 18 and Up"]
    union [Encounter: "Preventive Care Services-Initial Office Visit, 18 and Up"]
    union [Encounter: "Home Healthcare Services"]
    union [Encounter: "Telephone Visits"]
    union [Encounter: "Online Assessments"] ) ValidEncounter
    where ValidEncounter.status = 'finished'
      and ValidEncounter.period during "Measurement Period"

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice"
  //or PalliativeCare."Palliative Care in the Measurement Period"
  or (exists "Absence of Cervix"
    and not
      (
      exists "Diagnosis of High Grade Pre-cancerous Cervical Lesion"
      or exists "Diagnosis of Cervical Cancer"
      or exists "Exclusionary Cervical Histology Result"
      )
    )

define "Numerator":
  ManagementLibrary.MostRecentCytologyReportWasWithinPastFiveYearsFrom(start of "Measurement Period")
  //"Three Negative Cervical Cytology Within Last 10 Years"

define "Adequate Prior Screening":
  "Negative Cervical Cytology Every 3 Years x 3"
  and Count(ManagementLibrary."NegativeSurveillanceTests") >= 2

//All PrimaryHPV, Cotest, and CervicalCytologyAlone tests
/*define "Identified Tests":
  true

define "Primary HrHPV not Cotest":
  ManagementLibrary.SortedHpvReports H
  where not (H in Cotests.HrHPV)

define "Cytology Reports not Cotest":
  ManagementLibrary.SortedCytologyReports C
  where not (C in Cotests.Cytology)

define "Cotests":
  from ManagementLibrary.SortedHpvReports HrHPV, ManagementLibrary.SortedCytologyReports Cytology
  where HrHPV.date in Interval[Cytology.date - 1 day, Cytology.date + 1 day]

define "Negative Cervical Cytology":
  "Cytology Reports not Cotest" C
  where C.riskTableInput = 'NILM'

define "Negative Primary HrHPV":
  "Primary HrHPV not Cotest" P
  where P.riskTableInput = 'HPV-Negative'

define "Negative Cotests":
  ManagementLibrary.NegativeCotests*/

define "Negative Cervical Cytology Every 3 Years x 3":
  true

/*Negagtive Cervical Cytology AND Cervical Cytology Alone*/
define "Three Negative Cervical Cytology Within Last 10 Years":
//  from QICore.Observation NormalCytology,
  Count(QICore.Observation NormalCytology
    where NormalCytology.code ~ "NILM"
    and NormalCytology.effective.latest() in Interval[start of "Measurement Period" - 10 years, Today()]) >= 3

define "Consecutive Cytologies Within 36 To 42 Months":
    QICore.Observation Cytology
      where Cytology.code ~ "NILM"
    //let PriorCytology: Last(QICore.Observation)

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

define "Cervical Cytology Within 3 Years":
  QICore.Observation CervicalCytology
    where CervicalCytology.code in "Pap Test"
      and CervicalCytology.effective.latest() 3 years or less on or before end of "Measurement Period"
      and CervicalCytology.value is not null

define "HPV Test Within 5 Years for Women Age 30 and Older":
  QICore.Observation HPVTest
    where HPVTest.code in "HPV Test"
      and AgeInYearsAt(date from start of HPVTest.effective.toInterval()) >= 30
      and HPVTest.effective.latest() 5 years or less on or before end of "Measurement Period"
      and HPVTest.value is not null

define "Diagnosis of High Grade Pre-cancerous Cervical Lesion":
  QICore.Condition Lesion
    where Lesion.code in "PlaceHolderValueSet"

define "Diagnosis of Cervical Cancer":
  QICore.Condition Cancer
    where Cancer.code in "PlaceHolderValueSet"

define "Exclusionary Cervical Histology Result":
  QICore.Condition Histology
    where Histology.code ~ PlaceHolderCode
