library A_NeverScreened version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary

codesystem "PlaceHolderCodeSystem": 'http://terminology.hl7.org/CodeSystem/PlaceHolderCodeSystem'

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

valueset "PlaceHolderValueSet": 'http://cts.nlm.nih.gov/fhir/ValueSet/PlaceHolder'

code "PlaceHolderCode": 'laboratory' from "PlaceHolderCodeSystem" display 'PlaceHolderCode'

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
  AgeInYearsAt(date from start of "Measurement Period") in Interval[24, 65) //Start of measurement period for age calculation?
    and TLSL.FemaleorTransgenderMale
    and exists "Qualifying Encounters" //Do we need a qualifing encounter during the measurement period?

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
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or (exists "Absence of Cervix"
    and not
      (exists "Diagnosis of High Grade Pre-cancerous Cervical Lesion"
      or ManagementLibrary."HasCervicalCancerDiagnoses"
      or exists "Exclusionary Cervical Histology Result")
    )

define "Numerator":
  Count("Cervical Cytology Within 10 Years") = 0
  and Count("HPV Test Within 10 Years") = 0

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

define "Cervical Cytology Within 10 Years":
  QICore.Observation CervicalCytology
    where CervicalCytology.code in "Pap Test"
      and CervicalCytology.effective.latest() 10 years or less on or before end of "Measurement Period" //would screening during measurement period be included if this was changed to "...start of measurement period"
      //and CervicalCytology.value is not null

define "HPV Test Within 10 Years":
  QICore.Observation HPVTest
    where HPVTest.code in "HPV Test"
      and HPVTest.effective.latest() 10 years or less on or before end of "Measurement Period" //would screening during measurement period be included if this was changed to "...start of measurement period"
      //and HPVTest.value is not null
