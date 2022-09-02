library C_Mgmt_TimeToTreatment version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.1.000' called FHIRHelpers
include HospiceFHIR4 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.000' called TLSL
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include HPVVaccinationSDE version '0.0.1' called HPVVaccinationSDE

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'
valueset "Referral to Gynecology": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.277'

parameter "Measurement Period" Interval<DateTime> default Interval[@2021-01-01T00:00:00.0, @2022-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period")in Interval[20, 65)
    and TLSL.FemaleorTransgenderMale
    and exists "CIN3 Cervical Cancer Histology"

define "CIN3 Cervical Cancer Histology":
  ManagementLibrary.SortedBiopsyReports Biopsy
    where Biopsy.date in day of Interval[start of "Measurement Period" - 3 months, end of "Measurement Period" - 3 months]
    and Biopsy.riskTableInput = 'CIN3'
    sort by date

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  or "Absence of Cervix"
  or "Pregnant"

define "Numerator":
  (exists ManagementLibrary."CervicalPrecancerTreatments" AblationOrExcision
    where Common.ProcedureDate(AblationOrExcision) 3 months or less after First("CIN3 Cervical Cancer Histology").date)
  or
  (exists "Precancer Treatment Referral" R
    where R.authoredOn 30 days or less after First("CIN3 Cervical Cancer Histology").date)

define "Precancer Treatment Referral":
  [ServiceRequest: "Referral to Gynecology"] Referral
    where Referral.status in { 'draft', 'active', 'on-hold', 'completed' }
    and Referral.doNotPerform is not true

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

define "SDE HPV Vaccination Status":
  HPVVaccinationSDE."HPV Vaccinated"

//The CQL below is required for the extended lookback period of this measure. They
//are a nearly direct copy of several CDS Library definitions, modified with a
//longer lookback period. 
//As part of future plans to refactor the CQL libraries for better use in both
// eCQMs and CDS, the lookback period will eventually not have to be customized as below.

define "Weeks to look back":
  ToQuantity(ToString(weeks between (start of "Measurement Period" - 3 months) and Now()+ 2 weeks) + ' week')


define Pregnant:
  Exists(Dash.PregnancyDiagnoses) or
  Exists(Dash.PregnancyObservations)

define PregnancyDiagnoses:
  C3F.Confirmed(
    C3F.ActiveOrRecurring(
      C3F.ConditionLookBack(
        [Condition: Dash."Pregnancy"] union [Condition: Dash."Pregnancy (New ICD10 codes published in 2018 and 2020)"],
        "Weeks to look back"
      )
    )
  )

define PregnancyObservations:
  C3F.ObservationLookBack(
    C3F.Verified(
      [Observation: Dash."Pregnancy Status"] P
        where P.value ~ Dash."Patient currently pregnant"
    ),
    "Weeks to look back"
  )