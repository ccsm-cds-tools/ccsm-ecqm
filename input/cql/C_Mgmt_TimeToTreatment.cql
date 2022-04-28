library C_Mgmt_TimeToTreatment version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include HospiceQICore4 version '2.0.000' called Hospice
//include PalliativeCareFHIR version '0.6.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common

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
valueset "HSIL": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.256'

valueset "HPV Positive": 'http://cts.nlm.nih.gov/fhir/ValueSet/test' //placeholder for HPV positive codes "Positive", "hrHPV 16 positive", "hrHPV 18 positive"
valueset "Abnormal Cytology": 'http://cts.nlm.nih.gov/fhir/ValueSet/test' //placeholder for abnormal cytology codes "ASCUS", "LSIL", "NILM"

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
  AgeInYearsAt(date from start of "Measurement Period")in Interval[25, 65)
    and Patient.gender = 'female'
    //and Patient.genderIdentity = 'transgenderMale' //extension http://hl7.org/fhir/StructureDefinition/patient-genderIdentity; needs valueSet
    and exists "Abnormal Cervical Cancer Screening Cotest"

define "Abnormal Cervical Cancer Screening Cotest":
  from ManagementLibrary.SortedCytologyReports HSILCervicalCytology, ManagementLibrary.SortedHpvReports HPVTest //A definition for all cotests isn't in ManagmenetLibrary. Should that be created?
    let screeningPeriod: Interval[start of "Measurement Period" - 3 months, end of "Measurement Period" - 3 months]
    where HSILCervicalCytology.date in screeningPeriod
    and HPVTest.date in screeningPeriod
    and HSILCervicalCytology.riskTableInput = 'HSIL+'
    and HPVTest.riskTableInput = 'HPV16+' //just 16+, not also 18? And, Antigen or DNA positive, or both (as is is set now)? (See HPV interpretation table)
    //and HPVTest.date within 1 day of HSILCervicalCytology.date //this makes it a cotest, is this needed?
    sort by HSILCervicalCytology.date

/*define "Qualifying Encounters":
  ( [Encounter: "Office Visit"]
    union [Encounter: "Preventive Care Services - Established Office Visit, 18 and Up"]
    union [Encounter: "Preventive Care Services-Initial Office Visit, 18 and Up"]
    union [Encounter: "Home Healthcare Services"]
    union [Encounter: "Telephone Visits"]
    union [Encounter: "Online Assessments"] ) ValidEncounter
    where ValidEncounter.status = 'finished'
      and ValidEncounter.period during "Measurement Period"*/

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice"
  //or PalliativeCare."Palliative Care in the Measurement Period"
  or (exists "Absence of Cervix"
    and not
      (
      exists "Diagnosis of High Grade Pre-cancerous Cervical Lesion"
      //or exists "Diagnosis of Cervical Cancer"
      //or exists "Exclusionary Cervical Histology Result"
      )
    )

define "Numerator":
  Common.ProcedureDate(First(ManagementLibrary.CervicalPrecancerTreatments C return C sort by (performed as dateTime))) 3 months or less after First("Abnormal Cervical Cancer Screening Cotest").HSILCervicalCytology.date
  and AgeInYearsAt(date from start of "Measurement Period") in Interval[30, 65)

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
//    where Lesion.code in "PlaceHolderValueSet"

define "Exclusionary Cervical Histology Result":
  QICore.Condition Histology
//    where Histology.code ~ PlaceHolderCode