library A_Screening65yo version '0.0.1'

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

define "Three Negative Cytology 3 Years Apart":
  from "All Negative Cytology Alone After 55" FirstNeg,
    "All Negative Cytology Alone After 55" SecondNeg,
    "All Negative Cytology Alone After 55" ThirdNeg
  where (FirstNeg != SecondNeg and FirstNeg != ThirdNeg and SecondNeg != ThirdNeg)
    and SecondNeg.date in Interval[FirstNeg.date + 3 years, FirstNeg.date + 3 years + 6 months]
    and ThirdNeg.date in Interval[SecondNeg.date + 3 years, SecondNeg.date + 3 years + 6 months]

define "Numerator":
  (exists "Three Negative Cytology 3 Years Apart")
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

define "Negative Surveillance in 10-Year Interval":
  "All Negative Surveillance After 55" SurveillanceTest
    where SurveillanceTest.date in day of "Surveillance Screening 10-Year Interval"

define "Cotests":
  from SortedHpvReports HrHPVCotest, SortedCytologyReports CytologyCotest
  where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

define "First Surveillance Date After 55":
  First("All Negative Surveillance After 55").date

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

//The CQL below is required for the extended lookback period of this measure. They
//are a nearly direct copy of several CDS Library definitions, modified with a
//longer lookback period. 
//As part of future plans to refactor the CQL libraries for better use in both
// eCQMs and CDS, the lookback period will eventually not have to be customized as below.

define HpvReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."HPV Test"],
      24 years
    )
  )

define CervicalCytologyReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."Pap Test"],
      24 years
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
