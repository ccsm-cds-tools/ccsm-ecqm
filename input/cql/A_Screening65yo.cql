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
    and exists "Qualifying Encounters"

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

define "Numerator": //Need to align more tightly with eCQM spreadsheet
  (ManagementLibrary.MostRecentCytologyReportWasWithinPastFiveYearsFrom(start of "Measurement Period") //Modified CDS library definition
  and Count("Negative Cervical Cytology Every 3 Years") >= 3)
    or
  (exists ManagementLibrary."NegativePrimaryHrHpvTests" X where X.date in Interval[start of "Measurement Period" - 5 years, end of "Measurement Period")
  and Count(ManagementLibrary."NegativeSurveillanceTests" X where X.date in Interval[start of "Measurement Period" - 10 years, end of "Measurement Period")) >= 2)

define "Normal Cervical Cancer Screening Cytology Alone Within 10 Years":
  (ManagementLibrary.SortedCytologyReports except Cotests.CytologyCotest) CytologyAlone
    where CytologyAlone.date in Interval[start of "Measurement Period" - 10 years, end of "Measurement Period")//should the end of this interval be the date of the last encounter of the measurement period?
    and CytologyAlone.riskTableInput = 'NILM'

define "Negative Cervical Cytology Every 3 Years":
  "Normal Cervical Cancer Screening Cytology Alone Within 10 Years" CytologyAlone
  where CytologyAlone.date in Interval[CytologyAlone.date - 3.5 years, CytologyAlone.date - 3 years]

define "Cotests":
  from ManagementLibrary.SortedHpvReports HrHPVCotest, ManagementLibrary.SortedCytologyReports CytologyCotest
  where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

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

define "Diagnosis of High Grade Pre-cancerous Cervical Lesion":
  QICore.Condition Lesion
    where Lesion.code in "PlaceHolderValueSet"

define "Diagnosis of Cervical Cancer":
  QICore.Condition Cancer
    where Cancer.code in "PlaceHolderValueSet"

define "Exclusionary Cervical Histology Result":
  QICore.Condition Histology
    where Histology.code ~ PlaceHolderCode
