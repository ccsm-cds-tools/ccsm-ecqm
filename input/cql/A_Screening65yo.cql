library A_Screening65yo version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include TopLevelScreeningLibrary version '1.0.0' called TLSL
//include HospiceFHIR4 version '2.3.000' called Hospice
//include PalliativeCareFHIR version '0.6.000' called PalliativeCare

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

valueset "NILM": 'http://cts.nlm.nih.gov/fhir/ValueSet/NILM'
valueset "HPV Positive": 'http://cts.nlm.nih.gov/fhir/ValueSet/HPV.positive'

code "laboratory": 'laboratory' from "ObservationCategoryCodes" display 'Laboratory'

parameter "Measurement Period" Interval<DateTime>
  default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "SDE Ethnicity":
  SDE."SDE Ethnicity"

define "SDE Payer":
  SDE."SDE Payer"

define "SDE Race":
  SDE."SDE Race"

define "SDE Sex":
  SDE."SDE Sex"

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") >= 65
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

/*
define "Denominator Exclusions":
  Hospice."Has Hospice"
    or exists "Absence of Cervix"
    or PalliativeCare."Palliative Care in the Measurement Period"
*/

define "Numerator":
  "Three Negative Cervical Cytology Within Last 10 Years"

/*Negagtive Cervical Cytology AND Cervical Cytology Alone*/
define "Three Negative Cervical Cytology Within Last 10 Years":
  Count(QICore.Observation NormalCytology
//  where NormalCytology.code in "NILM" //todo
  where  NormalCytology.effective.latest() in Interval[start of "Measurement Period" - 10 years, Today()]) >= 3 //todo make this "and"; Also, 10 years from start of MP, or 10 years from today?

define "Consecutive Cytologies Within 36 To 42 Months":
  from
    QICore.Observation Cytology
    //  where NormalCytology.code in "NILM" //todo
    let PriorCytology: Last(QICore.Observation)

/*define "Negative Cervical Cytology":
  exists
    (QICore.Observation NegCervicalCytology
      where NegCervicalCytology.code in "NILM")
  and not exists
    (QICore.Observation HPVTest
      where HPVTest.code in "HPV Positive")*/

define "Negative Primary hrHPV":
  true


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
