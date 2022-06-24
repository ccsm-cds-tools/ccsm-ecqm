library A_Screening65yo version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include AdultOutpatientEncountersFHIR4_2022 version '3.0.000' called AdultOutpatient
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include CCSMCommonFunctions version '1.0.0' called Common

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[64,75)
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
  (Count("Negative Cytology Every 3 Years") >= 2 and "Last Negative Cytology in Latter Half of 10-Year Interval")
  or
  (Count("Negative Surveillance in 10-Year Interval") >= 2)

define "All Negative Cytology Alone After 55":
  (SortedCytologyReports except Cotests.CytologyCotest) CytologyAlone
    where CytologyAlone.date in Interval[Patient.birthDate + 55 years, end of "Measurement Period")
    and CytologyAlone.riskTableInput = 'NILM'
      sort by date

define "All Negative Surveillance After 55":
  NegativeSurveillanceTests SurveillanceTest
    where SurveillanceTest.date in Interval[Patient.birthDate + 55 years, end of "Measurement Period")
      sort by date

define "Last Negative Cytology in Latter Half of 10-Year Interval":
  (Last ("Negative Cytology in 10-Year Interval")).date in Interval[start of "Cytology Screening 10-Year Interval" + 5 years, end of "Cytology Screening 10-Year Interval"]

define "Negative Cytology in 10-Year Interval":
  "All Negative Cytology Alone After 55" CytologyAlone
    where CytologyAlone.date in "Cytology Screening 10-Year Interval"

define "Negative Surveillance in 10-Year Interval":
  "All Negative Surveillance After 55" SurveillanceTes
    where SurveillanceTes.date in "Surveillance Screening 10-Year Interval"

define "Negative Cytology Every 3 Years":
  from "Negative Cytology in 10-Year Interval" CytologyAlone, "Cytology Testing Intervals" TestingIntervals
  where CytologyAlone.date in TestingIntervals

define "Cytology Testing Intervals":
  "Negative Cytology in 10-Year Interval" input
  return Interval[input.date + 3 years, input.date + 3 years + 6 months]

define "Cotests":
  from SortedHpvReports HrHPVCotest, SortedCytologyReports CytologyCotest
  where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

define "First Cytology Date After 55":
  First("All Negative Cytology Alone After 55").date

define "First Surveillance Date After 55":
  First("All Negative Surveillance After 55").date

define "Cytology Screening 10-Year Interval":
  Interval["First Cytology Date After 55", "First Cytology Date After 55" + 10 years]

define "Surveillance Screening 10-Year Interval":
  Interval["First Surveillance Date After 55", "First Surveillance Date After 55" + 10 years]

//The CPT value set below will be integrated into the ManagementLibrary definition
//of AbsenceOrRemovalOfCervix. When that work is complete the code looking for
//the CPT value set will be removed.
define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

//The CQL below is required for the extended lookback period of this measure.
//As part of refactoring the CQL libraries for better use in both eCQMs and CDS,
//the lookback period will not have to be customized as below.

define HpvReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."HPV Test"],
      22 years
    )
  )

define CervicalCytologyReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."Pap Test"],
      22 years
    )
  )

define SortedCytologyReports:
  (CervicalCytologyReports) C
  return {
    riskTableInput: ManagementLibrary.HighestRankedInterpretation(
      ManagementLibrary.CytologyInterpretation(
        C.conclusionCode
      )
    ),
    allConclusions: C.conclusionCode,
    date: Common.DiagnosticReportDate(C)
  }
  sort by date desc

define SortedHpvReports:
  (HpvReports) H
  return {
    riskTableInput: ManagementLibrary.HighestRankedInterpretation(
      ManagementLibrary.HpvInterpretation(
        H.conclusionCode
      )
    ),
    allConclusions: H.conclusionCode,
    date: Common.DiagnosticReportDate(H)
  }
  sort by date desc

define NegativeHrHpvTests:
  SortedHpvReports R
    where AnyTrue(
      (R.allConclusions) aC
        return
          aC in Dash."HPV Negative Results"
    )

define NegativeHrHpvTestsAsPartOfCotest:
  from NegativeHrHpvTests H, SortedCytologyReports C
    where H.date within 1 day of C.date
    return H

define NegativePrimaryHrHpvTests:
  NegativeHrHpvTests except NegativeHrHpvTestsAsPartOfCotest

define NegativeCytologyTests:
  SortedCytologyReports R
    where AnyTrue(
      (R.allConclusions) aC
        return
          aC ~ Dash."NILM"
    )

define NegativeCotests:
  from NegativeHrHpvTests H, NegativeCytologyTests C
    where H.date within 1 day of C.date
    return H

define NegativeSurveillanceTests:
  (
    NegativePrimaryHrHpvTests union
    NegativeCotests
  )
