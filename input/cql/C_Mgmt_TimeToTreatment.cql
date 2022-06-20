library C_Mgmt_TimeToTreatment version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'
valueset "Referral to Gynecology": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.277'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period")in Interval[21, 65)
    and TLSL.FemaleorTransgenderMale
    and exists "CIN3 Cervical Cancer Histology"

define "CIN3 Cervical Cancer Histology":
  ManagementLibrary.SortedBiopsyReports Biopsy
    where Biopsy.date in Interval[start of "Measurement Period" - 3 months, end of "Measurement Period" - 3 months]
    and Biopsy.riskTableInput = 'CIN3'
    sort by date

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  or "Absence of Cervix"
  or ManagementLibrary."Pregnant"

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
