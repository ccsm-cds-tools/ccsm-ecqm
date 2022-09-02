library A_NeverScreened version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.1.000' called FHIRHelpers
include TopLevelScreeningLibrary version '1.0.000' called TLSL
include HospiceFHIR4 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include AdultOutpatientEncountersFHIR4 version '3.0.000' called AdultOutpatient
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include CCSMCommonFunctions version '1.0.0' called Common

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'

parameter "Measurement Period" Interval<DateTime> default Interval[@2021-01-01T00:00:00.0, @2022-01-01T00:00:00.0)
parameter CervicalCytologyLookbackPeriod default 15 years

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[23, 65)
    and TLSL.FemaleorTransgenderMale
    and exists AdultOutpatient."Qualifying Encounters"

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or ("Absence of Cervix"
    and not
      (ManagementLibrary."HasHighGradePreCancerCervicalLesion"
      or ManagementLibrary."HasCervicalCancerDiagnoses"
      or exists Dash."HighGradeOrCancerHistologyResults")
    )

define "Numerator":
  Count(CervicalCytologyReports) = 0
  and Count(HpvReports) = 0

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

//The CQL below is required for the extended lookback period of this measure. They
//are a nearly direct copy of several CDS Library definitions, modified with a
//longer lookback period. 
//As part of future plans to refactor the CQL libraries for better use in both
// eCQMs and CDS, the lookback period will eventually not have to be customized as below.

define HpvReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."HPV Test"],
      14 years
    )
  )

define CervicalCytologyReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."Pap Test"],
      14 years
    )
  )
