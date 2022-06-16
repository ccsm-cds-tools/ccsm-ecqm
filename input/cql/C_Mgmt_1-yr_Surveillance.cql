library C_Mgmt_TimeToColpoOrTreatment version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F

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
valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'

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
  AgeInYearsAt(date from start of "Measurement Period")in Interval[25, 65]
    and TLSL.FemaleorTransgenderMale
    and
      (exists "Abnormal Cervical Cancer Screening Cotest" //NILM and Positive, or LSIL and Negative, within MP shifted back 18 months
      or
      exists "Abnormal Cervical Cancer Screening Cytology Alone") //ASCUS, within MP shifted back 18 months

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or exists "Surveillance Tests" C where C.date before "First Abnormal Cervical Cancer Screening Result Date"
  or exists "Absence of Cervix"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  // or exists "a prior HPV screening test result before the initial abnormal result" // this is probably the same as line above

define "Numerator":
//  (
  "Most Recent Surveillance Test Date" in "Cotest Numerator Interval"
    or
  "Most Recent Surveillance Test Date" in "Cytology Alone Numerator Interval"
//  )
//  and AgeInYearsAt(date from start of "Measurement Period") in Interval[25, 65)

define "Cotest Numerator Interval":
  Interval[First("Abnormal Cervical Cancer Screening Cotest").CytologyCotest.date - 18 months, First("Abnormal Cervical Cancer Screening Cotest").CytologyCotest.date - 12 months]

define "Cytology Alone Numerator Interval":
  Interval[First("Abnormal Cervical Cancer Screening Cytology Alone").date - 12 months, First("Abnormal Cervical Cancer Screening Cytology Alone").date - 6 months]

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

define "Diagnosis of High Grade Pre-cancerous Cervical Lesion":
  QICore.Condition Lesion
//    where Lesion.code in "PlaceHolderValueSet"

define "Exclusionary Cervical Histology Result":
  QICore.Condition Histology
//    where Histology.code ~ PlaceHolderCode

define "Abnormal Cervical Cancer Screening Cotest":
"Cotests" Cotests //A definition for all cotests isn't in ManagmenetLibrary. Should that be created, as below?
  let screeningPeriod: Interval[start of "Measurement Period" - 18 months, start of "Measurement Period" - 6 months),
      CytologyCotest: Cotests.CytologyCotest,
      HrHPVCotest: Cotests.HrHPVCotest
  where Cotests.CytologyCotest.date in screeningPeriod
  //and HPVTest.date in screeningPeriod
  and (
        (CytologyCotest.riskTableInput ='NILM' and HrHPVCotest.riskTableInput = 'HPV-positive')
        or
        (CytologyCotest.riskTableInput ='LSIL' and HrHPVCotest.riskTableInput = 'HPV-negative')
      )
  sort by CytologyCotest.date

define "Abnormal Cervical Cancer Screening Cytology Alone":
  (ManagementLibrary.SortedCytologyReports except Cotests.CytologyCotest) CytologyAlone
  where CytologyAlone.date in Interval[start of "Measurement Period" - 18 months, start of "Measurement Period" - 6 months)
  and CytologyAlone.riskTableInput = 'ASC-US'
  sort by date

define "First Abnormal Cervical Cancer Screening Result Date":
  First(("Abnormal Cervical Cancer Screening Cytology Alone" union "Abnormal Cervical Cancer Screening Cotest") tests
  return tests sort by date).date

define "Cotests":
from ManagementLibrary.SortedHpvReports HrHPVCotest, ManagementLibrary.SortedCytologyReports CytologyCotest
where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

define "Primary HrHPV":
  ManagementLibrary.SortedHpvReports except Cotests.HrHPVCotest

define "Surveillance Tests":
  "Cotests" union "Primary HrHPV"

define "Most Recent Surveillance Test Date":
  First("Surveillance Tests" ST return ST sort by date).date
