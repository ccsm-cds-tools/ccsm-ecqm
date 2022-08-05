library C_Mgmt_TimeToTreatment version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DashboardLibrary version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include HPVVaccination_SDE version '0.0.1' called HPVVaccination_SDE
include CollateManagementData version '1.1.0' called Collate

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'
valueset "Referral to Gynecology": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.277'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period")in Interval[20, 65)
    and TLSL.FemaleorTransgenderMale
    and exists "CIN3 Cervical Cancer Histology"

define "CIN3 Cervical Cancer Histology":
  SortedBiopsyReports Biopsy
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
  or Dash."Pregnant"

define "Numerator":
  (exists Collate."CervicalPrecancerTreatments" AblationOrExcision
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
  HPVVaccination_SDE."HPV Vaccinated"


//The CQL below is required for the extended lookback period of this measure.
//As part of refactoring the CQL libraries for better use in both eCQMs and CDS,
//the lookback period will not have to be customized as below.

define HpvDiagnosticReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."HPV Test"],
      22 years
    )
  )

define HpvObservations:
  [Observation: Dash."HPV Test"]

define CervicalCytologyReports:
  Common.CompletedDiagnosticReport(
    Common.LookBack(
      [DiagnosticReport: Dash."Pap Test"],
      22 years
    )
  )

define CytologyObservations:
  [Observation: Dash."Pap Test"]

define function CollateConclusionCodes(D DiagnosticReport, ObsList List<Observation>):
  D.conclusionCode union
  (ObsList) O
    where 
      Exists( (D.result ) R where Last(Split(R.reference,'/')) =  O.id ) or
      Exists( (O.basedOn) oB where AnyTrue((D.basedOn) dB return dB = oB ) ) or
      C3F.FindDate(O) = Common.DiagnosticReportDate(D)
    return O.value as FHIR.CodeableConcept

define HistologyDiagnosticReports:
  Common.CompletedDiagnosticReport([DiagnosticReport: Dash."Biopsy Report"])

define HistologyObservations:
  [Observation: Dash."Biopsy Report"]

define HpvDiagnosticReportsSummary:
  (HpvDiagnosticReports) D
  return {
    name: 'HPV Test',
    longName: Common.ConceptText(D.code),
    riskTableInput: Dash.HighestRankedInterpretation(Dash.HpvInterpretation(CollateConclusionCodes(D,HpvObservations))),
    allConclusions: (CollateConclusionCodes(D,HpvObservations)) cC,
    date: Common.DiagnosticReportDate(D),
    reference: 'DiagnosticReport/' + D.id
  }

define CervicalCytologyReportsSummary:
  (CervicalCytologyReports) D
  return {
    name: 'Cervical Cytology',
    longName: Common.ConceptText(D.code),
    riskTableInput: Dash.HighestRankedInterpretation(Dash.CytologyInterpretation(CollateConclusionCodes(D,CytologyObservations))),
    allConclusions:
      (CollateConclusionCodes(D,CytologyObservations)) cC,
    date: Common.DiagnosticReportDate(D),
    reference: 'DiagnosticReport/' + D.id
  }

define HistologyDiagnosticReportsSummary:
  (HistologyDiagnosticReports) D
  return {
    name: 'Cervical Histology',
    longName: Common.ConceptText(D.code),
    riskTableInput: Dash.HighestRankedInterpretation(Dash.BiopsyInterpretation(CollateConclusionCodes(D,HistologyObservations))),
    allConclusions:
      (CollateConclusionCodes(D,HistologyObservations)) cC, 
    date: Common.DiagnosticReportDate(D),
    reference: 'DiagnosticReport/' + D.id
  }

define SortedCytologyReports:
  (CervicalCytologyReportsSummary) C
  sort by date desc

define SortedHpvReports:
  (HpvDiagnosticReportsSummary) H
  sort by date desc

define SortedBiopsyReports:
  (HistologyDiagnosticReportsSummary) H
  sort by date desc